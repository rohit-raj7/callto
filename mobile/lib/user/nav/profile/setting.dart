import 'package:flutter/material.dart';
import '../../../terms_condition/privacy_policy.dart';
import '../../../terms_condition/terms_of_use.dart';

import '../../../terms_condition/refund_policy.dart';
import '../../../account/delete.dart';
import '../../../account/logout.dart'; 
import '../../../terms_condition/faqs.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Settings UI',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        useMaterial3: true,
      ),
      home: const SettingsPage(),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1A1A1A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // General Section
            _buildSectionHeader("General"),
            _buildSettingsCard(
              children: [
                _buildSettingTile(
                  icon: Icons.description_outlined,
                  title: "Terms & Conditions",
                  subtitle: "Review our terms of service",
                  iconColor: const Color(0xFF4A90E2),
                  iconBgColor: const Color(0xFFE3F2FD),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  icon: Icons.privacy_tip_outlined,
                  title: "Privacy Policy",
                  subtitle: "How we handle your data",
                  iconColor: const Color(0xFF5C6BC0),
                  iconBgColor: const Color(0xFFEDE7F6),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  icon: Icons.receipt_long_outlined,
                  title: "Refund Policy",
                  subtitle: "Learn about refunds",
                  iconColor: const Color(0xFFD81B60),
                  iconBgColor: const Color(0xFFF8BBD0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RefundPolicyScreen()),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  icon: Icons.help_outline,
                  title: "FAQs",
                  subtitle: "Get answers to common questions",
                  iconColor: const Color(0xFF26A69A),
                  iconBgColor: const Color(0xFFE0F2F1),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FAQsPage()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Account Section
            _buildSectionHeader("Account"),
            _buildSettingsCard(
              children: [
                _buildSettingTile(
                  icon: Icons.logout,
                  title: "Logout",
                  subtitle: "Sign out of your account",
                  iconColor: const Color(0xFFFF9800),
                  iconBgColor: const Color(0xFFFFF3E0),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LogoutPage()),
                    );
                  },
                ),
                _buildDivider(),
                _buildSettingTile(
                  icon: Icons.delete_outline,
                  title: "Delete Account",
                  subtitle: "Permanently remove your account",
                  iconColor: const Color(0xFFE53935),
                  iconBgColor: const Color(0xFFFFEBEE),
                  textColor: const Color(0xFFE53935),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const DeleteAccountPage()),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Footer
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.shield_outlined, color: Color(0xFF43A047), size: 16),
                        SizedBox(width: 6),
                        Text(
                          "100% Safe and Private",
                          style: TextStyle(
                            color: Color(0xFF43A047),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Version 1.0.0 (20251201)",
                    style: TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section Header
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF757575),
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Settings Card Container
  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // Divider
  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 72),
      child: Divider(height: 1, color: Color(0xFFF0F0F0)),
    );
  }

  // Reusable Settings Tile
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    required Color iconBgColor,
    Color textColor = const Color(0xFF1A1A1A),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9E9E9E),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFFBDBDBD),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}