import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
                      "Privacy Policy",
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
                    icon: Icons.shield_rounded,
                    title: "Your Privacy Matters",
                    content: "This policy explains how Appdost Technologies Pvt. Ltd. collects, uses, and protects your personal information when you use CallTo.",
                    color: Colors.blue,
                  ),
                  _infoBanner(
                    icon: Icons.gavel_rounded,
                    title: "Legal Compliance",
                    content: "Compliant with DPDP Act 2023 (India), IT Act 2000, and International data protection standards.",
                    color: Colors.green,
                  ),

                  _section(
                    title: "1. About CallTo & Ownership",
                    body: "CallTo is a product and brand fully owned and operated by Appdost Technologies Pvt. Ltd., registered in India. All data processing and legal responsibilities are managed by the parent company.",
                  ),

                  _section(
                    title: "2. Information We Collect",
                    body: "We collect information to provide better services to our users. This includes:",
                    bullets: const [
                      "Personal Information: Name, email, phone number, gender, and date of birth.",
                      "Device Data: Model, operating system, IP address, and unique device identifiers.",
                      "Usage Data: Call logs (duration, timing), app preferences, and interaction history.",
                      "Media: Profile pictures and identity documents (only when required for verification).",
                    ],
                  ),

                  _section(
                    title: "3. Purpose of Data Collection",
                    body: "Your data is used strictly for legitimate business purposes:",
                    bullets: const [
                      "Facilitating real-time voice communication.",
                      "Account verification and security monitoring.",
                      "Preventing fraud, harassment, and illegal activities.",
                      "Improving app performance and user experience.",
                      "Complying with legal and regulatory obligations.",
                    ],
                  ),

                  _dangerSection(
                    title: "4. Data Sharing Policy",
                    body: "We value your trust. CallTo DOES NOT sell your personal data to third parties.",
                    bullets: const [
                      "Data is shared with our parent company (Appdost) for operational needs.",
                      "Shared with secure payment gateways for processing transactions.",
                      "Disclosed to law enforcement only when required by valid legal process.",
                    ],
                  ),

                  _section(
                    title: "5. Data Security & Encryption",
                    body: "We implement industry-standard security measures to protect your data:",
                    bullets: const [
                      "End-to-end encryption for signaling and communication.",
                      "Secure SSL/TLS encryption for all data in transit.",
                      "Regular security audits and data minimization practices.",
                      "Strict access controls for employee data handling.",
                    ],
                  ),

                  _section(
                    title: "6. Your Data Rights",
                    body: "Under the DPDP Act and other applicable laws, you have the right to:",
                    bullets: const [
                      "Access and download your personal data.",
                      "Correct or update inaccurate information.",
                      "Request deletion of your account and associated data.",
                      "Withdraw consent for data processing at any time.",
                    ],
                  ),

                  _dangerSection(
                    title: "7. Age Restriction",
                    body: "CallTo is strictly for adults aged 18 and above.",
                    bullets: const [
                      "We do not knowingly collect data from minors.",
                      "Accounts found to be operated by minors will be terminated immediately.",
                    ],
                  ),

                  _section(
                    title: "8. Data Retention",
                    body: "We retain your information only as long as necessary to provide services or comply with legal obligations. Upon account deletion, your data is securely erased or anonymized within our systems.",
                  ),

                  _section(
                    title: "9. Contact Information",
                    body: "For privacy-related inquiries, data rights requests, or grievances, please reach out to us:",
                    bullets: const [
                      "Email: privacy@callto.in",
                      "Support: support@callto.in",
                      "Phone: +91 7061588507",
                      "Address: Appdost Technologies Pvt. Ltd., Patna, Bihar, India",
                      "Grievance Redressal: For IT Act 2000 complaints, contact our Grievance Officer at support@callto.in",
                    ],
                  ),

                  _section(
                    title: "10. Changes to Privacy Policy",
                    body: "Callto may update this Privacy Policy periodically. Significant changes will be notified through in-app messages, email, or the platform. Continued use of Callto indicates acceptance of updated policies.",
                  ),

                  _finalNotice(),
                  
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

  Widget _finalNotice() {
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
          Icon(Icons.lock_person_rounded, size: 56, color: Colors.white),
          SizedBox(height: 16),
          Text(
            "Privacy Commitment",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Text(
            "We are committed to protecting your personal data and ensuring a safe communication environment. Your trust is our foundation.",
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
