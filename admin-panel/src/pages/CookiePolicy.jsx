/* eslint-disable no-unused-vars */
import React from 'react';
import { motion } from 'framer-motion';
import { Cookie, Settings, BarChart3, Shield, Clock, AlertTriangle, CheckCircle } from 'lucide-react';
import PublicNavbar from '../components/PublicNavbar';

const CookiePolicy = () => {
  const fadeInUp = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0 }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <PublicNavbar />

      {/* Hero Section */}
      <section className="relative pt-32 pb-12 px-4">
        <div className="max-w-7xl mx-auto">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center"
          >
            <div className="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-pink-500 to-rose-600 rounded-2xl mb-6 shadow-xl shadow-pink-200 dark:shadow-none">
              <Cookie className="w-10 h-10 text-white" strokeWidth={2.5} />
            </div>
            <h1 className="text-4xl font-extrabold text-gray-900 dark:text-white mb-4">
              Cookie Policy
            </h1>
            <p className="text-xl text-gray-600 dark:text-gray-300 max-w-3xl mx-auto">
              How we use cookies to enhance your Callto experience
            </p>
            <p className="text-sm text-gray-500 dark:text-gray-400 mt-4">
              Last Updated: January 27, 2026
            </p>
          </motion.div>
        </div>
      </section>

      {/* Content Section */}
      <section className="py-12 px-4">
        <div className="max-w-4xl mx-auto">
          <div className="space-y-6">
            {/* Important Notice */}
            <motion.div
              variants={fadeInUp}
              className="bg-gradient-to-r from-pink-50 to-rose-50 dark:from-pink-900/20 dark:to-rose-900/20 border-l-4 border-pink-500 p-4 rounded-lg"
            >
              <div className="flex items-start gap-3">
                <AlertTriangle className="w-5 h-5 text-pink-600 dark:text-pink-400 flex-shrink-0 mt-1" />
                <div>
                  <h3 className="font-semibold text-pink-900 dark:text-pink-100 mb-1">Cookie Consent</h3>
                  <p className="text-sm text-pink-800 dark:text-pink-200">
                    By using Callto, you consent to the use of cookies in accordance with this policy. You can manage your cookie preferences in your account settings.
                  </p>
                </div>
              </div>
            </motion.div>

            {/* 1. What Are Cookies */}
            <motion.section
              variants={fadeInUp}
              className="bg-white dark:bg-gray-800 rounded-xl p-5 shadow-sm border border-gray-200 dark:border-gray-700 hover:border-pink-200 dark:hover:border-pink-800 transition-colors"
            >
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-3">
                1. What Are Cookies?
              </h2>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-sm mb-4">
                Cookies are small text files that are stored on your device when you visit our website or use our mobile app. They help us provide you with a better experience by remembering your preferences and understanding how you use our platform.
              </p>
              <div className="grid md:grid-cols-2 gap-4">
                <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                  <h4 className="font-semibold text-gray-900 dark:text-white mb-2">Session Cookies</h4>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Temporary cookies that expire when you close your browser. Used for maintaining your session during calls.
                  </p>
                </div>
                <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                  <h4 className="font-semibold text-gray-900 dark:text-white mb-2">Persistent Cookies</h4>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Cookies that remain on your device for a set period. Used for remembering your preferences and login status.
                  </p>
                </div>
              </div>
            </motion.section>

            {/* 2. Types of Cookies We Use */}
            <motion.section
              variants={fadeInUp}
              className="bg-white dark:bg-gray-800 rounded-xl p-5 shadow-sm border border-gray-200 dark:border-gray-700"
            >
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-3">
                2. Types of Cookies We Use
              </h2>

              <div className="space-y-4">
                {/* Essential Cookies */}
                <div className="border border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20 rounded-lg p-4">
                  <div className="flex items-start gap-3">
                    <CheckCircle className="w-5 h-5 text-green-600 dark:text-green-400 flex-shrink-0 mt-0.5" />
                    <div>
                      <h3 className="font-semibold text-green-900 dark:text-green-100 mb-2">Essential Cookies</h3>
                      <p className="text-sm text-green-800 dark:text-green-200 mb-2">
                        Required for the platform to function properly. Cannot be disabled.
                      </p>
                      <ul className="space-y-1 text-sm text-green-700 dark:text-green-300">
                        <li>• Authentication and security tokens</li>
                        <li>• Call session management</li>
                        <li>• CSRF protection</li>
                        <li>• Load balancing and routing</li>
                      </ul>
                    </div>
                  </div>
                </div>

                {/* Functional Cookies */}
                <div className="border border-pink-200 dark:border-pink-800 bg-pink-50 dark:bg-pink-900/20 rounded-lg p-4">
                  <div className="flex items-start gap-3">
                    <Settings className="w-5 h-5 text-pink-600 dark:text-pink-400 flex-shrink-0 mt-0.5" />
                    <div>
                      <h3 className="font-semibold text-pink-900 dark:text-pink-100 mb-2">Functional Cookies</h3>
                      <p className="text-sm text-pink-800 dark:text-pink-200 mb-2">
                        Enhance your experience and remember your preferences.
                      </p>
                      <ul className="space-y-1 text-sm text-pink-700 dark:text-pink-300">
                        <li>• Language and region settings</li>
                        <li>• Theme preferences (light/dark mode)</li>
                        <li>• Notification preferences</li>
                        <li>• Saved search filters</li>
                      </ul>
                    </div>
                  </div>
                </div>

                {/* Analytics Cookies */}
                <div className="border border-purple-200 dark:border-purple-800 bg-purple-50 dark:bg-purple-900/20 rounded-lg p-4">
                  <div className="flex items-start gap-3">
                    <BarChart3 className="w-5 h-5 text-purple-600 dark:text-purple-400 flex-shrink-0 mt-0.5" />
                    <div>
                      <h3 className="font-semibold text-purple-900 dark:text-purple-100 mb-2">Analytics Cookies</h3>
                      <p className="text-sm text-purple-800 dark:text-purple-200 mb-2">
                        Help us understand how users interact with our platform to improve services.
                      </p>
                      <ul className="space-y-1 text-sm text-purple-700 dark:text-purple-300">
                        <li>• Page views and user journey tracking</li>
                        <li>• Call quality metrics</li>
                        <li>• Feature usage statistics</li>
                        <li>• Performance monitoring</li>
                      </ul>
                    </div>
                  </div>
                </div>

                {/* Third-Party Cookies */}
                <div className="border border-rose-200 dark:border-rose-800 bg-rose-50 dark:bg-rose-900/20 rounded-lg p-4">
                  <div className="flex items-start gap-3">
                    <Shield className="w-5 h-5 text-rose-600 dark:text-rose-400 flex-shrink-0 mt-0.5" />
                    <div>
                      <h3 className="font-semibold text-rose-900 dark:text-rose-100 mb-2">Third-Party Cookies</h3>
                      <p className="text-sm text-rose-800 dark:text-rose-200 mb-2">
                        Used by trusted partners for payment processing, communication, and infrastructure.
                      </p>
                      <ul className="space-y-1 text-sm text-rose-700 dark:text-rose-300">
                        <li>• Payment gateway cookies (Stripe, Razorpay)</li>
                        <li>• Communication service cookies (Twilio, Agora)</li>
                        <li>• Cloud infrastructure cookies (AWS, GCP)</li>
                        <li>• Customer support chat cookies</li>
                      </ul>
                    </div>
                  </div>
                </div>
              </div>
            </motion.section>

            {/* 3. Call-Specific Cookies */}
            <motion.section
              variants={fadeInUp}
              className="bg-gradient-to-br from-purple-50 to-fuchsia-50 dark:from-purple-900/20 dark:to-fuchsia-900/20 rounded-xl p-5 shadow-sm border border-purple-200 dark:border-purple-800"
            >
              <h2 className="text-xl font-bold text-purple-900 dark:text-purple-100 mb-3">
                3. Call-Specific Cookies
              </h2>
              <p className="text-purple-800 dark:text-purple-200 leading-relaxed text-sm mb-4">
                Our calling platform uses specialized cookies to ensure smooth voice communication:
              </p>
              <div className="grid md:grid-cols-2 gap-4">
                <div className="bg-white dark:bg-gray-800 rounded-lg p-3 border border-purple-200 dark:border-purple-700">
                  <h4 className="font-semibold text-gray-900 dark:text-white mb-2">Session Management</h4>
                  <ul className="space-y-1 text-sm text-gray-600 dark:text-gray-400">
                    <li>• Call authentication tokens</li>
                    <li>• WebRTC connection data</li>
                    <li>• Quality monitoring flags</li>
                    <li>• Bandwidth optimization</li>
                  </ul>
                </div>
                <div className="bg-white dark:bg-gray-800 rounded-lg p-3 border border-purple-200 dark:border-purple-700">
                  <h4 className="font-semibold text-gray-900 dark:text-white mb-2">Quality Assurance</h4>
                  <ul className="space-y-1 text-sm text-gray-600 dark:text-gray-400">
                    <li>• Connection stability metrics</li>
                    <li>• Audio quality indicators</li>
                    <li>• Network performance data</li>
                    <li>• Device capability detection</li>
                  </ul>
                </div>
              </div>
            </motion.section>

            {/* 4. Cookie Management */}
            <motion.section
              variants={fadeInUp}
              className="bg-white dark:bg-gray-800 rounded-xl p-5 shadow-sm border border-gray-200 dark:border-gray-700"
            >
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-3">
                4. Managing Your Cookie Preferences
              </h2>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-sm mb-4">
                You have control over how we use cookies. Here's how you can manage your preferences:
              </p>
              <div className="space-y-3">
                <div className="flex items-start gap-3">
                  <span className="w-2 h-2 bg-pink-500 rounded-full mt-2 flex-shrink-0"></span>
                  <div>
                    <strong className="text-gray-900 dark:text-white">Account Settings:</strong>
                    <span className="text-gray-600 dark:text-gray-400 text-sm ml-1">Manage cookie preferences in your profile settings</span>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <span className="w-2 h-2 bg-pink-500 rounded-full mt-2 flex-shrink-0"></span>
                  <div>
                    <strong className="text-gray-900 dark:text-white">Browser Settings:</strong>
                    <span className="text-gray-600 dark:text-gray-400 text-sm ml-1">Control cookies through your browser preferences</span>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <span className="w-2 h-2 bg-pink-500 rounded-full mt-2 flex-shrink-0"></span>
                  <div>
                    <strong className="text-gray-900 dark:text-white">Opt-out Links:</strong>
                    <span className="text-gray-600 dark:text-gray-400 text-sm ml-1">Use our unsubscribe links for marketing communications</span>
                  </div>
                </div>
                <div className="flex items-start gap-3">
                  <span className="w-2 h-2 bg-pink-500 rounded-full mt-2 flex-shrink-0"></span>
                  <div>
                    <strong className="text-gray-900 dark:text-white">Mobile Apps:</strong>
                    <span className="text-gray-600 dark:text-gray-400 text-sm ml-1">Manage app permissions in your device settings</span>
                  </div>
                </div>
              </div>
            </motion.section>

            {/* 5. Cookie Retention */}
            <motion.section
              variants={fadeInUp}
              className="bg-white dark:bg-gray-800 rounded-xl p-5 shadow-sm border border-gray-200 dark:border-gray-700"
            >
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-3">
                5. How Long We Keep Cookies
              </h2>
              <div className="grid md:grid-cols-2 gap-4">
                <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                  <div className="flex items-center gap-2 mb-2">
                    <Clock className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                    <h4 className="font-semibold text-gray-900 dark:text-white">Session Cookies</h4>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Deleted when you close your browser or end your session. Typically last 24 hours maximum.
                  </p>
                </div>
                <div className="bg-gray-50 dark:bg-gray-700/50 rounded-lg p-3">
                  <div className="flex items-center gap-2 mb-2">
                    <Clock className="w-4 h-4 text-gray-600 dark:text-gray-400" />
                    <h4 className="font-semibold text-gray-900 dark:text-white">Persistent Cookies</h4>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    Remain until deleted or expired. Analytics cookies typically last 12-24 months.
                  </p>
                </div>
              </div>
            </motion.section>

            {/* 6. Impact of Disabling Cookies */}
            <motion.section
              variants={fadeInUp}
              className="bg-amber-50 dark:bg-amber-900/20 rounded-xl p-5 shadow-sm border border-amber-200 dark:border-amber-800"
            >
              <h2 className="text-xl font-bold text-amber-900 dark:text-amber-100 mb-3">
                6. What Happens If You Disable Cookies?
              </h2>
              <p className="text-amber-800 dark:text-amber-200 leading-relaxed text-sm mb-4">
                While you can disable non-essential cookies, this may affect your experience:
              </p>
              <div className="space-y-2 text-amber-700 dark:text-amber-300 text-sm">
                <p><strong>Essential Cookies Disabled:</strong> Core platform functionality may not work, including login and calling features.</p>
                <p><strong>Functional Cookies Disabled:</strong> You'll need to re-enter preferences and settings on each visit.</p>
                <p><strong>Analytics Cookies Disabled:</strong> We won't be able to improve the platform based on usage patterns.</p>
                <p><strong>Third-Party Cookies Disabled:</strong> Payment processing and some communication features may be affected.</p>
              </div>
            </motion.section>

            {/* 7. Updates to This Policy */}
            <motion.section
              variants={fadeInUp}
              className="bg-white dark:bg-gray-800 rounded-xl p-5 shadow-sm border border-gray-200 dark:border-gray-700"
            >
              <h2 className="text-xl font-bold text-gray-900 dark:text-white mb-3">
                7. Updates to This Cookie Policy
              </h2>
              <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-sm">
                We may update this Cookie Policy to reflect changes in our practices or for legal reasons. We'll notify you of significant changes through our platform or via email. Your continued use of Callto after changes take effect constitutes acceptance of the updated policy.
              </p>
            </motion.section>

            {/* 8. Contact Information */}
            <motion.section
              variants={fadeInUp}
              className="bg-gradient-to-br from-pink-50 to-rose-50 dark:from-pink-900/20 dark:to-rose-900/20 rounded-xl p-5 shadow-sm border border-pink-200 dark:border-pink-800"
            >
              <h2 className="text-xl font-bold text-pink-900 dark:text-pink-100 mb-3">
                8. Contact Us About Cookies
              </h2>
              <p className="text-pink-800 dark:text-pink-200 leading-relaxed text-sm mb-4">
                Have questions about our cookie usage or need help managing your preferences?
              </p>
              <div className="grid md:grid-cols-2 gap-4">
                <div className="bg-white dark:bg-gray-800 rounded-lg p-3 border border-pink-200 dark:border-pink-700">
                  <h4 className="font-semibold text-gray-900 dark:text-white mb-2">Cookie Support</h4>
                  <p className="text-sm text-gray-700 dark:text-gray-300">
                    <strong>Email:</strong> cookies@callto.in<br />
                    <strong>Response Time:</strong> 2-3 business days
                  </p>
                </div>
                <div className="bg-white dark:bg-gray-800 rounded-lg p-3 border border-pink-200 dark:border-pink-700">
                  <h4 className="font-semibold text-gray-900 dark:text-white mb-2">Privacy Team</h4>
                  <p className="text-sm text-gray-700 dark:text-gray-300">
                    <strong>Email:</strong> privacy@callto.in<br />
                    <strong>Support:</strong> Available 24/7 in-app
                  </p>
                </div>
              </div>
            </motion.section>

            {/* Cookie Settings CTA */}
            <motion.section
              variants={fadeInUp}
              className="bg-gradient-to-r from-pink-500 to-rose-500 rounded-xl p-5 shadow-lg text-white text-center"
            >
              <Cookie className="w-12 h-12 mx-auto mb-3" />
              <h3 className="text-lg font-bold mb-2">
                Manage Your Cookie Preferences
              </h3>
              <p className="text-pink-100 leading-relaxed text-sm max-w-2xl mx-auto mb-4">
                Take control of your privacy. Update your cookie settings anytime through your account preferences.
              </p>
              <button className="bg-white text-pink-600 px-6 py-2 rounded-lg font-semibold hover:bg-pink-50 transition-colors">
                Open Cookie Settings
              </button>
              <div className="mt-4 text-xs text-pink-100">
                <p>Cookie Policy Version 1.2 - India</p>
              </div>
            </motion.section>
          </div>
        </div>
      </section>
    </div>
  );
};

export default CookiePolicy;