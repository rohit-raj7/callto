import React, { useEffect, useMemo, useState } from 'react';
import toast from 'react-hot-toast';
import { Clock3, Save, Percent } from 'lucide-react';
import { getOfferBannerConfig, updateOfferBannerConfig } from '../services/api';

const defaultForm = {
  title: 'Limited Time Offer',
  headline: 'Flat 25% OFF',
  subtext: 'on recharge of INR 100',
  buttonText: 'Recharge for INR 75',
  countdownPrefix: 'Offer ends in',
  rechargeAmount: '100',
  discountedAmount: '75',
  startsAt: '',
  expiresAt: '',
  isActive: false,
};

const toDateTimeLocalValue = (value) => {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  const tzOffsetMs = date.getTimezoneOffset() * 60 * 1000;
  return new Date(date.getTime() - tzOffsetMs).toISOString().slice(0, 16);
};

const toIsoOrNull = (value) => {
  if (!value) return null;
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
};

const OfferBannerConfig = () => {
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [updatedAt, setUpdatedAt] = useState(null);
  const [form, setForm] = useState(defaultForm);

  useEffect(() => {
    const loadConfig = async () => {
      try {
        setLoading(true);
        const response = await getOfferBannerConfig();
        const config = response.data?.offerBanner;
        if (config) {
          setForm({
            title: config.title ?? defaultForm.title,
            headline: config.headline ?? defaultForm.headline,
            subtext: config.subtext ?? defaultForm.subtext,
            buttonText: config.buttonText ?? defaultForm.buttonText,
            countdownPrefix: config.countdownPrefix ?? defaultForm.countdownPrefix,
            rechargeAmount: String(config.rechargeAmount ?? defaultForm.rechargeAmount),
            discountedAmount: String(config.discountedAmount ?? defaultForm.discountedAmount),
            startsAt: toDateTimeLocalValue(config.startsAt),
            expiresAt: toDateTimeLocalValue(config.expiresAt),
            isActive: config.isActive === true,
          });
          setUpdatedAt(config.updatedAt || null);
        }
      } catch (error) {
        toast.error('Failed to load offer banner config');
      } finally {
        setLoading(false);
      }
    };

    loadConfig();
  }, []);

  const savingsAmount = useMemo(() => {
    const rechargeAmount = Number(form.rechargeAmount);
    const discountedAmount = Number(form.discountedAmount);
    if (!Number.isFinite(rechargeAmount) || !Number.isFinite(discountedAmount)) {
      return null;
    }
    const amount = rechargeAmount - discountedAmount;
    return amount > 0 ? amount : 0;
  }, [form.rechargeAmount, form.discountedAmount]);

  const handleInputChange = (field) => (event) => {
    const value = event.target.value;
    setForm((prev) => ({ ...prev, [field]: value }));
  };

  const saveOfferBanner = async ({ activeValue, successMessage, overrideStartsAt, overrideExpiresAt }) => {
    const rechargeAmount = Number(form.rechargeAmount);
    const discountedAmount = Number(form.discountedAmount);

    if (!form.title.trim()) {
      toast.error('Title is required');
      return;
    }
    if (!form.headline.trim()) {
      toast.error('Headline is required');
      return;
    }
    if (!form.subtext.trim()) {
      toast.error('Subtext is required');
      return;
    }
    if (!form.buttonText.trim()) {
      toast.error('Button text is required');
      return;
    }
    if (!form.countdownPrefix.trim()) {
      toast.error('Countdown prefix is required');
      return;
    }
    if (!Number.isFinite(rechargeAmount) || rechargeAmount <= 0) {
      toast.error('Recharge amount must be a positive number');
      return;
    }
    if (!Number.isFinite(discountedAmount) || discountedAmount <= 0) {
      toast.error('Discounted amount must be a positive number');
      return;
    }
    if (discountedAmount >= rechargeAmount) {
      toast.error('Discounted amount must be lower than recharge amount');
      return;
    }
    const effectiveStartsAt = overrideStartsAt !== undefined ? overrideStartsAt : form.startsAt;
    const effectiveExpiresAt = overrideExpiresAt !== undefined ? overrideExpiresAt : form.expiresAt;
    const startsAtIso = toIsoOrNull(effectiveStartsAt);
    const expiresAtIso = toIsoOrNull(effectiveExpiresAt);
    if (!expiresAtIso) {
      toast.error('Offer expiry date and time is required');
      return;
    }
    if (effectiveStartsAt && !startsAtIso) {
      toast.error('Start date/time is invalid');
      return;
    }
    if (startsAtIso && new Date(expiresAtIso) <= new Date(startsAtIso)) {
      toast.error('Expiry date/time must be greater than start date/time');
      return;
    }

    try {
      setSaving(true);
      const response = await updateOfferBannerConfig({
        title: form.title.trim(),
        headline: form.headline.trim(),
        subtext: form.subtext.trim(),
        buttonText: form.buttonText.trim(),
        countdownPrefix: form.countdownPrefix.trim(),
        rechargeAmount,
        discountedAmount,
        minWalletBalance: 5,
        startsAt: startsAtIso,
        expiresAt: expiresAtIso,
        isActive: activeValue,
      });

      const updated = response.data?.offerBanner;
      if (updated) {
        setUpdatedAt(updated.updatedAt || null);
        setForm((prev) => ({
          ...prev,
          startsAt: toDateTimeLocalValue(updated.startsAt),
          expiresAt: toDateTimeLocalValue(updated.expiresAt),
          isActive: updated.isActive === true,
        }));
      }
      toast.success(successMessage);
      return true;
    } catch (error) {
      const msg = error?.response?.data?.error || 'Failed to update offer banner';
      toast.error(msg);
      return false;
    } finally {
      setSaving(false);
    }
  };

  const handleToggle = async () => {
    if (loading || saving) return;
    const nextValue = !form.isActive;

    // When enabling the banner, auto-extend expiresAt if it's in the past
    let newStartsAt;
    let newExpiresAt;
    if (nextValue) {
      const currentExpiry = form.expiresAt ? new Date(form.expiresAt) : null;
      if (!currentExpiry || Number.isNaN(currentExpiry.getTime()) || currentExpiry <= new Date()) {
        const extendedExpiry = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // +7 days
        const now = new Date();
        newStartsAt = toDateTimeLocalValue(now.toISOString());
        newExpiresAt = toDateTimeLocalValue(extendedExpiry.toISOString());
        setForm((prev) => ({
          ...prev,
          isActive: nextValue,
          expiresAt: newExpiresAt,
          startsAt: newStartsAt,
        }));
        toast('Expiry was in the past — auto-extended to 7 days from now', { icon: 'ℹ️' });
      } else {
        setForm((prev) => ({ ...prev, isActive: nextValue }));
      }
    } else {
      setForm((prev) => ({ ...prev, isActive: nextValue }));
    }

    const success = await saveOfferBanner({
      activeValue: nextValue,
      successMessage: nextValue ? 'Banner enabled' : 'Banner disabled',
      ...(newStartsAt !== undefined && { overrideStartsAt: newStartsAt }),
      ...(newExpiresAt !== undefined && { overrideExpiresAt: newExpiresAt }),
    });

    if (!success) {
      setForm((prev) => ({ ...prev, isActive: !nextValue }));
    }
  };

  const handleSave = async () => {
    await saveOfferBanner({
      activeValue: form.isActive,
      successMessage: 'Offer banner updated successfully',
    });
  };

  return (
    <div className="p-6 bg-gray-50 dark:bg-gray-900 min-h-screen">
      <div className="mb-6 flex flex-col gap-2">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-orange-500 to-pink-500 flex items-center justify-center shadow-lg">
            <Percent className="w-5 h-5 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Offer Banner</h1>
        </div>
        <p className="text-gray-600 dark:text-gray-400">
          Create and control the user-home promotional banner from one place.
        </p>
        <p className="text-xs text-gray-500 dark:text-gray-400">
          Eligibility rule: banner is shown only to users with wallet balance below INR 5.
        </p>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 p-6 space-y-6">
        {loading ? (
          <div className="text-gray-500 dark:text-gray-400">Loading offer banner config...</div>
        ) : (
          <>
            <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4 p-4 rounded-xl bg-gray-50 dark:bg-gray-700/50 border border-gray-200 dark:border-gray-600">
              <div>
                <p className="text-sm font-semibold text-gray-900 dark:text-gray-100">Banner Display Toggle</p>
                <p className="text-xs text-gray-600 dark:text-gray-400">
                  When disabled, no user will see this banner even if dates are valid.
                </p>
              </div>
              <button
                type="button"
                onClick={handleToggle}
                disabled={loading || saving}
                className={`relative inline-flex h-8 w-16 items-center rounded-full transition-colors ${
                  form.isActive ? 'bg-emerald-500' : 'bg-gray-300 dark:bg-gray-600'
                } disabled:opacity-60 disabled:cursor-not-allowed`}
                aria-label="Toggle offer banner visibility"
              >
                <span
                  className={`inline-block h-6 w-6 transform rounded-full bg-white shadow transition-transform ${
                    form.isActive ? 'translate-x-9' : 'translate-x-1'
                  }`}
                />
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Title</label>
                <input
                  type="text"
                  value={form.title}
                  onChange={handleInputChange('title')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Headline</label>
                <input
                  type="text"
                  value={form.headline}
                  onChange={handleInputChange('headline')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
              <div className="md:col-span-2">
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Subtext</label>
                <input
                  type="text"
                  value={form.subtext}
                  onChange={handleInputChange('subtext')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Recharge Button Text</label>
                <input
                  type="text"
                  value={form.buttonText}
                  onChange={handleInputChange('buttonText')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Countdown Prefix</label>
                <input
                  type="text"
                  value={form.countdownPrefix}
                  onChange={handleInputChange('countdownPrefix')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Recharge Amount (INR)</label>
                <input
                  type="number"
                  min="1"
                  step="0.01"
                  value={form.rechargeAmount}
                  onChange={handleInputChange('rechargeAmount')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Discounted Amount (INR)</label>
                <input
                  type="number"
                  min="1"
                  step="0.01"
                  value={form.discountedAmount}
                  onChange={handleInputChange('discountedAmount')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Starts At (optional)</label>
                <input
                  type="datetime-local"
                  value={form.startsAt}
                  onChange={handleInputChange('startsAt')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">Expires At</label>
                <input
                  type="datetime-local"
                  value={form.expiresAt}
                  onChange={handleInputChange('expiresAt')}
                  className="w-full rounded-lg border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-gray-900 dark:text-white"
                />
              </div>
            </div>

            <div className="rounded-xl p-5 bg-gradient-to-r from-orange-500 to-pink-500 text-white shadow-lg">
              <div className="flex items-center gap-2 text-sm font-semibold mb-3 bg-white/20 w-fit rounded-full px-3 py-1">
                <Clock3 className="w-4 h-4" />
                <span>{form.countdownPrefix || 'Offer ends in'} 09:36:55</span>
              </div>
              <p className="text-sm opacity-90">{form.title || 'Limited Time Offer'}</p>
              <p className="text-3xl font-bold mt-1">{form.headline || 'Flat 25% OFF'}</p>
              <p className="text-sm mt-1 opacity-95">{form.subtext || 'on recharge of INR 100'}</p>
              <button
                type="button"
                className="mt-4 rounded-lg bg-white text-pink-700 px-4 py-2 text-sm font-semibold shadow"
              >
                {form.buttonText || 'Recharge for INR 75'}
              </button>
              {savingsAmount !== null && (
                <p className="text-xs mt-3 opacity-90">
                  User saves INR {savingsAmount.toFixed(2)} on this recharge.
                </p>
              )}
            </div>

            <div className="flex items-center justify-between">
              <div className="text-xs text-gray-500 dark:text-gray-400">
                {updatedAt ? `Last updated: ${new Date(updatedAt).toLocaleString()}` : 'Not updated yet'}
              </div>
              <button
                type="button"
                onClick={handleSave}
                disabled={saving}
                className="inline-flex items-center gap-2 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white px-5 py-2 text-sm font-semibold disabled:opacity-60"
              >
                <Save className="w-4 h-4" />
                {saving ? 'Saving...' : 'Save changes'}
              </button>
            </div>
          </>
        )}
      </div>
    </div>
  );
};

export default OfferBannerConfig;
