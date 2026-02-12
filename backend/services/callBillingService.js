import { pool, getRateConfig } from '../db.js';

const roundMoney = (value) => Number(Number(value || 0).toFixed(2));

const calculateCallCharge = (durationSeconds, userRate, payoutRate) => {
  const seconds = Math.max(0, Math.floor(Number(durationSeconds) || 0));
  const minutes = Math.ceil(seconds / 60);
  const userCharge = roundMoney(minutes * Number(userRate || 0));
  const listenerEarn = roundMoney(minutes * Number(payoutRate || 0));

  return { minutes, userCharge, listenerEarn };
};

const fetchOrCreateWallet = async (client, userId) => {
  const walletResult = await client.query(
    'SELECT wallet_id, balance FROM wallets WHERE user_id = $1 FOR UPDATE',
    [userId]
  );

  if (walletResult.rows.length > 0) {
    return walletResult.rows[0];
  }

  const created = await client.query(
    'INSERT INTO wallets (user_id, balance) VALUES ($1, 0.0) RETURNING wallet_id, balance',
    [userId]
  );
  return created.rows[0];
};

const getExistingBilling = async (client, callId) => {
  const existing = await client.query(
    'SELECT minutes, user_charge, listener_earn FROM call_records WHERE call_id = $1',
    [callId]
  );
  return existing.rows[0] || null;
};

const finalizeCallBilling = async ({ callId, durationSeconds }) => {
  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    const callResult = await client.query(
      'SELECT * FROM calls WHERE call_id = $1 FOR UPDATE',
      [callId]
    );

    if (callResult.rows.length === 0) {
      const error = new Error('Call not found');
      error.code = 'CALL_NOT_FOUND';
      throw error;
    }

    const call = callResult.rows[0];

    const existingBilling = await getExistingBilling(client, callId);
    if (existingBilling) {
      await client.query('COMMIT');
      return {
        alreadyBilled: true,
        minutes: Number(existingBilling.minutes),
        userCharge: roundMoney(existingBilling.user_charge),
        listenerEarn: roundMoney(existingBilling.listener_earn)
      };
    }

    const listenerResult = await client.query(
      `SELECT listener_id, user_rate_per_min, listener_payout_per_min, wallet_balance, total_earning
       FROM listeners
       WHERE listener_id = $1
       FOR UPDATE`,
      [call.listener_id]
    );

    if (listenerResult.rows.length === 0) {
      console.error(`[BILLING] Listener not found for call ${callId}, listener_id=${call.listener_id}`);
      const error = new Error('Listener not found for billing');
      error.code = 'LISTENER_NOT_FOUND';
      throw error;
    }

    const listener = listenerResult.rows[0];
    let userRate = Number(listener.user_rate_per_min || 0);
    const payoutRate = Number(listener.listener_payout_per_min || 0);

    // Validation: listener_payout_per_min MUST come from DB (set by admin).
    // If missing or invalid, billing cannot proceed — prevents incorrect payouts.
    if (!Number.isFinite(userRate) || userRate <= 0) {
      console.error(`[BILLING] Invalid user_rate_per_min=${listener.user_rate_per_min} for listener ${call.listener_id}. Rate must be set by admin.`);
      const error = new Error('Invalid user rate for billing');
      error.code = 'INVALID_USER_RATE';
      throw error;
    }

    if (!Number.isFinite(payoutRate) || payoutRate <= 0) {
      console.error(`[BILLING] Invalid listener_payout_per_min=${listener.listener_payout_per_min} for listener ${call.listener_id}. Payout rate must be set by admin via ListenerRateSettings.`);
      const error = new Error('Invalid payout rate for billing');
      error.code = 'INVALID_PAYOUT_RATE';
      throw error;
    }

    // Check if caller is eligible for first-time offer
    const callerResult = await client.query(
      'SELECT is_first_time_user, offer_used FROM users WHERE user_id = $1',
      [call.caller_id]
    );
    const caller = callerResult.rows[0];
    let offerApplied = false;

    if (caller && caller.is_first_time_user && !caller.offer_used) {
      const rateConfig = await getRateConfig();
      if (rateConfig.first_time_offer_enabled
          && rateConfig.offer_minutes_limit > 0
          && Number(rateConfig.offer_flat_price) > 0) {
        const offerRate = Number(rateConfig.offer_flat_price) / rateConfig.offer_minutes_limit;
        console.log(`[BILLING] First-time offer applied for user ${call.caller_id}: ₹${offerRate}/min instead of ₹${userRate}/min`);
        userRate = offerRate;
        offerApplied = true;
      }
    }

    const { minutes, userCharge, listenerEarn } = calculateCallCharge(
      durationSeconds,
      userRate,
      payoutRate
    );

    // Log the billing calculation for audit trail
    console.log(`[BILLING] call=${callId} | duration=${durationSeconds}s → ${minutes}min | userRate=₹${userRate}/min → charge=₹${userCharge} | payoutRate=₹${payoutRate}/min → listenerEarn=₹${listenerEarn} | commission=₹${(userCharge - listenerEarn).toFixed(2)}`);

    await fetchOrCreateWallet(client, call.caller_id);

    const walletUpdate = await client.query(
      `UPDATE wallets
       SET balance = balance - $2, updated_at = NOW()
       WHERE user_id = $1 AND balance >= $2
       RETURNING balance`,
      [call.caller_id, userCharge]
    );

    if (walletUpdate.rows.length === 0) {
      const error = new Error('INSUFFICIENT_BALANCE');
      error.code = 'INSUFFICIENT_BALANCE';
      throw error;
    }

    const updatedUserBalance = walletUpdate.rows[0].balance;
    await client.query(
      'UPDATE users SET wallet_balance = $2 WHERE user_id = $1',
      [call.caller_id, updatedUserBalance]
    );

    const listenerUpdate = await client.query(
      `UPDATE listeners
       SET wallet_balance = wallet_balance + $2,
           total_earning = total_earning + $2,
           updated_at = CURRENT_TIMESTAMP
       WHERE listener_id = $1
       RETURNING wallet_balance, total_earning`,
      [call.listener_id, listenerEarn]
    );

    if (listenerUpdate.rows.length === 0) {
      const error = new Error('Listener wallet update failed');
      error.code = 'LISTENER_WALLET_UPDATE_FAILED';
      throw error;
    }

    await client.query(
      `UPDATE calls
       SET status = 'completed',
           duration_seconds = $2,
           billed_minutes = $3,
           total_cost = $4,
           rate_per_minute = $5,
           ended_at = CURRENT_TIMESTAMP
       WHERE call_id = $1`,
      [callId, durationSeconds, minutes, userCharge, userRate]
    );

    await client.query(
      `INSERT INTO call_records (
         call_id, user_id, listener_id, minutes, user_charge, listener_earn, started_at, ended_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)`,
      [
        callId,
        call.caller_id,
        call.listener_id,
        minutes,
        userCharge,
        listenerEarn,
        call.started_at
      ]
    );

    await client.query(
      `INSERT INTO call_billing_audit (
         call_id, user_id, listener_id, minutes, user_charge, listener_earn, user_rate_per_min, listener_payout_per_min
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        callId,
        call.caller_id,
        call.listener_id,
        minutes,
        userCharge,
        listenerEarn,
        userRate,
        payoutRate
      ]
    );

    // Mark offer as used INSIDE the transaction to prevent race conditions
    // This ensures a user can only ever get the offer rate on one call
    if (offerApplied) {
      await client.query(
        `UPDATE users SET offer_used = TRUE, updated_at = CURRENT_TIMESTAMP WHERE user_id = $1`,
        [call.caller_id]
      );
      console.log(`[BILLING] Marked offer_used=true for user ${call.caller_id} (inside transaction)`);
    }

    await client.query('COMMIT');

    return {
      alreadyBilled: false,
      minutes,
      userCharge,
      listenerEarn
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export { calculateCallCharge, finalizeCallBilling };
