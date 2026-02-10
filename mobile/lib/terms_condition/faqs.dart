import 'package:flutter/material.dart';
import '../../support/contact_support.dart';

class FAQsPage extends StatefulWidget {
  const FAQsPage({super.key});

  @override
  State<FAQsPage> createState() => _FAQsPageState();
}

class _FAQsPageState extends State<FAQsPage> {
  String selectedCategory = 'All';

  // App Colors - consistent with the rest of the app
  static const Color primaryPink = Color(0xFFFF4081);
  static const Color backgroundPink = Color(0xFFFCE4EC);

  final Map<String, List<Map<String, String>>> categorizedFaqs = {
    'Account': [
      {
        "question": "How can I create an account?",
        "answer": "Tap on 'Sign Up' on the home screen, enter your email address and create a password. You'll receive a verification email to activate your account. Follow the link in the email to complete registration."
      },
      {
        "question": "How can I change my profile details?",
        "answer": "Go to your profile section by tapping your profile picture, then click 'Edit Profile'. You can update your name, bio, profile picture, and other personal information. Don't forget to save your changes."
      },
      {
        "question": "How do I reset my password?",
        "answer": "On the login screen, tap 'Forgot Password?', enter your registered email address, and we'll send you a password reset link. Click the link and follow the instructions to create a new password."
      },
      {
        "question": "Can I change my email address?",
        "answer": "Yes! Go to Settings → Account Settings → Email Address. Enter your new email and verify it through the confirmation email we send. Your old email will remain active until you confirm the new one."
      },
      {
        "question": "How do I delete my account?",
        "answer": "Navigate to Settings → Account Settings → Delete Account. You'll be asked to confirm your decision. Please note that this action is permanent and cannot be undone. All your data will be permanently deleted."
      },
    ],
    'Privacy & Security': [
      {
        "question": "How is my data protected?",
        "answer": "We use industry-standard end-to-end encryption for all data transmission. Your personal information is stored on secure cloud servers with multiple layers of protection including firewalls, intrusion detection systems, and regular security audits."
      },
      {
        "question": "Who can see my profile information?",
        "answer": "You have full control over your privacy settings. Go to Settings → Privacy to choose who can view your profile, contact you, and see your activity. Options include Everyone, Friends Only, or Only Me."
      },
      {
        "question": "Can I block or report users?",
        "answer": "Yes. Go to the user's profile, tap the three-dot menu, and select 'Block' or 'Report'. Blocked users cannot contact you or view your profile. Reported users are reviewed by our moderation team."
      },
      {
        "question": "Is my payment information secure?",
        "answer": "Absolutely. We don't store your credit card information on our servers. All payments are processed through certified payment gateways (Stripe, PayPal) that comply with PCI-DSS security standards."
      },
      {
        "question": "How do I enable two-factor authentication?",
        "answer": "Go to Settings → Security → Two-Factor Authentication. Choose between SMS or authenticator app. Follow the setup instructions to add an extra layer of security to your account."
      },
    ],
    'Features': [
      {
        "question": "How do I upload photos or videos?",
        "answer": "Tap the '+' button at the bottom of the screen, select 'Photo' or 'Video', choose from your gallery or take a new one. You can add filters, captions, and tags before posting."
      },
      {
        "question": "Can I edit or delete my posts?",
        "answer": "Yes! Tap the three-dot menu on your post and select 'Edit' to modify the caption or 'Delete' to remove it completely. Edited posts will show an 'edited' label."
      },
      {
        "question": "How does the search feature work?",
        "answer": "Use the search icon to find users, hashtags, or content. You can filter results by People, Posts, or Tags. Recent searches are saved for quick access and can be cleared in settings."
      },
      {
        "question": "What are notifications and how do I manage them?",
        "answer": "Notifications keep you updated on likes, comments, follows, and messages. Customize them in Settings → Notifications. You can enable/disable specific types or set quiet hours."
      },
      {
        "question": "How do I share content with friends?",
        "answer": "Tap the share icon on any post. You can share via direct message within the app, or to other platforms like WhatsApp, Facebook, or copy the link to share anywhere."
      },
    ],
    'Subscriptions': [
      
      {
        "question": "How do I upgrade my account?",
        "answer": "Go to Settings → Subscription → Choose Plan. Select your preferred plan, enter payment details, and confirm. Your premium features will activate immediately upon successful payment."
      },
      {
        "question": "Can I cancel my subscription anytime?",
        "answer": "Yes! Go to Settings → Subscription → Manage Subscription → Cancel. You'll retain premium access until the end of your billing period. No refunds for partial months."
      },
      {
        "question": "What payment methods do you accept?",
        "answer": "We accept all major credit/debit cards (Visa, Mastercard, American Express), PayPal, Apple Pay, and Google Pay. Payment methods can be managed in your account settings."
      },
      {
        "question": "Will I be charged automatically?",
        "answer": "Yes, subscriptions auto-renew unless cancelled. You'll receive an email reminder 3 days before renewal. You can turn off auto-renewal in Settings → Subscription anytime."
      },
    ],
    'Technical': [
      {
        "question": "The app is running slowly. What should I do?",
        "answer": "Try these steps: 1) Close and restart the app, 2) Clear cache in Settings → Storage, 3) Update to the latest version, 4) Restart your device, 5) Check your internet connection. Contact support if issues persist."
      },
      {
        "question": "Why am I not receiving notifications?",
        "answer": "Check: 1) Notifications are enabled in app Settings, 2) Device settings allow notifications for our app, 3) You're connected to the internet, 4) Battery optimization isn't restricting the app. Try logging out and back in."
      },
      {
        "question": "How do I update the app?",
        "answer": "Visit the App Store (iOS) or Google Play Store (Android), search for our app, and tap 'Update' if available. Enable automatic updates in your device's app store settings for convenience."
      },
      {
        "question": "Can I use the app on multiple devices?",
        "answer": "Yes! Log in with the same credentials on any device. Your data syncs automatically across all devices. You can manage active sessions in Settings → Security → Active Sessions."
      },
      {
        "question": "What should I do if the app crashes?",
        "answer": "First, force close and restart the app. If it continues, clear the app cache, update to the latest version, or reinstall. Send us a crash report through Settings → Help → Report a Problem with details."
      },
    ],
    'Support': [
      {
        "question": "How do I contact support?",
        "answer": "You can reach us at support@callto.in, use the in-app chat (Settings → Help → Contact Support), or call our helpline. Our support team is available 24/7 and typically responds within 2-4 hours."
      },
      {
        "question": "Can I recover a deleted account?",
        "answer": "Unfortunately, no. Account deletion is permanent and irreversible. All your data, posts, and connections are permanently removed from our servers within 30 days. We recommend downloading your data before deletion."
      },
      {
        "question": "How do I download my data?",
        "answer": "Go to Settings → Privacy → Download Your Data. We'll prepare a file containing all your information and send a download link to your email within 48 hours. The link expires after 7 days."
      },
      {
        "question": "Where can I report bugs or suggest features?",
        "answer": "We love feedback! Go to Settings → Help → Feedback or email support@callto.in. Include screenshots and detailed descriptions for bugs. We review all suggestions for future updates."
      },
      {
        "question": "Is there a user community or forum?",
        "answer": "Yes! Visit our official website to connect with other users, share tips, get help, and stay updated on new features. You can also join our official social media channels."
      },
    ],
  };

  List<Map<String, String>> get filteredFaqs {
    if (selectedCategory == 'All') {
      return categorizedFaqs.values.expand((list) => list).toList();
    }
    return categorizedFaqs[selectedCategory] ?? [];
  }

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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white30, width: 2),
                      ),
                      child: const Icon(Icons.help_outline_rounded,
                          color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "FAQs",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "How can we help you today?",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
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

          // Category Filter (SliverToBoxAdapter)
          SliverToBoxAdapter(
            child: Container(
              height: 50,
              margin: const EdgeInsets.symmetric(vertical: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildCategoryChip('All', Icons.apps_rounded, isDark),
                  _buildCategoryChip('Account', Icons.person_outline, isDark),
                  _buildCategoryChip('Privacy & Security', Icons.security_outlined, isDark),
                  _buildCategoryChip('Features', Icons.star_outline, isDark),
                  _buildCategoryChip('Subscriptions', Icons.payment_outlined, isDark),
                  _buildCategoryChip('Technical', Icons.settings_outlined, isDark),
                  _buildCategoryChip('Support', Icons.support_agent_outlined, isDark),
                ],
              ),
            ),
          ),

          // FAQ List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final faq = filteredFaqs[index];
                  return _buildFAQCard(faq, isDark);
                },
                childCount: filteredFaqs.length,
              ),
            ),
          ),

          // Contact Support Button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
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
                  children: [
                    const Icon(Icons.support_agent_rounded, size: 56, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      "Still Need Help?",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Our support team is available 24/7 to assist you with any questions or issues.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primaryPink,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ContactSupportPage()),
                        );
                      },
                      child: const Text(
                        "Contact Support",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, IconData icon, bool isDark) {
    final isSelected = selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            const SizedBox(width: 6),
            Text(category),
          ],
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        selectedColor: primaryPink,
        checkmarkColor: Colors.white,
        elevation: isSelected ? 2 : 0,
        side: BorderSide(
          color: isSelected ? primaryPink : (isDark ? Colors.white12 : Colors.grey[300]!),
          width: 1,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onSelected: (selected) {
          setState(() {
            selectedCategory = category;
          });
        },
      ),
    );
  }

  Widget _buildFAQCard(Map<String, String> faq, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.transparent,
          width: 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          iconColor: primaryPink,
          collapsedIconColor: isDark ? Colors.grey[600] : Colors.grey[400],
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryPink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.question_answer_rounded,
                  color: primaryPink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  faq["question"]!,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : backgroundPink.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                faq["answer"]!,
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[800],
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
