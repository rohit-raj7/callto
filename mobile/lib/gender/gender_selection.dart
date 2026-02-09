

import 'package:flutter/material.dart';
import '../user/user_form/intro_screen.dart';
import '../listener/listener_form/intro_screen.dart';
import '../services/storage_service.dart';

class GenderSelectionPage extends StatefulWidget {
  const GenderSelectionPage({super.key});

  @override
  State<GenderSelectionPage> createState() => _GenderSelectionPageState();
}

class _GenderSelectionPageState extends State<GenderSelectionPage> {
  String? selectedGender;

  void _selectGender(String gender) {
    setState(() {
      selectedGender = gender;
    });
  }

  Future<void> _continue() async {
    if (selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: Color.from(
            alpha: 1,
            red: 0.957,
            green: 0.263,
            blue: 0.212,
          ),
        ),
      );
      return;
    }

    // Save gender locally for resume routing (no backend save here)
    final storageService = StorageService();
    await storageService.saveGender(selectedGender!);
    await storageService.saveUserProfileComplete(false);
    await storageService.saveListenerProfileComplete(false);
    await storageService.saveIsListener(false);

    if (!mounted) return;
    if (selectedGender == 'Male') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => BecomeHostOnboarding()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              Text(
                'Select Your Gender',
                style: TextStyle(
                  fontSize: screenHeight * 0.035,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink[800],
                ),
              ),
              SizedBox(height: screenHeight * 0.01),
              Text(
                'Choose your gender to continue',
                style: TextStyle(
                  fontSize: screenHeight * 0.02,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: screenHeight * 0.06),

              // Gender Selection Cards - Circular Layout
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCircularGenderButton(
                    context: context,
                    gender: 'Male',
                    icon: Icons.male,
                    color: Colors.blue,
                    isSelected: selectedGender == 'Male',
                    screenHeight: screenHeight,
                    screenWidth: screenWidth,
                    imagePath: 'assets/images/male.jpg',
                  ),
                  _buildCircularGenderButton(
                    context: context,
                    gender: 'Female',
                    icon: Icons.female,
                    color: Colors.pink,
                    isSelected: selectedGender == 'Female',
                    screenHeight: screenHeight,
                    screenWidth: screenWidth,
                    imagePath: 'assets/images/female.jpg',
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.06),

              // Continue Button
              SizedBox(
                width: screenWidth * 0.7,
                height: screenHeight * 0.065,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: screenHeight * 0.022,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircularGenderButton({
    required BuildContext context,
    required String gender,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required double screenHeight,
    required double screenWidth,
    String? imagePath,
  }) {
    double circleSize = screenHeight * 0.15;

    return GestureDetector(
      onTap: () => _selectGender(gender),
      child: Column(
        children: [
          // Circular Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? color.withValues(alpha: 0.4)
                      : Colors.grey.withValues(alpha: 0.2),
                  spreadRadius: isSelected ? 4 : 2,
                  blurRadius: isSelected ? 12 : 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: imagePath != null && imagePath.isNotEmpty
                  ? ClipOval(
                      child: Image.asset(
                        imagePath,
                        height: circleSize * 0.85,
                        width: circleSize * 0.85,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            icon,
                            size: circleSize * 0.5,
                            color: color,
                          );
                        },
                      ),
                    )
                  : Icon(icon, size: circleSize * 0.5, color: color),
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          // Gender Label
          Text(
            gender,
            style: TextStyle(
              fontSize: screenHeight * 0.025,
              fontWeight: FontWeight.bold,
              color: isSelected ? color : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
 