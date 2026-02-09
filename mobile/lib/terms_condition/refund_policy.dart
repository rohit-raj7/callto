import 'package:flutter/material.dart';

class RefundPolicyScreen extends StatelessWidget {
  const RefundPolicyScreen({super.key});

  // App Colors - consistent with the rest of the app
  static const Color primaryPink = Color(0xFFFF4081);
  static const Color backgroundPink = Color(0xFFFCE4EC);
  static const Color textDark = Color(0xFF880E4F);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 360;
    final isSmall = width < 420;
    final textScale = isCompact ? 0.92 : 1.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : backgroundPink,
      body: CustomScrollView(
        slivers: [
          // Hero Section
          SliverAppBar(
            expandedHeight: isSmall ? 210 : 240,
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
                      height: isSmall ? 68 : 80,
                      width: isSmall ? 68 : 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isSmall ? 20 : 24),
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(isSmall ? 10 : 12),
                        child: Image.asset(
                          'assets/login/homelogo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Refund Policy",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmall ? 24 : 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Last Updated: February 05, 2026",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: isSmall ? 11 : 12,
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
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 16 : 20,
                vertical: 20,
              ),
              child: Column(
                children: [
                  _infoBanner(
                    icon: Icons.info_outline_rounded,
                    title: "Important Notice",
                    content: "Please read our refund terms carefully. By using CallTo, you agree to these policies regarding transactions and service fees.",
                    color: Colors.orange,
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _dangerSection(
                    title: "1. No Refund After Service Initiation",
                    body: "Once an order or service request is assigned or initiated, no refund will be issued under any circumstances.",
                    bullets: const [
                      "Live voice calls once connected.",
                      "Chat consultations once the session begins.",
                      "Any digital service that has been partially or fully delivered.",
                    ],
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _section(
                    title: "2. Technical Failures",
                    body: "We understand that technology can sometimes fail. Refunds may be considered only when a platform-side technical failure prevents delivery.",
                    bullets: const [
                      "Call could not connect due to system error.",
                      "Audio completely inaudible due to platform glitch.",
                      "Consultant was unreachable despite being shown as online.",
                      "Report the issue within 24 hours with your order details.",
                    ],
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _section(
                    title: "3. User Responsibility",
                    body: "Users are responsible for their own environment and device connectivity.",
                    bullets: const [
                      "No refunds for poor internet connection on the user's side.",
                      "No refunds for device or hardware issues (mic, speaker, etc.).",
                      "No refunds if you provide incorrect information during registration.",
                    ],
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _section(
                    title: "4. Dissatisfaction Policy",
                    body: "CallTo facilitates communication and entertainment. We do not guarantee the accuracy, quality, or outcome of any conversation.",
                    warning: "Dissatisfaction with a consultant's style, tone, advice, or emotional outcome is NOT a valid ground for a refund.",
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _section(
                    title: "5. Refund Deductions",
                    body: "In the rare event a refund is approved, it will be processed after deducting certain unavoidable costs:",
                    bullets: const [
                      "Payment gateway transaction fees.",
                      "Applicable government taxes and GST.",
                      "Operational processing charges.",
                      "Promotional credits or coupons already applied.",
                    ],
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _dangerSection(
                    title: "6. Wallet-Only Refunds",
                    body: "To ensure fast and secure processing, all approved refunds are handled via our internal wallet system.",
                    bullets: const [
                      "Refunds are credited ONLY to your CallTo Wallet.",
                      "Wallet balances cannot be withdrawn to a bank account or UPI.",
                      "Wallet credits can be used for any future services on CallTo.",
                    ],
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _section(
                    title: "7. Processing Time",
                    body: "Refund requests are subject to a quality audit. Our team will review call logs and system data to verify the claim.",
                    bullets: const [
                      "Audit and review may take up to 72 hours (3 business days).",
                      "You will be notified of the decision via email or app notification.",
                    ],
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _section(
                    title: "8. Order Cancellations by CallTo",
                    body: "If CallTo cancels a paid order or service due to internal reasons, a full refund of the amount paid will be credited to your wallet.",
                    textScale: textScale,
                    isCompact: isCompact,
                  ),

                  _contactSection(textScale: textScale, isCompact: isCompact),

                  _finalDecisionSection(textScale: textScale, isCompact: isCompact),

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
    double textScale = 1.0,
    bool isCompact = false,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 20 * textScale,
              fontWeight: FontWeight.bold,
              color: textDark,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                fontSize: 14 * textScale,
                color: Colors.grey.shade800,
                height: 1.5,
              ),
            ),
          ],
          if (bullets != null) ...[
            const SizedBox(height: 12),
            ...bullets.map((e) => Padding(
                  padding: EdgeInsets.only(bottom: isCompact ? 6 : 8, left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.check_circle_rounded, size: 16, color: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e,
                          style: TextStyle(
                            fontSize: 14 * textScale,
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
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_rounded, color: Colors.red.shade400, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 13 * textScale,
                        color: Colors.red.shade900,
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
    double textScale = 1.0,
    bool isCompact = false,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isCompact ? 12 : 16),
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18 * textScale,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(fontSize: 14 * textScale, color: Colors.red.shade900),
          ),
          const SizedBox(height: 12),
          ...bullets.map((e) => Padding(
                padding: EdgeInsets.only(bottom: isCompact ? 4 : 6),
                child: Row(
                  children: [
                    const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e,
                        style: TextStyle(fontSize: 13 * textScale, color: Colors.red.shade800),
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
    double textScale = 1.0,
    bool isCompact = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isCompact ? 12 : 16),
      padding: EdgeInsets.all(isCompact ? 14 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isCompact ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isCompact ? 20 : 24),
          ),
          SizedBox(width: isCompact ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14 * textScale,
                    color: color.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13 * textScale,
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

  Widget _contactSection({double textScale = 1.0, bool isCompact = false}) {
    return _section(
      title: "9. Contact Support",
      body: "If you believe you are eligible for a refund or have payment issues, please contact our billing team:",
      bullets: const [
        "Email: support@callto.in",
        "Subject: Refund Request - [Your Account ID]",
        "Phone: +91 7061588507",
      ],
      textScale: textScale,
      isCompact: isCompact,
    );
  }

  Widget _finalDecisionSection({double textScale = 1.0, bool isCompact = false}) {
    return Container(
      margin: EdgeInsets.only(top: isCompact ? 20 : 24),
      padding: EdgeInsets.all(isCompact ? 18 : 24),
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
        children: [
          Icon(Icons.gavel_rounded, size: isCompact ? 46 : 56, color: Colors.white),
          SizedBox(height: isCompact ? 12 : 16),
          Text(
            "Final Decision",
            style: TextStyle(
              fontSize: 22 * textScale,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: isCompact ? 8 : 10),
          Text(
            "All refund decisions made by the CallTo management team are final and non-negotiable.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14 * textScale,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

