import 'package:flutter/material.dart';
import 'language_selection_page.dart';
import '../../services/storage_service.dart';

class FemaleProfilePage extends StatefulWidget {
  const FemaleProfilePage({super.key});

  @override
  State<FemaleProfilePage> createState() => _FemaleProfilePageState();
}

class _FemaleProfilePageState extends State<FemaleProfilePage> {
  final TextEditingController dummyNameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  int? selectedAvatarIndex;

  final List<String> avatarImages = [
    'assets/images/male_profile/avatar1.jpg',
    'assets/images/male_profile/avatar2.jpg',
    'assets/images/male_profile/avatar3.jpg',
    'assets/images/male_profile/avatar4.jpg',
    'assets/images/male_profile/avatar5.jpg',
    'assets/images/male_profile/avatar6.jpg',
    'assets/images/male_profile/avatar7.jpg',
    'assets/images/male_profile/avatar8.jpg',
    'assets/images/male_profile/avatar9.jpg',
    'assets/images/male_profile/avatar10.jpg',
    'assets/images/male_profile/avatar11.jpg',
    'assets/images/male_profile/avatar12.jpg',
    'assets/images/male_profile/avatar13.jpg',
    'assets/images/male_profile/avatar14.jpg',
    'assets/images/male_profile/avatar15.jpg',
    'assets/images/male_profile/avatar16.jpg',
    'assets/images/male_profile/avatar17.jpg',
    'assets/images/male_profile/avatar18.jpg',
  ];

  Future<void> _submitProfile() async {
    if (dummyNameController.text.isEmpty ||
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

    final storageService = StorageService();
    final displayName = dummyNameController.text.trim();
    final city = cityController.text.trim();
    final avatarUrl = avatarImages[selectedAvatarIndex!];

    // Save to local storage silently (notification shown at final submission)
    await storageService.saveDisplayName(displayName);
    await storageService.saveCity(city);
    await storageService.saveAvatarUrl(avatarUrl);

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LanguageSelectionPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFF4081),
              Color(0xFFFCE4EC),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.06),
            child: Column(
              children: [
                const SizedBox(height: 24),

                /// 🔥 Avatar Preview (Large)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: selectedAvatarIndex == null
                        ? const Icon(Icons.person,
                            size: 70, color: Colors.white)
                        : Image.asset(
                            avatarImages[selectedAvatarIndex!],
                            fit: BoxFit.cover,
                          ),
                  ),
                ),

                const SizedBox(height: 36),

                /// Form Section
                Container(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile Details',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildTextField(
                        label: 'Display Name',
                        hint: 'Your public name',
                        icon: Icons.badge_outlined,
                        controller: dummyNameController,
                      ),

                      const SizedBox(height: 20),

                      _buildTextField(
                        label: 'City',
                        hint: 'Your location',
                        icon: Icons.location_on_outlined,
                        controller: cityController,
                      ),

                      const SizedBox(height: 32),

                      const Text(
                        'Choose Avatar',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// ✅ ONE LINE – 3 AVATARS – BIG SIZE
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: avatarImages.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 20),
                          itemBuilder: (context, index) {
                            return SizedBox(
                              width: 100,
                              child: _buildAvatarOption(
                                avatarImages[index],
                                selectedAvatarIndex == index,
                                () => setState(
                                    () => selectedAvatarIndex = index),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 36),

                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4081),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          onPressed: _submitProfile,
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Text Field
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFFFF4081)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  /// 🔹 Avatar Option (Bigger + Animated)
  Widget _buildAvatarOption(
      String imageUrl, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.2 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  isSelected ? const Color(0xFFFF4081) : Colors.transparent,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              imageUrl,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
