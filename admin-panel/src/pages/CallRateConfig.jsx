import React, { useEffect, useState } from 'react';
import toast from 'react-hot-toast';
import { getRateConfig, updateRateConfig } from '../services/api';

const CallRateConfig = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [updatedAt, setUpdatedAt] = useState(null);
  const [form, setForm] = useState({
    normalPerMinuteRate: '',
    firstTimeOfferEnabled: false,
    offerMinutesLimit: '',
    offerFlatPrice: ''
  });

  useEffect(() => {
    const loadConfig = async () => {
      try {
        setLoading(true);
        const res = await getRateConfig();
        const rateConfig = res.data?.rateConfig;
        if (rateConfig) {
          setForm({
            normalPerMinuteRate: rateConfig.normalPerMinuteRate ?? '',
            firstTimeOfferEnabled: rateConfig.firstTimeOfferEnabled === true,
            offerMinutesLimit: rateConfig.offerMinutesLimit ?? '',
            offerFlatPrice: rateConfig.offerFlatPrice ?? ''
          });
          setUpdatedAt(rateConfig.updatedAt || null);
        }
      } catch (error) {
        toast.error('Failed to load rate config');
      } finally {
        setLoading(false);
      }
    };

    loadConfig();
  }, []);

  const handleChange = (field) => (event) => {
    const value = field === 'firstTimeOfferEnabled'
      ? event.target.checked
      : event.target.value;
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const handleSave = async () => {
    const normalPerMinuteRate = Number(form.normalPerMinuteRate);
    const offerMinutesLimit = Number(form.offerMinutesLimit);
    const offerFlatPrice = Number(form.offerFlatPrice);
    const firstTimeOfferEnabled = form.firstTimeOfferEnabled === true;

    if (!Number.isFinite(normalPerMinuteRate) || normalPerMinuteRate <= 0) {
      toast.error('Normal rate per minute must be a positive number');
      return;
    }

    if (firstTimeOfferEnabled) {
      if (!Number.isFinite(offerMinutesLimit) || offerMinutesLimit <= 0) {
        toast.error('Offer minutes limit must be a positive number');
        return;
      }
      if (!Number.isFinite(offerFlatPrice) || offerFlatPrice <= 0) {
        toast.error('Offer flat price must be a positive number');
        return;
      }
    }

    try {
      setSaving(true);
      const res = await updateRateConfig({
        normalPerMinuteRate,
        firstTimeOfferEnabled,
        offerMinutesLimit: firstTimeOfferEnabled ? offerMinutesLimit : null,
        offerFlatPrice: firstTimeOfferEnabled ? offerFlatPrice : null
      });
      const updated = res.data?.rateConfig;
      if (updated) {
        setForm({
          normalPerMinuteRate: updated.normalPerMinuteRate ?? normalPerMinuteRate,
          firstTimeOfferEnabled: updated.firstTimeOfferEnabled === true,
          offerMinutesLimit: updated.offerMinutesLimit ?? (firstTimeOfferEnabled ? offerMinutesLimit : ''),
          offerFlatPrice: updated.offerFlatPrice ?? (firstTimeOfferEnabled ? offerFlatPrice : '')
        });
        setUpdatedAt(updated.updatedAt || null);
      }
      toast.success('Rate config updated');
    } catch (error) {
      toast.error('Failed to update rate config');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="p-6 bg-gray-50 dark:bg-gray-900 min-h-screen">
      <div className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Call Rate Config (First Time User Offer)</h1>
        <p className="text-gray-600 dark:text-gray-400">
          Configure the normal call rate and first-time user offer settings.
        </p>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-6 space-y-6">
        {loading ? (
          <div className="text-gray-500 dark:text-gray-400">Loading rate config...</div>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Normal Rate (₹/min)
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                  value={form.normalPerMinuteRate}
                  onChange={handleChange('normalPerMinuteRate')}
                />
              </div>
              <div className="flex items-center gap-3">
                <input
                  id="firstTimeOfferEnabled"
                  type="checkbox"
                  className="h-4 w-4"
                  checked={form.firstTimeOfferEnabled}
                  onChange={handleChange('firstTimeOfferEnabled')}
                />
                <label htmlFor="firstTimeOfferEnabled" className="text-sm font-medium text-gray-700 dark:text-gray-300">
                  Enable first-time offer
                </label>
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Offer Minutes Limit
                </label>
                <input
                  type="number"
                  step="1"
                  min="0"
                  disabled={!form.firstTimeOfferEnabled}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white disabled:opacity-50"
                  value={form.offerMinutesLimit}
                  onChange={handleChange('offerMinutesLimit')}
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Offer Flat Price (₹)
                </label>
                <input
                  type="number"
                  step="0.01"
                  min="0"
                  disabled={!form.firstTimeOfferEnabled}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white disabled:opacity-50"
                  value={form.offerFlatPrice}
                  onChange={handleChange('offerFlatPrice')}
                />
              </div>
            </div>

            <div className="flex items-center justify-between">
              <div className="text-xs text-gray-500 dark:text-gray-400">
                {updatedAt ? `Last updated: ${new Date(updatedAt).toLocaleString()}` : 'Not updated yet'}
              </div>
              <button
                className="rounded-lg bg-indigo-600 text-white px-5 py-2 text-sm font-semibold disabled:opacity-50"
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

export default CallRateConfig;
