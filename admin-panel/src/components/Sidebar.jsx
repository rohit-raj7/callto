import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Home, Users, Headphones, Bell, Sun, Moon, Search, Menu, X, LogOut, Settings, ChevronLeft, ChevronRight, Contact, Trash2, CreditCard, Star } from 'lucide-react';
import { useTheme } from '../contexts/ThemeContext';
import { useNotifications } from '../contexts/NotificationContext';
import NotificationCenter from './NotificationCenter';
import CommandPalette from './CommandPalette';

const Sidebar = () => {
  const navigate = useNavigate();
  const location = useLocation();
  const { isDark, toggleTheme } = useTheme();
  const { unreadCount } = useNotifications();
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [isMobileOpen, setIsMobileOpen] = useState(false);
  const [showNotifications, setShowNotifications] = useState(false);
  const [showSearch, setShowSearch] = useState(false);

  const menuItems = [
    { id: 'dashboard', label: 'Dashboard', icon: Home, path: '/admin-no-all-call/dashboard', shortcut: 'G D' },
    { id: 'users', label: 'Users', icon: Users, path: '/admin-no-all-call/users', shortcut: 'G U' },
    { id: 'listeners', label: 'Listeners', icon: Headphones, path: '/admin-no-all-call/listeners', shortcut: 'G L' },
    { id: 'listener-rates', label: 'Listener Rates', icon: Settings, path: '/admin-no-all-call/listener-rates', shortcut: 'G S' },
    { id: 'call-rate-config', label: 'Call Rate Config', icon: Settings, path: '/admin-no-all-call/call-rate-config', shortcut: 'G O' },
    { id: 'chat-charge-config', label: 'Chat Config', icon: Settings, path: '/admin-no-all-call/chat-charge-config', shortcut: 'G H' },
    { id: 'recharge-packs', label: 'Recharge Packs', icon: CreditCard, path: '/admin-no-all-call/recharge-packs', shortcut: 'G P' },
    { id: 'offer-banner', label: 'Offer Banner', icon: Settings, path: '/admin-no-all-call/offer-banner', shortcut: 'G B' },
    { id: 'user-contacts', label: 'User Contacts', icon: Contact, path: '/admin-no-all-call/user-contacts', shortcut: 'G C' },
    { id: 'send-notification', label: 'Send Notification', icon: Bell, path: '/admin-no-all-call/send-notification', shortcut: 'G N' },
    { id: 'contact-messages', label: 'Contact Messages', icon: Contact, path: '/admin-no-all-call/contact-messages', shortcut: 'G M' },
    { id: 'app-ratings', label: 'App Ratings', icon: Star, path: '/admin-no-all-call/app-ratings', shortcut: 'G A' },
    { id: 'delete-requests', label: 'Delete Requests', icon: Trash2, path: '/admin-no-all-call/delete-requests', shortcut: 'G R' },
  ];

  const handleNavigate = (path) => {
    navigate(path);
    setIsMobileOpen(false);
  };

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    navigate('/admin-no-all-call');
  };

  const handleSearchOpen = (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
      e.preventDefault();
      setShowSearch(true);
    }
  };

  React.useEffect(() => {
    document.addEventListener('keydown', handleSearchOpen);
    return () => document.removeEventListener('keydown', handleSearchOpen);
  }, []);

  return (
    <>
      {/* Mobile Overlay */}
      {isMobileOpen && (
        <div 
          className="fixed inset-0 bg-black bg-opacity-50 z-40 lg:hidden"
          onClick={() => setIsMobileOpen(false)}
        />
      )}

      {/* Mobile Header */}
      <div className="lg:hidden fixed top-0 left-0 right-0 bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 z-30 px-4 py-3 flex items-center justify-between">
        <div className="flex items-center space-x-3">
          <button
            onClick={() => setIsMobileOpen(!isMobileOpen)}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            {isMobileOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
          </button>
          <h1 className="text-xl font-bold">CallTo Admin</h1>
        </div>
        <div className="flex items-center space-x-2">
          <button
            onClick={() => setShowSearch(true)}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <Search className="w-5 h-5" />
          </button>
          <button
            onClick={toggleTheme}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
          </button>
          <button
            onClick={() => setShowNotifications(!showNotifications)}
            className="relative p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
          >
            <Bell className="w-5 h-5" />
            {unreadCount > 0 && (
              <span className="absolute top-1 right-1 w-2 h-2 bg-red-500 rounded-full"></span>
            )}
          </button>
        </div>
      </div>

      {/* Desktop Sidebar */}
      <aside
        className={`hidden lg:flex fixed left-0 top-0 h-screen bg-white dark:bg-gray-800 border-r border-gray-200 dark:border-gray-700 flex-col transition-all duration-300 z-30 ${
          isCollapsed ? 'w-20' : 'w-64'
        }`}
      >
        {/* Logo & Collapse Button */}
        <div className="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
          {!isCollapsed && (
            <h1 className="text-xl font-bold text-gray-900 dark:text-white">CallTo Admin</h1>
          )}
          <button
            onClick={() => setIsCollapsed(!isCollapsed)}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 ml-auto"
            title={isCollapsed ? 'Expand' : 'Collapse'}
          >
            {isCollapsed ? <ChevronRight className="w-5 h-5" /> : <ChevronLeft className="w-5 h-5" />}
          </button>
        </div>

        {/* Search */}
        <div className="p-4">
          <button
            onClick={() => setShowSearch(true)}
            className={`w-full flex items-center space-x-3 px-3 py-2 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors ${
              isCollapsed ? 'justify-center' : ''
            }`}
            title="Search (Ctrl+K)"
          >
            <Search className="w-5 h-5" />
            {!isCollapsed && (
              <>
                <span className="flex-1 text-left text-sm">Search...</span>
                <span className="text-xs bg-gray-200 dark:bg-gray-600 px-2 py-1 rounded">⌘K</span>
              </>
            )}
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 px-3 py-2 space-y-1 overflow-y-auto overflow-x-hidden overscroll-contain scroll-smooth [scrollbar-gutter:stable] [scrollbar-width:thin] [&::-webkit-scrollbar]:w-1.5 [&::-webkit-scrollbar-track]:bg-transparent [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-gray-300 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600">
          {menuItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <button
                key={item.id}
                onClick={() => handleNavigate(item.path)}
                className={`w-full flex items-center space-x-3 px-3 py-2 rounded-lg transition-colors group relative ${
                  isActive
                    ? 'bg-blue-500 text-white'
                    : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
                } ${isCollapsed ? 'justify-center' : ''}`}
                title={isCollapsed ? `${item.label} (${item.shortcut})` : ''}
              >
                <item.icon className="w-5 h-5" />
                {!isCollapsed && (
                  <>
                    <span className="flex-1 text-left">{item.label}</span>
                    <span className="text-xs opacity-60">{item.shortcut}</span>
                  </>
                )}
                {isActive && (
                  <div className="absolute left-0 top-0 bottom-0 w-1 bg-blue-600 rounded-r"></div>
                )}
              </button>
            );
          })}
        </nav>

        {/* Bottom Actions */}
        <div className="p-4 border-t border-gray-200 dark:border-gray-700 space-y-2">
          <button
            onClick={toggleTheme}
            className={`w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
              isCollapsed ? 'justify-center' : ''
            }`}
            title="Toggle theme"
          >
            {isDark ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            {!isCollapsed && <span>Toggle Theme</span>}
          </button>
          
          <button
            onClick={() => setShowNotifications(!showNotifications)}
            className={`w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors relative ${
              isCollapsed ? 'justify-center' : ''
            }`}
            title="Notifications"
          >
            <Bell className="w-5 h-5" />
            {!isCollapsed && <span>Notifications</span>}
            {unreadCount > 0 && (
              <span className={`${isCollapsed ? 'absolute top-1 right-1' : ''} flex items-center justify-center min-w-[20px] h-5 px-1 bg-red-500 text-white text-xs rounded-full`}>
                {unreadCount}
              </span>
            )}
          </button>

          <button
            onClick={handleLogout}
            className={`w-full flex items-center space-x-3 px-3 py-2 rounded-lg text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors ${
              isCollapsed ? 'justify-center' : ''
            }`}
            title="Logout"
          >
            <LogOut className="w-5 h-5" />
            {!isCollapsed && <span>Logout</span>}
          </button>
        </div>
      </aside>

      {/* Mobile Sidebar */}
      <aside
        className={`lg:hidden fixed left-0 top-0 h-screen bg-white dark:bg-gray-800 w-64 flex flex-col transition-transform duration-300 z-50 ${
          isMobileOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <h1 className="text-xl font-bold text-gray-900 dark:text-white">CallTo Admin</h1>
        </div>

        <nav className="flex-1 px-3 py-2 space-y-1 overflow-y-auto overflow-x-hidden overscroll-contain scroll-smooth [scrollbar-gutter:stable] [scrollbar-width:thin] [&::-webkit-scrollbar]:w-1.5 [&::-webkit-scrollbar-track]:bg-transparent [&::-webkit-scrollbar-thumb]:rounded-full [&::-webkit-scrollbar-thumb]:bg-gray-300 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600">
          {menuItems.map((item) => {
            const isActive = location.pathname === item.path;
            return (
              <button
                key={item.id}
                onClick={() => handleNavigate(item.path)}
                className={`w-full flex items-center space-x-3 px-3 py-3 rounded-lg transition-colors ${
                  isActive
                    ? 'bg-blue-500 text-white'
                    : 'text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
                }`}
              >
                <item.icon className="w-6 h-6" />
                <span className="flex-1 text-left">{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className="p-4 border-t border-gray-200 dark:border-gray-700 space-y-2">
          <button
            onClick={handleLogout}
            className="w-full flex items-center space-x-3 px-3 py-3 rounded-lg text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors"
          >
            <LogOut className="w-6 h-6" />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* Notification Center */}
      {showNotifications && (
        <NotificationCenter onClose={() => setShowNotifications(false)} />
      )}

      {/* Command Palette */}
      {showSearch && (
        <CommandPalette onClose={() => setShowSearch(false)} />
      )}
    </>
  );
};

export default Sidebar;
