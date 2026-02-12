import express from 'express';
import jwt from 'jsonwebtoken';
import axios from 'axios';
import { OAuth2Client } from 'google-auth-library';

import User from '../models/User.js';
import Listener from '../models/Listener.js';
import { pool, getRateConfig } from '../db.js';
import { authenticate } from '../middleware/auth.js';

const router = express.Router();
const googleClient = new OAuth2Client(process.env.google_client_id);

/**
 * =====================================================
 * SOCIAL LOGIN / SIGNUP (SAME BUTTON)
 * Google + Facebook
 * =====================================================
 */
router.post('/social-login', async (req, res) => {
  try {
    const { provider, token, fcm_token } = req.body;

    if (!provider || !token) {
      return res.status(400).json({ error: 'provider and token are required' });
    }

    if (!['google', 'facebook'].includes(provider)) {
      return res.status(400).json({ error: 'Unsupported provider' });
    }

    let userInfo;

    // ===================== GOOGLE =====================
    if (provider === 'google') {
      try {
        // First, try to verify as ID token
        const ticket = await googleClient.verifyIdToken({
          idToken: token,
          audience: process.env.google_client_id,
        });

        const payload = ticket.getPayload();

        userInfo = {
          provider_user_id: payload.sub,
          email: payload.email,
          full_name: payload.name,
          display_name: payload.given_name || payload.name,
          avatar_url: payload.picture,
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
            provider_user_id: googleUser.sub,
            email: googleUser.email,
            full_name: googleUser.name,
            display_name: googleUser.given_name || googleUser.name,
            avatar_url: googleUser.picture,
          };
        } catch (accessTokenError) {
          console.error('Google token verification failed:', accessTokenError);
          return res.status(401).json({ error: 'Invalid Google token' });
        }
      }
    }

    // ===================== FACEBOOK =====================
    if (provider === 'facebook') {
      const appToken = `${process.env.facebook_app_id}|${process.env.facebook_app_secret}`;

      const debug = await axios.get(
        `https://graph.facebook.com/debug_token?input_token=${token}&access_token=${appToken}`
      );

      if (!debug.data.data.is_valid) {
        return res.status(401).json({ error: 'Invalid Facebook token' });
      }

      const fbRes = await axios.get(
        `https://graph.facebook.com/me?fields=id,email,name,first_name,picture&access_token=${token}`
      );

      const fb = fbRes.data;

      userInfo = {
        provider_user_id: fb.id,
        email: fb.email,
        full_name: fb.name,
        display_name: fb.first_name || fb.name,
        avatar_url: fb.picture?.data?.url,
      };
    }

    // ===================== FIND USER =====================
    let user = await User.findByProvider(provider, userInfo.provider_user_id);
    let isNewUser = false;

    // Try matching by email and link provider
    if (!user && userInfo.email) {
      const existingByEmail = await User.findByEmail(userInfo.email);
      if (existingByEmail) {
        user = await User.linkProvider(
          existingByEmail.user_id,
          provider,
          userInfo.provider_user_id
        );
      }
    }

    // ===================== CREATE USER =====================
    if (!user) {
      const rateConfig = await getRateConfig();
      const isFirstTimeUser = true; // All new users are first-time users
      user = await User.create({
        phone_number: null,
        email: userInfo.email || null,
        auth_provider: provider,
        google_id: provider === 'google' ? userInfo.provider_user_id : null,
        facebook_id: provider === 'facebook' ? userInfo.provider_user_id : null,
        full_name: userInfo.full_name,
        display_name: userInfo.display_name,
        avatar_url: userInfo.avatar_url,
        account_type: 'user',
        is_first_time_user: isFirstTimeUser,
        offer_used: false,
        offer_minutes_limit: rateConfig?.offer_minutes_limit,
        offer_flat_price: rateConfig?.offer_flat_price
      });
      isNewUser = true;
    } else {
      await User.updateLastLogin(user.user_id);
      if (fcm_token) {
        await User.update(user.user_id, { fcm_token });
      }
    }

    await User.verifyUser(user.user_id);

    // ===================== JWT =====================
    const jwtToken = jwt.sign(
      {
        user_id: user.user_id,
        provider,
        email: user.email,
      },
      process.env.JWT_SECRET,
      { expiresIn: '30d' }
    );

    return res.json({
      message: isNewUser ? 'Signup successful' : 'Login successful',
      token: jwtToken,
      user: await User.findById(user.user_id),
      isNewUser,
    });

  } catch (error) {
    console.error('Social login error:', error);
    return res.status(500).json({ error: 'Social authentication failed' });
  }
});

/**
 * =====================================================
 * COMPLETE PROFILE AFTER SOCIAL LOGIN
 * =====================================================
 */
router.post('/register', authenticate, async (req, res) => {
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
      fcm_token,
      original_name,
      rate_per_minute,
      languages,
    } = req.body;

    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });

    let accountType = 'user';
    if (gender && gender.toLowerCase() === 'female') {
      accountType = 'listener';
    }

    await User.update(user.user_id, {
      email,
      full_name,
      display_name,
      gender,
      date_of_birth,
      city,
      country,
      avatar_url,
      bio,
      fcm_token,
    });

    if (accountType === 'listener') {
      if (!display_name || !rate_per_minute || !languages) {
        return res.status(400).json({
          error: 'Listener requires display_name, rate_per_minute, languages',
        });
      }

      const listener = await Listener.create({
        user_id: user.user_id,
        original_name: original_name || full_name,
        professional_name: display_name,
        languages: Array.isArray(languages) ? languages : [languages],
        rate_per_minute: parseFloat(rate_per_minute),
        profile_image: avatar_url,
        experience_years: 0,
      });

      await pool.query(
        "UPDATE users SET account_type = 'listener' WHERE user_id = $1",
        [user.user_id]
      );

      return res.json({
        message: 'Listener profile created',
        user: await User.findById(user.user_id),
        listener,
        accountType: 'listener',
      });
    }

    await pool.query(
      "UPDATE users SET account_type = 'user' WHERE user_id = $1",
      [user.user_id]
    );

    return res.json({
      message: 'Profile updated',
      user: await User.findById(user.user_id),
      accountType: 'user',
    });

  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: 'Profile update failed' });
  }
});

/**
 * =====================================================
 * GET CURRENT USER
 * =====================================================
 */
router.get('/me', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ user });
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

export default router;
