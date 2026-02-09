import React, { createContext, useContext, useState, useCallback } from 'react';

const NotificationContext = createContext();

export const useNotifications = () => {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error('useNotifications must be used within a NotificationProvider');
  }
  return context;
};

export const NotificationProvider = ({ children }) => {
  const [notifications, setNotifications] = useState([
    { id: 1, title: 'New user registration', message: 'John Doe joined the platform', time: '2 mins ago', read: false, type: 'user' },
    { id: 2, title: 'Listener verification', message: 'Sarah Johnson completed verification', time: '5 mins ago', read: false, type: 'listener' },
    { id: 3, title: 'System update', message: 'Platform maintenance completed', time: '1 hour ago', read: true, type: 'system' },
  ]);

  const markAsRead = useCallback((id) => {
    setNotifications(prev => 
      prev.map(notification => 
        notification.id === id ? { ...notification, read: true } : notification
      )
    );
  }, []);

  const markAllAsRead = useCallback(() => {
    setNotifications(prev => 
      prev.map(notification => ({ ...notification, read: true }))
    );
  }, []);

  const addNotification = useCallback((notification) => {
    const newNotification = {
      id: Date.now(),
      read: false,
      time: 'now',
      ...notification
    };
    setNotifications(prev => [newNotification, ...prev]);
  }, []);

  const unreadCount = notifications.filter(n => !n.read).length;

  return (
    <NotificationContext.Provider value={{ 
      notifications, 
      markAsRead, 
      markAllAsRead, 
      addNotification, 
      unreadCount 
    }}>
      {children}
    </NotificationContext.Provider>
  );
};