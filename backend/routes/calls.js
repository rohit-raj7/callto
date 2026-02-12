import express from 'express';
const router = express.Router();
import pkg from 'agora-access-token';
const { RtcTokenBuilder, RtcRole } = pkg;
import Call from '../models/Call.js';
import Rating from '../models/Rating.js';
import Listener from '../models/Listener.js';
import User from '../models/User.js';
import { authenticate } from '../middleware/auth.js';
import config from '../config/config.js';
import { finalizeCallBilling } from '../services/callBillingService.js';
import { getRateConfig } from '../db.js';

const resolveDurationSeconds = (call, durationSeconds) => {
  const endedAt = new Date();
  if (call.started_at) {
    return Math.max(
      0,
      Math.round((endedAt.getTime() - new Date(call.started_at).getTime()) / 1000)
    );
  }
  if (call.created_at) {
    return Math.max(
      0,
      Math.round((endedAt.getTime() - new Date(call.created_at).getTime()) / 1000)
    );
  }
  if (durationSeconds !== undefined) {
    return Math.max(0, Number(durationSeconds) || 0);
  }
  return 0;
};

// POST /api/calls
// Initiate a new call
router.post('/', authenticate, async (req, res) => {
  try {
    const { listener_id, call_type } = req.body;

    if (!listener_id) {
      return res.status(400).json({ error: 'listener_id is required' });
    }

    // Get listener details for rate
    const listener = await Listener.findById(listener_id);
    
    if (!listener) {
      return res.status(404).json({ error: 'Experts not found' });
    }

    // VERIFICATION CHECK: Block calls to non-approved listeners
    // Only listeners with verificationStatus = 'approved' can receive calls
    const verificationStatus = listener.verification_status || 'approved'; // Backward compatibility
    if (verificationStatus !== 'approved') {
      console.log(`[CALLS] Call blocked: Listener ${listener_id} not approved (status: ${verificationStatus})`);
      return res.status(403).json({ 
        error: 'Listener not approved yet',
        details: 'This listener is currently under verification and cannot receive calls.'
      });
    }

    if (!listener.is_available || !listener.is_online) {
      console.log(`[CALLS] Experts ${listener.listener_id} unavailable: available=${listener.is_available}, online=${listener.is_online}`);
      return res.status(400).json({ 
        error: 'Experts is not available',
        details: { is_available: listener.is_available, is_online: listener.is_online }
      });
    }

    // BUSY CHECK: Block calls to listeners already in an active call
    if (listener.is_busy) {
      console.log(`[CALLS] Experts ${listener.listener_id} is BUSY — rejecting call`);
      return res.status(409).json({
        error: 'Experts is busy',
        status: 'busy',
        details: 'This listener is currently on another call. Please try again later.'
      });
    }

    const userRate = Number(listener.user_rate_per_min || 0);
    if (!Number.isFinite(userRate) || userRate <= 0) {
      return res.status(500).json({ error: 'Experts rate is invalid' });
    }

    // Check if user is eligible for first-time offer
    const caller = await User.findById(req.userId);
    const rateConfig = await getRateConfig();
    const isOfferEligible = caller && caller.is_first_time_user && !caller.offer_used
      && rateConfig.first_time_offer_enabled
      && rateConfig.offer_minutes_limit > 0
      && Number(rateConfig.offer_flat_price) > 0;

    const effectiveRate = isOfferEligible
      ? Number(rateConfig.offer_flat_price) / rateConfig.offer_minutes_limit
      : userRate;

    const wallet = await User.getWallet(req.userId);
    const availableBalance = parseFloat(wallet.balance || 0);
    if (availableBalance < effectiveRate) {
      return res.status(402).json({
        error: 'Low balance',
        details: `Minimum balance of ₹${effectiveRate.toFixed(2)} is required to start a call`
      });
    }

    // Create call — store the effective rate so billing uses it
    const call = await Call.create({
      caller_id: req.userId,
      listener_id,
      call_type: call_type || 'audio',
      rate_per_minute: effectiveRate
    });

    res.status(201).json({
      message: 'Call initiated',
      call
    });
  } catch (error) {
    console.error('Create call error:', error);
    res.status(500).json({ error: 'Failed to initiate call' });
  }
});

// GET /api/calls/:call_id
// Get call details
router.get('/:call_id', authenticate, async (req, res) => {
  try {
    const call = await Call.findById(req.params.call_id);

    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    // Check if user is part of the call (as caller or listener)
    const listener = await Listener.findByUserId(req.userId);
    const isListener = listener && call.listener_id === listener.listener_id;
    
    if (call.caller_id !== req.userId && !isListener) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    res.json({ call });
  } catch (error) {
    console.error('Get call error:', error);
    res.status(500).json({ error: 'Failed to fetch call' });
  }
});

// PUT /api/calls/:call_id/status
// Update call status
router.put('/:call_id/status', authenticate, async (req, res) => {
  try {
    const { status, duration_seconds } = req.body;

    if (!status) {
      return res.status(400).json({ error: 'Status is required' });
    }

    const validStatuses = ['pending', 'ringing', 'ongoing', 'completed', 'missed', 'rejected', 'cancelled'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    // Get call and verify user is part of it
    const call = await Call.findById(req.params.call_id);
    
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }
    
    // Check if user is caller or listener
    const listener = await Listener.findByUserId(req.userId);
    const isListener = listener && call.listener_id === listener.listener_id;
    
    if (call.caller_id !== req.userId && !isListener) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (status === 'completed') {
      const resolvedDurationSeconds = resolveDurationSeconds(call, duration_seconds);
      const billing = await finalizeCallBilling({
        callId: req.params.call_id,
        durationSeconds: resolvedDurationSeconds
      });

      if (!billing.alreadyBilled) {
        await Listener.incrementCallStats(call.listener_id, billing.minutes);
      }

      // BUSY: Clear busy when call completes
      try { await Listener.clearBusy(call.listener_id); } catch (e) { console.error('[CALLS] clearBusy error:', e.message); }

      const updatedCall = await Call.findById(req.params.call_id);
      return res.json({
        message: 'Call status updated',
        call: updatedCall,
        billing: {
          minutes: billing.minutes,
          userCharge: billing.userCharge,
          // FIX: Include listenerEarn and platformCommission so listener
          // dashboard can show correct payout without frontend calculation.
          // listenerEarn is computed using admin-set listener_payout_per_min
          // from the DB — never from frontend values.
          listenerEarn: billing.listenerEarn,
          platformCommission: billing.userCharge - billing.listenerEarn,
          durationSeconds: resolvedDurationSeconds
        }
      });
    }

    // BUSY: Set busy when call becomes ongoing, clear on terminal states
    if (status === 'ongoing') {
      try { await Listener.setBusy(call.listener_id); } catch (e) { console.error('[CALLS] setBusy error:', e.message); }
    } else if (['rejected', 'missed', 'cancelled'].includes(status)) {
      try { await Listener.clearBusy(call.listener_id); } catch (e) { console.error('[CALLS] clearBusy error:', e.message); }
    }

    const updatedCall = await Call.updateStatus(req.params.call_id, status);

    res.json({
      message: 'Call status updated',
      call: updatedCall
    });
  } catch (error) {
    console.error('Update call status error:', error);
    if (error.code === 'INSUFFICIENT_BALANCE') {
      return res.status(402).json({ error: 'Insufficient balance to complete billing' });
    }
    res.status(500).json({ error: 'Failed to update call status' });
  }
});

// POST /api/calls/end
// Finalize call billing with duration
router.post('/end', authenticate, async (req, res) => {
  try {
    const { callId, durationSeconds } = req.body || {};

    if (!callId) {
      return res.status(400).json({ error: 'callId is required' });
    }

    const call = await Call.findById(callId);
    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    const listener = await Listener.findByUserId(req.userId);
    const isListener = listener && call.listener_id === listener.listener_id;

    if (call.caller_id !== req.userId && !isListener) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const resolvedDurationSeconds = resolveDurationSeconds(call, durationSeconds);
    const billing = await finalizeCallBilling({
      callId,
      durationSeconds: resolvedDurationSeconds
    });

    if (!billing.alreadyBilled) {
      await Listener.incrementCallStats(call.listener_id, billing.minutes);
      // offer_used is now marked atomically inside callBillingService transaction
    }

    const updatedCall = await Call.findById(callId);

    // BUSY: Clear busy when call ends
    try { await Listener.clearBusy(call.listener_id); } catch (e) { console.error('[CALLS] clearBusy error:', e.message); }

    res.json({
      message: 'Call ended',
      call: updatedCall,
      billing: {
        minutes: billing.minutes,
        userCharge: billing.userCharge,
        // FIX: Include listenerEarn and platformCommission so listener
        // dashboard can show correct payout without frontend calculation.
        // listenerEarn is computed using admin-set listener_payout_per_min
        // from the DB — never from frontend values.
        listenerEarn: billing.listenerEarn,
        platformCommission: billing.userCharge - billing.listenerEarn,
        durationSeconds: resolvedDurationSeconds
      }
    });
  } catch (error) {
    console.error('End call error:', error);
    if (error.code === 'INSUFFICIENT_BALANCE') {
      return res.status(402).json({ error: 'Insufficient balance to complete billing' });
    }
    if (error.code === 'CALL_NOT_FOUND') {
      return res.status(404).json({ error: 'Call not found' });
    }
    res.status(500).json({ error: 'Failed to end call' });
  }
});

// GET /api/calls/history/me
// Get user's call history
router.get('/history/me', authenticate, async (req, res) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit) : 20;
    const offset = req.query.offset ? parseInt(req.query.offset) : 0;

    const calls = await Call.getUserCallHistory(req.userId, limit, offset);

    res.json({
      calls,
      count: calls.length
    });
  } catch (error) {
    console.error('Get call history error:', error);
    res.status(500).json({ error: 'Failed to fetch call history' });
  }
});

// GET /api/calls/history/listener
// Get listener's call history (for listeners to see their callers)
router.get('/history/listener', authenticate, async (req, res) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit) : 20;
    const offset = req.query.offset ? parseInt(req.query.offset) : 0;

    // Get listener_id for this user
    const listener = await Listener.findByUserId(req.userId);
    
    if (!listener) {
      return res.status(404).json({ error: 'Listener profile not found' });
    }

    const calls = await Call.getListenerCallHistory(listener.listener_id, limit, offset);

    res.json({
      calls,
      count: calls.length
    });
  } catch (error) {
    console.error('Get listener call history error:', error);
    res.status(500).json({ error: 'Failed to fetch call history' });
  }
});

// GET /api/calls/active/me
// Get user's active calls
router.get('/active/me', authenticate, async (req, res) => {
  try {
    const calls = await Call.getActiveCalls(req.userId);

    res.json({
      calls,
      count: calls.length
    });
  } catch (error) {
    console.error('Get active calls error:', error);
    res.status(500).json({ error: 'Failed to fetch active calls' });
  }
});

// POST /api/calls/:call_id/rating
// Rate a completed call
router.post('/:call_id/rating', authenticate, async (req, res) => {
  try {
    const { rating, review_text } = req.body;

    if (!rating || rating < 1 || rating > 5) {
      return res.status(400).json({ error: 'Rating must be between 1 and 5' });
    }

    // Get call details
    const call = await Call.findById(req.params.call_id);

    if (!call) {
      return res.status(404).json({ error: 'Call not found' });
    }

    if (call.caller_id !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    if (call.status !== 'completed') {
      return res.status(400).json({ error: 'Can only rate completed calls' });
    }

    // Check if already rated
    const alreadyRated = await Rating.isCallRated(req.params.call_id);
    if (alreadyRated) {
      return res.status(400).json({ error: 'Call already rated' });
    }

    // Create rating
    const ratingRecord = await Rating.create({
      call_id: req.params.call_id,
      listener_id: call.listener_id,
      user_id: req.userId,
      rating: parseFloat(rating),
      review_text
    });

    // Update listener's average rating and total ratings
    const averageData = await Rating.getListenerAverageRating(call.listener_id);
    await Listener.updateRatingStats(call.listener_id, averageData.average_rating, averageData.total_ratings);

    res.status(201).json({
      message: 'Rating submitted successfully',
      rating: ratingRecord
    });
  } catch (error) {
    console.error('Create rating error:', error);
    res.status(500).json({ error: 'Failed to submit rating' });
  }
});

// POST /api/calls/random
// Initiate a random call with a random listener
router.post('/random', authenticate, async (req, res) => {
  try {
    const { call_type } = req.body;

    // Get a random available listener
    const listeners = await Listener.getRandomAvailable(1);

    if (listeners.length === 0) {
      return res.status(404).json({ error: 'No available listeners found' });
    }

    const listener = listeners[0];

    if (!listener.is_available || !listener.is_online) {
      console.log(`[CALLS] Listener ${listener.listener_id} unavailable: available=${listener.is_available}, online=${listener.is_online}`);
      return res.status(400).json({ 
        error: 'Listener is not available',
        details: { is_available: listener.is_available, is_online: listener.is_online }
      });
    }

    // BUSY CHECK: getRandomAvailable already filters busy, but guard against race condition
    if (listener.is_busy) {
      console.log(`[CALLS] Random listener ${listener.listener_id} is BUSY — rejecting`);
      return res.status(409).json({
        error: 'Listener is busy',
        status: 'busy',
        details: 'Selected listener is currently on another call. Please try again.'
      });
    }

    const userRate = Number(listener.user_rate_per_min || 0);
    if (!Number.isFinite(userRate) || userRate <= 0) {
      return res.status(500).json({ error: 'Listener rate is invalid' });
    }

    // Check if user is eligible for first-time offer
    const caller = await User.findById(req.userId);
    const rateConfig = await getRateConfig();
    const isOfferEligible = caller && caller.is_first_time_user && !caller.offer_used
      && rateConfig.first_time_offer_enabled
      && rateConfig.offer_minutes_limit > 0
      && Number(rateConfig.offer_flat_price) > 0;

    const effectiveRate = isOfferEligible
      ? Number(rateConfig.offer_flat_price) / rateConfig.offer_minutes_limit
      : userRate;

    const wallet = await User.getWallet(req.userId);
    const availableBalance = parseFloat(wallet.balance || 0);
    if (availableBalance < effectiveRate) {
      return res.status(402).json({
        error: 'Insufficient balance',
        details: `Minimum balance of ₹${effectiveRate.toFixed(2)} is required to start a call`
      });
    }

    // Create call with random listener — store effective rate
    const call = await Call.create({
      caller_id: req.userId,
      listener_id: listener.listener_id,
      call_type: call_type || 'audio',
      rate_per_minute: effectiveRate
    });

    res.status(201).json({
      message: 'Random call initiated',
      call,
      listener: {
        listener_id: listener.listener_id,
        professional_name: listener.professional_name,
        avatar_url: listener.profile_image,
        rating: listener.average_rating,
        city: listener.city
      }
    });
  } catch (error) {
    console.error('Random call error:', error);
    res.status(500).json({ error: 'Failed to initiate random call' });
  }
});

// POST /api/calls/agora/token
// Generate Agora RTC token for a call
router.post('/agora/token', authenticate, async (req, res) => {
  try {
    const { channel_name, uid } = req.body;
    console.log(`[AGORA] Token request for channel: ${channel_name}, uid: ${uid}`);

    if (!channel_name) {
      console.log('[AGORA] Error: channel_name is required');
      return res.status(400).json({ error: 'channel_name is required' });
    }

    const appId = config.agora.appId;
    const appCertificate = config.agora.appCertificate;

    if (!appId || !appCertificate) {
      console.error('[AGORA] Error: Agora credentials not configured', { appId: !!appId, cert: !!appCertificate });
      return res.status(500).json({ error: 'Agora credentials not configured' });
    }

    // Use provided uid or default to 0 (will be assigned by Agora)
    let userUid = 0;
    if (uid !== undefined && uid !== null) {
      userUid = parseInt(uid);
      if (isNaN(userUid)) userUid = 0;
    }
    
    // Token expiry time (1 hour from now - increased for stability)
    const expirationTimeInSeconds = config.agora.tokenExpirySeconds || 3600;
    const currentTimestamp = Math.floor(Date.now() / 1000);
    const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

    console.log(`[AGORA] Generating token with: appId=${appId.substring(0, 5)}..., cert=${appCertificate ? 'YES' : 'NO'}, channel=${channel_name}, uid=${userUid}, expiry=${expirationTimeInSeconds}s`);

    // Build token with uid
    let token;
    try {
      console.log('[AGORA] Calling RtcTokenBuilder.buildTokenWithUid...');
      token = RtcTokenBuilder.buildTokenWithUid(
        appId,
        appCertificate,
        channel_name,
        userUid,
        RtcRole.PUBLISHER,
        privilegeExpiredTs
      );
      console.log('[AGORA] Token builder success');
    } catch (buildError) {
      console.error('[AGORA] buildTokenWithUid failed with error:', buildError);
      console.error('[AGORA] Error stack:', buildError.stack);
      return res.status(500).json({ 
        error: 'Failed to build Agora token', 
        details: buildError.message,
        stack: buildError.stack
      });
    }

    if (!token) {
      console.error('[AGORA] Token builder returned empty token');
      return res.status(500).json({ error: 'Generated token is empty' });
    }

    console.log('[AGORA] Token generated successfully');

    res.json({
      token,
      channel_name,
      uid: userUid,
      expires_at: new Date(privilegeExpiredTs * 1000).toISOString()
    });
  } catch (error) {
    console.error('[AGORA] Fatal error generating Agora token:', error);
    res.status(500).json({ 
      error: 'Failed to generate Agora token',
      details: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

export default router;
