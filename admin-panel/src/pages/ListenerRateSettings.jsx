import React, { useEffect, useState, useMemo, useCallback, useRef } from 'react';
import { getAdminListeners, updateListenerRates } from '../services/api';

/* ── Bayesian average ──────────────────────────────────────────────────
   Smooths ratings for listeners with few reviews so a single 5★ review
   doesn't outrank a consistent 4.8★ with 50+ reviews.
   Formula:  (C·m  +  Σ ratings) / (C + n)
     C = confidence weight (min reviews before we trust raw avg)
     m = global prior mean
     n = this listener's review count                                  */
const bayesianAvg = (avg, n, globalMean, C = 5) => {
  if (n === 0) return 0;
  return (C * globalMean + avg * n) / (C + n);
};

/* ── Helpers ────────────────────────────────────────────────────────── */
const fmt = (mins) => {
  const m = Number(mins) || 0;
  if (m === 0) return '0 min';
  if (m < 60) return `${m.toFixed(1)} min`;
  const h = Math.floor(m / 60);
  const r = Math.round(m % 60);
  return r > 0 ? `${h}h ${r}m` : `${h}h`;
};

const ratingColor = (r) => {
  if (r === 0) return 'bg-gray-100 text-gray-500 dark:bg-gray-700 dark:text-gray-400';
  if (r >= 4.5) return 'bg-emerald-100 text-emerald-700 dark:bg-emerald-900/30 dark:text-emerald-400';
  if (r >= 3.5) return 'bg-sky-100 text-sky-700 dark:bg-sky-900/30 dark:text-sky-400';
  if (r >= 2.5) return 'bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-400';
  return 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400';
};

const marginColor = (pct) => {
  if (pct >= 70) return 'text-emerald-600 dark:text-emerald-400';
  if (pct >= 50) return 'text-sky-600 dark:text-sky-400';
  if (pct >= 30) return 'text-amber-600 dark:text-amber-400';
  return 'text-red-600 dark:text-red-400';
};

/* ── Star Rating ───────────────────────────────────────────────────── */
const StarRating = ({ rating, id }) => {
  const full = Math.floor(rating);
  const fraction = rating - full;
  const hasHalf = fraction >= 0.25 && fraction < 0.75;
  const roundUp = fraction >= 0.75;
  const filled = full + (roundUp ? 1 : 0);
  const empty = Math.max(0, 5 - filled - (hasHalf ? 1 : 0));
  const gradId = `half-${id}`;

  const starPath = 'M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z';

  return (
    <div className="flex items-center gap-px">
      {[...Array(filled)].map((_, i) => (
        <svg key={`f${i}`} className="w-3.5 h-3.5 text-amber-400" fill="currentColor" viewBox="0 0 20 20"><path d={starPath} /></svg>
      ))}
      {hasHalf && (
        <svg className="w-3.5 h-3.5" viewBox="0 0 20 20">
          <defs>
            <linearGradient id={gradId}>
              <stop offset="50%" stopColor="#FBBF24" />
              <stop offset="50%" stopColor="#D1D5DB" />
            </linearGradient>
          </defs>
          <path fill={`url(#${gradId})`} d={starPath} />
        </svg>
      )}
      {[...Array(empty)].map((_, i) => (
        <svg key={`e${i}`} className="w-3.5 h-3.5 text-gray-300 dark:text-gray-600" fill="currentColor" viewBox="0 0 20 20"><path d={starPath} /></svg>
      ))}
    </div>
  );
};

/* ── Stat Card ─────────────────────────────────────────────────────── */
const StatCard = ({ icon, label, value, sub }) => (
  <div className="bg-white dark:bg-gray-800 rounded-xl p-4 shadow-sm border border-gray-100 dark:border-gray-700">
    <div className="flex items-center gap-2 mb-2">
      <span className="text-lg">{icon}</span>
      <span className="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">{label}</span>
    </div>
    <p className="text-2xl font-bold text-gray-900 dark:text-white">{value}</p>
    {sub && <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">{sub}</p>}
  </div>
);

/* ── Skeleton Row ──────────────────────────────────────────────────── */
const SkeletonRow = () => (
  <div className="grid grid-cols-12 gap-4 items-center px-5 py-4 border-b border-gray-100 dark:border-gray-700 animate-pulse">
    <div className="col-span-3"><div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-3/4" /><div className="h-3 bg-gray-100 dark:bg-gray-700 rounded w-1/2 mt-2" /></div>
    <div className="col-span-2"><div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-2/3" /></div>
    <div className="col-span-1"><div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-full" /></div>
    <div className="col-span-2"><div className="h-8 bg-gray-200 dark:bg-gray-700 rounded" /></div>
    <div className="col-span-2"><div className="h-8 bg-gray-200 dark:bg-gray-700 rounded" /></div>
    <div className="col-span-2"><div className="h-8 bg-gray-200 dark:bg-gray-700 rounded" /></div>
  </div>
);

/* ═══════════════════════════════════════════════════════════════════ */
const ListenerRateSettings = () => {
  const [listeners, setListeners] = useState([]);
  const [loading, setLoading] = useState(true);
  const [savingId, setSavingId] = useState(null);
  const [error, setError] = useState(null);
  const [toast, setToast] = useState(null);      // { type, text }
  const toastTimer = useRef(null);

  // Filters
  const [minRating, setMinRating] = useState('');
  const [maxRating, setMaxRating] = useState('');
  const [minMinutes, setMinMinutes] = useState('');
  const [maxMinutes, setMaxMinutes] = useState('');
  const [sortBy, setSortBy] = useState('name');
  const [sortOrder, setSortOrder] = useState('desc');
  const [searchQuery, setSearchQuery] = useState('');

  const showToast = useCallback((type, text) => {
    clearTimeout(toastTimer.current);
    setToast({ type, text });
    toastTimer.current = setTimeout(() => setToast(null), 4000);
  }, []);

  useEffect(() => { fetchListeners(); return () => clearTimeout(toastTimer.current); }, []);

  const fetchListeners = async () => {
    try {
      setLoading(true);
      const res = await getAdminListeners();
      const rows = (res.data.listeners || []).map((l) => ({
        ...l,
        user_rate_per_min: l.user_rate_per_min ?? 0,
        listener_payout_per_min: l.listener_payout_per_min ?? 0,
        computed_avg_rating: Number(l.computed_avg_rating) || 0,
        computed_total_ratings: Number(l.computed_total_ratings) || 0,
        total_call_minutes: Number(l.total_call_minutes) || 0,
        total_calls: Number(l.total_calls) || 0,
      }));
      setListeners(rows);
      setError(null);
    } catch {
      setError('Failed to load listeners');
    } finally {
      setLoading(false);
    }
  };

  /* ── Derived data ────────────────────────────────────────────────── */
  const globalMean = useMemo(() => {
    const rated = listeners.filter((l) => l.computed_total_ratings > 0);
    if (!rated.length) return 3.0;
    return rated.reduce((s, l) => s + l.computed_avg_rating, 0) / rated.length;
  }, [listeners]);

  const filteredListeners = useMemo(() => {
    let list = listeners.map((l) => ({
      ...l,
      bayesian: bayesianAvg(l.computed_avg_rating, l.computed_total_ratings, globalMean),
    }));

    if (searchQuery.trim()) {
      const q = searchQuery.toLowerCase();
      list = list.filter((l) =>
        (l.name || '').toLowerCase().includes(q) || (l.listener_id || '').toLowerCase().includes(q)
      );
    }
    if (minRating !== '') { const v = Number(minRating); if (Number.isFinite(v)) list = list.filter((l) => l.computed_avg_rating >= v); }
    if (maxRating !== '') { const v = Number(maxRating); if (Number.isFinite(v)) list = list.filter((l) => l.computed_avg_rating <= v); }
    if (minMinutes !== '') { const v = Number(minMinutes); if (Number.isFinite(v)) list = list.filter((l) => l.total_call_minutes >= v); }
    if (maxMinutes !== '') { const v = Number(maxMinutes); if (Number.isFinite(v)) list = list.filter((l) => l.total_call_minutes <= v); }

    list.sort((a, b) => {
      let c = 0;
      if (sortBy === 'rating') c = a.bayesian - b.bayesian;
      else if (sortBy === 'minutes') c = a.total_call_minutes - b.total_call_minutes;
      else c = (a.name || '').localeCompare(b.name || '');
      return sortOrder === 'asc' ? c : -c;
    });
    return list;
  }, [listeners, searchQuery, minRating, maxRating, minMinutes, maxMinutes, sortBy, sortOrder, globalMean]);

  const stats = useMemo(() => {
    const rated = listeners.filter((l) => l.computed_total_ratings > 0);
    const totalMins = listeners.reduce((s, l) => s + l.total_call_minutes, 0);
    const totalReviews = listeners.reduce((s, l) => s + l.computed_total_ratings, 0);
    return {
      total: listeners.length,
      rated: rated.length,
      avgRating: rated.length ? (rated.reduce((s, l) => s + l.computed_avg_rating, 0) / rated.length).toFixed(2) : '—',
      totalMinutes: fmt(totalMins),
      totalReviews,
    };
  }, [listeners]);

  /* ── Actions ─────────────────────────────────────────────────────── */
  const updateField = (id, field, value) => {
    setListeners((prev) =>
      prev.map((l) => (l.listener_id === id ? { ...l, [field]: value } : l))
    );
  };

  const saveRates = async (listener) => {
    const userRate = Number(listener.user_rate_per_min);
    const payoutRate = Number(listener.listener_payout_per_min);

    if (!Number.isFinite(userRate) || userRate <= 0) return showToast('error', 'User rate must be a positive number');
    if (!Number.isFinite(payoutRate) || payoutRate <= 0) return showToast('error', 'Payout rate must be a positive number');
    if (payoutRate > userRate) return showToast('error', 'Payout rate cannot exceed user rate');

    try {
      setSavingId(listener.listener_id);
      await updateListenerRates(listener.listener_id, {
        userRatePerMin: userRate,
        listenerPayoutPerMin: payoutRate,
      });
      showToast('success', `Rates saved for ${listener.name}`);
    } catch {
      showToast('error', 'Failed to update rates');
    } finally {
      setSavingId(null);
    }
  };

  const clearFilters = () => {
    setMinRating(''); setMaxRating(''); setMinMinutes(''); setMaxMinutes('');
    setSearchQuery(''); setSortBy('name'); setSortOrder('desc');
  };

  const hasFilters = minRating !== '' || maxRating !== '' || minMinutes !== '' || maxMinutes !== '' || searchQuery.trim() !== '';

  const getMargin = (userRate, payoutRate) => {
    const u = Number(userRate) || 0;
    const p = Number(payoutRate) || 0;
    if (u <= 0) return { pct: 0, amount: 0 };
    return { pct: Math.round(((u - p) / u) * 100), amount: (u - p).toFixed(2) };
  };

  /* ── Render ──────────────────────────────────────────────────────── */
  return (
    <div className="p-4 md:p-6 bg-gray-50 dark:bg-gray-900 min-h-screen">
      {/* Header */}
      <div className="flex items-start justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white">Listener Rate Settings</h1>
          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">Manage per-listener billing rates, view performance metrics, and filter by rating or call time.</p>
        </div>
        <button
          onClick={fetchListeners}
          disabled={loading}
          className="inline-flex items-center gap-1.5 px-3 py-2 text-sm font-medium rounded-lg border border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-800 transition-colors disabled:opacity-50"
        >
          <svg className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
          Refresh
        </button>
      </div>

      {/* Toast */}
      {toast && (
        <div className={`mb-4 rounded-lg px-4 py-3 text-sm font-medium flex items-center justify-between transition-all ${
          toast.type === 'success'
            ? 'bg-emerald-50 text-emerald-700 dark:bg-emerald-900/20 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-800'
            : 'bg-red-50 text-red-700 dark:bg-red-900/20 dark:text-red-400 border border-red-200 dark:border-red-800'
        }`}>
          <span>{toast.type === 'success' ? '✓' : '✕'} {toast.text}</span>
          <button onClick={() => setToast(null)} className="ml-3 opacity-60 hover:opacity-100">✕</button>
        </div>
      )}

      {error && (
        <div className="mb-4 rounded-lg bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 border border-red-200 dark:border-red-800 px-4 py-3 text-sm flex items-center justify-between">
          <span>{error}</span>
          <button onClick={fetchListeners} className="ml-3 text-red-600 dark:text-red-400 underline text-xs">Retry</button>
        </div>
      )}

      {/* Summary Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <StatCard icon="👥" label="Listeners" value={stats.total} />
        <StatCard icon="⭐" label="Avg Rating" value={stats.avgRating} sub={`${stats.rated} rated · ${stats.totalReviews} total reviews`} />
        <StatCard icon="📞" label="Total Call Time" value={stats.totalMinutes} sub={`across all listeners`} />
        <StatCard icon="💰" label="Rated Listeners" value={stats.rated} sub={`of ${stats.total} total`} />
      </div>

      {/* Filters */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 p-4 mb-6">
        <div className="flex items-center justify-between mb-3">
          <h2 className="text-sm font-semibold text-gray-700 dark:text-gray-300 flex items-center gap-1.5">
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" /></svg>
            Filters & Sort
          </h2>
          {hasFilters && (
            <button onClick={clearFilters} className="text-xs font-medium text-indigo-600 dark:text-indigo-400 hover:underline">
              Clear all
            </button>
          )}
        </div>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
          <div>
            <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Search</label>
            <div className="relative">
              <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
              <input
                type="text"
                placeholder="Name or ID..."
                className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 pl-9 pr-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Rating Range (0 – 5)</label>
            <div className="flex gap-2">
              <input type="number" step="0.5" min="0" max="5" placeholder="Min" className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none" value={minRating} onChange={(e) => setMinRating(e.target.value)} />
              <input type="number" step="0.5" min="0" max="5" placeholder="Max" className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none" value={maxRating} onChange={(e) => setMaxRating(e.target.value)} />
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Call Minutes Range</label>
            <div className="flex gap-2">
              <input type="number" min="0" placeholder="Min" className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none" value={minMinutes} onChange={(e) => setMinMinutes(e.target.value)} />
              <input type="number" min="0" placeholder="Max" className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2 text-sm text-gray-900 dark:text-white placeholder-gray-400 focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none" value={maxMinutes} onChange={(e) => setMaxMinutes(e.target.value)} />
            </div>
          </div>
          <div>
            <label className="block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1">Sort By</label>
            <div className="flex gap-2">
              <select
                className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2 text-sm text-gray-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                value={sortBy}
                onChange={(e) => setSortBy(e.target.value)}
              >
                <option value="name">Name</option>
                <option value="rating">Rating (Bayesian)</option>
                <option value="minutes">Call Minutes</option>
              </select>
              <button
                className="px-3 py-2 rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 text-sm text-gray-600 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-600 transition-colors shrink-0"
                onClick={() => setSortOrder((o) => (o === 'asc' ? 'desc' : 'asc'))}
                title={sortOrder === 'asc' ? 'Ascending' : 'Descending'}
              >
                {sortOrder === 'asc' ? '↑ Asc' : '↓ Desc'}
              </button>
            </div>
          </div>
        </div>
        {hasFilters && (
          <p className="text-xs text-gray-500 dark:text-gray-400 mt-3 flex items-center gap-1">
            <span className="inline-block w-1.5 h-1.5 rounded-full bg-indigo-500" />
            Showing {filteredListeners.length} of {listeners.length} listeners
          </p>
        )}
      </div>

      {/* Table */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 overflow-hidden">
        {/* Header */}
        <div className="px-5 py-3 border-b border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-800/80">
          <div className="grid grid-cols-12 gap-4 text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
            <div className="col-span-3">Listener</div>
            <div className="col-span-2">Rating</div>
            <div className="col-span-1">Call Time</div>
            <div className="col-span-2">User Rate (₹/min)</div>
            <div className="col-span-2">Payout (₹/min)</div>
            <div className="col-span-2">Action</div>
          </div>
        </div>

        {/* Body */}
        {loading ? (
          <>
            <SkeletonRow /><SkeletonRow /><SkeletonRow /><SkeletonRow /><SkeletonRow />
          </>
        ) : filteredListeners.length === 0 ? (
          <div className="px-5 py-12 text-center">
            <p className="text-gray-400 dark:text-gray-500 text-sm">
              {hasFilters ? 'No listeners match the current filters.' : 'No listeners found.'}
            </p>
            {hasFilters && (
              <button onClick={clearFilters} className="mt-2 text-xs text-indigo-600 dark:text-indigo-400 hover:underline">
                Clear filters
              </button>
            )}
          </div>
        ) : (
          filteredListeners.map((listener, idx) => {
            const margin = getMargin(listener.user_rate_per_min, listener.listener_payout_per_min);
            return (
              <div
                key={listener.listener_id}
                className={`grid grid-cols-12 gap-4 items-center px-5 py-4 border-b border-gray-100 dark:border-gray-700/50 hover:bg-gray-50 dark:hover:bg-gray-700/30 transition-colors ${idx % 2 === 0 ? '' : 'bg-gray-50/50 dark:bg-gray-800/50'}`}
              >
                {/* Listener */}
                <div className="col-span-3 min-w-0">
                  <p className="font-medium text-gray-900 dark:text-white truncate">{listener.name}</p>
                  <p className="text-xs text-gray-400 dark:text-gray-500 font-mono truncate">{listener.listener_id}</p>
                </div>

                {/* Rating */}
                <div className="col-span-2">
                  {listener.computed_total_ratings > 0 ? (
                    <div className="space-y-1">
                      <div className="flex items-center gap-1.5">
                        <StarRating rating={listener.computed_avg_rating} id={listener.listener_id} />
                        <span className={`text-xs font-bold px-1.5 py-0.5 rounded ${ratingColor(listener.computed_avg_rating)}`}>
                          {listener.computed_avg_rating.toFixed(1)}
                        </span>
                      </div>
                      <p className="text-xs text-gray-400 dark:text-gray-500">
                        {listener.computed_total_ratings} review{listener.computed_total_ratings !== 1 ? 's' : ''}
                        {listener.computed_total_ratings < 5 && (
                          <span className="text-amber-500 ml-1" title="Low confidence — fewer than 5 reviews">⚠</span>
                        )}
                      </p>
                    </div>
                  ) : (
                    <span className="text-xs text-gray-400 dark:text-gray-500 italic">No ratings</span>
                  )}
                </div>

                {/* Call Time */}
                <div className="col-span-1">
                  <p className="text-sm font-semibold text-gray-900 dark:text-white">{fmt(listener.total_call_minutes)}</p>
                  <p className="text-xs text-gray-400 dark:text-gray-500">{listener.total_calls} call{listener.total_calls !== 1 ? 's' : ''}</p>
                </div>

                {/* User Rate */}
                <div className="col-span-2">
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2 text-sm text-gray-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                    value={listener.user_rate_per_min}
                    onChange={(e) => updateField(listener.listener_id, 'user_rate_per_min', e.target.value)}
                  />
                </div>

                {/* Payout Rate + Margin */}
                <div className="col-span-2">
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    className="w-full rounded-lg border border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-700 px-3 py-2 text-sm text-gray-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                    value={listener.listener_payout_per_min}
                    onChange={(e) => updateField(listener.listener_id, 'listener_payout_per_min', e.target.value)}
                  />
                  {Number(listener.user_rate_per_min) > 0 && (
                    <p className={`text-xs mt-1 ${marginColor(margin.pct)}`}>
                      Margin: ₹{margin.amount} ({margin.pct}%)
                    </p>
                  )}
                </div>

                {/* Action */}
                <div className="col-span-2">
                  <button
                    className="w-full rounded-lg bg-indigo-600 text-white px-3 py-2 text-sm font-semibold disabled:opacity-50 hover:bg-indigo-700 active:bg-indigo-800 transition-colors shadow-sm"
                    disabled={savingId === listener.listener_id}
                    onClick={() => saveRates(listener)}
                  >
                    {savingId === listener.listener_id ? (
                      <span className="flex items-center justify-center gap-1.5">
                        <svg className="w-3.5 h-3.5 animate-spin" fill="none" viewBox="0 0 24 24"><circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" /><path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" /></svg>
                        Saving…
                      </span>
                    ) : 'Save'}
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Footer info */}
      <div className="mt-4 px-4 py-3 bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-100 dark:border-gray-700 flex items-start gap-2">
        <svg className="w-4 h-4 text-gray-400 mt-0.5 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
        <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed">
          <strong>Rating sort</strong> uses Bayesian average — listeners with fewer reviews are pulled toward the global mean, preventing a single 5★ from outranking a consistent 4.8★ with many reviews.
          <span className="text-amber-500 ml-1">⚠</span> indicates fewer than 5 reviews (low confidence).
          <strong className="ml-2">Margin</strong> = (User Rate − Payout) / User Rate.
        </p>
      </div>
    </div>
  );
};

export default ListenerRateSettings;
