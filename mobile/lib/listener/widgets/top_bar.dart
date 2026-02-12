import 'package:flutter/material.dart';
import '../nav/profile.dart';
import '../../services/storage_service.dart';
import '../../services/listener_service.dart';
import '../../services/call_service.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  String? _avatarUrl;
  double _totalEarnings = 0.0;
  // ignore: unused_field - used for future loading state
  bool _isLoading = true;
  final CallService _callService = CallService();

  @override
  void initState() {
    super.initState();
    _loadAvatar();
    _loadEarnings();
  }

  /// Load total earnings from call history
  Future<void> _loadEarnings() async {
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
      print('Failed to load earnings: $e');
    }
  }

  Future<void> _loadAvatar() async {
    final storageService = StorageService();

    // First, try to get from local storage immediately (fast)
    String? localAvatar = await storageService.getListenerAvatarUrl();
    if (localAvatar == null || localAvatar.isEmpty) {
      localAvatar = await storageService.getAvatarUrl();
    }

    if (mounted && localAvatar != null && localAvatar.isNotEmpty) {
      setState(() {
        _avatarUrl = localAvatar;
        _isLoading = false;
      });
    }

    // Then try to fetch from backend for latest data (in background)
    try {
      final listenerService = ListenerService();
      final result = await listenerService.getMyProfile();
      if (result.success &&
          result.listener != null &&
          result.listener!.avatarUrl != null) {
        final backendAvatar = result.listener!.avatarUrl!;
        await storageService.saveListenerAvatarUrl(backendAvatar);
        if (mounted && backendAvatar.isNotEmpty) {
          setState(() {
            _avatarUrl = backendAvatar;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Backend fetch failed, use local storage value
      print('Failed to fetch avatar from backend: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: BottomCurveClipper(),
      child: Container(
        width: double.infinity,
        height: 90,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: const BoxDecoration(color: Color(0xFFFADADD)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            /// LEFT SIDE → Profile + Wallet (₹0.00 just right of profile)
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    );
                    if (result != null) {
                      _loadAvatar();
                    }
                    // Refresh earnings when returning from profile
                    _loadEarnings();
                  },
                  child: _buildAvatarWidget(),
                ),

                const SizedBox(width: 10),

                /// Wallet
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.currency_rupee_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _totalEarnings.toStringAsFixed(2),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            /// RIGHT SIDE → Logo
            Image.asset(
              'assets/login/logo.png',
              height: 36,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      // Check if it's an asset or network image
      if (_avatarUrl!.startsWith('http')) {
        return CircleAvatar(
          radius: 20,
          backgroundImage: NetworkImage(_avatarUrl!),
        );
      } else {
        return CircleAvatar(
          radius: 20,
          backgroundImage: AssetImage(_avatarUrl!),
        );
      }
    }
    // Default avatar
    return const CircleAvatar(
      radius: 20,
      backgroundImage: AssetImage('assets/images/female_profile/avatar15.jpg'),
    );
  }
}

/// Bottom curved clipper
class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
