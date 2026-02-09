
import React, { useState, useEffect, useCallback } from 'react';
import { getUsers, getAdminListeners } from '../services/api';
import { 
  Users, Headphones, Activity, Star, UserPlus, Bell, Download, TrendingUp, 
  BarChart3, PieChart, Activity as ActivityIcon, Wifi, WifiOff, RefreshCw,
  Clock, Calendar, Phone, Mail, MapPin, CheckCircle, XCircle, UserCheck
} from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, PieChart as RechartsPieChart, Pie, Cell, Legend, AreaChart, Area } from 'recharts';

const AdminDashboard = () => {
  const [stats, setStats] = useState({
    totalUsers: 0,
    totalListeners: 0,
    activeListeners: 0,
    averageRating: 0,
    approvedListeners: 0,
    newUsersToday: 0,
  });
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [recentActivities, setRecentActivities] = useState([]);
  const [chartData, setChartData] = useState({
    userGrowth: [],
    listenerPerformance: [],
    ratingDistribution: [],
    usersByLocation: [],
    accountTypes: []
  });
  const [realTimeStatus, setRealTimeStatus] = useState({
    onlineListeners: 0,
    totalCalls: 0,
    systemHealth: 'healthy',
    lastUpdated: new Date()
  });
  const [lastRefresh, setLastRefresh] = useState(new Date());

  const fetchStats = useCallback(async () => {
    try {
      setLoading(true);
      const [usersRes, listenersRes] = await Promise.all([getUsers(), getAdminListeners()]);
      const usersData = usersRes.data || [];
      const listenersData = listenersRes.data?.listeners || [];

      const totalUsers = usersData.length;
      const totalListeners = listenersData.length;
      const activeListeners = listenersData.filter(l => l.is_online).length;
      const approvedListeners = listenersData.filter(l => (l.verification_status || 'pending') === 'approved').length;
      
      // Calculate average rating from listeners
      const listenersWithRating = listenersData.filter(l => l.average_rating && l.average_rating > 0);
      const averageRating = listenersWithRating.length > 0
        ? listenersWithRating.reduce((sum, l) => sum + parseFloat(l.average_rating || 0), 0) / listenersWithRating.length
        : 0;

      // Calculate new users today
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const newUsersToday = usersData.filter(u => {
        const createdAt = new Date(u.created_at);
        return createdAt >= today;
      }).length;

      setStats({
        totalUsers,
        totalListeners,
        activeListeners,
        averageRating: averageRating.toFixed(1),
        approvedListeners,
        newUsersToday,
      });

      // Real-time status from actual data
      setRealTimeStatus({
        onlineListeners: activeListeners,
        totalCalls: listenersData.reduce((sum, l) => sum + (l.total_calls || 0), 0),
        systemHealth: 'healthy',
        lastUpdated: new Date()
      });

      // Generate user growth data from actual created_at dates
      const userGrowthMap = {};
      const monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      
      // Get last 6 months
      const now = new Date();
      for (let i = 5; i >= 0; i--) {
        const date = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const key = `${date.getFullYear()}-${date.getMonth()}`;
        userGrowthMap[key] = { 
          month: monthNames[date.getMonth()], 
          users: 0, 
          listeners: 0,
          year: date.getFullYear()
        };
      }

      // Count users per month
      usersData.forEach(u => {
        if (u.created_at) {
          const date = new Date(u.created_at);
          const key = `${date.getFullYear()}-${date.getMonth()}`;
          if (userGrowthMap[key]) {
            userGrowthMap[key].users++;
          }
        }
      });

      // Count listeners per month
      listenersData.forEach(l => {
        if (l.created_at) {
          const date = new Date(l.created_at);
          const key = `${date.getFullYear()}-${date.getMonth()}`;
          if (userGrowthMap[key]) {
            userGrowthMap[key].listeners++;
          }
        }
      });

      const userGrowth = Object.values(userGrowthMap);

      // Listener performance - top 5 by rating
      const listenerPerformance = listenersData
        .filter(l => l.professional_name || l.name)
        .slice(0, 6)
        .map(l => ({
          name: (l.professional_name || l.name || 'Unknown').slice(0, 10),
          calls: l.total_calls || 0,
          rating: parseFloat(l.average_rating || 0).toFixed(1),
          earnings: l.total_earnings || 0
        }));

      // Rating distribution from actual listener ratings
      const ratingBuckets = { '0-2': 0, '2-3': 0, '3-4': 0, '4-5': 0 };
      listenersData.forEach(l => {
        const rating = parseFloat(l.average_rating || 0);
        if (rating < 2) ratingBuckets['0-2']++;
        else if (rating < 3) ratingBuckets['2-3']++;
        else if (rating < 4) ratingBuckets['3-4']++;
        else ratingBuckets['4-5']++;
      });

      const ratingDistribution = Object.entries(ratingBuckets).map(([rating, count]) => ({
        rating,
        count
      }));

      // Users by location
      const locationMap = {};
      usersData.forEach(u => {
        const location = u.city || u.country || 'Unknown';
        locationMap[location] = (locationMap[location] || 0) + 1;
      });
      const usersByLocation = Object.entries(locationMap)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 5)
        .map(([location, count]) => ({ location, count }));

      // Account types distribution
      const accountTypeMap = {};
      usersData.forEach(u => {
        const type = u.account_type || 'user';
        accountTypeMap[type] = (accountTypeMap[type] || 0) + 1;
      });
      const accountTypes = Object.entries(accountTypeMap).map(([type, count]) => ({
        type: type.charAt(0).toUpperCase() + type.slice(1),
        count
      }));

      setChartData({
        userGrowth,
        listenerPerformance,
        ratingDistribution,
        usersByLocation,
        accountTypes
      });

      // Recent activities from actual data
      const activities = [];
      
      // Get recent user signups
      const recentUsers = [...usersData]
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, 3);
      
      recentUsers.forEach(u => {
        activities.push({
          id: `user-${u.user_id}`,
          type: 'user_signup',
          message: `New user registered: ${u.display_name || u.email || 'Anonymous'}`,
          timestamp: new Date(u.created_at),
          icon: UserPlus
        });
      });

      // Get recent listener registrations
      const recentListeners = [...listenersData]
        .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
        .slice(0, 2);
      
      recentListeners.forEach(l => {
        activities.push({
          id: `listener-${l.listener_id}`,
          type: 'listener_registration',
          message: `New listener joined: ${l.professional_name || l.name || 'Unknown'}`,
          timestamp: new Date(l.created_at),
          icon: Headphones
        });
      });

      // Sort all activities by timestamp
      activities.sort((a, b) => b.timestamp - a.timestamp);
      setRecentActivities(activities.slice(0, 5));
      setLastRefresh(new Date());

    } catch (error) {
      setError('Failed to fetch dashboard data');
      console.error('Error fetching stats:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchStats();

    // Auto-refresh every 30 seconds
    const refreshInterval = setInterval(fetchStats, 30000);

    return () => clearInterval(refreshInterval);
  }, [fetchStats]);

  const formatTimeAgo = (date) => {
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return `${diffMins} min ago`;
    if (diffHours < 24) return `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
    return `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
  };

  const COLORS = ['#3b82f6', '#10b981', '#f59e0b', '#ef4444', '#8b5cf6', '#ec4899'];

  if (loading)
    return (
      <div className="w-full min-h-[80vh] bg-gray-50 dark:bg-gray-900 py-8 px-4">
        <div className="max-w-7xl mx-auto">
          <h1 className="text-3xl font-bold text-gray-800 dark:text-white mb-8 text-center">Admin Dashboard</h1>
          <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-4 gap-6 mb-8">
            {[...Array(4)].map((_, i) => (
              <div key={i} className="bg-white dark:bg-gray-800 shadow-lg rounded-xl p-6 animate-pulse">
                <div className="flex items-center justify-center mb-4">
                  <div className="w-12 h-12 bg-gray-300 dark:bg-gray-600 rounded-full"></div>
                </div>
                <div className="h-4 bg-gray-300 dark:bg-gray-600 rounded mb-2"></div>
                <div className="h-8 bg-gray-300 dark:bg-gray-600 rounded"></div>
              </div>
            ))}
          </div>
        </div>
      </div>
    );

  if (error)
    return (
      <div className="flex flex-col items-center justify-center min-h-[40vh] gap-4">
        <div className="text-lg text-red-500 font-semibold">{error}</div>
        <button 
          onClick={fetchStats}
          className="flex items-center gap-2 px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
        >
          <RefreshCw className="w-4 h-4" />
          Retry
        </button>
      </div>
    );


  return (
    <div className="w-full min-h-[80vh] bg-gray-50 dark:bg-gray-900 py-8 px-4">
      <div className="max-w-7xl mx-auto">
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-12">
          <div>
            <div className="flex items-center gap-3 mb-2">
              <div className="w-12 h-12 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg">
                <BarChart3 className="w-7 h-7 text-white" />
              </div>
              <h1 className="text-4xl font-extrabold bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 dark:from-white dark:via-gray-200 dark:to-white bg-clip-text text-transparent">Admin Dashboard</h1>
            </div>
            <p className="text-gray-600 dark:text-gray-400 mt-2 flex items-center gap-2 text-sm">
              <Clock className="w-4 h-4" />
              Last updated: <span className="font-semibold">{formatTimeAgo(lastRefresh)}</span>
            </p>
          </div>
          <button
            onClick={fetchStats}
            disabled={loading}
            className="mt-4 sm:mt-0 flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-blue-500 to-blue-600 text-white rounded-xl hover:from-blue-600 hover:to-blue-700 transition-all shadow-lg hover:shadow-xl disabled:opacity-50 disabled:cursor-not-allowed font-semibold"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
            Refresh Data
          </button>
        </div>

        {/* Statistics Cards */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6 gap-6 mb-10">
          <div className="group relative bg-gradient-to-br from-blue-500 via-blue-600 to-blue-700 shadow-xl rounded-2xl p-6 flex flex-col items-center text-white hover:scale-105 hover:shadow-2xl transition-all duration-300 cursor-pointer overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-blue-400/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
            <div className="relative z-10">
              <div className="bg-white/20 backdrop-blur-sm p-3 rounded-xl mb-3">
                <Users className="w-10 h-10" strokeWidth={2.5} />
              </div>
              <span className="text-xs font-semibold uppercase tracking-wider opacity-90 mb-2 block">Total Users</span>
              <span className="text-3xl font-extrabold">{stats.totalUsers}</span>
            </div>
          </div>
          <div className="group relative bg-gradient-to-br from-green-500 via-green-600 to-emerald-700 shadow-xl rounded-2xl p-6 flex flex-col items-center text-white hover:scale-105 hover:shadow-2xl transition-all duration-300 cursor-pointer overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-green-400/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
            <div className="relative z-10">
              <div className="bg-white/20 backdrop-blur-sm p-3 rounded-xl mb-3">
                <Headphones className="w-10 h-10" strokeWidth={2.5} />
              </div>
              <span className="text-xs font-semibold uppercase tracking-wider opacity-90 mb-2 block">Total Listeners</span>
              <span className="text-3xl font-extrabold">{stats.totalListeners}</span>
            </div>
          </div>
          <div className="group relative bg-gradient-to-br from-yellow-500 via-orange-500 to-orange-600 shadow-xl rounded-2xl p-6 flex flex-col items-center text-white hover:scale-105 hover:shadow-2xl transition-all duration-300 cursor-pointer overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-yellow-400/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
            <div className="relative z-10">
              <div className="bg-white/20 backdrop-blur-sm p-3 rounded-xl mb-3 relative">
                <Activity className="w-10 h-10" strokeWidth={2.5} />
                <div className="absolute -top-1 -right-1 w-3 h-3 bg-green-400 rounded-full animate-pulse"></div>
              </div>
              <span className="text-xs font-semibold uppercase tracking-wider opacity-90 mb-2 block">Online Now</span>
              <span className="text-3xl font-extrabold">{stats.activeListeners}</span>
            </div>
          </div>
          <div className="group relative bg-gradient-to-br from-purple-500 via-purple-600 to-indigo-700 shadow-xl rounded-2xl p-6 flex flex-col items-center text-white hover:scale-105 hover:shadow-2xl transition-all duration-300 cursor-pointer overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-purple-400/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
            <div className="relative z-10">
              <div className="bg-white/20 backdrop-blur-sm p-3 rounded-xl mb-3">
                <Star className="w-10 h-10" strokeWidth={2.5} fill="currentColor" />
              </div>
              <span className="text-xs font-semibold uppercase tracking-wider opacity-90 mb-2 block">Avg Rating</span>
              <span className="text-3xl font-extrabold">{stats.averageRating} ⭐</span>
            </div>
          </div>
          <div className="group relative bg-gradient-to-br from-emerald-500 via-teal-600 to-cyan-700 shadow-xl rounded-2xl p-6 flex flex-col items-center text-white hover:scale-105 hover:shadow-2xl transition-all duration-300 cursor-pointer overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-emerald-400/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
            <div className="relative z-10">
              <div className="bg-white/20 backdrop-blur-sm p-3 rounded-xl mb-3">
                <UserCheck className="w-10 h-10" strokeWidth={2.5} />
              </div>
              <span className="text-xs font-semibold uppercase tracking-wider opacity-90 mb-2 block">Approved</span>
              <span className="text-3xl font-extrabold">{stats.approvedListeners}</span>
            </div>
          </div>
          <div className="group relative bg-gradient-to-br from-pink-500 via-rose-600 to-red-600 shadow-xl rounded-2xl p-6 flex flex-col items-center text-white hover:scale-105 hover:shadow-2xl transition-all duration-300 cursor-pointer overflow-hidden">
            <div className="absolute inset-0 bg-gradient-to-br from-pink-400/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity"></div>
            <div className="relative z-10">
              <div className="bg-white/20 backdrop-blur-sm p-3 rounded-xl mb-3">
                <UserPlus className="w-10 h-10" strokeWidth={2.5} />
              </div>
              <span className="text-xs font-semibold uppercase tracking-wider opacity-90 mb-2 block">New Today</span>
              <span className="text-3xl font-extrabold">{stats.newUsersToday}</span>
            </div>
          </div>
        </div>

        {/* Real-time Status Indicator */}
        <div className="bg-white dark:bg-gray-800 shadow-2xl rounded-2xl p-8 mb-10 border border-gray-100 dark:border-gray-700">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-2xl font-bold text-gray-800 dark:text-white flex items-center">
              <div className="bg-gradient-to-br from-green-500 to-emerald-600 p-2 rounded-xl mr-3">
                <ActivityIcon className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              Real-time Status
            </h2>
            <div className="flex items-center gap-2 bg-green-50 dark:bg-green-900/20 px-4 py-2 rounded-full">
              <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              <span className="text-xs text-gray-600 dark:text-gray-400 font-semibold">
                Auto-refresh: 30s
              </span>
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="group flex items-center p-6 bg-gradient-to-br from-blue-50 to-blue-100/50 dark:from-blue-900/20 dark:to-blue-800/10 rounded-xl border border-blue-200 dark:border-blue-800/30 hover:shadow-lg transition-all">
              <div className="bg-blue-500 p-3 rounded-xl mr-4 shadow-lg">
                <Activity className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              <div className="flex-1">
                <span className="text-gray-600 dark:text-gray-400 text-sm font-semibold block mb-1">Online Listeners</span>
                <p className="text-3xl font-extrabold text-blue-600 dark:text-blue-400">{realTimeStatus.onlineListeners}</p>
              </div>
              <div className="w-3 h-3 bg-blue-500 rounded-full animate-pulse"></div>
            </div>
            <div className="group flex items-center p-6 bg-gradient-to-br from-green-50 to-emerald-100/50 dark:from-green-900/20 dark:to-emerald-800/10 rounded-xl border border-green-200 dark:border-green-800/30 hover:shadow-lg transition-all">
              <div className="bg-green-500 p-3 rounded-xl mr-4 shadow-lg">
                <Phone className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              <div className="flex-1">
                <span className="text-gray-600 dark:text-gray-400 text-sm font-semibold block mb-1">Total Calls Made</span>
                <p className="text-3xl font-extrabold text-green-600 dark:text-green-400">{realTimeStatus.totalCalls}</p>
              </div>
              <div className="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
            </div>
            <div className="group flex items-center p-6 bg-gradient-to-br from-emerald-50 to-teal-100/50 dark:from-emerald-900/20 dark:to-teal-800/10 rounded-xl border border-emerald-200 dark:border-emerald-800/30 hover:shadow-lg transition-all">
              <div className={`${realTimeStatus.systemHealth === 'healthy' ? 'bg-green-500' : 'bg-red-500'} p-3 rounded-xl mr-4 shadow-lg`}>
                {realTimeStatus.systemHealth === 'healthy' ? (
                  <Wifi className="w-6 h-6 text-white" strokeWidth={2.5} />
                ) : (
                  <WifiOff className="w-6 h-6 text-white" strokeWidth={2.5} />
                )}
              </div>
              <div className="flex-1">
                <span className="text-gray-600 dark:text-gray-400 text-sm font-semibold block mb-1">System Health</span>
                <p className={`text-2xl font-extrabold ${realTimeStatus.systemHealth === 'healthy' ? 'text-green-600 dark:text-green-400' : 'text-red-600 dark:text-red-400'}`}>
                  {realTimeStatus.systemHealth === 'healthy' ? '✓ Operational' : '⚠ Warning'}
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* Charts Section */}
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-10">
          <div className="bg-white dark:bg-gray-800 shadow-2xl rounded-2xl p-8 border-2 border-gray-100 dark:border-gray-700 hover:border-blue-200 dark:hover:border-blue-800/40 transition-all">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-gradient-to-br from-blue-500 to-cyan-600 p-3 rounded-xl shadow-lg">
                <TrendingUp className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-800 dark:text-white">
                  User & Listener Growth
                </h2>
                <p className="text-sm text-gray-500 dark:text-gray-400">Last 6 Months</p>
              </div>
            </div>
            {chartData.userGrowth.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <AreaChart data={chartData.userGrowth}>
                  <defs>
                    <linearGradient id="colorUsers" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#3b82f6" stopOpacity={0}/>
                    </linearGradient>
                    <linearGradient id="colorListeners" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor="#10b981" stopOpacity={0.3}/>
                      <stop offset="95%" stopColor="#10b981" stopOpacity={0}/>
                    </linearGradient>
                  </defs>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis dataKey="month" stroke="#9ca3af" />
                  <YAxis stroke="#9ca3af" />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#1f2937', border: 'none', borderRadius: '8px' }}
                    labelStyle={{ color: '#fff' }}
                  />
                  <Legend />
                  <Area type="monotone" dataKey="users" stroke="#3b82f6" fill="url(#colorUsers)" strokeWidth={2} name="Users" />
                  <Area type="monotone" dataKey="listeners" stroke="#10b981" fill="url(#colorListeners)" strokeWidth={2} name="Listeners" />
                </AreaChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[300px] flex items-center justify-center text-gray-500">No data available</div>
            )}
          </div>

          <div className="bg-white dark:bg-gray-800 shadow-2xl rounded-2xl p-8 border-2 border-gray-100 dark:border-gray-700 hover:border-green-200 dark:hover:border-green-800/40 transition-all">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-gradient-to-br from-green-500 to-emerald-600 p-3 rounded-xl shadow-lg">
                <BarChart3 className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-800 dark:text-white">
                  Top Listeners by Calls
                </h2>
                <p className="text-sm text-gray-500 dark:text-gray-400">Most Active</p>
              </div>
            </div>
            {chartData.listenerPerformance.length > 0 ? (
              <ResponsiveContainer width="100%" height={300}>
                <BarChart data={chartData.listenerPerformance}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis dataKey="name" stroke="#9ca3af" fontSize={12} />
                  <YAxis stroke="#9ca3af" />
                  <Tooltip 
                    contentStyle={{ backgroundColor: '#1f2937', border: 'none', borderRadius: '8px' }}
                    labelStyle={{ color: '#fff' }}
                  />
                  <Bar dataKey="calls" fill="#10b981" radius={[4, 4, 0, 0]} name="Total Calls" />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[300px] flex items-center justify-center text-gray-500">No listener data available</div>
            )}
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-10">
          <div className="bg-white dark:bg-gray-800 shadow-2xl rounded-2xl p-8 border-2 border-gray-100 dark:border-gray-700 hover:border-purple-200 dark:hover:border-purple-800/40 transition-all">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-gradient-to-br from-purple-500 to-indigo-600 p-3 rounded-xl shadow-lg">
                <PieChart className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-800 dark:text-white">
                  Rating Distribution
                </h2>
                <p className="text-sm text-gray-500 dark:text-gray-400">Quality Metrics</p>
              </div>
            </div>
            {chartData.ratingDistribution.some(d => d.count > 0) ? (
              <ResponsiveContainer width="100%" height={250}>
                <RechartsPieChart>
                  <Pie
                    data={chartData.ratingDistribution}
                    cx="50%"
                    cy="50%"
                    labelLine={false}
                    label={({ rating, percent }) => percent > 0 ? `${rating}: ${(percent * 100).toFixed(0)}%` : ''}
                    outerRadius={80}
                    fill="#8884d8"
                    dataKey="count"
                  >
                    {chartData.ratingDistribution.map((entry, index) => (
                      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                  <Legend />
                </RechartsPieChart>
              </ResponsiveContainer>
            ) : (
              <div className="h-[250px] flex items-center justify-center text-gray-500">No rating data</div>
            )}
          </div>

          <div className="bg-white dark:bg-gray-800 shadow-2xl rounded-2xl p-8 border-2 border-gray-100 dark:border-gray-700 hover:border-red-200 dark:hover:border-red-800/40 transition-all">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-gradient-to-br from-red-500 to-orange-600 p-3 rounded-xl shadow-lg">
                <MapPin className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-800 dark:text-white">
                  Users by Location
                </h2>
                <p className="text-sm text-gray-500 dark:text-gray-400">Top 5 Cities</p>
              </div>
            </div>
            {chartData.usersByLocation.length > 0 ? (
              <div className="space-y-4">
                {chartData.usersByLocation.map((item, index) => (
                  <div key={item.location} className="flex items-center justify-between p-3 bg-gradient-to-r from-gray-50 to-transparent dark:from-gray-700/30 dark:to-transparent rounded-xl hover:from-gray-100 dark:hover:from-gray-700/50 transition-all">
                    <div className="flex items-center gap-3">
                      <div className="w-8 h-8 rounded-xl flex items-center justify-center font-bold text-white shadow-lg" style={{ backgroundColor: COLORS[index % COLORS.length] }}>
                        {index + 1}
                      </div>
                      <span className="text-gray-700 dark:text-gray-300 font-semibold">{item.location}</span>
                    </div>
                    <span className="font-extrabold text-xl text-gray-900 dark:text-white">{item.count}</span>
                  </div>
                ))}
              </div>
            ) : (
              <div className="h-[200px] flex items-center justify-center text-gray-500">No location data</div>
            )}
          </div>

          {/* Recent Activity Timeline */}
          <div className="bg-white dark:bg-gray-800 shadow-2xl rounded-2xl p-8 border-2 border-gray-100 dark:border-gray-700 hover:border-indigo-200 dark:hover:border-indigo-800/40 transition-all">
            <div className="flex items-center gap-3 mb-6">
              <div className="bg-gradient-to-br from-indigo-500 to-purple-600 p-3 rounded-xl shadow-lg">
                <Clock className="w-6 h-6 text-white" strokeWidth={2.5} />
              </div>
              <div>
                <h2 className="text-xl font-bold text-gray-800 dark:text-white">Recent Activity</h2>
                <p className="text-sm text-gray-500 dark:text-gray-400">Latest Updates</p>
              </div>
            </div>
            {recentActivities.length > 0 ? (
              <div className="space-y-4">
                {recentActivities.map((activity) => (
                  <div key={activity.id} className="flex items-start space-x-4 p-4 bg-gradient-to-r from-indigo-50 via-purple-50 to-transparent dark:from-indigo-900/20 dark:via-purple-900/15 dark:to-transparent rounded-xl border border-indigo-100 dark:border-indigo-800/30 hover:border-indigo-200 dark:hover:border-indigo-700/50 transition-all">
                    <div className="flex-shrink-0 w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl flex items-center justify-center shadow-lg">
                      <activity.icon className="w-5 h-5 text-white" strokeWidth={2.5} />
                    </div>
                    <div className="flex-1 min-w-0">
                      <p className="text-sm text-gray-900 dark:text-white font-medium">{activity.message}</p>
                      <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
                        {formatTimeAgo(activity.timestamp)}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="h-[200px] flex items-center justify-center text-gray-500">No recent activities</div>
            )}
          </div>
        </div>

        {/* Quick Actions Panel */}
        <div className="fixed bottom-6 right-6 flex flex-col space-y-3">
          <button 
            onClick={fetchStats}
            className="bg-blue-500 hover:bg-blue-600 text-white p-3 rounded-full shadow-lg transition-colors duration-200 flex items-center justify-center"
            title="Refresh Data"
          >
            <RefreshCw className="w-6 h-6" />
          </button>
          <button className="bg-green-500 hover:bg-green-600 text-white p-3 rounded-full shadow-lg transition-colors duration-200 flex items-center justify-center" title="Notifications">
            <Bell className="w-6 h-6" />
          </button>
          <button className="bg-purple-500 hover:bg-purple-600 text-white p-3 rounded-full shadow-lg transition-colors duration-200 flex items-center justify-center" title="Export Report">
            <Download className="w-6 h-6" />
          </button>
        </div>
      </div>
    </div>
  );
};

export default AdminDashboard;