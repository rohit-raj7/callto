import React, { useEffect, useState } from 'react';
import toast from 'react-hot-toast';
import { getChatChargeConfig, updateChatChargeConfig } from '../services/api';

const ChatChargeConfig = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [updatedAt, setUpdatedAt] = useState(null);
  const [form, setForm] = useState({
    chargingEnabled: false,
    freeMessageLimit: '',
    messageBlockSize: '',
    chargePerMessageBlock: ''
  });

  useEffect(() => {
    const loadConfig = async () => {
      try {
        setLoading(true);
        const res = await getChatChargeConfig();
        const config = res.data?.chatChargeConfig;
        if (config) {
          setForm({
            chargingEnabled: config.chargingEnabled === true,
            freeMessageLimit: config.freeMessageLimit ?? '',
            messageBlockSize: config.messageBlockSize ?? '',
            chargePerMessageBlock: config.chargePerMessageBlock ?? ''
          });
          setUpdatedAt(config.updatedAt || null);
        }
      } catch (error) {
        toast.error('Failed to load chat charge config');
      } finally {
        setLoading(false);
      }
    };

    loadConfig();
  }, []);

  const handleChange = (field) => (event) => {
    const value = field === 'chargingEnabled'
      ? event.target.checked
      : event.target.value;
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSave = async () => {
    const chargingEnabled = form.chargingEnabled === true;
    const freeMessageLimit = Number(form.freeMessageLimit);
    const messageBlockSize = Number(form.messageBlockSize);
    const chargePerMessageBlock = Number(form.chargePerMessageBlock);

    if (!Number.isFinite(freeMessageLimit) || freeMessageLimit < 0) {
      toast.error('Free message limit must be a non-negative number');
      return;
    }

    if (chargingEnabled) {
      if (!Number.isFinite(messageBlockSize) || messageBlockSize <= 0) {
        toast.error('Message block size must be a positive number');
        return;
      }
      if (!Number.isFinite(chargePerMessageBlock) || chargePerMessageBlock <= 0) {
        toast.error('Charge per message block must be a positive number');
        return;
      }
    }

    try {
      setSaving(true);
      const res = await updateChatChargeConfig({
        chargingEnabled,
        freeMessageLimit,
        messageBlockSize: chargingEnabled ? messageBlockSize : (messageBlockSize || 2),
        chargePerMessageBlock: chargingEnabled ? chargePerMessageBlock : (chargePerMessageBlock || 1.00)
      });
      const updated = res.data?.chatChargeConfig;
      if (updated) {
        setForm({
          chargingEnabled: updated.chargingEnabled === true,
          freeMessageLimit: updated.freeMessageLimit ?? freeMessageLimit,
          messageBlockSize: updated.messageBlockSize ?? (chargingEnabled ? messageBlockSize : ''),
          chargePerMessageBlock: updated.chargePerMessageBlock ?? (chargingEnabled ? chargePerMessageBlock : '')
        });
        setUpdatedAt(updated.updatedAt || null);
      }
      toast.success('Chat charge config updated');
    } catch (error) {
      toast.error('Failed to update chat charge config');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="p-6 bg-gray-50 dark:bg-gray-900 min-h-screen">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Chat Charge Config</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Configure per-message charging for user chats. Listeners are never charged.
        </p>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 space-y-6">
        {loading ? (
          <div className="text-gray-500 dark:text-gray-400">Loading chat charge config...</div>
        ) : (
          <>
            {/* Enable/Disable Toggle */}
            <div className="flex items-center gap-3 p-4 bg-gray-50 dark:bg-gray-700 rounded-lg">
              <input
                id="chargingEnabled"
                type="checkbox"
                className="h-5 w-5 rounded"
                checked={form.chargingEnabled}
                onChange={handleChange('chargingEnabled')}
              />
              <label htmlFor="chargingEnabled" className="text-sm font-semibold text-gray-700 dark:text-gray-300">
                Enable chat charging for users
              </label>
              <span className="ml-auto text-xs text-gray-500 dark:text-gray-400">
                {form.chargingEnabled ? '🟢 Active' : '🔴 Disabled'}
              </span>
            </div>

            {/* Config Fields */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Free Messages Per User (Global)
                </label>
                <input
                  type="number"
                  step="1"
                  min="0"
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                  value={form.freeMessageLimit}
                  onChange={handleChange('freeMessageLimit')}
                  placeholder="e.g. 5"
                />
                <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  Total free messages each user gets globally (across all listeners). Does not reset on chat clear.
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Message Block Size
                </label>
                <input
                  type="number"
                  step="1"
                  min="1"
                  disabled={!form.chargingEnabled}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white disabled:opacity-50"
                  value={form.messageBlockSize}
                  onChange={handleChange('messageBlockSize')}
                  placeholder="e.g. 2"
                />
                <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  Number of paid messages per charge. e.g. 2 means charge every 2 messages.
                </p>
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Charge Per Block (₹)
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  disabled={!form.chargingEnabled}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white disabled:opacity-50"
                  value={form.chargePerMessageBlock}
                  onChange={handleChange('chargePerMessageBlock')}
                  placeholder="e.g. 1.00"
                />
                <p className="mt-1 text-xs text-gray-500 dark:text-gray-400">
                  Amount (₹) charged per message block.
                </p>
              </div>
            </div>

            {/* Summary */}
            {form.chargingEnabled && form.freeMessageLimit !== '' && form.messageBlockSize !== '' && form.chargePerMessageBlock !== '' && (
              <div className="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
                <p className="text-sm text-blue-800 dark:text-blue-300">
                  <strong>Summary:</strong> Each user gets <strong>{form.freeMessageLimit}</strong> free messages globally (across all conversations). 
                  After that, <strong>₹{form.chargePerMessageBlock}</strong> is charged every <strong>{form.messageBlockSize}</strong> message(s).
                  Clearing chat or switching listeners does not reset the free count. Listeners are never charged.
                </p>
              </div>
            )}

            <div className="flex items-center justify-between">
              <div className="text-xs text-gray-500 dark:text-gray-400">
                {updatedAt ? `Last updated: ${new Date(updatedAt).toLocaleString()}` : 'Not updated yet'}
              </div>
              <button
                className="rounded-lg bg-indigo-600 text-white px-5 py-2 text-sm font-semibold disabled:opacity-50 hover:bg-indigo-700 transition-colors"
                onClick={handleSave}
                disabled={saving}
              >
                {saving ? 'Saving...' : 'Save changes'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default ChatChargeConfig;
