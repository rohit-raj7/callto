import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../actions/calling.dart';
import '../../services/socket_service.dart';
import '../../services/storage_service.dart';
import '../../services/call_service.dart';
import '../../services/listener_service.dart';
import '../../models/listener_model.dart' as model;

class RandomCallScreen extends StatefulWidget {
  const RandomCallScreen({super.key});

  @override
  State<RandomCallScreen> createState() => _RandomCallScreenState();
}

class _RandomCallScreenState extends State<RandomCallScreen>
    with TickerProviderStateMixin {
  bool isSearching = false;
  Map<String, String>? matchedUser;
  final SocketService _socketService = SocketService();
  final StorageService _storage = StorageService();
  final ListenerService _listenerService = ListenerService();
  final AudioPlayer _searchAudioPlayer = AudioPlayer();

  late AnimationController _pulseController;
  late AnimationController _orbitController;

  // Female profile avatars for the visual effect
  final List<String> _dummyAvatars = [
    'assets/images/female_profile/avatar2.jpg',
    'assets/images/female_profile/avatar3.jpg',
    'assets/images/female_profile/avatar4.jpg',
    'assets/images/female_profile/avatar5.jpg',
    'assets/images/female_profile/avatar6.jpg',
    'assets/images/female_profile/avatar7.jpg',
    'assets/images/female_profile/avatar8.jpg',
    'assets/images/female_profile/avatar9.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _stopSearchSound();
    _searchAudioPlayer.dispose();
    _pulseController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  Future<void> _startSearchSound() async {
    try {
      await _searchAudioPlayer.stop();
      await _searchAudioPlayer.setReleaseMode(ReleaseMode.loop);
      await _searchAudioPlayer.play(AssetSource('voice/random.mp3'));
    } catch (e) {
      debugPrint('RandomCall: search sound error: $e');
    }
  }

  Future<void> _stopSearchSound() async {
    try {
      await _searchAudioPlayer.stop();
    } catch (_) {}
  }

  void findRandomPerson() async {
    setState(() {
      isSearching = true;
      matchedUser = null;
    });

    _startSearchSound();

    // Minimum search animation time for better UX
    final minSearchTime = Future.delayed(const Duration(seconds: 2));

    try {
      // Ensure socket is connected to get real-time online status
      await _socketService.connect();

      int maxRetries = 3;
      int retryCount = 0;
      List<model.Listener> onlineListeners = [];

      // Retry logic to find online listeners
      while (retryCount < maxRetries && onlineListeners.isEmpty) {
        // Fetch listeners marked as online from API
        final result = await _listenerService.getListeners(
          isOnline: true,
          limit: 50, // Fetch more to increase chances
        );

        if (result.success && result.listeners.isNotEmpty) {
          // Get real-time online status from socket
          final socketOnlineMap = _socketService.listenerOnlineMap;

          // Filter listeners who are confirmed online via socket
          onlineListeners = result.listeners.where((listener) {
            // Check if listener is online in socket map
            // If socket map is empty, trust the API response
            if (socketOnlineMap.isEmpty) {
              return true;
            }
            return socketOnlineMap[listener.userId] == true;
          }).toList();

          // If no socket-confirmed online listeners, use API result
          if (onlineListeners.isEmpty && result.listeners.isNotEmpty) {
            onlineListeners = result.listeners;
          }
        }

        if (onlineListeners.isEmpty) {
          retryCount++;
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(milliseconds: 500));
          }
        }
      }

      // Wait for minimum search time
      await minSearchTime;

      if (onlineListeners.isNotEmpty) {
        // Shuffle and pick random listener
        onlineListeners.shuffle();
        final randomListener = onlineListeners.first;

        await _stopSearchSound();
        setState(() {
          isSearching = false;
          matchedUser = {
            'id': randomListener.userId,
            'listener_id': randomListener.listenerId,
            'name': randomListener.professionalName ?? 'Unknown',
            'city': randomListener.city ?? 'Unknown',
            'topic': randomListener.specialties.isNotEmpty
                ? randomListener.specialties.first
                : 'General',
            'image':
                randomListener.avatarUrl ??
                'assets/images/female_profile/avatar2.jpg',
          };
        });
      } else {
        await _stopSearchSound();
        setState(() {
          isSearching = false;
          matchedUser = null;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No Experts online right now. Please try again later.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error finding random listener: $e');
      await _stopSearchSound();
      await minSearchTime;
      setState(() {
        isSearching = false;
        matchedUser = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to find Experts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void startCall(Map<String, String> user) async {
    // Connect to socket and wait for connection
    final connected = await _socketService.connect();

    if (!connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect. Please try again.')),
        );
      }
      return;
    }

    // Get current user info
    final userName = await _storage.getDisplayName() ?? 'You';
    final userAvatar = await _storage.getAvatarUrl();
    final userGender = await _storage.getGender();

    final listenerId = user['id'];

    // Create call record in database first
    final callService = CallService();
    final callResult = await callService.initiateCall(
      listenerId: user['listener_id'] ?? listenerId ?? '',
      callType: 'audio',
    );

    if (!callResult.success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(callResult.error ?? 'Failed to initiate call'),
          ),
        );
      }
      return;
    }

    final callId = callResult.call!.callId;

    // Notify listener via socket
    if (listenerId != null) {
      print('Caller: Initiating call to Experts userId: $listenerId');
      _socketService.initiateCall(
        callId: callId,
        listenerId: listenerId,
        callerName: userName,
        callerAvatar: userAvatar,
        topic: user['topic'],
        gender: userGender,
      );
    } else {
      print('Warning: No Experts userId available for call');
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Calling(
          callerName: user['name']!,
          callerAvatar: user['image']!,
          userName: userName,
          userAvatar: userAvatar,
          channelName: callId,
          listenerId: listenerId,
        ),
      ),
    );
  }

  void _handleBack() {
    _stopSearchSound();
    if (isSearching) {
      setState(() {
        isSearching = false;
        matchedUser = null;
      });
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF0B1220),
        appBar: AppBar(
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
            onPressed: _handleBack,
          ),
          title: const Text(
            "Random Match",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0B1220), Color(0xFF111827), Color(0xFF312E81)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            bottom: true,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              child: isSearching
                  ? _orbitSearchingView(size)
                  : matchedUser != null
                  ? _matchedCard(matchedUser!, size)
                  : _idleView(size),
            ),
          ),
        ),
      ),
    );
  }

  /// ---------------- Idle View ----------------
  Widget _idleView(Size size) {
    // Responsive sizes based on screen
    final circleSize = size.width * 0.4;
    final maxCircleSize = circleSize > 180 ? 180.0 : circleSize;
    final iconSize = maxCircleSize * 0.44;

    return SingleChildScrollView(
      key: const ValueKey('idle'),
      physics: const BouncingScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight:
              size.height -
              MediaQuery.of(context).padding.top -
              kToolbarHeight -
              MediaQuery.of(context).padding.bottom,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: size.width * 0.06,
            vertical: size.height * 0.02,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: size.height * 0.05),
              // Pulsing Radar Effect
              Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow rings
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width:
                            maxCircleSize * 1.55 +
                            (_pulseController.value * 40),
                        height:
                            maxCircleSize * 1.55 +
                            (_pulseController.value * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.pinkAccent.withOpacity(
                              0.1 - (_pulseController.value * 0.1),
                            ),
                            width: 1,
                          ),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width:
                            maxCircleSize * 1.22 +
                            (_pulseController.value * 30),
                        height:
                            maxCircleSize * 1.22 +
                            (_pulseController.value * 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.pinkAccent.withOpacity(0.05),
                        ),
                      );
                    },
                  ),
                  // Main Circle
                  Container(
                    width: maxCircleSize,
                    height: maxCircleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_search_rounded,
                      size: iconSize,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: size.height * 0.04),
              Text(
                "Find Your Match",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width * 0.062,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              SizedBox(height: size.height * 0.015),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.05),
                child: Text(
                  "Connect instantly with a verified Experts for a random voice conversation.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: size.width * 0.037,
                    height: 1.6,
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.02),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.008,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      color: Colors.white.withOpacity(0.8),
                      size: size.width * 0.04,
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      "Verified Experts only",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: size.width * 0.032,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: size.height * 0.05),
              // Start Matching Button
              Container(
                height: size.height * 0.065,
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 56, minHeight: 48),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEC4899).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: findRandomPerson,
                    borderRadius: BorderRadius.circular(28),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: size.width * 0.052,
                        ),
                        SizedBox(width: size.width * 0.02),
                        Text(
                          "Start Matching",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size.width * 0.039,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.03),
            ],
          ),
        ),
      ),
    );
  }

  /// ---------------- Orbit/Radar Searching View ----------------
  Widget _orbitSearchingView(Size size) {
    final baseRadius = size.width * 0.2;
    final avatarRadius = size.width * 0.045;

    return SizedBox(
      key: const ValueKey('searching'),
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Radar Circles
          ...List.generate(4, (index) {
            final double radarSize =
                (baseRadius * 1.5) + (index * baseRadius * 0.8);
            return Container(
              width: radarSize,
              height: radarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.07),
                  width: 1,
                ),
              ),
            );
          }),

          // Orbiting Avatars
          AnimatedBuilder(
            animation: _orbitController,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: _dummyAvatars.asMap().entries.map((entry) {
                  final index = entry.key;
                  final imagePath = entry.value;

                  // Calculate different orbit paths - responsive
                  final double radius =
                      baseRadius + ((index % 3) * baseRadius * 0.6);
                  final double speed = 1.0 + ((index % 3) * 0.5);
                  final bool clockwise = index % 2 == 0;

                  final double initialAngle =
                      (index * (2 * math.pi / _dummyAvatars.length));
                  final double currentAngle =
                      initialAngle +
                      (_orbitController.value *
                          2 *
                          math.pi *
                          speed *
                          (clockwise ? 1 : -1));

                  return Transform.translate(
                    offset: Offset(
                      math.cos(currentAngle) * radius,
                      math.sin(currentAngle) * radius,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pinkAccent.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: avatarRadius,
                        backgroundImage: AssetImage(imagePath),
                        backgroundColor: Colors.grey[800],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // Center Glowing Core
          Container(
            width: size.width * 0.15,
            height: size.width * 0.15,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: size.width * 0.025,
                height: size.width * 0.025,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.pinkAccent.withOpacity(0.8),
                ),
              ),
            ),
          ),

          // Bottom Text
          Positioned(
            bottom: size.height * 0.12,
            left: size.width * 0.05,
            right: size.width * 0.05,
            child: Column(
              children: [
                Text(
                  "Finding available Experts...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.width * 0.043,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                SizedBox(height: size.height * 0.01),
                Text(
                  "Scanning online profiles",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: size.width * 0.034,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ---------------- Matched User Card ----------------
  Widget _matchedCard(Map<String, String> user, Size size) {
    final avatarRadius = size.width * 0.13;
    final maxAvatarRadius = avatarRadius > 60 ? 60.0 : avatarRadius;

    return SingleChildScrollView(
      key: const ValueKey('matched'),
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.05,
          vertical: size.height * 0.02,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(size.width * 0.05),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF111827), Color(0xFF1F2937)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Badge
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.01,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: size.width * 0.038,
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      "Match Found!",
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: size.width * 0.034,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: size.height * 0.025),

              // Avatar with Glow
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pinkAccent.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: maxAvatarRadius,
                  backgroundImage: AssetImage(user['image']!),
                  backgroundColor: Colors.grey[800],
                ),
              ),
              SizedBox(height: size.height * 0.02),

              // User Details
              Text(
                user['name']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size.width * 0.058,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: size.height * 0.008),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on,
                    color: Colors.white.withOpacity(0.6),
                    size: size.width * 0.04,
                  ),
                  SizedBox(width: size.width * 0.01),
                  Text(
                    user['city']!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: size.width * 0.038,
                    ),
                  ),
                ],
              ),
              SizedBox(height: size.height * 0.02),

              // Tags
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.01,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.topic_rounded,
                      color: const Color(0xFF8B5CF6),
                      size: size.width * 0.045,
                    ),
                    SizedBox(width: size.width * 0.02),
                    Text(
                      user['topic']!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: size.width * 0.034,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: size.height * 0.03),

              // Actions
              SizedBox(
                width: double.infinity,
                height: size.height * 0.06,
                child: ElevatedButton(
                  onPressed: () => startCall(user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: size.height * 0.015,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    elevation: 4,
                    shadowColor: const Color(0xFFEC4899).withOpacity(0.4),
                  ),
                  child: Text(
                    "Start Call Now",
                    style: TextStyle(
                      fontSize: size.width * 0.041,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: size.height * 0.012),
              TextButton(
                onPressed: findRandomPerson,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: size.height * 0.01),
                  foregroundColor: Colors.white.withOpacity(0.7),
                ),
                child: Text(
                  "Find Another Match",
                  style: TextStyle(fontSize: size.width * 0.037),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
