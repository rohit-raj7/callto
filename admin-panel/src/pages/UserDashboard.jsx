import React from 'react';
import { motion } from 'framer-motion';
import {
  Phone, MessageCircle, Clock, Shuffle,
  Wallet, Star, Users, PhoneCall, Headphones
} from 'lucide-react';
import UserDashboardLayout from '../components/UserDashboardLayout';
import ProfileCard from '../components/ProfileCard';

const UserDashboard = () => {
  // Mock data - matching mobile app features
  const stats = [
    {
      label: 'Total Calls',
      value: '24',
      icon: Phone,
      color: 'from-pink-500 to-rose-500',
      change: '+3 this week'
    },
    {
      label: 'Chat Sessions',
      value: '156',
      icon: MessageCircle,
      color: 'from-pink-400 to-pink-600',
      change: '+12 today'
    },
    {
      label: 'Minutes Talked',
      value: '89',
      icon: Clock,
      color: 'from-rose-400 to-pink-500',
      change: '15 mins today'
    },
    {
      label: 'Wallet Balance',
      value: '₹0.00',
      icon: Wallet,
      color: 'from-pink-500 to-red-400',
      change: 'Add Balance'
    }
  ];

  // Available listeners matching mobile app
  const availableListeners = [
    {
      id: 1,
      name: 'Aarav Sharma',
      age: 28,
      avatar: 'https://ui-avatars.com/api/?name=Aarav+Sharma&size=64&background=FCE4EC&color=EC4899',
      city: 'Mumbai',
      topic: 'Life Coach',
      rate: '₹15/min',
      rating: 4.8,
      isOnline: true,
    },
    {
      id: 2,
      name: 'Sneha D',
      age: 31,
      avatar: 'https://ui-avatars.com/api/?name=Sneha+D&size=64&background=FCE4EC&color=EC4899',
      city: 'Ahmedabad',
      topic: 'Career Advisor',
      rate: '₹20/min',
      rating: 4.9,
      isOnline: true,
    },
    {
      id: 3,
      name: 'Khushi Raj',
      age: 35,
      avatar: 'https://ui-avatars.com/api/?name=Khushi+Raj&size=64&background=FCE4EC&color=EC4899',
      city: 'Delhi',
      topic: 'Astrology',
      rate: '₹25/min',
      rating: 4.7,
      isOnline: false,
    },
  ];

  // Recent calls matching mobile app recents
  const recentCalls = [
    {
      id: 1,
      name: 'Kajal',
      status: 'Completed',
      duration: '5m 1s',
      time: '5:29 PM',
      avatar: 'https://ui-avatars.com/api/?name=Kajal&size=64&background=FCE4EC&color=EC4899',
      isOnline: false,
    },
    {
      id: 2,
      name: 'Priya Mehta',
      status: 'Missed',
      duration: '-',
      time: '3:15 PM',
      avatar: 'https://ui-avatars.com/api/?name=Priya+Mehta&size=64&background=FCE4EC&color=EC4899',
      isOnline: true,
    },
  ];

  // Topics for filtering - matching mobile app
  const topics = ['All', 'Confidence', 'Marriage', 'Breakup', 'Single', 'Relationship'];

  return (
    <UserDashboardLayout>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 bg-gradient-to-b from-pink-50 to-white dark:from-gray-900 dark:to-gray-800 min-h-screen">
        {/* Welcome Section - Callto Style */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="mb-10"
        >
          <div className="flex items-center gap-3 mb-3">
            <div className="w-14 h-14 bg-gradient-to-br from-pink-500 to-rose-600 rounded-2xl flex items-center justify-center shadow-lg">
              <MessageCircle className="w-7 h-7 text-white" strokeWidth={2.5} />
            </div>
            <div>
              <h1 className="text-4xl font-extrabold bg-gradient-to-r from-gray-900 via-pink-600 to-rose-600 dark:from-white dark:via-pink-400 dark:to-rose-400 bg-clip-text text-transparent">
                Start a Conversation... 💬
              </h1>
              <p className="text-gray-600 dark:text-gray-400 mt-1">
                Connect with experts who can help you with life, career, and more.
              </p>
            </div>
          </div>
          
          {/* Topic Filter - matching mobile app */}
          <div className="flex flex-wrap gap-3 mt-6">
            {topics.map((topic) => (
              <button
                key={topic}
                className="px-5 py-2.5 rounded-full text-sm font-semibold bg-gradient-to-r from-pink-100 to-rose-100 dark:from-pink-900/30 dark:to-rose-900/30 text-pink-700 dark:text-pink-400 hover:from-pink-200 hover:to-rose-200 dark:hover:from-pink-800/40 dark:hover:to-rose-800/40 transition-all border border-pink-200 dark:border-pink-800/30 hover:shadow-md"
              >
                {topic}
              </button>
            ))}
          </div>
        </motion.div>

        {/* Stats Grid */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
          className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-10"
        >
          {stats.map((stat, index) => (
            <motion.div
              key={stat.label}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: index * 0.1 }}
              whileHover={{ y: -6, scale: 1.02 }}
              className="group bg-white dark:bg-gray-800 rounded-2xl shadow-xl p-7 border-2 border-gray-100 dark:border-gray-700 hover:border-pink-200 dark:hover:border-pink-800/40 hover:shadow-2xl transition-all duration-300 relative overflow-hidden"
            >
              <div className="absolute top-0 right-0 w-24 h-24 bg-gradient-to-br opacity-5 rounded-bl-full transition-opacity group-hover:opacity-10"></div>
              <div className="relative z-10">
                <div className="flex items-center justify-between mb-5">
                  <div className={`bg-gradient-to-br ${stat.color} w-14 h-14 rounded-2xl flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform duration-300`}>
                    <stat.icon className="w-7 h-7 text-white" strokeWidth={2.5} />
                  </div>
                  <span className="text-sm font-semibold text-pink-600 dark:text-pink-400 bg-pink-50 dark:bg-pink-900/30 px-3 py-1 rounded-full">
                    {stat.change}
                  </span>
                </div>
                <div className="text-4xl font-extrabold text-gray-900 dark:text-white mb-2">
                  {stat.value}
                </div>
                <div className="text-sm font-semibold text-gray-600 dark:text-gray-400 uppercase tracking-wide">
                  {stat.label}
                </div>
              </div>
            </motion.div>
          ))}
        </motion.div>

        <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
          {/* Available Listeners - matching mobile app expert cards */}
          <motion.div
            initial={{ opacity: 0, x: -20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 }}
            className="lg:col-span-2"
          >
            <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-2xl p-8 border-2 border-pink-100 dark:border-gray-700">
              <div className="flex items-center justify-between mb-8">
                <div className="flex items-center gap-3">
                  <div className="bg-gradient-to-br from-pink-500 to-rose-600 p-2 rounded-xl">
                    <Headphones className="w-6 h-6 text-white" strokeWidth={2.5} />
                  </div>
                  <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
                    Available Listeners
                  </h2>
                </div>
                <button className="text-pink-600 dark:text-pink-400 hover:text-pink-700 dark:hover:text-pink-300 text-sm font-bold flex items-center gap-1 bg-pink-50 dark:bg-pink-900/30 px-4 py-2 rounded-full hover:bg-pink-100 dark:hover:bg-pink-900/50 transition-colors">
                  View all
                  <Users className="w-4 h-4" />
                </button>
              </div>

              <div className="space-y-5">
                {availableListeners.map((listener, index) => (
                  <motion.div
                    key={listener.id}
                    initial={{ opacity: 0, x: -20 }}
                    animate={{ opacity: 1, x: 0 }}
                    transition={{ delay: index * 0.1 }}
                    whileHover={{ scale: 1.02 }}
                    className="group flex items-center space-x-5 p-5 bg-gradient-to-br from-pink-50 via-rose-50 to-pink-50 dark:from-pink-900/20 dark:via-rose-900/15 dark:to-pink-900/20 rounded-2xl border-2 border-pink-100 dark:border-pink-800/30 hover:border-pink-300 dark:hover:border-pink-700/50 hover:shadow-xl transition-all duration-300"
                  >
                    <div className="relative">
                      <img
                        src={listener.avatar}
                        alt={listener.name}
                        className="w-16 h-16 rounded-2xl border-3 border-pink-300 dark:border-pink-700 shadow-lg group-hover:scale-110 transition-transform duration-300"
                      />
                      {listener.isOnline && (
                        <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-green-500 rounded-full border-3 border-white dark:border-gray-800 animate-pulse shadow-lg"></div>
                      )}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center space-x-2 mb-1">
                        <h3 className="font-bold text-lg text-gray-900 dark:text-white truncate">
                          {listener.name}
                        </h3>
                        <span className="text-sm text-gray-600 dark:text-gray-400 font-medium">
                          • {listener.age} Y
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 dark:text-gray-400 font-medium mb-1">{listener.city}</p>
                      <p className="text-sm text-pink-600 dark:text-pink-400 font-bold mb-2 bg-pink-100 dark:bg-pink-900/40 px-2 py-1 rounded inline-block">{listener.topic}</p>
                      <div className="flex items-center space-x-3 mt-2">
                        <span className="text-base font-bold text-gray-800 dark:text-gray-200 bg-white dark:bg-gray-700 px-3 py-1 rounded-full">{listener.rate}</span>
                        <div className="flex items-center bg-yellow-50 dark:bg-yellow-900/30 px-3 py-1 rounded-full">
                          <Star className="w-4 h-4 fill-yellow-500 text-yellow-500" />
                          <span className="text-sm ml-1.5 font-bold text-gray-800 dark:text-gray-200">{listener.rating}</span>
                        </div>
                      </div>
                    </div>
                    <div className="flex flex-col space-y-3">
                      <button className="px-6 py-3 bg-gradient-to-r from-pink-500 to-rose-600 text-white font-bold rounded-xl hover:from-pink-600 hover:to-rose-700 transition-all shadow-lg hover:shadow-xl flex items-center justify-center space-x-2 group-hover:scale-105">
                        <Phone className="w-5 h-5" strokeWidth={2.5} />
                        <span>Call Now</span>
                      </button>
                      <button className="px-6 py-3 bg-white dark:bg-gray-700 border-2 border-pink-300 dark:border-pink-700 text-pink-600 dark:text-pink-400 font-bold rounded-xl hover:bg-pink-50 dark:hover:bg-pink-900/30 transition-all flex items-center justify-center space-x-2 group-hover:scale-105">
                        <MessageCircle className="w-5 h-5" strokeWidth={2.5} />
                        <span>Chat</span>
                      </button>
                    </div>
                  </motion.div>
                ))}
              </div>
            </div>
          </motion.div>

          {/* Recent Calls - matching mobile app recents */}
          <motion.div
            initial={{ opacity: 0, x: 20 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.3 }}
          >
            <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 border border-pink-100 dark:border-gray-700">
              <div className="flex items-center justify-between mb-6">
                <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                  Recents
                </h2>
                <button className="text-pink-600 dark:text-pink-400 hover:underline text-sm font-medium">
                  View all
                </button>
              </div>

              <div className="space-y-4">
                {recentCalls.map((call, index) => (
                  <motion.div
                    key={call.id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ delay: index * 0.1 }}
                    className="p-4 bg-gradient-to-r from-pink-50 to-rose-50 dark:from-pink-900/20 dark:to-rose-900/20 rounded-lg border border-pink-100 dark:border-pink-800"
                  >
                    <div className="flex items-center space-x-3">
                      <div className="relative">
                        <img
                          src={call.avatar}
                          alt={call.name}
                          className="w-12 h-12 rounded-full"
                        />
                        {call.isOnline && (
                          <div className="absolute bottom-0 right-0 w-3 h-3 bg-green-500 rounded-full border-2 border-white"></div>
                        )}
                      </div>
                      <div className="flex-1">
                        <h3 className="font-semibold text-gray-900 dark:text-white">
                          {call.name}
                        </h3>
                        <div className="flex items-center text-sm text-gray-600 dark:text-gray-400">
                          <Clock className="w-3 h-3 mr-1" />
                          <span>{call.duration} • {call.time}</span>
                        </div>
                      </div>
                      <span className={`text-xs px-2 py-1 rounded-full ${
                        call.status === 'Completed' 
                          ? 'bg-green-100 text-green-600 dark:bg-green-900/30 dark:text-green-400' 
                          : 'bg-red-100 text-red-600 dark:bg-red-900/30 dark:text-red-400'
                      }`}>
                        {call.status}
                      </span>
                    </div>
                  </motion.div>
                ))}
              </div>

              {/* Quick Actions - Callto Style */}
              <div className="mt-6 pt-6 border-t border-pink-100 dark:border-gray-700">
                <h3 className="text-sm font-semibold text-gray-900 dark:text-white mb-3">
                  Quick Actions
                </h3>
                <div className="space-y-2">
                  <button className="w-full flex items-center space-x-2 px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-pink-50 dark:hover:bg-pink-900/20 rounded-lg transition-colors">
                    <Shuffle className="w-4 h-4 text-pink-500" />
                    <span>Random Call</span>
                  </button>
                  <button className="w-full flex items-center space-x-2 px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-pink-50 dark:hover:bg-pink-900/20 rounded-lg transition-colors">
                    <Wallet className="w-4 h-4 text-pink-500" />
                    <span>Add Balance</span>
                  </button>
                  <button className="w-full flex items-center space-x-2 px-3 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-pink-50 dark:hover:bg-pink-900/20 rounded-lg transition-colors">
                    <Users className="w-4 h-4 text-pink-500" />
                    <span>Browse Listeners</span>
                  </button>
                </div>
              </div>
            </div>
          </motion.div>
        </div>

        {/* More Listeners Section */}
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.4 }}
          className="mt-8"
        >
          <div className="bg-white dark:bg-gray-800 rounded-xl shadow-lg p-6 border border-pink-100 dark:border-gray-700">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-xl font-bold text-gray-900 dark:text-white">
                More Listeners for You
              </h2>
              <button className="text-pink-600 dark:text-pink-400 hover:underline text-sm font-medium">
                View all listeners
              </button>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
              {availableListeners.map((listener, index) => (
                <motion.div
                  key={`more-${listener.id}`}
                  initial={{ opacity: 0, scale: 0.9 }}
                  animate={{ opacity: 1, scale: 1 }}
                  transition={{ delay: index * 0.1 }}
                  className="bg-pink-50 dark:bg-pink-900/20 rounded-xl p-4 border border-pink-100 dark:border-pink-800/30"
                >
                  <div className="flex flex-col items-center text-center">
                    <div className="relative mb-3">
                      <img
                        src={listener.avatar}
                        alt={listener.name}
                        className="w-16 h-16 rounded-full border-3 border-pink-300"
                      />
                      {listener.isOnline && (
                        <div className="absolute bottom-0 right-0 w-4 h-4 bg-green-500 rounded-full border-2 border-white"></div>
                      )}
                    </div>
                    <h3 className="font-semibold text-gray-900 dark:text-white">{listener.name}</h3>
                    <p className="text-sm text-gray-600 dark:text-gray-400">{listener.city} • {listener.age}Y</p>
                    <p className="text-sm text-pink-600 dark:text-pink-400 font-medium mt-1">{listener.topic}</p>
                    <div className="flex items-center justify-center space-x-2 mt-2">
                      <span className="font-semibold text-gray-800 dark:text-gray-200">{listener.rate}</span>
                      <div className="flex items-center text-yellow-500">
                        <Star className="w-4 h-4 fill-current" />
                        <span className="text-xs ml-1">{listener.rating}</span>
                      </div>
                    </div>
                    <div className="flex space-x-2 mt-4 w-full">
                      <button className="flex-1 py-2 bg-gradient-to-r from-pink-500 to-rose-500 text-white text-sm rounded-full hover:from-pink-600 hover:to-rose-600 transition-colors">
                        Call Now
                      </button>
                      <button className="py-2 px-3 bg-pink-100 dark:bg-pink-900/30 text-pink-600 dark:text-pink-400 rounded-full hover:bg-pink-200 dark:hover:bg-pink-800/40 transition-colors">
                        <MessageCircle className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </motion.div>
              ))}
            </div>
          </div>
        </motion.div>
      </div>
    </UserDashboardLayout>
  );
};

export default UserDashboard;
