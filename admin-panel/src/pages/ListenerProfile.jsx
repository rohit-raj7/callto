import React, { useState, useEffect, useRef } from 'react';
import { useParams } from 'react-router-dom';
import { getListenerById } from '../services/api';
import { Calendar, momentLocalizer } from 'react-big-calendar';
import moment from 'moment';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar, PieChart, Pie, Cell } from 'recharts';
import { User, Star, Clock, DollarSign, Calendar as CalendarIcon, MessageSquare, Shield, CheckCircle, XCircle, AlertTriangle, Filter, Search, ChevronLeft, ChevronRight, BarChart as BarChartIcon } from 'lucide-react';
import 'react-big-calendar/lib/css/react-big-calendar.css';

const localizer = momentLocalizer(moment);

// Import socket.io-client (ensure it's installed in admin-panel)
import io from 'socket.io-client';

// Use your deployed backend URL (API + Socket.IO are together)
// Use import.meta.env for Vite compatibility
const SOCKET_URL = import.meta.env.VITE_SOCKET_URL || 'https://callto-4.onrender.com';

const ListenerProfile = () => {
  const { listener_id } = useParams();
  const [listener, setListener] = useState(null);
  const [isOnline, setIsOnline] = useState(false);
  const [lastStatusChange, setLastStatusChange] = useState(Date.now());
  const socketRef = useRef(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [retryCount, setRetryCount] = useState(0);
  const [activeTab, setActiveTab] = useState('overview');
  const [reviews, setReviews] = useState([]);
  const [reviewsPage, setReviewsPage] = useState(1);
  const [reviewsFilter, setReviewsFilter] = useState({ rating: 'all', date: 'all' });
  const [availability, setAvailability] = useState([]);
  const [performanceData, setPerformanceData] = useState({
    callDuration: [],
    earnings: [],
    ratings: []
  });
  const [showConfirmModal, setShowConfirmModal] = useState(false);
  const [confirmAction, setConfirmAction] = useState(null);
  const [actionLoading, setActionLoading] = useState(false);

  const MAX_RETRY_ATTEMPTS = 3;
  const RETRY_DELAY = 2000;

  useEffect(() => {
    const fetchListenerData = async (attemptNumber = 0) => {
      try {
        setLoading(true);
        setError(null);
        
        // Add timeout to the API call
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), 10000); // 10 second timeout
        
        const res = await getListenerById(listener_id, { signal: controller.signal });
        clearTimeout(timeoutId);
        
        // Validate response
        if (!res || !res.data) {
          throw new Error('Invalid response from server');
        }
        
        setListener(res.data);
        setIsOnline(res.data.is_online || false);
        setRetryCount(0); // Reset retry count on success
        
        // Mock data (keep your existing mock data)
        setReviews([
          { id: 1, user: 'John D.', rating: 5, comment: 'Amazing listener, very helpful!', date: '2024-01-20', sentiment: 'positive' },
          { id: 2, user: 'Sarah M.', rating: 4, comment: 'Good session, but could be more engaging.', date: '2024-01-18', sentiment: 'neutral' },
          { id: 3, user: 'Mike R.', rating: 5, comment: 'Life-changing conversation!', date: '2024-01-15', sentiment: 'positive' },
          { id: 4, user: 'Emma L.', rating: 3, comment: 'Okay experience, nothing special.', date: '2024-01-12', sentiment: 'neutral' },
          { id: 5, user: 'David K.', rating: 5, comment: 'Exceptional support and understanding.', date: '2024-01-10', sentiment: 'positive' },
        ]);
        setPerformanceData({
          callDuration: [
            { month: 'Jan', duration: 45 },
            { month: 'Feb', duration: 52 },
            { month: 'Mar', duration: 48 },
            { month: 'Apr', duration: 61 },
            { month: 'May', duration: 55 },
            { month: 'Jun', duration: 58 },
          ],
          earnings: [
            { month: 'Jan', amount: 1200 },
            { month: 'Feb', amount: 1450 },
            { month: 'Mar', amount: 1350 },
            { month: 'Apr', amount: 1680 },
            { month: 'May', amount: 1520 },
            { month: 'Jun', amount: 1750 },
          ],
          ratings: [
            { month: 'Jan', rating: 4.2 },
            { month: 'Feb', rating: 4.5 },
            { month: 'Mar', rating: 4.3 },
            { month: 'Apr', rating: 4.7 },
            { month: 'May', rating: 4.6 },
            { month: 'Jun', rating: 4.8 },
          ]
        });
        setAvailability([
          {
            title: 'Available',
            start: new Date(2024, 0, 22, 9, 0),
            end: new Date(2024, 0, 22, 17, 0),
            resource: { type: 'available' }
          },
          {
            title: 'Busy',
            start: new Date(2024, 0, 23, 10, 0),
            end: new Date(2024, 0, 23, 12, 0),
            resource: { type: 'busy' }
          },
        ]);
      } catch (error) {
        console.error('Error fetching listener:', error);
        
        // Handle different error types
        let errorMessage = 'Failed to fetch listener profile';
        
        if (error.name === 'AbortError') {
          errorMessage = 'Request timeout - please try again';
        } else if (error.response) {
          // Server responded with error status
          if (error.response.status === 404) {
            errorMessage = 'Listener not found';
          } else if (error.response.status === 500) {
            errorMessage = 'Server error - please try again later';
          } else if (error.response.status === 401 || error.response.status === 403) {
            errorMessage = 'Unauthorized - please login again';
          } else {
            errorMessage = `Error: ${error.response.data?.message || error.response.statusText}`;
          }
        } else if (error.request) {
          // Request made but no response received
          errorMessage = 'Network error - please check your connection';
        } else if (error.message) {
          errorMessage = error.message;
        }
        
        setError(errorMessage);
        
        // Retry logic
        if (attemptNumber < MAX_RETRY_ATTEMPTS && error.name !== 'AbortError') {
          setRetryCount(attemptNumber + 1);
          setTimeout(() => {
            fetchListenerData(attemptNumber + 1);
          }, RETRY_DELAY * (attemptNumber + 1)); // Exponential backoff
        }
      } finally {
        setLoading(false);
      }
    };
    
    if (listener_id) {
      fetchListenerData();
    }
  }, [listener_id]);

  // Real-time presence subscription
  useEffect(() => {
    if (!listener_id) return;
    
    // Initialize socket connection
    if (!socketRef.current) {
      socketRef.current = io(SOCKET_URL, {
        transports: ['websocket', 'polling'],
        reconnection: true,
        reconnectionDelay: 1000,
        reconnectionAttempts: 5,
      });
      
      // Handle connection errors
      socketRef.current.on('connect_error', (error) => {
        console.error('Socket connection error:', error);
      });
      
      socketRef.current.on('connect', () => {
        console.log('Socket connected');
      });
    }
    
    const socket = socketRef.current;

    // Listen for presence events
    const handleOnline = (data) => {
      if (data.userId === listener_id) {
        setIsOnline(true);
        setLastStatusChange(Date.now());
      }
    };
    const handleOffline = (data) => {
      if (data.userId === listener_id) {
        setIsOnline(false);
        setLastStatusChange(Date.now());
      }
    };
    socket.on('user:online', handleOnline);
    socket.on('user:offline', handleOffline);

    // Cleanup
    return () => {
      socket.off('user:online', handleOnline);
      socket.off('user:offline', handleOffline);
    };
  }, [listener_id]);

  // Cleanup socket on unmount
  useEffect(() => {
    return () => {
      if (socketRef.current) {
        socketRef.current.disconnect();
        socketRef.current = null;
      }
    };
  }, []);

  const handleAction = (action) => {
    setConfirmAction(action);
    setShowConfirmModal(true);
  };

  const confirmActionHandler = async () => {
    setActionLoading(true);
    try {
      // Mock API calls - replace with actual API calls
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      if (confirmAction === 'suspend') {
        setListener(prev => ({ ...prev, is_suspended: !prev.is_suspended }));
      } else if (confirmAction === 'verify') {
        setListener(prev => ({ ...prev, is_verified: true }));
      }
      
      setShowConfirmModal(false);
      setConfirmAction(null);
    } catch (error) {
      console.error('Action failed:', error);
      setError('Failed to perform action - please try again');
    } finally {
      setActionLoading(false);
    }
  };

  const handleRetry = () => {
    setError(null);
    setLoading(true);
    window.location.reload();
  };

  const filteredReviews = reviews.filter(review => {
    if (reviewsFilter.rating !== 'all' && review.rating !== parseInt(reviewsFilter.rating)) return false;
    if (reviewsFilter.date === 'recent' && new Date(review.date) < new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)) return false;
    return true;
  });

  const renderStars = (rating) => {
    return [...Array(5)].map((_, i) => (
      <Star key={i} className={`w-4 h-4 ${i < rating ? 'text-yellow-400 fill-current' : 'text-gray-300'}`} />
    ));
  };

  const eventStyleGetter = (event) => {
    let backgroundColor = '#10b981'; // green for available
    if (event.resource?.type === 'busy') {
      backgroundColor = '#ef4444'; // red for busy
    }
    return {
      style: {
        backgroundColor,
        borderRadius: '4px',
        opacity: 0.8,
        color: 'white',
        border: '0px',
        display: 'block'
      }
    };
  };

  if (loading) return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-7xl mx-auto px-4">
        <div className="animate-pulse">
          <div className="h-8 bg-gray-300 rounded w-1/4 mb-6"></div>
          <div className="bg-white rounded-lg shadow-md p-6">
            <div className="flex space-x-6">
              <div className="w-32 h-32 bg-gray-300 rounded-full"></div>
              <div className="flex-1 space-y-3">
                <div className="h-6 bg-gray-300 rounded w-1/3"></div>
                <div className="h-4 bg-gray-300 rounded w-1/2"></div>
                <div className="h-4 bg-gray-300 rounded w-2/3"></div>
                <div className="h-4 bg-gray-300 rounded w-1/4"></div>
              </div>
            </div>
          </div>
          {retryCount > 0 && (
            <div className="mt-4 text-center text-sm text-gray-600">
              Retrying... (Attempt {retryCount} of {MAX_RETRY_ATTEMPTS})
            </div>
          )}
        </div>
      </div>
    </div>
  );

  if (error) return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="text-center max-w-md px-4">
        <XCircle className="w-16 h-16 text-red-500 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Error Loading Profile</h2>
        <p className="text-gray-600 mb-6">{error}</p>
        <div className="flex flex-col sm:flex-row gap-3 justify-center">
          <button
            onClick={handleRetry}
            className="px-6 py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-lg font-semibold transition-colors"
          >
            Try Again
          </button>
          <button
            onClick={() => window.history.back()}
            className="px-6 py-3 bg-gray-200 hover:bg-gray-300 text-gray-700 rounded-lg font-semibold transition-colors"
          >
            Go Back
          </button>
        </div>
        {retryCount > 0 && (
          <p className="mt-4 text-sm text-gray-500">
            Attempted {retryCount} {retryCount === 1 ? 'retry' : 'retries'}
          </p>
        )}
      </div>
    </div>
  );

  if (!listener) return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <div className="text-center">
        <User className="w-16 h-16 text-gray-400 mx-auto mb-4" />
        <h2 className="text-2xl font-bold text-gray-900 mb-2">Listener Not Found</h2>
        <p className="text-gray-600 mb-6">The requested listener profile could not be found.</p>
        <button
          onClick={() => window.history.back()}
          className="px-6 py-3 bg-blue-500 hover:bg-blue-600 text-white rounded-lg font-semibold transition-colors"
        >
          Go Back
        </button>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-gray-50 py-8">
      <div className="max-w-7xl mx-auto px-4">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">Listener Profile</h1>
          <p className="text-gray-600">Manage and monitor listener performance and details</p>
        </div>

        {/* Profile Header Card */}
        <div className="bg-white rounded-lg shadow-md p-6 mb-6">
          <div className="flex flex-col md:flex-row items-start space-y-4 md:space-y-0 md:space-x-6">
            <div className="relative">
              <img
                src={listener.avatar_url || '/default-avatar.png'}
                alt="Profile"
                className="w-32 h-32 rounded-full object-cover border-4 border-white shadow-lg"
                onError={(e) => {
                  e.target.src = 'https://ui-avatars.com/api/?name=' + encodeURIComponent(listener.professional_name || 'User') + '&size=128&background=random';
                }}
              />
              <div className={`absolute -bottom-2 -right-2 w-8 h-8 rounded-full flex items-center justify-center ${
                isOnline ? 'bg-green-500' : 'bg-red-500'
              }`}>
                <div className={`w-3 h-3 rounded-full ${isOnline ? 'bg-green-200' : 'bg-red-200'}`}></div>
              </div>
            </div>
            <div className="flex-1">
              <div className="flex items-center justify-between mb-4">
                <div>
                  <h2 className="text-2xl font-bold text-gray-900">{listener.professional_name}</h2>
                  <p className="text-gray-600">{listener.city}, {listener.country}</p>
                  <p className="text-xs text-gray-400 mt-1">
                    Status: {isOnline ? 'Online' : 'Offline'} • Updated: {new Date(lastStatusChange).toLocaleTimeString()}
                  </p>
                </div>
                <div className="flex space-x-2">
                  <button
                    onClick={() => handleAction('suspend')}
                    className={`px-4 py-2 rounded-lg font-semibold transition-colors ${
                      listener.is_suspended
                        ? 'bg-green-500 hover:bg-green-600 text-white'
                        : 'bg-red-500 hover:bg-red-600 text-white'
                    }`}
                  >
                    {listener.is_suspended ? 'Unsuspend' : 'Suspend'}
                  </button>
                  <button
                    onClick={() => handleAction('verify')}
                    className="px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg font-semibold transition-colors"
                    disabled={listener.is_verified}
                  >
                    {listener.is_verified ? 'Verified' : 'Verify'}
                  </button>
                  <button
                    onClick={() => handleAction('message')}
                    className="px-4 py-2 bg-purple-500 hover:bg-purple-600 text-white rounded-lg font-semibold transition-colors"
                  >
                    Send Message
                  </button>
                </div>
              </div>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div className="text-center">
                  <div className="text-2xl font-bold text-blue-600">{listener.average_rating?.toFixed(1) || 'N/A'}</div>
                  <div className="text-sm text-gray-600">Average Rating</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-green-600">{listener.total_calls || 0}</div>
                  <div className="text-sm text-gray-600">Total Calls</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-purple-600">₹{listener.total_earnings || 0}</div>
                  <div className="text-sm text-gray-600">Total Earnings</div>
                </div>
                <div className="text-center">
                  <div className="text-2xl font-bold text-orange-600">{listener.experience_years || 0}y</div>
                  <div className="text-sm text-gray-600">Experience</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        {/* Tabs */}
        <div className="bg-white rounded-lg shadow-md">
          <div className="border-b border-gray-200">
            <nav className="flex space-x-8 px-6 overflow-x-auto">
              {[
                { id: 'overview', label: 'Overview', icon: User },
                { id: 'performance', label: 'Performance', icon: BarChartIcon },
                { id: 'reviews', label: 'Reviews', icon: Star },
                { id: 'availability', label: 'Availability', icon: CalendarIcon },
                { id: 'payment', label: 'Payment Info', icon: DollarSign },
              ].map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`py-4 px-1 border-b-2 font-medium text-sm flex items-center space-x-2 whitespace-nowrap ${
                    activeTab === tab.id
                      ? 'border-blue-500 text-blue-600'
                      : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                  }`}
                >
                  <tab.icon className="w-4 h-4" />
                  <span>{tab.label}</span>
                </button>
              ))}
            </nav>
          </div>

          <div className="p-6">
            {/* Overview Tab */}
            {activeTab === 'overview' && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">Personal Information</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Age:</span>
                      <span className="font-medium">{listener.age}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Specialties:</span>
                      <span className="font-medium">{listener.specialties?.join(', ') || 'N/A'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Languages:</span>
                      <span className="font-medium">{listener.languages?.join(', ') || 'N/A'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Education:</span>
                      <span className="font-medium">{listener.education || 'N/A'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Certifications:</span>
                      <span className="font-medium">{listener.certifications || 'N/A'}</span>
                    </div>
                  </div>
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">Professional Details</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Rate per Minute:</span>
                      <span className="font-medium">₹{listener.rate_per_minute}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Experience:</span>
                      <span className="font-medium">{listener.experience_years} years</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Status:</span>
                      <span className={`px-2 py-1 rounded text-sm font-medium ${
                        isOnline ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'
                      }`}>
                        {isOnline ? 'Online' : 'Offline'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Verification:</span>
                      <span className={`px-2 py-1 rounded text-sm font-medium ${
                        listener.verification_status === 'approved' ? 'bg-green-100 text-green-800' 
                        : listener.verification_status === 'rejected' ? 'bg-red-100 text-red-800'
                        : listener.verification_status === 'reapplied' ? 'bg-orange-100 text-orange-800'
                        : 'bg-yellow-100 text-yellow-800'
                      }`}>
                        {listener.verification_status === 'approved' ? 'Verified' 
                        : listener.verification_status === 'rejected' ? 'Rejected'
                        : listener.verification_status === 'reapplied' ? 'Reapplied'
                        : 'Pending'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Account Status:</span>
                      <span className={`px-2 py-1 rounded text-sm font-medium ${
                        listener.is_suspended ? 'bg-red-100 text-red-800' : 'bg-green-100 text-green-800'
                      }`}>
                        {listener.is_suspended ? 'Suspended' : 'Active'}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            )}

            {/* Performance Tab */}
            {activeTab === 'performance' && (
              <div className="space-y-8">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">Call Duration Trends</h3>
                  <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={performanceData.callDuration}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip />
                      <Line type="monotone" dataKey="duration" stroke="#3b82f6" strokeWidth={2} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">Monthly Earnings</h3>
                  <ResponsiveContainer width="100%" height={300}>
                    <BarChart data={performanceData.earnings}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" />
                      <YAxis />
                      <Tooltip formatter={(value) => [`₹${value}`, 'Earnings']} />
                      <Bar dataKey="amount" fill="#10b981" />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">Rating History</h3>
                  <ResponsiveContainer width="100%" height={300}>
                    <LineChart data={performanceData.ratings}>
                      <CartesianGrid strokeDasharray="3 3" />
                      <XAxis dataKey="month" />
                      <YAxis domain={[0, 5]} />
                      <Tooltip />
                      <Line type="monotone" dataKey="rating" stroke="#f59e0b" strokeWidth={2} />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              </div>
            )}

            {/* Reviews Tab */}
            {activeTab === 'reviews' && (
              <div>
                <div className="flex justify-between items-center mb-6">
                  <h3 className="text-lg font-semibold text-gray-900">User Reviews</h3>
                  <div className="flex space-x-4">
                    <select
                      value={reviewsFilter.rating}
                      onChange={(e) => setReviewsFilter(prev => ({ ...prev, rating: e.target.value }))}
                      className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
                    >
                      <option value="all">All Ratings</option>
                      <option value="5">5 Stars</option>
                      <option value="4">4 Stars</option>
                      <option value="3">3 Stars</option>
                      <option value="2">2 Stars</option>
                      <option value="1">1 Star</option>
                    </select>
                    <select
                      value={reviewsFilter.date}
                      onChange={(e) => setReviewsFilter(prev => ({ ...prev, date: e.target.value }))}
                      className="px-3 py-2 border border-gray-300 rounded-lg text-sm"
                    >
                      <option value="all">All Time</option>
                      <option value="recent">Last 30 Days</option>
                    </select>
                  </div>
                </div>
                <div className="space-y-4">
                  {filteredReviews.map((review) => (
                    <div key={review.id} className="border border-gray-200 rounded-lg p-4">
                      <div className="flex items-center justify-between mb-2">
                        <div className="flex items-center space-x-2">
                          <span className="font-medium text-gray-900">{review.user}</span>
                          <div className="flex">{renderStars(review.rating)}</div>
                        </div>
                        <span className="text-sm text-gray-500">{review.date}</span>
                      </div>
                      <p className="text-gray-700">{review.comment}</p>
                      <div className="mt-2">
                        <span className={`px-2 py-1 rounded text-xs font-medium ${
                          review.sentiment === 'positive' ? 'bg-green-100 text-green-800' :
                          review.sentiment === 'negative' ? 'bg-red-100 text-red-800' :
                          'bg-yellow-100 text-yellow-800'
                        }`}>
                          {review.sentiment}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
                <div className="flex justify-between items-center mt-6">
                  <button
                    onClick={() => setReviewsPage(prev => Math.max(1, prev - 1))}
                    disabled={reviewsPage === 1}
                    className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                  >
                    Previous
                  </button>
                  <span className="text-sm text-gray-600">Page {reviewsPage} of 3</span>
                  <button
                    onClick={() => setReviewsPage(prev => prev + 1)}
                    disabled={reviewsPage === 3}
                    className="px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium disabled:opacity-50 disabled:cursor-not-allowed hover:bg-gray-50"
                  >
                    Next
                  </button>
                </div>
              </div>
            )}

            {/* Availability Tab */}
            {activeTab === 'availability' && (
              <div>
                <h3 className="text-lg font-semibold text-gray-900 mb-4">Weekly Availability Calendar</h3>
                <div className="h-96">
                  <Calendar
                    localizer={localizer}
                    events={availability}
                    startAccessor="start"
                    endAccessor="end"
                    style={{ height: '100%' }}
                    eventPropGetter={eventStyleGetter}
                    views={['week', 'day']}
                    defaultView="week"
                    min={new Date(2024, 0, 1, 6, 0)}
                    max={new Date(2024, 0, 1, 22, 0)}
                  />
                </div>
                <div className="mt-4 flex space-x-4">
                  <div className="flex items-center">
                    <div className="w-4 h-4 bg-green-500 rounded mr-2"></div>
                    <span className="text-sm text-gray-600">Available</span>
                  </div>
                  <div className="flex items-center">
                    <div className="w-4 h-4 bg-red-500 rounded mr-2"></div>
                    <span className="text-sm text-gray-600">Busy</span>
                  </div>
                </div>
              </div>
            )}

            {/* Payment Info Tab */}
            {activeTab === 'payment' && (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">Payment Details</h3>
                  <div className="space-y-3">
                    <div className="flex justify-between">
                      <span className="text-gray-600">Payment Method:</span>
                      <span className="font-medium">{listener.payment_method || 'Bank Transfer'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Account Number:</span>
                      <span className="font-medium">****{listener.account_last4 || '1234'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Monthly Earnings:</span>
                      <span className="font-medium">₹{listener.monthly_earnings || '1,750'}</span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-gray-600">Pending Payout:</span>
                      <span className="font-medium">₹{listener.pending_payout || '350'}</span>
                    </div>
                  </div>
                </div>
                <div>
                  <h3 className="text-lg font-semibold text-gray-900 mb-4">Payout History</h3>
                  <div className="space-y-2">
                    <div className="flex justify-between items-center py-2 border-b border-gray-200">
                      <span className="text-sm text-gray-600">January 2024</span>
                      <span className="font-medium">₹1,200</span>
                    </div>
                    <div className="flex justify-between items-center py-2 border-b border-gray-200">
                      <span className="text-sm text-gray-600">December 2023</span>
                      <span className="font-medium">₹1,450</span>
                    </div>
                    <div className="flex justify-between items-center py-2 border-b border-gray-200">
                      <span className="text-sm text-gray-600">November 2023</span>
                      <span className="font-medium">₹1,350</span>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Confirmation Modal */}
        {showConfirmModal && (
          <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
            <div className="bg-white rounded-lg p-6 max-w-md w-full mx-4">
              <div className="flex items-center mb-4">
                <AlertTriangle className="w-6 h-6 text-yellow-500 mr-3" />
                <h3 className="text-lg font-semibold text-gray-900">Confirm Action</h3>
              </div>
              <p className="text-gray-600 mb-6">
                Are you sure you want to {confirmAction} this listener?
                {confirmAction === 'suspend' && ' This will prevent them from receiving new calls.'}
                {confirmAction === 'verify' && ' This will mark their account as verified.'}
                {confirmAction === 'message' && ' This will open a message composer.'}
              </p>
              <div className="flex space-x-3">
                <button
                  onClick={() => setShowConfirmModal(false)}
                  className="flex-1 px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors"
                  disabled={actionLoading}
                >
                  Cancel
                </button>
                <button
                  onClick={confirmActionHandler}
                  className="flex-1 px-4 py-2 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors disabled:opacity-50"
                  disabled={actionLoading}
                >
                  {actionLoading ? 'Processing...' : 'Confirm'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default ListenerProfile;