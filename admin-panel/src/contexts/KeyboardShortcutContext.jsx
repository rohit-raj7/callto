import React, { createContext, useContext, useState, useCallback, useEffect } from 'react';

const KeyboardShortcutContext = createContext();

export const useKeyboardShortcuts = () => {
  const context = useContext(KeyboardShortcutContext);
  if (!context) {
    throw new Error('useKeyboardShortcuts must be used within a KeyboardShortcutProvider');
  }
  return context;
};

export const KeyboardShortcutProvider = ({ children }) => {
  const [shortcuts] = useState({
    'ctrl+k': 'Open search',
    'ctrl+/': 'Show shortcuts',
    'esc': 'Close modals',
    'ctrl+d': 'Toggle dark mode',
    'g d': 'Go to dashboard',
    'g u': 'Go to users',
    'g l': 'Go to listeners',
    'g b': 'Go to offer banner'
  });

  const [showShortcuts, setShowShortcuts] = useState(false);

  const handleKeyDown = useCallback((event) => {
    // Handle global keyboard shortcuts
    const key = event.key.toLowerCase();
    const ctrlOrCmd = event.ctrlKey || event.metaKey;
    
    if (ctrlOrCmd && key === '/') {
      event.preventDefault();
      setShowShortcuts(true);
    }
    
    if (key === 'escape') {
      setShowShortcuts(false);
    }
  }, []);

  useEffect(() => {
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [handleKeyDown]);

  return (
    <KeyboardShortcutContext.Provider value={{ 
      shortcuts, 
      showShortcuts, 
      setShowShortcuts 
    }}>
      {children}
    </KeyboardShortcutContext.Provider>
  );
};
