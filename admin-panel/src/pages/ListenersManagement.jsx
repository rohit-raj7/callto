import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { getAdminListeners, deleteListener } from '../services/api';
import ListenerEditForm from '../components/ListenerEditForm';
import ConfirmationModal from '../components/ConfirmationModal';
import { 
  Search, Filter, Download, Eye, Edit3, Trash2, 
  ChevronUp, ChevronDown, Users, UserCheck, UserX,
  Star, RefreshCw, MoreVertical, X, Headphones,
  Phone, Mail, MapPin, Clock, TrendingUp, Copy, Check,
  Shield, CheckCircle, AlertCircle, XCircle
} from 'lucide-react';

/* -------------------- HELPERS -------------------- */
const exportCSV = (rows, columns, filename = 'listeners.csv') => {
  const header = columns.join(',');
  const data = rows.map(r =>
    columns.map(c => `"${r[c] ?? ''}"`).join(',')
  );
  const csv = [header, ...data].join('\n');
  const blob = new Blob([csv], { type: 'text/csv' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
};

/* -------------------- SKELETON LOADER -------------------- */
const TableSkeleton = () => (
  <div className="animate-pulse">
    {[...Array(5)].map((_, i) => (
      <div key={i} className="flex items-center gap-4 p-4 border-b border-gray-100 dark:border-gray-700">
        <div className="w-5 h-5 bg-gray-200 dark:bg-gray-700 rounded" />
        <div className="w-10 h-10 bg-gray-200 dark:bg-gray-700 rounded-full" />
        <div className="flex-1 space-y-2">
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-1/4" />
          <div className="h-3 bg-gray-200 dark:bg-gray-700 rounded w-1/3" />
        </div>
        <div className="h-6 bg-gray-200 dark:bg-gray-700 rounded w-16" />
        <div className="h-6 bg-gray-200 dark:bg-gray-700 rounded w-20" />
      </div>
    ))}
  </div>
);

/* -------------------- STAT CARD -------------------- */
const StatCard = ({ icon: Icon, label, value, trend, color }) => (
  <div className={`bg-gradient-to-br ${color} rounded-xl p-4 text-white shadow-lg transform hover:scale-105 transition-all duration-300`}>
    <div className="flex items-center justify-between">
      <div>
        <p className="text-sm opacity-80">{label}</p>
        <p className="text-2xl font-bold mt-1">{value}</p>
        {trend && (
          <p className="text-xs mt-1 flex items-center gap-1">
            <TrendingUp className="w-3 h-3" />
            {trend}
          </p>
        )}
      </div>
      <div className="p-3 bg-white/20 rounded-lg">
        <Icon className="w-6 h-6" />
      </div>
    </div>
  </div>
);

/* -------------------- COMPONENT -------------------- */
const ListenersManagement = () => {
  const navigate = useNavigate();

  const [listeners, setListeners] = useState([]);
  const [filteredListeners, setFilteredListeners] = useState([]);

  const [selectedIds, setSelectedIds] = useState([]);
  const [viewMode, setViewMode] = useState('table'); // 'table' or 'grid'

  const [searchTerm, setSearchTerm] = useState('');
  const [filterOnline, setFilterOnline] = useState('');
  const [filterVerified, setFilterVerified] = useState('');
  const [minRating, setMinRating] = useState('');
  const [showFilters, setShowFilters] = useState(false);

  const [sortConfig, setSortConfig] = useState({ key: 'name', direction: 'asc' });

  const [editingListener, setEditingListener] = useState(null);
  const [deletingListener, setDeletingListener] = useState(null);
  const [activeDropdown, setActiveDropdown] = useState(null);
  const [copiedField, setCopiedField] = useState(null);

  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState(null);

  // Pagination
  const [currentPage, setCurrentPage] = useState(1);
  const itemsPerPage = 10;

  /* -------------------- STATS -------------------- */
  const stats = useMemo(() => ({
    total: listeners.length,
    online: listeners.filter(l => l.is_online).length,
    approved: listeners.filter(l => (l.verification_status || 'pending') === 'approved').length,
    pending: listeners.filter(l => (l.verification_status || 'pending') === 'pending').length,
    rejected: listeners.filter(l => (l.verification_status || 'pending') === 'rejected').length,
    verified: listeners.filter(l => l.is_verified).length,
    avgRating: listeners.length > 0 
      ? (listeners.reduce((sum, l) => sum + (Number(l.average_rating) || 0), 0) / listeners.length).toFixed(1)
      : '0.0'
  }), [listeners]);

  /* -------------------- COPY TO CLIPBOARD -------------------- */
  const handleCopy = async (value, fieldKey) => {
    if (!value) return;
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(fieldKey);
      setTimeout(() => setCopiedField(null), 2000);
    } catch (err) {
      console.error('Failed to copy:', err);
    }
  };

  /* -------------------- FETCH -------------------- */
  useEffect(() => {
    fetchListeners();
    const interval = setInterval(fetchListeners, 30000);
    return () => clearInterval(interval);
  }, []);

  const fetchListeners = async (showRefresh = false) => {
    if (showRefresh) setRefreshing(true);
    try {
      const res = await getAdminListeners();
      setListeners(res.data.listeners || []);
      setError(null);
    } catch {
      setError('Failed to fetch listeners');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  /* -------------------- FILTER + SORT -------------------- */
  useEffect(() => {
    let data = [...listeners];

    if (searchTerm) {
      const term = searchTerm.toLowerCase();
      data = data.filter(l =>
        l.name?.toLowerCase().includes(term) ||
        l.email?.toLowerCase().includes(term) ||
        l.phone_number?.includes(term) ||
        l.mobile_number?.includes(term) ||
        l.city?.toLowerCase().includes(term)
      );
    }

    if (filterOnline !== '') {
      data = data.filter(l => l.is_online === (filterOnline === 'true'));
    }

    if (filterVerified !== '') {
      if (['approved', 'pending', 'rejected', 'reapplied'].includes(filterVerified)) {
        data = data.filter(l => (l.verification_status || 'pending') === filterVerified);
      } else {
        data = data.filter(l => l.is_verified === (filterVerified === 'true'));
      }
    }

    if (minRating) {
      data = data.filter(l => (Number(l.average_rating) || 0) >= Number(minRating));
    }

    if (sortConfig.key) {
      data.sort((a, b) => {
        let x = a[sortConfig.key] ?? '';
        let y = b[sortConfig.key] ?? '';
        if (sortConfig.key === 'average_rating') {
          x = Number(x) || 0;
          y = Number(y) || 0;
        }
        return sortConfig.direction === 'asc'
          ? x > y ? 1 : -1
          : x < y ? 1 : -1;
      });
    }

    setFilteredListeners(data);
    setCurrentPage(1);
  }, [listeners, searchTerm, filterOnline, filterVerified, minRating, sortConfig]);

  const toggleSort = key => {
    setSortConfig(prev => ({
      key,
      direction: prev.key === key && prev.direction === 'asc' ? 'desc' : 'asc'
    }));
  };

  const SortIcon = ({ column }) => {
    if (sortConfig.key !== column) return <ChevronUp className="w-4 h-4 opacity-30" />;
    return sortConfig.direction === 'asc' 
      ? <ChevronUp className="w-4 h-4 text-indigo-600" />
      : <ChevronDown className="w-4 h-4 text-indigo-600" />;
  };

  /* -------------------- PAGINATION -------------------- */
  const paginatedListeners = useMemo(() => {
    const start = (currentPage - 1) * itemsPerPage;
    return filteredListeners.slice(start, start + itemsPerPage);
  }, [filteredListeners, currentPage]);

  const totalPages = Math.ceil(filteredListeners.length / itemsPerPage);

  /* -------------------- BULK -------------------- */
  const toggleSelect = id =>
    setSelectedIds(prev =>
      prev.includes(id) ? prev.filter(i => i !== id) : [...prev, id]
    );

  const selectAll = e =>
    setSelectedIds(e.target.checked ? paginatedListeners.map(l => l.listener_id) : []);

  const clearFilters = () => {
    setSearchTerm('');
    setFilterOnline('');
    setFilterVerified('');
    setMinRating('');
  };

  const hasActiveFilters = searchTerm || filterOnline || filterVerified || minRating;

  /* -------------------- RENDER RATING STARS -------------------- */
  const RatingStars = ({ rating }) => {
    const numRating = Number(rating) || 0;
    return (
      <div className="flex items-center gap-1">
        {[1, 2, 3, 4, 5].map(star => (
          <Star 
            key={star} 
            className={`w-4 h-4 ${star <= numRating ? 'text-yellow-400 fill-yellow-400' : 'text-gray-300'}`}
          />
        ))}
        <span className="text-sm text-gray-600 dark:text-gray-400 ml-1">
          {numRating > 0 ? numRating.toFixed(1) : 'N/A'}
        </span>
      </div>
    );
  };

  /* -------------------- UI -------------------- */
  if (loading) {
    return (
      <div className="p-6 bg-gray-50 dark:bg-gray-900 min-h-screen">
        <div className="mb-6">
          <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-64 animate-pulse" />
        </div>
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          {[...Array(4)].map((_, i) => (
            <div key={i} className="h-24 bg-gray-200 dark:bg-gray-700 rounded-xl animate-pulse" />
          ))}
        </div>
        <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm">
          <TableSkeleton />
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="p-6 bg-gray-50 dark:bg-gray-900 min-h-screen flex items-center justify-center">
        <div className="text-center bg-white dark:bg-gray-800 p-8 rounded-xl shadow-lg max-w-md">
          <div className="w-16 h-16 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
            <X className="w-8 h-8 text-red-600" />
          </div>
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">Failed to Load</h3>
          <p className="text-gray-600 dark:text-gray-400 mb-4">{error}</p>
          <button
            onClick={() => { setLoading(true); fetchListeners(); }}
            className="px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors"
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6 bg-gray-50 dark:bg-gray-900 min-h-screen transition-colors">

      {/* HEADER */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white flex items-center gap-3">
            <div className="p-2 bg-indigo-100 dark:bg-indigo-900/50 rounded-lg">
              <Headphones className="w-6 h-6 text-indigo-600 dark:text-indigo-400" />
            </div>
            Listeners Management
          </h1>
          <p className="text-gray-600 dark:text-gray-400 mt-1">
            Manage and monitor all registered listeners
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button
            onClick={() => fetchListeners(true)}
            disabled={refreshing}
            className={`p-2 rounded-lg border border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 
              hover:bg-gray-50 dark:hover:bg-gray-700 transition-all ${refreshing ? 'animate-spin' : ''}`}
            title="Refresh"
          >
            <RefreshCw className="w-5 h-5 text-gray-600 dark:text-gray-400" />
          </button>
          <div className="flex bg-gray-100 dark:bg-gray-800 rounded-lg p-1">
            <button
              onClick={() => setViewMode('table')}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-all ${
                viewMode === 'table' 
                  ? 'bg-white dark:bg-gray-700 shadow-sm text-indigo-600 dark:text-indigo-400' 
                  : 'text-gray-600 dark:text-gray-400'
              }`}
            >
              Table
            </button>
            <button
              onClick={() => setViewMode('grid')}
              className={`px-3 py-1.5 rounded-md text-sm font-medium transition-all ${
                viewMode === 'grid' 
                  ? 'bg-white dark:bg-gray-700 shadow-sm text-indigo-600 dark:text-indigo-400' 
                  : 'text-gray-600 dark:text-gray-400'
              }`}
            >
              Grid
            </button>
          </div>
        </div>
      </div>

      {/* STATS CARDS */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <StatCard 
          icon={Users} 
          label="Total Listeners" 
          value={stats.total}
          color="from-blue-500 to-blue-600"
        />
        <StatCard 
          icon={UserCheck} 
          label="Online Now" 
          value={stats.online}
          trend={`${stats.total > 0 ? ((stats.online / stats.total) * 100).toFixed(0) : 0}% active`}
          color="from-emerald-500 to-emerald-600"
        />
        <StatCard 
          icon={Shield} 
          label="Approved" 
          value={stats.approved}
          trend={stats.pending > 0 ? `${stats.pending} pending` : ''}
          color="from-purple-500 to-purple-600"
        />
        <StatCard 
          icon={Star} 
          label="Avg Rating" 
          value={stats.avgRating}
          color="from-amber-500 to-amber-600"
        />
      </div>

      {/* SEARCH & FILTER BAR */}
      <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm p-4 mb-6">
        <div className="flex flex-col md:flex-row gap-4">
          {/* Search */}
          <div className="relative flex-1">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
            <input
              type="text"
              placeholder="Search by name, email, phone, or city..."
              value={searchTerm}
              onChange={e => setSearchTerm(e.target.value)}
              className="w-full pl-10 pr-4 py-2.5 border border-gray-200 dark:border-gray-700 rounded-lg 
                bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-white
                focus:ring-2 focus:ring-indigo-500 focus:border-transparent transition-all"
            />
          </div>

          {/* Filter Toggle */}
          <button
            onClick={() => setShowFilters(!showFilters)}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-lg border transition-all ${
              showFilters || hasActiveFilters
                ? 'bg-indigo-50 dark:bg-indigo-900/30 border-indigo-200 dark:border-indigo-800 text-indigo-600 dark:text-indigo-400'
                : 'bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700 text-gray-600 dark:text-gray-400'
            }`}
          >
            <Filter className="w-5 h-5" />
            Filters
            {hasActiveFilters && (
              <span className="w-2 h-2 bg-indigo-600 rounded-full" />
            )}
          </button>

          {/* Export */}
          <button
            onClick={() => exportCSV(
              selectedIds.length > 0 
                ? listeners.filter(l => selectedIds.includes(l.listener_id))
                : filteredListeners,
              ['listener_id', 'name', 'email', 'phone_number', 'city', 'is_online', 'is_verified', 'average_rating']
            )}
            className="flex items-center gap-2 px-4 py-2.5 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-all"
          >
            <Download className="w-5 h-5" />
            Export {selectedIds.length > 0 ? `(${selectedIds.length})` : ''}
          </button>
        </div>

        {/* Advanced Filters */}
        {showFilters && (
          <div className="mt-4 pt-4 border-t border-gray-100 dark:border-gray-700">
            <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Status</label>
                <select
                  value={filterOnline}
                  onChange={e => setFilterOnline(e.target.value)}
                  className="w-full p-2.5 border border-gray-200 dark:border-gray-700 rounded-lg 
                    bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-white"
                >
                  <option value="">All Status</option>
                  <option value="true">Online</option>
                  <option value="false">Offline</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Verification</label>
                <select
                  value={filterVerified}
                  onChange={e => setFilterVerified(e.target.value)}
                  className="w-full p-2.5 border border-gray-200 dark:border-gray-700 rounded-lg 
                    bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-white"
                >
                  <option value="">All Status</option>
                  <option value="approved">Approved</option>
                  <option value="pending">Pending</option>
                  <option value="rejected">Rejected</option>
                  <option value="reapplied">Reapplied</option>
                </select>
              </div>
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">Min Rating</label>
                <select
                  value={minRating}
                  onChange={e => setMinRating(e.target.value)}
                  className="w-full p-2.5 border border-gray-200 dark:border-gray-700 rounded-lg 
                    bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-white"
                >
                  <option value="">Any Rating</option>
                  <option value="4">4+ Stars</option>
                  <option value="3">3+ Stars</option>
                  <option value="2">2+ Stars</option>
                </select>
              </div>
              <div className="flex items-end">
                <button
                  onClick={clearFilters}
                  className="w-full p-2.5 text-gray-600 dark:text-gray-400 hover:text-red-600 dark:hover:text-red-400 
                    border border-gray-200 dark:border-gray-700 rounded-lg hover:border-red-200 dark:hover:border-red-800 transition-colors"
                >
                  Clear Filters
                </button>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* BULK ACTION BAR */}
      {selectedIds.length > 0 && (
        <div className="bg-indigo-50 dark:bg-indigo-900/30 border border-indigo-200 dark:border-indigo-800 
          p-4 rounded-xl mb-4 flex items-center justify-between animate-fadeIn">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 bg-indigo-100 dark:bg-indigo-900/50 rounded-lg flex items-center justify-center">
              <Users className="w-5 h-5 text-indigo-600 dark:text-indigo-400" />
            </div>
            <span className="text-indigo-700 dark:text-indigo-300 font-medium">
              {selectedIds.length} listener{selectedIds.length > 1 ? 's' : ''} selected
            </span>
          </div>
          <button
            onClick={() => setSelectedIds([])}
            className="text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-200 text-sm"
          >
            Clear selection
          </button>
        </div>
      )}

      {/* RESULTS INFO */}
      <div className="flex items-center justify-between mb-4">
        <p className="text-sm text-gray-600 dark:text-gray-400">
          Showing {paginatedListeners.length} of {filteredListeners.length} listeners
          {hasActiveFilters && ` (filtered from ${listeners.length})`}
        </p>
      </div>

      {/* TABLE VIEW */}
      {viewMode === 'table' && (
        <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full">
              <thead className="bg-gray-50 dark:bg-gray-900/50">
                <tr>
                  <th className="p-4 w-12">
                    <input 
                      type="checkbox" 
                      onChange={selectAll}
                      checked={selectedIds.length === paginatedListeners.length && paginatedListeners.length > 0}
                      className="w-4 h-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                    />
                  </th>
                  <th 
                    onClick={() => toggleSort('name')} 
                    className="p-4 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:text-gray-700 dark:hover:text-gray-200"
                  >
                    <div className="flex items-center gap-1">
                      Listener
                      <SortIcon column="name" />
                    </div>
                  </th>
                  <th className="p-4 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Contact
                  </th>
                  <th 
                    onClick={() => toggleSort('average_rating')} 
                    className="p-4 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider cursor-pointer hover:text-gray-700 dark:hover:text-gray-200"
                  >
                    <div className="flex items-center gap-1">
                      Rating
                      <SortIcon column="average_rating" />
                    </div>
                  </th>
                  <th className="p-4 text-left text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Status
                  </th>
                  <th className="p-4 text-right text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Actions
                  </th>
                </tr>
              </thead>

              <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                {paginatedListeners.length === 0 ? (
                  <tr>
                    <td colSpan="6" className="p-12 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mb-4">
                          <Users className="w-8 h-8 text-gray-400" />
                        </div>
                        <p className="text-gray-500 dark:text-gray-400 font-medium">No listeners found</p>
                        <p className="text-gray-400 dark:text-gray-500 text-sm mt-1">
                          {hasActiveFilters ? 'Try adjusting your filters' : 'No listeners registered yet'}
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedListeners.map(l => (
                    <tr 
                      key={l.listener_id} 
                      className="hover:bg-gray-50 dark:hover:bg-gray-700/50 transition-colors cursor-pointer"
                      onClick={(e) => {
                        // Don't navigate if clicking on interactive elements
                        if (e.target.closest('input[type="checkbox"]') || e.target.closest('button') || e.target.closest('a')) return;
                        navigate(`/admin-no-all-call/listeners/${l.listener_id}`);
                      }}
                    >
                      <td className="p-4">
                        <input
                          type="checkbox"
                          checked={selectedIds.includes(l.listener_id)}
                          onChange={() => toggleSelect(l.listener_id)}
                          className="w-4 h-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                        />
                      </td>
                      <td className="p-4">
                        <div className="flex items-center gap-3">
                          <div className="relative">
                            <div className="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full 
                              flex items-center justify-center text-white font-semibold">
                              {l.name?.charAt(0)?.toUpperCase() || '?'}
                            </div>
                            {l.is_online && (
                              <div className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-emerald-500 
                                border-2 border-white dark:border-gray-800 rounded-full" />
                            )}
                          </div>
                          <div>
                            <p 
                              className="font-medium text-gray-900 dark:text-white cursor-pointer hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
                            >
                              {l.name}
                            </p>
                            <p className="text-sm text-gray-500 dark:text-gray-400 flex items-center gap-1">
                              <MapPin className="w-3 h-3" />
                              {l.city || 'Unknown'}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="space-y-1.5">
                          {/* Email - clickable to copy */}
                          {l.email && (
                            <button
                              onClick={() => handleCopy(l.email, `email-${l.listener_id}`)}
                              className="text-sm text-gray-600 dark:text-gray-300 flex items-center gap-1.5 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors group"
                              title="Click to copy email"
                            >
                              <Mail className="w-3.5 h-3.5 text-gray-400 group-hover:text-indigo-500" />
                              <span className="truncate max-w-[180px]">{l.email}</span>
                              {copiedField === `email-${l.listener_id}` ? (
                                <Check className="w-3.5 h-3.5 text-green-500" />
                              ) : (
                                <Copy className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity" />
                              )}
                            </button>
                          )}
                          {!l.email && (
                            <p className="text-sm text-gray-400 flex items-center gap-1.5">
                              <Mail className="w-3.5 h-3.5" />
                              —
                            </p>
                          )}
                          
                          {/* Mobile/Phone Number - clickable to copy */}
                          {(l.mobile_number || l.phone_number) ? (
                            <button
                              onClick={() => handleCopy(l.mobile_number || l.phone_number, `phone-${l.listener_id}`)}
                              className="text-sm text-gray-500 dark:text-gray-400 flex items-center gap-1.5 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors group"
                              title="Click to copy phone"
                            >
                              <Phone className="w-3.5 h-3.5 text-gray-400 group-hover:text-indigo-500" />
                              <span>{l.mobile_number || l.phone_number}</span>
                              {copiedField === `phone-${l.listener_id}` ? (
                                <Check className="w-3.5 h-3.5 text-green-500" />
                              ) : (
                                <Copy className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity" />
                              )}
                            </button>
                          ) : (
                            <p className="text-sm text-gray-400 flex items-center gap-1.5">
                              <Phone className="w-3.5 h-3.5" />
                              —
                            </p>
                          )}
                        </div>
                      </td>
                      <td className="p-4">
                        <RatingStars rating={l.average_rating} />
                        <p className="text-xs text-gray-400 mt-0.5">
                          {l.total_ratings || 0} reviews
                        </p>
                      </td>
                      <td className="p-4">
                        <div className="flex flex-col gap-1.5">
                          <span className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium ${
                            l.is_online 
                              ? 'bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400'
                              : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                          }`}>
                            <span className={`w-1.5 h-1.5 rounded-full ${l.is_online ? 'bg-emerald-500' : 'bg-gray-400'}`} />
                            {l.is_online ? 'Online' : 'Offline'}
                          </span>
                          {(() => {
                            const vs = l.verification_status || 'pending';
                            if (vs === 'approved') return (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400">
                                <CheckCircle className="w-3 h-3" />
                                Approved
                              </span>
                            );
                            if (vs === 'rejected') return (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400">
                                <XCircle className="w-3 h-3" />
                                Rejected
                              </span>
                            );
                            if (vs === 'reapplied') return (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400">
                                <RefreshCw className="w-3 h-3" />
                                Reapplied
                              </span>
                            );
                            return (
                              <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400">
                                <AlertCircle className="w-3 h-3" />
                                Pending
                              </span>
                            );
                          })()}
                        </div>
                      </td>
                      <td className="p-4">
                        <div className="flex items-center justify-end gap-2">
                          <button
                            onClick={() => navigate(`/admin-no-all-call/listeners/${l.listener_id}`)}
                            className="p-2 text-gray-500 hover:text-indigo-600 hover:bg-indigo-50 
                              dark:hover:bg-indigo-900/30 rounded-lg transition-all"
                            title="View Details"
                          >
                            <Eye className="w-5 h-5" />
                          </button>
                          <button
                            onClick={() => setEditingListener(l)}
                            className="p-2 text-gray-500 hover:text-amber-600 hover:bg-amber-50 
                              dark:hover:bg-amber-900/30 rounded-lg transition-all"
                            title="Edit"
                          >
                            <Edit3 className="w-5 h-5" />
                          </button>
                          <button
                            onClick={() => setDeletingListener(l)}
                            className="p-2 text-gray-500 hover:text-red-600 hover:bg-red-50 
                              dark:hover:bg-red-900/30 rounded-lg transition-all"
                            title="Delete"
                          >
                            <Trash2 className="w-5 h-5" />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>

          {/* Pagination */}
          {totalPages > 1 && (
            <div className="flex items-center justify-between px-4 py-3 border-t border-gray-100 dark:border-gray-700">
              <p className="text-sm text-gray-600 dark:text-gray-400">
                Page {currentPage} of {totalPages}
              </p>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="px-3 py-1.5 text-sm border border-gray-200 dark:border-gray-700 rounded-lg 
                    disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                >
                  Previous
                </button>
                {[...Array(Math.min(5, totalPages))].map((_, i) => {
                  let page;
                  if (totalPages <= 5) {
                    page = i + 1;
                  } else if (currentPage <= 3) {
                    page = i + 1;
                  } else if (currentPage >= totalPages - 2) {
                    page = totalPages - 4 + i;
                  } else {
                    page = currentPage - 2 + i;
                  }
                  return (
                    <button
                      key={page}
                      onClick={() => setCurrentPage(page)}
                      className={`w-8 h-8 text-sm rounded-lg transition-colors ${
                        currentPage === page
                          ? 'bg-indigo-600 text-white'
                          : 'hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-600 dark:text-gray-400'
                      }`}
                    >
                      {page}
                    </button>
                  );
                })}
                <button
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="px-3 py-1.5 text-sm border border-gray-200 dark:border-gray-700 rounded-lg 
                    disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                >
                  Next
                </button>
              </div>
            </div>
          )}
        </div>
      )}

      {/* GRID VIEW */}
      {viewMode === 'grid' && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          {paginatedListeners.length === 0 ? (
            <div className="col-span-full bg-white dark:bg-gray-800 rounded-xl p-12 text-center">
              <div className="flex flex-col items-center">
                <div className="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mb-4">
                  <Users className="w-8 h-8 text-gray-400" />
                </div>
                <p className="text-gray-500 dark:text-gray-400 font-medium">No listeners found</p>
              </div>
            </div>
          ) : (
            paginatedListeners.map(l => (
              <div 
                key={l.listener_id}
                className="bg-white dark:bg-gray-800 rounded-xl shadow-sm hover:shadow-md transition-all p-5 relative group"
              >
                {/* Selection checkbox */}
                <div className="absolute top-3 left-3">
                  <input
                    type="checkbox"
                    checked={selectedIds.includes(l.listener_id)}
                    onChange={() => toggleSelect(l.listener_id)}
                    className="w-4 h-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
                  />
                </div>

                {/* More actions */}
                <div className="absolute top-3 right-3">
                  <button
                    onClick={() => setActiveDropdown(activeDropdown === l.listener_id ? null : l.listener_id)}
                    className="p-1.5 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
                  >
                    <MoreVertical className="w-5 h-5" />
                  </button>
                  {activeDropdown === l.listener_id && (
                    <div className="absolute right-0 mt-1 w-40 bg-white dark:bg-gray-800 rounded-lg shadow-lg border border-gray-100 dark:border-gray-700 py-1 z-10">
                      <button
                        onClick={() => { navigate(`/admin-no-all-call/listeners/${l.listener_id}`); setActiveDropdown(null); }}
                        className="w-full px-4 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center gap-2"
                      >
                        <Eye className="w-4 h-4" /> View
                      </button>
                      <button
                        onClick={() => { setEditingListener(l); setActiveDropdown(null); }}
                        className="w-full px-4 py-2 text-left text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center gap-2"
                      >
                        <Edit3 className="w-4 h-4" /> Edit
                      </button>
                      <button
                        onClick={() => { setDeletingListener(l); setActiveDropdown(null); }}
                        className="w-full px-4 py-2 text-left text-sm text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 flex items-center gap-2"
                      >
                        <Trash2 className="w-4 h-4" /> Delete
                      </button>
                    </div>
                  )}
                </div>

                {/* Card content */}
                <div 
                  className="text-center pt-4 cursor-pointer"
                  onClick={() => navigate(`/admin-no-all-call/listeners/${l.listener_id}`)}
                >
                  <div className="relative inline-block">
                    <div className="w-16 h-16 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full 
                      flex items-center justify-center text-white text-xl font-bold mx-auto hover:scale-105 transition-transform">
                      {l.name?.charAt(0)?.toUpperCase() || '?'}
                    </div>
                    {l.is_online && (
                      <div className="absolute bottom-0 right-0 w-4 h-4 bg-emerald-500 
                        border-2 border-white dark:border-gray-800 rounded-full" />
                    )}
                  </div>
                  <h3 className="mt-3 font-semibold text-gray-900 dark:text-white hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors">{l.name}</h3>
                  <p className="text-sm text-gray-500 dark:text-gray-400 flex items-center justify-center gap-1 mt-1">
                    <MapPin className="w-3 h-3" />
                    {l.city || 'Unknown'}
                  </p>
                </div>

                {/* Stats */}
                <div className="mt-4 flex justify-center">
                  <RatingStars rating={l.average_rating} />
                </div>

                {/* Badges */}
                <div className="mt-4 flex items-center justify-center gap-2 flex-wrap">
                  <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${
                    l.is_online 
                      ? 'bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400'
                      : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                  }`}>
                    {l.is_online ? 'Online' : 'Offline'}
                  </span>
                  {(() => {
                    const vs = l.verification_status || 'pending';
                    if (vs === 'approved') return (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400">
                        <CheckCircle className="w-3 h-3" />
                        Approved
                      </span>
                    );
                    if (vs === 'rejected') return (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400">
                        <XCircle className="w-3 h-3" />
                        Rejected
                      </span>
                    );
                    if (vs === 'reapplied') return (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-orange-100 dark:bg-orange-900/30 text-orange-700 dark:text-orange-400">
                        <RefreshCw className="w-3 h-3" />
                        Reapplied
                      </span>
                    );
                    return (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-400">
                        <AlertCircle className="w-3 h-3" />
                        Pending
                      </span>
                    );
                  })()}
                </div>

                {/* Quick action */}
                <button
                  onClick={() => navigate(`/admin-no-all-call/listeners/${l.listener_id}`)}
                  className="mt-4 w-full py-2 text-sm font-medium text-indigo-600 dark:text-indigo-400 
                    border border-indigo-200 dark:border-indigo-800 rounded-lg 
                    hover:bg-indigo-50 dark:hover:bg-indigo-900/30 transition-colors"
                >
                  View Profile
                </button>
              </div>
            ))
          )}
        </div>
      )}

      {/* Grid Pagination */}
      {viewMode === 'grid' && totalPages > 1 && (
        <div className="flex items-center justify-center mt-6 gap-2">
          <button
            onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            disabled={currentPage === 1}
            className="px-4 py-2 text-sm border border-gray-200 dark:border-gray-700 rounded-lg 
              disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
          >
            Previous
          </button>
          <span className="text-sm text-gray-600 dark:text-gray-400">
            Page {currentPage} of {totalPages}
          </span>
          <button
            onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
            className="px-4 py-2 text-sm border border-gray-200 dark:border-gray-700 rounded-lg 
              disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
          >
            Next
          </button>
        </div>
      )}

      {/* MODALS */}
      {editingListener && (
        <ListenerEditForm
          listener={editingListener}
          onSave={() => {
            setEditingListener(null);
            fetchListeners();
          }}
          onClose={() => setEditingListener(null)}
        />
      )}

      {deletingListener && (
        <ConfirmationModal
          message={`Are you sure you want to permanently delete "${deletingListener.name}"? This will remove ALL data including their user account, email, contacts, calls, ratings, wallet, and chat history. This action cannot be undone.`}
          onConfirm={async () => {
            await deleteListener(deletingListener.listener_id);
            setDeletingListener(null);
            fetchListeners();
          }}
          onCancel={() => setDeletingListener(null)}
        />
      )}
    </div>
  );
};

export default ListenersManagement;
