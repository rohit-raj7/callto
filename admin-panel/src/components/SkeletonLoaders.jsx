import React from 'react';
import { motion } from 'framer-motion';
import clsx from 'clsx';

// Skeleton for Profile Card
export const ProfileCardSkeleton = ({ className }) => {
  return (
    <div className={clsx('bg-white dark:bg-gray-800 rounded-2xl shadow-lg p-6', className)}>
      <div className="animate-pulse">
        {/* Avatar and basic info */}
        <div className="flex items-start space-x-4 mb-4">
          <div className="w-16 h-16 bg-gray-200 dark:bg-gray-700 rounded-full" />
          <div className="flex-1">
            <div className="h-5 bg-gray-200 dark:bg-gray-700 rounded w-32 mb-2" />
            <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-24" />
          </div>
        </div>

        {/* Bio */}
        <div className="space-y-2 mb-4">
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-full" />
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-4/5" />
        </div>

        {/* Interests */}
        <div className="flex gap-2 mb-4">
          <div className="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-20" />
          <div className="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-24" />
          <div className="h-6 bg-gray-200 dark:bg-gray-700 rounded-full w-16" />
        </div>

        {/* Bottom section */}
        <div className="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-700">
          <div className="w-20 h-20 bg-gray-200 dark:bg-gray-700 rounded-full" />
          <div className="h-10 bg-gray-200 dark:bg-gray-700 rounded-lg w-28" />
        </div>
      </div>
    </div>
  );
};

// Skeleton for User List Item
export const UserListItemSkeleton = ({ className }) => {
  return (
    <div className={clsx('bg-white dark:bg-gray-800 rounded-lg shadow p-4', className)}>
      <div className="flex items-center space-x-4 animate-pulse">
        <div className="w-12 h-12 bg-gray-200 dark:bg-gray-700 rounded-full flex-shrink-0" />
        <div className="flex-1">
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-32 mb-2" />
          <div className="h-3 bg-gray-200 dark:bg-gray-700 rounded w-24" />
        </div>
        <div className="h-8 bg-gray-200 dark:bg-gray-700 rounded w-20" />
      </div>
    </div>
  );
};

// Skeleton for Chat Message
export const ChatMessageSkeleton = ({ align = 'left', className }) => {
  return (
    <div className={clsx('flex', align === 'right' ? 'justify-end' : 'justify-start', className)}>
      <div className="animate-pulse max-w-xs">
        <div className="flex items-end space-x-2">
          {align === 'left' && <div className="w-8 h-8 bg-gray-200 dark:bg-gray-700 rounded-full flex-shrink-0" />}
          <div>
            <div className={clsx(
              'h-16 rounded-2xl',
              align === 'right'
                ? 'bg-indigo-200 dark:bg-indigo-900/30 w-48'
                : 'bg-gray-200 dark:bg-gray-700 w-56'
            )} />
            <div className="h-3 bg-gray-200 dark:bg-gray-700 rounded w-16 mt-1" />
          </div>
        </div>
      </div>
    </div>
  );
};

// Skeleton with Shimmer Effect
export const ShimmerSkeleton = ({ className, width = 'w-full', height = 'h-4' }) => {
  return (
    <div className={clsx('relative overflow-hidden bg-gray-200 dark:bg-gray-700 rounded', width, height, className)}>
      <div className="absolute inset-0 -translate-x-full animate-shimmer bg-gradient-to-r from-transparent via-white/20 to-transparent" />
    </div>
  );
};

// Skeleton for Table Row
export const TableRowSkeleton = ({ columns = 4, className }) => {
  return (
    <tr className={clsx('animate-pulse', className)}>
      {Array.from({ length: columns }).map((_, index) => (
        <td key={index} className="px-6 py-4">
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded" />
        </td>
      ))}
    </tr>
  );
};

// Skeleton for Grid Layout
export const GridSkeleton = ({ count = 6, children, className }) => {
  return (
    <div className={clsx('grid gap-6', className)}>
      {Array.from({ length: count }).map((_, index) => (
        <React.Fragment key={index}>
          {children || <ProfileCardSkeleton />}
        </React.Fragment>
      ))}
    </div>
  );
};

// Loading Spinner
export const LoadingSpinner = ({ size = 'md', className }) => {
  const sizeClasses = {
    sm: 'w-4 h-4',
    md: 'w-8 h-8',
    lg: 'w-12 h-12',
    xl: 'w-16 h-16',
  };

  return (
    <div className={clsx('flex items-center justify-center', className)}>
      <motion.div
        animate={{ rotate: 360 }}
        transition={{ duration: 1, repeat: Infinity, ease: 'linear' }}
        className={clsx(
          'border-4 border-gray-200 dark:border-gray-700 border-t-indigo-600 rounded-full',
          sizeClasses[size]
        )}
      />
    </div>
  );
};

// Full Page Loading
export const PageLoader = ({ message = 'Loading...' }) => {
  return (
    <div className="fixed inset-0 bg-white/80 dark:bg-gray-900/80 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="text-center">
        <LoadingSpinner size="xl" className="mb-4" />
        <p className="text-lg text-gray-600 dark:text-gray-400">{message}</p>
      </div>
    </div>
  );
};

// Skeleton for Discovery Page Filters
export const FilterSidebarSkeleton = () => {
  return (
    <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 space-y-6">
      <div className="animate-pulse">
        <div className="h-6 bg-gray-200 dark:bg-gray-700 rounded w-24 mb-4" />
        
        {/* Age Range */}
        <div className="mb-6">
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-20 mb-2" />
          <div className="h-10 bg-gray-200 dark:bg-gray-700 rounded" />
        </div>

        {/* Location */}
        <div className="mb-6">
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-24 mb-2" />
          <div className="h-10 bg-gray-200 dark:bg-gray-700 rounded" />
        </div>

        {/* Interests */}
        <div>
          <div className="h-4 bg-gray-200 dark:bg-gray-700 rounded w-20 mb-2" />
          <div className="flex flex-wrap gap-2">
            {[1, 2, 3, 4, 5, 6].map((i) => (
              <div key={i} className="h-8 bg-gray-200 dark:bg-gray-700 rounded-full w-20" />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
};

export default {
  ProfileCardSkeleton,
  UserListItemSkeleton,
  ChatMessageSkeleton,
  ShimmerSkeleton,
  TableRowSkeleton,
  GridSkeleton,
  LoadingSpinner,
  PageLoader,
  FilterSidebarSkeleton,
};
