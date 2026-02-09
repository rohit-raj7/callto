import express from 'express';
const router = express.Router();
import Listener from '../models/Listener.js';
import Rating from '../models/Rating.js';
import { pool } from '../db.js';
import { authenticate, authenticateAdmin } from '../middleware/auth.js';
import multer from 'multer';
import { v2 as cloudinary } from 'cloudinary';

// Configure Cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// Multer memory storage for voice uploads (no disk writes)
const voiceUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
  fileFilter: (req, file, cb) => {
    const allowed = ['audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/webm', 'audio/m4a', 'audio/mp4', 'audio/aac', 'audio/x-m4a'];
    if (allowed.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Unsupported audio type: ${file.mimetype}`), false);
    }
  },
});

// GET /api/listeners
// Get all listeners with filters-
router.get('/', async (req, res) => {
  try {
    const filters = {
      specialty: req.query.specialty,
      language: req.query.language,
      is_online: req.query.is_online !== undefined ? req.query.is_online === 'true' : undefined,
      min_rating: req.query.min_rating ? parseFloat(req.query.min_rating) : undefined,
      city: req.query.city,
      sort_by: req.query.sort_by || 'rating',
      limit: req.query.limit ? parseInt(req.query.limit) : 20,
      offset: req.query.offset ? parseInt(req.query.offset) : 0
    };

    console.log('[LISTENERS_ROUTE] Fetching listeners with filters:', filters);

    const listeners = await Listener.getAll(filters);
    console.log('[LISTENERS_ROUTE] Found', listeners.length, 'listeners from database');

    // Add avatar_url alias from profile_image and rating alias for frontend compatibility
    const listenersWithAvatar = listeners.map(listener => ({
      ...listener,
      avatar_url: listener.profile_image || null,
      rating: listener.average_rating || 0
    }));

    console.log('[LISTENERS_ROUTE] Returning', listenersWithAvatar.length, 'listeners');

    res.json({
      listeners: listenersWithAvatar,
      count: listenersWithAvatar.length,
      filters: filters
    });
  } catch (error) {
    console.error('Get listeners error:', error);
    res.status(500).json({ error: 'Failed to fetch listeners' });
  }
});

// GET /api/listeners/search
// Search listeners
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query;

    if (!q) {
      return res.status(400).json({ error: 'Search query is required' });
    }

    const listeners = await Listener.search(q);

    res.json({
      listeners,
      count: listeners.length,
      query: q
    });
  } catch (error) {
    console.error('Search listeners error:', error);
    res.status(500).json({ error: 'Failed to search listeners' });
  }
});

// POST /api/listeners/heartbeat
// Update listener last active timestamp
router.post('/heartbeat', authenticate, async (req, res) => {
  try {
    const listener = await Listener.findByUserId(req.userId);
    
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }

    await Listener.updateLastActive(listener.listener_id);
    
    res.json({ success: true });
  } catch (error) {
    console.error('Heartbeat error:', error);
    res.status(500).json({ error: 'Failed to update heartbeat' });
  }
});

// GET /api/listeners/:listener_id
// Get listener profile
router.get('/:listener_id', async (req, res) => {
  try {
    const listener = await Listener.findById(req.params.listener_id);

    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }

    // Map DB response to frontend-friendly keys (provide avatar_url alias)
    const responseListener = { ...listener };
    if (listener && listener.profile_image) {
      responseListener.avatar_url = listener.profile_image;
    }

    // Get listener stats
    const stats = await Listener.getStats(req.params.listener_id);

    // Get recent ratings
    const ratings = await Rating.getListenerRatings(req.params.listener_id, 5, 0);

    res.json({
      listener: responseListener,
      stats,
      recent_ratings: ratings
    });
  } catch (error) {
    console.error('Get listener error:', error);
    res.status(500).json({ error: 'Failed to fetch listener' });
  }
});

// POST /api/listeners
// Create listener profile (user becomes a listener)
router.post('/', authenticate, async (req, res) => {
  try {
    console.log('Creating listener profile with data:', req.body);
    console.log('User ID:', req.userId);

    const {
      professional_name,
      original_name,
      age,
      specialties,
      languages,
      rate_per_minute,
      experience_years,
      education,
      certifications,
      profile_image,
      city
    } = req.body;

    // Validate required fields
    if (!professional_name || rate_per_minute === undefined || rate_per_minute === null || !specialties || !languages) {
      return res.status(400).json({ 
        error: 'Professional name, rate, specialties, and languages are required' 
      });
    }

    // Validate data types
    const rateValue = parseFloat(rate_per_minute);
    if (isNaN(rateValue) || rateValue <= 0) {
      return res.status(400).json({ 
        error: 'Rate per minute must be a valid positive number' 
      });
    }

    // Check if user already has a listener profile
    const existingListener = await Listener.findByUserId(req.userId);
    console.log('Existing listener found:', existingListener ? existingListener.listener_id : 'none');
    
    let listener;
    if (existingListener) {
      // Update existing listener profile instead of rejecting
      console.log('Updating existing listener profile:', existingListener.listener_id);
      listener = await Listener.update(existingListener.listener_id, {
        professional_name,
        age: age ? parseInt(age) : undefined,
        specialties: Array.isArray(specialties) ? specialties : [specialties],
        languages: Array.isArray(languages) ? languages : [languages],
        rate_per_minute: rateValue,
        experience_years: experience_years ? parseInt(experience_years) : undefined,
        education,
        certifications: Array.isArray(certifications) ? certifications : [],
        profile_image
      });
    } else {
      // Create new listener profile
      listener = await Listener.create({
        user_id: req.userId,
        professional_name,
        age: age ? parseInt(age) : undefined,
        specialties: Array.isArray(specialties) ? specialties : [specialties],
        languages: Array.isArray(languages) ? languages : [languages],
        rate_per_minute: rateValue,
        experience_years: experience_years ? parseInt(experience_years) : undefined,
        education,
        certifications: Array.isArray(certifications) ? certifications : [],
        profile_image
      });

      // Update user account type
      await pool.query(
        "UPDATE users SET account_type = 'listener' WHERE user_id = $1",
        [req.userId]
      );
    }

    console.log('Listener profile saved successfully:', listener.listener_id);

    // Update user city if provided
    if (city) {
      await pool.query(
        "UPDATE users SET city = $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2",
        [city, req.userId]
      );
      console.log('User city updated to:', city);
    }

    res.status(201).json({
      message: 'Listener profile created successfully',
      listener
    });
  } catch (error) {
    console.error('Create listener error:', error);
    console.error('Error details:', {
      message: error.message,
      detail: error.detail,
      code: error.code,
      constraint: error.constraint
    });
    
    // Return more specific error messages
    if (error.code === '23505') { // Unique constraint violation
      return res.status(400).json({ 
        error: 'A listener profile already exists for this user' 
      });
    }
    
    if (error.code === '23503') { // Foreign key constraint
      return res.status(400).json({ 
        error: 'Invalid user reference' 
      });
    }

    res.status(500).json({ 
      error: error.message || 'Failed to create listener profile',
      details: process.env.NODE_ENV === 'development' ? error.detail : undefined
    });
  }
});

// PUT /api/listeners/:listener_id
// Update listener profile
router.put('/:listener_id', authenticate, async (req, res) => {
  try {
    // Log incoming data for easier debugging
    console.log('Update listener request body:', req.body);

    // Verify listener belongs to user
    const listener = await Listener.findById(req.params.listener_id);
    if (!listener) {
      console.error('Listener not found for update. listener_id:', req.params.listener_id, 'userId:', req.userId, 'Incoming body:', req.body);
      return res.status(404).json({ error: 'Listener profile not found. Please complete profile setup first (POST /api/listeners).' });
    }

    // Log gender for debugging
    console.log('Listener gender:', listener.gender);

    if (listener.user_id !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Create a shallow copy and normalize fields
    const incoming = { ...req.body };

    // Accept both `avatar_url` (frontend model expectation) and `profile_image` (DB column)
    if (incoming.avatar_url && !incoming.profile_image) {
      incoming.profile_image = incoming.avatar_url;
      delete incoming.avatar_url;
    }

    // Normalize specialties/languages/certifications: allow comma-separated strings
    ['specialties', 'languages', 'certifications'].forEach(field => {
      if (incoming[field] && typeof incoming[field] === 'string') {
        incoming[field] = incoming[field]
          .split(',')
          .map(s => s.trim())
          .filter(Boolean);
      }
    });

    // Only pass through expected fields; Listener.update will validate further
    const updatedListener = await Listener.update(req.params.listener_id, incoming);

    // If city is present in the request, update it in the users table
    if (typeof incoming.city === 'string' && incoming.city.trim() !== '') {
      try {
        // Update city in users table
        await import('../models/User.js').then(({ default: User }) =>
          User.update(listener.user_id, { city: incoming.city })
        );
      } catch (cityErr) {
        console.error('Failed to update city in users table:', cityErr);
        // Optionally, you can return an error or just log it
      }
    }

    // Map DB response to frontend-friendly keys (provide avatar_url alias)
    const responseListener = { ...updatedListener };
    if (updatedListener && updatedListener.profile_image) {
      responseListener.avatar_url = updatedListener.profile_image;
    }

    res.json({
      message: 'Listener profile updated successfully',
      listener: responseListener
    });
  } catch (error) {
    // Detailed error logging to assist debugging
    console.error('Update listener error:', {
      message: error.message,
      detail: error.detail,
      code: error.code,
      constraint: error.constraint,
      requestBody: req.body
    });

    res.status(500).json({
      error: 'Failed to update listener profile',
      details: process.env.NODE_ENV === 'development' ? {
        message: error.message,
        detail: error.detail,
        code: error.code,
        constraint: error.constraint
      } : undefined
    });
  }
});

// DELETE /api/listeners/:listener_id
// Delete listener (admin only)
router.delete('/:listener_id', authenticateAdmin, async (req, res) => {
  try {
    const listener = await Listener.findById(req.params.listener_id);
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }

    const deleted = await Listener.delete(req.params.listener_id);
    if (!deleted) {
      return res.status(404).json({ error: 'Listener not found' });
    }

    res.json({ message: 'Listener deleted successfully' });
  } catch (error) {
    console.error('Delete listener error:', error);
    res.status(500).json({ error: 'Failed to delete listener' });
  }
});

// PUT /api/listeners/:listener_id/status
// Update availability status (not online status, which is automatic)
router.put('/:listener_id/status', authenticate, async (req, res) => {
  try {
    const { is_available } = req.body;

    if (is_available === undefined) {
      return res.status(400).json({ error: 'is_available status is required' });
    }

    // Verify listener belongs to user
    const listener = await Listener.findById(req.params.listener_id);
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }
    if (listener.user_id !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Update only is_available, not is_online
    await Listener.update(req.params.listener_id, { is_available });

    res.json({
      message: 'Availability updated successfully'
    });
  } catch (error) {
    console.error('Update status error:', error);
    res.status(500).json({ error: 'Failed to update availability' });
  }
});

// GET /api/listeners/:listener_id/ratings
// Get listener ratings and reviews
router.get('/:listener_id/ratings', async (req, res) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit) : 20;
    const offset = req.query.offset ? parseInt(req.query.offset) : 0;

    const ratings = await Rating.getListenerRatings(
      req.params.listener_id,
      limit,
      offset
    );

    const averageData = await Rating.getListenerAverageRating(req.params.listener_id);

    res.json({
      ratings,
      count: ratings.length,
      average_rating: parseFloat(averageData.average_rating),
      total_ratings: parseInt(averageData.total_ratings)
    });
  } catch (error) {
    console.error('Get ratings error:', error);
    res.status(500).json({ error: 'Failed to fetch ratings' });
  }
});

// GET /api/listeners/:listener_id/stats
// Get listener statistics
router.get('/:listener_id/stats', async (req, res) => {
  try {
    const stats = await Listener.getStats(req.params.listener_id);

    res.json({ stats });
  } catch (error) {
    console.error('Get stats error:', error);
    res.status(500).json({ error: 'Failed to fetch statistics' });
  }
});

// POST /api/listeners/:listener_id/availability
// Set listener availability schedule
router.post('/:listener_id/availability', authenticate, async (req, res) => {
  try {
    const { day_of_week, start_time, end_time, is_available } = req.body;

    if (day_of_week === undefined || !start_time || !end_time) {
      return res.status(400).json({ 
        error: 'day_of_week, start_time, and end_time are required' 
      });
    }

    // Verify listener belongs to user
    const listener = await Listener.findById(req.params.listener_id);
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }
    if (listener.user_id !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const query = `
      INSERT INTO listener_availability 
        (listener_id, day_of_week, start_time, end_time, is_available)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `;

    const result = await pool.query(query, [
      req.params.listener_id,
      day_of_week,
      start_time,
      end_time,
      is_available !== false
    ]);

    res.json({
      message: 'Availability schedule added',
      availability: result.rows[0]
    });
  } catch (error) {
    console.error('Add availability error:', error);
    res.status(500).json({ error: 'Failed to add availability' });
  }
});

// GET /api/listeners/:listener_id/availability
// Get listener availability schedule
router.get('/:listener_id/availability', async (req, res) => {
  try {
    const query = `
      SELECT * FROM listener_availability
      WHERE listener_id = $1
      ORDER BY day_of_week, start_time
    `;
    const result = await pool.query(query, [req.params.listener_id]);

    res.json({ availability: result.rows });
  } catch (error) {
    console.error('Get availability error:', error);
    res.status(500).json({ error: 'Failed to fetch availability' });
  }
});

// GET /api/listeners/me/profile
// Get current user's listener profile
router.get('/me/profile', authenticate, async (req, res) => {
  try {
    const listener = await Listener.findByUserId(req.userId);

    if (!listener) {
      return res.status(404).json({ error: 'Listener profile not found' });
    }

    // Map DB response to frontend-friendly keys (provide avatar_url alias)
    const responseListener = { ...listener };
    if (listener && listener.profile_image) {
      responseListener.avatar_url = listener.profile_image;
    }

    const stats = await Listener.getStats(listener.listener_id);

    res.json({
      listener: responseListener,
      stats
    });
  } catch (error) {
    console.error('Get my profile error:', error);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PUT /api/listeners/me/payment-details
// Update payment details for current listener
router.put('/me/payment-details', authenticate, async (req, res) => {
  try {
    console.log('Updating payment details for user:', req.userId, 'Data:', req.body);

    // Get listener for current user
    const listener = await Listener.findByUserId(req.userId);
    if (!listener) {
      return res.status(404).json({ error: 'Listener profile not found' });
    }

    const {
      payment_method,
      mobile_number,
      upi_id,
      aadhaar_number,
      pan_number,
      name_as_per_pan,
      account_number,
      ifsc_code,
      bank_name,
      account_holder_name,
      pan_aadhaar_bank
    } = req.body;

    if (!payment_method || !['upi', 'bank', 'both'].includes(payment_method)) {
      return res.status(400).json({ error: 'Valid payment_method (upi/bank/both) is required' });
    }

    // Validate payment method fields
    if (payment_method === 'upi' || payment_method === 'both') {
      if (!upi_id) {
        return res.status(400).json({
          error: 'UPI method requires: upi_id'
        });
      }
    }
    
    if (payment_method === 'bank' || payment_method === 'both') {
      if (!account_number || !ifsc_code || !account_holder_name) {
        return res.status(400).json({
          error: 'Bank method requires: account_number, ifsc_code, account_holder_name'
        });
      }
    }

    // Try to create the table if it doesn't exist (for Vercel compatibility)
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS listener_payment_details (
          payment_detail_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          listener_id UUID UNIQUE REFERENCES listeners(listener_id) ON DELETE CASCADE,
          payment_method VARCHAR(20) CHECK (payment_method IN ('upi', 'bank', 'both')),
          mobile_number VARCHAR(15),
          upi_id VARCHAR(255),
          aadhaar_number VARCHAR(12),
          pan_number VARCHAR(10),
          name_as_per_pan VARCHAR(100),
          account_number VARCHAR(20),
          ifsc_code VARCHAR(11),
          bank_name VARCHAR(100),
          account_holder_name VARCHAR(100),
          pan_aadhaar_bank VARCHAR(20),
          is_verified BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
    } catch (tableError) {
      console.log('Table already exists or error creating table:', tableError.message);
    }

    const query = `
      INSERT INTO listener_payment_details (
        listener_id, payment_method, mobile_number, upi_id, aadhaar_number, pan_number, 
        name_as_per_pan, account_number, ifsc_code, bank_name, 
        account_holder_name, pan_aadhaar_bank
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      ON CONFLICT (listener_id) DO UPDATE SET
        payment_method = $2, mobile_number = $3, upi_id = $4, aadhaar_number = $5, pan_number = $6,
        name_as_per_pan = $7, account_number = $8, ifsc_code = $9, bank_name = $10,
        account_holder_name = $11, pan_aadhaar_bank = $12, updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `;

    const result = await pool.query(query, [
      listener.listener_id, payment_method, mobile_number || null, upi_id || null, aadhaar_number || null, pan_number || null,
      name_as_per_pan || null, account_number || null, ifsc_code || null, bank_name || null, account_holder_name || null, pan_aadhaar_bank || null
    ]);

    console.log('Payment details updated successfully for listener:', listener.listener_id);

    res.json({
      message: 'Payment details updated successfully',
      payment_details: result.rows[0]
    });
  } catch (error) {
    console.error('Update payment details error:', error);
    console.error('Error details:', {
      message: error.message,
      detail: error.detail,
      code: error.code,
      constraint: error.constraint,
      body: req.body
    });

    res.status(500).json({ 
      error: error.message || 'Failed to update payment details',
      details: process.env.NODE_ENV === 'development' ? error.detail : undefined
    });
  }
});

// PUT /api/listeners/:listener_id/experiences
// Update listener experiences
router.put('/:listener_id/experiences', authenticate, async (req, res) => {
  try {
    console.log('Update experiences request body:', req.body);
    let { experiences, yearsOfExperience, expertise } = req.body;

    // Accept both array and string for experiences
    if (typeof experiences === 'string') {
      experiences = experiences.split(',').map(s => s.trim()).filter(Boolean);
    }
    if (!Array.isArray(experiences)) {
      return res.status(400).json({ error: 'Experiences must be an array or comma-separated string' });
    }

    // Verify listener belongs to user
    const listener = await Listener.findById(req.params.listener_id);
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }
    if (listener.user_id !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Update experiences array
    const result = await Listener.updateExperiences(req.params.listener_id, experiences);

    // Optionally update yearsOfExperience and expertise if present
    const updateFields = {};
    if (yearsOfExperience !== undefined) {
      updateFields.experience_years = parseInt(yearsOfExperience) || 0;
    }
    if (expertise !== undefined) {
      updateFields.specialties = Array.isArray(expertise)
        ? expertise
        : (typeof expertise === 'string' ? expertise.split(',').map(s => s.trim()).filter(Boolean) : undefined);
    }
    if (Object.keys(updateFields).length > 0) {
      await Listener.update(req.params.listener_id, updateFields);
    }

    res.json({
      message: 'Experiences updated successfully',
      experiences: result.experiences
    });
  } catch (error) {
    console.error('Update experiences error:', error);
    res.status(500).json({ error: 'Failed to update experiences' });
  }
});

// POST /api/listeners/upload-voice
// Upload voice recording to Cloudinary (returns secure_url)
router.post('/upload-voice', authenticate, voiceUpload.single('voiceFile'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file provided. Send as multipart field "voiceFile".' });
    }

    console.log(`[UPLOAD_VOICE] Uploading ${req.file.originalname} (${req.file.mimetype}, ${req.file.size} bytes) for user ${req.userId}`);

    // Upload buffer to Cloudinary via stream
    const result = await new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          resource_type: 'video', // Cloudinary uses 'video' for audio files
          folder: 'callto/voice_verifications',
          public_id: `voice_${req.userId}_${Date.now()}`,
          format: 'mp3', // Normalize to mp3 for browser compatibility
        },
        (error, result) => {
          if (error) reject(error);
          else resolve(result);
        }
      );
      stream.end(req.file.buffer);
    });

    console.log(`[UPLOAD_VOICE] Cloudinary upload success: ${result.secure_url}`);

    res.json({
      message: 'Voice uploaded successfully',
      secure_url: result.secure_url,
      public_id: result.public_id,
      duration: result.duration,
      format: result.format,
    });
  } catch (error) {
    console.error('Upload voice error:', error);
    res.status(500).json({ error: error.message || 'Failed to upload voice to Cloudinary' });
  }
});

// PUT /api/listeners/:listener_id/voice-verification
// Update voice verification status
router.put('/:listener_id/voice-verification', authenticate, async (req, res) => {
  try {
    const { voice_url, voice_data, mime_type } = req.body;

    // Accept either a URL or base64 audio data
    let finalVoiceUrl = voice_url;

    if (!finalVoiceUrl && voice_data) {
      // voice_data is base64-encoded audio — store as data URL
      const mimeType = mime_type || 'audio/ogg';
      finalVoiceUrl = `data:${mimeType};base64,${voice_data}`;
    }

    if (!finalVoiceUrl) {
      return res.status(400).json({ error: 'Voice URL or voice data is required' });
    }

    // Verify listener belongs to user
    const listener = await Listener.findById(req.params.listener_id);
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }
    if (listener.user_id !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    const result = await Listener.updateVoiceVerification(req.params.listener_id, finalVoiceUrl);

    res.json({
      message: 'Voice verification updated successfully',
      voice_verified: result.voice_verified
    });
  } catch (error) {
    console.error('Update voice verification error:', error);
    res.status(500).json({ error: 'Failed to update voice verification' });
  }
});

// POST /api/listeners/:listener_id/payment-details
// Add or update payment details for listener
router.post('/:listener_id/payment-details', authenticate, async (req, res) => {
  try {
    console.log('Saving payment details for listener:', req.params.listener_id, 'Data:', req.body);

    const {
      payment_method,
      mobile_number,
      upi_id,
      aadhaar_number,
      pan_number,
      name_as_per_pan,
      account_number,
      ifsc_code,
      bank_name,
      account_holder_name,
      pan_aadhaar_bank
    } = req.body;

    if (!payment_method || !['upi', 'bank', 'both'].includes(payment_method)) {
      return res.status(400).json({ error: 'Valid payment_method (upi/bank/both) is required' });
    }

    // Verify listener belongs to user
    const listener = await Listener.findById(req.params.listener_id);
    if (!listener) {
      return res.status(404).json({ error: 'Listener not found' });
    }
    if (listener.user_id !== req.userId) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Validate payment method fields
    if (payment_method === 'upi' || payment_method === 'both') {
      if (!upi_id) {
        return res.status(400).json({
          error: 'UPI method requires: upi_id'
        });
      }
    }
    
    if (payment_method === 'bank' || payment_method === 'both') {
      if (!account_number || !ifsc_code || !account_holder_name) {
        return res.status(400).json({
          error: 'Bank method requires: account_number, ifsc_code, account_holder_name'
        });
      }
    }

    // Try to create the table if it doesn't exist (for Vercel compatibility)
    try {
      await pool.query(`
        CREATE TABLE IF NOT EXISTS listener_payment_details (
          payment_detail_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
          listener_id UUID UNIQUE REFERENCES listeners(listener_id) ON DELETE CASCADE,
          payment_method VARCHAR(20) CHECK (payment_method IN ('upi', 'bank', 'both')),
          mobile_number VARCHAR(15),
          upi_id VARCHAR(255),
          aadhaar_number VARCHAR(12),
          pan_number VARCHAR(10),
          name_as_per_pan VARCHAR(100),
          account_number VARCHAR(20),
          ifsc_code VARCHAR(11),
          bank_name VARCHAR(100),
          account_holder_name VARCHAR(100),
          pan_aadhaar_bank VARCHAR(20),
          is_verified BOOLEAN DEFAULT FALSE,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
      `);
    } catch (tableError) {
      console.log('Table already exists or error creating table:', tableError.message);
    }

    const query = `
      INSERT INTO listener_payment_details (
        listener_id, payment_method, mobile_number, upi_id, aadhaar_number, pan_number, 
        name_as_per_pan, account_number, ifsc_code, bank_name, 
        account_holder_name, pan_aadhaar_bank
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      ON CONFLICT (listener_id) DO UPDATE SET
        payment_method = $2, mobile_number = $3, upi_id = $4, aadhaar_number = $5, pan_number = $6,
        name_as_per_pan = $7, account_number = $8, ifsc_code = $9, bank_name = $10,
        account_holder_name = $11, pan_aadhaar_bank = $12, updated_at = CURRENT_TIMESTAMP
      RETURNING *
    `;

    const result = await pool.query(query, [
      req.params.listener_id, payment_method, mobile_number || null, upi_id || null, aadhaar_number || null, pan_number || null,
      name_as_per_pan || null, account_number || null, ifsc_code || null, bank_name || null, account_holder_name || null, pan_aadhaar_bank || null
    ]);

    console.log('Payment details saved successfully for listener:', req.params.listener_id);

    res.status(201).json({
      message: 'Payment details saved successfully',
      payment_details: result.rows[0]
    });
  } catch (error) {
    console.error('Add payment details error:', error);
    console.error('Error details:', {
      message: error.message,
      detail: error.detail,
      code: error.code,
      constraint: error.constraint,
      body: req.body
    });

    if (error.code === '23505') { // Unique constraint violation
      return res.status(400).json({ 
        error: 'Payment details already exist for this listener' 
      });
    }

    if (error.code === '23503') { // Foreign key constraint
      return res.status(400).json({ 
        error: 'Invalid listener reference' 
      });
    }

    res.status(500).json({ 
      error: error.message || 'Failed to save payment details',
      details: process.env.NODE_ENV === 'development' ? error.detail : undefined
    });
  }
});

// GET /api/listeners/random
// Get a random available listener (for random calls)
router.get('/random', async (req, res) => {
  try {
    const limit = req.query.limit ? parseInt(req.query.limit) : 1;
    const excludeListenerId = req.query.exclude || null;

    const listeners = await Listener.getRandomAvailable(limit, excludeListenerId);

    if (listeners.length === 0) {
      return res.status(404).json({ error: 'No available listeners found' });
    }

    res.json({
      listeners,
      count: listeners.length
    });
  } catch (error) {
    console.error('Get random listeners error:', error);
    res.status(500).json({ error: 'Failed to fetch random listeners' });
  }
});

export default router;
