import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  Calendar,
  Filter,
  Mail,
  Phone,
  RefreshCw,
  Search,
  Trash2,
  User,
  X
} from 'lucide-react';
import { deleteDeleteRequest, getDeleteRequests } from '../services/api';

const DeleteRequests = () => {
  const [requests, setRequests] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [roleFilter, setRoleFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedRequest, setSelectedRequest] = useState(null);
  const [deletingId, setDeletingId] = useState(null);
  const [deleteError, setDeleteError] = useState(null);
  const itemsPerPage = 12;

  const counts = useMemo(() => {
    const userCount = requests.filter((r) => r.role === 'user').length;
    const listenerCount = requests.filter((r) => r.role === 'listener').length;
    const pendingCount = requests.filter((r) => r.status === 'pending').length;
    return { userCount, listenerCount, pendingCount };
  }, [requests]);

  const fetchRequests = useCallback(async () => {
    setLoading(true);
    setError(null);

    try {
      const params = {
        page: currentPage,
        limit: itemsPerPage
      };

      if (roleFilter !== 'all') {
        params.role = roleFilter;
      }

      if (statusFilter !== 'all') {
        params.status = statusFilter;
      }

      if (searchTerm.trim()) {
        params.search = searchTerm.trim();
      }

      const res = await getDeleteRequests(params);
      const payload = res.data || {};
      setRequests(Array.isArray(payload.requests) ? payload.requests : []);
      setTotalCount(payload.count || 0);
    } catch (err) {
      console.error('Error fetching delete requests:', err);
      setError('Failed to load delete requests. Please try again.');
    } finally {
      setLoading(false);
    }
  }, [currentPage, roleFilter, statusFilter, searchTerm]);

  useEffect(() => {
    const timer = setTimeout(() => {
      fetchRequests();
    }, 300);

    return () => clearTimeout(timer);
  }, [fetchRequests]);

  const totalPages = Math.max(1, Math.ceil(totalCount / itemsPerPage));

  const formatDate = (value) => {
    if (!value) return 'N/A';
    try {
      return new Date(value).toLocaleString();
    } catch {
      return value;
    }
  };

  const roleBadge = (role) => (
    <span
      className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border ${
        role === 'listener'
          ? 'bg-purple-50 text-purple-700 border-purple-200'
          : 'bg-blue-50 text-blue-700 border-blue-200'
      }`}
    >
      <span className={`w-2 h-2 rounded-full ${role === 'listener' ? 'bg-purple-500' : 'bg-blue-500'}`} />
      {role === 'listener' ? 'Listener' : 'User'}
    </span>
  );

  const statusBadge = (status) => {
    if (status === 'approved') {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border bg-emerald-50 text-emerald-700 border-emerald-200">
          <span className="w-2 h-2 rounded-full bg-emerald-500" />
          Approved
        </span>
      );
    }
    if (status === 'rejected') {
      return (
        <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border bg-red-50 text-red-700 border-red-200">
          <span className="w-2 h-2 rounded-full bg-red-500" />
          Rejected
        </span>
      );
    }
    return (
      <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border bg-amber-50 text-amber-700 border-amber-200">
        <span className="w-2 h-2 rounded-full bg-amber-500" />
        Pending
      </span>
    );
  };

  const handleDelete = async (request) => {
    if (!request?.request_id || deletingId) return;

    const confirmed = window.confirm('Delete this request? This cannot be undone.');
    if (!confirmed) return;

    setDeletingId(request.request_id);
    setDeleteError(null);

    try {
      await deleteDeleteRequest(request.request_id);
      setRequests((prev) => prev.filter((item) => item.request_id !== request.request_id));
      setTotalCount((prev) => Math.max(prev - 1, 0));
      if (selectedRequest?.request_id === request.request_id) {
        setSelectedRequest(null);
      }
    } catch (err) {
      console.error('Delete request error:', err);
      setDeleteError('Failed to delete request. Please try again.');
    } finally {
      setDeletingId(null);
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[500px]">
        <div className="flex flex-col items-center gap-4">
          <div className="relative">
            <div className="w-16 h-16 border-4 border-red-200 rounded-full"></div>
            <div className="absolute top-0 left-0 w-16 h-16 border-4 border-red-600 border-t-transparent rounded-full animate-spin"></div>
          </div>
          <div className="text-center">
            <p className="text-lg font-medium text-gray-900 dark:text-white">Loading Requests</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">Fetching delete requests...</p>
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
          <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Unable to Load Requests</h3>
          <p className="text-gray-600 dark:text-gray-400 mb-6">{error}</p>
          <button
            onClick={fetchRequests}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-red-600 to-rose-600 text-white rounded-xl hover:from-red-700 hover:to-rose-700 transition-all shadow-lg shadow-red-500/25 font-medium"
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
            <div className="w-14 h-14 bg-gradient-to-br from-red-500 via-rose-500 to-orange-500 rounded-2xl flex items-center justify-center shadow-lg shadow-red-500/30">
              <Trash2 className="w-7 h-7 text-white" />
            </div>
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">
                Delete Requests
              </h1>
              <p className="text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-2">
                <Calendar className="w-4 h-4" />
                Account deletion requests from users and listeners
              </p>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={fetchRequests}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-gray-700 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 transition-all font-medium shadow-sm"
            >
              <RefreshCw className="w-4 h-4" />
              Refresh
            </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Total Requests</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{totalCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Across all roles</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-red-500 to-rose-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <AlertTriangle className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Pending</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{counts.pendingCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Needs review</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-amber-500 to-orange-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <AlertTriangle className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Users</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{counts.userCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Loaded in this page</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-blue-500 to-cyan-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <User className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Listeners</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{counts.listenerCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Loaded in this page</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-purple-500 to-indigo-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <User className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
      </div>

      <div className="mb-6 grid grid-cols-1 lg:grid-cols-3 gap-4">
        <div className="lg:col-span-2 relative">
          <div className="absolute left-5 top-1/2 -translate-y-1/2 flex items-center gap-2">
            <Search className="w-5 h-5 text-gray-400" />
          </div>
          <input
            type="text"
            value={searchTerm}
            onChange={(e) => {
              setCurrentPage(1);
              setSearchTerm(e.target.value);
            }}
            placeholder="Search by name, email, phone, or reason"
            className="w-full pl-14 pr-14 py-4 bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-700 rounded-2xl focus:ring-4 focus:ring-red-500/20 focus:border-red-500 outline-none transition-all text-gray-900 dark:text-white placeholder-gray-400"
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
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div className="flex items-center gap-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl px-4 py-3">
            <Filter className="w-4 h-4 text-gray-400" />
            <select
              value={roleFilter}
              onChange={(e) => {
                setCurrentPage(1);
                setRoleFilter(e.target.value);
              }}
              className="w-full bg-transparent text-gray-700 dark:text-gray-300 outline-none"
            >
              <option value="all">All Roles</option>
              <option value="user">Users</option>
              <option value="listener">Listeners</option>
            </select>
          </div>
          <div className="flex items-center gap-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl px-4 py-3">
            <Filter className="w-4 h-4 text-gray-400" />
            <select
              value={statusFilter}
              onChange={(e) => {
                setCurrentPage(1);
                setStatusFilter(e.target.value);
              }}
              className="w-full bg-transparent text-gray-700 dark:text-gray-300 outline-none"
            >
              <option value="all">All Statuses</option>
              <option value="pending">Pending</option>
              <option value="approved">Approved</option>
              <option value="rejected">Rejected</option>
            </select>
          </div>
        </div>
      </div>

      {deleteError && (
        <div className="mb-6 rounded-2xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">
          {deleteError}
        </div>
      )}

      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-750 border-b border-gray-200 dark:border-gray-700">
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Status</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Role</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Name</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Email</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Phone</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Reason</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Received</th>
                <th className="text-center px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {requests.length === 0 ? (
                <tr>
                  <td colSpan="8" className="px-6 py-16 text-center">
                    <div className="flex flex-col items-center">
                      <div className="w-20 h-20 bg-gradient-to-br from-gray-100 to-gray-200 rounded-2xl flex items-center justify-center mb-5">
                        <Trash2 className="w-10 h-10 text-gray-400" />
                      </div>
                      <p className="text-lg font-semibold text-gray-700 dark:text-gray-300">No delete requests</p>
                      <p className="text-gray-500 dark:text-gray-400 mt-2 max-w-sm">
                        Delete requests will appear here when users submit them.
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                requests.map((item) => (
                  <tr key={item.request_id} className="hover:bg-red-50/50 dark:hover:bg-gray-700/50 transition-colors">
                    <td className="px-6 py-5">{statusBadge(item.status)}</td>
                    <td className="px-6 py-5">{roleBadge(item.role)}</td>
                    <td className="px-6 py-5">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 bg-gradient-to-br from-red-400 to-rose-500 rounded-xl flex items-center justify-center text-white font-bold text-sm">
                          {(item.name || 'U').charAt(0).toUpperCase()}
                        </div>
                        <span className="font-semibold text-gray-900 dark:text-white">
                          {item.name || 'Unknown'}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex items-center gap-2 text-gray-700 dark:text-gray-300">
                        <Mail className="w-4 h-4 text-gray-400" />
                        {item.email || 'N/A'}
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <div className="flex items-center gap-2 text-gray-700 dark:text-gray-300">
                        <Phone className="w-4 h-4 text-gray-400" />
                        {item.phone || 'N/A'}
                      </div>
                    </td>
                    <td className="px-6 py-5">
                      <p className="text-gray-700 dark:text-gray-300 line-clamp-2 max-w-md">
                        {item.reason || 'N/A'}
                      </p>
                    </td>
                    <td className="px-6 py-5 text-sm text-gray-500 dark:text-gray-400">
                      {formatDate(item.created_at)}
                    </td>
                    <td className="px-6 py-5 text-center">
                      <div className="flex items-center justify-center gap-2">
                        <button
                          onClick={() => setSelectedRequest(item)}
                          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-gradient-to-r from-red-500 to-rose-600 rounded-xl hover:from-red-600 hover:to-rose-700 transition-all shadow-lg shadow-red-500/25"
                        >
                          <User className="w-4 h-4" />
                          View
                        </button>
                        <button
                          onClick={() => handleDelete(item)}
                          disabled={deletingId === item.request_id}
                          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-red-600 border border-red-200 rounded-xl hover:bg-red-50 transition-all disabled:opacity-60"
                        >
                          <Trash2 className="w-4 h-4" />
                          {deletingId === item.request_id ? 'Deleting' : 'Delete'}
                        </button>
                      </div>
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

      {selectedRequest && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl max-w-2xl w-full p-6">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-xl font-bold text-gray-900 dark:text-white">Delete Request</h2>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  {formatDate(selectedRequest.created_at)}
                </p>
              </div>
              <button
                onClick={() => setSelectedRequest(null)}
                className="w-9 h-9 rounded-lg border border-gray-200 dark:border-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-6 space-y-4">
              <div className="flex items-center justify-between flex-wrap gap-2">
                <div className="flex items-center gap-2">
                  {roleBadge(selectedRequest.role)}
                  {statusBadge(selectedRequest.status)}
                </div>
                <span className="text-sm text-gray-500 dark:text-gray-400">
                  User ID: {selectedRequest.user_id ? selectedRequest.user_id.slice(-8) : 'N/A'}
                </span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">Name</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium">{selectedRequest.name}</p>
                </div>
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">Email</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium">{selectedRequest.email}</p>
                </div>
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">Phone</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium">{selectedRequest.phone}</p>
                </div>
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">Status</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium capitalize">{selectedRequest.status}</p>
                </div>
              </div>
              <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                <p className="text-xs font-semibold text-gray-500 uppercase">Reason</p>
                <p className="mt-3 text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                  {selectedRequest.reason}
                </p>
              </div>
              <div className="flex flex-wrap items-center justify-end gap-2">
                <button
                  onClick={() => handleDelete(selectedRequest)}
                  disabled={deletingId === selectedRequest.request_id}
                  className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-red-600 border border-red-200 rounded-xl hover:bg-red-50 transition-all disabled:opacity-60"
                >
                  <Trash2 className="w-4 h-4" />
                  {deletingId === selectedRequest.request_id ? 'Deleting' : 'Delete Request'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DeleteRequests;
