import React, { useEffect, useMemo, useState } from 'react';
import {
  Inbox,
  Search,
  RefreshCw,
  Mail,
  User,
  MessageSquare,
  Calendar,
  Filter,
  X
} from 'lucide-react';
import { getContactMessages } from '../services/api';

const ContactMessages = () => {
  const [messages, setMessages] = useState([]);
  const [totalCount, setTotalCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [sourceFilter, setSourceFilter] = useState('all');
  const [currentPage, setCurrentPage] = useState(1);
  const [selectedMessage, setSelectedMessage] = useState(null);
  const itemsPerPage = 12;

  const counts = useMemo(() => {
    const contactCount = messages.filter((m) => m.source === 'contact').length;
    const supportCount = messages.filter((m) => m.source === 'support').length;
    return { contactCount, supportCount };
  }, [messages]);

  useEffect(() => {
    const timer = setTimeout(() => {
      fetchMessages();
    }, 300);

    return () => clearTimeout(timer);
  }, [currentPage, sourceFilter, searchTerm]);

  const fetchMessages = async () => {
    setLoading(true);
    setError(null);

    try {
      const params = {
        page: currentPage,
        limit: itemsPerPage
      };

      if (sourceFilter !== 'all') {
        params.source = sourceFilter;
      }

      if (searchTerm.trim()) {
        params.search = searchTerm.trim();
      }

      const res = await getContactMessages(params);
      const payload = res.data || {};
      setMessages(Array.isArray(payload.messages) ? payload.messages : []);
      setTotalCount(payload.count || 0);
    } catch (err) {
      console.error('Error fetching contact messages:', err);
      setError('Failed to load contact messages. Please try again.');
    } finally {
      setLoading(false);
    }
  };

  const totalPages = Math.max(1, Math.ceil(totalCount / itemsPerPage));

  const formatDate = (value) => {
    if (!value) return 'N/A';
    try {
      return new Date(value).toLocaleString();
    } catch {
      return value;
    }
  };

  const sourceBadge = (source) => {
    const isSupport = source === 'support';
    return (
      <span
        className={`inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-semibold border ${
          isSupport
            ? 'bg-amber-50 text-amber-700 border-amber-200'
            : 'bg-blue-50 text-blue-700 border-blue-200'
        }`}
      >
        <span className={`w-2 h-2 rounded-full ${isSupport ? 'bg-amber-500' : 'bg-blue-500'}`} />
        {isSupport ? 'Support' : 'Contact'}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-[500px]">
        <div className="flex flex-col items-center gap-4">
          <div className="relative">
            <div className="w-16 h-16 border-4 border-indigo-200 rounded-full"></div>
            <div className="absolute top-0 left-0 w-16 h-16 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
          </div>
          <div className="text-center">
            <p className="text-lg font-medium text-gray-900 dark:text-white">Loading Messages</p>
            <p className="text-sm text-gray-500 dark:text-gray-400">Fetching contact submissions...</p>
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
          <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-2">Unable to Load Messages</h3>
          <p className="text-gray-600 dark:text-gray-400 mb-6">{error}</p>
          <button
            onClick={fetchMessages}
            className="inline-flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-indigo-600 to-blue-600 text-white rounded-xl hover:from-indigo-700 hover:to-blue-700 transition-all shadow-lg shadow-indigo-500/25 font-medium"
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
            <div className="w-14 h-14 bg-gradient-to-br from-indigo-500 via-blue-500 to-cyan-500 rounded-2xl flex items-center justify-center shadow-lg shadow-blue-500/30">
              <Inbox className="w-7 h-7 text-white" />
            </div>
            <div>
              <h1 className="text-2xl sm:text-3xl font-bold text-gray-900 dark:text-white">
                Contact Messages
              </h1>
              <p className="text-gray-500 dark:text-gray-400 mt-1 flex items-center gap-2">
                <Calendar className="w-4 h-4" />
                Latest submissions from contact and support forms
              </p>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <button
              onClick={fetchMessages}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 border border-gray-200 dark:border-gray-700 rounded-xl hover:bg-gray-50 dark:hover:bg-gray-700 transition-all font-medium shadow-sm"
            >
              <RefreshCw className="w-4 h-4" />
              Refresh
            </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-8">
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Total Messages</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{totalCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Across all sources</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-indigo-500 to-blue-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <MessageSquare className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Contact Form</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{counts.contactCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Loaded in this page</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-blue-500 to-cyan-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <Mail className="w-7 h-7 text-white" />
            </div>
          </div>
        </div>
        <div className="group bg-white dark:bg-gray-800 rounded-2xl p-6 border border-gray-100 dark:border-gray-700 shadow-sm hover:shadow-xl transition-all">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide">Support Form</p>
              <p className="text-3xl font-bold text-gray-900 dark:text-white mt-2">{counts.supportCount}</p>
              <p className="text-sm text-gray-500 dark:text-gray-400 mt-2">Loaded in this page</p>
            </div>
            <div className="w-14 h-14 bg-gradient-to-br from-amber-500 to-orange-600 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
              <Inbox className="w-7 h-7 text-white" />
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
            placeholder="Search by name, email, or message"
            className="w-full pl-14 pr-14 py-4 bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-700 rounded-2xl focus:ring-4 focus:ring-blue-500/20 focus:border-blue-500 outline-none transition-all text-gray-900 dark:text-white placeholder-gray-400"
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
        <div className="flex items-center gap-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-2xl px-4 py-3">
          <Filter className="w-4 h-4 text-gray-400" />
          <select
            value={sourceFilter}
            onChange={(e) => {
              setCurrentPage(1);
              setSourceFilter(e.target.value);
            }}
            className="w-full bg-transparent text-gray-700 dark:text-gray-300 outline-none"
          >
            <option value="all">All Sources</option>
            <option value="contact">Contact Form</option>
            <option value="support">Support Form</option>
          </select>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-800 rounded-2xl border border-gray-200 dark:border-gray-700 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-750 border-b border-gray-200 dark:border-gray-700">
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Source</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Name</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Email</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Message</th>
                <th className="text-left px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Received</th>
                <th className="text-center px-6 py-4 text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-700">
              {messages.length === 0 ? (
                <tr>
                  <td colSpan="6" className="px-6 py-16 text-center">
                    <div className="flex flex-col items-center">
                      <div className="w-20 h-20 bg-gradient-to-br from-gray-100 to-gray-200 rounded-2xl flex items-center justify-center mb-5">
                        <Inbox className="w-10 h-10 text-gray-400" />
                      </div>
                      <p className="text-lg font-semibold text-gray-700 dark:text-gray-300">No contact messages</p>
                      <p className="text-gray-500 dark:text-gray-400 mt-2 max-w-sm">
                        Contact submissions will appear here when users send them.
                      </p>
                    </div>
                  </td>
                </tr>
              ) : (
                messages.map((item) => (
                  <tr key={item.contact_id} className="hover:bg-blue-50/50 dark:hover:bg-gray-700/50 transition-colors">
                    <td className="px-6 py-5">{sourceBadge(item.source)}</td>
                    <td className="px-6 py-5">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 bg-gradient-to-br from-indigo-400 to-blue-500 rounded-xl flex items-center justify-center text-white font-bold text-sm">
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
                      <p className="text-gray-700 dark:text-gray-300 line-clamp-2 max-w-md">
                        {item.message || 'N/A'}
                      </p>
                    </td>
                    <td className="px-6 py-5 text-sm text-gray-500 dark:text-gray-400">
                      {formatDate(item.created_at)}
                    </td>
                    <td className="px-6 py-5 text-center">
                      <button
                        onClick={() => setSelectedMessage(item)}
                        className="inline-flex items-center gap-2 px-4 py-2 text-sm font-semibold text-white bg-gradient-to-r from-indigo-500 to-blue-600 rounded-xl hover:from-indigo-600 hover:to-blue-700 transition-all shadow-lg shadow-indigo-500/25"
                      >
                        <User className="w-4 h-4" />
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

      {selectedMessage && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 backdrop-blur-sm p-4">
          <div className="bg-white dark:bg-gray-900 rounded-2xl shadow-2xl max-w-2xl w-full p-6">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="text-xl font-bold text-gray-900 dark:text-white">Contact Message</h2>
                <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                  {formatDate(selectedMessage.created_at)}
                </p>
              </div>
              <button
                onClick={() => setSelectedMessage(null)}
                className="w-9 h-9 rounded-lg border border-gray-200 dark:border-gray-700 flex items-center justify-center text-gray-500 hover:text-gray-700"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="mt-6 space-y-4">
              <div className="flex items-center justify-between">
                {sourceBadge(selectedMessage.source)}
                <span className="text-sm text-gray-500 dark:text-gray-400">
                  User ID: {selectedMessage.user_id ? selectedMessage.user_id.slice(-8) : 'N/A'}
                </span>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">Name</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium">{selectedMessage.name}</p>
                </div>
                <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                  <p className="text-xs font-semibold text-gray-500 uppercase">Email</p>
                  <p className="mt-2 text-gray-900 dark:text-white font-medium">{selectedMessage.email}</p>
                </div>
              </div>
              <div className="p-4 rounded-xl border border-gray-200 dark:border-gray-700">
                <p className="text-xs font-semibold text-gray-500 uppercase">Message</p>
                <p className="mt-3 text-gray-700 dark:text-gray-300 whitespace-pre-wrap">
                  {selectedMessage.message}
                </p>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ContactMessages;
