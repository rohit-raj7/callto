import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../terms_condition/terms_of_use.dart';
import '../terms_condition/privacy_policy.dart';
import '../gender/gender_selection.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../models/user_model.dart';
import '../user/widgets/bottom_nav_bar.dart' as user_bottom_nav_bar;
import '../listener/widgets/bottom_nav_bar.dart' as listener_bottom_nav_bar;
import '../user/user_form/intro_screen.dart';
import '../listener/listener_form/intro_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State createState() => _LoginScreenState();
}

class _LoginScreenState extends State with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  GoogleSignIn? _googleSignIn;
  bool _isLoading = false;
  bool _agreedToTerms = true;
  bool _googleSignInAvailable = false;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List leftImages = [
    'assets/login/img1.jpg',
    'assets/login/img2.jpg',
    'assets/login/img3.jpg',
    'assets/login/img4.jpg',
    'assets/login/img6.jpg',
    'assets/login/img7.jpg',
    'assets/login/img8.jpg',
  ];

  final List rightImages = [
    'assets/login/img9.jpg',
    'assets/login/img10.jpg',
    'assets/login/img11.jpg',
    'assets/login/img12.jpg',
    'assets/login/img13.jpg',
    'assets/login/img14.jpg',
    'assets/login/img15.jpg',
  ];

  late final ScrollController leftScrollController;
  late final ScrollController rightScrollController;

  @override
  void initState() {
    super.initState();
    leftScrollController = ScrollController();
    rightScrollController = ScrollController();

    // Initialize animations
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    // Initialize Google Sign-In
    _initializeGoogleSignIn();

    // Start animations and autoscroll after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
        _autoScroll(leftScrollController, down: true);
        _autoScroll(rightScrollController, down: true);
      }
    });
  }

  void _initializeGoogleSignIn() {
    try {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      _googleSignInAvailable = true;
    } catch (e) {
      print('Google Sign-In initialization failed: $e');
      _googleSignInAvailable = false;
    }
  }

  void _autoScroll(ScrollController controller, {required bool down}) async {
    const double scrollSpeed = 0.8 * 3.5;
    const Duration delay = Duration(milliseconds: 40);

    while (mounted) {
      await Future.delayed(delay);

      if (!controller.hasClients || !controller.position.hasContentDimensions) {
        continue;
      }

      double offset = controller.offset + (down ? scrollSpeed : -scrollSpeed);

      if (offset >= controller.position.maxScrollExtent) {
        offset = controller.position.minScrollExtent;
      } else if (offset <= controller.position.minScrollExtent) {
        offset = controller.position.maxScrollExtent;
      }

      controller.jumpTo(offset);
    }
  }

  @override
  void dispose() {
    leftScrollController.dispose();
    rightScrollController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showLoading(bool show) {
    if (!mounted) return;
    setState(() {
      _isLoading = show;
    });
  }

  Future _handleGoogleLogin() async {
    if (!_agreedToTerms) {
      _showError('Please agree to Terms of Use and Privacy Policy');
      return;
    }

    if (kIsWeb && (!_googleSignInAvailable || _googleSignIn == null)) {
      _showError(
        'Google Sign-In is not configured for web.\n'
        'Please use the mobile app or configure Google OAuth for web.',
      );
      return;
    }

    if (_googleSignIn == null) {
      _initializeGoogleSignIn();
    }

    _showLoading(true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        _showLoading(false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      final String? token = idToken ?? accessToken;

      if (token == null) {
        _showError('Failed to get Google authentication token');
        _showLoading(false);
        return;
      }

      final result = await _authService.socialLogin(
        provider: 'google',
        token: token,
      );

      _showLoading(false);

      if (result.success) {
        await _postLoginNavigation(result);
      } else {
        _showError(result.error ?? 'Google login failed');
      }
    } catch (e) {
      _showLoading(false);
      _showError('Google login failed: $e');
    }
  }

  void _navigateToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GenderSelectionPage()),
    );
  }

  Future _postLoginNavigation(AuthResult result) async {
    if (result.isNewUser) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GenderSelectionPage()),
      );
      return;
    }

    // For existing users, try refreshing from backend first
    User? userForRouting = result.user;
    try {
      final refreshed = await _authService.refreshUserData();
      if (refreshed != null) {
        userForRouting = refreshed;
      }
    } catch (e) {
      // If refresh fails, use the user data from login response
      print('Failed to refresh user data after login: $e');
    }
    await _routeByProfileState(userForRouting);
  }

  Future<void> _routeByProfileState(User? user) async {
    final accountType = user?.accountType;
    final gender = await _storageService.getGender();
    final listenerComplete = await _storageService.getListenerProfileComplete();
    final userComplete = await _storageService.getUserProfileComplete();

    // Check backend user object directly for completed profile
    final backendProfileComplete = user != null && user.hasCompleteProfile;

    if (listenerComplete || accountType == 'listener') {
      await _storageService.saveIsListener(true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const listener_bottom_nav_bar.BottomNavBar()),
      );
      return;
    }

    if (userComplete || backendProfileComplete) {
      await _storageService.saveIsListener(false);
      await _storageService.saveUserProfileComplete(true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const user_bottom_nav_bar.BottomNavBar()),
      );
      return;
    }

    // Use backend gender if local is missing
    final effectiveGender = gender ?? user?.gender;

    if (effectiveGender == 'Female') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BecomeHostOnboarding()),
      );
      return;
    }

    if (effectiveGender == 'Male') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GenderSelectionPage()),
    );
  }

  void _navigateToTerms() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
    );
  }

  void _navigateToPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isTablet = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // Background image carousel
          Row(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: leftScrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: leftImages.length * 3,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height: screenHeight,
                      child: _buildImageAsset(
                        leftImages[index % leftImages.length],
                        screenHeight,
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: rightScrollController,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rightImages.length * 3,
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height: screenHeight,
                      child: _buildImageAsset(
                        rightImages[index % rightImages.length],
                        screenHeight,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.8),
                ],
              ),
            ),
          ),

          // Main content
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? screenWidth * 0.2 : screenWidth * 0.05,
                vertical: screenHeight * 0.02,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header section
                      _buildHeaderSection(screenHeight, screenWidth),

                      SizedBox(height: screenHeight * 0.03),

                      // Stats section
                      _buildStatsSection(screenHeight),

                      SizedBox(height: screenHeight * 0.04),

                      // Login card
                      _buildLoginCard(screenHeight, screenWidth, isTablet),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(double screenHeight, double screenWidth) {
    final double baseLogoSize = screenHeight * 0.12;
    final double maxByWidth = screenWidth * 0.35;
    final double cappedLogoSize =
        baseLogoSize.clamp(80.0, 160.0).toDouble();
    final double logoSize =
        cappedLogoSize <= maxByWidth ? cappedLogoSize : maxByWidth;

    return Column(
      children: [
        // Logo only
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D9FF).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: _buildImageAsset(
            'assets/login/homelogo.png',
            logoSize,
            isLogo: true,
          ),
        ),

        SizedBox(height: screenHeight * 0.015),

        // Subtitle
        Text(
          'Connect with Friends Near You',
          style: TextStyle(
            fontSize: screenHeight * 0.015,
            color: Colors.white70,
            fontWeight: FontWeight.w300,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(double screenHeight) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenHeight * 0.03,
        vertical: screenHeight * 0.018,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF00D9FF).withOpacity(0.2),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '71,445',
            style: TextStyle(
              fontSize: screenHeight * 0.035,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF00D9FF),
            ),
          ),
          SizedBox(height: screenHeight * 0.006),
          Text(
            'Active Users Making Friends',
            style: TextStyle(
              fontSize: screenHeight * 0.014,
              color: Colors.white60,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(double screenHeight, double screenWidth, bool isTablet) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenHeight * 0.03,
        vertical: screenHeight * 0.035,
      ),
      
      child: Column(
        children: [
          // Section title
          Text(
            'Get Started',
            style: TextStyle(
              fontSize: screenHeight * 0.024,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),

          
          SizedBox(height: screenHeight * 0.028),

          // Google login button
          _buildGoogleLoginButton(screenHeight),

          SizedBox(height: screenHeight * 0.02),

          // Divider
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
              
            ],
          ),

          SizedBox(height: screenHeight * 0.02),

          SizedBox(height: screenHeight * 0.03),

          // Terms section
          _buildTermsSection(screenHeight),
        ],
      ),
    );
  }

   Widget _buildGoogleLoginButton(double screenHeight) {
  final double buttonHeight = screenHeight * 0.055;

  return GestureDetector(
    onTap: _isLoading ? null : _handleGoogleLogin,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      height: buttonHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.black.withOpacity(0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            SizedBox(
              width: buttonHeight * 0.4,
              height: buttonHeight * 0.4,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
              ),
            )
          else ...[
            // Google logo
            Image.asset(
              'assets/login/google_logo.png',
              height: buttonHeight * 0.45,
            ),

            const SizedBox(width: 12),

            Text(
              'Continue with Google',
              style: TextStyle(
                color: Colors.black87,
                fontSize: screenHeight * 0.015,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

  Widget _buildTermsSection(double screenHeight) {
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: screenHeight * 0.035,
              height: screenHeight * 0.035,
              child: Checkbox(
                value: _agreedToTerms,
                onChanged: (value) {
                  setState(() {
                    _agreedToTerms = value ?? false;
                  });
                },
                checkColor: Colors.black,
                activeColor: const Color(0xFF00D9FF),
                side: BorderSide(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            SizedBox(width: screenHeight * 0.015),
            Expanded(
              child: Wrap(
                spacing: 4,
                children: [
                  Text(
                    'I agree to the ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: screenHeight * 0.014,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  _buildTextButton(
                    'Terms of Use',
                    _navigateToTerms,
                    screenHeight,
                  ),
                  Text(
                    ' and ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: screenHeight * 0.014,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  _buildTextButton(
                    'Privacy Policy',
                    _navigateToPrivacyPolicy,
                    screenHeight,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextButton(
    String text,
    VoidCallback onPressed,
    double screenHeight,
  ) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: const Color(0xFF00D9FF),
          fontSize: screenHeight * 0.014,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFF00D9FF).withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildImageAsset(String path, double height, {bool isLogo = false}) {
    // Ensure height is positive and cacheHeight is at least 1
    final safeHeight = height > 0 ? height : 1.0;
    final cacheHeight = (safeHeight * MediaQuery.of(context).devicePixelRatio).round();
    final safeCacheHeight = cacheHeight > 0 ? cacheHeight : 1;
    
    return Image.asset(
      path,
      height: safeHeight,
      fit: isLogo ? BoxFit.contain : BoxFit.cover,
      cacheHeight: safeCacheHeight,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          height: safeHeight,
          color: isLogo ? Colors.transparent : Colors.grey.shade900,
          child: Center(
            child: Icon(
              isLogo ? Icons.image_not_supported : Icons.hide_image_outlined,
              color: Colors.white30,
              size: isLogo ? safeHeight * 0.8 : 50,
            ),
          ),
        );
      },
    );
  }
}