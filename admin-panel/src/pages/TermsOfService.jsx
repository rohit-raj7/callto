import React from 'react';
import { motion } from 'framer-motion';
import { Scale, FileText, Shield, AlertCircle, CheckCircle, Users, AlertTriangle, Mail, Phone, MapPin } from 'lucide-react';
import PublicNavbar from '../components/PublicNavbar';

const TermsOfService = () => {
  const fadeInUp = {
    hidden: { opacity: 0, y: 20 },
    visible: { opacity: 1, y: 0 }
  };

  const staggerContainer = {
    hidden: { opacity: 0 },
    visible: {
      opacity: 1,
      transition: {
        staggerChildren: 0.1
      }
    }
  };

  const sections = [
    { id: 'intro', title: 'Introduction' },
    { id: 'registration', title: 'Registration and Eligibility' },
    { id: 'platform', title: 'Nature of the Platform' },
    { id: 'conduct', title: 'User Conduct During Calls' },
    { id: 'account', title: 'Account Responsibilities' },
    { id: 'prohibited', title: 'Prohibited Activities' },
    { id: 'privacy', title: 'Privacy and Data Handling' },
    { id: 'payments', title: 'Payments and Premium Features' },
    { id: 'ip', title: 'Intellectual Property Rights' },
    { id: 'thirdparty', title: 'Third-Party Services' },
    { id: 'availability', title: 'Service Availability' },
    { id: 'modifications', title: 'Modifications to Terms' },
    { id: 'liability', title: 'Limitations of Liability' },
    { id: 'dispute', title: 'Dispute Resolution' },
    { id: 'contact', title: 'Contact Information' },
    { id: 'acceptance', title: 'Acceptance of Terms' },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800">
      <PublicNavbar />
      
      {/* Hero Section */}
      <section className="relative pt-16 md:pt-32 pb-8 md:pb-12 px-4">
        <div className="max-w-4xl mx-auto">
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            className="text-center"
          >
            <div className="inline-flex items-center justify-center w-16 h-16 md:w-20 md:h-20 bg-gradient-to-br from-pink-500 to-rose-600 rounded-2xl mb-4 md:mb-6 shadow-xl">
              <Scale className="w-8 h-8 md:w-10 md:h-10 text-white" strokeWidth={2.5} />
            </div>
            <h1 className="text-3xl md:text-5xl font-extrabold text-gray-900 dark:text-white mb-2 md:mb-4 leading-tight">
              Terms &amp; Conditions
            </h1>
            <p className="text-base md:text-xl text-gray-600 dark:text-gray-300 max-w-3xl mx-auto px-2">
              Please read these terms carefully before using CallTo services
            </p>
            <p className="text-xs md:text-sm text-gray-500 dark:text-gray-400 mt-3 md:mt-4">
              Last Updated: January 30, 2026
            </p>
          </motion.div>
        </div>
      </section>

      {/* Content Section */}
      <section className="py-8 md:py-16 px-4">
        <div className="max-w-4xl mx-auto">
          <div className="bg-white dark:bg-gray-800 rounded-xl md:rounded-2xl shadow-lg md:shadow-2xl p-4 md:p-8 lg:p-12 border border-gray-200 dark:border-gray-700">
            
            {/* Company Info Banner */}
            <div className="bg-gradient-to-r from-blue-50 to-indigo-50 dark:from-blue-900/30 dark:to-indigo-900/30 border-l-4 border-blue-500 p-4 md:p-6 rounded-lg mb-6 md:mb-8">
              <div className="flex items-start gap-2 md:gap-3">
                <MapPin className="w-5 h-5 md:w-6 md:h-6 text-blue-600 dark:text-blue-400 flex-shrink-0 mt-0.5 md:mt-1" />
                <div>
                  <h3 className="font-bold text-blue-900 dark:text-blue-100 mb-1 text-sm md:text-base">Parent Company</h3>
                  <p className="text-xs md:text-sm text-blue-800 dark:text-blue-200">
                    Appdost Complete IT Solution Pvt. Ltd., Patna, Bihar, India
                  </p>
                </div>
              </div>
            </div>

            {/* Important Notice */}
            <div className="bg-gradient-to-r from-amber-50 to-orange-50 dark:from-amber-900/20 dark:to-orange-900/20 border-l-4 border-amber-500 p-4 md:p-6 rounded-lg mb-6 md:mb-8">
              <div className="flex items-start gap-2 md:gap-3">
                <AlertCircle className="w-5 h-5 md:w-6 md:h-6 text-amber-600 dark:text-amber-400 flex-shrink-0 mt-0.5 md:mt-1" />
                <div>
                  <h3 className="font-bold text-amber-900 dark:text-amber-100 mb-1 text-sm md:text-base">Important Notice</h3>
                  <p className="text-xs md:text-sm text-amber-800 dark:text-amber-200">
                    By accessing or using CallTo, you agree to be bound by these Terms and Conditions. 
                    If you do not agree to these terms, please do not use our services.
                  </p>
                </div>
              </div>
            </div>

            {/* Terms Content */}
            <div className="space-y-6 md:space-y-8">
              
              {/* 1. Introduction */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  1. Introduction
                </h2>
                <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                  These Terms and Conditions form a comprehensive, binding agreement between the individual user and CallTo, a communication platform owned and managed under its parent company, Appdost Complete IT Solution Pvt. Ltd. By installing or using the CallTo application, the user confirms that they have fully understood and accepted the obligations, rights, and responsibilities defined herein. These Terms govern all aspects of the user's relationship with CallTo, including account creation, real-time communication features, conduct rules, privacy practices, and legal expectations. If the user does not agree with any portion of these Terms, they must immediately discontinue usage and uninstall the application.
                </p>
              </motion.section>

              {/* 2. Registration and Eligibility */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  2. Registration and Eligibility
                </h2>
                <div className="space-y-3 md:space-y-4">
                  <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                    To access and use the services of CallTo, a user must complete the registration process using accurate and verifiable information. Registration requires providing a valid mobile number, email address, or authentication through approved third-party login systems such as Google.
                  </p>
                  <ul className="space-y-2 text-gray-600 dark:text-gray-400">
                    <li className="flex items-start space-x-2 text-xs md:text-sm">
                      <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                      <span>Only individuals 18+ years old are eligible to register independently</span>
                    </li>
                    <li className="flex items-start space-x-2 text-xs md:text-sm">
                      <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                      <span>Minors may use with parental consent and supervision</span>
                    </li>
                    <li className="flex items-start space-x-2 text-xs md:text-sm">
                      <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                      <span>All provided information must remain truthful and updated</span>
                    </li>
                    <li className="flex items-start space-x-2 text-xs md:text-sm">
                      <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                      <span>CallTo reserves right to verify identity if suspicious activity detected</span>
                    </li>
                  </ul>
                </div>
              </motion.section>

              {/* 3. Nature of the Platform */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  3. Nature of the Platform and Real-Time Calling Features
                </h2>
                <div className="space-y-3 md:space-y-4">
                  <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                    CallTo provides digital communication services including voice calling, social conversation, user connections, and real-time interactive features. The platform is not a dating, escort, adult-content, or sexually oriented service.
                  </p>
                  <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-3 md:p-4">
                    <p className="text-xs md:text-sm text-red-800 dark:text-red-200">
                      <strong>Important:</strong> All conversations must remain within legal, safe, and respectful boundaries. Users may not attempt to transform the platform for intimate, explicit, indecent, or inappropriate purposes.
                    </p>
                  </div>
                </div>
              </motion.section>

              {/* 4. User Conduct During Calls */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  4. User Conduct During Real-Time Calls
                </h2>
                <ul className="space-y-2 text-gray-600 dark:text-gray-400">
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="text-red-500 font-bold flex-shrink-0">✗</span>
                    <span>Explicit, sexual, obscene, abusive, or threatening language prohibited</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="text-red-500 font-bold flex-shrink-0">✗</span>
                    <span>Recording conversations without consent is forbidden</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="text-red-500 font-bold flex-shrink-0">✗</span>
                    <span>Aggressive behavior, blackmail, or manipulation strictly forbidden</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <CheckCircle className="w-4 h-4 md:w-5 md:h-5 text-green-500 flex-shrink-0 mt-0.5" />
                    <span>Maintain respectful, lawful, and culturally appropriate communication</span>
                  </li>
                </ul>
              </motion.section>

              {/* 5. Account Responsibilities */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  5. Account Responsibilities
                </h2>
                <ul className="space-y-2 text-gray-600 dark:text-gray-400">
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Maintain confidentiality of login details and passwords</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>You are responsible for all activities under your account</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Immediately notify support if account is compromised</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Do not share device access with unauthorized individuals</span>
                  </li>
                </ul>
              </motion.section>

              {/* 6. Prohibited Activities */}
              <motion.section variants={fadeInUp} className="bg-red-50 dark:bg-red-900/20 rounded-lg md:rounded-xl p-4 md:p-6 border border-red-200 dark:border-red-800">
                <h2 className="text-xl md:text-2xl font-bold text-red-900 dark:text-red-100 mb-3 md:mb-4">
                  6. Prohibited Activities and Misuse
                </h2>
                <ul className="space-y-2 text-red-800 dark:text-red-200">
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-red-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Hacking, system manipulation, or using bots</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-red-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Creating fake profiles or impersonating others</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-red-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Spam, fraud, or engaging in illegal activities</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="text-red-500 font-bold">Violations lead to permanent account removal</span>
                  </li>
                </ul>
              </motion.section>

              {/* 7. Privacy and Data Handling */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  7. Privacy and Data Handling
                </h2>
                <div className="space-y-3 md:space-y-4">
                  <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                    CallTo collects personal information to operate and improve the application in compliance with India's DPDP Act and applicable data protection rules.
                  </p>
                  <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-3 md:p-4">
                    <p className="text-xs md:text-sm text-blue-900 dark:text-blue-100">
                      <strong>Data Uses:</strong> Safety, fraud detection, analytics, compliance, service improvement, and automated pattern analysis for complaints or unusual behavior.
                    </p>
                  </div>
                </div>
              </motion.section>

              {/* 8. Payments and Premium Features */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  8. Payments and Premium Features
                </h2>
                <ul className="space-y-2 text-gray-600 dark:text-gray-400">
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Ensure payment information is accurate and authorized</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Purchases may not be refundable unless stated explicitly</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Pricing may be revised or services discontinued</span>
                  </li>
                  <li className="flex items-start space-x-2 text-xs md:text-sm">
                    <span className="w-1.5 h-1.5 md:w-2 md:h-2 bg-pink-500 rounded-full mt-1.5 flex-shrink-0"></span>
                    <span>Auto-renewal occurs unless canceled before renewal date</span>
                  </li>
                </ul>
              </motion.section>

              {/* 9. Intellectual Property Rights */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  9. Intellectual Property Rights
                </h2>
                <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed mb-3">
                  All intellectual property relating to CallTo—including application code, user interface, branding, and digital assets—is the exclusive property of CallTo. Unauthorized use, copying, modification, or distribution is strictly prohibited under Indian and GCC intellectual property laws.
                </p>
              </motion.section>

              {/* 10. Third-Party Services */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  10. Third-Party Services
                </h2>
                <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                  CallTo may depend on third-party systems for cloud services, analytics, and authentication. These external systems operate independently, and CallTo does not control their policies or guarantee performance. Users interact with third-party systems at their own risk.
                </p>
              </motion.section>

              {/* 11. Service Availability and Termination */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  11. Service Availability and Termination
                </h2>
                <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed mb-3">
                  CallTo may modify, update, suspend, or discontinue services without prior notification. Technical interruptions may occur due to maintenance or network issues.
                </p>
                <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                  If a user violates any terms, CallTo may suspend, restrict, or terminate access permanently. CallTo is not responsible for restoring terminated accounts.
                </p>
              </motion.section>

              {/* 12. Modifications to Terms */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  12. Modifications and Updates to These Terms
                </h2>
                <div className="space-y-3 md:space-y-4">
                  <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                    CallTo reserves full authority to revise, update, or modify these Terms as required. Updates will be made available within the application or on the official website. Continued use after updates signifies acceptance of the modified Terms.
                  </p>
                  <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg p-3 md:p-4">
                    <p className="text-xs md:text-sm text-amber-900 dark:text-amber-100">
                      <strong>Important:</strong> If you disagree with updated Terms, your only remedy is to discontinue use and uninstall the application.
                    </p>
                  </div>
                </div>
              </motion.section>

              {/* 13. Limitations of Liability */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  13. Limitations of Liability
                </h2>
                <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed mb-3">
                  CallTo does not guarantee uninterrupted or flawless service. The platform is offered "as is," and CallTo is not liable for loss of data, emotional distress from user-to-user interaction, or damages caused by misuse or external interference.
                </p>
                <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
                  Users agree that CallTo is not responsible for the actions or behavior of other users during calls or for network failures, delayed connectivity, or device-related issues.
                </p>
              </motion.section>

              {/* 14. Dispute Resolution and Jurisdiction */}
              <motion.section variants={fadeInUp} className="bg-gray-50 dark:bg-gray-700/30 rounded-lg md:rounded-xl p-4 md:p-6 border border-gray-200 dark:border-gray-700">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  14. Dispute Resolution and Jurisdiction
                </h2>
                <div className="space-y-3 md:space-y-4 text-xs md:text-sm text-gray-600 dark:text-gray-400">
                  <p className="leading-relaxed">
                    All disputes or legal claims associated with CallTo shall be governed under Indian law.
                  </p>
                  <p className="leading-relaxed">
                    <strong>Exclusive Jurisdiction:</strong> The courts located in Patna, Bihar, India have exclusive jurisdiction for resolving disputes.
                  </p>
                  <p className="leading-relaxed">
                    Users located in GCC countries must comply with local conduct and digital behavior laws, but legal disputes remain subject to Indian jurisdiction unless mandated otherwise by local authority.
                  </p>
                </div>
              </motion.section>

              {/* 15. Contact Information */}
              <motion.section variants={fadeInUp} className="bg-gradient-to-br from-pink-50 to-rose-50 dark:from-pink-900/20 dark:to-rose-900/20 rounded-lg md:rounded-xl p-4 md:p-6 border border-pink-200 dark:border-pink-800">
                <h2 className="text-xl md:text-2xl font-bold text-gray-900 dark:text-white mb-3 md:mb-4">
                  15. Contact Information
                </h2>
                <div className="space-y-3 md:space-y-4">
                  <div className="flex items-start gap-2 md:gap-3">
                    <Mail className="w-4 h-4 md:w-5 md:h-5 text-pink-600 dark:text-pink-400 flex-shrink-0 mt-0.5 md:mt-1" />
                    <div>
                      <p className="text-xs md:text-sm font-semibold text-gray-900 dark:text-white">Email Support</p>
                      <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400">support@callto.in</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-2 md:gap-3">
                    <Mail className="w-4 h-4 md:w-5 md:h-5 text-pink-600 dark:text-pink-400 flex-shrink-0 mt-0.5 md:mt-1" />
                    <div>
                      <p className="text-xs md:text-sm font-semibold text-gray-900 dark:text-white">Legal Inquiries</p>
                      <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400">info@callto.in</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-2 md:gap-3">
                    <Phone className="w-4 h-4 md:w-5 md:h-5 text-pink-600 dark:text-pink-400 flex-shrink-0 mt-0.5 md:mt-1" />
                    <div>
                      <p className="text-xs md:text-sm font-semibold text-gray-900 dark:text-white">Phone</p>
                      <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400">+91 7061588507</p>
                    </div>
                  </div>
                  <div className="flex items-start gap-2 md:gap-3">
                    <MapPin className="w-4 h-4 md:w-5 md:h-5 text-pink-600 dark:text-pink-400 flex-shrink-0 mt-0.5 md:mt-1" />
                    <div>
                      <p className="text-xs md:text-sm font-semibold text-gray-900 dark:text-white">Headquarters</p>
                      <p className="text-xs md:text-sm text-gray-600 dark:text-gray-400">Appdost Complete IT Solution Pvt. Ltd., Patna, Bihar, India</p>
                    </div>
                  </div>
                </div>
              </motion.section>

              {/* 16. Acceptance of Terms */}
              <motion.section variants={fadeInUp} className="bg-gradient-to-r from-pink-500 to-rose-500 rounded-lg md:rounded-xl p-4 md:p-6 shadow-lg text-white text-center">
                <CheckCircle className="w-12 h-12 md:w-16 md:h-16 mx-auto mb-3 md:mb-4" />
                <h2 className="text-xl md:text-2xl font-bold mb-2 md:mb-3">
                  Acceptance of Terms
                </h2>
                <p className="text-xs md:text-sm text-pink-100 leading-relaxed">
                  By continuing to use CallTo, the user confirms that they have read, understood, and accepted all the Terms and Conditions contained in this document. Continued usage signifies ongoing consent to all current and updated Terms.
                </p>
                <div className="mt-4 md:mt-6 text-xs md:text-sm text-pink-100">
                  <p>These Terms are effective as of January 1, 2025</p>
                  <p className="mt-2">Version 3.0 - India</p>
                </div>
              </motion.section>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
};

export default TermsOfService;