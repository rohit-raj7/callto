import React, { useState, useEffect } from 'react';
import { getUserTransactions } from '../services/api';
import { useTheme } from '../contexts/ThemeContext';
import toast from 'react-hot-toast';

const UserTransactionsModal = ({ user, onClose }) => {
  const { isDark } = useTheme();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [typeFilter, setTypeFilter] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const perPage = 8;

  useEffect(() => {
    fetchTransactions();
  }, [user.user_id]);

  const fetchTransactions = async () => {
    try {
      const res = await getUserTransactions(user.user_id);
      setData(res.data);
    } catch (err) {
      console.error('Error fetching transactions:', err);
      toast.error('Failed to load transactions');
    } finally {
      setLoading(false);
    }
  };

  // Convert UTC to IST
  const toIST = (dateStr) => {
    const d = new Date(dateStr);
    const istOffset = 5.5 * 60 * 60 * 1000;
    return new Date(d.getTime() + istOffset);
  };

  const formatDate = (dateStr) => {
    const ist = toIST(dateStr);
    const day = ist.getUTCDate().toString().padStart(2, '0');
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const month = months[ist.getUTCMonth()];
    const year = ist.getUTCFullYear();
    let hours = ist.getUTCHours();
    const minutes = ist.getUTCMinutes().toString().padStart(2, '0');
    const ampm = hours >= 12 ? 'PM' : 'AM';
    hours = hours % 12 || 12;
    return `${day} ${month} ${year}, ${hours}:${minutes} ${ampm}`;
  };

  const getTypeBadge = (type) => {
    const styles = {
      credit: 'bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400',
      debit: 'bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-400',
      refund: 'bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-400',
      recharge: 'bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-400',
    };
    return styles[type] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300';
  };

  const getStatusBadge = (status) => {
    const styles = {
      completed: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
      success: 'bg-green-100 text-green-700 dark:bg-green-900/30 dark:text-green-400',
      pending: 'bg-yellow-100 text-yellow-700 dark:bg-yellow-900/30 dark:text-yellow-400',
      failed: 'bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-400',
    };
    return styles[status] || 'bg-gray-100 text-gray-700 dark:bg-gray-700 dark:text-gray-300';
  };

  const filteredTxns = (data?.transactions || []).filter((tx) => {
    const matchesSearch =
      !searchTerm ||
      (tx.description && tx.description.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (tx.transaction_id && tx.transaction_id.toLowerCase().includes(searchTerm.toLowerCase()));
    const matchesType = !typeFilter || tx.transaction_type === typeFilter;
    return matchesSearch && matchesType;
  });

  const totalPages = Math.ceil(filteredTxns.length / perPage);
  const paginatedTxns = filteredTxns.slice((currentPage - 1) * perPage, currentPage * perPage);

  useEffect(() => {
    setCurrentPage(1);
  }, [searchTerm, typeFilter]);

  // Compute summary
  const totalCredits = (data?.transactions || [])
    .filter((t) => t.transaction_type === 'credit')
    .reduce((sum, t) => sum + parseFloat(t.amount || 0), 0);
  const totalDebits = (data?.transactions || [])
    .filter((t) => t.transaction_type === 'debit')
    .reduce((sum, t) => sum + parseFloat(t.amount || 0), 0);

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4" onClick={onClose}>
      <div
        className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl w-full max-w-4xl max-h-[90vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Header */}
        <div className="bg-gradient-to-r from-blue-600 to-blue-700 rounded-t-2xl px-6 py-5 text-white">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-4">
              <div className="h-12 w-12 bg-white bg-opacity-20 rounded-full flex items-center justify-center text-xl font-bold">
                {user.display_name ? user.display_name.charAt(0).toUpperCase() : 'U'}
              </div>
              <div>
                <h2 className="text-xl font-bold">{user.display_name || 'Unknown User'}</h2>
                <div className="flex items-center gap-3 text-blue-100 text-sm mt-0.5">
                  {user.email && (
                    <span className="flex items-center gap-1">
                      <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                      </svg>
                      {user.email}
                    </span>
                  )}
                  {user.mobile_number && (
                    <span className="flex items-center gap-1">
                      <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" />
                      </svg>
                      {user.mobile_number}
                    </span>
                  )}
                  {(user.city || user.country) && (
                    <span className="flex items-center gap-1">
                      <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                      </svg>
                      {[user.city, user.country].filter(Boolean).join(', ')}
                    </span>
                  )}
                </div>
              </div>
            </div>
            <button onClick={onClose} className="text-white hover:bg-white hover:bg-opacity-20 rounded-lg p-2 transition-colors">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </button>
          </div>
        </div>

        {loading ? (
          <div className="flex items-center justify-center py-20 bg-white dark:bg-gray-800">
            <div className="animate-spin rounded-full h-10 w-10 border-b-2 border-blue-600 dark:border-blue-400"></div>
          </div>
        ) : (
          <div className="flex-1 overflow-y-auto">
            {/* Summary Cards */}
            <div className="grid grid-cols-3 gap-4 px-6 py-4">
              <div className="bg-blue-50 dark:bg-blue-900/20 rounded-xl p-4 text-center">
                <p className="text-xs font-medium text-blue-600 dark:text-blue-400 uppercase tracking-wide">Wallet Balance</p>
                <p className="text-2xl font-bold text-blue-900 dark:text-blue-100 mt-1">₹{parseFloat(data?.wallet?.balance || 0).toFixed(2)}</p>
              </div>
              <div className="bg-green-50 dark:bg-green-900/20 rounded-xl p-4 text-center">
                <p className="text-xs font-medium text-green-600 dark:text-green-400 uppercase tracking-wide">Total Credits</p>
                <p className="text-2xl font-bold text-green-900 dark:text-green-100 mt-1">₹{totalCredits.toFixed(2)}</p>
              </div>
              <div className="bg-red-50 dark:bg-red-900/20 rounded-xl p-4 text-center">
                <p className="text-xs font-medium text-red-600 dark:text-red-400 uppercase tracking-wide">Total Debits</p>
                <p className="text-2xl font-bold text-red-900 dark:text-red-100 mt-1">₹{totalDebits.toFixed(2)}</p>
              </div>
            </div>

            {/* Filters */}
            <div className="px-6 pb-3 flex gap-3">
              <div className="flex-1 relative">
                <svg className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
                <input
                  type="text"
                  placeholder="Search transactions..."
                  value={searchTerm}
                  onChange={(e) => setSearchTerm(e.target.value)}
                  className="w-full pl-9 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500"
                />
              </div>
              <select
                value={typeFilter}
                onChange={(e) => setTypeFilter(e.target.value)}
                className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 focus:border-transparent outline-none bg-white dark:bg-gray-700 text-gray-900 dark:text-white"
              >
                <option value="">All Types</option>
                <option value="credit">Credit</option>
                <option value="debit">Debit</option>
                <option value="refund">Refund</option>
              </select>
            </div>

            {/* Transaction List */}
            <div className="px-6 pb-4">
              {filteredTxns.length === 0 ? (
                <div className="text-center py-12 text-gray-500 dark:text-gray-400">
                  <svg className="w-12 h-12 mx-auto mb-3 text-gray-300 dark:text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2" />
                  </svg>
                  <p className="font-medium">No transactions found</p>
                  <p className="text-sm mt-1">This user has no transaction history yet</p>
                </div>
              ) : (
                <div className="space-y-2">
                  {paginatedTxns.map((tx) => (
                    <div
                      key={tx.transaction_id}
                      className="bg-gray-50 dark:bg-gray-700/50 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-xl p-4 transition-colors border border-gray-100 dark:border-gray-600"
                    >
                      <div className="flex items-center justify-between">
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center gap-2 mb-1">
                            <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${getTypeBadge(tx.transaction_type)}`}>
                              {tx.transaction_type === 'credit' ? '↑' : '↓'} {tx.transaction_type}
                            </span>
                            <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium ${getStatusBadge(tx.status)}`}>
                              {tx.status}
                            </span>
                            {tx.payment_method && (
                              <span className="text-xs text-gray-400 dark:text-gray-500">{tx.payment_method}</span>
                            )}
                          </div>
                          <p className="text-sm text-gray-700 dark:text-gray-300 truncate">{tx.description || 'No description'}</p>
                          <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">{formatDate(tx.created_at)}</p>
                        </div>
                        <div className="ml-4 text-right flex-shrink-0">
                          <p className={`text-lg font-bold ${tx.transaction_type === 'credit' ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'}`}>
                            {tx.transaction_type === 'credit' ? '+' : '-'}₹{parseFloat(tx.amount).toFixed(2)}
                          </p>
                          <p className="text-xs text-gray-400 dark:text-gray-500 font-mono mt-0.5">
                            {tx.transaction_id.substring(0, 8)}...
                          </p>
                        </div>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* Pagination */}
              {totalPages > 1 && (
                <div className="flex items-center justify-between mt-4 pt-3 border-t border-gray-200 dark:border-gray-700">
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    Showing {(currentPage - 1) * perPage + 1}–{Math.min(currentPage * perPage, filteredTxns.length)} of {filteredTxns.length}
                  </p>
                  <div className="flex gap-1">
                    <button
                      disabled={currentPage === 1}
                      onClick={() => setCurrentPage(currentPage - 1)}
                      className="px-3 py-1.5 border border-gray-300 dark:border-gray-600 rounded-lg text-xs font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      Prev
                    </button>
                    <span className="px-3 py-1.5 text-xs text-gray-600 dark:text-gray-400">{currentPage} / {totalPages}</span>
                    <button
                      disabled={currentPage === totalPages}
                      onClick={() => setCurrentPage(currentPage + 1)}
                      className="px-3 py-1.5 border border-gray-300 dark:border-gray-600 rounded-lg text-xs font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 hover:bg-gray-50 dark:hover:bg-gray-600 disabled:opacity-40 disabled:cursor-not-allowed"
                    >
                      Next
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default UserTransactionsModal;
