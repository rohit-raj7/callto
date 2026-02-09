import React, { useState, useMemo } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { Search, X } from 'lucide-react';
import clsx from 'clsx';

const InterestTagsSelector = ({
  selectedInterests = [],
  onChange,
  maxSelections = 10,
  className,
}) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [activeCategory, setActiveCategory] = useState('all');

  // Available interests by category
  const interestCategories = {
    'Sports & Fitness': [
      'Football', 'Basketball', 'Tennis', 'Swimming', 'Yoga', 'Hiking',
      'Running', 'Cycling', 'Gym', 'Martial Arts', 'Golf', 'Skiing'
    ],
    'Music & Arts': [
      'Rock', 'Pop', 'Jazz', 'Classical', 'Hip Hop', 'Electronic',
      'Painting', 'Photography', 'Dancing', 'Singing', 'Guitar', 'Piano'
    ],
    'Technology': [
      'Programming', 'AI/ML', 'Gaming', 'Robotics', 'Web Dev', 'Mobile Dev',
      'Data Science', 'Cybersecurity', 'Blockchain', 'IoT', 'VR/AR', '3D Printing'
    ],
    'Food & Lifestyle': [
      'Cooking', 'Baking', 'Coffee', 'Wine', 'Beer', 'Vegan',
      'Vegetarian', 'Travel', 'Reading', 'Writing', 'Fashion', 'Gardening'
    ],
    'Outdoor & Adventure': [
      'Camping', 'Hiking', 'Climbing', 'Surfing', 'Diving', 'Kayaking',
      'Fishing', 'Bird Watching', 'Astronomy', 'Photography', 'Nature', 'Wildlife'
    ],
    'Creative & Hobbies': [
      'Drawing', 'Sculpture', 'Crafts', 'Knitting', 'Woodworking', 'Pottery',
      'Board Games', 'Video Games', 'Chess', 'Puzzle Solving', 'Collecting', 'DIY'
    ],
  };

  // Flatten all interests for search
  const allInterests = useMemo(() => {
    return Object.entries(interestCategories).flatMap(([category, interests]) =>
      interests.map(interest => ({ interest, category }))
    );
  }, []);

  // Filter interests based on search and category
  const filteredInterests = useMemo(() => {
    let interests = allInterests;

    // Filter by category
    if (activeCategory !== 'all') {
      interests = interests.filter(item => item.category === activeCategory);
    }

    // Filter by search query
    if (searchQuery) {
      interests = interests.filter(item =>
        item.interest.toLowerCase().includes(searchQuery.toLowerCase())
      );
    }

    return interests;
  }, [allInterests, activeCategory, searchQuery]);

  // Group filtered interests by category for display
  const groupedInterests = useMemo(() => {
    const groups = {};
    filteredInterests.forEach(({ interest, category }) => {
      if (!groups[category]) {
        groups[category] = [];
      }
      groups[category].push(interest);
    });
    return groups;
  }, [filteredInterests]);

  const handleInterestToggle = (interest) => {
    if (selectedInterests.includes(interest)) {
      // Remove interest
      onChange(selectedInterests.filter(i => i !== interest));
    } else if (selectedInterests.length < maxSelections) {
      // Add interest
      onChange([...selectedInterests, interest]);
    }
  };

  const removeSelectedInterest = (interest) => {
    onChange(selectedInterests.filter(i => i !== interest));
  };

  const clearAll = () => {
    onChange([]);
  };

  return (
    <div className={clsx('space-y-6', className)}>
      {/* Search Bar */}
      <div className="relative">
        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-gray-400" />
        <input
          type="text"
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          placeholder="Search interests..."
          className="w-full pl-10 pr-4 py-3 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 transition-colors"
        />
      </div>

      {/* Category Filter */}
      <div className="flex flex-wrap gap-2">
        <button
          onClick={() => setActiveCategory('all')}
          className={clsx(
            'px-4 py-2 rounded-full text-sm font-medium transition-all',
            activeCategory === 'all'
              ? 'bg-indigo-600 text-white'
              : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
          )}
        >
          All
        </button>
        {Object.keys(interestCategories).map((category) => (
          <button
            key={category}
            onClick={() => setActiveCategory(category)}
            className={clsx(
              'px-4 py-2 rounded-full text-sm font-medium transition-all',
              activeCategory === category
                ? 'bg-indigo-600 text-white'
                : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
            )}
          >
            {category}
          </button>
        ))}
      </div>

      {/* Selected Interests */}
      {selectedInterests.length > 0 && (
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <h3 className="text-sm font-semibold text-gray-900 dark:text-white">
              Selected ({selectedInterests.length}/{maxSelections})
            </h3>
            <button
              onClick={clearAll}
              className="text-sm text-red-600 dark:text-red-400 hover:underline"
            >
              Clear all
            </button>
          </div>
          <div className="flex flex-wrap gap-2">
            <AnimatePresence>
              {selectedInterests.map((interest) => (
                <motion.button
                  key={interest}
                  initial={{ scale: 0, opacity: 0 }}
                  animate={{ scale: 1, opacity: 1 }}
                  exit={{ scale: 0, opacity: 0 }}
                  whileHover={{ scale: 1.05 }}
                  whileTap={{ scale: 0.95 }}
                  onClick={() => removeSelectedInterest(interest)}
                  className="inline-flex items-center space-x-2 px-3 py-2 bg-gradient-to-r from-indigo-600 to-purple-600 text-white rounded-full text-sm font-medium hover:shadow-lg transition-all"
                >
                  <span>{interest}</span>
                  <X className="w-4 h-4" />
                </motion.button>
              ))}
            </AnimatePresence>
          </div>
        </div>
      )}

      {/* Available Interests */}
      <div className="space-y-6 max-h-96 overflow-y-auto">
        {Object.entries(groupedInterests).map(([category, interests]) => (
          <div key={category}>
            <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300 mb-3">
              {category}
            </h3>
            <div className="flex flex-wrap gap-2">
              {interests.map((interest) => {
                const isSelected = selectedInterests.includes(interest);
                const isDisabled = !isSelected && selectedInterests.length >= maxSelections;

                return (
                  <motion.button
                    key={interest}
                    whileHover={{ scale: isDisabled ? 1 : 1.05 }}
                    whileTap={{ scale: isDisabled ? 1 : 0.95 }}
                    onClick={() => !isDisabled && handleInterestToggle(interest)}
                    disabled={isDisabled}
                    className={clsx(
                      'px-4 py-2 rounded-full font-medium transition-all text-sm',
                      isSelected
                        ? 'bg-gradient-to-r from-indigo-600 to-purple-600 text-white shadow-lg'
                        : isDisabled
                        ? 'bg-gray-100 dark:bg-gray-800 text-gray-400 cursor-not-allowed'
                        : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-600'
                    )}
                  >
                    {interest}
                  </motion.button>
                );
              })}
            </div>
          </div>
        ))}

        {filteredInterests.length === 0 && (
          <div className="text-center py-8">
            <p className="text-gray-500 dark:text-gray-400">
              {searchQuery ? 'No interests found matching your search.' : 'No interests available in this category.'}
            </p>
          </div>
        )}
      </div>

      {/* Selection Limit Warning */}
      {selectedInterests.length >= maxSelections && (
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4"
        >
          <p className="text-sm text-yellow-800 dark:text-yellow-200">
            You've reached the maximum of {maxSelections} interests. Remove some to add more.
          </p>
        </motion.div>
      )}
    </div>
  );
};

export default InterestTagsSelector;
