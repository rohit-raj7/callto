import 'package:flutter/material.dart';
import '../../../services/user_service.dart';
import '../../../services/storage_service.dart';

class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() => _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  String? selectedLanguageCode;
  String? selectedLanguageName;

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

  Future<void> _continue() async {
    if (selectedLanguageCode == null || selectedLanguageName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a language')),
      );
      return;
    }

    final userService = UserService();
    final storageService = StorageService();
    final loading = SnackBar(
      content: Row(
        children: const [
          CircularProgressIndicator(),
          SizedBox(width: 12),
          Text('Saving language...'),
        ],
      ),
      duration: const Duration(seconds: 30),
    );

    ScaffoldMessenger.of(context).showSnackBar(loading);

    try {
      // Save to backend using language code
      final success = await userService.addLanguage(language: selectedLanguageCode!);
      
      // Save to localStorage using full language name for display
      await storageService.saveLanguage(selectedLanguageName!);
      
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Language saved successfully'),
            backgroundColor: Colors.green[700],
          ),
        );
        
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save language')),
        );
      }
    } catch (e) {
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
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select Language',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                    final isSelected = selectedLanguageCode == lang['code'];

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          selectedLanguageCode = lang['code'];
                          selectedLanguageName = lang['english'];
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
