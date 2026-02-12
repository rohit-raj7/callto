import 'package:flutter/material.dart';
import 'profile/contact.dart';
import 'profile/my_transaction.dart';
import 'profile/wallet.dart'; 
import '../screens/recents_screen.dart';
import 'profile/setting.dart';
import 'profile/language.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';
import '../../ui/skeleton_loading_ui/profile_skeleton.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final StorageService _storageService = StorageService();
  final UserService _userService = UserService();
  String? displayName;
  String? city;
  String? avatarUrl;
  String? gender;
  String? language;
  String? dateOfBirth;
  String? mobileNumber;
  bool _isEditMode = false;
  double _walletBalance = 0.0;
  bool _isLoading = true;

  // Controllers for edit mode
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _dobController;
  late TextEditingController _mobileController;
  int? _selectedAvatarIndex;

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

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _nameController = TextEditingController();
    _cityController = TextEditingController();
    _dobController = TextEditingController();
    _mobileController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload data when returning to this page (important for language updates)
    _loadUserData();
  }

  Future<void> _refreshLanguage() async {
    // Reload language specifically
    final storedLanguage = await _storageService.getLanguage();
    setState(() {
      language = storedLanguage;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _dobController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final data = await _storageService.getUserFormData();
    final walletResult = await _userService.getWallet();
    if (!mounted) return;
    setState(() {
      displayName = data['displayName'] ?? 'User';
      city = data['city'] ?? 'Not specified';
      avatarUrl = data['avatarUrl'];
      gender = data['gender'];
      language = data['language'];
      dateOfBirth = data['dob'];
      mobileNumber = data['mobile'];
      _nameController.text = displayName ?? '';
      _cityController.text = city ?? '';
      _dobController.text = dateOfBirth ?? '';
      _mobileController.text = mobileNumber ?? '';
      if (walletResult.success) {
        _walletBalance = walletResult.balance;
      }
      if (avatarUrl != null) {
        _selectedAvatarIndex = avatarImages.indexOf(avatarUrl!);
        if (_selectedAvatarIndex == -1) _selectedAvatarIndex = null;
      }
      _isLoading = false;
    });
  }

  Future<void> _saveProfileChanges() async {
    if (_nameController.text.isEmpty ||
        _cityController.text.isEmpty ||
        _selectedAvatarIndex == null ||
        _dobController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newAvatarUrl = avatarImages[_selectedAvatarIndex!];
    final newDob = _dobController.text;
    final newMobile = _mobileController.text.trim();
    
    // Validate mobile number if provided (must be 10 digits)
    if (newMobile.isNotEmpty && newMobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      // Save to backend first
      final userService = UserService();
      final result = await userService.updateProfile(
        displayName: _nameController.text,
        city: _cityController.text,
        avatarUrl: newAvatarUrl,
        dateOfBirth: newDob,
      );

      if (result.success) {
        // Save to localStorage
        await _storageService.saveDisplayName(_nameController.text);
        await _storageService.saveCity(_cityController.text);
        await _storageService.saveAvatarUrl(newAvatarUrl);
        await _storageService.saveDob(newDob);
        if (newMobile.isNotEmpty) {
          await _storageService.saveMobile(newMobile);
        }
        setState(() {
          displayName = _nameController.text;
          city = _cityController.text;
          avatarUrl = newAvatarUrl;
          dateOfBirth = newDob;
          mobileNumber = newMobile.isNotEmpty ? newMobile : null;
          _isEditMode = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: Colors.green[700],
          ),
        );

        // Pop with updated user
        Navigator.pop(context, result.user);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to update profile'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4EC),
        elevation: 0,
        title: Text(
          _isEditMode ? "Edit Profile" : "My Profile",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isEditMode) {
              setState(() => _isEditMode = false);
              _loadUserData(); // Reload original data
            } else {
              Navigator.pop(context);
            }
          },
        ),

        // // 💰 Wallet Balance 
        actions: !_isEditMode
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Row(
                    children: [
                      // Stylish wallet balance badge
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.pinkAccent.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Text(
                          "₹${_walletBalance.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            fontSize: 14,
                          ),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // Settings button
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.settings,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            : [],
      ),

      body: _isLoading
          ? SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: const ProfileCardSkeleton(),
            )
          : _isEditMode
              ? _buildEditMode()
              : _buildViewMode(),
    );
  }

  Widget _buildViewMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Column(
        children: [
          // --- Profile Header ---
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6F9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC7D8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF5C8A).withOpacity(0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Side - Profile Icon
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFF5C8A), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5C8A).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                        ? AssetImage(avatarUrl!)
                        : const AssetImage('assets/images/male.jpg'),
                  ),
                ),

                const SizedBox(width: 16),

                // Right Side - Name and Buttons
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName ?? 'User',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${gender ?? 'Male'} • $city',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      // DOB display
                      if (dateOfBirth != null && dateOfBirth!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'DOB: $dateOfBirth',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      // Mobile display
                      if (mobileNumber != null && mobileNumber!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                mobileNumber!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        'Language: ${language ?? 'Not selected'}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Buttons Row - Side by Side
                      Row(
                        children: [
                          // Edit Profile Button
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                setState(() => _isEditMode = true);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFFF5C8A),
                                    width: 2,
                                  ),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.edit,
                                        color: Color(0xFFFF5C8A),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Edit",
                                        style: TextStyle(
                                          color: Color(0xFFFF5C8A),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Add Balance Button
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const WalletScreen(),
                                  ),
                                );
                                // Reload wallet balance when returning
                                _loadUserData();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF5C8A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Add Balance",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // --- Options List ---
          _buildListTile(
            Icons.history,
            "Recents",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecentsScreen()),
              );
            },
          ),
           _buildListTile(
            Icons.swap_horiz,
            "My Wallet",
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
              // Reload wallet balance when returning
              _loadUserData();
            },
          ),
          _buildListTile(
            Icons.swap_horiz,
            "My Transactions",
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransactionScreen()),
              );
              // Reload wallet balance when returning
              _loadUserData();
            },
          ),

          _buildListTile(
            Icons.language,
            "Change Language",
            trailing: Text(
              language ?? 'Not selected',
              style: const TextStyle(
                color: Colors.pinkAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const LanguageSelectionPage(),
                ),
              );
              // Refresh language after returning
              await _refreshLanguage();
            },
          ),

          _buildListTile(
            Icons.mail_outline,
            "Contact Us",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ContactUsPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        children: [
          // Avatar Selection
          const Text(
            "Select Avatar",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: avatarImages.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedAvatarIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedAvatarIndex = index);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? Colors.pinkAccent
                              : Colors.grey.shade300,
                          width: isSelected ? 4 : 2,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.pinkAccent.withOpacity(0.4),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: AssetImage(avatarImages[index]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Name Field
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Display Name',
              hintText: 'Enter your name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.person),
            ),
          ),

          const SizedBox(height: 16),

          // City Field
          TextField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: 'City',
              hintText: 'Enter your city',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),

          const SizedBox(height: 16),

          // Gender Display (Read-only)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.wc, color: Colors.grey),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gender',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      gender ?? 'Not specified',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Mobile Number Field (Optional)
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            decoration: InputDecoration(
              labelText: 'Mobile Number (Optional)',
              hintText: 'Enter your 10-digit mobile number',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.phone_android),
              prefixText: '+91 ',
              prefixStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // DOB Field
          TextField(
            controller: _dobController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Date of Birth',
              hintText: 'Select your date of birth',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.cake),
            ),
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: dateOfBirth != null && dateOfBirth!.isNotEmpty
                    ? DateTime.tryParse(dateOfBirth!) ?? DateTime(2000, 1, 1)
                    : DateTime(2000, 1, 1),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                _dobController.text = picked.toIso8601String().split('T')[0];
              }
            },
          ),
          const SizedBox(height: 16),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveProfileChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Method ---
  Widget _buildListTile(
    IconData icon,
    String title, {
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFE4EC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.pinkAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing:
            trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
