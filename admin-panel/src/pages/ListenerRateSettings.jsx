import React, { useEffect, useState } from 'react';
import { getAdminListeners, updateListenerRates } from '../services/api';

const ListenerRateSettings = () => {
  const [listeners, setListeners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState(null);
  const [error, setError] = useState(null);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    fetchListeners();
  }, []);

  const fetchListeners = async () => {
    try {
      setLoading(true);
      const res = await getAdminListeners();
      const rows = (res.data.listeners || []).map((listener) => ({
        ...listener,
        user_rate_per_min: listener.user_rate_per_min ?? 0,
        listener_payout_per_min: listener.listener_payout_per_min ?? 0
      }));
      setListeners(rows);
      setError(null);
    } catch (err) {
      setError('Failed to load listeners');
    } finally {
      setLoading(false);
    }
  };

  const updateRateField = (listenerId, field, value) => {
    setListeners((prev) =>
      prev.map((listener) =>
        listener.listener_id === listenerId
          ? { ...listener, [field]: value }
          : listener
      )
    );
  };

  const saveRates = async (listener) => {
    const userRate = Number(listener.user_rate_per_min);
    const payoutRate = Number(listener.listener_payout_per_min);

    if (!Number.isFinite(userRate) || userRate <= 0) {
      setMessage('User call rate must be a positive number');
      return;
    }

    if (!Number.isFinite(payoutRate) || payoutRate <= 0) {
      setMessage('Listener payout rate must be a positive number');
      return;
    }

    if (payoutRate > userRate) {
      setMessage('Listener payout rate must be <= user call rate');
      return;
    }

    try {
      setSavingId(listener.listener_id);
      setMessage(null);
      await updateListenerRates(listener.listener_id, {
        userRatePerMin: userRate,
        listenerPayoutPerMin: payoutRate
      });
      setMessage('Rates updated successfully');
    } catch (err) {
      setMessage('Failed to update rates');
    } finally {
      setSavingId(null);
    }
  };

  return (
    <div className="p-6 bg-gray-50 dark:bg-gray-900 min-h-screen">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Listener Rate Settings</h1>
        <p className="text-gray-600 dark:text-gray-400">Set user-visible and payout rates per listener.</p>
      </div>

      {error && (
        <div className="mb-4 rounded-lg bg-red-50 text-red-700 px-4 py-3">{error}</div>
      )}
      {message && (
        <div className="mb-4 rounded-lg bg-green-50 text-green-700 px-4 py-3">{message}</div>
      )}

      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <div className="grid grid-cols-12 gap-4 text-sm font-semibold text-gray-600 dark:text-gray-300">
            <div className="col-span-4">Listener</div>
            <div className="col-span-3">User Call Rate (₹/min)</div>
            <div className="col-span-3">Listener Payout Rate (₹/min)</div>
            <div className="col-span-2">Action</div>
          </div>
        </div>

        {loading ? (
          <div className="p-6 text-gray-500 dark:text-gray-400">Loading listeners...</div>
        ) : (
          listeners.map((listener) => (
            <div
              key={listener.listener_id}
              className="grid grid-cols-12 gap-4 items-center px-4 py-4 border-b border-gray-100 dark:border-gray-700"
            >
              <div className="col-span-4">
                <p className="font-medium text-gray-900 dark:text-white">{listener.name}</p>
                <p className="text-xs text-gray-500">{listener.listener_id}</p>
              </div>
              <div className="col-span-3">
                <input
                  type="number"
                  step="0.01"
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                  value={listener.user_rate_per_min}
                  onChange={(e) => updateRateField(listener.listener_id, 'user_rate_per_min', e.target.value)}
                />
              </div>
              <div className="col-span-3">
                <input
                  type="number"
                  step="0.01"
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                  value={listener.listener_payout_per_min}
                  onChange={(e) => updateRateField(listener.listener_id, 'listener_payout_per_min', e.target.value)}
                />
              </div>
              <div className="col-span-2">
                <button
                  className="w-full rounded-lg bg-indigo-600 text-white px-3 py-2 text-sm font-semibold disabled:opacity-50"
                  disabled={savingId === listener.listener_id}
                  onClick={() => saveRates(listener)}
                >
                  {savingId === listener.listener_id ? 'Saving...' : 'Save'}
                </button>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default ListenerRateSettings;
