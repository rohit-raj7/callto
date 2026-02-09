import React from 'react';
import { motion } from 'framer-motion';
import { useNavigate, Link } from 'react-router-dom';
import { 
  Phone, Shield, Users, Lock, ArrowRight, CheckCircle2, 
  UserCheck, MessageCircle, Sparkles, Clock, Shuffle, Headphones, Heart
} from 'lucide-react';
import PublicNavbar from '../components/PublicNavbar';
import downloadApp from '../assets/downloadApp.svg';

const LandingPage = () => {
  const navigate = useNavigate();

  // Animation variants
  const fadeInUp = {
    hidden: { opacity: 0, y: 60 },
    visible: { opacity: 1, y: 0 }
  };

  const staggerContainer = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.2
      }
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <PublicNavbar />

      {/* Hero Section */}
      <section id="home" className="relative pt-32 pb-20 px-4 overflow-hidden">
        {/* Animated Background */}
        <div className="absolute inset-0 bg-gradient-to-br from-pink-50 via-rose-50 to-pink-100 dark:from-pink-950 dark:via-rose-950 dark:to-pink-950">
          <motion.div
            animate={{
              scale: [1, 1.2, 1],
              rotate: [0, 90, 0],
            }}
            transition={{
              duration: 20,
              repeat: Infinity,
              repeatType: 'reverse'
            }}
            className="absolute top-20 left-20 w-72 h-72 bg-pink-200/30 dark:bg-pink-700/30 rounded-full blur-3xl"
          />
          <motion.div
            animate={{
              scale: [1, 1.3, 1],
              rotate: [0, -90, 0],
            }}
            transition={{
              duration: 25,
              repeat: Infinity,
              repeatType: 'reverse'
            }}
            className="absolute bottom-20 right-20 w-96 h-96 bg-rose-200/30 dark:bg-rose-700/30 rounded-full blur-3xl"
          />
        </div>

        {/* Hero Content */}
        <div className="relative max-w-7xl mx-auto">
          <motion.div
            initial="hidden"
            animate="visible"
            variants={staggerContainer}
            className="text-center max-w-4xl mx-auto"
          >
            <motion.div
              variants={fadeInUp}
              className="inline-flex items-center space-x-2 bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm px-4 py-2 rounded-full mb-6 shadow-md"
            >
              <Sparkles className="w-4 h-4 text-pink-600" />
              <span className="text-sm font-semibold text-gray-700 dark:text-gray-300">
                Talk to Someone Who Understands You 
              </span>
               <Sparkles className="w-4 h-4 text-pink-600" />
            </motion.div>

            <motion.h1
              variants={fadeInUp}
              className="text-5xl sm:text-6xl lg:text-7xl font-bold mb-6"
            >
              <span className="bg-gradient-to-r from-pink-500 via-rose-500 to-pink-600 bg-clip-text text-transparent">
                Callto
              </span>
              <br />
              <span className="text-gray-900 dark:text-white">
                Connect & Talk
              </span>
            </motion.h1>

            <motion.p
              variants={fadeInUp}
              className="text-xl text-gray-600 dark:text-gray-300 mb-10 max-w-2xl mx-auto"
            >
              Connect with expert listeners who can help you with life challenges, 
              career advice, relationships, and more. Your conversation, your choice.
            </motion.p>

            <motion.div
              variants={fadeInUp}
              className="flex flex-col sm:flex-row items-center justify-center gap-4"
            >
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="bg-gradient-to-r from-pink-500 to-rose-500 text-white px-8 py-4 rounded-xl font-semibold text-lg shadow-lg hover:shadow-xl transition-all flex items-center space-x-2 group"
              >
                <span>Download App</span>
                <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
              </motion.button>
              
              <motion.a
                href="https://play.google.com/store"
                target="_blank"
                rel="noopener noreferrer"
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="bg-white dark:bg-gray-800 px-6 py-3 rounded-xl shadow-lg hover:shadow-xl transition-all border border-gray-200 dark:border-gray-700 flex items-center justify-center"
              >
                {/* Play Store Badge */}
                <img src={downloadApp} alt="Get it on Play Store" className="h-12 w-auto" />
              </motion.a>
            </motion.div>

            {/* Stats */}
            <motion.div
              variants={fadeInUp}
              className="grid grid-cols-3 gap-8 mt-16 max-w-2xl mx-auto"
            >
              {[
                { value: '50K+', label: 'Happy Users' },
                { value: '100K+', label: 'Calls Made' },
                { value: '98%', label: 'Satisfaction Rate' }
              ].map((stat, index) => (
                <div key={index} className="text-center">
                  <div className="text-3xl sm:text-4xl font-bold bg-gradient-to-r from-pink-500 to-rose-500 bg-clip-text text-transparent">
                    {stat.value}
                  </div>
                  <div className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                    {stat.label}
                  </div>
                </div>
              ))}
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* Features Section */}
      <section id="features" className="py-20 px-4 bg-white dark:bg-gray-800">
        <div className="max-w-7xl mx-auto">
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            variants={staggerContainer}
            className="text-center mb-16"
          >
            <motion.h2
              variants={fadeInUp}
              className="text-4xl sm:text-5xl font-bold text-gray-900 dark:text-white mb-4"
            >
              Why Choose Callto?
            </motion.h2>
            <motion.p
              variants={fadeInUp}
              className="text-xl text-gray-600 dark:text-gray-300 max-w-2xl mx-auto"
            >
              Experience meaningful conversations with verified experts
            </motion.p>
          </motion.div>

          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            variants={staggerContainer}
            className="grid md:grid-cols-2 lg:grid-cols-4 gap-8"
          >
            {[
              {
                icon: Headphones,
                title: 'Expert Listeners',
                description: 'Talk to verified experts in life coaching, career advice, relationships & more',
                color: 'from-pink-500 to-rose-500'
              },
              {
                icon: Phone,
                title: 'Voice & Chat',
                description: 'Connect through voice calls or text chat - your choice, your comfort',
                color: 'from-pink-400 to-pink-600'
              },
              {
                icon: Lock,
                title: 'Private & Secure',
                description: 'Your conversations are completely private and confidential',
                color: 'from-rose-400 to-pink-500'
              },
              {
                icon: Shuffle,
                title: 'Random Connect',
                description: 'Try our random call feature to connect with available listeners instantly',
                color: 'from-pink-500 to-red-400'
              }
            ].map((feature, index) => (
              <motion.div
                key={index}
                variants={fadeInUp}
                whileHover={{ y: -10 }}
                className="bg-gray-50 dark:bg-gray-900 p-8 rounded-2xl shadow-lg hover:shadow-xl transition-all group"
              >
                <div className={`bg-gradient-to-r ${feature.color} w-16 h-16 rounded-xl flex items-center justify-center mb-6 group-hover:scale-110 transition-transform`}>
                  <feature.icon className="w-8 h-8 text-white" />
                </div>
                <h3 className="text-xl font-bold text-gray-900 dark:text-white mb-3">
                  {feature.title}
                </h3>
                <p className="text-gray-600 dark:text-gray-400">
                  {feature.description}
                </p>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* How It Works Section */}
      <section id="how-it-works" className="py-24 px-4 bg-gray-50 dark:bg-gray-900 relative overflow-hidden">
        {/* Background Patterns */}
        <div className="absolute top-0 left-0 w-full h-full overflow-hidden opacity-30 pointer-events-none">
            <div className="absolute -top-[20%] -left-[10%] w-[50%] h-[50%] bg-pink-200/20 rounded-full blur-[100px]" />
            <div className="absolute top-[40%] -right-[10%] w-[50%] h-[50%] bg-purple-200/20 rounded-full blur-[100px]" />
        </div>

        <div className="max-w-7xl mx-auto relative z-10">
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true, margin: "-100px" }}
            variants={staggerContainer}
            className="text-center mb-20"
          >
            <motion.div 
              variants={fadeInUp}
              className="inline-block mb-4"
            >
              <span className="text-sm font-bold text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-900/30 px-4 py-2 rounded-full uppercase tracking-wider">
                Simple & Effective
              </span>
            </motion.div>
            <motion.h2
              variants={fadeInUp}
              className="text-4xl sm:text-6xl font-extrabold text-gray-900 dark:text-white mb-6 leading-tight"
            >
              How <span className="bg-gradient-to-r from-pink-500 to-indigo-600 bg-clip-text text-transparent">Callto</span> Works
            </motion.h2>
            <motion.p
              variants={fadeInUp}
              className="text-xl text-gray-600 dark:text-gray-300 max-w-3xl mx-auto leading-relaxed"
            >
              Get connected with verified expert listeners in just <span className="font-semibold text-gray-900 dark:text-white">three simple steps</span>
            </motion.p>
          </motion.div>

          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            variants={staggerContainer}
            className="grid md:grid-cols-3 gap-8 lg:gap-12 relative max-w-6xl mx-auto pt-10"
          >
            {/* Connecting Line (Desktop) */}
            <div className="hidden md:block absolute top-24 left-[16%] right-[16%] h-0.5 bg-gradient-to-r from-pink-200 via-purple-200 to-indigo-200 dark:from-gray-700 dark:via-gray-600 dark:to-gray-700" />

            {[
              {
                step: '01',
                icon: UserCheck,
                title: 'Create Account',
                description: 'Sign up securely with your preferred method and customize your profile preferences.',
                color: 'text-pink-600',
                bg: 'bg-pink-50 dark:bg-pink-900/20',
                details: ['Quick 2-minute setup', 'Secure authentication', 'Personalized profile']
              },
              {
                step: '02',
                icon: Headphones,
                title: 'Choose Listener',
                description: 'Browse verified experts by topic or use our smart matching to find the perfect listener.',
                color: 'text-purple-600',
                bg: 'bg-purple-50 dark:bg-purple-900/20',
                details: ['100+ verified experts', 'Topic-based filtering', 'Real user reviews']
              },
              {
                step: '03',
                icon: Phone,
                title: 'Connect & Talk',
                description: 'Start a private voice call or chat instantly. Pay only for the time you talk.',
                color: 'text-indigo-600',
                bg: 'bg-indigo-50 dark:bg-indigo-900/20',
                details: ['Crystal clear audio', 'Pay-per-minute', '100% Private'],
                hasVoice: true
              }
            ].map((step, index) => (
              <motion.div
                key={index}
                variants={fadeInUp}
                className="relative z-10 h-full"
              >
                <div className="bg-white dark:bg-gray-800 rounded-[2.5rem] p-8 shadow-xl shadow-gray-200/50 dark:shadow-none border border-gray-100 dark:border-gray-700 h-full group hover:-translate-y-2 transition-all duration-500">
                  <div className="relative flex justify-center mb-8">
                    <div className="w-20 h-20 rounded-2xl bg-white dark:bg-gray-800 shadow-lg flex items-center justify-center relative z-10 border border-gray-50 dark:border-gray-700 group-hover:scale-110 transition-transform duration-500">
                       <span className={`text-2xl font-black bg-gradient-to-br from-pink-500 to-purple-600 bg-clip-text text-transparent`}>{step.step}</span>
                    </div>
                    <div className={`absolute inset-0 ${step.bg} rounded-2xl blur-xl transform group-hover:scale-150 transition-transform duration-500 opacity-60`} />
                  </div>

                  <div className="text-center relative">
                    {step.hasVoice && (
                      <div className="absolute -top-40 left-1/2 transform -translate-x-1/2 w-full flex justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-500 pointer-events-none">
                         <div className="flex items-center space-x-1 h-8">
                            {[1,2,3,4,5,4,3,2,1].map((h, i) => (
                              <motion.div
                                key={i}
                                animate={{ height: [10, 30, 10] }}
                                transition={{ duration: 1, repeat: Infinity, delay: i * 0.1 }}
                                className="w-1 bg-indigo-500 rounded-full"
                              />
                            ))}
                         </div>
                      </div>
                    )}
                    
                    <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-4">
                      {step.title}
                    </h3>
                    <p className="text-gray-600 dark:text-gray-400 leading-relaxed mb-8">
                      {step.description}
                    </p>

                    <div className="bg-gray-50 dark:bg-gray-700/30 rounded-2xl p-5 space-y-3 text-left border border-gray-100 dark:border-gray-600/50">
                      {step.details.map((detail, idx) => (
                        <div key={idx} className="flex items-start text-sm text-gray-700 dark:text-gray-300">
                          <CheckCircle2 className={`w-4 h-4 mr-3 flex-shrink-0 mt-0.5 ${step.color}`} />
                          <span className="font-medium">{detail}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </motion.div>
            ))}
          </motion.div>
        </div>
      </section>

      {/* About Section */}
      <section id="about" className="py-20 px-4 bg-white dark:bg-gray-800">
        <div className="max-w-4xl mx-auto">
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            variants={staggerContainer}
            className="text-center mb-16"
          >
            <motion.h2
              variants={fadeInUp}
              className="text-4xl sm:text-5xl font-bold text-gray-900 dark:text-white mb-4"
            >
              About Callto
            </motion.h2>
            <motion.p
              variants={fadeInUp}
              className="text-xl text-gray-600 dark:text-gray-300 max-w-2xl mx-auto"
            >
              Connecting people with expert listeners for meaningful conversations
            </motion.p>
          </motion.div>

          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            variants={staggerContainer}
            className="grid md:grid-cols-2 gap-12 items-start"
          >
            <motion.div variants={fadeInUp} className="space-y-8">
              <div className="space-y-6">
                <h3 className="text-3xl font-bold text-gray-900 dark:text-white mb-6">
                  Who We Are
                </h3>
                <p className="text-gray-600 dark:text-gray-400 leading-relaxed text-lg">
                  Callto is a safe space to talk freely where your identity stays anonymous. We connect you with empathetic listeners who understand and support you when you're feeling low or just need someone to listen.
                </p>
                <div className="grid grid-cols-2 gap-4">
                  <div className="bg-gray-50 dark:bg-gray-700/30 p-4 rounded-xl">
                    <div className="flex items-center space-x-2 mb-2">
                      <div className="w-2 h-2 rounded-full bg-orange-500" />
                      <span className="font-bold text-gray-900 dark:text-white text-sm">Age Restricted</span>
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400">Strictly 18+ platform for adults only</p>
                  </div>
                  <div className="bg-gray-50 dark:bg-gray-700/30 p-4 rounded-xl">
                    <div className="flex items-center space-x-2 mb-2">
                      <div className="w-2 h-2 rounded-full bg-red-500" />
                      <span className="font-bold text-gray-900 dark:text-white text-sm">Not Dating</span>
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400">Purely for social connection & support</p>
                  </div>
                  <div className="bg-gray-50 dark:bg-gray-700/30 p-4 rounded-xl">
                    <div className="flex items-center space-x-2 mb-2">
                      <div className="w-2 h-2 rounded-full bg-blue-500" />
                      <span className="font-bold text-gray-900 dark:text-white text-sm">Secure Wallet</span>
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400">Transparent billing & transactions</p>
                  </div>
                  <div className="bg-gray-50 dark:bg-gray-700/30 p-4 rounded-xl">
                    <div className="flex items-center space-x-2 mb-2">
                      <div className="w-2 h-2 rounded-full bg-pink-500" />
                      <span className="font-bold text-gray-900 dark:text-white text-sm">Voice Verified</span>
                    </div>
                    <p className="text-xs text-gray-500 dark:text-gray-400">Make money using Voice</p>
                  </div>
                </div>
                <div className="mt-4 bg-gray-50 dark:bg-gray-700/30 p-6 rounded-2xl border border-gray-100 dark:border-gray-600">
                  <h4 className="font-bold text-lg text-gray-900 dark:text-white mb-2">Become a Host</h4>
                  <p className="text-gray-600 dark:text-gray-400 text-sm mb-4">
                    Join our community of listeners. Answer calls and earn up to <span className="font-bold text-pink-600">₹10,000 every week!</span>
                  </p>
                  <div className="flex flex-wrap gap-2">
                    <span className="bg-pink-100 dark:bg-pink-900/30 text-pink-700 dark:text-pink-300 px-3 py-1 rounded-full text-xs font-medium">Voice Verification</span>
                    <span className="bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 px-3 py-1 rounded-full text-xs font-medium">Weekly Payouts</span>
                    <span className="bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300 px-3 py-1 rounded-full text-xs font-medium">Flexible Hours</span>
                  </div>
                </div>
                <div className="mt-4 bg-gray-50 dark:bg-gray-700/30 p-6 rounded-2xl border border-gray-100 dark:border-gray-600">
                  <h4 className="font-bold text-lg text-gray-900 dark:text-white mb-2">Find Support</h4>
                  <p className="text-gray-600 dark:text-gray-400 text-sm mb-4">
                    Connect with empathetic listeners in a safe, anonymous space. Get support for life challenges, career advice, and relationships.
                  </p>
                  <div className="flex flex-wrap gap-2">
                    <span className="bg-pink-100 dark:bg-pink-900/30 text-pink-700 dark:text-pink-300 px-3 py-1 rounded-full text-xs font-medium">Anonymous Chat</span>
                    <span className="bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 px-3 py-1 rounded-full text-xs font-medium">24/7 Support</span>
                    <span className="bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300 px-3 py-1 rounded-full text-xs font-medium">Topic-Based Matching</span>
                  </div>
                </div>
              </div>
            </motion.div>

            <motion.div variants={fadeInUp} className="space-y-6">
              <div className="bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 p-6 rounded-2xl shadow-sm hover:shadow-md transition-shadow group">
                <div className="flex items-start space-x-4">
                  <div className="bg-pink-100 dark:bg-pink-900/30 p-3 rounded-xl group-hover:bg-pink-200 dark:group-hover:bg-pink-900/50 transition-colors">
                    <Shield className="w-6 h-6 text-pink-600 dark:text-pink-400" />
                  </div>
                  <div>
                    <h4 className="font-bold text-lg text-gray-900 dark:text-white mb-2">Safe & Secure</h4>
                    <p className="text-gray-600 dark:text-gray-400 text-sm leading-relaxed">
                      Every call is safe and secure. No abuse. No misbehavior. We actively maintain a respectful space for everyone.
                    </p>
                  </div>
                </div>
              </div>

              <div className="bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 p-6 rounded-2xl shadow-sm hover:shadow-md transition-shadow group">
                <div className="flex items-start space-x-4">
                  <div className="bg-purple-100 dark:bg-purple-900/30 p-3 rounded-xl group-hover:bg-purple-200 dark:group-hover:bg-purple-900/50 transition-colors">
                    <Users className="w-6 h-6 text-purple-600 dark:text-purple-400" />
                  </div>
                  <div>
                    <h4 className="font-bold text-lg text-gray-900 dark:text-white mb-2">Empathetic Listeners</h4>
                    <p className="text-gray-600 dark:text-gray-400 text-sm leading-relaxed">
                      Connect with empathetic listeners who understand and support you. Whether you're feeling low or need advice, we're here.
                    </p>
                  </div>
                </div>
              </div>

              <div className="bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 p-6 rounded-2xl shadow-sm hover:shadow-md transition-shadow group">
                <div className="flex items-start space-x-4">
                  <div className="bg-indigo-100 dark:bg-indigo-900/30 p-3 rounded-xl group-hover:bg-indigo-200 dark:group-hover:bg-indigo-900/50 transition-colors">
                    <Lock className="w-6 h-6 text-indigo-600 dark:text-indigo-400" />
                  </div>
                  <div>
                    <h4 className="font-bold text-lg text-gray-900 dark:text-white mb-2">Private & Anonymous</h4>
                    <p className="text-gray-600 dark:text-gray-400 text-sm leading-relaxed">
                      Your name & face are always private. Your identity stays anonymous, creating a safe space to talk freely without judgment.
                    </p>
                  </div>
                </div>
              </div>

              {/* Support Contact Mini-Card */}
              <div className="bg-gradient-to-r from-gray-50 to-gray-100 dark:from-gray-800 dark:to-gray-700/50 p-4 rounded-xl border border-gray-200 dark:border-gray-600 flex items-center justify-between">
                <div>
                  <p className="text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Need Help?</p>
                  <p className="text-sm font-semibold text-gray-900 dark:text-white">support@callto.in</p>
                </div>
                <div className="h-8 w-px bg-gray-300 dark:bg-gray-600 mx-4" />
                <div>
                  <p className="text-xs font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Grievance Officer</p>
                  <p className="text-sm font-semibold text-gray-900 dark:text-white">Available 24/7</p>
                </div>
              </div>
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* CTA Section */}
      <section className="py-20 px-4 bg-gradient-to-r from-pink-500 to-rose-500">
        <div className="max-w-4xl mx-auto text-center">
          <motion.div
            initial="hidden"
            whileInView="visible"
            viewport={{ once: true }}
            variants={staggerContainer}
          >
            <motion.h2
              variants={fadeInUp}
              className="text-4xl sm:text-5xl font-bold text-white mb-6"
            >
              Ready to Connect with Expert Listeners?
            </motion.h2>
            <motion.p
              variants={fadeInUp}
              className="text-xl text-pink-100 mb-10"
            >
              Join thousands of people who have already found meaningful conversations on Callto
            </motion.p>
            <motion.div
              variants={fadeInUp}
              className="flex flex-col sm:flex-row items-center justify-center gap-4"
            >
              <motion.button
                whileHover={{ scale: 1.05 }}
                whileTap={{ scale: 0.95 }}
                className="bg-white text-pink-600 px-8 py-4 rounded-xl font-semibold text-lg shadow-lg hover:shadow-xl transition-all flex items-center space-x-2"
              >
                <span>Start Your Journey</span>
                <ArrowRight className="w-5 h-5" />
              </motion.button>
            </motion.div>

            {/* Trust Badges */}
            <motion.div
              variants={fadeInUp}
              className="mt-16 flex flex-wrap items-center justify-center gap-8 text-white/80"
            >
              {[
                'SSL Secured',
                'GDPR Compliant',
                'Verified Listeners',
                '24/7 Support'
              ].map((badge, index) => (
                <div key={index} className="flex items-center space-x-2">
                  <CheckCircle2 className="w-5 h-5" />
                  <span className="text-sm font-medium">{badge}</span>
                </div>
              ))}
            </motion.div>
          </motion.div>
        </div>
      </section>

      {/* Footer */}
      <footer className="bg-gray-900 text-gray-400 py-8 px-4">
        <div className="max-w-7xl mx-auto">
          <div className="flex flex-col items-center space-y-4">
            {/* Logo */}
            <div className="flex items-center space-x-2">
              <div className="bg-gradient-to-r from-pink-500 to-rose-500 p-2 rounded-lg">
                <Phone className="w-5 h-5 text-white" />
              </div>
              <span className="text-xl font-bold text-white">Callto</span>
            </div>
            
            {/* Links */}
            <div className="flex flex-wrap items-center justify-center gap-x-6 gap-y-2 text-sm">
              <Link to="/privacy-policy" className="hover:text-white transition-colors">
                Privacy Policy
              </Link>
              <span className="text-gray-600">•</span>
              <Link to="/terms-of-service" className="hover:text-white transition-colors">
                Terms of Service
              </Link>
              <span className="text-gray-600">•</span>
              <Link to="/cookie-policy" className="hover:text-white transition-colors">
                Cookie Policy
              </Link>
            </div>

            {/* Play Store Button */}
            <motion.a
              href="https://play.google.com/store"
              target="_blank"
              rel="noopener noreferrer"
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="bg-white dark:bg-gray-800 px-5 py-2.5 rounded-xl shadow hover:shadow-md transition-all border border-gray-200 dark:border-gray-700 flex items-center justify-center"
            >
              <img src={downloadApp} alt="Get it on Play Store" className="h-10 w-auto" />
            </motion.a>
            
            {/* Copyright */}
            <p className="text-sm text-gray-500">
              © 2026 Callto. All rights reserved.
            </p>
          </div>
        </div>
      </footer>
    </div>
  );
};

export default LandingPage;
