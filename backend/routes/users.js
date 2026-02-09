import express from 'express';
const router = express.Router();
import User from '../models/User.js';
import { pool } from '../db.js';
import { authenticate, authenticateAdmin } from '../middleware/auth.js';
// GET /api/users
router.get('/', async (req, res) => {
  try {
    const users = await User.getAll();
    res.json(users);
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// GET /api/users/profile
// Get user profile
router.get('/profile', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ user });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PUT /api/users/profile
// Update user profile
router.put('/profile', authenticate, async (req, res) => {
  try {
    const {
      email,
      full_name,
      display_name,
      gender,
      date_of_birth,
      city,
      country,
      avatar_url,
      bio,
      mobile_number
    } = req.body;

    const updatedUser = await User.update(req.userId, {
      email,
      full_name,
      display_name,
      gender,
      date_of_birth,
      city,
      country,
      avatar_url,
      bio,
      mobile_number
    });

    res.json({
      message: 'Profile updated successfully',
      user: updatedUser
    });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
});

// POST /api/users/languages
// Add language preference
router.post('/languages', authenticate, async (req, res) => {
  try {
    const { language, proficiency_level } = req.body;

    if (!language) {
      return res.status(400).json({ error: 'Language is required' });
    }

    const query = `
      INSERT INTO user_languages (user_id, language, proficiency_level)
      VALUES ($1, $2, $3)
      RETURNING *
    `;
    const result = await pool.query(query, [req.userId, language, proficiency_level || 'Basic']);

    res.json({
      message: 'Language added successfully',
      language: result.rows[0]
    });
  } catch (error) {
    console.error('Add language error:', error);
    res.status(500).json({ error: 'Failed to add language' });
  }
});

// GET /api/users/languages
// Get user languages
router.get('/languages/me', authenticate, async (req, res) => {
  try {
    const query = `
      SELECT * FROM user_languages 
      WHERE user_id = $1
      ORDER BY created_at ASC
    `;
    const result = await pool.query(query, [req.userId]);

    res.json({ languages: result.rows });
  } catch (error) {
    console.error('Get languages error:', error);
    res.status(500).json({ error: 'Failed to fetch languages' });
  }
});

// DELETE /api/users/languages/:language_id
// Remove language
router.delete('/languages/:language_id', authenticate, async (req, res) => {
  try {
    await pool.query(
      'DELETE FROM user_languages WHERE id = $1 AND user_id = $2',
      [req.params.language_id, req.userId]
    );

    res.json({ message: 'Language removed successfully' });
  } catch (error) {
    console.error('Delete language error:', error);
    res.status(500).json({ error: 'Failed to remove language' });
  }
});

// GET /api/users/wallet
// Get user wallet
router.get('/wallet', authenticate, async (req, res) => {
  try {
    const wallet = await User.getWallet(req.userId);
    res.json({ wallet });
  } catch (error) {
    console.error('Get wallet error:', error);
    res.status(500).json({ error: 'Failed to fetch wallet' });
  }
});

// POST /api/users/wallet/add
// Add balance to wallet after successful payment
router.post('/wallet/add', authenticate, async (req, res) => {
  try {
    const { amount, payment_id, payment_method, description } = req.body;
    const parsedAmount = Number(amount);

    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ error: 'Valid amount is required' });
    }

    const paymentDetails = {
      payment_id,
      payment_method: payment_method || 'razorpay',
      description: description || 'Wallet recharge',
      currency: 'INR'
    };

    const wallet = await User.addBalance(req.userId, parsedAmount, paymentDetails);
    res.json({
      message: 'Balance added successfully',
      balance: wallet.balance,
    });
  } catch (error) {
    console.error('Add balance error:', error);
    res.status(500).json({ error: 'Failed to add balance' });
  }
});

// POST /api/users/favorites/:listener_id
// Add listener to favorites
router.post('/favorites/:listener_id', authenticate, async (req, res) => {
  try {
    const query = `
      INSERT INTO favorites (user_id, listener_id)
      VALUES ($1, $2)
      ON CONFLICT (user_id, listener_id) DO NOTHING
      RETURNING *
    `;
    const result = await pool.query(query, [req.userId, req.params.listener_id]);

    res.json({
      message: 'Added to favorites',
      favorite: result.rows[0]
    });
  } catch (error) {
    console.error('Add favorite error:', error);
    res.status(500).json({ error: 'Failed to add favorite' });
  }
});

// DELETE /api/users/favorites/:listener_id
// Remove listener from favorites
router.delete('/favorites/:listener_id', authenticate, async (req, res) => {
  try {
    await pool.query(
      'DELETE FROM favorites WHERE user_id = $1 AND listener_id = $2',
      [req.userId, req.params.listener_id]
    );

    res.json({ message: 'Removed from favorites' });
  } catch (error) {
    console.error('Remove favorite error:', error);
    res.status(500).json({ error: 'Failed to remove favorite' });
  }
});

// GET /api/users/favorites
// Get user's favorite listeners
router.get('/favorites', authenticate, async (req, res) => {
  try {
    const query = `
      SELECT l.*, u.display_name, u.city, u.country, f.created_at as favorited_at
      FROM favorites f
      JOIN listeners l ON f.listener_id = l.listener_id
      JOIN users u ON l.user_id = u.user_id
      WHERE f.user_id = $1
      ORDER BY f.created_at DESC
    `;
    const result = await pool.query(query, [req.userId]);

    res.json({ favorites: result.rows });
  } catch (error) {
    console.error('Get favorites error:', error);
    res.status(500).json({ error: 'Failed to fetch favorites' });
  }
});

// POST /api/users/block/:user_id
// Block a user
router.post('/block/:blocked_user_id', authenticate, async (req, res) => {
  try {
    const { reason } = req.body;

    const query = `
      INSERT INTO blocked_users (blocker_id, blocked_id, reason)
      VALUES ($1, $2, $3)
      ON CONFLICT (blocker_id, blocked_id) DO NOTHING
      RETURNING *
    `;
    const result = await pool.query(query, [req.userId, req.params.blocked_user_id, reason]);

    res.json({
      message: 'User blocked successfully',
      block: result.rows[0]
    });
  } catch (error) {
    console.error('Block user error:', error);
    res.status(500).json({ error: 'Failed to block user' });
  }
});

// DELETE /api/users/block/:user_id
// Unblock a user
router.delete('/block/:blocked_user_id', authenticate, async (req, res) => {
  try {
    await pool.query(
      'DELETE FROM blocked_users WHERE blocker_id = $1 AND blocked_id = $2',
      [req.userId, req.params.blocked_user_id]
    );

    res.json({ message: 'User unblocked successfully' });
  } catch (error) {
    console.error('Unblock user error:', error);
    res.status(500).json({ error: 'Failed to unblock user' });
  }
});

// GET /api/users/blocked
// Get blocked users list
router.get('/blocked', authenticate, async (req, res) => {
  try {
    const query = `
      SELECT u.user_id, u.display_name, u.avatar_url, b.created_at as blocked_at, b.reason
      FROM blocked_users b
      JOIN users u ON b.blocked_id = u.user_id
      WHERE b.blocker_id = $1
      ORDER BY b.created_at DESC
    `;
    const result = await pool.query(query, [req.userId]);

    res.json({ blocked_users: result.rows });
  } catch (error) {
    console.error('Get blocked users error:', error);
    res.status(500).json({ error: 'Failed to fetch blocked users' });
  }
});

// DELETE /api/users/account
// Delete user account
router.delete('/account', authenticate, async (req, res) => {
  try {
    await User.deactivate(req.userId);
    res.json({ message: 'Account deactivated successfully' });
  } catch (error) {
    console.error('Delete account error:', error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

// DELETE /api/users/:user_id
// Delete user (admin only)
router.delete('/:user_id', authenticateAdmin, async (req, res) => {
  try {
    const user = await User.findById(req.params.user_id);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    const deleted = await User.delete(req.params.user_id);
    if (!deleted) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.json({ message: 'User deleted successfully' });
  } catch (error) {
    console.error('Delete user error:', error);
    res.status(500).json({ error: 'Failed to delete user' });
  }
});

// GET /api/users/:user_id
// Get user by ID (public profile) — MUST be last to avoid catching /wallet, /favorites, etc.
router.get('/:user_id', async (req, res) => {
  try {
    const user = await User.findById(req.params.user_id);
    
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }

    // Return limited public info
    const publicProfile = {
      user_id: user.user_id,
      display_name: user.display_name,
      avatar_url: user.avatar_url,
      city: user.city,
      country: user.country,
      bio: user.bio
    };

    res.json({ user: publicProfile });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

export default router;
