import 'package:flutter/material.dart';
import 'voice_selection_page.dart';
import '../../services/storage_service.dart';

class ExperiencedPage extends StatefulWidget {
  final String? selectedLanguage;
  const ExperiencedPage({super.key, this.selectedLanguage});

  @override
  State<ExperiencedPage> createState() => _ExperiencedPageState();
}

class _ExperiencedPageState extends State<ExperiencedPage> {
  // Consistent Color Palette (matching other screens)
  final Color primaryColor = const Color(0xFFFF4081); // Pink (primary accent)
  final Color primaryLight = const Color(0xFFFCE4EC); // Light pink
  final Color backgroundColor = const Color(0xFFFCE4EC); // Light pink background
  final Color surfaceColor = Colors.white;
  final Color textPrimary = const Color(0xFF880E4F); // Pink-800 for dark text
  final Color textSecondary = const Color(0xFF757575); // Grey-600
  final Color borderColor = const Color(0xFFF8BBD0); // Pink-100

  final List<Map<String, String>> experiences = [
  {'title': 'Confidence', 'emoji': '🌟'},
  {'title': 'Marriage', 'emoji': '🤝'},
  {'title': 'Breakup', 'emoji': '🥀'},
  {'title': 'Single', 'emoji': '🌱'},
  {'title': 'Relationship', 'emoji': '💞'},
];


  final Set<int> selectedExperiences = {};
  int? selectedExperience; // Single selection instead of multiple

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceSelectionPage(selectedLanguage: widget.selectedLanguage),
      ),
    );
  }

  Future<void> _continue() async {
    final storageService = StorageService();
    
    // Save single experience to localStorage (or empty string if skipped)
    final experience = selectedExperience != null 
        ? experiences[selectedExperience!]['title']! 
        : '';

    try {
      // Save experience to localStorage silently
      await storageService.saveListenerExperience(experience);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VoiceSelectionPage(selectedLanguage: widget.selectedLanguage),
        ),
      );
    } catch (e) {
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Your Experiences',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Main Heading
              Text(
                'What have you been going through lately?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Select one that applies • You can skip if you prefer',
                style: TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Experiences List
              Expanded(
                child: ListView.builder(
                  itemCount: experiences.length,
                  itemBuilder: (context, index) {
                    final bool isSelected = selectedExperience == index;
                    final item = experiences[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedExperience = null; // Deselect if tapping same item
                            } else {
                              selectedExperience = index; // Select only this one
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          height: 72,
                          decoration: BoxDecoration(
                            color: isSelected ? primaryColor : surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? primaryColor : borderColor,
                              width: isSelected ? 0 : 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                // Emoji
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.2)
                                        : primaryLight,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      item['emoji']!,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Title
                                Expanded(
                                  child: Text(
                                    item['title']!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : textPrimary,
                                    ),
                                  ),
                                ),
                                // Radio button
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.white : borderColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Center(
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: primaryColor.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    selectedExperience == null ? 'Skip & Continue' : 'Continue',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              // Optional Skip Text Button (if needed)
              if (selectedExperience != null)
                TextButton(
                  onPressed: _skip,
                  child: Text(
                    'Skip instead',
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}