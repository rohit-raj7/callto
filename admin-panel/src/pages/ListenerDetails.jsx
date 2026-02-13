import React, { useState, useEffect, useRef } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { getListenerById, updateListenerVerificationStatus } from '../services/api';
import {
  ArrowLeft, Copy, Check, Mail, Phone, MapPin, Calendar,
  Star, TrendingUp, Clock, DollarSign, Headphones, Award,
  Shield, Building2, CreditCard, User, Briefcase, GraduationCap,
  Languages, Heart, Activity, Eye, EyeOff, MessageSquare, IndianRupee, 
  CheckCircle, XCircle, AlertCircle, Volume2, Mic, Play, Pause, RotateCcw
} from 'lucide-react';

const ListenerDetails = () => {
  const { listener_id } = useParams();
  const navigate = useNavigate();
  const [listener, setListener] = useState(null);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [copiedField, setCopiedField] = useState(null);
  const [updatingVerification, setUpdatingVerification] = useState(false);
  const [verificationSuccess, setVerificationSuccess] = useState(false);

  // Rejection modal state
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');
  const [customRejectionReason, setCustomRejectionReason] = useState('');

  // Voice player state
  const [isVoicePlaying, setIsVoicePlaying] = useState(false);
  const [voiceProgress, setVoiceProgress] = useState(0);
  const [voiceDuration, setVoiceDuration] = useState(0);
  const [voiceCurrentTime, setVoiceCurrentTime] = useState(0);
  const audioRef = useRef(null);

  // Platform commission constants (30% platform, 70% listener)
  const PLATFORM_COMMISSION_PERCENT = 30;
  const LISTENER_SHARE_PERCENT = 70;

  useEffect(() => {
    const fetchListener = async () => {
      try {
        const res = await getListenerById(listener_id);
        setListener(res.data.listener);
        setStats(res.data.stats || {});
      } catch (error) {
        setError('Failed to fetch listener details');
        console.error('Error fetching listener:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchListener();
  }, [listener_id]);

  // Audio player handlers
  const handlePlayPause = () => {
    if (!audioRef.current) return;
    if (isVoicePlaying) {
      audioRef.current.pause();
    } else {
      audioRef.current.play();
    }
    setIsVoicePlaying(!isVoicePlaying);
  };

  const handleAudioTimeUpdate = () => {
    if (!audioRef.current) return;
    const current = audioRef.current.currentTime;
    const duration = audioRef.current.duration;
    setVoiceCurrentTime(current);
    setVoiceProgress(duration ? (current / duration) * 100 : 0);
  };

  const handleAudioLoadedMetadata = () => {
    if (audioRef.current) {
      setVoiceDuration(audioRef.current.duration);
    }
  };

  const handleAudioEnded = () => {
    setIsVoicePlaying(false);
    setVoiceProgress(0);
    setVoiceCurrentTime(0);
  };

  const handleProgressClick = (e) => {
    if (!audioRef.current) return;
    const rect = e.currentTarget.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const pct = x / rect.width;
    audioRef.current.currentTime = pct * audioRef.current.duration;
  };

  const handleRestart = () => {
    if (!audioRef.current) return;
    audioRef.current.currentTime = 0;
    setVoiceProgress(0);
    setVoiceCurrentTime(0);
    if (!isVoicePlaying) {
      audioRef.current.play();
      setIsVoicePlaying(true);
    }
  };

  const formatTime = (secs) => {
    if (!secs || isNaN(secs)) return '0:00';
    const m = Math.floor(secs / 60);
    const s = Math.floor(secs % 60);
    return `${m}:${s.toString().padStart(2, '0')}`;
  };

  const handleCopyToClipboard = async (value, fieldName) => {
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(fieldName);
      setTimeout(() => setCopiedField(null), 2000); // Reset after 2 seconds
    } catch (error) {
      console.error('Failed to copy to clipboard:', error);
    }
  };

  const REJECTION_REASONS = [
    'Wrong PAN/Aadhaar details',
    'Voice not verified',
    'Payment method not correct',
    'Mobile number not added',
    'Profile details incomplete',
    'Inappropriate content',
    'Other',
  ];

  const handleVerificationStatusChange = async (newStatus) => {
    if (!['approved', 'rejected', 'pending'].includes(newStatus)) {
      console.error('Invalid verification status:', newStatus);
      return;
    }

    // If rejecting, show modal instead of directly updating
    if (newStatus === 'rejected') {
      setRejectionReason('');
      setCustomRejectionReason('');
      setShowRejectModal(true);
      return;
    }

    setUpdatingVerification(true);
    setVerificationSuccess(false);

    try {
      await updateListenerVerificationStatus(listener_id, newStatus);
      
      // Update local state
      setListener(prev => ({
        ...prev,
        verification_status: newStatus,
        is_verified: newStatus === 'approved',
        rejection_reason: null
      }));

      // Show success message
      setVerificationSuccess(true);
      setTimeout(() => setVerificationSuccess(false), 3000);
    } catch (error) {
      console.error('Failed to update verification status:', error);
      setError('Failed to update verification status. Please try again.');
      setTimeout(() => setError(null), 5000);
    } finally {
      setUpdatingVerification(false);
    }
  };

  const handleConfirmReject = async () => {
    const reason = rejectionReason === 'Other' ? customRejectionReason : rejectionReason;
    if (!reason || reason.trim() === '') {
      return; // Don't allow empty reason
    }

    setShowRejectModal(false);
    setUpdatingVerification(true);
    setVerificationSuccess(false);

    try {
      await updateListenerVerificationStatus(listener_id, 'rejected', reason.trim());
      
      setListener(prev => ({
        ...prev,
        verification_status: 'rejected',
        is_verified: false,
        rejection_reason: reason.trim()
      }));

      setVerificationSuccess(true);
      setTimeout(() => setVerificationSuccess(false), 3000);
    } catch (error) {
      console.error('Failed to reject listener:', error);
      setError('Failed to reject listener. Please try again.');
      setTimeout(() => setError(null), 5000);
    } finally {
      setUpdatingVerification(false);
    }
  };

  const maskValue = (value, visibleChars = 4) => {
    if (!value || value.length <= visibleChars) return value;
    return '*'.repeat(value.length - visibleChars) + value.slice(-visibleChars);
  };

  const InfoItem = ({ icon: Icon, label, value, copyable = false, masked = false, fieldKey = '' }) => {
    const displayValue = masked && value ? maskValue(value) : value;
    const actualValue = value || 'N/A';
    
    return (
      <div className="group h-full">
        <div className="flex items-center gap-2 text-xs text-gray-500 dark:text-gray-400 mb-1">
          {Icon && <Icon className="w-3.5 h-3.5" />}
          <span className="font-medium uppercase tracking-wide">{label}</span>
        </div>
        {copyable && value ? (
          <button
            onClick={() => handleCopyToClipboard(actualValue, fieldKey)}
            className="flex items-center gap-2 w-full h-full text-left px-3 py-2 rounded-lg bg-gray-50 dark:bg-gray-800 hover:bg-indigo-50 dark:hover:bg-indigo-900/20 border border-gray-200 dark:border-gray-700 transition-all group-hover:border-indigo-300 dark:group-hover:border-indigo-700"
            title="Click to copy"
          >
            <span className="flex-1 text-sm font-medium text-gray-900 dark:text-white font-mono truncate">
              {displayValue}
            </span>
            {copiedField === fieldKey ? (
              <Check className="w-4 h-4 text-green-500 flex-shrink-0" />
            ) : (
              <Copy className="w-4 h-4 text-gray-400 group-hover:text-indigo-500 flex-shrink-0" />
            )}
          </button>
        ) : (
          <div className="px-3 py-2 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700">
            <p className="text-sm font-medium text-gray-900 dark:text-white">
              {displayValue || 'N/A'}
            </p>
          </div>
        )}
      </div>
    );
  };

  const StatCard = ({ icon: Icon, label, value, color = 'indigo', trend }) => (
    <div className={`bg-gradient-to-br from-${color}-500 to-${color}-600 rounded-xl p-6 text-white shadow-lg hover:shadow-xl transition-all`}>
      <div className="flex items-center justify-between mb-3">
        <div className="p-3 bg-white/20 rounded-lg">
          <Icon className="w-6 h-6" />
        </div>
        {trend && (
          <div className="flex items-center gap-1 text-xs bg-white/20 px-2 py-1 rounded-full">
            <TrendingUp className="w-3 h-3" />
            {trend}
          </div>
        )}
      </div>
      <div className="text-3xl font-bold mb-1">{value}</div>
      <div className="text-sm opacity-90">{label}</div>
    </div>
  );

  const renderRatingStars = (value = 0) => {
    const safeValue = Number(value) || 0;
    const stars = [];
    for (let i = 1; i <= 5; i += 1) {
      const full = safeValue >= i;
      const half = !full && safeValue >= i - 0.5;
      stars.push(
        <span key={`star-${i}`} className="relative inline-flex">
          <Star className="w-5 h-5 text-amber-300" />
          {half && (
            <span className="absolute inset-0 overflow-hidden" style={{ width: '50%' }}>
              <Star className="w-5 h-5 text-amber-500 fill-amber-500" />
            </span>
          )}
          {full && (
            <span className="absolute inset-0">
              <Star className="w-5 h-5 text-amber-500 fill-amber-500" />
            </span>
          )}
        </span>
      );
    }
    return stars;
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-50 dark:bg-gray-900">
        <div className="text-center">
          <div className="relative w-16 h-16 mx-auto mb-4">
            <div className="absolute inset-0 border-4 border-indigo-200 dark:border-indigo-800 rounded-full"></div>
            <div className="absolute inset-0 border-4 border-indigo-600 rounded-full border-t-transparent animate-spin"></div>
          </div>
          <p className="text-gray-600 dark:text-gray-400 font-medium">Loading listener details...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-50 dark:bg-gray-900">
        <div className="text-center bg-white dark:bg-gray-800 rounded-xl shadow-lg p-8 max-w-md">
          <div className="w-16 h-16 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
            <Activity className="w-8 h-8 text-red-600" />
          </div>
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">Failed to Load</h3>
          <p className="text-gray-600 dark:text-gray-400 mb-6">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="px-6 py-2.5 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors font-medium"
          >
            Try Again
          </button>
        </div>
      </div>
    );
  }

  if (!listener) {
    return (
      <div className="flex items-center justify-center min-h-screen bg-gray-50 dark:bg-gray-900">
        <div className="text-center bg-white dark:bg-gray-800 rounded-xl shadow-lg p-8 max-w-md">
          <div className="w-16 h-16 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mx-auto mb-4">
            <User className="w-8 h-8 text-gray-400" />
          </div>
          <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">Listener Not Found</h3>
          <p className="text-gray-600 dark:text-gray-400 mb-6">The listener you're looking for doesn't exist or has been removed.</p>
          <button
            onClick={() => navigate('/admin-no-all-call/listeners')}
            className="px-6 py-2.5 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors font-medium"
          >
            Back to Listeners
          </button>
        </div>
      </div>
    );
  }

  // Calculate earnings from stats
  // total_earnings from backend is gross (what users paid)
  // Listener gets 70%, platform takes 30%
  const grossEarnings = parseFloat(stats?.total_earnings) || 0;
  const netEarnings = parseFloat((grossEarnings * (LISTENER_SHARE_PERCENT / 100)).toFixed(2));
  const platformFee = parseFloat((grossEarnings * (PLATFORM_COMMISSION_PERCENT / 100)).toFixed(2));
  const verificationStatus = listener.verification_status || 'pending';

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 p-6 transition-colors">
      <div className="max-w-7xl mx-auto">
        {/* Header with Back Button */}
        <div className="mb-6">
          <button
            onClick={() => navigate('/admin-no-all-call/listeners')}
            className="flex items-center gap-2 text-gray-600 dark:text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors mb-4 group"
          >
            <ArrowLeft className="w-5 h-5 group-hover:-translate-x-1 transition-transform" />
            <span className="font-medium">Back to Listeners</span>
          </button>
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">Listener Profile</h1>
              <p className="text-gray-600 dark:text-gray-400">Complete information and statistics</p>
            </div>
          </div>
        </div>

        {/* Profile Header Card */}
        <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-8 mb-6">
          <div className="flex flex-col lg:flex-row gap-8">
            {/* Avatar Section */}
            <div className="flex flex-col items-center lg:items-start">
              <div className="relative">
                <div className="w-32 h-32 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full flex items-center justify-center text-white text-4xl font-bold shadow-lg">
                  {(listener.professional_name || listener.display_name || '?').charAt(0).toUpperCase()}
                </div>
                {listener.is_online && (
                  <div className="absolute bottom-2 right-2 w-6 h-6 bg-emerald-500 border-4 border-white dark:border-gray-800 rounded-full animate-pulse"></div>
                )}
                {listener.is_verified && (
                  <div className="absolute -top-1 -right-1 w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center shadow-lg">
                    <Shield className="w-5 h-5 text-white" />
                  </div>
                )}
              </div>
              <div className="mt-4 text-center lg:text-left">
                <span className={`inline-flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium ${
                  listener.is_online
                    ? 'bg-emerald-100 dark:bg-emerald-900/30 text-emerald-700 dark:text-emerald-400'
                    : 'bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400'
                }`}>
                  <span className={`w-2 h-2 rounded-full ${listener.is_online ? 'bg-emerald-500' : 'bg-gray-400'}`}></span>
                  {listener.is_online ? 'Online Now' : 'Offline'}
                </span>
              </div>
            </div>

            {/* Basic Info Section */}
            <div className="flex-1">
              <div className="mb-4">
                <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
                  {listener.professional_name || listener.display_name || 'Unknown Listener'}
                </h2>
                <div className="flex flex-wrap items-center gap-3 text-sm text-gray-600 dark:text-gray-400">
                  <span className="flex items-center gap-1.5">
                    <User className="w-4 h-4" />
                    ID: {listener.listener_id?.slice(0, 8)}...
                  </span>
                  {listener.city && (
                    <span className="flex items-center gap-1.5">
                      <MapPin className="w-4 h-4" />
                      {listener.city}, {listener.country}
                    </span>
                  )}
                  <span className="flex items-center gap-1.5">
                    <Calendar className="w-4 h-4" />
                    Joined {new Date(listener.created_at).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })}
                  </span>
                </div>
              </div>

              {/* Rating and Rate */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
                <div className="flex items-center gap-3 bg-amber-50 dark:bg-amber-900/20 rounded-lg p-4">
                  <div className="p-2 bg-amber-100 dark:bg-amber-900/30 rounded-lg">
                    <Star className="w-5 h-5 text-amber-600" />
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-gray-900 dark:text-white">
                      {stats?.average_rating ? Number(stats.average_rating).toFixed(1) : 'N/A'}
                    </div>
                    <div className="text-xs text-gray-600 dark:text-gray-400">
                      {stats?.total_ratings || 0} reviews
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-3 bg-indigo-50 dark:bg-indigo-900/20 rounded-lg p-4">
                  <div className="p-2 bg-indigo-100 dark:bg-indigo-900/30 rounded-lg">
                    <IndianRupee className="w-5 h-5 text-indigo-600" />
                  </div>
                  <div>
                    <div className="text-2xl font-bold text-gray-900 dark:text-white">
                      ₹{listener.rate_per_minute || 0}
                    </div>
                    <div className="text-xs text-gray-600 dark:text-gray-400">
                      INR per minute
                    </div>
                  </div>
                </div>
              </div>

              {/* Quick Stats */}
              <div className="flex flex-wrap gap-4">
                {listener.is_verified && (
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400 rounded-lg text-sm font-medium">
                    <Shield className="w-4 h-4" />
                    Verified
                  </div>
                )}
                {(listener.verification_status === 'reapplied') && (
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-orange-50 dark:bg-orange-900/20 text-orange-700 dark:text-orange-400 rounded-lg text-sm font-medium">
                    <RotateCcw className="w-4 h-4" />
                    Reapplied
                  </div>
                )}
                {(listener.verification_status === 'rejected') && (
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-lg text-sm font-medium">
                    <XCircle className="w-4 h-4" />
                    Rejected
                  </div>
                )}
                {(listener.verification_status === 'pending') && (
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-yellow-50 dark:bg-yellow-900/20 text-yellow-700 dark:text-yellow-400 rounded-lg text-sm font-medium">
                    <AlertCircle className="w-4 h-4" />
                    Pending
                  </div>
                )}
                {listener.is_available && (
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-400 rounded-lg text-sm font-medium">
                    <Headphones className="w-4 h-4" />
                    Available
                  </div>
                )}
                {listener.experience_years && (
                  <div className="flex items-center gap-2 px-3 py-1.5 bg-purple-50 dark:bg-purple-900/20 text-purple-700 dark:text-purple-400 rounded-lg text-sm font-medium">
                    <Award className="w-4 h-4" />
                    {listener.experience_years}+ years
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          <StatCard
            icon={Headphones}
            label="Completed Calls"
            value={parseInt(stats?.total_calls) || 0}
            color="blue"
          />
          <StatCard
            icon={Clock}
            label="Total Minutes"
            value={parseInt(stats?.total_minutes) || 0}
            color="indigo"
          />
          <StatCard
            icon={IndianRupee}
            label="Total Earnings (Net)"
            value={`₹${netEarnings.toFixed(2)}`}
            color="emerald"
          />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
          <div className="lg:col-span-2">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
              <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-4 mb-6">
                <div>
                  <h3 className="text-xl font-semibold text-gray-900 dark:text-white">Verification Details</h3>
                  <p className="text-sm text-gray-600 dark:text-gray-400">All listener data grouped for quick admin review</p>
                </div>
                <span className={`inline-flex items-center gap-2 px-3 py-1.5 rounded-lg text-sm font-semibold ${
                  verificationStatus === 'approved'
                    ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-400'
                    : verificationStatus === 'rejected'
                    ? 'bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400'
                    : 'bg-amber-50 dark:bg-amber-900/20 text-amber-700 dark:text-amber-400'
                }`}>
                  {verificationStatus === 'approved' ? (
                    <CheckCircle className="w-4 h-4" />
                  ) : verificationStatus === 'rejected' ? (
                    <XCircle className="w-4 h-4" />
                  ) : (
                    <AlertCircle className="w-4 h-4" />
                  )}
                  {verificationStatus.toUpperCase()}
                </span>
              </div>

              <div className="divide-y divide-gray-200 dark:divide-gray-700">
                <div className="pb-6">
                  <div className="flex items-center gap-2 mb-4 text-sm font-semibold text-gray-900 dark:text-white">
                    <User className="w-4 h-4 text-indigo-600" />
                    Basic Info
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <InfoItem
                      icon={User}
                      label="Professional Name"
                      value={listener.professional_name}
                    />
                    <InfoItem
                      icon={User}
                      label="Display Name"
                      value={listener.display_name}
                    />
                    <InfoItem
                      icon={User}
                      label="Listener ID"
                      value={listener.listener_id}
                      copyable
                      fieldKey="listener_id"
                    />
                    <InfoItem
                      icon={User}
                      label="Age"
                      value={listener.age?.toString()}
                    />
                    <InfoItem
                      icon={Calendar}
                      label="Joined"
                      value={listener.created_at ? new Date(listener.created_at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' }) : null}
                    />
                    <InfoItem
                      icon={MapPin}
                      label="Location"
                      value={listener.city && listener.country ? `${listener.city}, ${listener.country}` : null}
                    />
                  </div>
                </div>

                <div className="py-6">
                  <div className="flex items-center gap-2 mb-4 text-sm font-semibold text-gray-900 dark:text-white">
                    <Mail className="w-4 h-4 text-indigo-600" />
                    Contact Details
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <InfoItem
                      icon={Mail}
                      label="Email Address"
                      value={listener.email}
                      copyable
                      fieldKey="email"
                    />
                    <InfoItem
                      icon={Phone}
                      label="Phone Number"
                      value={listener.phone_number}
                      copyable
                      fieldKey="phone_number"
                    />
                    <InfoItem
                      icon={Phone}
                      label="Mobile Number"
                      value={listener.mobile_number}
                      copyable
                      fieldKey="mobile_number"
                    />
                  </div>
                </div>

                <div className="py-6">
                  <div className="flex items-center gap-2 mb-4 text-sm font-semibold text-gray-900 dark:text-white">
                    <MessageSquare className="w-4 h-4 text-indigo-600" />
                    Profile Details
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <InfoItem
                      icon={GraduationCap}
                      label="Education"
                      value={listener.education}
                    />
                    <InfoItem
                      icon={IndianRupee}
                      label="Rate per Minute"
                      value={listener.rate_per_minute ? `₹${listener.rate_per_minute}` : null}
                    />
                  </div>
                  {listener.bio && (
                    <div className="mt-6">
                      <label className="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2 block">
                        About
                      </label>
                      <div className="px-3 py-3 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700">
                        <p className="text-sm text-gray-700 dark:text-gray-300 leading-relaxed whitespace-pre-wrap">
                          {listener.bio}
                        </p>
                      </div>
                    </div>
                  )}
                </div>

                <div className="py-6">
                  <div className="flex items-center gap-2 mb-4 text-sm font-semibold text-gray-900 dark:text-white">
                    <Briefcase className="w-4 h-4 text-indigo-600" />
                    Experience / Skills
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <InfoItem
                      icon={Award}
                      label="Experience"
                      value={listener.experience_years ? `${listener.experience_years} years` : null}
                    />
                    <InfoItem
                      icon={Clock}
                      label="Last Active"
                      value={listener.last_active_at ? new Date(listener.last_active_at).toLocaleString('en-US', {
                        month: 'short',
                        day: 'numeric',
                        hour: '2-digit',
                        minute: '2-digit'
                      }) : null}
                    />
                  </div>

                  {listener.specialties && listener.specialties.length > 0 && (
                    <div className="mt-6">
                      <label className="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2 block">
                        Specialties
                      </label>
                      <div className="flex flex-wrap gap-2">
                        {listener.specialties.map((specialty, index) => (
                          <span key={index} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-indigo-50 dark:bg-indigo-900/20 text-indigo-700 dark:text-indigo-400 rounded-lg text-sm font-medium">
                            <Heart className="w-3.5 h-3.5" />
                            {specialty}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  {listener.languages && listener.languages.length > 0 && (
                    <div className="mt-4">
                      <label className="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2 block">
                        Languages
                      </label>
                      <div className="flex flex-wrap gap-2">
                        {listener.languages.map((language, index) => (
                          <span key={index} className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-400 rounded-lg text-sm font-medium">
                            <Languages className="w-3.5 h-3.5" />
                            {language}
                          </span>
                        ))}
                      </div>
                    </div>
                  )}

                  {listener.certifications && (
                    <div className="mt-4">
                      <label className="text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wide mb-2 block">
                        Certifications
                      </label>
                      <div className="px-3 py-2 rounded-lg bg-gray-50 dark:bg-gray-800 border border-gray-200 dark:border-gray-700">
                        <p className="text-sm text-gray-900 dark:text-white">
                          {listener.certifications}
                        </p>
                      </div>
                    </div>
                  )}
                </div>

                {listener?.payment_info && (
                  <div className="py-6">
                    <div className="flex items-center gap-2 mb-4 text-sm font-semibold text-gray-900 dark:text-white">
                      <CreditCard className="w-4 h-4 text-indigo-600" />
                      Documents
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <InfoItem
                        icon={Building2}
                        label="Payment Method"
                        value={listener.payment_info.payment_method?.toUpperCase()}
                      />
                      {listener.payment_info.payment_method === 'upi' && (
                        <>
                          <InfoItem
                            icon={CreditCard}
                            label="UPI ID"
                            value={listener.payment_info.upi_id}
                            copyable
                            fieldKey="upi_id"
                          />
                          <InfoItem
                            icon={Shield}
                            label="Aadhaar"
                            value={listener.payment_info.aadhaar_number}
                            copyable
                            masked
                            fieldKey="aadhaar_number"
                          />
                          <InfoItem
                            icon={Shield}
                            label="PAN Number"
                            value={listener.payment_info.pan_number}
                            copyable
                            masked
                            fieldKey="pan_number"
                          />
                          <InfoItem
                            icon={User}
                            label="Name as per PAN"
                            value={listener.payment_info.name_as_per_pan}
                            copyable
                            fieldKey="name_as_per_pan"
                          />
                        </>
                      )}
                      {listener.payment_info.payment_method === 'bank' && (
                        <>
                          <InfoItem
                            icon={Building2}
                            label="Bank Name"
                            value={listener.payment_info.bank_name}
                            copyable
                            fieldKey="bank_name"
                          />
                          <InfoItem
                            icon={User}
                            label="Account Holder"
                            value={listener.payment_info.account_holder_name}
                            copyable
                            fieldKey="account_holder_name"
                          />
                          <InfoItem
                            icon={CreditCard}
                            label="Account Number"
                            value={listener.payment_info.account_number}
                            copyable
                            masked
                            fieldKey="account_number"
                          />
                          <InfoItem
                            icon={Building2}
                            label="IFSC Code"
                            value={listener.payment_info.ifsc_code}
                            copyable
                            fieldKey="ifsc_code"
                          />
                          <InfoItem
                            icon={Shield}
                            label="PAN/Aadhaar"
                            value={listener.payment_info.pan_aadhaar_bank}
                            copyable
                            masked
                            fieldKey="pan_aadhaar_bank"
                          />
                        </>
                      )}
                    </div>
                    <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
                      <p className="text-xs text-gray-500 dark:text-gray-400 flex items-center gap-1.5">
                        <Eye className="w-3.5 h-3.5" />
                        Click on any value to copy. Sensitive data is masked.
                      </p>
                    </div>
                  </div>
                )}

                <div className="pt-6">
                  <div className="flex items-center gap-2 mb-4 text-sm font-semibold text-gray-900 dark:text-white">
                    <Shield className="w-4 h-4 text-indigo-600" />
                    Verification Status
                  </div>
                  <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <div className={`p-4 rounded-xl border ${
                      verificationStatus === 'approved'
                        ? 'border-emerald-200 dark:border-emerald-800 bg-emerald-50 dark:bg-emerald-900/20'
                        : verificationStatus === 'rejected'
                        ? 'border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20'
                        : 'border-amber-200 dark:border-amber-800 bg-amber-50 dark:bg-amber-900/20'
                    }`}>
                      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-gray-600 dark:text-gray-400">
                        {verificationStatus === 'approved' ? (
                          <CheckCircle className="w-3.5 h-3.5" />
                        ) : verificationStatus === 'rejected' ? (
                          <XCircle className="w-3.5 h-3.5" />
                        ) : (
                          <AlertCircle className="w-3.5 h-3.5" />
                        )}
                        Status
                      </div>
                      <div className="mt-2 text-sm font-semibold text-gray-900 dark:text-white">{verificationStatus.toUpperCase()}</div>
                    </div>
                    <div className={`p-4 rounded-xl border ${
                      listener.is_available
                        ? 'border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20'
                        : 'border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/40'
                    }`}>
                      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-gray-600 dark:text-gray-400">
                        <Headphones className="w-3.5 h-3.5" />
                        Availability
                      </div>
                      <div className="mt-2 text-sm font-semibold text-gray-900 dark:text-white">
                        {listener.is_available ? 'Available' : 'Unavailable'}
                      </div>
                    </div>
                    <div className={`p-4 rounded-xl border ${
                      listener.is_online
                        ? 'border-emerald-200 dark:border-emerald-800 bg-emerald-50 dark:bg-emerald-900/20'
                        : 'border-gray-200 dark:border-gray-700 bg-gray-50 dark:bg-gray-900/40'
                    }`}>
                      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-gray-600 dark:text-gray-400">
                        <Activity className="w-3.5 h-3.5" />
                        Online Status
                      </div>
                      <div className="mt-2 text-sm font-semibold text-gray-900 dark:text-white">
                        {listener.is_online ? 'Online' : 'Offline'}
                      </div>
                    </div>
                    <div className="p-4 rounded-xl border border-indigo-200 dark:border-indigo-800 bg-indigo-50 dark:bg-indigo-900/20">
                      <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-wide text-gray-600 dark:text-gray-400">
                        <Clock className="w-3.5 h-3.5" />
                        Last Active
                      </div>
                      <div className="mt-2 text-sm font-semibold text-gray-900 dark:text-white">
                        {listener.last_active_at ? new Date(listener.last_active_at).toLocaleString('en-US', {
                          month: 'short',
                          day: 'numeric',
                          hour: '2-digit',
                          minute: '2-digit'
                        }) : 'N/A'}
                      </div>
                    </div>

                    <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6 h-fit">
                      <div className="flex items-center justify-between mb-4">
                        <div>
                          <h3 className="text-lg font-semibold text-gray-900 dark:text-white">Listener Ratings</h3>
                          <p className="text-sm text-gray-600 dark:text-gray-400">Call feedback overview</p>
                        </div>
                        {Number(stats?.average_rating || 0) >= 4.5 && (
                          <span className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-semibold bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300">
                            <Award className="w-3.5 h-3.5" />
                            Top Rated Listener
                          </span>
                        )}
                      </div>
                      <div className="flex items-center gap-4">
                        <div className="text-4xl font-bold text-gray-900 dark:text-white">
                          {stats?.average_rating ? Number(stats.average_rating).toFixed(1) : '0.0'}
                        </div>
                        <div>
                          <div className="flex items-center gap-1">
                            {renderRatingStars(Number(stats?.average_rating || 0))}
                          </div>
                          <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                            {stats?.total_ratings || 0} total ratings
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div className="space-y-6">
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-5 flex items-center gap-2">
                <Shield className="w-5 h-5 text-indigo-600" />
                Verification Control
              </h3>
              
              <div className="mb-5 p-4 rounded-xl border-2" style={{
                borderColor: 
                  (listener.verification_status || 'pending') === 'approved' ? '#10b981' :
                  (listener.verification_status || 'pending') === 'rejected' ? '#ef4444' :
                  (listener.verification_status || 'pending') === 'reapplied' ? '#f97316' : '#f59e0b',
                backgroundColor: 
                  (listener.verification_status || 'pending') === 'approved' ? '#ecfdf5' :
                  (listener.verification_status || 'pending') === 'rejected' ? '#fef2f2' :
                  (listener.verification_status || 'pending') === 'reapplied' ? '#fff7ed' : '#fffbeb'
              }}>
                <div className="flex items-center gap-3">
                  {(listener.verification_status || 'pending') === 'approved' ? (
                    <div className="p-2 bg-green-500 rounded-lg">
                      <CheckCircle className="w-5 h-5 text-white" />
                    </div>
                  ) : (listener.verification_status || 'pending') === 'rejected' ? (
                    <div className="p-2 bg-red-500 rounded-lg">
                      <XCircle className="w-5 h-5 text-white" />
                    </div>
                  ) : (listener.verification_status || 'pending') === 'reapplied' ? (
                    <div className="p-2 bg-orange-500 rounded-lg">
                      <RotateCcw className="w-5 h-5 text-white" />
                    </div>
                  ) : (
                    <div className="p-2 bg-yellow-500 rounded-lg">
                      <AlertCircle className="w-5 h-5 text-white" />
                    </div>
                  )}
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <div className="text-sm font-bold text-gray-900 dark:text-gray-100">
                        Status: {(listener.verification_status || 'pending').toUpperCase()}
                      </div>
                      {(listener.verification_status || 'pending') === 'reapplied' && (
                        <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-orange-100 text-orange-700 border border-orange-300">
                          <RotateCcw className="w-3 h-3" />
                          Reapplied
                        </span>
                      )}
                    </div>
                    <div className="text-xs text-gray-600 dark:text-gray-400 mt-0.5">
                      {(listener.verification_status || 'pending') === 'approved' 
                        ? 'Listener is visible to users and can receive calls/chats'
                        : (listener.verification_status || 'pending') === 'rejected'
                        ? 'Listener is hidden and cannot receive calls/chats'
                        : (listener.verification_status || 'pending') === 'reapplied'
                        ? `Listener reapplied for verification (attempt ${listener.reapply_attempts || 1} of 3)`
                        : 'Awaiting verification - hidden from users'}
                    </div>
                  </div>
                </div>
                {/* Show rejection reason if exists */}
                {listener.rejection_reason && (listener.verification_status === 'rejected') && (
                  <div className="mt-3 p-3 bg-red-100 dark:bg-red-900/30 rounded-lg border border-red-200 dark:border-red-800">
                    <div className="text-xs font-semibold text-red-700 dark:text-red-400 mb-1">Rejection Reason:</div>
                    <div className="text-sm text-red-800 dark:text-red-300">{listener.rejection_reason}</div>
                  </div>
                )}
                {/* Show reapply attempts count */}
                {(listener.reapply_attempts > 0) && (
                  <div className="mt-2 text-xs text-gray-500 dark:text-gray-400">
                    Reapply attempts used: {listener.reapply_attempts} / 3
                  </div>
                )}
              </div>

              {verificationSuccess && (
                <div className="mb-4 p-3 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg animate-pulse">
                  <div className="flex items-center gap-2 text-green-700 dark:text-green-400 text-sm font-medium">
                    <CheckCircle className="w-4 h-4" />
                    <span>Verification status updated successfully!</span>
                  </div>
                </div>
              )}

              <div className="mb-4">
                <label className="text-xs font-semibold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-3 block">
                  Change Verification Status
                </label>
                <div className="bg-gray-100 dark:bg-gray-700 p-1.5 rounded-xl flex gap-1.5">
                  <button
                    onClick={() => handleVerificationStatusChange('approved')}
                    disabled={updatingVerification}
                    className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-semibold text-sm transition-all duration-200 border ${
                      (listener.verification_status || 'pending') === 'approved'
                        ? 'bg-green-500 text-white shadow-lg shadow-green-500/30 border-green-500 scale-[1.02]'
                        : 'text-gray-600 dark:text-gray-300 border-transparent hover:bg-white/60 dark:hover:bg-gray-600'
                    } ${updatingVerification ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
                  >
                    <CheckCircle className="w-4 h-4" />
                    <span>Approved</span>
                  </button>

                  <button
                    onClick={() => handleVerificationStatusChange('pending')}
                    disabled={updatingVerification}
                    className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-semibold text-sm transition-all duration-200 border ${
                      ['pending', 'reapplied'].includes(listener.verification_status || 'pending')
                        ? 'bg-yellow-500 text-white shadow-lg shadow-yellow-500/30 border-yellow-500 scale-[1.02]'
                        : 'text-gray-600 dark:text-gray-300 border-transparent hover:bg-white/60 dark:hover:bg-gray-600'
                    } ${updatingVerification ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
                  >
                    <AlertCircle className="w-4 h-4" />
                    <span>Pending</span>
                  </button>

                  <button
                    onClick={() => handleVerificationStatusChange('rejected')}
                    disabled={updatingVerification}
                    className={`flex-1 flex items-center justify-center gap-2 px-4 py-3 rounded-lg font-semibold text-sm transition-all duration-200 border ${
                      (listener.verification_status || 'pending') === 'rejected'
                        ? 'bg-red-500 text-white shadow-lg shadow-red-500/30 border-red-500 scale-[1.02]'
                        : 'text-gray-600 dark:text-gray-300 border-transparent hover:bg-white/60 dark:hover:bg-gray-600'
                    } ${updatingVerification ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer'}`}
                  >
                    <XCircle className="w-4 h-4" />
                    <span>Rejected</span>
                  </button>
                </div>
                
                {updatingVerification && (
                  <div className="mt-3 flex items-center justify-center gap-2 text-sm text-gray-500 dark:text-gray-400">
                    <div className="w-4 h-4 border-2 border-indigo-500 border-t-transparent rounded-full animate-spin"></div>
                    <span>Updating status...</span>
                  </div>
                )}
              </div>
 
            </div>

            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6">
              <h3 className="text-lg font-semibold text-gray-900 dark:text-white mb-4 flex items-center gap-2">
                <Mic className="w-5 h-5 text-indigo-600" />
                Voice Verification
              </h3>

              {listener.voice_verification_url ? (
                <div>
                  {/* Hidden audio element */}
                  <audio
                    ref={audioRef}
                    src={listener.voice_verification_url}
                    onTimeUpdate={handleAudioTimeUpdate}
                    onLoadedMetadata={handleAudioLoadedMetadata}
                    onEnded={handleAudioEnded}
                    preload="metadata"
                  />

                  {/* Player Card */}
                  <div className="bg-gradient-to-br from-indigo-50 to-purple-50 dark:from-indigo-900/20 dark:to-purple-900/20 rounded-xl p-5 border border-indigo-100 dark:border-indigo-800/40">
                    {/* Waveform / Progress Bar */}
                    <div
                      className="relative h-12 bg-white/60 dark:bg-gray-800/60 rounded-lg mb-4 cursor-pointer overflow-hidden group"
                      onClick={handleProgressClick}
                    >
                      {/* Waveform decorative bars */}
                      <div className="absolute inset-0 flex items-center justify-around px-2 opacity-30">
                        {Array.from({ length: 40 }).map((_, i) => (
                          <div
                            key={i}
                            className="w-1 rounded-full bg-indigo-400 dark:bg-indigo-500"
                            style={{ height: `${20 + Math.sin(i * 0.7) * 15 + Math.random() * 10}px` }}
                          />
                        ))}
                      </div>
                      {/* Progress overlay */}
                      <div
                        className="absolute inset-y-0 left-0 flex items-center justify-around px-2 overflow-hidden transition-all"
                        style={{ width: `${voiceProgress}%` }}
                      >
                        <div className="absolute inset-0 bg-indigo-500/20 dark:bg-indigo-400/20" />
                        {Array.from({ length: 40 }).map((_, i) => (
                          <div
                            key={i}
                            className="relative w-1 rounded-full bg-indigo-600 dark:bg-indigo-400"
                            style={{ height: `${20 + Math.sin(i * 0.7) * 15 + Math.random() * 10}px` }}
                          />
                        ))}
                      </div>
                      {/* Hover hint */}
                      <div className="absolute inset-0 bg-indigo-500/0 group-hover:bg-indigo-500/5 transition-colors" />
                    </div>

                    {/* Controls Row */}
                    <div className="flex items-center gap-3">
                      {/* Play / Pause Button */}
                      <button
                        onClick={handlePlayPause}
                        className="w-11 h-11 flex items-center justify-center rounded-full bg-indigo-600 hover:bg-indigo-700 text-white shadow-lg shadow-indigo-500/30 transition-all hover:scale-105 active:scale-95 flex-shrink-0"
                      >
                        {isVoicePlaying ? (
                          <Pause className="w-5 h-5" />
                        ) : (
                          <Play className="w-5 h-5 ml-0.5" />
                        )}
                      </button>

                      {/* Restart Button */}
                      <button
                        onClick={handleRestart}
                        className="w-9 h-9 flex items-center justify-center rounded-full bg-white dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 text-gray-600 dark:text-gray-300 border border-gray-200 dark:border-gray-600 transition-all hover:scale-105 active:scale-95 flex-shrink-0"
                        title="Restart"
                      >
                        <RotateCcw className="w-4 h-4" />
                      </button>

                      {/* Time Display */}
                      <div className="flex-1 flex items-center justify-end">
                        <span className="text-sm font-mono font-medium text-gray-600 dark:text-gray-300">
                          {formatTime(voiceCurrentTime)}
                          <span className="text-gray-400 dark:text-gray-500 mx-1">/</span>
                          {formatTime(voiceDuration)}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Voice Status Badge */}
                  <div className="mt-3 flex items-center gap-2">
                    <div className={`flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium ${
                      listener.voice_verified
                        ? 'bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-400'
                        : 'bg-yellow-50 dark:bg-yellow-900/20 text-yellow-700 dark:text-yellow-400'
                    }`}>
                      {listener.voice_verified ? (
                        <><CheckCircle className="w-3.5 h-3.5" /> Verified</>
                      ) : (
                        <><AlertCircle className="w-3.5 h-3.5" /> Pending Review</>
                      )}
                    </div>
                  </div>
                </div>
              ) : (
                <div className="flex flex-col items-center py-8 text-center">
                  <div className="w-14 h-14 bg-gray-100 dark:bg-gray-700 rounded-full flex items-center justify-center mb-3">
                    <Volume2 className="w-7 h-7 text-gray-400" />
                  </div>
                  <p className="text-sm font-medium text-gray-500 dark:text-gray-400">No voice recording</p>
                  <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">Listener hasn't submitted a voice verification yet</p>
                </div>
              )}
            </div>

          </div>
        </div>
      </div>

      {/* Rejection Reason Modal */}
      {showRejectModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl max-w-md w-full p-6 animate-in fade-in">
            <div className="flex items-center gap-3 mb-6">
              <div className="p-2 bg-red-100 dark:bg-red-900/30 rounded-lg">
                <XCircle className="w-6 h-6 text-red-600" />
              </div>
              <div>
                <h3 className="text-lg font-bold text-gray-900 dark:text-white">Reject Listener</h3>
                <p className="text-sm text-gray-500 dark:text-gray-400">Please provide a reason for rejection</p>
              </div>
            </div>

            <div className="space-y-4">
              <div>
                <label className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2 block">
                  Rejection Reason
                </label>
                <div className="space-y-2">
                  {REJECTION_REASONS.map((reason) => (
                    <label
                      key={reason}
                      className={`flex items-center gap-3 p-3 rounded-lg border-2 cursor-pointer transition-all ${
                        rejectionReason === reason
                          ? 'border-red-500 bg-red-50 dark:bg-red-900/20'
                          : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
                      }`}
                    >
                      <input
                        type="radio"
                        name="rejectionReason"
                        value={reason}
                        checked={rejectionReason === reason}
                        onChange={(e) => setRejectionReason(e.target.value)}
                        className="w-4 h-4 text-red-500 focus:ring-red-500"
                      />
                      <span className="text-sm font-medium text-gray-700 dark:text-gray-300">{reason}</span>
                    </label>
                  ))}
                </div>
              </div>

              {rejectionReason === 'Other' && (
                <div>
                  <label className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-2 block">
                    Custom Reason
                  </label>
                  <textarea
                    value={customRejectionReason}
                    onChange={(e) => setCustomRejectionReason(e.target.value)}
                    placeholder="Enter the reason for rejection..."
                    className="w-full p-3 rounded-lg border-2 border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-900 text-gray-900 dark:text-white text-sm focus:border-red-500 focus:ring-1 focus:ring-red-500 outline-none resize-none"
                    rows={3}
                  />
                </div>
              )}
            </div>

            <div className="flex gap-3 mt-6">
              <button
                onClick={() => setShowRejectModal(false)}
                className="flex-1 px-4 py-3 rounded-lg border-2 border-gray-200 dark:border-gray-700 text-gray-700 dark:text-gray-300 font-semibold text-sm hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmReject}
                disabled={!rejectionReason || (rejectionReason === 'Other' && !customRejectionReason.trim())}
                className={`flex-1 px-4 py-3 rounded-lg font-semibold text-sm transition-all ${
                  rejectionReason && (rejectionReason !== 'Other' || customRejectionReason.trim())
                    ? 'bg-red-500 text-white hover:bg-red-600 shadow-lg shadow-red-500/30'
                    : 'bg-gray-200 dark:bg-gray-700 text-gray-400 cursor-not-allowed'
                }`}
              >
                Confirm Reject
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default ListenerDetails;
