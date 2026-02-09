import { pool } from '../db.js';

class NotificationDelivery {
  static async ensure(outbox_id, user_id) {
    const q = `
      INSERT INTO notification_deliveries (outbox_id, user_id)
      VALUES ($1, $2)
      ON CONFLICT (outbox_id, user_id) DO UPDATE
      SET outbox_id = EXCLUDED.outbox_id
      RETURNING *
    `;
    const res = await pool.query(q, [outbox_id, user_id]);
    return res.rows[0];
  }

  static async markSent(outbox_id, user_id) {
    const q = `
      UPDATE notification_deliveries
      SET status = 'SENT', delivered_at = CURRENT_TIMESTAMP
      WHERE outbox_id = $1 AND user_id = $2
      RETURNING *
    `;
    const res = await pool.query(q, [outbox_id, user_id]);
    return res.rows[0];
  }

  static async markFailed(outbox_id, user_id, error) {
    const q = `
      UPDATE notification_deliveries
      SET status = 'FAILED', retry_count = COALESCE(retry_count,0) + 1, last_error = $3
      WHERE outbox_id = $1 AND user_id = $2
      RETURNING *
    `;
    const res = await pool.query(q, [outbox_id, user_id, String(error || '')]);
    return res.rows[0];
  }
}

export default NotificationDelivery;

