


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
        scaffoldBackgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFFFE4EC),
        title: const Text(
          "Settings",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Column(
        children: [
          const SizedBox(height: 10),

          // --- Settings Options ---
          _buildSettingTile(
            icon: Icons.description_outlined,
            title: "Terms & Conditions",
            iconColor: Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.privacy_tip_outlined,
            title: "Privacy Policy",
            iconColor: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.receipt_long_outlined,
            title: "Refund Policy",
            iconColor: Colors.pinkAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RefundPolicyScreen()),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.help_outline,
            title: "FAQs",
            iconColor: Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FAQsPage()),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.logout,
            title: "Logout",
            iconColor: Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => LogoutPage()),
              );
            },
          ),
          _buildSettingTile(
            icon: Icons.delete_outline,
            title: "Delete Account",
            iconColor: Colors.redAccent,
            textColor: Colors.redAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DeleteAccountPage()),
              );
            },
          ),

          const Spacer(),

          // --- Footer ---
          Column(
            children: const [
              Icon(Icons.verified_user, color: Colors.green, size: 18),
              SizedBox(height: 4),
              Text(
                "100% Safe and Private",
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "Version: 1.0.0 (20251201)",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  // --- Reusable Settings Tile ---
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color iconColor = Colors.black54,
    Color textColor = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFE4EC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: Icon(icon, color: iconColor),
          title: Text(
            title,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: onTap,
        ),
      ),
    );
  }
}

