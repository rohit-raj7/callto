import React, { useState, useEffect, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import {
  Filter, SlidersHorizontal, MapPin, Calendar, Heart,
  Users, Search, SortAsc, SortDesc
} from 'lucide-react';
import clsx from 'clsx';
import ProfileCard from './ProfileCard';
import { GridSkeleton } from './SkeletonLoaders';
import SearchAutocomplete from './SearchAutocomplete';

// Mock user data
const mockUsers = [
  {
    id: 1,
    name: 'Sarah Wilson',
    age: 28,
    avatar: 'https://ui-avatars.com/api/?name=Sarah+Wilson&size=128&background=random',
    location: 'New York, NY',
    bio: 'Photography enthusiast and coffee lover. Always up for an adventure!',
    interests: ['Photography', 'Coffee', 'Travel', 'Hiking'],
    isOnline: true,
    compatibilityScore: 85,
    isConnected: false,
  },
  {
    id: 2,
    name: 'John Smith',
    age: 32,
    avatar: 'https://ui-avatars.com/api/?name=John+Smith&size=128&background=random',
    location: 'Los Angeles, CA',
    bio: 'Software engineer who loves gaming and board games. Looking for like-minded friends.',
    interests: ['Gaming', 'Programming', 'Board Games', 'Tech'],
    isOnline: false,
    compatibilityScore: 72,
    isConnected: false,
  },
  {
    id: 3,
    name: 'Emma Brown',
    age: 25,
    avatar: 'https://ui-avatars.com/api/?name=Emma+Brown&size=128&background=random',
    location: 'Chicago, IL',
    bio: 'Artist and musician. Love creating and exploring new creative outlets.',
    interests: ['Painting', 'Music', 'Dancing', 'Photography'],
    isOnline: true,
    compatibilityScore: 91,
    isConnected: true,
  },
  {
    id: 4,
    name: 'Mike Johnson',
    age: 30,
    avatar: 'https://ui-avatars.com/api/?name=Mike+Johnson&size=128&background=random',
    location: 'Austin, TX',
    bio: 'Fitness enthusiast and outdoor adventurer. Always planning the next hike!',
    interests: ['Hiking', 'Fitness', 'Camping', 'Photography'],
    isOnline: false,
    compatibilityScore: 68,
    isConnected: false,
  },
  {
    id: 5,
    name: 'Lisa Chen',
    age: 27,
    avatar: 'https://ui-avatars.com/api/?name=Lisa+Chen&size=128&background=random',
    location: 'San Francisco, CA',
    bio: 'Book lover and foodie. Love discovering new restaurants and cozy cafes.',
    interests: ['Reading', 'Cooking', 'Coffee', 'Travel'],
    isOnline: true,
    compatibilityScore: 78,
    isConnected: false,
  },
  {
    id: 6,
    name: 'David Rodriguez',
    age: 29,
    avatar: 'https://ui-avatars.com/api/?name=David+Rodriguez&size=128&background=random',
    location: 'Miami, FL',
    bio: 'Music producer and DJ. Always looking for the next great beat.',
    interests: ['Music', 'DJing', 'Electronic', 'Nightlife'],
    isOnline: false,
    compatibilityScore: 65,
    isConnected: false,
  },
];

const DiscoveryPage = () => {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showFilters, setShowFilters] = useState(false);
  const [sortBy, setSortBy] = useState('compatibility');
  const [sortOrder, setSortOrder] = useState('desc');

  // Filter states
  const [filters, setFilters] = useState({
    ageRange: [18, 50],
    location: '',
    interests: [],
    onlineOnly: false,
  });

  // Load users
  useEffect(() => {
    const loadUsers = async () => {
      setLoading(true);
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1500));
      setUsers(mockUsers);
      setLoading(false);
    };

    loadUsers();
  }, []);

  // Apply filters and sorting
  const filteredUsers = useMemo(() => {
    let filtered = [...users];

    // Apply filters
    if (filters.ageRange) {
      filtered = filtered.filter(user =>
        user.age >= filters.ageRange[0] && user.age <= filters.ageRange[1]
      );
    }

    if (filters.location) {
      filtered = filtered.filter(user =>
        user.location.toLowerCase().includes(filters.location.toLowerCase())
      );
    }

    if (filters.interests.length > 0) {
      filtered = filtered.filter(user =>
        filters.interests.some(interest =>
          user.interests.includes(interest)
        )
      );
    }

    if (filters.onlineOnly) {
      filtered = filtered.filter(user => user.isOnline);
    }

    // Apply sorting
    filtered.sort((a, b) => {
      let aValue, bValue;

      switch (sortBy) {
        case 'compatibility':
          aValue = a.compatibilityScore;
          bValue = b.compatibilityScore;
          break;
        case 'age':
          aValue = a.age;
          bValue = b.age;
          break;
        case 'name':
          aValue = a.name.toLowerCase();
          bValue = b.name.toLowerCase();
          break;
        default:
          return 0;
      }

      if (sortOrder === 'asc') {
        return aValue > bValue ? 1 : -1;
      } else {
        return aValue < bValue ? 1 : -1;
      }
    });

    return filtered;
  }, [users, filters, sortBy, sortOrder]);

  const handleConnect = (user) => {
    // Update user connection status
    setUsers(prev => prev.map(u =>
      u.id === user.id ? { ...u, isConnected: true } : u
    ));
  };

  const handleViewProfile = (user) => {
    console.log('View profile:', user);
    // Navigate to profile page
  };

  const handleSearch = (query) => {
    console.log('Search:', query);
    // Implement search logic
  };

  const updateFilter = (key, value) => {
    setFilters(prev => ({ ...prev, [key]: value }));
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      {/* Header */}
      <div className="bg-gradient-to-r from-indigo-50 via-purple-50 to-pink-50 dark:from-gray-800 dark:via-gray-800 dark:to-gray-800 shadow-xl border-b-2 border-indigo-100 dark:border-gray-700">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
          <div className="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-6">
            {/* Title */}
            <div className="flex items-center gap-4">
              <div className="bg-gradient-to-br from-indigo-500 to-purple-600 p-3 rounded-2xl shadow-lg">
                <Users className="w-8 h-8 text-white" strokeWidth={2.5} />
              </div>
              <div>
                <h1 className="text-3xl font-extrabold bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 dark:from-indigo-400 dark:via-purple-400 dark:to-pink-400 bg-clip-text text-transparent">
                  Discover People
                </h1>
                <p className="text-gray-700 dark:text-gray-300 font-medium mt-1">
                  Find your next meaningful connection
                </p>
              </div>
            </div>

            {/* Search and Controls */}
            <div className="flex flex-col sm:flex-row gap-4">
              <SearchAutocomplete
                onSearch={handleSearch}
                placeholder="Search by name, interests..."
                className="w-full sm:w-80"
              />

              <div className="flex gap-3">
                {/* Sort Dropdown */}
                <div className="relative">
                  <select
                    value={`${sortBy}-${sortOrder}`}
                    onChange={(e) => {
                      const [field, order] = e.target.value.split('-');
                      setSortBy(field);
                      setSortOrder(order);
                    }}
                    className="px-5 py-3 bg-white dark:bg-gray-700 border-2 border-indigo-200 dark:border-gray-600 rounded-xl text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 font-semibold shadow-md hover:shadow-lg transition-all"
                  >
                    <option value="compatibility-desc">🎯 Best Match</option>
                    <option value="compatibility-asc">Worst Match</option>
                    <option value="age-desc">Age: High to Low</option>
                    <option value="age-asc">Age: Low to High</option>
                    <option value="name-asc">Name: A-Z</option>
                    <option value="name-desc">Name: Z-A</option>
                  </select>
                </div>

                {/* Filter Toggle */}
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => setShowFilters(!showFilters)}
                  className={clsx(
                    'px-5 py-3 rounded-xl font-bold transition-all flex items-center space-x-2 shadow-lg hover:shadow-xl',
                    showFilters
                      ? 'bg-gradient-to-r from-indigo-600 to-purple-600 text-white'
                      : 'bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-300 border-2 border-indigo-200 dark:border-gray-600 hover:bg-indigo-50 dark:hover:bg-gray-600'
                  )}
                >
                  <Filter className="w-5 h-5" strokeWidth={2.5} />
                  <span className="hidden sm:inline">Filters</span>
                </motion.button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="flex gap-8">
          {/* Filters Sidebar */}
          <AnimatePresence>
            {showFilters && (
              <motion.div
                initial={{ width: 0, opacity: 0 }}
                animate={{ width: 320, opacity: 1 }}
                exit={{ width: 0, opacity: 0 }}
                className="hidden lg:block flex-shrink-0"
              >
                <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl p-8 sticky top-8 border-2 border-indigo-100 dark:border-gray-700">
                  <div className="flex items-center gap-3 mb-8">
                    <div className="bg-gradient-to-br from-indigo-500 to-purple-600 p-2 rounded-xl">
                      <SlidersHorizontal className="w-6 h-6 text-white" strokeWidth={2.5} />
                    </div>
                    <h2 className="text-xl font-extrabold text-gray-900 dark:text-white">
                      Filters
                    </h2>
                  </div>

                  <div className="space-y-8">
                    {/* Age Range */}
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                        Age Range: {filters.ageRange[0]} - {filters.ageRange[1]}
                      </label>
                      <div className="px-2">
                        <input
                          type="range"
                          min="18"
                          max="80"
                          value={filters.ageRange[0]}
                          onChange={(e) => updateFilter('ageRange', [parseInt(e.target.value), filters.ageRange[1]])}
                          className="w-full"
                        />
                        <input
                          type="range"
                          min="18"
                          max="80"
                          value={filters.ageRange[1]}
                          onChange={(e) => updateFilter('ageRange', [filters.ageRange[0], parseInt(e.target.value)])}
                          className="w-full mt-2"
                        />
                      </div>
                    </div>

                    {/* Location */}
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                        Location
                      </label>
                      <div className="relative">
                        <MapPin className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                        <input
                          type="text"
                          value={filters.location}
                          onChange={(e) => updateFilter('location', e.target.value)}
                          placeholder="City, State"
                          className="w-full pl-10 pr-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500"
                        />
                      </div>
                    </div>

                    {/* Online Only */}
                    <div>
                      <label className="flex items-center space-x-2">
                        <input
                          type="checkbox"
                          checked={filters.onlineOnly}
                          onChange={(e) => updateFilter('onlineOnly', e.target.checked)}
                          className="rounded border-gray-300 dark:border-gray-600 text-indigo-600 focus:ring-indigo-500"
                        />
                        <span className="text-sm text-gray-700 dark:text-gray-300">
                          Online only
                        </span>
                      </label>
                    </div>

                    {/* Popular Interests */}
                    <div>
                      <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                        Popular Interests
                      </label>
                      <div className="flex flex-wrap gap-2">
                        {['Photography', 'Travel', 'Music', 'Gaming', 'Cooking', 'Fitness'].map((interest) => (
                          <button
                            key={interest}
                            onClick={() => {
                              const newInterests = filters.interests.includes(interest)
                                ? filters.interests.filter(i => i !== interest)
                                : [...filters.interests, interest];
                              updateFilter('interests', newInterests);
                            }}
                            className={clsx(
                              'px-3 py-1 rounded-full text-sm font-medium transition-all',
                              filters.interests.includes(interest)
                                ? 'bg-indigo-600 text-white'
                                : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
                            )}
                          >
                            {interest}
                          </button>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>

          {/* Main Content */}
          <div className="flex-1">
            {/* Results Count */}
            <div className="mb-6">
              <p className="text-gray-600 dark:text-gray-400">
                {loading ? 'Loading...' : `${filteredUsers.length} people found`}
              </p>
            </div>

            {/* User Grid */}
            {loading ? (
              <GridSkeleton count={6} />
            ) : filteredUsers.length > 0 ? (
              <motion.div
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6"
              >
                <AnimatePresence>
                  {filteredUsers.map((user, index) => (
                    <motion.div
                      key={user.id}
                      initial={{ opacity: 0, y: 20 }}
                      animate={{ opacity: 1, y: 0 }}
                      exit={{ opacity: 0, y: -20 }}
                      transition={{ delay: index * 0.1 }}
                    >
                      <ProfileCard
                        user={user}
                        onConnect={handleConnect}
                        onViewProfile={handleViewProfile}
                      />
                    </motion.div>
                  ))}
                </AnimatePresence>
              </motion.div>
            ) : (
              <motion.div
                initial={{ opacity: 0, y: 20 }}
                animate={{ opacity: 1, y: 0 }}
                className="text-center py-16"
              >
                <Users className="w-16 h-16 text-gray-400 mx-auto mb-4" />
                <h3 className="text-xl font-semibold text-gray-900 dark:text-white mb-2">
                  No people found
                </h3>
                <p className="text-gray-600 dark:text-gray-400 mb-6">
                  Try adjusting your filters or search criteria
                </p>
                <button
                  onClick={() => setFilters({
                    ageRange: [18, 50],
                    location: '',
                    interests: [],
                    onlineOnly: false,
                  })}
                  className="px-6 py-3 bg-indigo-600 text-white rounded-lg font-medium hover:bg-indigo-700 transition-colors"
                >
                  Clear Filters
                </button>
              </motion.div>
            )}

            {/* Load More Button */}
            {!loading && filteredUsers.length > 0 && filteredUsers.length >= 6 && (
              <div className="text-center mt-8">
                <motion.button
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  className="px-8 py-3 bg-white dark:bg-gray-800 text-gray-900 dark:text-white border border-gray-300 dark:border-gray-600 rounded-lg font-medium hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                >
                  Load More People
                </motion.button>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default DiscoveryPage;
