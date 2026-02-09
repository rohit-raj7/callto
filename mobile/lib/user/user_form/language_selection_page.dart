import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../services/user_service.dart';
import '../../services/storage_service.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String? selectedLanguage;
  bool _isLoading = false;

  // Use singleton instances for better performance
  final UserService _userService = UserService();
  final StorageService _storageService = StorageService();

  final Color primaryPink = const Color(0xFFFF4081);
  final Color backgroundColor = const Color(0xFFFCE4EC);
  final Color textPrimary = const Color(0xFF880E4F);

  final List<Map<String, String>> languages = [
    {'code': 'hi', 'english': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'te', 'english': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'bn', 'english': 'Bangla', 'native': 'বাংলা'},
    {'code': 'ta', 'english': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'kn', 'english': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'ml', 'english': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'pa', 'english': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'or', 'english': 'Odia', 'native': 'ଓଡ଼ିଆ'},
    {'code': 'gu', 'english': 'Gujarati', 'native': 'ગુજરાતી'},
  ];

  void _continue() {
    if (selectedLanguage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a language')),
      );
      return;
    }

    // Prevent double-tap
    if (_isLoading) return;

    // Call backend to save language preference
    _saveLanguageAndContinue();
  }

  Future<void> _saveLanguageAndContinue() async {
    setState(() => _isLoading = true);

    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Saving profile...'),
          ],
        ),
        duration: const Duration(seconds: 30),
        backgroundColor: primaryPink,
      ),
    );

    try {
      // Get form data from localStorage (fast local operation)
      final formData = await _storageService.getUserFormData();

      // Run both API calls in parallel for faster saving
      final results = await Future.wait([
        _userService.updateProfile(
          gender: formData['gender'],
          displayName: formData['displayName'],
          city: formData['city'],
          avatarUrl: formData['avatarUrl'],
        ),
        _userService.addLanguage(language: selectedLanguage!),
        // Save language to localStorage in parallel
        _storageService.saveLanguage(selectedLanguage!),
      ]);

      final profileResult = results[0] as UserResult;

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (profileResult.success) {
        await _storageService.saveUserProfileComplete(true);
        await _storageService.saveIsListener(false);
        // Show professional success notification
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Profile completed successfully!',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const BottomNavBar()),
        );
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(profileResult.error ?? 'Failed to save profile')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            /// Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(color: textPrimary),
                  children: const [
                    TextSpan(
                      text: 'Select your\n',
                      style: TextStyle(fontSize: 18),
                    ),
                    TextSpan(
                      text: 'Primary Language',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),

            /// Subtitle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '*You cannot change this once you go ahead',
                style: TextStyle(
                  fontSize: 13,
                  color: primaryPink,
                ),
              ),
            ),

            const SizedBox(height: 24),

            /// Language Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  itemCount: languages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 2.8,
                  ),
                  itemBuilder: (context, index) {
                    final lang = languages[index];
                    final isSelected = selectedLanguage == lang['code'];

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          selectedLanguage = lang['code'];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? primaryPink : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: primaryPink,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color:
                                  isSelected ? Colors.white : primaryPink,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['english']!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : primaryPink,
                                  ),
                                ),
                                Text(
                                  lang['native']!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isSelected
                                        ? Colors.white70
                                        : primaryPink.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            /// Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryPink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Set Language',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
