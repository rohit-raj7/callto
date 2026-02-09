import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  // App Colors - consistent with the rest of the app
  static const Color primaryPink = Color(0xFFFF4081);
  static const Color backgroundPink = Color(0xFFFCE4EC);
  static const Color textDark = Color(0xFF880E4F);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : backgroundPink,
      body: CustomScrollView(
        slivers: [
          // Hero Section with Gradient
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E293B) : primaryPink,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                        : [primaryPink, const Color(0xFFF06292)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      height: 80,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Image.asset(
                          'assets/login/homelogo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Terms & Conditions",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Last Updated: February 05, 2026",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          /// CONTENT
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _infoBanner(
                    icon: Icons.business_rounded,
                    title: "Parent Company",
                    content: "Appdost Technologies Pvt. Ltd.\nPatna, Bihar, India",
                    color: Colors.blue,
                  ),
                  _infoBanner(
                    icon: Icons.shield_outlined,
                    title: "Legal Agreement",
                    content: "By using CallTo, you agree to these terms. Please read them carefully as they affect your legal rights.",
                    color: Colors.green,
                  ),

                  _section(
                    title: "1. Introduction",
                    body: "Welcome to CallTo, a real-time voice communication platform owned and operated by Appdost Technologies Pvt. Ltd. These Terms and Conditions constitute a legally binding agreement between you (the 'User') and CallTo. By accessing our mobile application or website, you acknowledge that you have read, understood, and agree to be bound by these terms.",
                  ),

                  _section(
                    title: "2. Eligibility & Registration",
                    body: "To use CallTo, you must be at least 18 years of age. If you are under 18, you may only use the service with the explicit consent and supervision of a parent or legal guardian.",
                    bullets: const [
                      "Users must provide accurate, current, and complete registration information.",
                      "You are responsible for maintaining the confidentiality of your account credentials.",
                      "Only one account is permitted per user unless explicitly authorized.",
                      "CallTo reserves the right to suspend accounts providing false information.",
                    ],
                  ),

                  _section(
                    title: "3. Nature of Service",
                    body: "CallTo provides a platform for voice-based social interaction. It is designed for respectful communication and networking.",
                    warning: "CallTo is NOT a dating, escort, adult, or sexually oriented service. Any attempt to use the platform for such purposes will result in an immediate and permanent ban.",
                  ),

                  _section(
                    title: "4. User Conduct Guidelines",
                    body: "To ensure a safe environment for everyone, all users must adhere to the following conduct rules during calls and interactions:",
                    bullets: const [
                      "No use of profane, abusive, or sexually explicit language.",
                      "No harassment, bullying, or threats against other users.",
                      "No recording of calls or sharing user data without explicit consent.",
                      "No solicitation of money, gifts, or personal financial information.",
                      "Respect the privacy and boundaries of every person you connect with.",
                    ],
                  ),

                  _dangerSection(
                    title: "5. Prohibited Activities",
                    body: "Engaging in any of the following activities will lead to immediate account termination and potential legal action:",
                    bullets: const [
                      "Attempting to hack, scrape, or manipulate CallTo systems.",
                      "Creating fake profiles or impersonating other individuals.",
                      "Distributing malware, spam, or unauthorized advertisements.",
                      "Using the service for any illegal or fraudulent activities.",
                      "Violating the intellectual property rights of CallTo or others.",
                    ],
                  ),

                  _section(
                    title: "6. Payments & Wallet System",
                    body: "CallTo uses a virtual wallet system for premium features and services.",
                    bullets: const [
                      "All payments are processed through secure third-party gateways.",
                      "Wallet balances are non-transferable and non-refundable unless required by law.",
                      "Users are responsible for all charges incurred under their account.",
                      "Prices for services may be modified by CallTo at any time.",
                    ],
                  ),

                  _section(
                    title: "7. Intellectual Property",
                    body: "All content, logos, trademarks, code, and UI designs within the CallTo app are the exclusive property of Appdost Technologies Pvt. Ltd. and are protected by Indian and International copyright laws.",
                  ),

                  _section(
                    title: "8. Limitation of Liability",
                    body: "CallTo is provided on an 'AS IS' and 'AS AVAILABLE' basis. Appdost Technologies Pvt. Ltd. shall not be liable for any direct, indirect, incidental, or consequential damages arising from your use of the platform or interactions with other users.",
                  ),

                  _section(
                    title: "9. Privacy Policy Reference",
                    body: "Your use of CallTo is also governed by our Privacy Policy, which explains how we collect, use, and protect your personal data in compliance with the DPDP Act.",
                  ),

                  _section(
                    title: "10. Jurisdiction & Governing Law",
                    body: "These terms are governed by the laws of India. Any disputes arising from these terms shall be subject to the exclusive jurisdiction of the courts in Patna, Bihar, India.",
                  ),

                  _contactSection(),

                  _acceptanceSection(),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// -------- Widgets --------

  Widget _section({
    required String title,
    String? body,
    List<String>? bullets,
    String? warning,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
          ],
          if (bullets != null) ...[
            const SizedBox(height: 12),
            ...bullets.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 6, color: primaryPink),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          if (warning != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_rounded, color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dangerSection({
    required String title,
    required String body,
    required List<String> bullets,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gpp_maybe_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(fontSize: 14, color: Colors.red.shade900),
          ),
          const SizedBox(height: 12),
          ...bullets.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e,
                        style: TextStyle(fontSize: 13, color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _infoBanner({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _contactSection() {
    return _section(
      title: "11. Contact Us",
      body: "If you have any questions or concerns regarding these Terms and Conditions, please reach out to our legal and support teams:",
      bullets: const [
        "Customer Support: support@callto.in",
        "Legal Inquiries: info@callto.in",
        "Phone: +91 7061588507",
        "Registered Address: Appdost Technologies Pvt. Ltd., Patna, Bihar, India",
      ],
    );
  }

  Widget _acceptanceSection() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryPink, Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryPink.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: const [
          Icon(Icons.verified_user_rounded, size: 56, color: Colors.white),
          SizedBox(height: 16),
          Text(
            "Final Acceptance",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "By continuing to use the CallTo app, you signify your irrevocable acceptance of these Terms and Conditions.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

