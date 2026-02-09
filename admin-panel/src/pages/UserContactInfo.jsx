import React, { useState, useEffect } from 'react';
import { getUsers } from '../services/api';
import { 
  Search, Download, Users, Phone, Mail, User, ChevronLeft, ChevronRight, 
  X, RefreshCw, UserCheck, Filter, MoreVertical, Eye, Calendar, MapPin,
  TrendingUp, Clock, Shield, ExternalLink
} from 'lucide-react';

/* -------------------- MAIN COMPONENT -------------------- */
const UserContactInfo = () => {
  const [users, setUsers] = useState([]);
  const [filteredUsers, setFilteredUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedUser, setSelectedUser] = useState(null);
  const [viewMode, setViewMode] = useState('table'); // 'table' or 'grid'
  const itemsPerPage = 10;

  /* -------------------- FETCH USERS -------------------- */
  useEffect(() => {
    fetchUsers();
  }, []);

  const fetchUsers = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await getUsers();
      const userData = res.data || [];
      setUsers(userData);
      setFilteredUsers(userData);
    } catch (err) {
      console.error('Error fetching users:', err);
      setError('Failed to load users. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  /* -------------------- SEARCH FILTER -------------------- */
  useEffect(() => {
    if (!searchTerm.trim()) {
      setFilteredUsers(users);
      return;
    }

    const lower = searchTerm.toLowerCase();
    const filtered = users.filter(u =>
      u.email?.toLowerCase().includes(lower) ||
      u.display_name?.toLowerCase().includes(lower) ||
      u.full_name?.toLowerCase().includes(lower) ||
      u.phone_number?.includes(searchTerm) ||
      u.mobile_number?.includes(searchTerm)
    );

    setFilteredUsers(filtered);
    setCurrentPage(1);
  }, [searchTerm, users]);

  /* -------------------- PAGINATION -------------------- */
  const paginatedUsers = filteredUsers.slice(
    (currentPage - 1) * itemsPerPage,
    currentPage * itemsPerPage
  );
  const totalPages = Math.ceil(filteredUsers.length / itemsPerPage);

  /* -------------------- CSV EXPORT -------------------- */
  const exportCSV = () => {
    const headers = ['Name', 'Age', 'Email', 'Phone/Mobile'];
    const rows = filteredUsers.map(u => [
      u.display_name || u.full_name || 'N/A',
      u.age || 'N/A',
      u.email || 'N/A',
      u.phone_number || u.mobile_number || 'N/A'
    ]);

    const csv = [
      headers.join(','),
      ...rows.map(r => r.map(c => `"${c}"`).join(','))
    ].join('\n');

    const blob = new Blob([csv], { type: 'text/csv' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'user_contacts.csv';
    a.click();
    URL.revokeObjectURL(url);
  };

  /* -------------------- LOADING STATE -------------------- */
  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[500px]">
        <div className="flex flex-col items-center gap-4">
          <div className="relative">
            <div className="w-16 h-16 border-4 border-blue-200 dark:border-blue-900 rounded-full"></div>
            <div className="absolute top-0 left-0 w-16 h-16 border-4 border-blue-600 border-t-transparent rounded-full animate-spin"></div>
          </div>
          <div className="text-center">
            <p className="text-lg font-medium text-gray-900 dark:text-white">Loading Users</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">Please wait while we fetch the data...</p>
          </div>
        </div>
      </div>
    );
  }

  /* -------------------- ERROR STATE -------------------- */
  if (error) {
    return (
      <div className="flex items-center justify-center min-h-[500px]">
        <div className="text-center max-w-md">
          <div className="w-20 h-20 mx-auto mb-6 bg-gradient-to-br from-red-100 to-red-200 dark:from-red-900/40 dark:to-red-800/40 rounded-2xl flex items-center justify-center shadow-lg">
            <X className="w-10 h-10 text-red-500" />
          </div>
          <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Unable to Load Data</h3>
          <p className="text-gray-600 dark:text-gray-400 mb-6">{error}</p>
          <button
            onClick={fetchUsers}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-600 to-blue-700 text-white rounded-xl hover:from-blue-700 hover:to-blue-800 transition-all shadow-lg shadow-blue-500/25 font-medium"
          >
            <RefreshCw className="w-5 h-5" />
            Try Again
          </button>
        </div>
      </div>
    );
  }

  /* -------------------- UI -------------------- */
  return (
    <div className="p-4 sm:p-6 lg:p-8 max-w-[1600px] mx-auto">
      {/* Header Section */}
      <div className="mb-8">
        <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
          <div className="flex items-start gap-4">
            <div className="w-14 h-14 bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 rounded-2xl flex items-center justify-center shadow-lg shadow-purple-500/30">
              <Users className="w-7 h-7 text-white" />
            </div>
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">
                User Contacts
              </h1>
              <p className="text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-2">
                <Clock className="w-4 h-4" />
                Last updated: Just now
              </p>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={() => setViewMode(viewMode === 'table' ? 'grid' : 'table')}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-gray-700 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 transition-all font-medium shadow-sm"
            >
              <Filter className="w-4 h-4" />
              {viewMode === 'table' ? 'Grid View' : 'Table View'}
            </button>
            <button
              onClick={fetchUsers}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-gray-700 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 transition-all font-medium shadow-sm"
            >
              <RefreshCw className="w-4 h-4" />
              Refresh
            </button>
            <button
              onClick={exportCSV}
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-gradient-to-r from-emerald-500 to-teal-600 text-white rounded-xl hover:from-emerald-600 hover:to-teal-700 transition-all shadow-lg shadow-emerald-500/25 font-medium"
            >
              <Download className="w-4 h-4" />
              Export CSV
            </button>
          </div>
        </div>
      </div>

      {/* Stats Cards - Enhanced */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl hover:shadow-blue-500/10 transition-all duration-300 hover:-translate-y-1">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Total Users</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{users.length}</p>
              <p className="text-sm text-emerald-600 dark:text-emerald-400 mt-2 flex items-center gap-1">
                <TrendingUp className="w-4 h-4" />
                <span>Active accounts</span>
              </p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-blue-500 to-blue-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <Users className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>

        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl hover:shadow-green-500/10 transition-all duration-300 hover:-translate-y-1">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">With Phone</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                {users.filter(u => u.phone_number || u.mobile_number).length}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">
                {users.length > 0 ? Math.round((users.filter(u => u.phone_number || u.mobile_number).length / users.length) * 100) : 0}% of total
              </p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-emerald-500 to-green-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <Phone className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>

        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl hover:shadow-purple-500/10 transition-all duration-300 hover:-translate-y-1">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">With Email</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                {users.filter(u => u.email).length}
              </p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">
                {users.length > 0 ? Math.round((users.filter(u => u.email).length / users.length) * 100) : 0}% of total
              </p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-purple-500 to-violet-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <Mail className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>

        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl hover:shadow-amber-500/10 transition-all duration-300 hover:-translate-y-1">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Verified</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">
                {users.filter(u => u.is_verified || u.email_verified).length}
              </p>
              <p className="text-sm text-amber-600 dark:text-amber-400 mt-2 flex items-center gap-1">
                <Shield className="w-4 h-4" />
                <span>Verified users</span>
              </p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-amber-500 to-orange-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <UserCheck className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
      </div>

      {/* Search Bar - Enhanced */}
      <div className="mb-8">
        <div className="relative">
          <div className="absolute left-5 top-1/2 -translate-y-1/2 flex items-center gap-2">
            <Search className="w-5 h-5 text-gray-400" />
          </div>
          <input
            type="text"
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            placeholder="Search by name, email, or phone number..."
            className="w-full pl-14 pr-14 py-4 bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-700 rounded-2xl focus:ring-4 focus:ring-blue-500/20 focus:border-blue-500 outline-none transition-all text-gray-900 dark:text-white placeholder-gray-400 text-base shadow-sm"
          />
          {searchTerm && (
            <button
              onClick={() => setSearchTerm('')}
              className="absolute right-5 top-1/2 -translate-y-1/2 w-8 h-8 flex items-center justify-center text-gray-400 hover:text-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
            >
              <X className="w-5 h-5" />
            </button>
          )}
        </div>
        {searchTerm && (
          <div className="flex items-center gap-2 mt-3 text-sm">
            <span className="px-3 py-1.5 bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-300 rounded-lg font-medium">
              {filteredUsers.length} result{filteredUsers.length !== 1 ? 's' : ''} found
            </span>
            <button
              onClick={() => setSearchTerm('')}
              className="text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
            >
              Clear search
            </button>
          </div>
        )}
      </div>

      {/* Users Table - Enhanced */}
      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-sm overflow-hidden">
        {viewMode === 'table' ? (
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-750 border-b border-gray-200 dark:border-gray-700">
                  <th className="text-left px-6 py-5 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">User</th>
                  <th className="text-left px-6 py-5 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Age</th>
                  <th className="text-left px-6 py-5 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Email Address</th>
                  <th className="text-left px-6 py-5 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Phone/Mobile</th>
                  <th className="text-center px-6 py-5 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
                {paginatedUsers.length === 0 ? (
                  <tr>
                    <td colSpan="5" className="px-6 py-16 text-center">
                      <div className="flex flex-col items-center">
                        <div className="w-20 h-20 bg-gradient-to-br from-gray-100 to-gray-200 dark:from-gray-700 dark:to-gray-600 rounded-2xl flex items-center justify-center mb-5 shadow-inner">
                          <Users className="w-10 h-10 text-gray-400" />
                        </div>
                        <p className="text-lg font-semibold text-gray-700 dark:text-gray-300">No users found</p>
                        <p className="text-gray-500 dark:text-gray-400 mt-2 max-w-sm">
                          Try adjusting your search criteria or check back later
                        </p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  paginatedUsers.map((u, index) => (
                    <tr 
                      key={u.user_id} 
                      className="hover:bg-blue-50/50 dark:hover:bg-gray-700/50 transition-colors group"
                      style={{ animationDelay: `${index * 50}ms` }}
                    >
                      <td className="px-6 py-5">
                        <div className="flex items-center gap-4">
                          <div className="relative">
                            <div className="w-12 h-12 bg-gradient-to-br from-indigo-400 via-purple-500 to-pink-500 rounded-xl flex items-center justify-center text-white font-bold text-lg shadow-lg">
                              {(u.display_name || u.full_name || 'U').charAt(0).toUpperCase()}
                            </div>
                            {(u.is_verified || u.email_verified) && (
                              <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center border-2 border-white dark:border-gray-800">
                                <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                                  <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                                </svg>
                              </div>
                            )}
                          </div>
                          <div>
                            <p className="font-semibold text-gray-900 dark:text-white">
                              {u.display_name || u.full_name || 'Unknown User'}
                            </p>
                            <p className="text-sm text-gray-500 dark:text-gray-400">
                              ID: {u.user_id?.toString().slice(-6) || 'N/A'}
                            </p>
                          </div>
                        </div>
                      </td>
                      <td className="px-6 py-5">
                        <div className="inline-flex items-center gap-2 px-3 py-1.5 bg-gray-100 dark:bg-gray-700 rounded-lg">
                          <Calendar className="w-4 h-4 text-gray-500" />
                          <span className="font-medium text-gray-700 dark:text-gray-300">
                            {u.age || (u.date_of_birth ? calculateAge(u.date_of_birth) : 'N/A')}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-5">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 bg-purple-100 dark:bg-purple-900/30 rounded-lg flex items-center justify-center">
                            <Mail className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                          </div>
                          <span className="text-gray-700 dark:text-gray-300 font-medium">
                            {u.email || 'N/A'}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-5">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 bg-emerald-100 dark:bg-emerald-900/30 rounded-lg flex items-center justify-center">
                            <Phone className="w-4 h-4 text-emerald-600 dark:text-emerald-400" />
                          </div>
                          <span className="text-gray-700 dark:text-gray-300 font-medium">
                            {u.phone_number || u.mobile_number || 'N/A'}
                          </span>
                        </div>
                      </td>
                      <td className="px-6 py-5">
                        <div className="flex items-center justify-center gap-2">
                          <button
                            onClick={() => setSelectedUser(u)}
                            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-gradient-to-r from-blue-500 to-indigo-600 rounded-xl hover:from-blue-600 hover:to-indigo-700 transition-all shadow-lg shadow-blue-500/25 hover:shadow-xl hover:shadow-blue-500/30 hover:-translate-y-0.5"
                          >
                            <Eye className="w-4 h-4" />
                            View
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        ) : (
          /* Grid View */
          <div className="p-6 grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {paginatedUsers.length === 0 ? (
              <div className="col-span-full py-16 text-center">
                <div className="flex flex-col items-center">
                  <div className="w-20 h-20 bg-gradient-to-br from-gray-100 to-gray-200 dark:from-gray-700 dark:to-gray-600 rounded-2xl flex items-center justify-center mb-5">
                    <Users className="w-10 h-10 text-gray-400" />
                  </div>
                  <p className="text-lg font-semibold text-gray-700 dark:text-gray-300">No users found</p>
                </div>
              </div>
            ) : (
              paginatedUsers.map(u => (
                <div
                  key={u.user_id}
                  className="bg-gray-50 dark:bg-gray-700/50 rounded-2xl p-5 hover:shadow-lg transition-all duration-300 hover:-translate-y-1 border border-gray-100 dark:border-gray-600 group"
                >
                  <div className="flex items-center gap-4 mb-4">
                    <div className="relative">
                      <div className="w-14 h-14 bg-gradient-to-br from-indigo-400 via-purple-500 to-pink-500 rounded-xl flex items-center justify-center text-white font-bold text-xl shadow-lg">
                        {(u.display_name || u.full_name || 'U').charAt(0).toUpperCase()}
                      </div>
                      {(u.is_verified || u.email_verified) && (
                        <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-emerald-500 rounded-full flex items-center justify-center border-2 border-white dark:border-gray-700">
                          <svg className="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                            <path fillRule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clipRule="evenodd" />
                          </svg>
                        </div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="font-bold text-gray-900 dark:text-white truncate">
                        {u.display_name || u.full_name || 'Unknown'}
                      </p>
                      <p className="text-sm text-gray-500 dark:text-gray-400">
                        Age: {u.age || (u.date_of_birth ? calculateAge(u.date_of_birth) : 'N/A')}
                      </p>
                    </div>
                  </div>
                  <div className="space-y-2 mb-4">
                    <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                      <Mail className="w-4 h-4 text-purple-500" />
                      <span className="truncate">{u.email || 'N/A'}</span>
                    </div>
                    <div className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
                      <Phone className="w-4 h-4 text-emerald-500" />
                      <span>{u.phone_number || u.mobile_number || 'N/A'}</span>
                    </div>
                  </div>
                  <button
                    onClick={() => setSelectedUser(u)}
                    className="w-full py-2.5 text-sm font-semibold text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/30 rounded-xl hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors flex items-center justify-center gap-2"
                  >
                    <Eye className="w-4 h-4" />
                    View Details
                  </button>
                </div>
              ))
            )}
          </div>
        )}

        {/* Pagination - Enhanced */}
        {totalPages > 1 && (
          <div className="flex flex-col sm:flex-row items-center justify-between px-6 py-5 border-t border-gray-200 dark:border-gray-700 bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-750 gap-4">
            <p className="text-sm font-medium text-gray-600 dark:text-gray-400">
              Showing <span className="text-gray-900 dark:text-white font-bold">{(currentPage - 1) * itemsPerPage + 1}</span> to <span className="text-gray-900 dark:text-white font-bold">{Math.min(currentPage * itemsPerPage, filteredUsers.length)}</span> of <span className="text-gray-900 dark:text-white font-bold">{filteredUsers.length}</span> users
            </p>
            <div className="flex items-center gap-2">
              <button
                disabled={currentPage === 1}
                onClick={() => setCurrentPage(p => p - 1)}
                className="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
              >
                <ChevronLeft className="w-4 h-4" />
                Previous
              </button>
              <div className="hidden sm:flex items-center gap-1">
                {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                  let pageNum;
                  if (totalPages <= 5) {
                    pageNum = i + 1;
                  } else if (currentPage <= 3) {
                    pageNum = i + 1;
                  } else if (currentPage >= totalPages - 2) {
                    pageNum = totalPages - 4 + i;
                  } else {
                    pageNum = currentPage - 2 + i;
                  }
                  return (
                    <button
                      key={pageNum}
                      onClick={() => setCurrentPage(pageNum)}
                      className={`w-10 h-10 text-sm font-bold rounded-xl transition-all ${
                        currentPage === pageNum
                          ? 'bg-gradient-to-r from-blue-500 to-indigo-600 text-white shadow-lg shadow-blue-500/30'
                          : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
                      }`}
                    >
                      {pageNum}
                    </button>
                  );
                })}
              </div>
              <button
                disabled={currentPage === totalPages}
                onClick={() => setCurrentPage(p => p + 1)}
                className="inline-flex items-center gap-2 px-4 py-2.5 text-sm font-semibold text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
              >
                Next
                <ChevronRight className="w-4 h-4" />
              </button>
            </div>
          </div>
        )}
      </div>

      {/* User Detail Modal - Enhanced */}
      {selectedUser && (
        <div 
          className="fixed inset-0 bg-black/60 backdrop-blur-md flex items-center justify-center z-50 p-4"
          onClick={() => setSelectedUser(null)}
        >
          <div 
            className="bg-white dark:bg-gray-800 rounded-3xl shadow-2xl w-full max-w-lg overflow-hidden animate-in zoom-in-95 duration-200"
            onClick={e => e.stopPropagation()}
          >
            {/* Modal Header - Gradient */}
            <div className="relative bg-gradient-to-br from-indigo-500 via-purple-500 to-pink-500 px-8 py-10 text-center overflow-hidden">
              {/* Decorative circles */}
              <div className="absolute top-0 left-0 w-32 h-32 bg-white/10 rounded-full -translate-x-16 -translate-y-16"></div>
              <div className="absolute bottom-0 right-0 w-24 h-24 bg-white/10 rounded-full translate-x-12 translate-y-12"></div>
              
              <button
                onClick={() => setSelectedUser(null)}
                className="absolute top-4 right-4 w-10 h-10 bg-white/20 hover:bg-white/30 rounded-xl flex items-center justify-center text-white transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
              
              <div className="relative">
                <div className="w-24 h-24 mx-auto bg-white rounded-2xl flex items-center justify-center text-4xl font-bold text-transparent bg-clip-text bg-gradient-to-br from-indigo-500 to-pink-500 mb-4 shadow-2xl">
                  {(selectedUser.display_name || selectedUser.full_name || 'U').charAt(0).toUpperCase()}
                </div>
                <h3 className="text-2xl font-bold text-white">
                  {selectedUser.display_name || selectedUser.full_name || 'Unknown User'}
                </h3>
                {(selectedUser.is_verified || selectedUser.email_verified) && (
                  <div className="inline-flex items-center gap-2 mt-3 px-3 py-1.5 bg-white/20 rounded-full text-white text-sm font-medium">
                    <Shield className="w-4 h-4" />
                    Verified User
                  </div>
                )}
              </div>
            </div>
            
            {/* Modal Body */}
            <div className="p-8 space-y-4">
              <div className="flex items-center gap-4 p-5 bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/20 dark:to-indigo-900/20 rounded-2xl border border-blue-100 dark:border-blue-800">
                <div className="w-12 h-12 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center shadow-lg">
                  <Calendar className="w-6 h-6 text-white" />
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Age</p>
                  <p className="text-lg font-bold text-gray-900 dark:text-white">
                    {selectedUser.age || (selectedUser.date_of_birth ? calculateAge(selectedUser.date_of_birth) + ' years old' : 'Not specified')}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-4 p-5 bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-2xl border border-purple-100 dark:border-purple-800">
                <div className="w-12 h-12 bg-gradient-to-br from-purple-500 to-pink-600 rounded-xl flex items-center justify-center shadow-lg">
                  <Mail className="w-6 h-6 text-white" />
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Email Address</p>
                  <p className="text-lg font-bold text-gray-900 dark:text-white truncate">
                    {selectedUser.email || 'Not provided'}
                  </p>
                </div>
              </div>

              <div className="flex items-center gap-4 p-5 bg-gradient-to-r from-emerald-50 to-teal-50 dark:from-emerald-900/20 dark:to-teal-900/20 rounded-2xl border border-emerald-100 dark:border-emerald-800">
                <div className="w-12 h-12 bg-gradient-to-br from-emerald-500 to-teal-600 rounded-xl flex items-center justify-center shadow-lg">
                  <Phone className="w-6 h-6 text-white" />
                </div>
                <div>
                  <p className="text-sm font-medium text-gray-500 dark:text-gray-400">Phone / Mobile</p>
                  <p className="text-lg font-bold text-gray-900 dark:text-white">
                    {selectedUser.phone_number || selectedUser.mobile_number || 'Not provided'}
                  </p>
                </div>
              </div>
            </div>

            {/* Modal Footer */}
            <div className="px-8 py-6 bg-gray-50 dark:bg-gray-700/50 border-t border-gray-200 dark:border-gray-700">
              <button
                onClick={() => setSelectedUser(null)}
                className="w-full px-6 py-3.5 bg-gradient-to-r from-gray-800 to-gray-900 dark:from-gray-600 dark:to-gray-700 text-white font-bold rounded-2xl hover:from-gray-900 hover:to-black dark:hover:from-gray-500 dark:hover:to-gray-600 transition-all shadow-lg"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

/* -------------------- HELPER FUNCTION -------------------- */
const calculateAge = (dateOfBirth) => {
  if (!dateOfBirth) return 'N/A';
  const today = new Date();
  const birthDate = new Date(dateOfBirth);
  let age = today.getFullYear() - birthDate.getFullYear();
  const monthDiff = today.getMonth() - birthDate.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
    age--;
  }
  return age > 0 ? age : 'N/A';
};

export default UserContactInfo;
