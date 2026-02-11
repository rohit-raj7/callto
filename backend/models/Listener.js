import { pool } from '../db.js';

class Listener {
  // Create new listener profile
  static async create(listenerData) {
    const {
      user_id,
      original_name,
      professional_name,
      age,
      specialties = [],
      experiences = [],
      languages = [],
      rate_per_minute,
      currency = 'INR',
      profile_image,
      experience_years,
      education,
      certifications = [],
      mobile_number
    } = listenerData;

    try {
      // Ensure arrays are properly formatted for PostgreSQL
      const sanitizedSpecialties = Array.isArray(specialties) ? specialties : [];
      const sanitizedLanguages = Array.isArray(languages) ? languages : [];
      const sanitizedCertifications = Array.isArray(certifications) ? certifications : [];

      // Note: original_name column may not exist in all databases
      // experiences should be updated separately via updateExperiences() method
      // to avoid database compatibility issues
      const normalizedRate = Number(rate_per_minute || 0);
      const userRatePerMin = Number.isFinite(normalizedRate) && normalizedRate > 0
        ? normalizedRate
        : 4.0;
      const payoutRatePerMin = Number.isFinite(normalizedRate) && normalizedRate > 0
        ? Number((normalizedRate * 0.25).toFixed(2))
        : 1.0;

      const query = `
        INSERT INTO listeners (
          user_id, professional_name, age, specialties, languages,
          rate_per_minute, user_rate_per_min, listener_payout_per_min,
          currency, profile_image, experience_years,
          education, certifications, mobile_number, verification_status
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'pending')
        RETURNING *
      `;

      const values = [
        user_id,
        professional_name,
        age || null,
        sanitizedSpecialties,
        sanitizedLanguages,
        normalizedRate || userRatePerMin,
        userRatePerMin,
        payoutRatePerMin,
        currency,
        profile_image || null,
        experience_years || null,
        education || null,
        sanitizedCertifications,
        mobile_number || null
      ];

      const result = await pool.query(query, values);
      return result.rows[0];
    } catch (error) {
      console.error('Error creating listener in database:', error.message, error.detail);
      throw error;
    }
  }

  // Update listener experiences (separate from creation)
  static async updateExperiences(listener_id, experiences) {
    const query = `
      UPDATE listeners 
      SET experiences = $1, updated_at = CURRENT_TIMESTAMP
      WHERE listener_id = $2
      RETURNING experiences
    `;
    const result = await pool.query(query, [experiences, listener_id]);
    return result.rows[0];
  }

  // Get listener by user_id
  static async findByUserId(user_id) {
    const query = `
      SELECT l.*, u.phone_number, u.email, u.city, u.country,
        pd.payment_method, pd.upi_id, pd.aadhaar_number, pd.pan_number, pd.name_as_per_pan,
        pd.account_number, pd.ifsc_code, pd.bank_name, pd.account_holder_name, pd.pan_aadhaar_bank,
        pd.is_verified as payment_verified
      FROM listeners l
      JOIN users u ON l.user_id = u.user_id
      LEFT JOIN listener_payment_details pd ON l.listener_id = pd.listener_id
      WHERE l.user_id = $1
    `;
    const result = await pool.query(query, [user_id]);
    const listener = result.rows[0];
    
    if (listener) {
      // Structure payment info
      if (listener.payment_method) {
        listener.payment_info = {
          payment_method: listener.payment_method,
          upi_id: listener.upi_id,
          aadhaar_number: listener.aadhaar_number,
          pan_number: listener.pan_number,
          name_as_per_pan: listener.name_as_per_pan,
          account_number: listener.account_number,
          ifsc_code: listener.ifsc_code,
          bank_name: listener.bank_name,
          account_holder_name: listener.account_holder_name,
          pan_aadhaar_bank: listener.pan_aadhaar_bank,
          payout_status: listener.payment_verified ? 'verified' : 'pending',
          payout_currency: listener.currency || 'INR'
        };
      }
      
      // Clean up individual payment fields
      delete listener.payment_method;
      delete listener.upi_id;
      delete listener.aadhaar_number;
      delete listener.pan_number;
      delete listener.name_as_per_pan;
      delete listener.account_number;
      delete listener.ifsc_code;
      delete listener.bank_name;
      delete listener.account_holder_name;
      delete listener.pan_aadhaar_bank;
      delete listener.payment_verified;
    }
    
    return listener;
  }

  // Get listener by listener_id
  static async findById(listener_id) {
    const query = `
      SELECT l.*, u.phone_number, u.email, u.city, u.country, u.display_name,
        CASE 
          WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
          THEN true 
          ELSE false 
        END as is_online,
        pd.payment_method, pd.upi_id, pd.aadhaar_number, pd.pan_number, pd.name_as_per_pan,
        pd.account_number, pd.ifsc_code, pd.bank_name, pd.account_holder_name, pd.pan_aadhaar_bank,
        pd.is_verified as payment_verified
      FROM listeners l
      JOIN users u ON l.user_id = u.user_id
      LEFT JOIN listener_payment_details pd ON l.listener_id = pd.listener_id
      WHERE l.listener_id = $1
    `;
    const result = await pool.query(query, [listener_id]);
    const listener = result.rows[0];
    
    if (listener) {
      // Structure payment info
      if (listener.payment_method) {
        listener.payment_info = {
          payment_method: listener.payment_method,
          upi_id: listener.upi_id,
          aadhaar_number: listener.aadhaar_number,
          pan_number: listener.pan_number,
          name_as_per_pan: listener.name_as_per_pan,
          account_number: listener.account_number,
          ifsc_code: listener.ifsc_code,
          bank_name: listener.bank_name,
          account_holder_name: listener.account_holder_name,
          pan_aadhaar_bank: listener.pan_aadhaar_bank,
          payout_status: listener.payment_verified ? 'verified' : 'pending',
          payout_currency: listener.currency || 'INR'
        };
      }
      
      // Clean up individual fields
      delete listener.payment_method;
      delete listener.upi_id;
      delete listener.aadhaar_number;
      delete listener.pan_number;
      delete listener.name_as_per_pan;
      delete listener.account_number;
      delete listener.ifsc_code;
      delete listener.bank_name;
      delete listener.account_holder_name;
      delete listener.pan_aadhaar_bank;
      delete listener.payment_verified;
    }
    
    return listener;
  }

  // Get all listeners with filters
  static async getAll(filters = {}) {
    let query = `
      SELECT
        l.listener_id,
        l.user_id,
        l.professional_name,
        l.age,
        l.specialties,
        l.languages,
        l.profile_image,
        l.average_rating,
        l.total_ratings,
        l.total_calls,
        l.total_minutes,
        l.is_available,
        l.verification_status,
        l.user_rate_per_min,
        COALESCE(l.is_busy, false) as is_busy,
        u.city,
        u.country,
        u.display_name,
        CASE 
          WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
          THEN true 
          ELSE false 
        END as is_online,
        CASE 
          WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
          THEN 1 
          ELSE 0 
        END as online_sort
      FROM listeners l
      JOIN users u ON l.user_id = u.user_id
      WHERE u.is_active = TRUE
        AND l.is_active = TRUE
        AND COALESCE(l.verification_status, 'approved') = 'approved' -- VERIFICATION CHECK: Only show approved listeners
    `;
    const values = [];
    let paramIndex = 1;

    // Only filter by is_available if explicitly requested
    if (filters.is_available !== undefined) {
      query += ` AND l.is_available = $${paramIndex}`;
      values.push(filters.is_available);
      paramIndex++;
    }

    // Filter by specialty
    if (filters.specialty) {
      query += ` AND $${paramIndex} = ANY(l.specialties)`;
      values.push(filters.specialty);
      paramIndex++;
    }

    // Filter by language
    if (filters.language) {
      query += ` AND $${paramIndex} = ANY(l.languages)`;
      values.push(filters.language);
      paramIndex++;
    }

    // Filter by online status - filter based on calculated is_online
    if (filters.is_online !== undefined) {
      if (filters.is_online) {
        query += ` AND l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes'`;
      } else {
        query += ` AND (l.last_active_at IS NULL OR (NOW() - l.last_active_at) > INTERVAL '2 minutes')`;
      }
    }

    // Filter by minimum rating
    if (filters.min_rating) {
      query += ` AND l.average_rating >= $${paramIndex}`;
      values.push(filters.min_rating);
      paramIndex++;
    }

    // Filter by city
    if (filters.city) {
      query += ` AND u.city ILIKE $${paramIndex}`;
      values.push(`%${filters.city}%`);
      paramIndex++;
    }

    // Sort by online status first (online listeners first), then by rating
    const sortBy = filters.sort_by || 'rating';
    let orderClause = ' ORDER BY online_sort DESC';
    
    if (sortBy === 'rating') {
      orderClause += ', l.average_rating DESC, l.total_ratings DESC';
    } else if (sortBy === 'recent') {
      orderClause += ', l.created_at DESC';
    } else if (sortBy === 'price_low') {
      orderClause += ', l.user_rate_per_min ASC';
    } else if (sortBy === 'price_high') {
      orderClause += ', l.user_rate_per_min DESC';
    }
    
    query += orderClause;

    // Pagination
    const limit = filters.limit || 20;
    const offset = filters.offset || 0;
    query += ` LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    values.push(limit, offset);

    const result = await pool.query(query, values);
    
    return result.rows;
  }

  // Search listeners by name, specialty, or city
  static async search(searchTerm) {
    const query = `
      SELECT
        l.listener_id,
        l.user_id,
        l.professional_name,
        l.age,
        l.specialties,
        l.languages,
        l.profile_image,
        l.average_rating,
        l.total_ratings,
        l.total_calls,
        l.total_minutes,
        l.is_available,
        l.verification_status,
        l.user_rate_per_min,
        COALESCE(l.is_busy, false) as is_busy,
        u.city,
        u.country,
        u.display_name,
        CASE 
          WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
          THEN true 
          ELSE false 
        END as is_online,
        CASE 
          WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
          THEN 1 
          ELSE 0 
        END as online_sort
      FROM listeners l
      JOIN users u ON l.user_id = u.user_id
      WHERE u.is_active = TRUE
        AND l.is_active = TRUE
        AND COALESCE(l.verification_status, 'approved') = 'approved' -- VERIFICATION CHECK: Only show approved listeners
        AND (
          l.professional_name ILIKE $1 
          OR u.city ILIKE $1
          OR EXISTS (
            SELECT 1 FROM unnest(l.specialties) AS specialty 
            WHERE specialty ILIKE $1
          )
        )
      ORDER BY online_sort DESC, l.average_rating DESC
      LIMIT 20
    `;
    
    const result = await pool.query(query, [`%${searchTerm}%`]);
    
    return result.rows;
  }

  // Get all listeners for admin with online status
  static async getAllForAdmin() {
    const query = `
      SELECT
        l.listener_id,
        l.user_id,
        COALESCE(l.professional_name, u.display_name) as name,
        l.age,
        l.rate_per_minute,
        l.user_rate_per_min,
        l.listener_payout_per_min,
        l.currency,
        l.average_rating,
        l.total_ratings,
        l.is_available,
        l.is_verified,
        l.verification_status,
        l.total_earning,
        l.wallet_balance,
        l.is_active,
        l.created_at,
        l.updated_at,
        l.last_active_at,
        l.mobile_number,
        CASE 
          WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
          THEN true 
          ELSE false 
        END as is_online,
        u.display_name as user_display_name,
        u.email,
        u.phone_number,
        u.city,
        u.country,
        u.is_active as user_active,
        u.created_at as user_created_at,
        COALESCE(r_agg.computed_avg_rating, 0) as computed_avg_rating,
        COALESCE(r_agg.computed_total_ratings, 0) as computed_total_ratings,
        COALESCE(c_agg.total_call_minutes, 0) as total_call_minutes,
        COALESCE(c_agg.total_calls, 0) as total_calls
      FROM listeners l
      JOIN users u ON l.user_id = u.user_id
      LEFT JOIN (
        SELECT listener_id,
               ROUND(AVG(rating)::numeric, 2) as computed_avg_rating,
               COUNT(*) as computed_total_ratings
        FROM ratings
        GROUP BY listener_id
      ) r_agg ON r_agg.listener_id = l.listener_id
      LEFT JOIN (
        SELECT listener_id,
               ROUND((COALESCE(SUM(duration_seconds), 0) / 60.0)::numeric, 1) as total_call_minutes,
               COUNT(*) as total_calls
        FROM calls
        WHERE status = 'completed'
        GROUP BY listener_id
      ) c_agg ON c_agg.listener_id = l.listener_id
    `;
    const result = await pool.query(query);

    const listeners = result.rows.map(row => {
      return {
        listener_id: row.listener_id,
        user_id: row.user_id,
        name: row.name,
        age: row.age,
        rate_per_minute: row.rate_per_minute,
        user_rate_per_min: row.user_rate_per_min,
        listener_payout_per_min: row.listener_payout_per_min,
        currency: row.currency,
        average_rating: row.average_rating,
        total_ratings: row.total_ratings,
        is_available: row.is_available,
        is_verified: row.is_verified,
        verification_status: row.verification_status,
        total_earning: row.total_earning,
        wallet_balance: row.wallet_balance,
        is_active: row.is_active,
        created_at: row.created_at,
        updated_at: row.updated_at,
        last_active_at: row.last_active_at,
        is_online: row.is_online,
        user_display_name: row.user_display_name,
        email: row.email,
        phone_number: row.phone_number,
        mobile_number: row.mobile_number,
        city: row.city,
        country: row.country,
        user_active: row.user_active,
        user_created_at: row.user_created_at,
        computed_avg_rating: parseFloat(row.computed_avg_rating) || 0,
        computed_total_ratings: parseInt(row.computed_total_ratings) || 0,
        total_call_minutes: parseFloat(row.total_call_minutes) || 0,
        total_calls: parseInt(row.total_calls) || 0
      };
    });

    return listeners;
  }

  // Update listener profile
  static async update(listener_id, updateData) {
    // Accept frontend keys and map to DB columns when needed
    const allowedFields = [
      'professional_name', 'age', 'specialties', 'languages',
      'profile_image', 'background_image',
      'experience_years', 'education', 'certifications', 'is_available', 'is_online',
      'mobile_number',
      // allow alias from frontend
      'avatar_url'
    ];

    // field -> column mapping (frontend -> DB)
    const fieldToColumn = {
      'avatar_url': 'profile_image',
      'profile_image': 'profile_image'
    };

    const updates = [];
    const values = [];
    let paramIndex = 1;

    // Normalize array fields if passed as comma-separated strings
    ['specialties', 'languages', 'certifications'].forEach(field => {
      if (updateData[field] && typeof updateData[field] === 'string') {
        updateData[field] = updateData[field]
          .split(',')
          .map(s => s.trim())
          .filter(Boolean);
      }
    });

    Object.keys(updateData).forEach(key => {
      if (!allowedFields.includes(key)) return;

      const column = fieldToColumn[key] || key;
      updates.push(`${column} = $${paramIndex}`);
      values.push(updateData[key]);
      paramIndex++;
    });

    if (updates.length === 0) {
      throw new Error('No valid fields to update');
    }

    values.push(listener_id);
    const query = `
      UPDATE listeners
      SET ${updates.join(', ')}, last_active_at = CURRENT_TIMESTAMP
      WHERE listener_id = $${paramIndex}
      RETURNING *
    `;

    try {
      const result = await pool.query(query, values);
      return result.rows[0];
    } catch (error) {
      // If a column doesn't exist (e.g., using frontend name), try a fallback
      if (error.code === '42703' && (error.message || '').includes('profile_image')) {
        // Attempt to alter table to add column if sensible, or retry mapping
        try {
          await pool.query('ALTER TABLE listeners ADD COLUMN IF NOT EXISTS profile_image TEXT');
          const retryResult = await pool.query(query, values);
          return retryResult.rows[0];
        } catch (retryError) {
          throw retryError;
        }
      }
      throw error;
    }
  }

  // Update last active timestamp
  static async updateLastActive(listener_id) {
    const query = `
      UPDATE listeners 
      SET last_active_at = CURRENT_TIMESTAMP
      WHERE listener_id = $1
    `;
    await pool.query(query, [listener_id]);
  }

  // Increment call statistics
  static async incrementCallStats(listener_id, duration_minutes) {
    const query = `
      UPDATE listeners 
      SET total_calls = total_calls + 1,
          total_minutes = total_minutes + $1
      WHERE listener_id = $2
      RETURNING total_calls, total_minutes
    `;
    const result = await pool.query(query, [duration_minutes, listener_id]);
    return result.rows[0];
  }

  // Get listener statistics
  static async getStats(listener_id) {
    const query = `
      SELECT 
        l.total_calls,
        l.total_minutes,
        l.average_rating,
        l.total_ratings,
        COUNT(DISTINCT c.caller_id) as unique_callers,
        SUM(c.total_cost) as total_earnings
      FROM listeners l
      LEFT JOIN calls c ON l.listener_id = c.listener_id AND c.status = 'completed'
      WHERE l.listener_id = $1
      GROUP BY l.listener_id, l.total_calls, l.total_minutes, l.average_rating, l.total_ratings
    `;
    const result = await pool.query(query, [listener_id]);
    return result.rows[0];
  }

  // Update voice verification status
  static async updateVoiceVerification(listener_id, voice_url) {
    const query = `
      UPDATE listeners 
      SET voice_verified = TRUE, voice_verification_url = $1, updated_at = CURRENT_TIMESTAMP
      WHERE listener_id = $2
      RETURNING listener_id, voice_verified, voice_verification_url
    `;
    const result = await pool.query(query, [voice_url, listener_id]);
    return result.rows[0];
  }

  // Update experiences
  static async updateExperiences(listener_id, experiences) {
    try {
      const query = `
        UPDATE listeners 
        SET experiences = $1, updated_at = CURRENT_TIMESTAMP
        WHERE listener_id = $2
        RETURNING experiences
      `;
      const result = await pool.query(query, [experiences, listener_id]);
      return result.rows[0];
    } catch (error) {
      // If experiences column doesn't exist, try to add it
      if (error.message.includes('column "experiences" does not exist')) {
        console.log('Experiences column missing, attempting to add it...');
        try {
          await pool.query('ALTER TABLE listeners ADD COLUMN IF NOT EXISTS experiences TEXT[]');
          // Retry the update
          const result = await pool.query(`
            UPDATE listeners 
            SET experiences = $1, updated_at = CURRENT_TIMESTAMP
            WHERE listener_id = $2
            RETURNING experiences
          `, [experiences, listener_id]);
          console.log('Experiences column added and data updated successfully');
          return result.rows[0];
        } catch (retryError) {
          console.error('Failed to add experiences column:', retryError.message);
          throw retryError;
        }
      }
      throw error;
    }
  }

  // Get random available listeners (for random call matching)
  static async getRandomAvailable(limit = 1, excludeListenerId = null) {
    let query = `
      SELECT
        l.listener_id,
        l.user_id,
        l.professional_name,
        l.age,
        l.specialties,
        l.languages,
        l.profile_image,
        l.average_rating,
        l.total_ratings,
        l.total_calls,
        l.total_minutes,
        l.is_available,
        l.verification_status,
        l.user_rate_per_min,
        u.city,
        u.country,
        u.display_name,
        CASE 
          WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
          THEN true 
          ELSE false 
        END as is_online
      FROM listeners l
      JOIN users u ON l.user_id = u.user_id
      WHERE l.is_available = TRUE AND u.is_active = TRUE
        AND l.is_active = TRUE
        AND COALESCE(l.is_busy, false) = FALSE
        AND COALESCE(l.verification_status, 'approved') = 'approved' -- VERIFICATION CHECK: Only show approved listeners
    `;
    const values = [];

    if (excludeListenerId) {
      query += ` AND l.listener_id != $1`;
      values.push(excludeListenerId);
    }

    query += ` ORDER BY RANDOM() LIMIT $${values.length + 1}`;
    values.push(limit);

    const result = await pool.query(query, values);
    
    return result.rows;
  }

  // Update listener rating statistics
  static async updateRatingStats(listener_id, average_rating, total_ratings) {
    const query = `
      UPDATE listeners 
      SET average_rating = $1, total_ratings = $2
      WHERE listener_id = $3
    `;
    await pool.query(query, [average_rating, total_ratings, listener_id]);
  }

  // Update listener verification status (admin only)
  // VERIFICATION CONTROL: This method allows admin to approve/reject listeners
  static async updateVerificationStatus(listener_id, status) {
    const validStatuses = ['pending', 'approved', 'rejected'];
    if (!validStatuses.includes(status)) {
      throw new Error(`Invalid verification status. Must be one of: ${validStatuses.join(', ')}`);
    }

    const query = `
      UPDATE listeners 
      SET verification_status = $1, 
          is_verified = $2,
          updated_at = CURRENT_TIMESTAMP
      WHERE listener_id = $3
      RETURNING listener_id, verification_status, is_verified
    `;
    
    // Keep is_verified in sync: true if approved, false otherwise
    const isVerified = status === 'approved';
    
    const result = await pool.query(query, [status, isVerified, listener_id]);
    return result.rows[0];
  }

  // ── Busy status methods ──

  // Set listener busy (call started)
  static async setBusy(listener_id) {
    const query = `
      UPDATE listeners
      SET is_busy = TRUE, updated_at = CURRENT_TIMESTAMP
      WHERE listener_id = $1
      RETURNING listener_id, is_busy
    `;
    const result = await pool.query(query, [listener_id]);
    console.log(`[LISTENER] setBusy: listener ${listener_id} → busy=true`);
    return result.rows[0];
  }

  // Clear listener busy (call ended / disconnected)
  static async clearBusy(listener_id) {
    const query = `
      UPDATE listeners
      SET is_busy = FALSE, updated_at = CURRENT_TIMESTAMP
      WHERE listener_id = $1
      RETURNING listener_id, is_busy
    `;
    const result = await pool.query(query, [listener_id]);
    console.log(`[LISTENER] clearBusy: listener ${listener_id} → busy=false`);
    return result.rows[0];
  }

  // Clear busy by user_id (for socket disconnect cleanup)
  static async clearBusyByUserId(user_id) {
    const query = `
      UPDATE listeners
      SET is_busy = FALSE, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1 AND is_busy = TRUE
      RETURNING listener_id, is_busy
    `;
    const result = await pool.query(query, [user_id]);
    if (result.rows.length > 0) {
      console.log(`[LISTENER] clearBusyByUserId: user ${user_id} → busy=false`);
    }
    return result.rows[0];
  }

  // Check if listener is busy
  static async isBusy(listener_id) {
    const query = `SELECT is_busy FROM listeners WHERE listener_id = $1`;
    const result = await pool.query(query, [listener_id]);
    return result.rows[0]?.is_busy === true;
  }

  // Delete listener and all related data (including associated user account)
  static async delete(listener_id) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // 1. Get the associated user_id before deleting
      const listenerResult = await client.query(
        'SELECT user_id FROM listeners WHERE listener_id = $1',
        [listener_id]
      );
      if (listenerResult.rowCount === 0) {
        await client.query('ROLLBACK');
        return false;
      }
      const user_id = listenerResult.rows[0].user_id;

      // 2. Delete call billing audit records referencing this listener
      await client.query(
        'DELETE FROM call_billing_audit WHERE listener_id = $1',
        [listener_id]
      );

      // 3. Delete call records referencing this listener
      await client.query(
        'DELETE FROM call_records WHERE listener_id = $1',
        [listener_id]
      );

      // 4. Delete calls where this listener was involved
      await client.query(
        'DELETE FROM calls WHERE listener_id = $1',
        [listener_id]
      );

      // 5. Delete ratings for this listener (CASCADE should handle, but explicit for safety)
      await client.query(
        'DELETE FROM ratings WHERE listener_id = $1',
        [listener_id]
      );

      // 6. Delete favorites referencing this listener
      await client.query(
        'DELETE FROM favorites WHERE listener_id = $1',
        [listener_id]
      );

      // 7. Delete listener payment details
      await client.query(
        'DELETE FROM listener_payment_details WHERE listener_id = $1',
        [listener_id]
      );

      // 8. Delete listener availability
      await client.query(
        'DELETE FROM listener_availability WHERE listener_id = $1',
        [listener_id]
      );

      // 9. Delete the listener row itself
      await client.query(
        'DELETE FROM listeners WHERE listener_id = $1',
        [listener_id]
      );

      // 10. If there is an associated user account, delete all user-related data too
      if (user_id) {
        // Delete notification deliveries for this user
        await client.query(
          'DELETE FROM notification_deliveries WHERE user_id = $1',
          [user_id]
        );

        // Delete contact messages by this user
        await client.query(
          'DELETE FROM contact_messages WHERE user_id = $1',
          [user_id]
        );

        // Delete delete account requests by this user
        await client.query(
          'DELETE FROM delete_account_requests WHERE user_id = $1',
          [user_id]
        );

        // Delete notifications for this user
        await client.query(
          'DELETE FROM notifications WHERE user_id = $1',
          [user_id]
        );

        // Delete transactions for this user
        await client.query(
          'DELETE FROM transactions WHERE user_id = $1',
          [user_id]
        );

        // Delete messages sent by this user
        await client.query(
          'DELETE FROM messages WHERE sender_id = $1',
          [user_id]
        );

        // Delete chats involving this user
        await client.query(
          'DELETE FROM chats WHERE user1_id = $1 OR user2_id = $1',
          [user_id]
        );

        // Delete blocked users records
        await client.query(
          'DELETE FROM blocked_users WHERE blocker_id = $1 OR blocked_id = $1',
          [user_id]
        );

        // Delete reports by or about this user
        await client.query(
          'DELETE FROM reports WHERE reporter_id = $1 OR reported_user_id = $1',
          [user_id]
        );

        // Delete user languages
        await client.query(
          'DELETE FROM user_languages WHERE user_id = $1',
          [user_id]
        );

        // Delete wallet
        await client.query(
          'DELETE FROM wallets WHERE user_id = $1',
          [user_id]
        );

        // Delete any remaining calls by this user as caller
        await client.query(
          'DELETE FROM calls WHERE caller_id = $1',
          [user_id]
        );

        // Delete call records by this user
        await client.query(
          'DELETE FROM call_records WHERE user_id = $1',
          [user_id]
        );

        // Delete call billing audit by this user
        await client.query(
          'DELETE FROM call_billing_audit WHERE user_id = $1',
          [user_id]
        );

        // Finally, delete the user account itself
        await client.query(
          'DELETE FROM users WHERE user_id = $1',
          [user_id]
        );
      }

      await client.query('COMMIT');
      return true;
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}

export default Listener;
