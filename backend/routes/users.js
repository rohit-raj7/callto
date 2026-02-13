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

// GET /api/users/offer-banner
// Returns active offer banner only for eligible users (wallet below threshold)
router.get('/offer-banner', authenticate, async (req, res) => {
  try {
    await pool.query(
      `INSERT INTO wallets (user_id, balance)
       VALUES ($1, 0.0)
       ON CONFLICT (user_id) DO NOTHING`,
      [req.userId]
    );

    const [walletResult, activeNonExpiredResult, activeAnyResult] = await Promise.all([
      pool.query('SELECT balance FROM wallets WHERE user_id = $1 LIMIT 1', [req.userId]),
      // 1) Try to find an active, non-expired banner
      pool.query(
        `SELECT config_id, title, headline, subtext, button_text, countdown_prefix,
                min_wallet_balance, expires_at, is_active, updated_at
         FROM offer_banner_config
         WHERE is_active = TRUE
           AND (starts_at IS NULL OR starts_at <= CURRENT_TIMESTAMP)
           AND expires_at > CURRENT_TIMESTAMP
         ORDER BY updated_at DESC
         LIMIT 1`
      ),
      // 2) Also fetch any active banner (even if expired) for auto-extend
      pool.query(
        `SELECT config_id, title, headline, subtext, button_text, countdown_prefix,
                min_wallet_balance, expires_at, is_active, updated_at
         FROM offer_banner_config
         WHERE is_active = TRUE
         ORDER BY updated_at DESC
         LIMIT 1`
      ),
    ]);

    const walletBalance = Number(walletResult.rows[0]?.balance ?? 0);
    let activeBanner = activeNonExpiredResult.rows[0];

    // Auto-extend: if there's an active banner but it's expired, extend by 12 hours
    if (!activeBanner && activeAnyResult.rows[0]) {
      const expiredBanner = activeAnyResult.rows[0];
      const newStartsAt = new Date();
      const newExpiresAt = new Date(Date.now() + 12 * 60 * 60 * 1000);

      console.log('[offer-banner] Auto-extending expired active banner:', expiredBanner.config_id,
        'old expires_at:', expiredBanner.expires_at, '-> new expires_at:', newExpiresAt);

      const updated = await pool.query(
        `UPDATE offer_banner_config
         SET starts_at = $1, expires_at = $2, updated_at = CURRENT_TIMESTAMP
         WHERE config_id = $3
         RETURNING config_id, title, headline, subtext, button_text, countdown_prefix,
                   min_wallet_balance, expires_at, is_active, updated_at`,
        [newStartsAt, newExpiresAt, expiredBanner.config_id]
      );
      activeBanner = updated.rows[0] || null;
    }

    console.log('[offer-banner] userId:', req.userId, '| walletBalance:', walletBalance,
      '| activeBannerFound:', Boolean(activeBanner));

    if (!activeBanner) {
      return res.json({
        activeOffer: false,
        walletBalance,
        reason: 'none_active',
      });
    }

    const minWalletBalance = 5;
    if (walletBalance >= minWalletBalance) {
      return res.json({
        activeOffer: false,
        walletBalance,
        minWalletBalance,
        reason: 'wallet_sufficient',
      });
    }

    res.json({
      activeOffer: true,
      walletBalance,
      minWalletBalance,
      offerBanner: {
        offerId: activeBanner.config_id,
        title: activeBanner.title,
        headline: activeBanner.headline,
        subtext: activeBanner.subtext,
        buttonText: activeBanner.button_text,
        countdownPrefix: activeBanner.countdown_prefix,
        expiresAt: activeBanner.expires_at,
        isActive: activeBanner.is_active === true,
        updatedAt: activeBanner.updated_at,
      },
    });
  } catch (error) {
    console.error('Get offer banner error:', error);
    res.status(500).json({ error: 'Failed to fetch offer banner' });
  }
});

// POST /api/users/wallet/add
// Add balance to wallet after successful payment
router.post('/wallet/add', authenticate, async (req, res) => {
  try {
    const { amount, payment_id, payment_method, description, pack_id } = req.body;
    const parsedAmount = Number(amount);

    if (!Number.isFinite(parsedAmount) || parsedAmount <= 0) {
      return res.status(400).json({ error: 'Valid amount is required' });
    }

    // Calculate extra bonus from recharge pack
    let bonusAmount = 0;
    if (pack_id) {
      const packResult = await pool.query(
        'SELECT extra_percent_or_amount FROM recharge_packs WHERE id = $1 AND is_active = TRUE',
        [pack_id]
      );
      if (packResult.rows.length > 0) {
        const extraPercent = Number(packResult.rows[0].extra_percent_or_amount) || 0;
        bonusAmount = Number((parsedAmount * extraPercent / 100).toFixed(2));
      }
    }

    const totalCredit = Number((parsedAmount + bonusAmount).toFixed(2));

    const paymentDetails = {
      payment_id,
      payment_method: payment_method || 'razorpay',
      description: bonusAmount > 0
        ? `Wallet recharge ₹${parsedAmount} + ₹${bonusAmount} extra bonus`
        : description || 'Wallet recharge',
      currency: 'INR'
    };

    const wallet = await User.addBalance(req.userId, totalCredit, paymentDetails);
    res.json({
      message: 'Balance added successfully',
      balance: wallet.balance,
      base_amount: parsedAmount,
      bonus_amount: bonusAmount,
      total_credited: totalCredit,
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
