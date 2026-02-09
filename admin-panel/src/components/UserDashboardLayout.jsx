import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Home, Phone, MessageCircle, Clock, Settings, User,
  Bell, Search, Menu, X, LogOut, Shuffle, HelpCircle, Wallet,
  Globe, Mail
} from 'lucide-react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import clsx from 'clsx';
import NotificationDropdown from '../components/NotificationDropdown';
import SearchAutocomplete from '../components/SearchAutocomplete';

const UserDashboardLayout = ({ children }) => {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();

  // Navigation items - matching mobile app features
  const navigationItems = [
    { name: 'Home', href: '/dashboard', icon: Home },
    { name: 'Call', href: '/call', icon: Phone },
    { name: 'Random Call', href: '/random-call', icon: Shuffle },
    { name: 'Chat', href: '/chat', icon: MessageCircle },
    { name: 'Recents', href: '/recents', icon: Clock },
    { name: 'Profile', href: '/profile', icon: User },
    { name: 'Wallet', href: '/wallet', icon: Wallet },
    { name: 'Language', href: '/language', icon: Globe },
    { name: 'Contact Us', href: '/contact', icon: Mail },
    { name: 'FAQs', href: '/faqs', icon: HelpCircle },
    { name: 'Settings', href: '/settings', icon: Settings },
  ];

  const handleSearch = (query) => {
    console.log('Search:', query);
    // Navigate to search results or filter current page
  };

  const handleLogout = () => {
    // Handle logout logic
    navigate('/');
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      {/* Mobile sidebar backdrop */}
      <AnimatePresence>
        {sidebarOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            onClick={() => setSidebarOpen(false)}
            className="fixed inset-0 bg-black/50 backdrop-blur-sm z-40 lg:hidden"
          />
        )}
      </AnimatePresence>

      {/* Sidebar */}
      <motion.div
        initial={{ x: -320 }}
        animate={{ x: sidebarOpen ? 0 : -320 }}
        transition={{ type: 'spring', damping: 25, stiffness: 200 }}
        className="fixed inset-y-0 left-0 z-50 w-80 bg-white dark:bg-gray-800 shadow-2xl lg:translate-x-0 lg:static lg:inset-0"
      >
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="flex items-center justify-center h-16 px-6 border-b border-gray-200 dark:border-gray-700">
            <Link to="/dashboard" className="flex items-center space-x-2 group">
              <div className="bg-gradient-to-r from-pink-500 to-rose-500 p-2 rounded-lg group-hover:scale-110 transition-transform">
                <Phone className="w-6 h-6 text-white" />
              </div>
              <span className="text-xl font-bold bg-gradient-to-r from-pink-500 to-rose-500 bg-clip-text text-transparent">
                Callto
              </span>
            </Link>
          </div>

          {/* User Profile Section */}
          <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700">
            <div className="flex items-center space-x-3">
              <img
                src="https://ui-avatars.com/api/?name=User&size=48&background=FCE4EC&color=EC4899"
                alt="Profile"
                className="w-12 h-12 rounded-full ring-2 ring-pink-200 dark:ring-pink-800"
              />
              <div className="flex-1 min-w-0">
                <p className="text-sm font-semibold text-gray-900 dark:text-white truncate">
                  User
                </p>
                <div className="flex items-center space-x-2">
                  <span className="text-xs bg-pink-100 dark:bg-pink-900/30 text-pink-600 dark:text-pink-400 px-2 py-0.5 rounded-full">
                    ₹0.00
                  </span>
                </div>
              </div>
            </div>
          </div>

          {/* Navigation */}
          <nav className="flex-1 px-4 py-6 space-y-1 overflow-y-auto">
            {navigationItems.map((item) => {
              const isActive = location.pathname === item.href;
              return (
                <Link
                  key={item.name}
                  to={item.href}
                  onClick={() => setSidebarOpen(false)}
                  className={clsx(
                    'flex items-center space-x-3 px-4 py-2.5 rounded-lg font-medium transition-all group',
                    isActive
                      ? 'bg-pink-50 dark:bg-pink-900/30 text-pink-600 dark:text-pink-400 border-r-2 border-pink-500'
                      : 'text-gray-700 dark:text-gray-300 hover:bg-pink-50 dark:hover:bg-pink-900/20 hover:text-pink-600 dark:hover:text-pink-400'
                  )}
                >
                  <item.icon
                    className={clsx(
                      'w-5 h-5 transition-colors',
                      isActive
                        ? 'text-pink-600 dark:text-pink-400'
                        : 'text-gray-500 dark:text-gray-400 group-hover:text-pink-500 dark:group-hover:text-pink-400'
                    )}
                  />
                  <span>{item.name}</span>
                </Link>
              );
            })}
          </nav>

          {/* Logout */}
          <div className="px-4 py-6 border-t border-gray-200 dark:border-gray-700">
            <button
              onClick={handleLogout}
              className="flex items-center space-x-3 w-full px-4 py-3 text-left text-gray-700 dark:text-gray-300 hover:bg-red-50 dark:hover:bg-red-900/20 hover:text-red-600 dark:hover:text-red-400 rounded-lg font-medium transition-all group"
            >
              <LogOut className="w-5 h-5 text-gray-500 dark:text-gray-400 group-hover:text-red-600 dark:group-hover:text-red-400" />
              <span>Logout</span>
            </button>
          </div>
        </div>
      </motion.div>

      {/* Main Content */}
      <div className="lg:pl-0">
        {/* Top Header */}
        <header className="bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700 lg:hidden">
          <div className="px-4 py-4">
            <div className="flex items-center justify-between">
              {/* Mobile menu button */}
              <button
                onClick={() => setSidebarOpen(true)}
                className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
              >
                <Menu className="w-6 h-6 text-gray-700 dark:text-gray-300" />
              </button>

              {/* Logo */}
              <Link to="/dashboard" className="flex items-center space-x-2">
                <div className="bg-gradient-to-r from-pink-500 to-rose-500 p-2 rounded-lg">
                  <Phone className="w-5 h-5 text-white" />
                </div>
                <span className="text-lg font-bold bg-gradient-to-r from-pink-500 to-rose-500 bg-clip-text text-transparent">
                  Callto
                </span>
              </Link>

              {/* Notifications */}
              <NotificationDropdown />
            </div>
          </div>
        </header>

        {/* Desktop Header */}
        <header className="hidden lg:block bg-white dark:bg-gray-800 shadow-sm border-b border-gray-200 dark:border-gray-700">
          <div className="px-8 py-4">
            <div className="flex items-center justify-between">
              {/* Search */}
              <div className="flex-1 max-w-md">
                <SearchAutocomplete
                  onSearch={handleSearch}
                  placeholder="Search people, interests..."
                />
              </div>

              {/* Right side actions */}
              <div className="flex items-center space-x-4">
                {/* Notifications */}
                <NotificationDropdown />

                {/* User menu */}
                <div className="relative">
                  <button className="flex items-center space-x-2 p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors">
                    <img
                      src="https://ui-avatars.com/api/?name=John+Doe&size=32&background=random"
                      alt="Profile"
                      className="w-8 h-8 rounded-full"
                    />
                    <span className="hidden xl:block text-sm font-medium text-gray-700 dark:text-gray-300">
                      John Doe
                    </span>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1">
          {children}
        </main>
      </div>
    </div>
  );
};

export default UserDashboardLayout;
