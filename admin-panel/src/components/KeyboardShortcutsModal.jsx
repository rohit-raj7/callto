import React from 'react';
import { useKeyboardShortcuts } from '../contexts/KeyboardShortcutContext';
import { X, Keyboard } from 'lucide-react';

const KeyboardShortcutsModal = () => {
  const { shortcuts, showShortcuts, setShowShortcuts } = useKeyboardShortcuts();

  if (!showShortcuts) return null;

  return (
    <>
      <div 
        className="fixed inset-0 bg-black bg-opacity-50 z-50 flex items-center justify-center p-4"
        onClick={() => setShowShortcuts(false)}
      >
        <div 
          className="bg-white dark:bg-gray-800 rounded-lg shadow-2xl max-w-2xl w-full p-6"
          onClick={(e) => e.stopPropagation()}
        >
          <div className="flex items-center justify-between mb-6">
            <div className="flex items-center space-x-3">
              <div className="p-2 bg-blue-100 dark:bg-blue-900/30 rounded-lg">
                <Keyboard className="w-6 h-6 text-blue-600 dark:text-blue-400" />
              </div>
              <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
                Keyboard Shortcuts
              </h2>
            </div>
            <button
              onClick={() => setShowShortcuts(false)}
              className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700"
            >
              <X className="w-5 h-5" />
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {Object.entries(shortcuts).map(([key, description]) => (
              <div 
                key={key}
                className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-700/50 rounded-lg"
              >
                <span className="text-gray-700 dark:text-gray-300">{description}</span>
                <kbd className="px-3 py-1 bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 rounded text-sm font-mono text-gray-900 dark:text-white">
                  {key.split('+').map(k => k.charAt(0).toUpperCase() + k.slice(1)).join(' + ')}
                </kbd>
              </div>
            ))}
          </div>

          <div className="mt-6 p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg">
            <p className="text-sm text-blue-800 dark:text-blue-200">
              <strong>Tip:</strong> Press <kbd className="px-2 py-1 bg-blue-100 dark:bg-blue-800 rounded text-xs">Ctrl + /</kbd> anytime to show this dialog
            </p>
          </div>
        </div>
      </div>
    </>
  );
};

export default KeyboardShortcutsModal;