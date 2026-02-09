import express from 'express';
import jwt from 'jsonwebtoken';
import axios from 'axios';
import { OAuth2Client } from 'google-auth-library';
import Admin from '../models/Admin.js';
import Listener from '../models/Listener.js';
import config from '../config/config.js';
import { pool } from '../db.js';
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

// GET /api/admin/listeners
// Get all listeners for admin panel
router.get('/listeners', async (req, res) => {
  try {
    const listeners = await Listener.getAllForAdmin();
    res.json({ listeners });
  } catch (error) {
    console.error('Get admin listeners error:', error);
    res.status(500).json({ error: 'Failed to fetch listeners' });
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
    const { status } = req.body;

    console.log(`[ADMIN] Updating verification status for listener ${listener_id} to: ${status}`);

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

    // Update verification status
    const updated = await Listener.updateVerificationStatus(listener_id, status);

    console.log(`[ADMIN] Listener ${listener_id} verification status updated to: ${status}`);

    res.json({
      message: `Listener verification status updated to ${status}`,
      listener: {
        listener_id: updated.listener_id,
        verification_status: updated.verification_status,
        is_verified: updated.is_verified
      }
    });
  } catch (error) {
    console.error('Update listener verification status error:', error);
    res.status(500).json({ error: 'Failed to update verification status' });
  }
});

export default router;
