import 'package:flutter/material.dart';
import './user_profile.dart';

void main() {
  runApp(const MyApp());
}

/* -------------------------------------------------------------------------- */
/*                                DESIGN TOKENS                                */
/* -------------------------------------------------------------------------- */

class AppColors {
  static const primary = Color(0xFFFF4081);
  static const background = Color(0xFFFCE4EC);
  static const textDark = Color(0xFF880E4F);
  static const textLight = Colors.white;
}

class AppText {
  static const headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textDark,
  );

  static const subtitle = TextStyle(
    fontSize: 16,
    height: 1.5,
    color: AppColors.textDark,
  );

  static const button = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

/* -------------------------------------------------------------------------- */
/*                                   APP ROOT                                 */
/* -------------------------------------------------------------------------- */

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.primary,
        ),
        fontFamily: 'Roboto',
      ),
      home: const OnboardingScreen(),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                             ONBOARDING SCREEN                               */
/* -------------------------------------------------------------------------- */

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Widget> _pages = const [
    _PrivacyPage(),
    _TalkPage(),
    _SecurePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _controller,
              onPageChanged: (i) => setState(() => _currentPage = i),
              children: _pages,
            ),

            /* ----------------------------- BOTTOM CTA ----------------------------- */
            Positioned(
              left: 0,
              right: 0,
              bottom: 32,
              child: Column(
                children: [
                  _PageIndicator(
                    count: _pages.length,
                    index: _currentPage,
                  ),
                  const SizedBox(height: 32),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FemaleProfilePage(),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? "Get Started"
                              : "Next",
                          style: AppText.button,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                              PAGE INDICATOR                                 */
/* -------------------------------------------------------------------------- */

class _PageIndicator extends StatelessWidget {
  final int count;
  final int index;

  const _PageIndicator({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          height: 8,
          width: index == i ? 22 : 8,
          decoration: BoxDecoration(
            color: index == i ? AppColors.primary : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 PAGE 1                                     */
/* -------------------------------------------------------------------------- */

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  @override
  Widget build(BuildContext context) {
    return _OnboardLayout(
      icon: Icons.security,
      title: "Your name & face,\nalways private",
      subtitle: "Your identity stays anonymous.\nA safe space to talk freely.",
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 PAGE 2                                     */
/* -------------------------------------------------------------------------- */

class _TalkPage extends StatelessWidget {
  const _TalkPage();

  @override
  Widget build(BuildContext context) {
    return _OnboardLayout(
      icon: Icons.chat_bubble_outline,
      title: "Feeling low?\nTalk to listeners",
      subtitle:
          "Connect with empathetic listeners\nwho understand and support you.",
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                 PAGE 3                                     */
/* -------------------------------------------------------------------------- */

class _SecurePage extends StatelessWidget {
  const _SecurePage();

  @override
  Widget build(BuildContext context) {
    return _OnboardLayout(
      icon: Icons.lock_outline,
      title: "Every call is safe\nand secure",
      subtitle:
          "No abuse. No misbehavior.\nWe actively maintain a respectful space.",
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                              SHARED LAYOUT                                  */
/* -------------------------------------------------------------------------- */

class _OnboardLayout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardLayout({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.15),
            ),
            child: Icon(icon, size: 90, color: AppColors.primary),
          ),
          const SizedBox(height: 48),
          Text(title, textAlign: TextAlign.center, style: AppText.headline),
          const SizedBox(height: 16),
          Text(subtitle, textAlign: TextAlign.center, style: AppText.subtitle),
        ],
      ),
    );
  }
}
