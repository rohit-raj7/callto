 


import 'package:flutter/material.dart';
import 'language_selection_page.dart';
import '../../services/storage_service.dart';

class FemaleProfilePage extends StatefulWidget {
  const FemaleProfilePage({super.key});

  @override
  State<FemaleProfilePage> createState() => _FemaleProfilePageState();
}

class _FemaleProfilePageState extends State<FemaleProfilePage> {
  // Consistent palette for listener onboarding
  final Color primaryColor = const Color(0xFFFF4081);
  final Color backgroundLight1 = const Color(0xFFFFEBEE);
  final Color backgroundLight2 = const Color(0xFFFCE4EC);
  final Color textPrimary = const Color(0xFF880E4F);
  final Color textSecondary = const Color(0xFF757575);
  final Color cardBorder = const Color(0xFFF8BBD0);

  final TextEditingController originalNameController = TextEditingController();
  final TextEditingController dummyNameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  int? selectedAvatarIndex;

  final List<String> avatarImages = [
    'assets/images/female_profile/avatar1.jpg',
    'assets/images/female_profile/avatar2.jpg',
    'assets/images/female_profile/avatar3.jpg',
    'assets/images/female_profile/avatar4.jpg',
    'assets/images/female_profile/avatar5.jpg',
    'assets/images/female_profile/avatar6.jpg',
    'assets/images/female_profile/avatar7.jpg',
    'assets/images/female_profile/avatar8.jpg',
    'assets/images/female_profile/avatar9.jpg',
    'assets/images/female_profile/avatar10.jpg',
    'assets/images/female_profile/avatar11.jpg',
    'assets/images/female_profile/avatar12.jpg',
    'assets/images/female_profile/avatar13.jpg',
    'assets/images/female_profile/avatar14.jpg',
    'assets/images/female_profile/avatar15.jpg',
    'assets/images/female_profile/avatar16.jpg',
  ];

  Future<void> _submitProfile() async {
    if (originalNameController.text.isEmpty ||
        dummyNameController.text.isEmpty ||
        ageController.text.isEmpty ||
        cityController.text.isEmpty ||
        selectedAvatarIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields and select an avatar'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final age = int.tryParse(ageController.text.trim());
    if (age == null || age < 18 || age > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid age between 18 and 100'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final storageService = StorageService();
    final professionalName = dummyNameController.text.trim();
    final originalName = originalNameController.text.trim();
    final city = cityController.text.trim();
    final avatarUrl = avatarImages[selectedAvatarIndex!];

    // Save all data to localStorage first
    try {
      await storageService.saveListenerProfessionalName(professionalName);
      await storageService.saveListenerOriginalName(originalName);
      await storageService.saveListenerAge(age);
      await storageService.saveListenerCity(city);
      await storageService.saveListenerAvatarUrl(avatarUrl);
      await storageService.saveListenerSpecialties(['Confidence']);
      await storageService.saveListenerRatePerMinute(1.0);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  @override
  void dispose() {
    originalNameController.dispose();
    dummyNameController.dispose();
    ageController.dispose();
    cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;

    final bool isMobile = screenWidth < 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Complete Your Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textPrimary,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [backgroundLight1, backgroundLight2],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.03),

                /// Selected Avatar Preview
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: selectedAvatarIndex == null
                        ? Icon(Icons.person, size: 60, color: primaryColor)
                        : Image.asset(
                            avatarImages[selectedAvatarIndex!],
                            fit: BoxFit.cover,
                          ),
                  ),
                ),

                SizedBox(height: screenHeight * 0.04),

                /// Form Section
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white,
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.12),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Personal Details',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF880E4F),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This info stays private and helps build trust.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildTextField(
                        label: 'Original Name',
                        hint: 'Your real name (private)',
                        icon: Icons.person_outline,
                        controller: originalNameController,
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        label: 'Display Name (Not your real name)',
                        hint: 'How others will see you',
                        icon: Icons.badge_outlined,
                        controller: dummyNameController,
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        label: 'Age',
                        hint: 'Your age in years',
                        icon: Icons.calendar_today,
                        controller: ageController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 20),

                      _buildTextField(
                        label: 'City',
                        hint: 'Where you live',
                        icon: Icons.location_on_outlined,
                        controller: cityController,
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'Choose Your Avatar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF880E4F),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick one that represents you professionally.',
                        style: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// Avatar Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isMobile ? 3 : 4,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: avatarImages.length,
                        itemBuilder: (context, index) {
                          return _buildAvatarOption(
                            imageUrl: avatarImages[index],
                            isSelected: selectedAvatarIndex == index,
                            onTap: () =>
                                setState(() => selectedAvatarIndex = index),
                          );
                        },
                      ),

                      const SizedBox(height: 36),

                      /// Continue Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _submitProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: primaryColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.04),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Text Field Widget
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textSecondary),
            prefixIcon: Icon(icon, color: primaryColor),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: primaryColor, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// Avatar Widget
  Widget _buildAvatarOption({
    required String imageUrl,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? primaryColor : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(imageUrl, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
