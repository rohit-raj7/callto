import 'package:flutter/material.dart';
import 'profile/contact.dart';
import 'profile/transacions.dart';
import 'profile/payment_methods.dart';
import '../screens/recents_screen.dart';
import 'profile/setting.dart';
import '../../services/listener_service.dart';
import '../../services/storage_service.dart';
import '../../services/call_service.dart';
import '../../models/listener_model.dart' as models;
import '../../ui/skeleton_loading_ui/profile_skeleton.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<void> _loadListenerFuture;
  models.Listener? _listener;
  String? _gender;
  double _totalEarnings = 0.0;
  final StorageService _storageService = StorageService();
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    _loadListenerFuture = _loadListenerData();
  }

  Future<void> _loadListenerData() async {
    try {
      final listenerService = ListenerService();
      final gender = await _storageService.getGender();

      // First try to fetch from backend (source of truth)
      final result = await listenerService.getMyProfile();

      // Load earnings data
      await _loadEarningsData();

      if (result.success && result.listener != null) {
        if (mounted) {
          setState(() {
            _listener = result.listener;
            _gender = gender;
          });
        }
      } else {
        // Backend failed, fall back to local storage
        final stored = await _storageService.getListenerFormData();
        if (mounted) {
          setState(() {
            _listener = models.Listener(
              listenerId: '',
              userId: '',
              professionalName: stored['professionalName'] as String?,
              specialties: (stored['specialties'] is List)
                  ? List<String>.from(stored['specialties'])
                  : <String>[],
              languages: (() {
                final raw = stored['languages'];
                if (raw is List) return List<String>.from(raw);
                if (raw is String && raw.isNotEmpty) {
                  return raw
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                }
                return <String>[];
              })(),
              ratePerMinute: (stored['ratePerMinute'] is double)
                  ? stored['ratePerMinute'] as double
                  : (stored['ratePerMinute'] is int
                        ? (stored['ratePerMinute'] as int).toDouble()
                        : 0.0),
              experienceYears: stored['experience'] is int
                  ? stored['experience'] as int
                  : null,
              avatarUrl: stored['avatarUrl'] as String?,
              city: stored['city'] as String?,
              rating: 0.0,
              totalCalls: 0,
            );
            _gender = gender;
          });
        }
      }
    } catch (e) {
      // swallow errors silently
    }
  }

  /// Load earnings data to display total earnings
  Future<void> _loadEarningsData() async {
    try {
      final result = await _callService.getListenerCallHistory(
        limit: 500,
        offset: 0,
      );

      if (result.success) {
        // Use backend-calculated listenerEarn (actual payout)
        double totalEarnings = 0;
        for (final call in result.calls) {
          if (call.status == 'completed' && call.listenerEarn != null) {
            totalEarnings += call.listenerEarn!;
          }
        }
        
        if (mounted) {
          setState(() {
            _totalEarnings = totalEarnings;
          });
        }
      }
    } catch (e) {
      // Silently handle errors - will show 0.00
    }
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _loadListenerFuture = _loadListenerData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadListenerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: const Color(0xFFFFE4EC),
              elevation: 0,
              title: const Text(
                "My Profile",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: const ProfileCardSkeleton(),
            ),
          );
        }

        if (_listener == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Failed to load profile'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshProfile,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final listener = _listener!;
        final isMobile = MediaQuery.of(context).size.width < 420;
        final avatarRadius = isMobile ? 34.0 : 40.0;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: const Color(0xFFFFE4EC),
            elevation: 0,
            title: const Text(
              "My Profile",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Row(
                  children: [
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
                        "₹${_totalEarnings.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
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
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Column(
              children: [
                // Profile Header
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFFC7D8),
                      width: 2,
                    ),
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
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFFF5C8A),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF5C8A).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          key: ValueKey(listener.avatarUrl),
                          radius: avatarRadius,
                          backgroundImage: avatarProvider(listener.avatarUrl),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listener.professionalName ?? 'Priya Rani',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  (() {
                                    final g = "Female";
                                    if (g.isNotEmpty) {
                                      return g;
                                    } else if (_gender != null &&
                                        _gender!.isNotEmpty) {
                                      return _gender!;
                                    } else {
                                      return 'Female';
                                    }
                                  })(),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                // Show city if available
                                if (listener.city != null &&
                                    listener.city!.isNotEmpty) ...[
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.location_city,
                                    size: 14,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    listener.city!,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  size: 14,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${(listener.rating).toStringAsFixed(1)}/5.0 (${listener.totalCalls} calls)',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                        onTap: () async {
                                          if (listener.listenerId.isEmpty) {
                                            await _refreshProfile();
                                            if (_listener == null ||
                                                _listener!.listenerId.isEmpty) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Listener data is still loading. Try again shortly.',
                                                    ),
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                          }

                                          final result = await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => EditProfilePage(
                                                listener: _listener!,
                                                gender: _gender,
                                              ),
                                            ),
                                          );

                                          if (result is models.Listener) {
                                            setState(() {
                                              _listener = result;
                                            });
                                            // Refresh from backend in background to sync any other data
                                            // but don't await to keep UI responsive
                                            Future.delayed(
                                              const Duration(milliseconds: 500),
                                              () {
                                                if (mounted) _refreshProfile();
                                              },
                                            );
                                          }
                                        },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isMobile ? 6 : 8,
                                        vertical: isMobile ? 6 : 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFFF5C8A),
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.edit,
                                            color: const Color(0xFFFF5C8A),
                                            size: isMobile ? 14 : 16,
                                          ),
                                          SizedBox(width: isMobile ? 2 : 4),
                                          Text(
                                            "Edit Profile",
                                            style: TextStyle(
                                              color: const Color(0xFFFF5C8A),
                                              fontWeight: FontWeight.w500,
                                              fontSize: isMobile ? 11 : 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: isMobile ? 6 : 8),
                                Expanded(
                                  child: InkWell(
                                        onTap: () {
                                          // Navigate to Earnings screen (renamed from PaymentMethodsPage)
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const PaymentMethodsPage(),
                                            ),
                                          );
                                        },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF5C8A),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.account_balance_wallet,
                                            color: Colors.white,
                                            size: isMobile ? 15 : 16,
                                          ),
                                          SizedBox(width: isMobile ? 3 : 4),
                                          Text(
                                            "Earned",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: isMobile ? 12 : 13,
                                            ),
                                          ),
                                        ],
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

                _buildListTile(
                  Icons.person_outline,
                  "Professional Details",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfessionalDetailsPage(
                          listener: listener,
                        ),
                      ),
                    );
                  },
                ),

                 _buildListTile(
                  Icons.account_balance_wallet,
                  "Payment Details",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentDetailsPage(
                          listener: listener,
                        ),
                      ),
                    );
                  },
                ),

                _buildListTile(
                  Icons.history,
                  "Recents",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecentsScreen(),
                      ),
                    );
                  },
                ),

                _buildListTile(
                  Icons.swap_horiz,
                  "Transactions",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WalletScreen(),
                      ),
                    );
                  },
                ),

                _buildListTile(
                  Icons.mail_outline,
                  "Contact Us",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContactUsPage(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),
                const Text(
                  "100% Safe and Private",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

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

// Top-level helper functions
ImageProvider avatarProvider(String? url) {
  if (url == null || url.isEmpty) {
    return const AssetImage('assets/images/user.png');
  }
  final lower = url.toLowerCase();
  if (lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.startsWith('data:')) {
    return NetworkImage(url);
  }
  return AssetImage(url);
}

String safeJoin(List<String>? items, {String fallback = 'Not specified'}) {
  if (items == null || items.isEmpty) return fallback;
  return items.join(', ');
}

// ============================================
// EDIT PROFILE PAGE
// ============================================
class EditProfilePage extends StatefulWidget {
  final models.Listener listener;
  final String? gender;

  const EditProfilePage({
    required this.listener,
    required this.gender,
    super.key,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _cityController;
  late TextEditingController _ageController;
  late TextEditingController _mobileController;
  late List<String> _selectedLanguages;
  String? _selectedSpecialty;
  int? _selectedAvatarIndex;

  final List<String> _avatarImages = [
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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.listener.professionalName ?? '',
    );
    _cityController = TextEditingController(text: widget.listener.city ?? '');
    _ageController = TextEditingController(
      text: widget.listener.age?.toString() ?? '',
    );
    _mobileController = TextEditingController(
      text: widget.listener.mobileNumber ?? '',
    );
    _selectedLanguages = List.from(widget.listener.languages);
    _selectedSpecialty = widget.listener.specialties.isNotEmpty
        ? widget.listener.specialties.first
        : null;

    if (widget.listener.avatarUrl != null &&
        widget.listener.avatarUrl!.isNotEmpty) {
      final idx = _avatarImages.indexOf(widget.listener.avatarUrl!);
      if (idx != -1) _selectedAvatarIndex = idx;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _ageController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4EC),
        elevation: 0,
        title: const Text('Edit Profile'),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.gender ?? 'Female',
                style: const TextStyle(fontSize: 16),
              ),
            ),

            const SizedBox(height: 20),

            // Avatar Selection
            const Text(
              'Profile Avatar',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Center(
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.pinkAccent, width: 3),
                    ),
                    child: CircleAvatar(
                      key: ValueKey(
                        _selectedAvatarIndex != null
                            ? _avatarImages[_selectedAvatarIndex!]
                            : widget.listener.avatarUrl,
                      ),
                      radius: 48,
                      backgroundImage: avatarProvider(
                        _selectedAvatarIndex != null
                            ? _avatarImages[_selectedAvatarIndex!]
                            : widget.listener.avatarUrl,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _showAvatarPicker,
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Change Avatar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.pinkAccent,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Professional Name
            const Text(
              'Professional Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your professional name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.pinkAccent,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // City
            const Text(
              'City',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: 'Enter your city',
                prefixIcon: const Icon(
                  Icons.location_city,
                  color: Colors.pinkAccent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.pinkAccent,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Age
            const Text(
              'Age',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter your age',
                prefixIcon: const Icon(
                  Icons.cake_rounded,
                  color: Colors.pinkAccent,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.pinkAccent,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mobile Number
            const Text(
              'Mobile Number (Optional)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: InputDecoration(
                hintText: 'Enter 10-digit mobile number',
                counterText: '',
                prefixIcon: const Icon(
                  Icons.phone_android,
                  color: Colors.pinkAccent,
                ),
                prefixText: '+91 ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Colors.pinkAccent,
                    width: 2,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Languages
            const Text(
              'Languages',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildLanguageSelector(),

            const SizedBox(height: 24),

            // Specialties
            const Text(
              'Specialties',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildSpecialtySelector(),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Avatar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _avatarImages.length,
                itemBuilder: (c, index) {
                  final isSelected =
                      _selectedAvatarIndex == index ||
                      (widget.listener.avatarUrl == _avatarImages[index] &&
                          _selectedAvatarIndex == null);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedAvatarIndex = index;
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.pinkAccent
                                : Colors.grey[300]!,
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundImage: AssetImage(_avatarImages[index]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Widget _buildLanguageSelector() {
    final languages = ['Hindi', 'English', 'Kannada', 'Tamil', 'Telugu'];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: languages.map((lang) {
        final isSelected = _selectedLanguages.contains(lang);
        return FilterChip(
          label: Text(lang),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedLanguages.add(lang);
              } else {
                _selectedLanguages.remove(lang);
              }
            });
          },
          backgroundColor: Colors.grey[200],
          selectedColor: Colors.pinkAccent,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSpecialtySelector() {
    final specialties = [
      "Confidence",
      "Marriage",
      "Single",
      "Breakup",
      "Relationship",
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: specialties.map((specialty) {
        final isSelected = _selectedSpecialty == specialty;
        return ChoiceChip(
          label: Text(specialty),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedSpecialty = selected ? specialty : null;
            });
          },
          backgroundColor: Colors.grey[200],
          selectedColor: Colors.pinkAccent,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
          ),
        );
      }).toList(),
    );
  }

  Future<void> _saveChanges() async {
    // Validation
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    final ageText = _ageController.text.trim();
    final mobile = _mobileController.text.trim();
    int? age;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a professional name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate age if provided
    if (ageText.isNotEmpty) {
      age = int.tryParse(ageText);
      if (age == null || age < 18 || age > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid age between 18 and 100'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Validate mobile if provided
    if (mobile.isNotEmpty && mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mobile number must be exactly 10 digits'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one language'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedSpecialty == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a specialty'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final listenerService = ListenerService();

      // Build update data
      final Map<String, dynamic> updates = {
        'professional_name': name,
        'languages': _selectedLanguages,
        'specialties': [_selectedSpecialty!],
      };

      // Add city if provided
      if (city.isNotEmpty) {
        updates['city'] = city;
      }

      // Add age if provided
      if (age != null) {
        updates['age'] = age;
      }

      // Add mobile if provided
      if (mobile.isNotEmpty) {
        updates['mobile_number'] = mobile;
      }

      // Add avatar if selected
      if (_selectedAvatarIndex != null) {
        updates['profile_image'] = _avatarImages[_selectedAvatarIndex!];
      }

      final result = await listenerService.updateListener(
        widget.listener.listenerId,
        updates,
      );

      if (!mounted) return;

      if (result.success) {
        // Persist updated data to local storage
        final storage = StorageService();
        try {
          await storage.saveListenerProfessionalName(name);
          await storage.saveListenerSpecialties([_selectedSpecialty!]);
          await storage.saveListenerLanguage(_selectedLanguages.join(','));

          if (city.isNotEmpty) {
            await storage.saveListenerCity(city);
          }

          if (age != null) {
            await storage.saveListenerAge(age);
          }

          if (_selectedAvatarIndex != null) {
            await storage.saveListenerAvatarUrl(
              _avatarImages[_selectedAvatarIndex!],
            );
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Create updated listener object to return
        final updatedListener = models.Listener(
          listenerId: widget.listener.listenerId,
          userId: widget.listener.userId,
          professionalName: name,
          age: age ?? widget.listener.age,
          specialties: [_selectedSpecialty!],
          languages: _selectedLanguages,
          ratePerMinute: widget.listener.ratePerMinute,
          isOnline: widget.listener.isOnline,
          isAvailable: widget.listener.isAvailable,
          isApproved: widget.listener.isApproved,
          rating: widget.listener.rating,
          totalCalls: widget.listener.totalCalls,
          totalMinutes: widget.listener.totalMinutes,
          experienceYears: widget.listener.experienceYears,
          education: widget.listener.education,
          certifications: widget.listener.certifications,
          avatarUrl: _selectedAvatarIndex != null
              ? _avatarImages[_selectedAvatarIndex!]
              : widget.listener.avatarUrl,
          bio: widget.listener.bio,
          city: city.isNotEmpty ? city : widget.listener.city,
          country: widget.listener.country,
          mobileNumber: mobile.isNotEmpty ? mobile : widget.listener.mobileNumber,
          createdAt: widget.listener.createdAt,
        );

        Navigator.pop(context, updatedListener);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to update profile'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ============================================
// PROFESSIONAL DETAILS PAGE
// ============================================
class ProfessionalDetailsPage extends StatelessWidget {
  final models.Listener listener;

  const ProfessionalDetailsPage({
    required this.listener,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4EC),
        elevation: 0,
        title: const Text(
          "Professional Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDetailCard(
            'Specialties',
            safeJoin(listener.specialties, fallback: 'Not specified'),
            Icons.psychology,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Languages',
            safeJoin(listener.languages, fallback: 'Not specified'),
            Icons.language,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Age',
            listener.age != null ? '${listener.age} years' : 'Not specified',
            Icons.cake_rounded,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Rate',
            listener.ratePerMinute > 0
                ? '₹${listener.ratePerMinute.toStringAsFixed(0)}/min'
                : 'Not specified',
            Icons.currency_rupee,
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            'Experience',
            (listener.totalMinutes > 0)
                ? (() {
                    final hours = listener.totalMinutes ~/ 60;
                    final minutes = listener.totalMinutes % 60;
                    String result = '';
                    if (hours > 0) result += '${hours}h ';
                    if (minutes > 0) result += '${minutes}m';
                    return result.trim().isNotEmpty ? result.trim() : '0m';
                  })()
                : 'Not specified',
                Icons.work,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.pinkAccent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// PAYMENT DETAILS PAGE
// ============================================
class PaymentDetailsPage extends StatelessWidget {
  final models.Listener listener;

  const PaymentDetailsPage({
    required this.listener,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final paymentInfo = listener.paymentInfo;
    final hasPaymentInfo = paymentInfo != null && paymentInfo.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4EC),
        elevation: 0,
        title: const Text(
          "Payment Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (hasPaymentInfo) ...[
            _buildInfoCard(
              'Payment Method',
              _getPaymentMethodText(paymentInfo['payment_method']),
              Icons.payment,
            ),
            const SizedBox(height: 12),
            if (paymentInfo['payment_method'] == 'upi' || paymentInfo['payment_method'] == 'both') ...[
              if (paymentInfo['upi_id'] != null) ...[
                _buildInfoCard(
                  'UPI ID',
                  paymentInfo['upi_id'],
                  Icons.account_balance_wallet,
                ),
                const SizedBox(height: 12),
              ],
            ],
            if (paymentInfo['payment_method'] == 'bank' || paymentInfo['payment_method'] == 'both') ...[
              _buildInfoCard(
                'Account Holder Name',
                paymentInfo['account_holder_name'] ?? 'Not specified',
                Icons.person,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                'Account Number',
                _maskAccountNumber(paymentInfo['account_number']),
                Icons.account_balance,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                'IFSC Code',
                paymentInfo['ifsc_code'] ?? 'Not specified',
                Icons.code,
              ),
              const SizedBox(height: 12),
              _buildInfoCard(
                'Bank Name',
                paymentInfo['bank_name'] ?? 'Not specified',
                Icons.account_balance,
              ),
              const SizedBox(height: 12),
            ],
            if (paymentInfo['pan_number'] != null) ...[
              _buildInfoCard(
                'PAN Number',
                _maskPAN(paymentInfo['pan_number']),
                Icons.credit_card,
              ),
              const SizedBox(height: 12),
            ],
            if (paymentInfo['aadhaar_number'] != null) ...[
              _buildInfoCard(
                'Aadhaar Number',
                _maskAadhaar(paymentInfo['aadhaar_number']),
                Icons.badge,
              ),
              const SizedBox(height: 12),
            ],
            _buildInfoCard(
              'Verification Status',
              paymentInfo['payout_status'] == 'verified' ? 'Verified ✓' : 'Pending Verification',
              Icons.verified,
              statusColor: paymentInfo['payout_status'] == 'verified' ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 24),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE4EC)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Payment Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your payment details to receive payouts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Update Payment Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditPaymentDetailsPage(
                      listener: listener,
                    ),
                  ),
                );
                
                if (result == true && context.mounted) {
                  // Refresh the page
                  Navigator.pop(context);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Update Payment Details',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[100]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your payment details are encrypted and secure. Updates may take 24-48 hours to verify.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {Color? statusColor}) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE4EC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.pinkAccent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: statusColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentMethodText(String? method) {
    switch (method) {
      case 'upi':
        return 'UPI';
      case 'bank':
        return 'Bank Transfer';
      case 'both':
        return 'UPI & Bank';
      default:
        return 'Not specified';
    }
  }

  String _maskAccountNumber(String? accountNumber) {
    if (accountNumber == null || accountNumber.isEmpty) return 'Not specified';
    if (accountNumber.length <= 4) return accountNumber;
    final last4 = accountNumber.substring(accountNumber.length - 4);
    return 'XXXX-XXXX-$last4';
  }

  String _maskPAN(String? pan) {
    if (pan == null || pan.isEmpty) return 'Not specified';
    if (pan.length <= 4) return pan;
    return 'XXXXXX${pan.substring(pan.length - 4)}';
  }

  String _maskAadhaar(String? aadhaar) {
    if (aadhaar == null || aadhaar.isEmpty) return 'Not specified';
    if (aadhaar.length <= 4) return aadhaar;
    return 'XXXX-XXXX-${aadhaar.substring(aadhaar.length - 4)}';
  }
}

// ============================================
// EDIT PAYMENT DETAILS PAGE
// ============================================
class EditPaymentDetailsPage extends StatefulWidget {
  final models.Listener listener;

  const EditPaymentDetailsPage({
    required this.listener,
    super.key,
  });

  @override
  State<EditPaymentDetailsPage> createState() => _EditPaymentDetailsPageState();
}

class _EditPaymentDetailsPageState extends State<EditPaymentDetailsPage> {
  late TextEditingController _upiController;
  late TextEditingController _accountNumberController;
  late TextEditingController _ifscController;
  late TextEditingController _bankNameController;
  late TextEditingController _accountHolderController;
  late TextEditingController _panController;
  late TextEditingController _aadhaarController;
  String _selectedMethod = 'upi';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final paymentInfo = widget.listener.paymentInfo;
    
    _upiController = TextEditingController(text: paymentInfo?['upi_id'] ?? '');
    _accountNumberController = TextEditingController(text: paymentInfo?['account_number'] ?? '');
    _ifscController = TextEditingController(text: paymentInfo?['ifsc_code'] ?? '');
    _bankNameController = TextEditingController(text: paymentInfo?['bank_name'] ?? '');
    _accountHolderController = TextEditingController(text: paymentInfo?['account_holder_name'] ?? '');
    _panController = TextEditingController(text: paymentInfo?['pan_number'] ?? '');
    _aadhaarController = TextEditingController(text: paymentInfo?['aadhaar_number'] ?? '');
    _selectedMethod = paymentInfo?['payment_method'] ?? 'upi';
  }

  @override
  void dispose() {
    _upiController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _accountHolderController.dispose();
    _panController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFE4EC),
        elevation: 0,
        title: const Text(
          "Update Payment Details",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Method Selection
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'upi',
                  label: Text('UPI'),
                  icon: Icon(Icons.account_balance_wallet, size: 16),
                ),
                ButtonSegment(
                  value: 'bank',
                  label: Text('Bank'),
                  icon: Icon(Icons.account_balance, size: 16),
                ),
                ButtonSegment(
                  value: 'both',
                  label: Text('Both'),
                  icon: Icon(Icons.payment, size: 16),
                ),
              ],
              selected: {_selectedMethod},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedMethod = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 24),
            
            // UPI Fields
            if (_selectedMethod == 'upi' || _selectedMethod == 'both') ...[
              const Text(
                'UPI Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _upiController,
                decoration: InputDecoration(
                  labelText: 'UPI ID *',
                  hintText: 'yourname@upi',
                  prefixIcon: const Icon(Icons.account_balance_wallet, color: Colors.pinkAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Bank Fields
            if (_selectedMethod == 'bank' || _selectedMethod == 'both') ...[
              const Text(
                'Bank Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _accountHolderController,
                decoration: InputDecoration(
                  labelText: 'Account Holder Name *',
                  prefixIcon: const Icon(Icons.person, color: Colors.pinkAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Account Number *',
                  prefixIcon: const Icon(Icons.account_balance, color: Colors.pinkAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _ifscController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'IFSC Code *',
                  prefixIcon: const Icon(Icons.code, color: Colors.pinkAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _bankNameController,
                decoration: InputDecoration(
                  labelText: 'Bank Name *',
                  prefixIcon: const Icon(Icons.account_balance, color: Colors.pinkAccent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // Additional Details
            const Text(
              'Additional Details (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _panController,
              textCapitalization: TextCapitalization.characters,
              maxLength: 10,
              decoration: InputDecoration(
                labelText: 'PAN Number',
                hintText: 'ABCDE1234F',
                prefixIcon: const Icon(Icons.credit_card, color: Colors.pinkAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _aadhaarController,
              keyboardType: TextInputType.number,
              maxLength: 12,
              decoration: InputDecoration(
                labelText: 'Aadhaar Number',
                hintText: 'XXXX-XXXX-XXXX',
                prefixIcon: const Icon(Icons.badge, color: Colors.pinkAccent),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePaymentDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Update Payment Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePaymentDetails() async {
    // Validate inputs
    if (_selectedMethod == 'upi' && _upiController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter UPI ID'), backgroundColor: Colors.red),
      );
      return;
    }
    
    if ((_selectedMethod == 'bank' || _selectedMethod == 'both') &&
        (_accountNumberController.text.trim().isEmpty ||
         _ifscController.text.trim().isEmpty ||
         _accountHolderController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required bank details'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final listenerService = ListenerService();
      
      final paymentData = {
        'payment_method': _selectedMethod,
        if (_selectedMethod == 'upi' || _selectedMethod == 'both')
          'upi_id': _upiController.text.trim(),
        if (_selectedMethod == 'bank' || _selectedMethod == 'both') ...{
          'account_number': _accountNumberController.text.trim(),
          'ifsc_code': _ifscController.text.trim().toUpperCase(),
          'bank_name': _bankNameController.text.trim(),
          'account_holder_name': _accountHolderController.text.trim(),
        },
        if (_panController.text.trim().isNotEmpty)
          'pan_number': _panController.text.trim().toUpperCase(),
        if (_aadhaarController.text.trim().isNotEmpty)
          'aadhaar_number': _aadhaarController.text.trim(),
      };

      final result = await listenerService.updatePaymentDetails(paymentData);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment details updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Return success to refresh the previous page
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to update payment details'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
