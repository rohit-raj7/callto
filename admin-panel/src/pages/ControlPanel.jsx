import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import api from '../services/api.js';
import { Eye, EyeOff, Mail, Lock, ArrowRight, CheckCircle, XCircle, Loader2, AlertCircle, Sun, Moon } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';

const extractAdminToken = (data = {}) =>
  data?.token || data?.access_token || data?.accessToken || data?.jwt || null;

const isUsableToken = (token) => {
  const normalized = String(token || '').trim();
  return Boolean(normalized) && normalized !== 'undefined' && normalized !== 'null';
};

const getApiErrorMessage = (err, fallbackMessage) => {
  const apiMessage = err?.response?.data?.error || err?.response?.data?.message;
  if (typeof apiMessage === 'string' && apiMessage.trim().length > 0) {
    return apiMessage.trim();
  }
  return fallbackMessage;
};

const AdminLogin = () => {
  const navigate = useNavigate();
  const { isDark, toggleTheme } = useTheme();
  const googleClientId = (import.meta.env.VITE_GOOGLE_CLIENT_ID || '').trim();
  // Redirect if already logged in
  useEffect(() => {
    const token = localStorage.getItem('adminToken');
    if (isUsableToken(token)) {
      navigate('/admin-no-all-call/dashboard');
    } else if (token) {
      localStorage.removeItem('adminToken');
    }
  }, [navigate]);
  const [formData, setFormData] = useState({
    email: '',
    password: ''
  });
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [loginMode, setLoginMode] = useState('login'); // 'login', 'forgot', 'reset'
  const [resetEmail, setResetEmail] = useState('');
  const [resetCode, setResetCode] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [message, setMessage] = useState('');
  const [messageType, setMessageType] = useState(''); // 'success', 'error'
  const [isGoogleConfigured, setIsGoogleConfigured] = useState(Boolean(googleClientId));
  // (removed duplicate navigate and useTheme declaration)

  // Validation functions
  const validateEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const validatePassword = (password) => {
    return password.length >= 6;
  };

  const validateForm = () => {
    const newErrors = {};
    if (!validateEmail(formData.email)) {
      newErrors.email = 'Please enter a valid email address';
    }
    if (!validatePassword(formData.password)) {
      newErrors.password = 'Password must be at least 6 characters';
    }
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
    
    // Clear error when user starts typing
    if (errors[name]) {
      setErrors(prev => ({ ...prev, [name]: '' }));
    }
  };

  const handleEmailLogin = async (e) => {
    e.preventDefault();
    if (!validateForm()) return;

    setLoading(true);
    setMessage('');
    try {
      const res = await api.post('/admin/login', formData);
      const token = extractAdminToken(res.data);
      if (!isUsableToken(token)) {
        throw new Error('Login response missing token');
      }
      localStorage.setItem('adminToken', token);
      navigate('/admin-no-all-call/dashboard');
    } catch (err) {
      setMessage(getApiErrorMessage(err, 'Invalid email or password'));
      setMessageType('error');
    } finally {
      setLoading(false);
    }
  };

  const handleForgotPassword = async (e) => {
    e.preventDefault();
    if (!validateEmail(resetEmail)) {
      setMessage('Please enter a valid email address');
      setMessageType('error');
      return;
    }

    setLoading(true);
    setMessage('');
    try {
      await api.post('/admin/forgot-password', { email: resetEmail });
      setMessage('Password reset code sent to your email');
      setMessageType('success');
      setLoginMode('reset');
    } catch (err) {
      setMessage('Failed to send reset code. Please try again.');
      setMessageType('error');
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async (e) => {
    e.preventDefault();
    if (!resetCode || resetCode.trim().length < 4) {
      setMessage('Please enter a valid reset code');
      setMessageType('error');
      return;
    }
    if (!validatePassword(newPassword)) {
      setMessage('Password must be at least 6 characters');
      setMessageType('error');
      return;
    }

    setLoading(true);
    setMessage('');
    try {
      await api.post('/admin/reset-password', {
        email: resetEmail,
        code: resetCode,
        newPassword,
      });
      setMessage('Password reset successful. Please sign in.');
      setMessageType('success');
      setLoginMode('login');
      setResetCode('');
      setNewPassword('');
    } catch (err) {
      setMessage('Failed to reset password. Please try again.');
      setMessageType('error');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!googleClientId) {
      setIsGoogleConfigured(false);
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.defer = true;
    script.onerror = () => {
      setIsGoogleConfigured(false);
      setMessage('Failed to load Google Sign-In. Please use email login.');
      setMessageType('error');
    };
    document.body.appendChild(script);

    script.onload = () => {
      try {
        const buttonContainer = document.getElementById('google-signin-button');
        if (!window.google?.accounts?.id || !buttonContainer) {
          throw new Error('Google Sign-In client not available');
        }

        window.google.accounts.id.initialize({
          client_id: googleClientId,
          callback: handleGoogleResponse,
        });

        window.google.accounts.id.renderButton(buttonContainer, {
          theme: 'filled_blue',
          size: 'large',
          width: 300,
        });
        setIsGoogleConfigured(true);
      } catch (err) {
        setIsGoogleConfigured(false);
        setMessage('Google Sign-In is not available for this domain. Please use email login.');
        setMessageType('error');
      }
    };

    return () => {
      if (script.parentNode) {
        script.parentNode.removeChild(script);
      }
    };
  }, [googleClientId]);

  const handleGoogleResponse = async (response) => {
    if (!response?.credential) {
      setMessage('Google did not return a credential. Please try again.');
      setMessageType('error');
      return;
    }

    setLoading(true);
    setMessage('');
    try {
      const res = await api.post('/admin/google-login', {
        token: response.credential,
      });
      const token = extractAdminToken(res.data);
      if (!isUsableToken(token)) {
        throw new Error('Google login response missing token');
      }
      localStorage.setItem('adminToken', token);
      navigate('/admin-no-all-call/dashboard');
    } catch (err) {
      setMessage(getApiErrorMessage(err, 'Login failed. Please try again.'));
      setMessageType('error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex">
      {/* Theme Toggle Button */}
      <button
        onClick={toggleTheme}
        className="fixed top-4 right-4 z-50 p-3 bg-white dark:bg-gray-800 shadow-lg rounded-full hover:shadow-xl transition-all duration-200"
        title="Toggle theme"
      >
        {isDark ? <Sun className="w-5 h-5 text-yellow-500" /> : <Moon className="w-5 h-5 text-indigo-600" />}
      </button>
      {/* Left side - Brand/Gradient */}
      <div className="hidden lg:flex lg:w-1/2 bg-gradient-to-br from-blue-600 via-purple-600 to-indigo-800 dark:from-gray-800 dark:via-gray-900 dark:to-black relative overflow-hidden">
        <div className="absolute inset-0 bg-black bg-opacity-20"></div>
        <div className="relative z-10 flex flex-col justify-center items-center text-white p-12">
          <div className="text-center">
            <h1 className="text-5xl font-bold mb-4">CallTo</h1>
            <p className="text-xl mb-8 opacity-90">Admin Dashboard</p>
            <div className="w-32 h-32 bg-white bg-opacity-20 rounded-full flex items-center justify-center mb-8">
              <div className="w-24 h-24 bg-white bg-opacity-30 rounded-full flex items-center justify-center">
                <div className="text-4xl">📞</div>
              </div>
            </div>
            <p className="text-lg opacity-80">
              Manage your platform with ease and efficiency
            </p>
          </div>
        </div>
        {/* Decorative elements */}
        <div className="absolute top-0 left-0 w-full h-full">
          <div className="absolute top-10 left-10 w-20 h-20 bg-white bg-opacity-10 rounded-full"></div>
          <div className="absolute bottom-20 right-20 w-32 h-32 bg-white bg-opacity-10 rounded-full"></div>
          <div className="absolute top-1/2 left-1/4 w-16 h-16 bg-white bg-opacity-10 rounded-full"></div>
        </div>
      </div>

      {/* Right side - Login Form */}
      <div className="w-full lg:w-1/2 flex items-center justify-center p-8 bg-gray-50 dark:bg-gray-900">
        <div className="w-full max-w-md">
          {/* Header */}
          <div className="text-center mb-8">
            <h2 className="text-3xl font-bold text-gray-900 dark:text-white mb-2">
              {loginMode === 'login' && 'Welcome Back'}
              {loginMode === 'forgot' && 'Reset Password'}
              {loginMode === 'reset' && 'Enter Reset Code'}
            </h2>
            <p className="text-gray-600 dark:text-gray-400">
              {loginMode === 'login' && 'Sign in to your admin account'}
              {loginMode === 'forgot' && 'Enter your email to receive reset code'}
              {loginMode === 'reset' && 'Check your email for the reset code'}
            </p>
          </div>

          {/* Message Display */}
          {message && (
            <div className={`mb-6 p-4 rounded-lg flex items-center space-x-3 ${
              messageType === 'success' 
                ? 'bg-green-50 text-green-800 border border-green-200' 
                : 'bg-red-50 text-red-800 border border-red-200'
            }`}>
              {messageType === 'success' ? (
                <CheckCircle className="w-5 h-5 flex-shrink-0" />
              ) : (
                <XCircle className="w-5 h-5 flex-shrink-0" />
              )}
              <span className="text-sm">{message}</span>
            </div>
          )}

          {/* Login Form */}
          {loginMode === 'login' && (
            <form onSubmit={handleEmailLogin} className="space-y-6">
              {/* Email Field */}
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Email Address
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="email"
                    name="email"
                    value={formData.email}
                    onChange={handleInputChange}
                    autoComplete="username"
                    className={`w-full pl-10 pr-4 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors dark:bg-gray-800 dark:text-white ${
                      errors.email ? 'border-red-300 bg-red-50 dark:bg-red-900/20 dark:border-red-500' : 'border-gray-300 dark:border-gray-600'
                    }`}
                    placeholder="admin@callto.com"
                    disabled={loading}
                  />
                </div>
                {errors.email && (
                  <p className="mt-1 text-sm text-red-600 flex items-center">
                    <AlertCircle className="w-4 h-4 mr-1" />
                    {errors.email}
                  </p>
                )}
              </div>

              {/* Password Field */}
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Password
                </label>
                <div className="relative">
                  <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type={showPassword ? 'text' : 'password'}
                    name="password"
                    value={formData.password}
                    onChange={handleInputChange}
                    autoComplete="current-password"
                    className={`w-full pl-10 pr-12 py-3 border rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors dark:bg-gray-800 dark:text-white ${
                      errors.password ? 'border-red-300 bg-red-50 dark:bg-red-900/20 dark:border-red-500' : 'border-gray-300 dark:border-gray-600'
                    }`}
                    placeholder="Enter your password"
                    disabled={loading}
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-gray-600"
                  >
                    {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                  </button>
                </div>
                {errors.password && (
                  <p className="mt-1 text-sm text-red-600 flex items-center">
                    <AlertCircle className="w-4 h-4 mr-1" />
                    {errors.password}
                  </p>
                )}
              </div>

              {/* Forgot Password Link */}
              <div className="flex justify-end">
                <button
                  type="button"
                  onClick={() => setLoginMode('forgot')}
                  className="text-sm text-blue-600 hover:text-blue-800 transition-colors"
                >
                  Forgot password?
                </button>
              </div>

              {/* Login Button */}
              <button
                type="submit"
                disabled={loading}
                className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold py-3 px-4 rounded-lg transition-colors flex items-center justify-center space-x-2"
              >
                {loading ? (
                  <>
                    <Loader2 className="w-5 h-5 animate-spin" />
                    <span>Signing in...</span>
                  </>
                ) : (
                  <>
                    <span>Sign In</span>
                    <ArrowRight className="w-5 h-5" />
                  </>
                )}
              </button>
            </form>
          )}

          {/* Forgot Password Form */}
          {loginMode === 'forgot' && (
            <form onSubmit={handleForgotPassword} className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Email Address
                </label>
                <div className="relative">
                  <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input
                    type="email"
                    value={resetEmail}
                    onChange={(e) => setResetEmail(e.target.value)}
                    autoComplete="email"
                    className="w-full pl-10 pr-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
                    placeholder="admin@callto.com"
                    disabled={loading}
                  />
                </div>
              </div>

              <div className="space-y-3">
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold py-3 px-4 rounded-lg transition-colors flex items-center justify-center space-x-2"
                >
                  {loading ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      <span>Sending...</span>
                    </>
                  ) : (
                    <span>Send Reset Code</span>
                  )}
                </button>
                <button
                  type="button"
                  onClick={() => setLoginMode('login')}
                  className="w-full bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-3 px-4 rounded-lg transition-colors"
                >
                  Back to Login
                </button>
              </div>
            </form>
          )}

          {/* Reset Password Form */}
          {loginMode === 'reset' && (
            <form onSubmit={handleResetPassword} className="space-y-6">
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Reset Code
                </label>
                <input
                  type="text"
                  value={resetCode}
                  onChange={(e) => setResetCode(e.target.value)}
                  autoComplete="one-time-code"
                  className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
                  placeholder="Enter 6-digit code"
                  disabled={loading}
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  New Password
                </label>
                <input
                  type="password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                  autoComplete="new-password"
                  className="w-full px-4 py-3 border border-gray-300 dark:border-gray-600 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-transparent dark:bg-gray-800 dark:text-white"
                  placeholder="Enter new password"
                  disabled={loading}
                />
              </div>

              <div className="space-y-3">
                <button
                  type="submit"
                  disabled={loading}
                  className="w-full bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold py-3 px-4 rounded-lg transition-colors flex items-center justify-center space-x-2"
                >
                  {loading ? (
                    <>
                      <Loader2 className="w-5 h-5 animate-spin" />
                      <span>Resetting...</span>
                    </>
                  ) : (
                    <span>Reset Password</span>
                  )}
                </button>
                <button
                  type="button"
                  onClick={() => setLoginMode('login')}
                  className="w-full bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-3 px-4 rounded-lg transition-colors"
                >
                  Back to Login
                </button>
              </div>
            </form>
          )}

          {/* Social Login Divider */}
          {loginMode === 'login' && isGoogleConfigured && (
            <>
              <div className="mt-8 mb-6">
                <div className="relative">
                  <div className="absolute inset-0 flex items-center">
                    <div className="w-full border-t border-gray-300 dark:border-gray-700"></div>
                  </div>
                  <div className="relative flex justify-center text-sm">
                    <span className="px-2 bg-gray-50 dark:bg-gray-900 text-gray-500 dark:text-gray-400">Or continue with</span>
                  </div>
                </div>
              </div>

              {/* Google Login Button */}
              <div id="google-signin-button" className="flex justify-center"></div>
              
              {loading && (
                <p className="text-center text-sm mt-4 text-gray-500 dark:text-gray-400">
                  Logging in...
                </p>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
};

export default AdminLogin;


