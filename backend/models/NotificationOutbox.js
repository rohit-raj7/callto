import { pool } from '../db.js';

class NotificationOutbox {
  static async create(data) {
    const {
      title,
      body,
      target_role,
      target_user_ids,
      schedule_at,
      repeat_interval,
      created_by
    } = data;
    const q = `
      INSERT INTO notification_outbox
      (title, body, target_role, target_user_ids, schedule_at, repeat_interval, created_by)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
    `;
    const res = await pool.query(q, [
      title,
      body,
      target_role,
      target_user_ids || null,
      schedule_at || null,
      repeat_interval || null,
      created_by
    ]);
    return res.rows[0];
  }

  static async findPendingReady(limit = 20) {
    const q = `
      SELECT *
      FROM notification_outbox
      WHERE status = 'PENDING'
        AND (schedule_at IS NULL OR schedule_at <= CURRENT_TIMESTAMP)
      ORDER BY created_at ASC
      LIMIT $1
    `;
    const res = await pool.query(q, [limit]);
    return res.rows;
  }

  static async markSent(id) {
    const q = `
      UPDATE notification_outbox
      SET status = 'SENT', delivered_at = CURRENT_TIMESTAMP
      WHERE id = $1
      RETURNING *
    `;
    const res = await pool.query(q, [id]);
    return res.rows[0];
  }

  static async markFailed(id, error) {
    const q = `
      UPDATE notification_outbox
      SET status = 'FAILED', last_error = $2
      WHERE id = $1
      RETURNING *
    `;
    const res = await pool.query(q, [id, String(error || '')]);
    return res.rows[0];
  }
}

export default NotificationOutbox;

