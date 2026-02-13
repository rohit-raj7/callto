import express from 'express';
import jwt from 'jsonwebtoken';
import axios from 'axios';
import { OAuth2Client } from 'google-auth-library';
import Admin from '../models/Admin.js';
import Listener from '../models/Listener.js';
import ChatChargeConfig from '../models/ChatChargeConfig.js';
import config from '../config/config.js';
import { pool, getRateConfig } from '../db.js';
import { authenticateAdmin } from '../middleware/auth.js';

const router = express.Router();
const googleClient = new OAuth2Client(process.env.admin_google_client_id);

// Admin Google login
router.post('/google-login', async (req, res) => {
  try {
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ error: 'Token is required' });
    }

    let userInfo;

    // Verify Google token
    try {
      // First, try to verify as ID token
      const ticket = await googleClient.verifyIdToken({
        idToken: token,
      });

      const payload = ticket.getPayload();

      userInfo = {
        email: payload.email,
        full_name: payload.name,
      };
    } catch (idTokenError) {
      // If ID token verification fails, try as access token
      console.log('ID token verification failed, trying access token...');
      try {
        const googleRes = await axios.get(
          `https://www.googleapis.com/oauth2/v3/userinfo?access_token=${token}`
        );

        const googleUser = googleRes.data;

        userInfo = {
          email: googleUser.email,
          full_name: googleUser.name,
        };
      } catch (accessTokenError) {
        console.error('Google token verification failed:', accessTokenError);
        return res.status(401).json({ error: 'Invalid Google token' });
      }
    }

    // Check if email matches the admin email
    if (userInfo.email !== 'calltoofficials@gmail.com') {
      return res.status(401).json({ error: 'Unauthorized: Not an admin email' });
    }

    // Find or create admin
    let admin = await Admin.findByEmail(userInfo.email);
    if (!admin) {
      // Create admin if not exists
      const hashedPassword = await Admin.hashPassword('defaultpassword'); // Not used, but required
      admin = await Admin.create({
        email: userInfo.email,
        password_hash: hashedPassword,
        full_name: userInfo.full_name,
      });
    }

    // Update last login
    await Admin.updateLastLogin(admin.admin_id);

    // Generate JWT token
    const jwtToken = jwt.sign(
      { admin_id: admin.admin_id, email: admin.email },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    res.json({
      message: 'Login successful',
      token: jwtToken,
      admin: {
        admin_id: admin.admin_id,
        email: admin.email,
        full_name: admin.full_name
      }
    });
  } catch (error) {
    console.error('Admin Google login error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

router.get('/rate-config', authenticateAdmin, async (req, res) => {
  try {
    const rateConfig = await getRateConfig();
    res.json({
      rateConfig: {
        normalPerMinuteRate: Number(rateConfig.normal_per_minute_rate),
        firstTimeOfferEnabled: rateConfig.first_time_offer_enabled === true,
        offerMinutesLimit: rateConfig.offer_minutes_limit,
        offerFlatPrice: rateConfig.offer_flat_price,
        updatedAt: rateConfig.updated_at
      }
    });
  } catch (error) {
    console.error('Get rate config error:', error);
    res.status(500).json({ error: 'Failed to fetch rate config' });
  }
});

router.put('/rate-config', authenticateAdmin, async (req, res) => {
  try {
    const {
      normalPerMinuteRate,
      firstTimeOfferEnabled,
      offerMinutesLimit,
      offerFlatPrice
    } = req.body || {};

    const parsedNormalRate = Number(normalPerMinuteRate);
    const parsedOfferMinutes = Number(offerMinutesLimit);
    const parsedOfferFlat = Number(offerFlatPrice);
    const offerEnabled = firstTimeOfferEnabled === true;

    if (!Number.isFinite(parsedNormalRate) || parsedNormalRate <= 0) {
      return res.status(400).json({ error: 'normalPerMinuteRate must be a positive number' });
    }

    if (offerEnabled) {
      if (!Number.isFinite(parsedOfferMinutes) || parsedOfferMinutes <= 0) {
        return res.status(400).json({ error: 'offerMinutesLimit must be a positive number' });
      }
      if (!Number.isFinite(parsedOfferFlat) || parsedOfferFlat <= 0) {
        return res.status(400).json({ error: 'offerFlatPrice must be a positive number' });
      }
    }

    const previousConfig = await getRateConfig();
    const updateQuery = `
      INSERT INTO rate_config (normal_per_minute_rate, first_time_offer_enabled, offer_minutes_limit, offer_flat_price)
      VALUES ($1, $2, $3, $4)
      RETURNING config_id, normal_per_minute_rate, first_time_offer_enabled, offer_minutes_limit, offer_flat_price, updated_at
    `;
    const updateResult = await pool.query(updateQuery, [
      parsedNormalRate,
      offerEnabled,
      offerEnabled ? parsedOfferMinutes : parsedOfferMinutes || null,
      offerEnabled ? parsedOfferFlat : parsedOfferFlat || null
    ]);

    await pool.query(
      `INSERT INTO rate_config_audit (admin_id, previous_config, new_config)
       VALUES ($1, $2, $3)`,
      [
        req.adminId || null,
        previousConfig ? JSON.stringify(previousConfig) : null,
        JSON.stringify(updateResult.rows[0])
      ]
    );

    if (offerEnabled) {
      await pool.query(
        `UPDATE users
         SET offer_minutes_limit = $1,
             offer_flat_price = $2
         WHERE is_first_time_user = TRUE
           AND offer_used = FALSE`,
        [parsedOfferMinutes, parsedOfferFlat]
      );
    } else {
      await pool.query(
        `UPDATE users
         SET offer_minutes_limit = NULL,
             offer_flat_price = NULL
         WHERE is_first_time_user = TRUE
           AND offer_used = FALSE`
      );
    }

    const updatedConfig = updateResult.rows[0];

    res.json({
      message: 'Rate config updated',
      rateConfig: {
        normalPerMinuteRate: Number(updatedConfig.normal_per_minute_rate),
        firstTimeOfferEnabled: updatedConfig.first_time_offer_enabled === true,
        offerMinutesLimit: updatedConfig.offer_minutes_limit,
        offerFlatPrice: updatedConfig.offer_flat_price,
        updatedAt: updatedConfig.updated_at
      }
    });
  } catch (error) {
    console.error('Update rate config error:', error);
    res.status(500).json({ error: 'Failed to update rate config' });
  }
});

router.get('/rate-config/audit', authenticateAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 50 } = req.query;
    const perPage = Math.min(Math.max(Number(limit) || 50, 1), 200);
    const currentPage = Math.max(Number(page) || 1, 1);
    const offset = (currentPage - 1) * perPage;

    const auditQuery = `
      SELECT audit_id, admin_id, previous_config, new_config, created_at
      FROM rate_config_audit
      ORDER BY created_at DESC
      LIMIT $1 OFFSET $2
    `;
    const countQuery = `SELECT COUNT(*)::int AS count FROM rate_config_audit`;
    const [auditResult, countResult] = await Promise.all([
      pool.query(auditQuery, [perPage, offset]),
      pool.query(countQuery)
    ]);

    res.json({
      audit: auditResult.rows,
      count: countResult.rows[0]?.count || 0,
      page: currentPage,
      limit: perPage
    });
  } catch (error) {
    console.error('Get rate config audit error:', error);
    res.status(500).json({ error: 'Failed to fetch audit log' });
  }
});

router.get('/rate-config/offer-users', authenticateAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 50, search } = req.query;
    const perPage = Math.min(Math.max(Number(limit) || 50, 1), 200);
    const currentPage = Math.max(Number(page) || 1, 1);
    const offset = (currentPage - 1) * perPage;

    const conds = ['offer_used = TRUE'];
    const params = [];
    let idx = 1;
    if (search) {
      conds.push(`(email ILIKE $${idx} OR display_name ILIKE $${idx})`);
      params.push(`%${String(search).trim()}%`);
      idx += 1;
    }

    const where = `WHERE ${conds.join(' AND ')}`;
    const listQuery = `
      SELECT user_id, email, display_name, created_at, last_login, offer_used, is_first_time_user,
             offer_minutes_limit, offer_flat_price
      FROM users
      ${where}
      ORDER BY updated_at DESC
      LIMIT $${idx} OFFSET $${idx + 1}
    `;
    const listParams = [...params, perPage, offset];

    const countQuery = `
      SELECT COUNT(*)::int AS count
      FROM users
      ${where}
    `;

    const [listResult, countResult] = await Promise.all([
      pool.query(listQuery, listParams),
      pool.query(countQuery, params)
    ]);

    res.json({
      users: listResult.rows,
      count: countResult.rows[0]?.count || 0,
      page: currentPage,
      limit: perPage
    });
  } catch (error) {
    console.error('Get offer users error:', error);
    res.status(500).json({ error: 'Failed to fetch offer users' });
  }
});

// GET /api/admin/listeners
// Get all listeners for admin panel
router.get('/listeners', authenticateAdmin, async (req, res) => {
  try {
    const listeners = await Listener.getAllForAdmin();
    res.json({ listeners });
  } catch (error) {
    console.error('Get admin listeners error:', error);
    res.status(500).json({ error: 'Failed to fetch listeners' });
  }
});

const parseRate = (value) => Number(value);
const isValidRate = (value) => Number.isFinite(value) && value > 0;

// POST /api/admin/listener/set-rates
// Set listener rates (admin only)
router.post('/listener/set-rates', authenticateAdmin, async (req, res) => {
  try {
    const { listenerId, userRatePerMin, listenerPayoutPerMin } = req.body || {};

    if (!listenerId) {
      return res.status(400).json({ error: 'listenerId is required' });
    }

    const userRate = parseRate(userRatePerMin);
    const payoutRate = parseRate(listenerPayoutPerMin);

    if (!isValidRate(userRate) || !isValidRate(payoutRate)) {
      return res.status(400).json({ error: 'Rates must be positive numbers' });
    }

    if (payoutRate > userRate) {
      return res.status(400).json({ error: 'Listener payout rate must be <= user rate' });
    }

    const updateResult = await pool.query(
      `UPDATE listeners
       SET user_rate_per_min = $2,
           listener_payout_per_min = $3,
           updated_at = CURRENT_TIMESTAMP
       WHERE listener_id = $1
       RETURNING listener_id, user_rate_per_min, listener_payout_per_min`,
      [listenerId, userRate, payoutRate]
    );

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: 'Listener not found' });
    }

    res.json({
      message: 'Listener rates set',
      rates: updateResult.rows[0]
    });
  } catch (error) {
    console.error('Set listener rates error:', error);
    res.status(500).json({ error: 'Failed to set listener rates' });
  }
});

// PUT /api/admin/listener/update-rates/:listenerId
// Update listener rates (admin only)
router.put('/listener/update-rates/:listenerId', authenticateAdmin, async (req, res) => {
  try {
    const { listenerId } = req.params;
    const { userRatePerMin, listenerPayoutPerMin } = req.body || {};

    const userRate = parseRate(userRatePerMin);
    const payoutRate = parseRate(listenerPayoutPerMin);

    if (!isValidRate(userRate) || !isValidRate(payoutRate)) {
      return res.status(400).json({ error: 'Rates must be positive numbers' });
    }

    if (payoutRate > userRate) {
      return res.status(400).json({ error: 'Listener payout rate must be <= user rate' });
    }

    const updateResult = await pool.query(
      `UPDATE listeners
       SET user_rate_per_min = $2,
           listener_payout_per_min = $3,
           updated_at = CURRENT_TIMESTAMP
       WHERE listener_id = $1
       RETURNING listener_id, user_rate_per_min, listener_payout_per_min`,
      [listenerId, userRate, payoutRate]
    );

    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: 'Listener not found' });
    }

    res.json({
      message: 'Listener rates updated',
      rates: updateResult.rows[0]
    });
  } catch (error) {
    console.error('Update listener rates error:', error);
    res.status(500).json({ error: 'Failed to update listener rates' });
  }
});

// GET /api/admin/contact-messages
// Fetch contact/support messages for admin panel
router.get('/contact-messages', authenticateAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 50, source, search } = req.query;
    const perPage = Math.min(Math.max(Number(limit) || 50, 1), 200);
    const currentPage = Math.max(Number(page) || 1, 1);
    const offset = (currentPage - 1) * perPage;

    const conds = [];
    const params = [];
    let idx = 1;

    if (source && (source === 'contact' || source === 'support')) {
      conds.push(`source = $${idx++}`);
      params.push(source);
    }

    if (search) {
      conds.push(`(name ILIKE $${idx} OR email ILIKE $${idx} OR message ILIKE $${idx})`);
      params.push(`%${String(search).trim()}%`);
      idx += 1;
    }

    const where = conds.length ? `WHERE ${conds.join(' AND ')}` : '';
    const listQuery = `
      SELECT contact_id, source, name, email, message, user_id, created_at
      FROM contact_messages
      ${where}
      ORDER BY created_at DESC
      LIMIT $${idx} OFFSET $${idx + 1}
    `;
    const listParams = [...params, perPage, offset];

    const countQuery = `
      SELECT COUNT(*)::int AS count
      FROM contact_messages
      ${where}
    `;

    const [listResult, countResult] = await Promise.all([
      pool.query(listQuery, listParams),
      pool.query(countQuery, params)
    ]);

    res.json({
      messages: listResult.rows,
      count: countResult.rows[0]?.count || 0,
      page: currentPage,
      limit: perPage
    });
  } catch (error) {
    console.error('Get contact messages error:', error);
    res.status(500).json({ error: 'Failed to fetch contact messages' });
  }
});

// GET /api/admin/delete-requests
// Fetch account deletion requests for admin panel
router.get('/delete-requests', authenticateAdmin, async (req, res) => {
  try {
    const { page = 1, limit = 50, role, status, search } = req.query;
    const perPage = Math.min(Math.max(Number(limit) || 50, 1), 200);
    const currentPage = Math.max(Number(page) || 1, 1);
    const offset = (currentPage - 1) * perPage;

    const conds = [];
    const params = [];
    let idx = 1;

    if (role && (role === 'user' || role === 'listener')) {
      conds.push(`role = $${idx++}`);
      params.push(role);
    }

    if (status && (status === 'pending' || status === 'approved' || status === 'rejected')) {
      conds.push(`status = $${idx++}`);
      params.push(status);
    }

    if (search) {
      conds.push(
        `(name ILIKE $${idx} OR email ILIKE $${idx} OR phone ILIKE $${idx} OR reason ILIKE $${idx})`
      );
      params.push(`%${String(search).trim()}%`);
      idx += 1;
    }

    const where = conds.length ? `WHERE ${conds.join(' AND ')}` : '';
    const listQuery = `
      SELECT request_id, user_id, name, email, phone, reason, role, status, created_at
      FROM delete_account_requests
      ${where}
      ORDER BY created_at DESC
      LIMIT $${idx} OFFSET $${idx + 1}
    `;
    const listParams = [...params, perPage, offset];

    const countQuery = `
      SELECT COUNT(*)::int AS count
      FROM delete_account_requests
      ${where}
    `;

    const [listResult, countResult] = await Promise.all([
      pool.query(listQuery, listParams),
      pool.query(countQuery, params)
    ]);

    res.json({
      requests: listResult.rows,
      count: countResult.rows[0]?.count || 0,
      page: currentPage,
      limit: perPage
    });
  } catch (error) {
    console.error('Get delete requests error:', error);
    res.status(500).json({ error: 'Failed to fetch delete requests' });
  }
});

// DELETE /api/admin/delete-requests/:request_id
// Remove a delete request from admin panel
router.delete('/delete-requests/:request_id', authenticateAdmin, async (req, res) => {
  try {
    const { request_id } = req.params;

    if (!request_id) {
      return res.status(400).json({ error: 'Request id is required' });
    }

    const deleteQuery = `
      DELETE FROM delete_account_requests
      WHERE request_id = $1
      RETURNING request_id
    `;

    const result = await pool.query(deleteQuery, [request_id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ error: 'Delete request not found' });
    }

    return res.json({ message: 'Delete request removed', request_id });
  } catch (error) {
    console.error('Delete request removal error:', error);
    return res.status(500).json({ error: 'Failed to delete request' });
  }
});

// PUT /api/admin/listeners/:listener_id/verification-status
// Update listener verification status (approve/reject)
// VERIFICATION CONTROL: Admin endpoint to approve or reject listener applications
router.put('/listeners/:listener_id/verification-status', authenticateAdmin, async (req, res) => {
  try {
    const { listener_id } = req.params;
    const { status, rejection_reason } = req.body;

    console.log(`[ADMIN] Updating verification status for listener ${listener_id} to: ${status}${rejection_reason ? ` (reason: ${rejection_reason})` : ''}`);

    if (!status || !['pending', 'approved', 'rejected'].includes(status)) {
      return res.status(400).json({ 
        error: 'Invalid status. Must be one of: pending, approved, rejected' 
      });
    }

    // Check if listener exists
    const listener = await Listener.findById(listener_id);
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }

    // Update verification status with optional rejection reason
    const updated = await Listener.updateVerificationStatus(listener_id, status, rejection_reason);

    console.log(`[ADMIN] Listener ${listener_id} verification status updated to: ${status}`);

    res.json({
      message: `Listener verification status updated to ${status}`,
      listener: {
        listener_id: updated.listener_id,
        verification_status: updated.verification_status,
        is_verified: updated.is_verified,
        rejection_reason: updated.rejection_reason,
        reapply_attempts: updated.reapply_attempts
      }
    });
  } catch (error) {
    console.error('Update listener verification status error:', error);
    res.status(500).json({ error: 'Failed to update verification status' });
  }
});

// Get user transactions (admin)
router.get('/users/:user_id/transactions', authenticateAdmin, async (req, res) => {
  try {
    const { user_id } = req.params;

    // Fetch user info
    const userResult = await pool.query(
      'SELECT user_id, display_name, email, mobile_number, city, country, account_type, is_active, created_at FROM users WHERE user_id = $1',
      [user_id]
    );
    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Fetch wallet
    const walletResult = await pool.query(
      'SELECT balance, currency, updated_at FROM wallets WHERE user_id = $1',
      [user_id]
    );

    // Fetch transactions
    const txResult = await pool.query(
      `SELECT transaction_id, transaction_type, amount, currency, description, payment_method, payment_gateway_id, status, related_call_id, created_at
       FROM transactions WHERE user_id = $1 ORDER BY created_at DESC`,
      [user_id]
    );

    res.json({
      user: userResult.rows[0],
      wallet: walletResult.rows[0] || { balance: '0.00', currency: 'INR' },
      transactions: txResult.rows
    });
  } catch (error) {
    console.error('Get user transactions error:', error);
    res.status(500).json({ error: 'Failed to fetch user transactions' });
  }
});

// ============================================
// CHAT CHARGE CONFIG ROUTES
// ============================================

// GET /api/admin/chat-charge-config
router.get('/chat-charge-config', authenticateAdmin, async (req, res) => {
  try {
    const config = await ChatChargeConfig.getActive();
    res.json({
      chatChargeConfig: {
        chargingEnabled: config.charging_enabled === true,
        freeMessageLimit: Number(config.free_message_limit),
        messageBlockSize: Number(config.message_block_size),
        chargePerMessageBlock: Number(config.charge_per_message_block),
        updatedAt: config.updated_at
      }
    });
  } catch (error) {
    console.error('Get chat charge config error:', error);
    res.status(500).json({ error: 'Failed to fetch chat charge config' });
  }
});

// PUT /api/admin/chat-charge-config
router.put('/chat-charge-config', authenticateAdmin, async (req, res) => {
  try {
    const {
      chargingEnabled,
      freeMessageLimit,
      messageBlockSize,
      chargePerMessageBlock
    } = req.body || {};

    const enabled = chargingEnabled === true;
    const freeLimit = Number(freeMessageLimit);
    const blockSize = Number(messageBlockSize);
    const chargePerBlock = Number(chargePerMessageBlock);

    if (!Number.isFinite(freeLimit) || freeLimit < 0) {
      return res.status(400).json({ error: 'freeMessageLimit must be a non-negative number' });
    }

    if (enabled) {
      if (!Number.isFinite(blockSize) || blockSize <= 0) {
        return res.status(400).json({ error: 'messageBlockSize must be a positive number' });
      }
      if (!Number.isFinite(chargePerBlock) || chargePerBlock <= 0) {
        return res.status(400).json({ error: 'chargePerMessageBlock must be a positive number' });
      }
    }

    const updated = await ChatChargeConfig.update({
      chargingEnabled: enabled,
      freeMessageLimit: freeLimit,
      messageBlockSize: enabled ? blockSize : (blockSize || 2),
      chargePerMessageBlock: enabled ? chargePerBlock : (chargePerBlock || 1.00)
    });

    res.json({
      message: 'Chat charge config updated',
      chatChargeConfig: {
        chargingEnabled: updated.charging_enabled === true,
        freeMessageLimit: Number(updated.free_message_limit),
        messageBlockSize: Number(updated.message_block_size),
        chargePerMessageBlock: Number(updated.charge_per_message_block),
        updatedAt: updated.updated_at
      }
    });
  } catch (error) {
    console.error('Update chat charge config error:', error);
    res.status(500).json({ error: 'Failed to update chat charge config' });
  }
});

export default router;
