import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  Star,
  MessageSquare,
  Search,
  RefreshCw,
  Calendar,
  User,
  Trash2,
  X,
} from 'lucide-react';
import { deleteAppRatings, getAppRatings } from '../services/api';

const ITEMS_PER_PAGE = 12;

const AppRatings = () => {
  const [ratings, setRatings] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  const [averageRating, setAverageRating] = useState(0);
  const [searchTerm, setSearchTerm] = useState('');
  const [ratingFilter, setRatingFilter] = useState('all');
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedItem, setSelectedItem] = useState(null);
  const [selectedRatingIds, setSelectedRatingIds] = useState(new Set());
  const [loading, setLoading] = useState(true);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState(null);
  const [actionError, setActionError] = useState('');

  const fetchRatings = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const params = {
        page: currentPage,
        limit: ITEMS_PER_PAGE,
      };

      if (searchTerm.trim()) {
        params.search = searchTerm.trim();
      }

      if (ratingFilter !== 'all') {
        params.min_rating = Number(ratingFilter);
        params.max_rating = Number(ratingFilter);
      }

      const res = await getAppRatings(params);
      const payload = res.data || {};
      setRatings(Array.isArray(payload.ratings) ? payload.ratings : []);
      setTotalCount(Number(payload.count || 0));
      setAverageRating(Number(payload.average_rating || 0));
    } catch (err) {
      console.error('Error fetching app ratings:', err);
      setError('Failed to load app ratings. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [currentPage, searchTerm, ratingFilter]);

  useEffect(() => {
    const timer = setTimeout(() => {
      fetchRatings();
    }, 300);

    return () => clearTimeout(timer);
  }, [fetchRatings]);

  const totalPages = Math.max(1, Math.ceil(totalCount / ITEMS_PER_PAGE));

  const currentPageRatingIds = useMemo(
    () =>
      ratings
        .map((item) => String(item.app_rating_id || '').trim())
        .filter((id) => id.length > 0),
    [ratings],
  );

  const allCurrentSelected = useMemo(
    () =>
      currentPageRatingIds.length > 0 &&
      currentPageRatingIds.every((id) => selectedRatingIds.has(id)),
    [currentPageRatingIds, selectedRatingIds],
  );

  useEffect(() => {
    const validIds = new Set(currentPageRatingIds);
    setSelectedRatingIds((prev) => {
      const next = new Set([...prev].filter((id) => validIds.has(id)));
      return next.size === prev.size ? prev : next;
    });
  }, [currentPageRatingIds]);

  const stats = useMemo(() => {
    const withFeedback = ratings.filter(
      (item) => item.feedback && String(item.feedback).trim().length > 0,
    ).length;
    const fiveStars = ratings.filter((item) => Number(item.rating) >= 5).length;
    return { withFeedback, fiveStars };
  }, [ratings]);

  const formatDate = (value) => {
    if (!value) return 'N/A';
    try {
      return new Date(value).toLocaleString();
    } catch {
      return value;
    }
  };

  const renderStars = (value, size = 16) => {
    const parsed = Number(value) || 0;
    return (
      <div className="inline-flex items-center gap-0.5">
        {[1, 2, 3, 4, 5].map((star) => (
          <Star
            key={star}
            className={`${
              star <= Math.round(parsed)
                ? 'text-amber-400 fill-amber-400'
                : 'text-gray-300'
            }`}
            size={size}
          />
        ))}
      </div>
    );
  };

  const handleToggleSelect = (ratingId) => {
    const normalizedId = String(ratingId || '').trim();
    if (!normalizedId) return;

    setSelectedRatingIds((prev) => {
      const next = new Set(prev);
      if (next.has(normalizedId)) {
        next.delete(normalizedId);
      } else {
        next.add(normalizedId);
      }
      return next;
    });
  };

  const handleToggleSelectAll = () => {
    setSelectedRatingIds((prev) => {
      if (allCurrentSelected) {
        return new Set([...prev].filter((id) => !currentPageRatingIds.includes(id)));
      }

      const next = new Set(prev);
      currentPageRatingIds.forEach((id) => next.add(id));
      return next;
    });
  };

  const handleDeleteSelected = async () => {
    const idsToDelete = Array.from(selectedRatingIds);
    if (idsToDelete.length === 0 || deleting) return;

    const confirmed = window.confirm(
      `Delete ${idsToDelete.length} selected rating${idsToDelete.length === 1 ? '' : 's'}? This action cannot be undone.`,
    );
    if (!confirmed) return;

    setDeleting(true);
    setActionError('');

    try {
      await deleteAppRatings(idsToDelete);
      setSelectedRatingIds(new Set());
      setSelectedItem((prev) => {
        if (!prev) return prev;
        return idsToDelete.includes(String(prev.app_rating_id || '').trim()) ? null : prev;
      });
      await fetchRatings();
    } catch (err) {
      console.error('Error deleting app ratings:', err);
      setActionError('Failed to delete selected ratings. Please try again.');
    } finally {
      setDeleting(false);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[500px]">
        <div className="flex flex-col items-center gap-4">
          <div className="relative">
            <div className="w-16 h-16 border-4 border-amber-200 rounded-full"></div>
            <div className="absolute top-0 left-0 w-16 h-16 border-4 border-amber-500 border-t-transparent rounded-full animate-spin"></div>
          </div>
          <div className="text-center">
            <p className="text-lg font-medium text-gray-900 dark:text-white">Loading App Ratings</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">Fetching user reviews and feedback...</p>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-[500px]">
        <div className="text-center max-w-md">
          <div className="w-20 h-20 mx-auto mb-6 bg-gradient-to-br from-red-100 to-red-200 rounded-2xl flex items-center justify-center shadow-lg">
            <X className="w-10 h-10 text-red-500" />
          </div>
          <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Unable to Load App Ratings</h3>
          <p className="text-gray-600 dark:text-gray-400 mb-6">{error}</p>
          <button
            onClick={fetchRatings}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-amber-500 to-orange-500 text-white rounded-xl hover:from-amber-600 hover:to-orange-600 transition-all shadow-lg shadow-amber-500/25 font-medium"
          >
            <RefreshCw className="w-5 h-5" />
            Try Again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-[1600px] mx-auto">
      <div className="mb-8">
        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 bg-gradient-to-br from-amber-500 via-orange-500 to-rose-500 rounded-2xl flex items-center justify-center shadow-lg shadow-orange-500/30">
              <Star className="w-7 h-7 text-white fill-white" />
            </div>
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">
                App Ratings
              </h1>
              <p className="text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-2">
                <Calendar className="w-4 h-4" />
                User ratings and feedback submitted from the mobile app
              </p>
            </div>
          </div>
          <button
            onClick={fetchRatings}
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-gray-700 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 transition-all font-medium shadow-sm"
          >
            <RefreshCw className="w-4 h-4" />
            Refresh
          </button>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                Total Ratings
              </p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{totalCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Matching current filters</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-amber-500 to-orange-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <Star className="w-7 h-7 text-white fill-white" />
            </div>
          </div>
        </div>

        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                Average Rating
              </p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                {averageRating.toFixed(2)}
              </p>
              <div className="mt-2">{renderStars(averageRating)}</div>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-orange-500 to-rose-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <MessageSquare className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>

        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">
                Feedback in Page
              </p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                {stats.withFeedback}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">
                {stats.fiveStars} five-star ratings in current page
              </p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-rose-500 to-pink-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <User className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
      </div>

      <div className="mb-6 grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 relative">
          <div className="absolute left-5 top-1/2 -translate-y-1/2">
            <Search className="w-5 h-5 text-gray-400" />
          </div>
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => {
              setCurrentPage(1);
              setSearchTerm(e.target.value);
            }}
            placeholder="Search by name, email, or feedback text"
            className="w-full pl-14 pr-14 py-4 bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-700 rounded-2xl focus:ring-4 focus:ring-orange-500/20 focus:border-orange-500 outline-none transition-all text-gray-900 dark:text-white placeholder-gray-400"
          />
          {searchTerm && (
            <button
              onClick={() => setSearchTerm('')}
              className="absolute right-5 top-1/2 -translate-y-1/2 w-8 h-8 flex items-center justify-center text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg"
            >
              <X className="w-5 h-5" />
            </button>
          )}
        </div>

        <div className="flex items-center gap-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl px-4 py-3">
          <Star className="w-4 h-4 text-amber-500 fill-amber-500" />
          <select
            value={ratingFilter}
            onChange={(e) => {
              setCurrentPage(1);
              setRatingFilter(e.target.value);
            }}
            className="w-full bg-transparent text-gray-700 dark:text-gray-300 outline-none"
          >
            <option value="all">All Ratings</option>
            <option value="5">5 Stars</option>
            <option value="4">4 Stars</option>
            <option value="3">3 Stars</option>
            <option value="2">2 Stars</option>
            <option value="1">1 Star</option>
          </select>
        </div>
      </div>

      <div className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-xl border border-amber-100 dark:border-gray-700 bg-amber-50/50 dark:bg-gray-800 px-4 py-3">
        <p className="text-sm font-medium text-gray-700 dark:text-gray-300">
          {selectedRatingIds.size} rating{selectedRatingIds.size === 1 ? '' : 's'} selected
        </p>
        <button
          onClick={handleDeleteSelected}
          disabled={selectedRatingIds.size === 0 || deleting}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-gradient-to-r from-red-500 to-rose-600 text-white rounded-xl disabled:opacity-50 disabled:cursor-not-allowed hover:from-red-600 hover:to-rose-700 transition-all font-medium shadow-lg shadow-red-500/20"
        >
          <Trash2 className="w-4 h-4" />
          {deleting ? 'Deleting...' : 'Delete Selected'}
        </button>
      </div>

      {actionError && (
        <div className="mb-4 px-4 py-3 rounded-xl border border-red-200 bg-red-50 text-red-700 text-sm font-medium">
          {actionError}
        </div>
      )}

      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-750 border-b border-gray-200 dark:border-gray-700">
                <th className="text-center px-4 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider w-14">
                  <input
                    type="checkbox"
                    checked={allCurrentSelected}
                    onChange={handleToggleSelectAll}
                    aria-label="Select all ratings on current page"
                    className="w-4 h-4 rounded border-gray-300 text-orange-500 focus:ring-orange-500"
                  />
                </th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  User
                </th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Rating
                </th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Feedback
                </th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Source
                </th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Submitted At
                </th>
                <th className="text-center px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Action
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {ratings.length === 0 ? (
                <tr>
                  <td colSpan="7" className="px-6 py-16 text-center">
                    <div className="flex flex-col items-center">
                      <div className="w-20 h-20 bg-gradient-to-br from-gray-100 to-gray-200 rounded-2xl flex items-center justify-center mb-5">
                        <Star className="w-10 h-10 text-gray-400" />
                      </div>
                      <p className="text-lg font-semibold text-gray-700 dark:text-gray-300">
                        No app ratings found
                      </p>
                      <p className="text-gray-500 dark:text-gray-400 mt-2 max-w-sm">
                        Ratings will appear here once users submit app feedback.
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                ratings.map((item) => (
                  <tr
                    key={item.app_rating_id}
                    className="hover:bg-orange-50/40 dark:hover:bg-gray-700/50 transition-colors"
                  >
                    <td className="px-4 py-5 text-center">
                      <input
                        type="checkbox"
                        checked={selectedRatingIds.has(String(item.app_rating_id || '').trim())}
                        onChange={() => handleToggleSelect(item.app_rating_id)}
                        aria-label={`Select rating ${item.app_rating_id}`}
                        className="w-4 h-4 rounded border-gray-300 text-orange-500 focus:ring-orange-500"
                      />
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 bg-gradient-to-br from-orange-400 to-rose-500 rounded-xl flex items-center justify-center text-white font-bold text-sm">
                          {(item.display_name || item.email || 'U').charAt(0).toUpperCase()}
                        </div>
                        <div>
                          <p className="font-semibold text-gray-900 dark:text-white">
                            {item.display_name || 'Unknown User'}
                          </p>
                          <p className="text-xs text-gray-500 dark:text-gray-400">
                            {item.email || 'No email'}
                          </p>
                        </div>
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex flex-col gap-1">
                        {renderStars(item.rating)}
                        <span className="text-xs text-gray-500 dark:text-gray-400">
                          {Number(item.rating || 0).toFixed(1)} / 5.0
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <p className="text-gray-700 dark:text-gray-300 line-clamp-2 max-w-md">
                        {item.feedback || 'No written feedback'}
                      </p>
                    </td>
                    <td className="px-6 py-5">
                      <span className="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold border bg-amber-50 text-amber-700 border-amber-200">
                        {item.source || 'mobile'}
                      </span>
                    </td>
                    <td className="px-6 py-5 text-sm text-gray-500 dark:text-gray-400">
                      {formatDate(item.created_at)}
                    </td>
                    <td className="px-6 py-5 text-center">
                      <button
                        onClick={() => setSelectedItem(item)}
                        className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-gradient-to-r from-amber-500 to-orange-600 rounded-xl hover:from-amber-600 hover:to-orange-700 transition-all shadow-lg shadow-amber-500/20"
                      >
                        View
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>

      {totalPages > 1 && (
        <div className="flex flex-wrap justify-between items-center gap-4 mt-6">
          <p className="text-sm text-gray-500 dark:text-gray-400">
            Page {currentPage} of {totalPages}
          </p>
          <div className="flex items-center gap-2">
            <button
              onClick={() => setCurrentPage((prev) => Math.max(prev - 1, 1))}
              disabled={currentPage === 1}
              className="px-4 py-2 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 disabled:opacity-50"
            >
              Prev
            </button>
            <button
              onClick={() => setCurrentPage((prev) => Math.min(prev + 1, totalPages))}
              disabled={currentPage === totalPages}
              className="px-4 py-2 rounded-lg border border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-300 disabled:opacity-50"
            >
              Next
            </button>
          </div>
        </div>
      )}

      {selectedItem && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl max-w-2xl w-full p-6">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-xl font-bold text-gray-900 dark:text-white">App Rating Details</h2>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  {formatDate(selectedItem.created_at)}
                </p>
              </div>
              <button
                onClick={() => setSelectedItem(null)}
                className="w-9 h-9 rounded-lg border border-gray-200 dark:border-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-6 space-y-4">
              <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                <p className="text-xs font-semibold text-gray-500 uppercase">Rating</p>
                <div className="mt-2 flex items-center gap-3">
                  {renderStars(selectedItem.rating, 18)}
                  <span className="font-semibold text-gray-900 dark:text-white">
                    {Number(selectedItem.rating || 0).toFixed(1)} / 5.0
                  </span>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">User Name</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium">
                    {selectedItem.display_name || 'Unknown User'}
                  </p>
                </div>
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">Email</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium">
                    {selectedItem.email || 'N/A'}
                  </p>
                </div>
              </div>

              <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                <p className="text-xs font-semibold text-gray-500 uppercase">Feedback</p>
                <p className="mt-3 text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                  {selectedItem.feedback || 'No written feedback provided.'}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default AppRatings;
