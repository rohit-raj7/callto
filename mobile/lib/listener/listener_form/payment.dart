import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../services/listener_service.dart';
import '../../services/storage_service.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String _selectedOption = 'upi';
  final _formKey = GlobalKey<FormState>();

  // Consistent color palette
  final Color primaryColor = const Color(0xFFFF4081);
  final Color backgroundColor = const Color(0xFFFCE4EC);
  final Color textPrimary = const Color(0xFF880E4F);

  // Controllers for UPI form
  final TextEditingController _upiController = TextEditingController();
  final TextEditingController _upiMobileController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _panController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Controllers for Bank form
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _bankMobileController = TextEditingController();
  final TextEditingController _ifscController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _panAadhaarController = TextEditingController();

  @override
  void dispose() {
    _upiController.dispose();
    _upiMobileController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    _nameController.dispose();
    _accountController.dispose();
    _bankMobileController.dispose();
    _ifscController.dispose();
    _fullNameController.dispose();
    _panAadhaarController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final listenerService = ListenerService();
    final storageService = StorageService();

    // Prepare payment details
    Map<String, dynamic> paymentDetails = {'payment_method': _selectedOption};

    if (_selectedOption == 'upi') {
      paymentDetails['upi_id'] = _upiController.text.trim();
      paymentDetails['mobile_number'] = _upiMobileController.text.trim();
      paymentDetails['aadhaar_number'] = _aadhaarController.text.trim();
      paymentDetails['pan_number'] = _panController.text.trim();
      paymentDetails['name_as_per_pan'] = _nameController.text.trim();
    } else {
      paymentDetails['account_number'] = _accountController.text.trim();
      paymentDetails['mobile_number'] = _bankMobileController.text.trim();
      paymentDetails['ifsc_code'] = _ifscController.text.trim();
      paymentDetails['account_holder_name'] = _fullNameController.text.trim();
      paymentDetails['pan_aadhaar_bank'] = _panAadhaarController.text.trim();
    }

    final loading = SnackBar(
      content: Row(
        children: const [
          CircularProgressIndicator(),
          SizedBox(width: 12),
          Text('Submitting listener profile...'),
        ],
      ),
      duration: const Duration(seconds: 30),
    );

    ScaffoldMessenger.of(context).showSnackBar(loading);

    try {
      // Retrieve all listener form data from localStorage
      final formData = await storageService.getListenerFormData();

      final professionalName = (formData['professionalName'] as String? ?? '')
          .trim();

      // Safely parse specialties array
      final specialtiesRaw = formData['specialties'] as List<dynamic>? ?? [];
      final specialties = specialtiesRaw
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim())
          .toList();

      // Get single experience (now a string, not a list)
      final experience = (formData['experience'] as String? ?? '').trim();

      final languageRaw = (formData['language'] as String? ?? 'English').trim();
      final languages = [languageRaw];

      // Parse rate per minute - handle both string and numeric formats
      double ratePerMinute = 0.0;
      final rateValue = formData['ratePerMinute'];
      if (rateValue != null) {
        if (rateValue is String) {
          ratePerMinute = double.tryParse(rateValue) ?? 0.0;
        } else if (rateValue is num) {
          ratePerMinute = rateValue.toDouble();
        }
      }

      // Validate required fields
      if (professionalName.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Professional name is required. Please complete all steps.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (ratePerMinute <= 0) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rate per minute must be greater than 0.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (specialties.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one specialty.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (languages.isEmpty || languageRaw.isEmpty) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a language.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('=== Listener Profile Data ===');
      print('Professional Name: $professionalName');
      print('Specialties: $specialties');
      print('Experience: $experience');
      print('Languages: $languages');
      print('Rate: $ratePerMinute');

      // Get avatar URL
      final avatarUrl = (formData['avatarUrl'] as String? ?? '').trim();

      // Get age
      final age = formData['age'] as int?;

      // Get city
      final city = (formData['city'] as String? ?? '').trim();

      // Step 1: Create listener profile on backend
      print('=== Calling becomeListener ===');
      final createResult = await listenerService.becomeListener(
        professionalName: professionalName,
        specialties: specialties.isEmpty ? ['emotional_support'] : specialties,
        languages: languages,
        ratePerMinute: ratePerMinute,
        avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
        age: age,
        city: city.isNotEmpty ? city : null,
      );

      print(
        'Create Result: success=${createResult.success}, error=${createResult.error}',
      );
      print('Listener ID: ${createResult.listener?.listenerId}');

      if (!createResult.success || createResult.listener == null) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              createResult.error ?? 'Failed to create listener profile',
            ),
            backgroundColor: Colors.red[700],
          ),
        );
        return;
      }

      final listenerId = createResult.listener!.listenerId;

      // Step 1b: Save experience separately (if selected)
      if (experience.isNotEmpty) {
        final experienceResult = await listenerService.updateExperiences(
          listenerId,
          [experience],
        );
        if (experienceResult.success) {
          print('Experiences saved successfully');
        } else {
          print(
            'Warning: Failed to save experiences: ${experienceResult.error}',
          );
          // Show a snackbar to inform the user but don't fail the whole flow
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Note: Experience details couldn\'t be saved, but your profile was created successfully.',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }

      // Step 1c: Upload voice verification data via Cloudinary (if recorded)
      final voiceBase64 = await storageService.getListenerVoiceBase64();
      final voiceMimeType = await storageService.getListenerVoiceMimeType();
      if (voiceBase64 != null && voiceBase64.isNotEmpty) {
        // Decode base64 back to bytes for multipart upload
        final Uint8List voiceBytes = base64Decode(voiceBase64);
        final mime = voiceMimeType ?? 'audio/ogg';
        final ext = mime.contains('m4a') ? 'm4a' : (mime.contains('wav') ? 'wav' : 'ogg');
        final filename = 'voice_verification.$ext';

        // Step A: Upload to Cloudinary via backend
        final uploadResult = await listenerService.uploadVoiceFile(
          fileBytes: voiceBytes,
          filename: filename,
          mimeType: mime,
        );

        if (uploadResult.success && uploadResult.message != null) {
          final cloudinaryUrl = uploadResult.message!;
          print('Voice uploaded to Cloudinary: $cloudinaryUrl');

          // Step B: Save Cloudinary URL to listener record
          final voiceResult = await listenerService.updateVoiceVerification(
            listenerId: listenerId,
            voiceUrl: cloudinaryUrl,
          );
          if (voiceResult.success) {
            print('Voice verification saved successfully');
          } else {
            print('Warning: Failed to save voice URL: ${voiceResult.error}');
          }
        } else {
          print('Warning: Failed to upload voice to Cloudinary: ${uploadResult.error}');
        }
      }

      // Step 2: Add payment details
      print('=== Calling addPaymentDetails ===');
      print('Listener ID: $listenerId');
      print('Payment Details: $paymentDetails');
      final paymentResult = await listenerService.addPaymentDetails(
        listenerId,
        paymentDetails,
      );

      print(
        'Payment Result: success=${paymentResult.success}, error=${paymentResult.error}',
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (paymentResult.success) {
        // Step 3: Set listener flag and preserve avatar before clearing form data
        await storageService.saveIsListener(true);
        await storageService.saveListenerProfileComplete(true);

        // Preserve avatar URL before clearing (so TopBar can display it)
        final savedAvatarUrl = avatarUrl.isNotEmpty ? avatarUrl : null;
        await storageService.clearListenerFormData();

        // Re-save avatar URL after clearing form data
        if (savedAvatarUrl != null) {
          await storageService.saveListenerAvatarUrl(savedAvatarUrl);
        }

        // Show a professional success notification with all data saved message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All details saved successfully! Your listener profile is now active.',
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
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
          ),
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BottomNavBar()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              paymentResult.error ?? 'Failed to save payment details',
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Payment Details',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 48,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Final Step!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Add your payment details to receive earnings',
                      style: TextStyle(
                        fontSize: 14,
                        color: textPrimary.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Payment Method Selection Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Select Payment Method',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildPaymentOption(
                          title: 'UPI Payment',
                          subtitle: 'Receive payments via UPI ID',
                          icon: Icons.phone_android_rounded,
                          value: 'upi',
                        ),
                        const SizedBox(height: 8),
                        _buildPaymentOption(
                          title: 'Bank Account',
                          subtitle: 'Direct bank transfer',
                          icon: Icons.account_balance_rounded,
                          value: 'bank',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Form Fields
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedOption == 'upi') ...[
                          Text(
                            'UPI Payment Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _upiController,
                            label: 'UPI ID',
                            hint: 'example@upi',
                            icon: Icons.alternate_email_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter UPI ID';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _upiMobileController,
                            label: 'Mobile Number',
                            hint: 'Enter 10-digit mobile number',
                            icon: Icons.phone_android_rounded,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter mobile number';
                              }
                              if (value.length != 10) {
                                return 'Mobile number must be 10 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _aadhaarController,
                            label: 'Aadhaar Number',
                            hint: 'Enter 12-digit Aadhaar',
                            icon: Icons.badge_rounded,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter Aadhaar Number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _panController,
                            label: 'PAN Number (Optional)',
                            hint: 'ABCDE1234F',
                            icon: Icons.credit_card_rounded,
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _nameController,
                            label: 'Name as per PAN',
                            hint: 'Your full name',
                            icon: Icons.person_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your name as per PAN';
                              }
                              return null;
                            },
                          ),
                        ] else ...[
                          Text(
                            'Bank Account Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _accountController,
                            label: 'Account Number',
                            hint: 'Enter account number',
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter account number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _bankMobileController,
                            label: 'Mobile Number',
                            hint: 'Enter 10-digit mobile number',
                            icon: Icons.phone_android_rounded,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter mobile number';
                              }
                              if (value.length != 10) {
                                return 'Mobile number must be 10 digits';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _ifscController,
                            label: 'IFSC Code',
                            hint: 'e.g., SBIN0001234',
                            icon: Icons.code_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter IFSC Code';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _fullNameController,
                            label: 'Account Holder Name',
                            hint: 'Full name as per bank',
                            icon: Icons.person_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter account holder name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildFormField(
                            controller: _panAadhaarController,
                            label: 'PAN / Aadhaar',
                            hint: 'Enter PAN or Aadhaar',
                            icon: Icons.badge_rounded,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter PAN or Aadhaar';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        elevation: 4,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Submit & Complete',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
  }) {
    final bool isSelected = _selectedOption == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedOption = value),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.1)
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.grey[200],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isSelected ? textPrimary : Colors.grey[800],
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedOption,
              onChanged: (v) => setState(() => _selectedOption = v!),
              activeColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLength: maxLength,
      validator: validator,
      decoration: InputDecoration(
        counterText: maxLength != null ? '' : null,
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: primaryColor),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
