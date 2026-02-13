import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { Search, Home, Users, Headphones, ArrowRight, Hash, Contact, Bell, Percent } from 'lucide-react';
import Fuse from 'fuse.js';

const CommandPalette = ({ onClose }) => {
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const [selected, setSelected] = useState(0);
  const inputRef = useRef(null);

  const items = [
    { id: 1, type: 'page', title: 'Dashboard', icon: Home, path: '/admin-no-all-call/dashboard', keywords: ['home', 'overview'] },
    { id: 2, type: 'page', title: 'Users Management', icon: Users, path: '/admin-no-all-call/users', keywords: ['users', 'customers'] },
    { id: 3, type: 'page', title: 'Listeners Management', icon: Headphones, path: '/admin-no-all-call/listeners', keywords: ['listeners', 'agents'] },
    { id: 4, type: 'page', title: 'User Contacts', icon: Contact, path: '/admin-no-all-call/user-contacts', keywords: ['contacts', 'support'] },
    { id: 5, type: 'page', title: 'Send Notification', icon: Bell, path: '/admin-no-all-call/send-notification', keywords: ['notification', 'push', 'alert'] },
    { id: 6, type: 'page', title: 'Offer Banner', icon: Percent, path: '/admin-no-all-call/offer-banner', keywords: ['offer', 'banner', 'discount'] },
    { id: 7, type: 'action', title: 'Toggle Dark Mode', icon: Hash, action: 'theme', keywords: ['dark', 'light', 'theme'] },
    { id: 8, type: 'user', title: 'John Doe', subtitle: 'john@example.com', path: '/admin-no-all-call/users', keywords: ['john'] },
    { id: 9, type: 'user', title: 'Sarah Smith', subtitle: 'sarah@example.com', path: '/admin-no-all-call/users', keywords: ['sarah'] },
    { id: 10, type: 'listener', title: 'Mike Johnson', subtitle: 'Professional Listener', path: '/admin-no-all-call/listeners', keywords: ['mike'] },
  ];

  const fuse = new Fuse(items, {
    keys: ['title', 'subtitle', 'keywords'],
    threshold: 0.3,
  });

  const results = query ? fuse.search(query).map(r => r.item) : items.slice(0, 5);

  const handleSelect = React.useCallback((item) => {
    if (item.path) {
      navigate(item.path);
    } else if (item.action === 'theme') {
      // Toggle theme action
      document.dispatchEvent(new KeyboardEvent('keydown', { key: 'd', ctrlKey: true }));
    }
    onClose();
  }, [navigate, onClose]);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') {
        onClose();
      } else if (e.key === 'ArrowDown') {
        e.preventDefault();
        setSelected((prev) => (prev + 1) % results.length);
      } else if (e.key === 'ArrowUp') {
        e.preventDefault();
        setSelected((prev) => (prev - 1 + results.length) % results.length);
      } else if (e.key === 'Enter' && results[selected]) {
        e.preventDefault();
        handleSelect(results[selected]);
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [selected, results, onClose, handleSelect]);

  return (
    <>
      <div 
        className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-start justify-center pt-[20vh]"
        onClick={onClose}
      >
        <div 
          className="w-full max-w-2xl mx-4 bg-white dark:bg-gray-800 rounded-lg shadow-2xl overflow-hidden"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Search Input */}
          <div className="flex items-center px-4 py-3 border-b border-gray-200 dark:border-gray-700">
            <Search className="w-5 h-5 text-gray-400" />
            <input
              ref={inputRef}
              type="text"
              value={query}
              onChange={(e) => {
                setQuery(e.target.value);
                setSelected(0);
              }}
              placeholder="Search for anything..."
              className="flex-1 ml-3 bg-transparent border-none outline-none text-gray-900 dark:text-white placeholder-gray-400"
            />
            <span className="text-xs text-gray-400 bg-gray-100 dark:bg-gray-700 px-2 py-1 rounded">
              ESC
            </span>
          </div>

          {/* Results */}
          <div className="max-h-96 overflow-y-auto">
            {results.length === 0 ? (
              <div className="p-8 text-center text-gray-500 dark:text-gray-400">
                <Search className="w-12 h-12 mx-auto mb-2 opacity-50" />
                <p>No results found</p>
              </div>
            ) : (
              <div className="py-2">
                {results.map((item, index) => {
                  const Icon = item.icon || Hash;
                  return (
                    <button
                      key={item.id}
                      onClick={() => handleSelect(item)}
                      className={`w-full flex items-center px-4 py-3 transition-colors ${
                        index === selected
                          ? 'bg-blue-50 dark:bg-blue-900/20'
                          : 'hover:bg-gray-50 dark:hover:bg-gray-700/50'
                      }`}
                      onMouseEnter={() => setSelected(index)}
                    >
                      <div className={`p-2 rounded-lg ${
                        item.type === 'page' ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-600' :
                        item.type === 'user' ? 'bg-green-100 dark:bg-green-900/30 text-green-600' :
                        item.type === 'listener' ? 'bg-purple-100 dark:bg-purple-900/30 text-purple-600' :
                        'bg-gray-100 dark:bg-gray-700 text-gray-600'
                      }`}>
                        <Icon className="w-4 h-4" />
                      </div>
                      <div className="ml-3 flex-1 text-left">
                        <p className="text-sm font-medium text-gray-900 dark:text-white">
                          {item.title}
                        </p>
                        {item.subtitle && (
                          <p className="text-xs text-gray-500 dark:text-gray-400">
                            {item.subtitle}
                          </p>
                        )}
                      </div>
                      <ArrowRight className="w-4 h-4 text-gray-400" />
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Footer */}
          <div className="px-4 py-2 bg-gray-50 dark:bg-gray-700/50 border-t border-gray-200 dark:border-gray-700 flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
            <div className="flex items-center space-x-4">
              <span><kbd className="px-2 py-1 bg-white dark:bg-gray-800 rounded">↑↓</kbd> Navigate</span>
              <span><kbd className="px-2 py-1 bg-white dark:bg-gray-800 rounded">↵</kbd> Select</span>
            </div>
            <span><kbd className="px-2 py-1 bg-white dark:bg-gray-800 rounded">ESC</kbd> Close</span>
          </div>
        </div>
      </div>
    </>
  );
};

export default CommandPalette;
