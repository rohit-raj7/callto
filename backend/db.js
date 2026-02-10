import pkg from 'pg';
const { Pool } = pkg;
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '.env') });

// ============================================
// DEVICE-TIME FIX: Override pg TIMESTAMP parser for correct timezone handling
// All database sessions are forced to UTC via pool.on('connect') below.
// Raw TIMESTAMP WITHOUT TIMEZONE values from PostgreSQL are therefore in UTC.
// This parser appends 'Z' suffix to produce proper UTC ISO 8601 strings.
// No hardcoded timezone offsets — the mobile client converts UTC to device
// local time using DateTime.toLocal() for correct display.
// ============================================
const pgTypes = pkg.types;

// OID 1114 = TIMESTAMP WITHOUT TIMEZONE
pgTypes.setTypeParser(1114, function parseTimestampAsUTC(val) {
  if (!val) return null;
  // Raw value is in UTC (session timezone forced to UTC via pool.on('connect'))
  // Append 'Z' suffix so clients know this is a UTC ISO 8601 string
  return val.replace(' ', 'T') + 'Z';
});

// Configure the PostgreSQL connection pool
// Increased limits and timeouts to handle connection instability and high traffic
const poolConfig = {
  ...(process.env.DATABASE_PUBLIC_URL
    ? { connectionString: process.env.DATABASE_PUBLIC_URL }
    : {
        host: process.env.DB_HOST,
        port: process.env.DB_PORT || 5432,
        user: process.env.DB_USER,
        password: process.env.DB_PASSWORD,
        database: process.env.DB_NAME
      }),
  max: 20, // Increased from 5 to 20
  idleTimeoutMillis: 30000, // Increased from 10s to 30s
  connectionTimeoutMillis: 30000, // Increased from 10s to 30s
};

if (process.env.NODE_ENV === 'production' || process.env.DATABASE_PUBLIC_URL) {
  poolConfig.ssl = {
    rejectUnauthorized: false
  };
}

const pool = new Pool(poolConfig);

// Handle unexpected errors on idle clients
pool.on('error', (err, client) => {
  console.error('Unexpected error on idle database client:', err.message);
});

// DEVICE-TIME FIX: Force all database sessions to UTC so CURRENT_TIMESTAMP
// always stores UTC values. This prevents timezone ambiguity with
// TIMESTAMP WITHOUT TIMEZONE columns regardless of server location.
pool.on('connect', (client) => {
  client.query("SET timezone = 'UTC'");
});

// Test the database connection
async function testConnection(retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const client = await pool.connect();
      console.log('✓ Successfully connected to AWS RDS PostgreSQL database');
      
      // Test query
      const result = await client.query('SELECT NOW()');
      console.log('Current database time:', result.rows[0].now);
      
      client.release();
      return true;
    } catch (error) {
      console.error(`✗ Error connecting to the database (attempt ${attempt}/${retries}):`, error.message);
      if (attempt === retries) {
        return false;
      }
      // Wait 2 seconds before retrying
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  }
}

async function getRateConfig() {
  const result = await pool.query(
    `SELECT config_id, normal_per_minute_rate, first_time_offer_enabled, offer_minutes_limit, offer_flat_price, updated_at
     FROM rate_config
     ORDER BY updated_at DESC
     LIMIT 1`
  );

  if (result.rows.length === 0) {
    const insertResult = await pool.query(
      `INSERT INTO rate_config (normal_per_minute_rate, first_time_offer_enabled, offer_minutes_limit, offer_flat_price)
       VALUES (4.00, FALSE, 5, 5.00)
       RETURNING config_id, normal_per_minute_rate, first_time_offer_enabled, offer_minutes_limit, offer_flat_price, updated_at`
    );
    return insertResult.rows[0];
  }

  return result.rows[0];
}

// Ensure required columns exist on startup (non-destructive)
async function ensureSchema() {
  try {
    // Ensure UUID function is available
    await pool.query('CREATE EXTENSION IF NOT EXISTS pgcrypto;');

    // Terminate any idle-in-transaction sessions left by previously killed processes
    await pool.query(`
      SELECT pg_terminate_backend(pid)
      FROM pg_stat_activity
      WHERE state = 'idle in transaction' AND pid <> pg_backend_pid()
    `);

    // Create admins table FIRST (notification_outbox references it)
    const createAdminsSql = `
      CREATE TABLE IF NOT EXISTS admins (
        admin_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        full_name VARCHAR(100),
        is_active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        last_login TIMESTAMP
      );
    `;
    await pool.query(createAdminsSql);
    console.log('✓ Ensured admins table exists');

    const createOutboxSql = `
      CREATE TABLE IF NOT EXISTS notification_outbox (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        title VARCHAR(255) NOT NULL,
        body TEXT NOT NULL,
        target_role VARCHAR(20) NOT NULL CHECK (target_role IN ('USER','LISTENER')),
        target_user_ids UUID[] NULL,
        schedule_at TIMESTAMP NULL,
        status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SENT','FAILED')),
        created_by UUID NOT NULL REFERENCES admins(admin_id),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        delivered_at TIMESTAMP NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT
      );
      CREATE INDEX IF NOT EXISTS idx_notification_outbox_schedule ON notification_outbox(schedule_at);
      CREATE INDEX IF NOT EXISTS idx_notification_outbox_status ON notification_outbox(status);
      CREATE INDEX IF NOT EXISTS idx_notification_outbox_target_role ON notification_outbox(target_role);
    `;
    await pool.query(createOutboxSql);

    const createDeliveriesSql = `
      CREATE TABLE IF NOT EXISTS notification_deliveries (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        outbox_id UUID NOT NULL REFERENCES notification_outbox(id) ON DELETE CASCADE,
        user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SENT','FAILED')),
        delivered_at TIMESTAMP NULL,
        retry_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(outbox_id, user_id)
      );
      CREATE INDEX IF NOT EXISTS idx_notification_deliveries_status ON notification_deliveries(status);
      CREATE INDEX IF NOT EXISTS idx_notification_deliveries_user ON notification_deliveries(user_id);
    `;
    await pool.query(createDeliveriesSql);

    // Add repeat_interval column if missing
    const alterOutboxSql = `
      ALTER TABLE notification_outbox ADD COLUMN IF NOT EXISTS repeat_interval VARCHAR(20) DEFAULT NULL;
    `;
    await pool.query(alterOutboxSql);

    const alterNotificationsSql = `
      ALTER TABLE notifications ADD COLUMN IF NOT EXISTS source_outbox_id UUID;
      CREATE INDEX IF NOT EXISTS idx_notifications_source_outbox ON notifications(source_outbox_id);
    `;
    await pool.query(alterNotificationsSql);

    const createContactMessagesSql = `
      CREATE TABLE IF NOT EXISTS contact_messages (
        contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        source VARCHAR(20) NOT NULL CHECK (source IN ('contact', 'support')),
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_contact_messages_created_at ON contact_messages(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_contact_messages_source ON contact_messages(source);
    `;
    await pool.query(createContactMessagesSql);

    const createDeleteRequestsSql = `
      CREATE TABLE IF NOT EXISTS delete_account_requests (
        request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(255) NOT NULL,
        phone VARCHAR(20) NOT NULL,
        reason TEXT NOT NULL,
        role VARCHAR(20) NOT NULL CHECK (role IN ('user', 'listener')),
        status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_delete_requests_created_at ON delete_account_requests(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_delete_requests_role ON delete_account_requests(role);
      CREATE INDEX IF NOT EXISTS idx_delete_requests_status ON delete_account_requests(status);
    `;
    await pool.query(createDeleteRequestsSql);

    // Add commonly used social auth columns if they don't exist yet
    const alterSql = `
      ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(20) DEFAULT 'phone';
      ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS facebook_id VARCHAR(255);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS account_type VARCHAR(20) DEFAULT 'user';
      ALTER TABLE users ADD COLUMN IF NOT EXISTS languages TEXT[];
      ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS is_first_time_user BOOLEAN DEFAULT FALSE;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS offer_used BOOLEAN DEFAULT FALSE;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS offer_minutes_limit INTEGER;
      ALTER TABLE users ADD COLUMN IF NOT EXISTS offer_flat_price DECIMAL(10, 2);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS wallet_balance DECIMAL(10, 2) DEFAULT 0.0;
      
      -- Add listener table columns if they don't exist
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS original_name VARCHAR(100);
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS experiences TEXT[];
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS voice_verified BOOLEAN DEFAULT FALSE;
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS voice_verification_url TEXT;
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP;
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS user_rate_per_min DECIMAL(10, 2);
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS listener_payout_per_min DECIMAL(10, 2);
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS total_earning DECIMAL(10, 2) DEFAULT 0.0;
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS wallet_balance DECIMAL(10, 2) DEFAULT 0.0;
      ALTER TABLE listeners ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
      
      ALTER TABLE calls ADD COLUMN IF NOT EXISTS billed_minutes INTEGER;
      ALTER TABLE calls ADD COLUMN IF NOT EXISTS offer_applied BOOLEAN DEFAULT FALSE;
      ALTER TABLE calls ADD COLUMN IF NOT EXISTS offer_flat_price DECIMAL(10, 2);
      ALTER TABLE calls ADD COLUMN IF NOT EXISTS offer_minutes_limit INTEGER;
    `;
    await pool.query(alterSql);
    console.log('✓ Ensured users and listeners table schema');

    const createRateConfigSql = `
      CREATE TABLE IF NOT EXISTS rate_config (
        config_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        normal_per_minute_rate DECIMAL(10, 2) NOT NULL,
        first_time_offer_enabled BOOLEAN DEFAULT FALSE,
        offer_minutes_limit INTEGER,
        offer_flat_price DECIMAL(10, 2),
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `;
    await pool.query(createRateConfigSql);

    const createRateConfigAuditSql = `
      CREATE TABLE IF NOT EXISTS rate_config_audit (
        audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        admin_id UUID REFERENCES admins(admin_id) ON DELETE SET NULL,
        previous_config JSONB,
        new_config JSONB,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_rate_config_audit_created_at ON rate_config_audit(created_at DESC);
    `;
    await pool.query(createRateConfigAuditSql);

    await pool.query(`
      INSERT INTO rate_config (normal_per_minute_rate, first_time_offer_enabled, offer_minutes_limit, offer_flat_price)
      SELECT 4.00, FALSE, 5, 5.00
      WHERE NOT EXISTS (SELECT 1 FROM rate_config)
    `);
    console.log('✓ Ensured rate_config table and default row');

    await pool.query(`
      CREATE TABLE IF NOT EXISTS call_records (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        call_id UUID REFERENCES calls(call_id) ON DELETE SET NULL,
        user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
        listener_id UUID REFERENCES listeners(listener_id) ON DELETE SET NULL,
        minutes INTEGER NOT NULL,
        user_charge DECIMAL(10, 2) NOT NULL,
        listener_earn DECIMAL(10, 2) NOT NULL,
        started_at TIMESTAMP,
        ended_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idx_call_records_call_id
        ON call_records(call_id) WHERE call_id IS NOT NULL;
      CREATE INDEX IF NOT EXISTS idx_call_records_user ON call_records(user_id, created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_call_records_listener ON call_records(listener_id, created_at DESC);
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS call_billing_audit (
        audit_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        call_id UUID REFERENCES calls(call_id) ON DELETE SET NULL,
        user_id UUID REFERENCES users(user_id) ON DELETE SET NULL,
        listener_id UUID REFERENCES listeners(listener_id) ON DELETE SET NULL,
        minutes INTEGER NOT NULL,
        user_charge DECIMAL(10, 2) NOT NULL,
        listener_earn DECIMAL(10, 2) NOT NULL,
        user_rate_per_min DECIMAL(10, 2) NOT NULL,
        listener_payout_per_min DECIMAL(10, 2) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_call_billing_audit_created_at ON call_billing_audit(created_at DESC);
    `);

    await pool.query(`
      UPDATE listeners
      SET user_rate_per_min = COALESCE(user_rate_per_min, rate_per_minute),
          listener_payout_per_min = COALESCE(listener_payout_per_min, rate_per_minute)
      WHERE user_rate_per_min IS NULL OR listener_payout_per_min IS NULL
    `);

    await pool.query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM pg_constraint
          WHERE conname = 'listeners_payout_rate_check'
        ) THEN
          ALTER TABLE listeners
          ADD CONSTRAINT listeners_payout_rate_check
          CHECK (listener_payout_per_min <= user_rate_per_min);
        END IF;
      END$$;
    `);
    
    // If phone_number is marked NOT NULL in the existing DB, allow nulls for social accounts
    const dropNotNullSql = `
      DO $$
      BEGIN
        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_name = 'users' AND column_name = 'phone_number' AND is_nullable = 'NO'
        ) THEN
          EXECUTE 'ALTER TABLE users ALTER COLUMN phone_number DROP NOT NULL';
        END IF;
      END$$;
    `;
    await pool.query(dropNotNullSql);
    console.log('✓ Ensured phone_number is nullable if previously NOT NULL');
  } catch (error) {
    console.error('Error ensuring schema:', error.message);
    throw error;
  }
}

// Generic query execution function
async function executeQuery(query, params = []) {
  try {
    const result = await pool.query(query, params);
    return result.rows;
  } catch (error) {
    console.error('Query error:', error.message);
    throw error;
  }
}

// Close the connection pool
async function closePool() {
  await pool.end();
  console.log('Database connection pool closed');
}

export { pool, testConnection, executeQuery, closePool };
export { ensureSchema, getRateConfig };



















// // aws //



// import pkg from 'pg';
// const { Pool } = pkg;
// import dotenv from 'dotenv';
// dotenv.config();

// // Configure the PostgreSQL connection pool
// // Optimized for serverless environments
// const pool = new Pool({
//   host: process.env.DB_HOST,
//   port: process.env.DB_PORT || 5432,
//   user: process.env.DB_USER,
//   password: process.env.DB_PASSWORD,
//   database: process.env.DB_NAME,
//   ssl: {
//     rejectUnauthorized: false // Required for AWS RDS
//   },
//   max: 5, // Reduced for serverless - each function instance gets its own pool
//   idleTimeoutMillis: 10000, // Close idle connections faster in serverless
//   connectionTimeoutMillis: 10000,
//   timezone: 'Asia/Kolkata' // Set timezone to IST for proper timestamp handling
// });

// // Test the database connection
// async function testConnection(retries = 3) {
//   for (let attempt = 1; attempt <= retries; attempt++) {
//     try {
//       const client = await pool.connect();
//       console.log('✓ Successfully connected to AWS RDS PostgreSQL database');
      
//       // Test query
//       const result = await client.query('SELECT NOW()');
//       console.log('Current database time:', result.rows[0].now);
      
//       client.release();
//       return true;
//     } catch (error) {
//       console.error(`✗ Error connecting to the database (attempt ${attempt}/${retries}):`, error.message);
//       if (attempt === retries) {
//         return false;
//       }
//       // Wait 2 seconds before retrying
//       await new Promise(resolve => setTimeout(resolve, 2000));
//     }
//   }
// }

// // Ensure required columns exist on startup (non-destructive)
// async function ensureSchema() {
//   try {
//     // Create admins table if it doesn't exist
//     const createAdminsSql = `
//       CREATE TABLE IF NOT EXISTS admins (
//         admin_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
//         email VARCHAR(255) UNIQUE NOT NULL,
//         password_hash VARCHAR(255) NOT NULL,
//         full_name VARCHAR(100),
//         is_active BOOLEAN DEFAULT TRUE,
//         created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
//         updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
//         last_login TIMESTAMP
//       );
//     `;
//     await pool.query(createAdminsSql);
//     console.log('✓ Ensured admins table exists');

//     // Add commonly used social auth columns if they don't exist yet
//     const alterSql = `
//       ALTER TABLE users ADD COLUMN IF NOT EXISTS auth_provider VARCHAR(20) DEFAULT 'phone';
//       ALTER TABLE users ADD COLUMN IF NOT EXISTS google_id VARCHAR(255);
//       ALTER TABLE users ADD COLUMN IF NOT EXISTS facebook_id VARCHAR(255);
//       ALTER TABLE users ADD COLUMN IF NOT EXISTS account_type VARCHAR(20) DEFAULT 'user';
//       ALTER TABLE users ADD COLUMN IF NOT EXISTS languages TEXT[];
//       ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP;
      
//       -- Add listener table columns if they don't exist
//       ALTER TABLE listeners ADD COLUMN IF NOT EXISTS original_name VARCHAR(100);
//       ALTER TABLE listeners ADD COLUMN IF NOT EXISTS experiences TEXT[];
//       ALTER TABLE listeners ADD COLUMN IF NOT EXISTS voice_verified BOOLEAN DEFAULT FALSE;
//       ALTER TABLE listeners ADD COLUMN IF NOT EXISTS voice_verification_url TEXT;
//       ALTER TABLE listeners ADD COLUMN IF NOT EXISTS last_active_at TIMESTAMP;
//     `;
//     await pool.query(alterSql);
//     console.log('✓ Ensured users and listeners table schema');
    
//     // If phone_number is marked NOT NULL in the existing DB, allow nulls for social accounts
//     const dropNotNullSql = `
//       DO $$
//       BEGIN
//         IF EXISTS (
//           SELECT 1 FROM information_schema.columns
//           WHERE table_name = 'users' AND column_name = 'phone_number' AND is_nullable = 'NO'
//         ) THEN
//           EXECUTE 'ALTER TABLE users ALTER COLUMN phone_number DROP NOT NULL';
//         END IF;
//       END$$;
//     `;
//     await pool.query(dropNotNullSql);
//     console.log('✓ Ensured phone_number is nullable if previously NOT NULL');
//   } catch (error) {
//     console.error('Error ensuring schema:', error.message);
//     throw error;
//   }
// }

// // Generic query execution function
// async function executeQuery(query, params = []) {
//   try {
//     const result = await pool.query(query, params);
//     return result.rows;
//   } catch (error) {
//     console.error('Query error:', error.message);
//     throw error;
//   }
// }

// // Close the connection pool
// async function closePool() {
//   await pool.end();
//   console.log('Database connection pool closed');
// }

// export { pool, testConnection, executeQuery, closePool };
// export { ensureSchema };
