import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { MapPin, Heart, MessageCircle, Loader2 } from 'lucide-react';
import clsx from 'clsx';

// Circular progress component for compatibility score
const CompatibilityScore = ({ score }) => {
  const radius = 35;
  const circumference = 2 * Math.PI * radius;
  const offset = circumference - (score / 100) * circumference;

  const getColor = (score) => {
    if (score >= 80) return '#10b981'; // green
    if (score >= 60) return '#f59e0b'; // orange
    return '#ef4444'; // red
  };

  return (
    <div className="relative w-20 h-20">
      <svg className="transform -rotate-90 w-20 h-20">
        <circle
          cx="40"
          cy="40"
          r={radius}
          stroke="currentColor"
          strokeWidth="6"
          fill="transparent"
          className="text-gray-200 dark:text-gray-700"
        />
        <motion.circle
          cx="40"
          cy="40"
          r={radius}
          stroke={getColor(score)}
          strokeWidth="6"
          fill="transparent"
          strokeDasharray={circumference}
          initial={{ strokeDashoffset: circumference }}
          animate={{ strokeDashoffset: offset }}
          transition={{ duration: 1, ease: 'easeOut' }}
          strokeLinecap="round"
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        <span className="text-lg font-bold text-gray-900 dark:text-white">
          {score}%
        </span>
      </div>
    </div>
  );
};

// Main Profile Card Component
const ProfileCard = ({
  user,
  onConnect,
  onViewProfile,
  className,
}) => {
  const [isConnecting, setIsConnecting] = useState(false);
  const [isFavorited, setIsFavorited] = useState(false);

  const handleConnect = async (e) => {
    e.stopPropagation();
    setIsConnecting(true);
    
    // Simulate API call
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    if (onConnect) {
      onConnect(user);
    }
    setIsConnecting(false);
  };

  const handleFavorite = (e) => {
    e.stopPropagation();
    setIsFavorited(!isFavorited);
  };

  const displayedInterests = user.interests?.slice(0, 3) || [];
  const remainingCount = (user.interests?.length || 0) - 3;

  return (
    <motion.div
      whileHover={{ y: -8, scale: 1.02 }}
      transition={{ type: 'spring', stiffness: 300, damping: 20 }}
      onClick={onViewProfile ? () => onViewProfile(user) : undefined}
      className={clsx(
        'bg-white dark:bg-gray-800 rounded-2xl shadow-lg hover:shadow-2xl transition-all cursor-pointer overflow-hidden',
        className
      )}
    >
      {/* Card Content */}
      <div className="p-6">
        {/* Top Section - Avatar and Basic Info */}
        <div className="flex items-start space-x-4 mb-4">
          {/* Avatar with online status */}
          <div className="relative flex-shrink-0">
            <img
              src={user.avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(user.name)}&size=64&background=random`}
              alt={user.name}
              className="w-16 h-16 rounded-full object-cover ring-2 ring-white dark:ring-gray-700"
            />
            {user.isOnline && (
              <motion.div
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                className="absolute bottom-0 right-0 w-4 h-4 bg-green-500 rounded-full ring-2 ring-white dark:ring-gray-800"
              />
            )}
          </div>

          {/* Name, Age, Location */}
          <div className="flex-1 min-w-0">
            <div className="flex items-center space-x-2 mb-1">
              <h3 className="text-lg font-bold text-gray-900 dark:text-white truncate">
                {user.name}
              </h3>
              {user.age && (
                <span className="text-gray-600 dark:text-gray-400 text-sm">
                  {user.age}
                </span>
              )}
            </div>
            
            {user.location && (
              <div className="flex items-center text-sm text-gray-600 dark:text-gray-400">
                <MapPin className="w-4 h-4 mr-1 flex-shrink-0" />
                <span className="truncate">{user.location}</span>
              </div>
            )}
          </div>

          {/* Favorite Button */}
          <motion.button
            whileTap={{ scale: 0.9 }}
            onClick={handleFavorite}
            className="flex-shrink-0 p-2 rounded-full hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
          >
            <Heart
              className={clsx(
                'w-5 h-5 transition-colors',
                isFavorited
                  ? 'fill-red-500 text-red-500'
                  : 'text-gray-400 dark:text-gray-500'
              )}
            />
          </motion.button>
        </div>

        {/* Bio */}
        {user.bio && (
          <p className="text-sm text-gray-600 dark:text-gray-400 mb-4 line-clamp-2">
            {user.bio}
          </p>
        )}

        {/* Interests */}
        {displayedInterests.length > 0 && (
          <div className="flex flex-wrap gap-2 mb-4">
            {displayedInterests.map((interest, index) => (
              <span
                key={index}
                className="px-3 py-1 bg-gradient-to-r from-indigo-50 to-purple-50 dark:from-indigo-900/30 dark:to-purple-900/30 text-indigo-700 dark:text-indigo-300 text-xs font-medium rounded-full"
              >
                {interest}
              </span>
            ))}
            {remainingCount > 0 && (
              <span className="px-3 py-1 bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-400 text-xs font-medium rounded-full">
                +{remainingCount} more
              </span>
            )}
          </div>
        )}

        {/* Bottom Section - Compatibility Score and Actions */}
        <div className="flex items-center justify-between pt-4 border-t border-gray-200 dark:border-gray-700">
          {/* Compatibility Score */}
          {typeof user.compatibilityScore === 'number' && (
            <div className="flex flex-col items-center">
              <CompatibilityScore score={user.compatibilityScore} />
              <span className="text-xs text-gray-600 dark:text-gray-400 mt-1">
                Match
              </span>
            </div>
          )}

          {/* Action Buttons */}
          <div className="flex space-x-2 ml-auto">
            {user.isConnected ? (
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="flex items-center space-x-2 px-4 py-2 bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 rounded-lg font-medium hover:bg-gray-200 dark:hover:bg-gray-600 transition-colors"
              >
                <MessageCircle className="w-4 h-4" />
                <span>Message</span>
              </motion.button>
            ) : (
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                onClick={handleConnect}
                disabled={isConnecting}
                className={clsx(
                  'flex items-center space-x-2 px-4 py-2 rounded-lg font-medium transition-all',
                  isConnecting
                    ? 'bg-gray-300 dark:bg-gray-600 text-gray-500 cursor-not-allowed'
                    : 'bg-gradient-to-r from-indigo-600 to-purple-600 text-white hover:shadow-lg'
                )}
              >
                {isConnecting ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    <span>Connecting...</span>
                  </>
                ) : (
                  <>
                    <Heart className="w-4 h-4" />
                    <span>Connect</span>
                  </>
                )}
              </motion.button>
            )}
          </div>
        </div>
      </div>
    </motion.div>
  );
};

export default ProfileCard;
