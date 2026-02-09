import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/delete_request_service.dart';
import '../services/storage_service.dart';
import '../user/nav/profile.dart' as user_profile;
import '../listener/nav/profile.dart' as listener_profile;

class DeleteRequestFormPage extends StatelessWidget {
  const DeleteRequestFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Delete Request Form"),
        backgroundColor: const Color(0xFFFFE4EC),
      ),
      body: const SafeArea(
        child: DeleteRequestForm(),
      ),
    );
  }
}

class DeleteRequestForm extends StatefulWidget {
  const DeleteRequestForm({super.key});

  @override
  State<DeleteRequestForm> createState() => _DeleteRequestFormState();
}

class _DeleteRequestFormState extends State<DeleteRequestForm> {
  // Form and controllers
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _reasonController = TextEditingController();
  final DeleteRequestService _service = DeleteRequestService();
  final StorageService _storage = StorageService();

  // State flags
  bool _isSubmitting = false;
  String _role = 'user';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _reasonController.addListener(_onReasonChanged);
    _prefillUserData();
  }

  @override
  void dispose() {
    _reasonController.removeListener(_onReasonChanged);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _onReasonChanged() {
    setState(() {});
  }

  // Load user profile details and auto-fill fields
  Future<void> _prefillUserData() async {
    User? user = AuthService().currentUser;
    if (user == null) {
      final raw = await _storage.getUserData();
      if (raw != null && raw.isNotEmpty) {
        try {
          user = User.fromJson(jsonDecode(raw));
        } catch (_) {}
      }
    }

    final storedUserId = await _storage.getUserId();
    final storedEmail = await _storage.getEmail();
    final storedPhone = await _storage.getMobile();
    final isListenerStored = await _storage.getIsListener();

    if (!mounted) return;

    setState(() {
      final fullName = user?.fullName?.trim();
      final displayName = user?.displayName?.trim();
      if ((fullName ?? '').isNotEmpty) {
        _nameController.text = fullName!;
      } else if ((displayName ?? '').isNotEmpty) {
        _nameController.text = displayName!;
      }

      final email = user?.email ?? storedEmail;
      if (email != null && email.isNotEmpty) {
        _emailController.text = email;
      }

      final phone = user?.phoneNumber ?? storedPhone;
      if (phone != null && phone.isNotEmpty) {
        _phoneController.text = phone;
      }

      _userId = user?.userId ?? storedUserId ?? '';
      _role = user?.accountType == 'listener' || isListenerStored ? 'listener' : 'user';
    });
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final requiredCheck = _validateRequired(value, 'Email');
    if (requiredCheck != null) return requiredCheck;
    final email = value!.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final requiredCheck = _validateRequired(value, 'Phone number');
    if (requiredCheck != null) return requiredCheck;
    final sanitized = value!.replaceAll(RegExp(r'\s+'), '');
    final phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');
    if (!phoneRegex.hasMatch(sanitized)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  void _navigateToProfile() {
    if (_role == 'listener') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const listener_profile.ProfilePage()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const user_profile.ProfilePage()),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      return;
    }
    if (_userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to identify account. Please log in again.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await _service.submitDeleteRequest(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      reason: _reasonController.text.trim(),
      role: _role,
      userId: _userId,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Delete request submitted successfully.')),
      );
      _navigateToProfile();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Failed to submit delete request')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE57373)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFD32F2F)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Deleting your account is permanent. All data, history, and access will be removed and cannot be restored.",
                          style: TextStyle(
                            color: Color(0xFFB71C1C),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _validateRequired(value, 'Full name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'user', child: Text('User')),
                    DropdownMenuItem(value: 'listener', child: Text('Listener')),
                  ],
                  onChanged: null,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: 5,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Reason for account deletion',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  buildCounter: (context,
                          {required int currentLength,
                          required bool isFocused,
                          required int? maxLength}) =>
                      Text('$currentLength/${maxLength ?? 0}'),
                  validator: (value) =>
                      _validateRequired(value, 'Reason for account deletion'),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Submit Request'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
