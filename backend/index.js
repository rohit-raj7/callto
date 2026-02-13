import express from 'express';
import http from 'http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import config from './config/config.js';
import { testConnection, ensureSchema, pool, getRateConfig } from './db.js';
// Initialize Express app
const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: config.cors,
  pingTimeout: config.socketIO.pingTimeout,
  pingInterval: config.socketIO.pingInterval
});

// Import routes
import authRoutes from './routes/auth.js';
import userRoutes from './routes/users.js';
import listenerRoutes from './routes/listeners.js';
import callRoutes from './routes/calls.js';
import createChatsRouter from './routes/chats.js';
import adminRoutes from './routes/admin.js';
import contactRoutes from './routes/contacts.js';
import notificationsRoutes from './routes/notifications.js';
import accountRoutes from './routes/account.js';
import paymentRoutes from './routes/payments.js';
import ratingRoutes from './routes/ratings.js';
import rechargePackRoutes from './routes/rechargePacks.js';
import User from './models/User.js';
import Listener from './models/Listener.js'; // Import for verification checks
import Call from './models/Call.js';
import { markCallStarted, calculateMaxCallDuration, finalizeCallBilling as billingFinalize } from './services/callBillingService.js';
import { Chat, Message } from './models/Chat.js';
import ChatChargeConfig from './models/ChatChargeConfig.js';
import { sendPushFCM } from './utils/fcm.js';
import NotificationOutbox from './models/NotificationOutbox.js';
import NotificationDelivery from './models/NotificationDelivery.js';

// ============================================
// MIDDLEWARE
// ============================================

// Security middleware
app.use(helmet());

// CORS
app.use(cors(config.cors));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Compression
app.use(compression());

// Logging
if (config.NODE_ENV === 'development') {
  app.use(morgan('dev'));
} else {
  app.use(morgan('combined'));
}

// Rate limiting — general (generous for mobile retries & socket reconnects)
const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.max,
  standardHeaders: true,  // Send RateLimit-* headers so clients know remaining quota
  legacyHeaders: false,   // Disable X-RateLimit-* (deprecated)
  message: { error: 'Too many requests from this IP, please try again later.' }
});
app.use('/api/', limiter);

// Stricter rate limit for auth endpoints (login, OTP, register)
const authLimiter = rateLimit({
  windowMs: config.authRateLimit.windowMs,
  max: config.authRateLimit.max,
  standardHeaders: true,
  legacyHeaders: false,
  message: { error: 'Too many login attempts. Please try again after some time.' }
});
app.use('/api/auth/', authLimiter);

// ============================================
// ROUTES
// ============================================

// Health check
app.get('/', (req, res) => {
  res.json({
    message: 'Call To API Server',
    version: '1.0.0',
    status: 'running'
  });
});

// API health check
app.get('/api/health', async (req, res) => {
  try {
    const dbConnected = await testConnection();
    res.json({
      status: 'healthy',
      database: dbConnected ? 'connected' : 'disconnected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(500).json({
      status: 'unhealthy',
      error: error.message
    });
  }
});

app.get('/api/config/call-rates', async (req, res) => {
  try {
    const rateConfig = await getRateConfig();
    res.json({
      normalPerMinuteRate: Number(rateConfig.normal_per_minute_rate),
      firstTimeOfferEnabled: rateConfig.first_time_offer_enabled === true,
      offerMinutesLimit: rateConfig.offer_minutes_limit,
      offerFlatPrice: rateConfig.offer_flat_price
    });
  } catch (error) {
    console.error('Get call rates error:', error);
    res.status(500).json({ error: 'Failed to fetch call rates' });
  }
});

// Mount API routes
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/listeners', listenerRoutes);
app.use('/api/calls', callRoutes);
app.use('/api/chats', createChatsRouter(io)); // Pass io for real-time message delivery
app.use('/api/admin', adminRoutes);
app.use('/api/contacts', contactRoutes);
app.use('/api/notifications', notificationsRoutes);
app.use('/api/account', accountRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/ratings', ratingRoutes);
app.use('/api/recharge-packs', rechargePackRoutes);

// ============================================
// SOCKET.IO - REAL-TIME FEATURES
// ============================================



// In-memory maps
const connectedUsers = new Map(); // Map of userId -> socketId
const listenerSockets = new Map(); // Map of listenerUserId -> socketId
const activeChannels = new Map(); // Map of channelName -> Set of userIds in channel
const lastSeenMap = new Map(); // Map of userId -> timestamp
const presenceTimeouts = new Map(); // Map of userId -> timeoutId
const busyListeners = new Map(); // Map of listenerUserId -> callId (in-memory busy tracking)
const pendingCalls = new Map(); // Map of callId -> { callerId, listenerId, listenerSocketId, createdAt } (tracks pre-answer calls for cancel routing)
const activeCallTimers = new Map(); // Map of callId -> { timerId, callerId, listenerUserId, channelName, startedAt, maxAllowedSeconds }
const processingCalls = new Set(); // Dedup guard: callIds currently being set up in call:joined handler

// Stale pendingCalls cleanup: remove entries older than 60 seconds
setInterval(() => {
  const now = Date.now();
  for (const [callId, pending] of pendingCalls.entries()) {
    if (now - pending.createdAt > 60000) {
      console.log(`[SOCKET] Stale pendingCall ${callId} removed (age: ${Math.round((now - pending.createdAt) / 1000)}s)`);
      pendingCalls.delete(callId);
    }
  }
}, 30000);

// Stale active call timer cleanup: safety net for calls whose timers were lost
// Checks every 5 minutes for any activeCallTimers older than maxAllowedSeconds + 60s
setInterval(() => {
  const now = Date.now();
  for (const [callId, timer] of activeCallTimers.entries()) {
    const elapsed = (now - timer.startedAt) / 1000;
    const maxWithGrace = timer.maxAllowedSeconds + 60;
    if (elapsed > maxWithGrace) {
      console.log(`[SOCKET] Stale activeCallTimer ${callId} removed (elapsed: ${Math.round(elapsed)}s > max: ${maxWithGrace}s)`);
      clearTimeout(timer.timerId);
      activeCallTimers.delete(callId);
      // Trigger billing as safety net
      (async () => {
        try {
          const billDuration = Math.min(Math.round(elapsed), timer.maxAllowedSeconds);
          await billingFinalize({ callId, durationSeconds: billDuration });
          console.log(`[SOCKET] Stale call ${callId}: safety billing completed (${billDuration}s)`);
        } catch (e) {
          console.error(`[SOCKET] Stale call ${callId}: safety billing error:`, e.message);
        }
      })();
    }
  }
}, 300000);

// WhatsApp-style chat state tracking
const userChatState = new Map(); // Map of userId -> { activelyViewingChatId, appState: 'foreground'|'background' }

// Socket.IO connection handler
io.on('connection', (socket) => {
  console.log(`[SOCKET] Connected: ${socket.id}`);

  // Helper: Clear busy status for a user (checks both parties)
  function _clearBusyForCall(userId1, userId2) {
    for (const uid of [userId1, userId2]) {
      if (uid && busyListeners.has(uid)) {
        busyListeners.delete(uid);
        io.emit('listener_busy_status', { listenerUserId: uid, busy: false });
        console.log(`[SOCKET] _clearBusyForCall: Listener ${uid} marked NOT BUSY`);
        // Also clear in DB (fire-and-forget)
        Listener.clearBusyByUserId(uid).catch(e => console.error('[SOCKET] clearBusyByUserId DB error:', e.message));
      }
    }
  }

  // 1. IDENTITY & PRESENCE
  
  // User joins (can be regular user or listener)
  socket.on('user:join', (data) => {
    // Support both old format (just userId string) and new format (object with userId, userName, avatar)
    let userId, userName, userAvatar, activelyViewingChatId;
    if (typeof data === 'string') {
      userId = data;
    } else if (data && typeof data === 'object') {
      userId = data.userId;
      userName = data.userName;
      userAvatar = data.userAvatar;
      activelyViewingChatId = data.activelyViewingChatId; // WhatsApp-style: which chat is open
    }
    
    if (!userId) return;
    socket.userId = userId;
    socket.userName = userName || 'Unknown';
    socket.userAvatar = userAvatar;
    connectedUsers.set(userId, socket.id);
    lastSeenMap.set(userId, Date.now());
    
    // Initialize or update user chat state (WhatsApp-style tracking)
    userChatState.set(userId, {
      activelyViewingChatId: activelyViewingChatId || null,
      appState: 'foreground'
    });
    
    // Join user's personal room for notifications
    socket.join(`user_${userId}`);
    console.log(`[SOCKET] User ${userId} joined personal room: user_${userId}`);
    
    // Clear any pending offline timeout
    if (presenceTimeouts.has(userId)) {
      clearTimeout(presenceTimeouts.get(userId));
      presenceTimeouts.delete(userId);
    }
    
    io.emit('user:online', { userId });
    console.log(`[SOCKET] User joined: ${userId} (${userName || 'unknown name'}), activeChat: ${activelyViewingChatId || 'none'}`);

    // Send current online listeners to the newly joined user
    const onlineListeners = Array.from(listenerSockets.keys());
    socket.emit('listeners:initial_status', onlineListeners);
  });

  // Listener specific join (for availability tracking)
  // CRITICAL: This is what makes a listener available to receive calls
  // Must be emitted when listener app is open (any page)
  socket.on('listener:join', (listenerUserId) => {
    if (!listenerUserId) return;
    socket.userId = listenerUserId; // Sync with userId
    socket.listenerUserId = listenerUserId;
    
    // Remove old socket if exists to prevent ghost sessions
    if (listenerSockets.has(listenerUserId)) {
      const oldSocketId = listenerSockets.get(listenerUserId);
      if (oldSocketId && oldSocketId !== socket.id) {
        console.log(`[SOCKET] listener:join: Removing old socket ${oldSocketId} for listener ${listenerUserId}`);
        const oldSocket = io.sockets.sockets.get(oldSocketId);
        if (oldSocket) oldSocket.disconnect(true);
      }
    }
    
    // Register listener as available for calls
    listenerSockets.set(listenerUserId, socket.id);
    connectedUsers.set(listenerUserId, socket.id); // Also ensure in connectedUsers
    
    io.emit('listener_status', { listenerUserId, online: true, timestamp: Date.now() });
    console.log(`[SOCKET] listener:join: ✓ Listener ${listenerUserId} is now ONLINE (socket: ${socket.id})`);
    console.log(`[SOCKET] listener:join: Total online listeners: ${listenerSockets.size}`);
  });

  // Explicit offline event - listener manually going offline
  // NOTE: This should only be called when listener explicitly goes offline,
  // NOT when navigating between pages in the app
  socket.on('listener:offline', (data) => {
    const { listenerUserId } = data || {};
    if (listenerUserId) {
      listenerSockets.delete(listenerUserId);
      io.emit('listener_status', { listenerUserId, online: false, timestamp: Date.now() });
      console.log(`[SOCKET] listener:offline: ✓ Listener ${listenerUserId} manually went OFFLINE`);
    }
  });

  // 2. CALL HANDLING

  // Initiate call: User -> Listener
  // CRITICAL: This checks if listener is online by looking for their socket
  // Listener is online if they have an entry in listenerSockets OR connectedUsers
  socket.on('call:initiate', async (data) => {
    const { listenerId, ...callData } = data || {};
    
    // Check both maps for the listener's socket
    const listenerSocketId = listenerSockets.get(listenerId) || connectedUsers.get(listenerId);
    
    console.log(`[SOCKET] call:initiate: Looking for listener ${listenerId}`);
    console.log(`[SOCKET] call:initiate: Found socketId: ${listenerSocketId || 'NONE'}`);
    
    if (!listenerSocketId) {
      // Listener is not connected — notify caller immediately
      console.log(`[SOCKET] call:initiate: ✗ Listener ${listenerId} NOT online (no socket found)`);
      socket.emit('call:failed', { callId: callData.callId, reason: 'listener_offline' });
      return;
    }

    // BUSY CHECK: If listener is already in an active call, notify caller
    if (busyListeners.has(listenerId)) {
      console.log(`[SOCKET] call:initiate: ✗ Listener ${listenerId} is BUSY (active call: ${busyListeners.get(listenerId)})`);
      socket.emit('call:busy', {
        callId: callData.callId,
        listenerId,
        reason: 'listener_busy',
        message: 'Listener is busy on another call'
      });
      return;
    }

    // Track this pending call so we can route cancel events to listener
    if (callData.callId) {
      pendingCalls.set(callData.callId, {
        callerId: socket.userId,
        listenerId,
        listenerSocketId,
        createdAt: Date.now(),
      });
      console.log(`[SOCKET] call:initiate: Tracking pending call ${callData.callId}`);
    }

    // Forward incoming-call to listener IMMEDIATELY (don't block on DB)
    io.to(listenerSocketId).emit('incoming-call', callData);
    console.log(`[SOCKET] call:initiate: ✓ Forwarded to listener ${listenerId} (socket: ${listenerSocketId})`);

    // THEN verify in background — if not approved, cancel the call
    try {
      const listener = await Listener.findByUserId(listenerId);
      if (listener) {
        const verificationStatus = listener.verification_status || 'approved';
        if (verificationStatus !== 'approved') {
          console.log(`[SOCKET] call:initiate blocked: Listener ${listenerId} not approved (status: ${verificationStatus})`);
          // Notify caller that call failed
          socket.emit('call:failed', { 
            callId: callData.callId, 
            reason: 'listener_not_approved',
            message: 'Listener not approved yet'
          });
          // Also cancel the incoming call on the listener side
          io.to(listenerSocketId).emit('call:ended', {
            callId: callData.callId,
            reason: 'cancelled',
            code: 'VERIFICATION_FAILED'
          });
          return;
        }
      }
    } catch (err) {
      console.error(`[SOCKET] call:initiate verification check failed:`, err);
      // Don't fail the call for a verification check error — call was already forwarded
    }
  });

  // Accept call: Listener -> User
  socket.on('call:accept', (data) => {
    const { callId, callerId } = data;
    console.log(`[SOCKET] call:accept: Call ${callId} accepted by ${socket.userId}`);
    
    // Remove from pending calls — no longer cancellable
    pendingCalls.delete(callId);
    
    // BUSY: Mark listener as busy in memory
    if (socket.userId) {
      busyListeners.set(socket.userId, callId);
      io.emit('listener_busy_status', { listenerUserId: socket.userId, busy: true });
      console.log(`[SOCKET] call:accept: Listener ${socket.userId} marked BUSY`);
      // Also set in DB (fire-and-forget)
      Listener.findByUserId(socket.userId).then(l => {
        if (l) Listener.setBusy(l.listener_id).catch(e => console.error('[SOCKET] setBusy DB error:', e.message));
      }).catch(e => console.error('[SOCKET] findByUserId for setBusy error:', e.message));
    }
    
    const callerSocketId = connectedUsers.get(callerId);
    if (callerSocketId) {
      io.to(callerSocketId).emit('call:accepted', {
        callId,
        listenerId: socket.userId
      });
    }
  });

  // Reject call: Listener -> User
  socket.on('call:reject', (data) => {
    const { callId, callerId } = data;
    console.log(`[SOCKET] call:reject: Call ${callId} rejected by ${socket.userId}`);
    
    // Remove from pending calls
    pendingCalls.delete(callId);
    
    const callerSocketId = connectedUsers.get(callerId);
    if (callerSocketId) {
      io.to(callerSocketId).emit('call:rejected', {
        callId,
        listenerId: socket.userId
      });
    }
  });

  // Joined Agora channel (for both parties)
  socket.on('call:joined', (data) => {
    const { callId, channelName } = data;
    const userId = socket.userId;
    if (!userId) return;

    console.log(`[SOCKET] User ${userId} joined channel ${channelName}`);
    
    if (!activeChannels.has(channelName)) {
      activeChannels.set(channelName, new Set());
    }
    activeChannels.get(channelName).add(userId);
    
    const usersInChannel = activeChannels.get(channelName);
    if (usersInChannel.size >= 2 && callId) {
      // Dedup: prevent double execution when both parties race to this point
      // (both call:joined events can see size >= 2 near-simultaneously)
      if (activeCallTimers.has(callId) || processingCalls.has(String(callId))) {
        console.log(`[SOCKET] call:joined: Call ${callId} already tracked/processing, skipping duplicate`);
        return;
      }
      processingCalls.add(String(callId));

      console.log(`[SOCKET] Both parties in ${channelName}, starting server-tracked call ${callId}`);

      // Snapshot channel users for use in async callback / timer
      const channelUsers = new Set(usersInChannel);

      // Server-authoritative call start: mark started_at and calculate max duration
      (async () => {
        try {
          const callData = await markCallStarted(callId);
          if (!callData) {
            console.error(`[SOCKET] Failed to mark call ${callId} as started`);
            channelUsers.forEach(uid => {
              const sid = connectedUsers.get(uid);
              if (sid) io.to(sid).emit('call:connected', { callId, channelName, maxAllowedSeconds: 0 });
            });
            return;
          }

          const rate = Number(callData.rate_per_minute || 0);
          const { maxAllowedSeconds, balance } = await calculateMaxCallDuration(callData.caller_id, rate);

          console.log(`[SOCKET] Call ${callId}: rate=\u20b9${rate}/min, balance=\u20b9${balance}, maxAllowed=${maxAllowedSeconds}s`);

          // Emit call:connected with max duration to both parties
          channelUsers.forEach(uid => {
            const sid = connectedUsers.get(uid);
            if (sid) {
              io.to(sid).emit('call:connected', {
                callId,
                channelName,
                maxAllowedSeconds,
                ratePerMinute: rate
              });
            }
          });

          // Server-side auto-disconnect timer
          if (maxAllowedSeconds > 0) {
            // Add 3-second grace period for network latency
            const timerMs = (maxAllowedSeconds + 3) * 1000;
            const timerId = setTimeout(async () => {
              console.log(`[SOCKET] Call ${callId}: max duration reached (${maxAllowedSeconds}s), auto-ending`);
              activeCallTimers.delete(callId);

              // Notify both parties to disconnect
              channelUsers.forEach(uid => {
                const sid = connectedUsers.get(uid);
                if (sid) {
                  io.to(sid).emit('call:ended', {
                    callId,
                    channelName,
                    reason: 'balance_exhausted',
                    code: 'MAX_DURATION_REACHED'
                  });
                }
              });

              // Trigger billing from server as safety net
              try {
                await billingFinalize({ callId, durationSeconds: maxAllowedSeconds });
                console.log(`[SOCKET] Call ${callId}: server-triggered billing completed`);
              } catch (billingErr) {
                console.error(`[SOCKET] Call ${callId}: server-triggered billing error:`, billingErr.message);
              }

              // Clear busy status for both parties
              channelUsers.forEach(uid => {
                if (busyListeners.has(uid)) {
                  busyListeners.delete(uid);
                  io.emit('listener_busy_status', { listenerUserId: uid, busy: false });
                  Listener.clearBusyByUserId(uid).catch(e => console.error('[SOCKET] clearBusy timer error:', e.message));
                }
              });

              // Clean up channel
              activeChannels.delete(channelName);
            }, timerMs);

            // Find listener's userId from channel participants (not the caller)
            const listenerUserId = [...channelUsers].find(uid => String(uid) !== String(callData.caller_id)) || null;

            activeCallTimers.set(callId, {
              timerId,
              callerId: callData.caller_id,
              listenerUserId,
              channelName,
              startedAt: Date.now(),
              maxAllowedSeconds
            });
            console.log(`[SOCKET] Call ${callId}: auto-disconnect timer set for ${maxAllowedSeconds + 3}s`);
          } else {
            // Zero balance — disconnect immediately
            console.log(`[SOCKET] Call ${callId}: zero allowed duration, disconnecting immediately`);
            channelUsers.forEach(uid => {
              const sid = connectedUsers.get(uid);
              if (sid) {
                io.to(sid).emit('call:ended', {
                  callId,
                  channelName,
                  reason: 'balance_exhausted',
                  code: 'ZERO_BALANCE'
                });
              }
            });
          }
        } catch (err) {
          console.error(`[SOCKET] Error in call:joined handler for call ${callId}:`, err);
          // Still emit call:connected without max duration as fallback
          channelUsers.forEach(uid => {
            const sid = connectedUsers.get(uid);
            if (sid) io.to(sid).emit('call:connected', { callId, channelName, maxAllowedSeconds: 0 });
          });
        } finally {
          processingCalls.delete(String(callId));
        }
      })();
    }
  });

  // End call
  socket.on('call:end', (data) => {
    const { callId, otherUserId } = data;
    console.log(`[SOCKET] call:end: Call ${callId} ended by ${socket.userId}`);
    
    // Clear server-side auto-disconnect timer & capture data for safety billing
    let endTimerData = null;
    if (callId && activeCallTimers.has(callId)) {
      endTimerData = activeCallTimers.get(callId);
      clearTimeout(endTimerData.timerId);
      activeCallTimers.delete(callId);
      console.log(`[SOCKET] call:end: Cleared auto-disconnect timer for call ${callId}`);
    }
    
    // BUSY: Clear busy for both parties (whichever is the listener)
    _clearBusyForCall(socket.userId, otherUserId);
    
    // 1. Try direct otherUserId path (for connected calls)
    const otherSocketId = connectedUsers.get(otherUserId);
    if (otherSocketId) {
      io.to(otherSocketId).emit('call:ended', {
        callId,
        endedBy: socket.userId,
        reason: 'caller_cancelled'
      });
    }
    
    // 2. Check pendingCalls — caller cancelled BEFORE listener answered
    const pending = pendingCalls.get(callId);
    if (pending) {
      pendingCalls.delete(callId);
      // Notify listener via their socket (may differ from otherUserId lookup)
      const listenerSid = listenerSockets.get(pending.listenerId) || connectedUsers.get(pending.listenerId);
      if (listenerSid && listenerSid !== otherSocketId) {
        io.to(listenerSid).emit('call:ended', {
          callId,
          endedBy: socket.userId,
          reason: 'caller_cancelled'
        });
      }
      console.log(`[SOCKET] call:end: Cancelled pending call ${callId}, notified listener ${pending.listenerId}`);
    }

    // 3. Safety billing: ensure billing happens even if frontend POST /api/calls/end fails
    //    billingFinalize is idempotent (checks call_records for existing billing)
    if (callId && endTimerData) {
      (async () => {
        try {
          const elapsed = Math.max(0, Math.round((Date.now() - endTimerData.startedAt) / 1000));
          const billDuration = Math.min(elapsed, endTimerData.maxAllowedSeconds);
          if (billDuration > 0) {
            await billingFinalize({ callId, durationSeconds: billDuration });
            console.log(`[SOCKET] call:end: Safety billing for call ${callId} (${billDuration}s)`);
          }
        } catch (e) {
          console.error(`[SOCKET] call:end: Safety billing error for call ${callId}:`, e.message);
        }
      })();
    }
  });

  // Leave channel
  socket.on('call:left', (data) => {
    const { channelName } = data;
    if (activeChannels.has(channelName) && socket.userId) {
      activeChannels.get(channelName).delete(socket.userId);
      if (activeChannels.get(channelName).size === 0) {
        activeChannels.delete(channelName);
      }
    }
  });

  // ============================================
  // 2.5 CHAT HANDLING (Real-time messaging)
  // ============================================

  // Join a chat room
  socket.on('chat:join', async (data) => {
    const { chatId, isActivelyViewing = true } = data || {};
    if (!chatId || !socket.userId) {
      console.log(`[SOCKET] chat:join failed - missing chatId or userId`);
      return;
    }

    // Join the Socket.IO room for this chat
    socket.join(`chat_${chatId}`);
    socket.chatRooms = socket.chatRooms || new Set();
    socket.chatRooms.add(chatId);
    
    // WhatsApp-style: Track which chat user is actively viewing
    if (isActivelyViewing) {
      const state = userChatState.get(socket.userId) || { appState: 'foreground' };
      state.activelyViewingChatId = chatId;
      userChatState.set(socket.userId, state);
    }
    
    console.log(`[SOCKET] User ${socket.userId} joined chat room: ${chatId} (activelyViewing: ${isActivelyViewing})`);

    // Fetch and send chat history
    try {
      const messages = await Message.getChatMessages(chatId, 50, 0);
      // FIX: Ensure all message timestamps are UTC ISO strings for consistent client parsing
      const normalizedMessages = messages.map(msg => ({
        ...msg,
        created_at: msg.created_at instanceof Date
          ? msg.created_at.toISOString()
          : msg.created_at,
        read_at: msg.read_at instanceof Date
          ? msg.read_at.toISOString()
          : msg.read_at,
      }));
      socket.emit('chat:history', {
        chatId,
        messages: normalizedMessages,
        count: normalizedMessages.length
      });
    } catch (error) {
      console.error(`[SOCKET] Error fetching chat history:`, error);
      socket.emit('chat:error', { error: 'Failed to fetch chat history' });
    }
  });

  // Leave a chat room
  socket.on('chat:leave', (data) => {
    const { chatId } = data || {};
    if (!chatId) return;

    socket.leave(`chat_${chatId}`);
    if (socket.chatRooms) {
      socket.chatRooms.delete(chatId);
    }
    
    // WhatsApp-style: Clear actively viewing state
    const state = userChatState.get(socket.userId);
    if (state && state.activelyViewingChatId === chatId) {
      state.activelyViewingChatId = null;
      userChatState.set(socket.userId, state);
    }
    
    console.log(`[SOCKET] User ${socket.userId} left chat room: ${chatId}`);
  });

  // WhatsApp-style: Update which chat user is actively viewing
  socket.on('chat:set_active_viewing', (data) => {
    const { chatId, isActivelyViewing } = data || {};
    if (!socket.userId) return;
    
    const state = userChatState.get(socket.userId) || { appState: 'foreground' };
    state.activelyViewingChatId = isActivelyViewing ? chatId : null;
    userChatState.set(socket.userId, state);
    
    console.log(`[SOCKET] User ${socket.userId} set actively viewing: ${chatId || 'none'}`);
  });

  // WhatsApp-style: Track app foreground/background state
  socket.on('user:app_state', (data) => {
    const { userId, state: appState, activelyViewingChatId } = data || {};
    if (!userId) return;
    
    const chatState = userChatState.get(userId) || {};
    chatState.appState = appState || 'foreground';
    
    // Also update actively viewing chat if provided
    if (appState === 'background') {
      chatState.activelyViewingChatId = null; // Not viewing any chat when in background
    } else if (activelyViewingChatId !== undefined) {
      chatState.activelyViewingChatId = activelyViewingChatId;
    }
    
    userChatState.set(userId, chatState);
    console.log(`[SOCKET] User ${userId} app state: ${appState}, activeChat: ${chatState.activelyViewingChatId || 'none'}`);
  });

  // Send a message in a chat
  socket.on('chat:send', async (data) => {
    const { chatId, content, messageType = 'text', mediaUrl } = data || {};
    
    if (!chatId || !content || !socket.userId) {
      console.log(`[SOCKET] chat:send failed - missing required fields`);
      socket.emit('chat:error', { error: 'Missing required fields' });
      return;
    }

    try {
      const chat = await Chat.findById(chatId);
      if (!chat) {
        socket.emit('chat:error', { error: 'Chat not found' });
        return;
      }

      if (chat.user1_id !== socket.userId && chat.user2_id !== socket.userId) {
        socket.emit('chat:error', { error: 'Forbidden' });
        return;
      }

      const otherUserId = chat.user1_id === socket.userId ? chat.user2_id : chat.user1_id;

      // CHAT CHARGING: Check if user should be charged for this message
      // Uses GLOBAL per-user counters (not per-chat) — survives chat clear/delete
      try {
        const chargeResult = await ChatChargeConfig.checkAndCharge(socket.userId);
        if (!chargeResult.allowed) {
          console.log(`[SOCKET] Message blocked for user ${socket.userId}: ${chargeResult.reason}`);
          socket.emit('chat:error', {
            status: 'failed',
            message: chargeResult.message || 'Insufficient balance. Please recharge.',
            code: chargeResult.reason || 'LOW_BALANCE',
            remainingFreeMessages: chargeResult.remainingFreeMessages ?? 0,
            totalMessagesSent: chargeResult.totalMessagesSent ?? 0
          });
          return;
        }
        if (chargeResult.charged) {
          console.log(`[SOCKET] Charged user ${socket.userId} ₹${chargeResult.chargeAmount} for chat message`);
        }
      } catch (chargeError) {
        console.error('[SOCKET] Chat charge check error:', chargeError);
        // On charging system error, allow message through (fail-open)
      }

      // Save message to database (Chat & Message already imported at module level)
      const message = await Message.create({
        chat_id: chatId,
        sender_id: socket.userId,
        message_type: messageType,
        message_content: content,
        media_url: mediaUrl
      });

      // Look up sender's display info from DB (prefer listener profile over Google data)
      let senderName = socket.userName || 'Unknown';
      let senderAvatar = socket.userAvatar;
      try {
        const senderInfoResult = await pool.query(
          `SELECT COALESCE(l.professional_name, u.display_name) as sender_name,
                  COALESCE(l.profile_image, u.avatar_url) as sender_avatar
           FROM users u
           LEFT JOIN listeners l ON u.user_id = l.user_id
           WHERE u.user_id = $1`,
          [socket.userId]
        );
        if (senderInfoResult.rows.length > 0) {
          senderName = senderInfoResult.rows[0].sender_name || senderName;
          senderAvatar = senderInfoResult.rows[0].sender_avatar || senderAvatar;
        }
      } catch (lookupErr) {
        console.error('[SOCKET] Sender info lookup failed, using socket data:', lookupErr.message);
      }

      const messageData = {
        chatId,
        message: {
          ...message,
          // FIX: Ensure created_at is always a UTC ISO string for consistent client parsing
          // The pg type parser in db.js now returns ISO strings, but this is defense-in-depth
          created_at: message.created_at instanceof Date
            ? message.created_at.toISOString()
            : message.created_at,
          sender_name: senderName,
          sender_avatar: senderAvatar
        }
      };

      // Broadcast message to all users in the chat room IMMEDIATELY (real-time UI update)
      console.log(`[SOCKET] chat:send timestamp debug: raw=${message.created_at}, type=${typeof message.created_at}, isDate=${message.created_at instanceof Date}, final=${messageData.message.created_at}`);
      io.to(`chat_${chatId}`).emit('chat:message', messageData);

      // Send notification to offline/non-viewing users asynchronously (don't block)
      Promise.resolve(chat).then(chatData => {
        if (chatData) {
          const otherUserState = userChatState.get(otherUserId);
          
          const isOtherUserViewingThisChat = otherUserState && 
            otherUserState.appState === 'foreground' && 
            otherUserState.activelyViewingChatId === chatId;
          
          if (!isOtherUserViewingThisChat) {
            io.to(`user_${otherUserId}`).emit('chat:new_message_notification', messageData);
            console.log(`[SOCKET] Sent notification to user_${otherUserId}`);
          }
        }
      }).catch(err => console.error('[SOCKET] Notification error:', err));

      console.log(`[SOCKET] Message sent in chat ${chatId} by ${socket.userId}`);
    } catch (error) {
      console.error(`[SOCKET] Error sending message:`, error.message || error);
      console.error(`[SOCKET] Error stack:`, error.stack);
      socket.emit('chat:error', { error: `Failed to send message: ${error.message || 'Unknown error'}` });
    }
  });

  // Typing indicator
  socket.on('chat:typing', (data) => {
    const { chatId, isTyping } = data || {};
    if (!chatId || !socket.userId) return;

    // Broadcast typing status to others in the chat room (not the sender)
    socket.to(`chat_${chatId}`).emit('chat:user_typing', {
      chatId,
      userId: socket.userId,
      userName: socket.userName || 'Unknown',
      isTyping: isTyping === true
    });
  });

  // Mark messages as read
  socket.on('chat:read', async (data) => {
    const { chatId } = data || {};
    if (!chatId || !socket.userId) return;

    try {
      await Message.markAsRead(chatId, socket.userId);
      
      // Notify the other user that messages were read
      socket.to(`chat_${chatId}`).emit('chat:messages_read', {
        chatId,
        readBy: socket.userId
      });
    } catch (error) {
      console.error(`[SOCKET] Error marking messages as read:`, error);
    }
  });

  // WhatsApp-style: Delete message for everyone
  // This permanently deletes from DB and broadcasts to both users
  // Backend does NOT store placeholder text - that's client-side only
  socket.on('delete_message', async (data) => {
    const { messageId, chatId, senderId, receiverId } = data || {};
    
    if (!messageId || !senderId) {
      console.log(`[SOCKET] delete_message failed - missing messageId or senderId`);
      socket.emit('chat:error', { error: 'Missing required fields for delete' });
      return;
    }

    try {
      // Delete message from database (validates sender ownership)
      const result = await Message.delete(messageId, senderId);
      
      if (!result.success) {
        console.log(`[SOCKET] delete_message failed: ${result.error}`);
        socket.emit('chat:error', { error: result.error });
        return;
      }

      console.log(`[SOCKET] Message ${messageId} deleted from DB by ${senderId}`);

      // Broadcast delete event to all users in the chat room
      // Both sender and receiver will save this locally and show placeholder
      const deleteData = {
        messageId,
        chatId: result.chatId || chatId,
        deletedBy: senderId
      };

      // Emit to chat room (for users currently in the chat)
      io.to(`chat_${chatId}`).emit('message:deleted', deleteData);
      
      // Also emit to both users' personal rooms (in case they're not in chat room)
      io.to(`user_${senderId}`).emit('message:deleted', deleteData);
      if (receiverId) {
        io.to(`user_${receiverId}`).emit('message:deleted', deleteData);
      }

      console.log(`[SOCKET] Delete event broadcast for message ${messageId}`);
    } catch (error) {
      console.error(`[SOCKET] Error deleting message:`, error);
      socket.emit('chat:error', { error: 'Failed to delete message' });
    }
  });

  // 3. DISCONNECTION

  socket.on('disconnect', () => {
    const userId = socket.userId;
    const listenerUserId = socket.listenerUserId;

    console.log(`[SOCKET] Disconnected: ${socket.id} (User: ${userId}, Listener: ${listenerUserId})`);

    // Clear any active call timers for this user's calls (matches both caller and listener)
    for (const [callId, timerData] of activeCallTimers.entries()) {
      const isCaller = String(timerData.callerId) === String(userId);
      const isListener = timerData.listenerUserId && String(timerData.listenerUserId) === String(userId);
      if (isCaller || isListener) {
        clearTimeout(timerData.timerId);
        activeCallTimers.delete(callId);
        console.log(`[SOCKET] disconnect: Cleared timer for call ${callId} (${isCaller ? 'caller' : 'listener'} disconnected)`);
        // Trigger billing safety net for disconnected calls
        (async () => {
          try {
            const elapsed = Math.max(0, Math.round((Date.now() - timerData.startedAt) / 1000));
            const billDuration = Math.min(elapsed, timerData.maxAllowedSeconds);
            if (billDuration > 0) {
              await billingFinalize({ callId, durationSeconds: billDuration });
              console.log(`[SOCKET] disconnect: Safety billing for call ${callId} (${billDuration}s)`);
            }
          } catch (e) {
            console.error(`[SOCKET] disconnect: Safety billing error for call ${callId}:`, e.message);
          }
        })();
      }
    }

    // Handle listener cleanup
    if (listenerUserId && listenerSockets.get(listenerUserId) === socket.id) {
      listenerSockets.delete(listenerUserId);
      io.emit('listener_status', { listenerUserId, online: false, timestamp: Date.now() });
      console.log(`[SOCKET] Listener marked offline: ${listenerUserId}`);
      
      // BUSY: Clear busy on disconnect (safety net)
      if (busyListeners.has(listenerUserId)) {
        busyListeners.delete(listenerUserId);
        io.emit('listener_busy_status', { listenerUserId, busy: false });
        console.log(`[SOCKET] Listener ${listenerUserId} busy cleared on disconnect`);
        Listener.clearBusyByUserId(listenerUserId).catch(e => console.error('[SOCKET] clearBusyByUserId on disconnect error:', e.message));
      }
    }

    // Handle user cleanup and active calls
    if (userId) {
      // BUSY: Clear busy if this userId is a busy listener (covers both listenerUserId and userId)
      if (busyListeners.has(userId)) {
        busyListeners.delete(userId);
        io.emit('listener_busy_status', { listenerUserId: userId, busy: false });
        console.log(`[SOCKET] User ${userId} busy cleared on disconnect (userId path)`);
        Listener.clearBusyByUserId(userId).catch(e => console.error('[SOCKET] clearBusyByUserId on disconnect error:', e.message));
      }

      // PENDING CALLS: If this user was a caller who disconnected during ringing,
      // notify the listener and clean up
      for (const [callId, pending] of pendingCalls.entries()) {
        if (String(pending.callerId) === String(userId)) {
          console.log(`[SOCKET] Caller ${userId} disconnected during pending call ${callId}, notifying listener`);
          if (pending.listenerSocketId) {
            io.to(pending.listenerSocketId).emit('call:ended', {
              callId,
              endedBy: userId,
              reason: 'caller_disconnected'
            });
          }
          pendingCalls.delete(callId);
        }
      }

      // Notify others in active channels
      for (const [channelName, users] of activeChannels.entries()) {
        if (users.has(userId)) {
          users.forEach(otherUid => {
            if (otherUid !== userId) {
              const otherSid = connectedUsers.get(otherUid);
              if (otherSid) {
                io.to(otherSid).emit('call:ended', {
                  callId: channelName,
                  endedBy: userId,
                  reason: 'peer_disconnected'
                });
              }
            }
          });
          users.delete(userId);
          if (users.size === 0) activeChannels.delete(channelName);
        }
      }

      // Debounce offline status
      if (presenceTimeouts.has(userId)) {
        clearTimeout(presenceTimeouts.get(userId));
      }
      
      const timeoutId = setTimeout(async () => {
        const lastSeen = lastSeenMap.get(userId) || 0;
        if (Date.now() - lastSeen > 1000) {
          connectedUsers.delete(userId);
          lastSeenMap.delete(userId);
          presenceTimeouts.delete(userId);
          userChatState.delete(userId); // Clean up chat state on disconnect
          
          try {
            // await User.updateLastSeen(userId); 
          } catch (err) {}
          
          io.emit('user:offline', { userId });
          console.log(`[SOCKET] User ${userId} marked offline (debounce)`);
        }
      }, 1000);
      
      presenceTimeouts.set(userId, timeoutId);
    }
  });
});

async function processNotifications() {
  let client;
  let inTransaction = false;
  try {
    client = await pool.connect();
    await client.query('BEGIN');
    inTransaction = true;
    const ready = await client.query(`
      SELECT *
      FROM notification_outbox
      WHERE status = 'PENDING'
        AND (schedule_at IS NULL OR schedule_at <= CURRENT_TIMESTAMP)
      ORDER BY created_at ASC
      LIMIT 10
      FOR UPDATE SKIP LOCKED
    `);
    for (const outbox of ready.rows) {
      const targetRole = outbox.target_role;
      let users;
      if (Array.isArray(outbox.target_user_ids) && outbox.target_user_ids.length > 0) {
        users = await client.query(
          `SELECT user_id, account_type, fcm_token FROM users WHERE user_id = ANY($1::uuid[])`,
          [outbox.target_user_ids]
        );
        users = users.rows.filter(u => (targetRole === 'USER' ? u.account_type === 'user' : u.account_type === 'listener'));
      } else {
        users = await client.query(
          `SELECT user_id, account_type, fcm_token FROM users WHERE account_type = $1`,
          [targetRole === 'USER' ? 'user' : 'listener']
        );
        users = users.rows;
      }
      for (const u of users) {
        // Use client (transaction) instead of pool for delivery tracking
        await client.query(
          `INSERT INTO notification_deliveries (outbox_id, user_id)
           VALUES ($1, $2)
           ON CONFLICT (outbox_id, user_id) DO UPDATE SET outbox_id = EXCLUDED.outbox_id
           RETURNING *`,
          [outbox.id, u.user_id]
        );
        const inserted = await client.query(
          `INSERT INTO notifications (user_id, title, message, notification_type, is_read, data, source_outbox_id)
           VALUES ($1, $2, $3, $4, FALSE, $5::jsonb, $6)
           ON CONFLICT DO NOTHING
           RETURNING notification_id, created_at`,
          [
            u.user_id,
            outbox.title,
            outbox.body,
            'system',
            JSON.stringify({ targetRole: targetRole }),
            outbox.id
          ]
        );
        if (inserted.rows.length > 0) {
          const payload = {
            id: inserted.rows[0].notification_id,
            title: outbox.title,
            body: outbox.body,
            createdAt: inserted.rows[0].created_at instanceof Date
              ? inserted.rows[0].created_at.toISOString()
              : inserted.rows[0].created_at
          };
          io.to(`user_${u.user_id}`).emit('app:notification', payload);
          if (u.fcm_token) {
            try {
              await sendPushFCM(u.fcm_token, outbox.title, outbox.body, { outboxId: String(outbox.id) });
            } catch {}
          }
          // Mark delivery sent within transaction
          await client.query(
            `UPDATE notification_deliveries SET status = 'SENT', delivered_at = CURRENT_TIMESTAMP
             WHERE outbox_id = $1 AND user_id = $2`,
            [outbox.id, u.user_id]
          );
        }
      }
      // Mark outbox as SENT within transaction
      await client.query(
        `UPDATE notification_outbox SET status = 'SENT', delivered_at = CURRENT_TIMESTAMP WHERE id = $1`,
        [outbox.id]
      );
      // Handle recurring notifications (daily/weekly)
      if (outbox.repeat_interval && outbox.schedule_at) {
        const interval = outbox.repeat_interval === 'daily' ? '1 day' : '7 days';
        await client.query(
          `INSERT INTO notification_outbox (title, body, target_role, target_user_ids, schedule_at, repeat_interval, created_by)
           VALUES ($1, $2, $3, $4, $5::timestamp + $6::interval, $7, $8)`,
          [
            outbox.title,
            outbox.body,
            outbox.target_role,
            outbox.target_user_ids,
            outbox.schedule_at,
            interval,
            outbox.repeat_interval,
            outbox.created_by
          ]
        );
      }
    }
    await client.query('COMMIT');
    inTransaction = false;
  } catch (e) {
    if (client && inTransaction) {
      try {
        await client.query('ROLLBACK');
      } catch {}
    }
    console.error('processNotifications error:', e.message);
  } finally {
    if (client) {
      client.release();
    }
  }
}



// ============================================
// ERROR HANDLING
// ============================================

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Route not found',
    path: req.originalUrl
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
    ...(config.NODE_ENV === 'development' && { stack: err.stack })
  });
});

// ============================================
// SERVER STARTUP
// ============================================

const PORT = config.PORT;

async function startServer() {
  try {
    // Test database connection
    console.log('🔗 Connecting to AWS RDS PostgreSQL...');
    const connected = await testConnection();
    
    if (!connected) {
      console.error('❌ Failed to connect to database. Exiting...');
      process.exit(1);
    }

    // Ensure schema has required columns (safe, idempotent)
    try {
      await ensureSchema();
    } catch (err) {
      console.error('❌ Failed to ensure database schema:', err.message);
      process.exit(1);
    }

    // PRODUCTION SAFETY: Clear all stale is_busy flags on startup.
    // If the server crashed or restarted, listeners may be stuck as busy.
    try {
      const { pool: startupPool } = await import('./db.js');
      const cleared = await startupPool.query(
        `UPDATE listeners SET is_busy = FALSE WHERE is_busy = TRUE RETURNING listener_id`
      );
      if (cleared.rowCount > 0) {
        console.log(`🧹 Cleared ${cleared.rowCount} stale busy flag(s) on startup:`, cleared.rows.map(r => r.listener_id));
      }
    } catch (err) {
      console.error('⚠️  Failed to clear stale busy flags:', err.message);
    }

    const listenWithFallback = (initialPort, attempts = 8) =>
      new Promise((resolve, reject) => {
        let port = Number(initialPort) || 3002;
        let tries = 0;
        const tryListen = () => {
          const onError = (err) => {
            server.off('error', onError);
            if (err && err.code === 'EADDRINUSE' && tries < attempts - 1) {
              port += 1;
              tries += 1;
              tryListen();
            } else {
              reject(err);
            }
          };
          server.once('error', onError);
          server.listen(port, () => {
            server.off('error', onError);
            resolve(port);
          });
        };
        tryListen();
      });

    const boundPort = await listenWithFallback(PORT, 8);
    console.log('\n' + '='.repeat(50));
    console.log(`🚀 Call To Backend Server`);
    console.log(`📡 Environment: ${config.NODE_ENV}`);
    console.log(`🌐 Server running on port ${boundPort}`);
    console.log(`🔌 Socket.IO ready for connections`);
    console.log(`📊 API endpoints available at http://localhost:${boundPort}/api`);
    console.log('='.repeat(50) + '\n');
    setInterval(() => {
      processNotifications().catch((err) => {
        console.error('processNotifications fatal error:', err.message);
      });
    }, 60 * 1000);
  } catch (error) {
    console.error('❌ Failed to start server:', error);
    process.exit(1);
  }
}

// Start the server
startServer();

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('\n🛑 SIGTERM signal received: closing server gracefully');
  server.close(() => {
    console.log('✓ Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('\n🛑 SIGINT signal received: closing server gracefully');
  server.close(() => {
    console.log('✓ Server closed');
    process.exit(0);
  });
});

export { app, server, io };



















// import express from 'express';
// import http from 'http';
// import { Server } from 'socket.io';
// import cors from 'cors';
// import helmet from 'helmet';
// import morgan from 'morgan';
// import compression from 'compression';
// import rateLimit from 'express-rate-limit';
// import config from './config/config.js';
// import { testConnection, ensureSchema } from './db.js';
// // Initialize Express app
// const app = express();
// const server = http.createServer(app);
// const io = new Server(server, {
//   cors: config.cors,
//   pingTimeout: config.socketIO.pingTimeout,
//   pingInterval: config.socketIO.pingInterval
// });

// // Import routes
// import authRoutes from './routes/auth.js';
// import userRoutes from './routes/users.js';
// import listenerRoutes from './routes/listeners.js';
// import callRoutes from './routes/calls.js';
// import chatRoutes from './routes/chats.js';
// import adminRoutes from './routes/admin.js';
// import User from './models/User.js';

// // ============================================
// // MIDDLEWARE
// // ============================================

// // Security middleware
// app.use(helmet());

// // CORS
// app.use(cors(config.cors));

// // Body parsing
// app.use(express.json({ limit: '10mb' }));
// app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// // Compression
// app.use(compression());

// // Logging
// if (config.NODE_ENV === 'development') {
//   app.use(morgan('dev'));
// } else {
//   app.use(morgan('combined'));
// }

// // Rate limiting
// const limiter = rateLimit({
//   windowMs: config.rateLimit.windowMs,
//   max: config.rateLimit.max,
//   message: 'Too many requests from this IP, please try again later.'
// });
// app.use('/api/', limiter);

// // ============================================
// // ROUTES
// // ============================================

// // Health check
// app.get('/', (req, res) => {
//   res.json({
//     message: 'Call To API Server',
//     version: '1.0.0',
//     status: 'running'
//   });
// });

// // API health check
// app.get('/api/health', async (req, res) => {
//   try {
//     const dbConnected = await testConnection();
//     res.json({
//       status: 'healthy',
//       database: dbConnected ? 'connected' : 'disconnected',
//       timestamp: new Date().toISOString()
//     });
//   } catch (error) {
//     res.status(500).json({
//       status: 'unhealthy',
//       error: error.message
//     });
//   }
// });

// // Mount API routes
// app.use('/api/auth', authRoutes);
// app.use('/api/users', userRoutes);
// app.use('/api/listeners', listenerRoutes);
// app.use('/api/calls', callRoutes);
// app.use('/api/chats', chatRoutes);
// app.use('/api/admin', adminRoutes);

// // ============================================
// // SOCKET.IO - REAL-TIME FEATURES
// // ============================================



// // In-memory maps
// const connectedUsers = new Map(); // Map of userId -> socketId
// const listenerSockets = new Map(); // Map of listenerUserId -> socketId
// const activeChannels = new Map(); // Map of channelName -> Set of userIds in channel
// const lastSeenMap = new Map(); // Map of userId -> timestamp
// const presenceTimeouts = new Map(); // Map of userId -> timeoutId

// // Socket.IO connection handler
// io.on('connection', (socket) => {
//   console.log(`[SOCKET] Connected: ${socket.id}`);

//   // 1. IDENTITY & PRESENCE
  
//   // User joins (can be regular user or listener)
//   socket.on('user:join', (userId) => {
//     if (!userId) return;
//     socket.userId = userId;
//     connectedUsers.set(userId, socket.id);
//     lastSeenMap.set(userId, Date.now());
    
//     // Clear any pending offline timeout
//     if (presenceTimeouts.has(userId)) {
//       clearTimeout(presenceTimeouts.get(userId));
//       presenceTimeouts.delete(userId);
//     }
    
//     io.emit('user:online', { userId });
//     console.log(`[SOCKET] User joined: ${userId}`);

//     // Send current online listeners to the newly joined user
//     const onlineListeners = Array.from(listenerSockets.keys());
//     socket.emit('listeners:initial_status', onlineListeners);
//   });

//   // Listener specific join (for availability tracking)
//   socket.on('listener:join', (listenerUserId) => {
//     if (!listenerUserId) return;
//     socket.userId = listenerUserId; // Sync with userId
//     socket.listenerUserId = listenerUserId;
    
//     // Remove old socket if exists to prevent ghost sessions
//     if (listenerSockets.has(listenerUserId)) {
//       const oldSocketId = listenerSockets.get(listenerUserId);
//       if (oldSocketId && oldSocketId !== socket.id) {
//         const oldSocket = io.sockets.sockets.get(oldSocketId);
//         if (oldSocket) oldSocket.disconnect(true);
//       }
//     }
    
//     listenerSockets.set(listenerUserId, socket.id);
//     connectedUsers.set(listenerUserId, socket.id); // Also ensure in connectedUsers
    
//     io.emit('listener_status', { listenerUserId, online: true, timestamp: Date.now() });
//     console.log(`[SOCKET] Listener joined: ${listenerUserId}`);
//   });

//   // Explicit offline event
//   socket.on('listener:offline', (data) => {
//     const { listenerUserId } = data || {};
//     if (listenerUserId) {
//       listenerSockets.delete(listenerUserId);
//       io.emit('listener_status', { listenerUserId, online: false, timestamp: Date.now() });
//       console.log(`[SOCKET] Listener offline: ${listenerUserId}`);
//     }
//   });

//   // 2. CALL HANDLING

//   // Initiate call: User -> Listener
//   socket.on('call:initiate', (data) => {
//     const { listenerId, ...callData } = data || {};
//     // Check both maps for the listener's socket
//     const listenerSocketId = listenerSockets.get(listenerId) || connectedUsers.get(listenerId);
    
//     if (listenerSocketId) {
//       io.to(listenerSocketId).emit('incoming-call', callData);
//       console.log(`[SOCKET] call:initiate: Forwarded to listener ${listenerId}`);
//     } else {
//       console.log(`[SOCKET] call:initiate: Listener ${listenerId} NOT online`);
//       // Optionally notify the caller that the listener is offline
//       socket.emit('call:failed', { callId: callData.callId, reason: 'listener_offline' });
//     }
//   });

//   // Accept call: Listener -> User
//   socket.on('call:accept', (data) => {
//     const { callId, callerId } = data;
//     console.log(`[SOCKET] call:accept: Call ${callId} accepted by ${socket.userId}`);
//     const callerSocketId = connectedUsers.get(callerId);
//     if (callerSocketId) {
//       io.to(callerSocketId).emit('call:accepted', {
//         callId,
//         listenerId: socket.userId
//       });
//     }
//   });

//   // Reject call: Listener -> User
//   socket.on('call:reject', (data) => {
//     const { callId, callerId } = data;
//     console.log(`[SOCKET] call:reject: Call ${callId} rejected by ${socket.userId}`);
//     const callerSocketId = connectedUsers.get(callerId);
//     if (callerSocketId) {
//       io.to(callerSocketId).emit('call:rejected', {
//         callId,
//         listenerId: socket.userId
//       });
//     }
//   });

//   // Joined Agora channel (for both parties)
//   socket.on('call:joined', (data) => {
//     const { callId, channelName } = data;
//     const userId = socket.userId;
//     if (!userId) return;

//     console.log(`[SOCKET] User ${userId} joined channel ${channelName}`);
    
//     if (!activeChannels.has(channelName)) {
//       activeChannels.set(channelName, new Set());
//     }
//     activeChannels.get(channelName).add(userId);
    
//     const usersInChannel = activeChannels.get(channelName);
//     if (usersInChannel.size >= 2) {
//       console.log(`[SOCKET] Both parties in ${channelName}, emitting call:connected`);
//       usersInChannel.forEach(uid => {
//         const sid = connectedUsers.get(uid);
//         if (sid) {
//           io.to(sid).emit('call:connected', { callId, channelName });
//         }
//       });
//     }
//   });

//   // End call
//   socket.on('call:end', (data) => {
//     const { callId, otherUserId } = data;
//     console.log(`[SOCKET] call:end: Call ${callId} ended by ${socket.userId}`);
//     const otherSocketId = connectedUsers.get(otherUserId);
//     if (otherSocketId) {
//       io.to(otherSocketId).emit('call:ended', {
//         callId,
//         endedBy: socket.userId
//       });
//     }
//   });

//   // Leave channel
//   socket.on('call:left', (data) => {
//     const { channelName } = data;
//     if (activeChannels.has(channelName) && socket.userId) {
//       activeChannels.get(channelName).delete(socket.userId);
//       if (activeChannels.get(channelName).size === 0) {
//         activeChannels.delete(channelName);
//       }
//     }
//   });

//   // 3. DISCONNECTION

//   socket.on('disconnect', () => {
//     const userId = socket.userId;
//     const listenerUserId = socket.listenerUserId;

//     console.log(`[SOCKET] Disconnected: ${socket.id} (User: ${userId}, Listener: ${listenerUserId})`);

//     // Handle listener cleanup
//     if (listenerUserId && listenerSockets.get(listenerUserId) === socket.id) {
//       listenerSockets.delete(listenerUserId);
//       io.emit('listener_status', { listenerUserId, online: false, timestamp: Date.now() });
//       console.log(`[SOCKET] Listener marked offline: ${listenerUserId}`);
//     }

//     // Handle user cleanup and active calls
//     if (userId) {
//       // Notify others in active channels
//       for (const [channelName, users] of activeChannels.entries()) {
//         if (users.has(userId)) {
//           users.forEach(otherUid => {
//             if (otherUid !== userId) {
//               const otherSid = connectedUsers.get(otherUid);
//               if (otherSid) {
//                 io.to(otherSid).emit('call:ended', {
//                   callId: channelName,
//                   endedBy: userId,
//                   reason: 'peer_disconnected'
//                 });
//               }
//             }
//           });
//           users.delete(userId);
//           if (users.size === 0) activeChannels.delete(channelName);
//         }
//       }

//       // Debounce offline status
//       if (presenceTimeouts.has(userId)) {
//         clearTimeout(presenceTimeouts.get(userId));
//       }
      
//       const timeoutId = setTimeout(async () => {
//         const lastSeen = lastSeenMap.get(userId) || 0;
//         if (Date.now() - lastSeen > 1000) {
//           connectedUsers.delete(userId);
//           lastSeenMap.delete(userId);
//           presenceTimeouts.delete(userId);
          
//           try {
//             // await User.updateLastSeen(userId); 
//           } catch (err) {}
          
//           io.emit('user:offline', { userId });
//           console.log(`[SOCKET] User ${userId} marked offline (debounce)`);
//         }
//       }, 1000);
      
//       presenceTimeouts.set(userId, timeoutId);
//     }
//   });
// });



// // ============================================
// // ERROR HANDLING
// // ============================================

// // 404 handler
// app.use((req, res) => {
//   res.status(404).json({
//     error: 'Route not found',
//     path: req.originalUrl
//   });
// });

// // Global error handler
// app.use((err, req, res, next) => {
//   console.error('Error:', err);
  
//   res.status(err.status || 500).json({
//     error: err.message || 'Internal server error',
//     ...(config.NODE_ENV === 'development' && { stack: err.stack })
//   });
// });

// // ============================================
// // SERVER STARTUP
// // ============================================

// const PORT = config.PORT;

// async function startServer() {
//   try {
//     // Test database connection
//     console.log('🔗 Connecting to AWS RDS PostgreSQL...');
//     const connected = await testConnection();
    
//     if (!connected) {
//       console.error('❌ Failed to connect to database. Exiting...');
//       process.exit(1);
//     }

//     // Ensure schema has required columns (safe, idempotent)
//     try {
//       await ensureSchema();
//     } catch (err) {
//       console.error('❌ Failed to ensure database schema:', err.message);
//       process.exit(1);
//     }

//     // Start server
//     server.listen(PORT, () => {
//       console.log('\n' + '='.repeat(50));
//       console.log(`🚀 Call To Backend Server`);
//       console.log(`📡 Environment: ${config.NODE_ENV}`);
//       console.log(`🌐 Server running on port ${PORT}`);
//       console.log(`🔌 Socket.IO ready for connections`);
//       console.log(`📊 API endpoints available at http://localhost:${PORT}/api`);
//       console.log('='.repeat(50) + '\n');
//     });
//   } catch (error) {
//     console.error('❌ Failed to start server:', error);
//     process.exit(1);
//   }
// }

// // Start the server
// startServer();

// // Handle graceful shutdown
// process.on('SIGTERM', () => {
//   console.log('\n🛑 SIGTERM signal received: closing server gracefully');
//   server.close(() => {
//     console.log('✓ Server closed');
//     process.exit(0);
//   });
// });

// process.on('SIGINT', () => {
//   console.log('\n🛑 SIGINT signal received: closing server gracefully');
//   server.close(() => {
//     console.log('✓ Server closed');
//     process.exit(0);
//   });
// });

// export { app, server, io };import express from 'express';
// import http from 'http';
// import { Server } from 'socket.io';
// import cors from 'cors';
// import helmet from 'helmet';
// import morgan from 'morgan';
// import compression from 'compression';
// import rateLimit from 'express-rate-limit';
// import config from './config/config.js';
// import { testConnection, ensureSchema } from './db.js';
// // Initialize Express app
// const app = express();
// const server = http.createServer(app);
// const io = new Server(server, {
//   cors: config.cors,
//   pingTimeout: config.socketIO.pingTimeout,
//   pingInterval: config.socketIO.pingInterval
// });

// // Import routes
// import authRoutes from './routes/auth.js';
// import userRoutes from './routes/users.js';
// import listenerRoutes from './routes/listeners.js';
// import callRoutes from './routes/calls.js';
// import chatRoutes from './routes/chats.js';
// import adminRoutes from './routes/admin.js';
// import User from './models/User.js';

// // ============================================
// // MIDDLEWARE
// // ============================================

// // Security middleware
// app.use(helmet());

// // CORS
// app.use(cors(config.cors));

// // Body parsing
// app.use(express.json({ limit: '10mb' }));
// app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// // Compression
// app.use(compression());

// // Logging
// if (config.NODE_ENV === 'development') {
//   app.use(morgan('dev'));
// } else {
//   app.use(morgan('combined'));
// }

// // Rate limiting
// const limiter = rateLimit({
//   windowMs: config.rateLimit.windowMs,
//   max: config.rateLimit.max,
//   message: 'Too many requests from this IP, please try again later.'
// });
// app.use('/api/', limiter);

// // ============================================
// // ROUTES
// // ============================================

// // Health check
// app.get('/', (req, res) => {
//   res.json({
//     message: 'Call To API Server',
//     version: '1.0.0',
//     status: 'running'
//   });
// });

// // API health check
// app.get('/api/health', async (req, res) => {
//   try {
//     const dbConnected = await testConnection();
//     res.json({
//       status: 'healthy',
//       database: dbConnected ? 'connected' : 'disconnected',
//       timestamp: new Date().toISOString()
//     });
//   } catch (error) {
//     res.status(500).json({
//       status: 'unhealthy',
//       error: error.message
//     });
//   }
// });

// // Mount API routes
// app.use('/api/auth', authRoutes);
// app.use('/api/users', userRoutes);
// app.use('/api/listeners', listenerRoutes);
// app.use('/api/calls', callRoutes);
// app.use('/api/chats', chatRoutes);
// app.use('/api/admin', adminRoutes);

// // ============================================
// // SOCKET.IO - REAL-TIME FEATURES
// // ============================================



// // In-memory maps
// const connectedUsers = new Map(); // Map of userId -> socketId
// const listenerSockets = new Map(); // Map of listenerUserId -> socketId
// const activeChannels = new Map(); // Map of channelName -> Set of userIds in channel
// const lastSeenMap = new Map(); // Map of userId -> timestamp
// const presenceTimeouts = new Map(); // Map of userId -> timeoutId

// // Socket.IO connection handler
// io.on('connection', (socket) => {
//   console.log(`[SOCKET] Connected: ${socket.id}`);

//   // 1. IDENTITY & PRESENCE
  
//   // User joins (can be regular user or listener)
//   socket.on('user:join', (userId) => {
//     if (!userId) return;
//     socket.userId = userId;
//     connectedUsers.set(userId, socket.id);
//     lastSeenMap.set(userId, Date.now());
    
//     // Clear any pending offline timeout
//     if (presenceTimeouts.has(userId)) {
//       clearTimeout(presenceTimeouts.get(userId));
//       presenceTimeouts.delete(userId);
//     }
    
//     io.emit('user:online', { userId });
//     console.log(`[SOCKET] User joined: ${userId}`);

//     // Send current online listeners to the newly joined user
//     const onlineListeners = Array.from(listenerSockets.keys());
//     socket.emit('listeners:initial_status', onlineListeners);
//   });

//   // Listener specific join (for availability tracking)
//   socket.on('listener:join', (listenerUserId) => {
//     if (!listenerUserId) return;
//     socket.userId = listenerUserId; // Sync with userId
//     socket.listenerUserId = listenerUserId;
    
//     // Remove old socket if exists to prevent ghost sessions
//     if (listenerSockets.has(listenerUserId)) {
//       const oldSocketId = listenerSockets.get(listenerUserId);
//       if (oldSocketId && oldSocketId !== socket.id) {
//         const oldSocket = io.sockets.sockets.get(oldSocketId);
//         if (oldSocket) oldSocket.disconnect(true);
//       }
//     }
    
//     listenerSockets.set(listenerUserId, socket.id);
//     connectedUsers.set(listenerUserId, socket.id); // Also ensure in connectedUsers
    
//     io.emit('listener_status', { listenerUserId, online: true, timestamp: Date.now() });
//     console.log(`[SOCKET] Listener joined: ${listenerUserId}`);
//   });

//   // Explicit offline event
//   socket.on('listener:offline', (data) => {
//     const { listenerUserId } = data || {};
//     if (listenerUserId) {
//       listenerSockets.delete(listenerUserId);
//       io.emit('listener_status', { listenerUserId, online: false, timestamp: Date.now() });
//       console.log(`[SOCKET] Listener offline: ${listenerUserId}`);
//     }
//   });

//   // 2. CALL HANDLING

//   // Initiate call: User -> Listener
//   socket.on('call:initiate', (data) => {
//     const { listenerId, ...callData } = data || {};
//     // Check both maps for the listener's socket
//     const listenerSocketId = listenerSockets.get(listenerId) || connectedUsers.get(listenerId);
    
//     if (listenerSocketId) {
//       io.to(listenerSocketId).emit('incoming-call', callData);
//       console.log(`[SOCKET] call:initiate: Forwarded to listener ${listenerId}`);
//     } else {
//       console.log(`[SOCKET] call:initiate: Listener ${listenerId} NOT online`);
//       // Optionally notify the caller that the listener is offline
//       socket.emit('call:failed', { callId: callData.callId, reason: 'listener_offline' });
//     }
//   });

//   // Accept call: Listener -> User
//   socket.on('call:accept', (data) => {
//     const { callId, callerId } = data;
//     console.log(`[SOCKET] call:accept: Call ${callId} accepted by ${socket.userId}`);
//     const callerSocketId = connectedUsers.get(callerId);
//     if (callerSocketId) {
//       io.to(callerSocketId).emit('call:accepted', {
//         callId,
//         listenerId: socket.userId
//       });
//     }
//   });

//   // Reject call: Listener -> User
//   socket.on('call:reject', (data) => {
//     const { callId, callerId } = data;
//     console.log(`[SOCKET] call:reject: Call ${callId} rejected by ${socket.userId}`);
//     const callerSocketId = connectedUsers.get(callerId);
//     if (callerSocketId) {
//       io.to(callerSocketId).emit('call:rejected', {
//         callId,
//         listenerId: socket.userId
//       });
//     }
//   });

//   // Joined Agora channel (for both parties)
//   socket.on('call:joined', (data) => {
//     const { callId, channelName } = data;
//     const userId = socket.userId;
//     if (!userId) return;

//     console.log(`[SOCKET] User ${userId} joined channel ${channelName}`);
    
//     if (!activeChannels.has(channelName)) {
//       activeChannels.set(channelName, new Set());
//     }
//     activeChannels.get(channelName).add(userId);
    
//     const usersInChannel = activeChannels.get(channelName);
//     if (usersInChannel.size >= 2) {
//       console.log(`[SOCKET] Both parties in ${channelName}, emitting call:connected`);
//       usersInChannel.forEach(uid => {
//         const sid = connectedUsers.get(uid);
//         if (sid) {
//           io.to(sid).emit('call:connected', { callId, channelName });
//         }
//       });
//     }
//   });

//   // End call
//   socket.on('call:end', (data) => {
//     const { callId, otherUserId } = data;
//     console.log(`[SOCKET] call:end: Call ${callId} ended by ${socket.userId}`);
//     const otherSocketId = connectedUsers.get(otherUserId);
//     if (otherSocketId) {
//       io.to(otherSocketId).emit('call:ended', {
//         callId,
//         endedBy: socket.userId
//       });
//     }
//   });

//   // Leave channel
//   socket.on('call:left', (data) => {
//     const { channelName } = data;
//     if (activeChannels.has(channelName) && socket.userId) {
//       activeChannels.get(channelName).delete(socket.userId);
//       if (activeChannels.get(channelName).size === 0) {
//         activeChannels.delete(channelName);
//       }
//     }
//   });

//   // 3. DISCONNECTION

//   socket.on('disconnect', () => {
//     const userId = socket.userId;
//     const listenerUserId = socket.listenerUserId;

//     console.log(`[SOCKET] Disconnected: ${socket.id} (User: ${userId}, Listener: ${listenerUserId})`);

//     // Handle listener cleanup
//     if (listenerUserId && listenerSockets.get(listenerUserId) === socket.id) {
//       listenerSockets.delete(listenerUserId);
//       io.emit('listener_status', { listenerUserId, online: false, timestamp: Date.now() });
//       console.log(`[SOCKET] Listener marked offline: ${listenerUserId}`);
//     }

//     // Handle user cleanup and active calls
//     if (userId) {
//       // Notify others in active channels
//       for (const [channelName, users] of activeChannels.entries()) {
//         if (users.has(userId)) {
//           users.forEach(otherUid => {
//             if (otherUid !== userId) {
//               const otherSid = connectedUsers.get(otherUid);
//               if (otherSid) {
//                 io.to(otherSid).emit('call:ended', {
//                   callId: channelName,
//                   endedBy: userId,
//                   reason: 'peer_disconnected'
//                 });
//               }
//             }
//           });
//           users.delete(userId);
//           if (users.size === 0) activeChannels.delete(channelName);
//         }
//       }

//       // Debounce offline status
//       if (presenceTimeouts.has(userId)) {
//         clearTimeout(presenceTimeouts.get(userId));
//       }
      
//       const timeoutId = setTimeout(async () => {
//         const lastSeen = lastSeenMap.get(userId) || 0;
//         if (Date.now() - lastSeen > 1000) {
//           connectedUsers.delete(userId);
//           lastSeenMap.delete(userId);
//           presenceTimeouts.delete(userId);
          
//           try {
//             // await User.updateLastSeen(userId); 
//           } catch (err) {}
          
//           io.emit('user:offline', { userId });
//           console.log(`[SOCKET] User ${userId} marked offline (debounce)`);
//         }
//       }, 1000);
      
//       presenceTimeouts.set(userId, timeoutId);
//     }
//   });
// });



// // ============================================
// // ERROR HANDLING
// // ============================================

// // 404 handler
// app.use((req, res) => {
//   res.status(404).json({
//     error: 'Route not found',
//     path: req.originalUrl
//   });
// });

// // Global error handler
// app.use((err, req, res, next) => {
//   console.error('Error:', err);
  
//   res.status(err.status || 500).json({
//     error: err.message || 'Internal server error',
//     ...(config.NODE_ENV === 'development' && { stack: err.stack })
//   });
// });

// // ============================================
// // SERVER STARTUP
// // ============================================

// const PORT = config.PORT;

// async function startServer() {
//   try {
//     // Test database connection
//     console.log('🔗 Connecting to AWS RDS PostgreSQL...');
//     const connected = await testConnection();
    
//     if (!connected) {
//       console.error('❌ Failed to connect to database. Exiting...');
//       process.exit(1);
//     }

//     // Ensure schema has required columns (safe, idempotent)
//     try {
//       await ensureSchema();
//     } catch (err) {
//       console.error('❌ Failed to ensure database schema:', err.message);
//       process.exit(1);
//     }

//     // Start server
//     server.listen(PORT, () => {
//       console.log('\n' + '='.repeat(50));
//       console.log(`🚀 Call To Backend Server`);
//       console.log(`📡 Environment: ${config.NODE_ENV}`);
//       console.log(`🌐 Server running on port ${PORT}`);
//       console.log(`🔌 Socket.IO ready for connections`);
//       console.log(`📊 API endpoints available at http://localhost:${PORT}/api`);
//       console.log('='.repeat(50) + '\n');
//     });
//   } catch (error) {
//     console.error('❌ Failed to start server:', error);
//     process.exit(1);
//   }
// }

// // Start the server
// startServer();

// // Handle graceful shutdown
// process.on('SIGTERM', () => {
//   console.log('\n🛑 SIGTERM signal received: closing server gracefully');
//   server.close(() => {
//     console.log('✓ Server closed');
//     process.exit(0);
//   });
// });

// process.on('SIGINT', () => {
//   console.log('\n🛑 SIGINT signal received: closing server gracefully');
//   server.close(() => {
//     console.log('✓ Server closed');
//     process.exit(0);
//   });
// });

// export { app, server, io };
