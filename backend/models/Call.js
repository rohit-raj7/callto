import { pool } from '../db.js';

class Call {
  // Create new call
  static async create(callData) {
    const {
      caller_id,
      listener_id,
      call_type = 'audio',
      rate_per_minute
    } = callData;

    const query = `
      INSERT INTO calls (caller_id, listener_id, call_type, rate_per_minute, status)
      VALUES ($1, $2, $3, $4, 'pending')
      RETURNING *
    `;

    const values = [caller_id, listener_id, call_type, rate_per_minute];
    const result = await pool.query(query, values);
    return result.rows[0];
  }

  // Get call by ID
  static async findById(call_id) {
    const query = `
      SELECT c.*, 
             u1.display_name as caller_name, u1.avatar_url as caller_avatar,
             u2.display_name as listener_name, u2.avatar_url as listener_avatar,
             l.professional_name
      FROM calls c
      LEFT JOIN users u1 ON c.caller_id = u1.user_id
      LEFT JOIN listeners l ON c.listener_id = l.listener_id
      LEFT JOIN users u2 ON l.user_id = u2.user_id
      WHERE c.call_id = $1
    `;
    const result = await pool.query(query, [call_id]);
    return result.rows[0];
  }

  // Update call status
  static async updateStatus(call_id, status, additionalData = {}) {
    let query = 'UPDATE calls SET status = $1';
    const values = [status, call_id];
    let paramIndex = 3;

    // Update started_at when status changes to 'ongoing'
    if (status === 'ongoing') {
      query += ', started_at = CURRENT_TIMESTAMP';
    }

    // Update ended_at and duration when call completes
    if (status === 'completed' || status === 'missed' || status === 'cancelled') {
      query += ', ended_at = CURRENT_TIMESTAMP';
      
      if (additionalData.duration_seconds !== undefined) {
        query += `, duration_seconds = $${paramIndex}`;
        values.splice(2, 0, additionalData.duration_seconds);
        paramIndex++;
      }
      
      if (additionalData.total_cost !== undefined) {
        query += `, total_cost = $${paramIndex}`;
        values.splice(paramIndex - 1, 0, additionalData.total_cost);
      }
    }

    query += ` WHERE call_id = $2 RETURNING *`;
    
    const result = await pool.query(query, values);
    return result.rows[0];
  }

  // Get user's call history
  static async getUserCallHistory(user_id, limit = 20, offset = 0) {
    const query = `
      SELECT c.*, 
             l.professional_name as listener_name, 
             l.profile_image as listener_avatar,
             l.user_id as listener_user_id,
             CASE 
               WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
               THEN true 
               ELSE false 
             END as listener_online,
             u.display_name as listener_display_name,
             u.city
      FROM calls c
      JOIN listeners l ON c.listener_id = l.listener_id
      JOIN users u ON l.user_id = u.user_id
      WHERE c.caller_id = $1
      ORDER BY c.created_at DESC
      LIMIT $2 OFFSET $3
    `;
    const result = await pool.query(query, [user_id, limit, offset]);
    return result.rows;
  }

  // Get listener's call history
  static async getListenerCallHistory(listener_id, limit = 20, offset = 0) {
    const query = `
      SELECT c.*, 
             u.display_name as caller_name,
             u.avatar_url as caller_avatar,
             u.city
      FROM calls c
      JOIN users u ON c.caller_id = u.user_id
      WHERE c.listener_id = $1
      ORDER BY c.created_at DESC
      LIMIT $2 OFFSET $3
    `;
    const result = await pool.query(query, [listener_id, limit, offset]);
    return result.rows;
  }

  // Get active calls for a user
  static async getActiveCalls(user_id) {
    const query = `
      SELECT c.*, 
             l.professional_name, l.profile_image,
             l.user_id as listener_user_id,
             CASE 
               WHEN l.last_active_at IS NOT NULL AND (NOW() - l.last_active_at) <= INTERVAL '2 minutes' 
               THEN true 
               ELSE false 
             END as listener_online,
             u.display_name as listener_display_name
      FROM calls c
      JOIN listeners l ON c.listener_id = l.listener_id
      JOIN users u ON l.user_id = u.user_id
      WHERE c.caller_id = $1 
        AND c.status IN ('pending', 'ringing', 'ongoing')
      ORDER BY c.created_at DESC
    `;
    const result = await pool.query(query, [user_id]);
    return result.rows;
  }

  static calculateBillingMinutes(duration_seconds) {
    const seconds = Math.max(0, Math.floor(Number(duration_seconds) || 0));
    // Billing rounds up to the next full minute so any partial minute counts as a full minute.
    return Math.max(1, Math.ceil(seconds / 60));
  }

  static calculateBillingAmount(duration_seconds, rate_per_minute = 4) {
    const minutes = this.calculateBillingMinutes(duration_seconds);
    return Number((minutes * rate_per_minute).toFixed(2));
  }
}

export default Call;
