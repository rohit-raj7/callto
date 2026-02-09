import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { ChevronDown, HelpCircle, Phone, MessageCircle, Wallet, Shield, User } from 'lucide-react';
import UserDashboardLayout from '../components/UserDashboardLayout';

const MotionDiv = motion.div;

const FAQs = () => {
  const [openItems, setOpenItems] = useState({});
  const [selectedCategory, setSelectedCategory] = useState('All');

  const toggleItem = (index) => {
    setOpenItems(prev => ({
      ...prev,
      [index]: !prev[index]
    }));
  };

  const categorizedFaqs = {
    'Getting Started': [
      {
        question: "How do I create a Callto account?",
        answer: "Tap 'Sign Up' on the home screen, enter your email and create a password. Verify your email through the confirmation link we send. You can also sign up with Google or Facebook for faster registration."
      },
      {
        question: "How do I set up my profile?",
        answer: "After signing up, go to your profile section and tap 'Edit Profile'. Add your interests, preferred topics (like Relationships, Career, Confidence), and a brief bio to help listeners understand what you're looking for."
      },
      {
        question: "Is Callto free to use?",
        answer: "Yes! Creating an account and browsing listeners is completely free. You only pay per minute when you connect with a listener through voice calls or text chat."
      },
    ],
    'Finding Listeners': [
      {
        question: "How do I find the right listener?",
        answer: "Browse our verified listeners by topic (Life Coaching, Career Advice, Relationships, etc.), rating, or location. You can also try our random call feature to connect instantly with an available listener."
      },
      {
        question: "What topics do listeners specialize in?",
        answer: "Our listeners specialize in various areas including: Life Coaching, Career Guidance, Relationships, Mental Wellness, Confidence Building, Marriage Counseling, Personal Development, and Astrology."
      },
      {
        question: "How do I know if a listener is available?",
        answer: "Look for the green 'Online' indicator on their profile. You can also check their availability status and typical response times in their profile details."
      },
    ],
    'Calls & Chats': [
      {
        question: "How do voice calls work?",
        answer: "Once you select a listener, tap 'Call' and pay for the minimum call duration (usually 5-10 minutes). You'll be connected immediately if they're available. Calls are charged per minute at the listener's rate."
      },
      {
        question: "Can I text chat instead of voice calls?",
        answer: "Absolutely! Many listeners offer both voice and text chat options. Text chat is often more affordable and allows you to communicate at your own pace. Check the listener's profile for available communication methods."
      },
      {
        question: "What if I need to end a call early?",
        answer: "You can end any call at any time. You'll only be charged for the actual time spent talking. There's no minimum commitment once the call starts."
      },
      {
        question: "Are conversations private and confidential?",
        answer: "Yes, all conversations are completely private and confidential. We use end-to-end encryption and never record or store conversation content. Your privacy is our top priority."
      },
    ],
    'Payments & Wallet': [
      {
        question: "How does the payment system work?",
        answer: "Add money to your wallet using UPI, credit/debit cards, or other payment methods. When you call or chat, the amount is deducted from your wallet balance at the listener's per-minute rate."
      },
      {
        question: "What are the rates for listeners?",
        answer: "Rates vary by listener expertise and experience, typically ranging from ₹10-30 per minute. Each listener sets their own rate, which is clearly displayed on their profile."
      },
      {
        question: "Can I get a refund?",
        answer: "Refunds are available for technical issues or if a listener doesn't connect. Contact our support team within 24 hours of the call with details. We review each case individually."
      },
    ],
    'Account & Privacy': [
      {
        question: "How do I change my password?",
        answer: "Go to Settings → Account → Change Password. Enter your current password and choose a new one. You'll receive a confirmation email when the change is complete."
      },
      {
        question: "Can I delete my account?",
        answer: "Yes, you can delete your account in Settings → Account → Delete Account. This action is permanent and will remove all your data. Contact support if you need help with this."
      },
      {
        question: "How is my personal information protected?",
        answer: "We use industry-standard security measures including encryption, secure servers, and regular security audits. Your payment information is never stored on our servers."
      },
    ],
    'Technical Support': [
      {
        question: "The app isn't working properly. What should I do?",
        answer: "Try these steps: 1) Restart the app, 2) Check your internet connection, 3) Update to the latest version, 4) Clear app cache, 5) Restart your device. Contact support if issues persist."
      },
      {
        question: "How do I update the app?",
        answer: "Visit the App Store (iOS) or Google Play Store (Android) and update Callto to the latest version. We recommend enabling automatic updates."
      },
      {
        question: "Can I use Callto on multiple devices?",
        answer: "Yes! Sign in with the same account on any device. Your profile and wallet balance sync automatically across all your devices."
      },
      {
        question: "How do I contact support?",
        answer: "You can reach our support team through the app (Settings → Help → Contact Support), email us at support@callto.com, or use the chat feature on our website."
      },
    ],
  };

  const categories = [
    { name: 'All', icon: HelpCircle, color: 'from-pink-500 to-rose-500' },
    { name: 'Getting Started', icon: User, color: 'from-pink-400 to-pink-600' },
    { name: 'Finding Listeners', icon: User, color: 'from-rose-400 to-pink-500' },
    { name: 'Calls & Chats', icon: Phone, color: 'from-pink-500 to-red-400' },
    { name: 'Payments & Wallet', icon: Wallet, color: 'from-pink-400 to-rose-500' },
    { name: 'Account & Privacy', icon: Shield, color: 'from-rose-400 to-pink-500' },
    { name: 'Technical Support', icon: HelpCircle, color: 'from-pink-500 to-red-400' },
  ];

  const getFilteredFaqs = () => {
    if (selectedCategory === 'All') {
      return Object.values(categorizedFaqs).flat();
    }
    return categorizedFaqs[selectedCategory] || [];
  };

  const filteredFaqs = getFilteredFaqs();

  return (
    <UserDashboardLayout>
      <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
        <div className="max-w-4xl mx-auto px-4 py-8">
          {/* Header */}
          <MotionDiv
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center mb-8"
          >
            <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-r from-pink-500 to-rose-500 rounded-full mb-6">
              <HelpCircle className="w-10 h-10 text-white" />
            </div>
            <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-4">
              Frequently Asked Questions
            </h1>
            <p className="text-xl text-gray-600 dark:text-gray-300">
              Find answers to common questions about Callto
            </p>
          </MotionDiv>

          {/* Category Filter */}
          <MotionDiv
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.1 }}
            className="mb-8"
          >
            <div className="flex flex-wrap justify-center gap-3">
              {categories.map((category) => (
                <button
                  key={category.name}
                  onClick={() => setSelectedCategory(category.name)}
                  className={`flex items-center space-x-2 px-4 py-2 rounded-full text-sm font-medium transition-all ${
                    selectedCategory === category.name
                      ? 'bg-gradient-to-r from-pink-500 to-rose-500 text-white shadow-lg'
                      : 'bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:shadow-md'
                  }`}
                >
                  <category.icon className="w-4 h-4" />
                  <span>{category.name}</span>
                </button>
              ))}
            </div>
          </MotionDiv>

          {/* FAQ Items */}
          <MotionDiv
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="space-y-4"
          >
            {filteredFaqs.map((faq, index) => (
              <MotionDiv
                key={index}
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ delay: index * 0.05 }}
                className="bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700 overflow-hidden"
              >
                <button
                  onClick={() => toggleItem(index)}
                  className="w-full px-6 py-4 text-left flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                >
                  <span className="text-lg font-semibold text-gray-900 dark:text-white pr-4">
                    {faq.question}
                  </span>
                  <MotionDiv
                    animate={{ rotate: openItems[index] ? 180 : 0 }}
                    transition={{ duration: 0.2 }}
                  >
                    <ChevronDown className="w-5 h-5 text-gray-500 flex-shrink-0" />
                  </MotionDiv>
                </button>

                <AnimatePresence>
                  {openItems[index] && (
                    <MotionDiv
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      transition={{ duration: 0.3 }}
                      className="overflow-hidden"
                    >
                      <div className="px-6 pb-4">
                        <p className="text-gray-600 dark:text-gray-400 leading-relaxed">
                          {faq.answer}
                        </p>
                      </div>
                    </MotionDiv>
                  )}
                </AnimatePresence>
              </MotionDiv>
            ))}
          </MotionDiv>

          {/* Contact Support */}
          <MotionDiv
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4 }}
            className="mt-12 text-center"
          >
            <div className="bg-gradient-to-r from-pink-50 to-rose-50 dark:from-pink-900/20 dark:to-rose-900/20 rounded-2xl p-8">
              <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">
                Still need help?
              </h3>
              <p className="text-gray-600 dark:text-gray-400 mb-6">
                Can't find the answer you're looking for? Our support team is here to help.
              </p>
              <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
                <button className="bg-gradient-to-r from-pink-500 to-rose-500 text-white px-6 py-3 rounded-xl font-semibold hover:shadow-lg transition-all flex items-center space-x-2">
                  <MessageCircle className="w-5 h-5" />
                  <span>Contact Support</span>
                </button>
                <button className="border-2 border-pink-500 text-pink-600 dark:text-pink-400 px-6 py-3 rounded-xl font-semibold hover:bg-pink-50 dark:hover:bg-pink-900/20 transition-all">
                  Visit Help Center
                </button>
              </div>
            </div>
          </MotionDiv>
        </div>
      </div>
    </UserDashboardLayout>
  );
};

export default FAQs;
