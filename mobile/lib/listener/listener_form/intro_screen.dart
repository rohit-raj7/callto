import 'package:flutter/material.dart';
import 'female_profile.dart';

class BecomeHostOnboarding extends StatefulWidget {
  const BecomeHostOnboarding({super.key});

  @override
  State<BecomeHostOnboarding> createState() => _BecomeHostOnboardingState();
}

class _BecomeHostOnboardingState extends State<BecomeHostOnboarding> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Shared color scheme aligned with other screens
  final Color primaryColor = const Color(0xFFFF4081); // Pink accent
  final Color backgroundLight1 = const Color(0xFFFFEBEE); // Very light pink
  final Color backgroundLight2 = const Color(0xFFFCE4EC); // Light pink
  final Color textPrimary = const Color(0xFF880E4F); // Deep pink text

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const FemaleProfilePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundLight1, backgroundLight2],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),

              /// TOP TITLE
              Text(
                "Become a Host",
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              /// VOICE VERIFICATION CHIP
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, size: 16, color: primaryColor),
                    const SizedBox(width: 6),
                    Text(
                      "make money using Voice",
                      style: TextStyle(color: textPrimary, fontSize: 13),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              /// IMAGE SLIDER
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _imageCard('assets/images/girl1.jpg'),
                    _imageCard('assets/images/girl2.jpg'),
                    _imageCard('assets/images/girl1.jpg'),
                  ],
                ),
              ),

              /// TEXT SECTION
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "Answer calls and earn upto",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "₹10,000 every week!",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// PAGE INDICATOR
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? primaryColor
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
              ),

              SizedBox(height: h * 0.05),

              /// CONTINUE BUTTON
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: 56,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 10,
                    ),
                    child: Text(
                      _currentPage == 2 ? "Get Started" : "Continue",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// IMAGE CARD LIKE SCREENSHOT
  Widget _imageCard(String assetPath) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.25),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(assetPath, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
