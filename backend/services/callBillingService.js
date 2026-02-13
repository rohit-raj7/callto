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

// Calculate maximum affordable call duration based on wallet balance
const calculateMaxCallDuration = async (callerId, ratePerMinute) => {
  try {
    const walletResult = await pool.query(
      'SELECT balance FROM wallets WHERE user_id = $1',
      [callerId]
    );

    const balance = walletResult.rows.length > 0
      ? Number(walletResult.rows[0].balance)
      : 0;

    const rate = Number(ratePerMinute);
    if (rate <= 0 || balance <= 0) return { maxAllowedSeconds: 0, balance, rate };

    // Pro-rata calculation: allow the full fractional time the wallet can afford
    // e.g., ₹5 at ₹4/min = 1.25 min × 60 = 75 seconds
    // Billing uses Math.ceil for minute rounding, but the wallet-cap in
    // finalizeCallBilling ensures we never charge more than the wallet holds.
    const maxAllowedSeconds = Math.max(0, Math.floor((balance / rate) * 60));

    console.log(`[BILLING] maxCallDuration: user=${callerId} balance=₹${balance} rate=₹${rate}/min → ${maxAllowedSeconds}s`);

    return { maxAllowedSeconds, balance, rate };
  } catch (error) {
    console.error(`[BILLING] calculateMaxCallDuration error:`, error);
    return { maxAllowedSeconds: 0, balance: 0, rate: Number(ratePerMinute) };
  }
};

// Mark call as started with server-authoritative timestamp
const markCallStarted = async (callId) => {
  try {
    const result = await pool.query(
      `UPDATE calls
       SET status = 'ongoing', started_at = CURRENT_TIMESTAMP
       WHERE call_id = $1 AND status IN ('pending', 'ringing')
       RETURNING call_id, started_at, rate_per_minute, caller_id, listener_id`,
      [callId]
    );

    if (result.rows.length === 0) {
      // Call might already be ongoing — return existing data
      const existing = await pool.query(
        'SELECT call_id, started_at, rate_per_minute, caller_id, listener_id FROM calls WHERE call_id = $1',
        [callId]
      );
      return existing.rows[0] || null;
    }

    console.log(`[BILLING] Call ${callId} marked as started at ${result.rows[0].started_at}`);
    return result.rows[0];
  } catch (error) {
    console.error(`[BILLING] markCallStarted error for call ${callId}:`, error);
    return null;
  }
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

    // Server-authoritative duration: prefer started_at from DB over frontend value
    if (call.started_at) {
      const serverMs = Date.now() - new Date(call.started_at).getTime();
      const serverDuration = Math.max(0, Math.round(serverMs / 1000));
      const clientDuration = durationSeconds;
      // Use the LESSER of server and frontend duration to prevent overcharging;
      // server value is ground truth, but API latency can inflate it slightly
      durationSeconds = clientDuration > 0
        ? Math.min(serverDuration, clientDuration)
        : serverDuration;
      console.log(`[BILLING] Duration resolved: server=${serverDuration}s, client=${clientDuration}s → effective=${durationSeconds}s`);
    }

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

    // ── Wallet-capped billing ──
    // Cap billing to wallet balance so connected calls NEVER fail with INSUFFICIENT_BALANCE.
    // Instead of rejecting the entire transaction, bill only what the wallet can afford.
    const wallet = await fetchOrCreateWallet(client, call.caller_id);
    const walletBalance = Number(wallet.balance);

    let billedMinutes = minutes;
    let billedUserCharge = userCharge;
    let billedListenerEarn = listenerEarn;

    if (walletBalance < userCharge && userCharge > 0) {
      const affordableMinutes = Math.max(0, Math.floor(walletBalance / userRate));
      billedMinutes = affordableMinutes;
      billedUserCharge = roundMoney(billedMinutes * userRate);
      billedListenerEarn = roundMoney(billedMinutes * payoutRate);
      console.log(`[BILLING] CAPPED: wallet=₹${walletBalance} < charge=₹${userCharge}. Capped to ${billedMinutes}min → user=₹${billedUserCharge}, listener=₹${billedListenerEarn}`);
    }

    // Deduct user wallet (skip if nothing to charge)
    if (billedUserCharge > 0) {
      const walletUpdate = await client.query(
        `UPDATE wallets
         SET balance = balance - $2, updated_at = NOW()
         WHERE user_id = $1 AND balance >= $2
         RETURNING balance`,
        [call.caller_id, billedUserCharge]
      );

      if (walletUpdate.rows.length === 0) {
        // Race condition: another transaction deducted between our read and write
        // Fall back to zero billing rather than failing the whole call
        console.log(`[BILLING] WARNING: Wallet race condition for user ${call.caller_id}. Zeroing billing.`);
        billedMinutes = 0;
        billedUserCharge = 0;
        billedListenerEarn = 0;
      } else {
        const updatedUserBalance = walletUpdate.rows[0].balance;
        await client.query(
          'UPDATE users SET wallet_balance = $2 WHERE user_id = $1',
          [call.caller_id, updatedUserBalance]
        );

        // Record debit transaction for audit trail
        await client.query(
          `INSERT INTO transactions (user_id, transaction_type, amount, currency, description, status, related_call_id)
           VALUES ($1, 'debit', $2, 'INR', $3, 'completed', $4)`,
          [call.caller_id, billedUserCharge, `Call charge (${billedMinutes} min)`, callId]
        );
      }
    }

    // Credit listener wallet (skip if nothing to credit)
    if (billedListenerEarn > 0) {
      const listenerUpdate = await client.query(
        `UPDATE listeners
         SET wallet_balance = wallet_balance + $2,
             total_earning = total_earning + $2,
             updated_at = CURRENT_TIMESTAMP
         WHERE listener_id = $1
         RETURNING wallet_balance, total_earning`,
        [call.listener_id, billedListenerEarn]
      );

      if (listenerUpdate.rows.length === 0) {
        console.error(`[BILLING] CRITICAL: Listener ${call.listener_id} wallet update returned 0 rows. User charged ₹${billedUserCharge} but listener not credited.`);
      }
    }

    // Update call record
    await client.query(
      `UPDATE calls
       SET status = 'completed',
           duration_seconds = $2,
           billed_minutes = $3,
           total_cost = $4,
           rate_per_minute = $5,
           ended_at = CURRENT_TIMESTAMP
       WHERE call_id = $1`,
      [callId, durationSeconds, billedMinutes, billedUserCharge, userRate]
    );

    // Create immutable billing record (unique index on call_id prevents duplicates)
    await client.query(
      `INSERT INTO call_records (
         call_id, user_id, listener_id, minutes, user_charge, listener_earn, started_at, ended_at
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, CURRENT_TIMESTAMP)`,
      [
        callId,
        call.caller_id,
        call.listener_id,
        billedMinutes,
        billedUserCharge,
        billedListenerEarn,
        call.started_at
      ]
    );

    // Audit log
    await client.query(
      `INSERT INTO call_billing_audit (
         call_id, user_id, listener_id, minutes, user_charge, listener_earn, user_rate_per_min, listener_payout_per_min
       ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        callId,
        call.caller_id,
        call.listener_id,
        billedMinutes,
        billedUserCharge,
        billedListenerEarn,
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
      minutes: billedMinutes,
      userCharge: billedUserCharge,
      listenerEarn: billedListenerEarn
    };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
};

export { calculateCallCharge, finalizeCallBilling, calculateMaxCallDuration, markCallStarted };
