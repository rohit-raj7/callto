import { pool } from '../db.js';

class User {
  // Create new user
  static async create(userData) {
    const {
      phone_number,
      email,
      password_hash,
      auth_provider = 'phone',
      google_id,
      facebook_id,
      full_name,
      display_name,
      gender,
      date_of_birth,
      city,
      country,
      avatar_url,
      account_type = 'user',
      is_first_time_user = false,
      offer_used = false,
      offer_minutes_limit = null,
      offer_flat_price = null
    } = userData;

    const query = `
      INSERT INTO users (
        phone_number, email, password_hash, auth_provider, google_id, facebook_id,
        full_name, display_name, gender, date_of_birth, city, country, avatar_url, account_type,
        is_first_time_user, offer_used, offer_minutes_limit, offer_flat_price
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
      RETURNING user_id, phone_number, email, auth_provider, google_id, facebook_id, full_name, display_name, gender, 
                city, country, avatar_url, account_type, is_first_time_user, offer_used, offer_minutes_limit, offer_flat_price, created_at
    `;

    const values = [
      phone_number, email, password_hash, auth_provider, google_id, facebook_id,
      full_name, display_name, gender, date_of_birth, city, country, avatar_url, account_type,
      is_first_time_user, offer_used, offer_minutes_limit, offer_flat_price
    ];

    const result = await pool.query(query, values);
    return result.rows[0];
  }
  // Get all users
  static async getAll() {
    const result = await pool.query('SELECT * FROM users');
    return result.rows;
  }

  // Find user by phone number
  static async findByPhone(phone_number) {
    const query = 'SELECT * FROM users WHERE phone_number = $1';
    const result = await pool.query(query, [phone_number]);
    return result.rows[0];
  }

  // Find user by email
  static async findByEmail(email) {
    const query = 'SELECT * FROM users WHERE email = $1';
    const result = await pool.query(query, [email]);
    return result.rows[0];
  }

  static async findByGoogleId(google_id) {
    const query = 'SELECT * FROM users WHERE google_id = $1';
    const result = await pool.query(query, [google_id]);
    return result.rows[0];
  }

  static async findByFacebookId(facebook_id) {
    const query = 'SELECT * FROM users WHERE facebook_id = $1';
    const result = await pool.query(query, [facebook_id]);
    return result.rows[0];
  }

  static async findByProvider(provider, providerUserId) {
    if (!provider || !providerUserId) return null;
    if (provider === 'google') return User.findByGoogleId(providerUserId);
    if (provider === 'facebook') return User.findByFacebookId(providerUserId);
    return null;
  }

  static async linkProvider(user_id, provider, providerUserId) {
    if (!user_id || !provider || !providerUserId) {
      throw new Error('user_id, provider, providerUserId are required');
    }

    let setClause = 'auth_provider = $1';
    if (provider === 'google') {
      setClause += ', google_id = $2';
    } else if (provider === 'facebook') {
      setClause += ', facebook_id = $2';
    } else {
      throw new Error('Unsupported provider');
    }

    const query = `
      UPDATE users
      SET ${setClause}, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $3
      RETURNING user_id, phone_number, email, auth_provider, google_id, facebook_id,
                full_name, display_name, gender, city, country, avatar_url, bio, is_verified,
                is_active, account_type, created_at, updated_at, last_login
    `;

    const result = await pool.query(query, [provider, providerUserId, user_id]);
    return result.rows[0];
  }

  // Find user by ID
  static async findById(user_id) {
    const query = `
      SELECT user_id, phone_number, email, auth_provider, google_id, facebook_id, full_name, display_name, gender,
             date_of_birth, city, country, avatar_url, bio, mobile_number, is_verified,
             is_active, account_type, is_first_time_user, offer_used, offer_minutes_limit, offer_flat_price,
             created_at, updated_at
      FROM users 
      WHERE user_id = $1 AND is_active = TRUE
    `;
    const result = await pool.query(query, [user_id]);
    return result.rows[0];
  }

  // Update user profile
  static async update(user_id, updateData) {
    const allowedFields = [
      'email', 'full_name', 'display_name', 'gender', 'date_of_birth',
      'city', 'country', 'avatar_url', 'bio', 'fcm_token', 'mobile_number'
    ];

    const updates = [];
    const values = [];
    let paramIndex = 1;

    Object.keys(updateData).forEach(key => {
      if (allowedFields.includes(key)) {
        updates.push(`${key} = $${paramIndex}`);
        values.push(updateData[key]);
        paramIndex++;
      }
    });

    if (updates.length === 0) {
      throw new Error('No valid fields to update');
    }

    values.push(user_id);
    const query = `
      UPDATE users 
      SET ${updates.join(', ')}
      WHERE user_id = $${paramIndex}
      RETURNING user_id, phone_number, email, full_name, display_name, gender,
                city, country, avatar_url, bio, mobile_number, updated_at
    `;

    const result = await pool.query(query, values);
    return result.rows[0];
  }

  // Update last login
  static async updateLastLogin(user_id) {
    const query = 'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE user_id = $1';
    await pool.query(query, [user_id]);
  }

  // Update last seen
  static async updateLastSeen(user_id) {
    const query = 'UPDATE users SET last_seen = CURRENT_TIMESTAMP WHERE user_id = $1';
    await pool.query(query, [user_id]);
  }

  static async markOfferUsed(user_id) {
    const query = `
      UPDATE users
      SET offer_used = TRUE, updated_at = CURRENT_TIMESTAMP
      WHERE user_id = $1
      RETURNING user_id, offer_used
    `;
    const result = await pool.query(query, [user_id]);
    return result.rows[0];
  }

  // Verify user
  static async verifyUser(user_id) {
    const query = `
      UPDATE users 
      SET is_verified = TRUE 
      WHERE user_id = $1
      RETURNING user_id, is_verified
    `;
    const result = await pool.query(query, [user_id]);
    return result.rows[0];
  }

  // Deactivate user
  static async deactivate(user_id) {
    const query = 'UPDATE users SET is_active = FALSE WHERE user_id = $1';
    await pool.query(query, [user_id]);
  }

  // Delete user and all related data
  static async delete(user_id) {
    const query = 'DELETE FROM users WHERE user_id = $1';
    const result = await pool.query(query, [user_id]);
    return result.rowCount > 0;
  }

  // Get user wallet
  static async getWallet(user_id) {
    const query = 'SELECT * FROM wallets WHERE user_id = $1';
    const result = await pool.query(query, [user_id]);

    let wallet;

    // Create wallet if it doesn't exist
    if (result.rows.length === 0) {
      const createQuery = `
        INSERT INTO wallets (user_id, balance)
        VALUES ($1, 0.0)
        RETURNING *
      `;
      const createResult = await pool.query(createQuery, [user_id]);
      wallet = createResult.rows[0];
    } else {
      wallet = result.rows[0];
    }

    const transactionQuery = `
      SELECT
        transaction_id,
        transaction_type,
        amount,
        currency,
        description,
        payment_method,
        payment_gateway_id,
        status,
        related_call_id,
        created_at
      FROM transactions
      WHERE user_id = $1
      ORDER BY created_at DESC
    `;
    const transactionResult = await pool.query(transactionQuery, [user_id]);

    return {
      ...wallet,
      transactions: transactionResult.rows,
    };
  }

  // Add balance to user wallet
  static async addBalance(user_id, amount, paymentDetails = {}) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Ensure wallet exists first
      await this.getWallet(user_id);

      // Update wallet balance
      const walletQuery = `
        UPDATE wallets 
        SET balance = balance + $2, updated_at = NOW()
        WHERE user_id = $1
        RETURNING *
      `;
      const walletResult = await client.query(walletQuery, [user_id, amount]);

      // Create transaction record
      const transactionQuery = `
        INSERT INTO transactions (
          user_id, transaction_type, amount, currency, description,
          payment_method, payment_gateway_id, status
        )
        VALUES ($1, 'credit', $2, $3, $4, $5, $6, 'completed')
        RETURNING *
      `;
      const transactionValues = [
        user_id,
        amount,
        paymentDetails.currency || 'INR',
        paymentDetails.description || 'Wallet recharge',
        paymentDetails.payment_method || 'razorpay',
        paymentDetails.payment_id || null
      ];
      await client.query(transactionQuery, transactionValues);

      await client.query('COMMIT');
      return walletResult.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  static async deductBalanceForCall(user_id, amount, call_id) {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      await client.query(
        `INSERT INTO wallets (user_id, balance)
         VALUES ($1, 0.0)
         ON CONFLICT (user_id) DO NOTHING`,
        [user_id]
      );

      const walletResult = await client.query(
        `UPDATE wallets
         SET balance = balance - $2, updated_at = NOW()
         WHERE user_id = $1 AND balance >= $2
         RETURNING *`,
        [user_id, amount]
      );

      if (walletResult.rows.length === 0) {
        const error = new Error('INSUFFICIENT_BALANCE');
        error.code = 'INSUFFICIENT_BALANCE';
        throw error;
      }

      await client.query(
        `INSERT INTO transactions (
           user_id, transaction_type, amount, currency, description,
           status, related_call_id
         )
         VALUES ($1, 'debit', $2, 'INR', $3, 'completed', $4)
         RETURNING *`,
        [user_id, amount, 'Call charge', call_id]
      );

      await client.query('COMMIT');
      return walletResult.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }
}

export default User;
