import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../actions/calling.dart';
import '../../services/storage_service.dart';
import '../../services/socket_service.dart';

class ExpertCard extends StatefulWidget {
  final String name;
  final int age;
  final String city;
  final String topic;
  final String rate;
  final String? secondaryRate;
  final double rating;
  final String imagePath;
  final List<String> languages;
  final String? listenerId;
  final String? listenerUserId; // The user_id for socket communication
  final bool isOnline; // Online status from parent (API + socket)
  final bool isBusy; // Busy status from parent (API + socket)

  const ExpertCard({
    super.key,
    required this.name,
    required this.age,
    required this.city,
    required this.topic,
    required this.rate,
    this.secondaryRate,
    required this.rating,
    required this.imagePath,
    this.languages = const ['Hindi', 'English'],
    this.listenerId,
    this.listenerUserId,
    this.isOnline = false,
    this.isBusy = false,
  });

  @override
  State<ExpertCard> createState() => _ExpertCardState();
}

class _ExpertCardState extends State<ExpertCard> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  late AnimationController _pulseController;
  bool isListenerOnline = false; // Track listener online status
  bool isListenerBusy = false; // Track listener busy status
  StreamSubscription<Map<String, bool>>? _onlineSubscription;
  StreamSubscription<Map<String, bool>>? _offlineSubscription;
  StreamSubscription<Map<String, bool>>? _busySubscription;

  @override
  void initState() {
    super.initState();
    print('[EXPERT_CARD] Init for listenerUserId: ${widget.listenerUserId}, listenerId: ${widget.listenerId}, isOnline: ${widget.isOnline}');
    
    // Initialize online status from parent widget (API + socket status)
    isListenerOnline = widget.isOnline;
    isListenerBusy = widget.isBusy;
    
    // Also check socket map for real-time updates
    final initialMap = SocketService().listenerOnlineMap;
    final initialBusyMap = SocketService().listenerBusyMap;
    final id = widget.listenerUserId ?? widget.listenerId;
    if (id != null && initialMap.containsKey(id)) {
      isListenerOnline = initialMap[id]!;
    }
    if (id != null && initialBusyMap.containsKey(id)) {
      isListenerBusy = initialBusyMap[id]!;
    }

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Listen to audio completion
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        isPlaying = false;
      });
    });

    // Set up socket listeners for presence events
    _setupPresenceListeners();
    
    // Ensure socket is connected to receive presence events
    _ensureSocketConnection();
  }

  @override
  void didUpdateWidget(ExpertCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update online status if parent provides a new value
    if (widget.isOnline != oldWidget.isOnline) {
      setState(() {
        isListenerOnline = widget.isOnline;
      });
    }
    if (widget.isBusy != oldWidget.isBusy) {
      setState(() {
        isListenerBusy = widget.isBusy;
      });
    }
  }

  Future<void> _toggleVoice() async {
    if (isPlaying) {
      await _audioPlayer.stop();
      setState(() {
        isPlaying = false;
      });
    } else {
      await _audioPlayer.play(AssetSource('voice/sample.mp3'));
      setState(() {
        isPlaying = true;
      });
    }
  }

  void _setupPresenceListeners() {
    final socketService = SocketService();
    // --- FIX: Listen for real-time online/offline events ---
    _onlineSubscription = socketService.listenerStatusStream.listen((map) {
      final id = widget.listenerUserId ?? widget.listenerId;
      if (id != null && map.containsKey(id)) {
        final online = map[id]!;
        if (mounted) {
          setState(() {
            isListenerOnline = online;
          });
        }
      }
    });
    // Listen for real-time busy status events
    _busySubscription = socketService.listenerBusyStream.listen((map) {
      final id = widget.listenerUserId ?? widget.listenerId;
      if (id != null && map.containsKey(id)) {
        final busy = map[id]!;
        if (mounted) {
          setState(() {
            isListenerBusy = busy;
          });
        }
      }
    });
  }

  Future<void> _ensureSocketConnection() async {
    final socketService = SocketService();
    print('[EXPERT_CARD] Ensuring socket connection...');
    if (!socketService.isConnected) {
      print('[EXPERT_CARD] Socket not connected, connecting...');
      await socketService.connect();
      print('[EXPERT_CARD] Socket connection attempt completed');
    } else {
      print('[EXPERT_CARD] Socket already connected');
    }
  }

  void _handleCallNow() async {
    // Check if listener is online from real-time socket map or widget status
    final currentOnlineStatus = isListenerOnline;
    
    if (!currentOnlineStatus) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listener is offline')),
        );
      }
      return;
    }

    // BUSY CHECK: Prevent calling a busy listener
    if (isListenerBusy) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listener is busy, please try later')),
        );
      }
      return;
    }

    // Stop audio before navigation
    if (isPlaying) {
      _audioPlayer.stop();
      setState(() {
        isPlaying = false;
      });
    }
    
    // Fetch current user data (quick local storage access)
    final storage = StorageService();
    final userName = await storage.getDisplayName() ?? 'You';
    final userAvatar = await storage.getAvatarUrl();
    final userGender = await storage.getGender();
    
    if (!mounted) return;

    // Navigate immediately - Calling screen will handle call creation and socket events
    final targetUserId = widget.listenerUserId ?? widget.listenerId;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Calling(
          callerName: widget.name,
          callerAvatar: widget.imagePath,
          userName: userName,
          userAvatar: userAvatar,
          listenerId: targetUserId, // User ID for socket communication
          listenerDbId: widget.listenerId, // Listener ID for database
          topic: widget.topic,
          language: widget.languages.isNotEmpty ? widget.languages.first : 'English',
          gender: userGender,
        ),
      ),
    );
  }

  String _getTruncatedName(String name) {
    if (name.length > 8) {
      return '${name.substring(0, 8)}...';
    }
    return name;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _pulseController.dispose();
    _onlineSubscription?.cancel();
    _offlineSubscription?.cancel();
    _busySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;
    final bool isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final bool isLargeScreen = screenWidth >= 500;

    // Responsive font sizes
    final double nameFontSize = isSmallScreen ? 13 : (isMediumScreen ? 14 : (isLargeScreen ? 16 : 15));
    final double cityFontSize = isSmallScreen ? 10 : (isLargeScreen ? 12 : 11);
    final double topicFontSize = isSmallScreen ? 10 : (isLargeScreen ? 12 : 11);
    final double ratingFontSize = isSmallScreen ? 10 : (isLargeScreen ? 12 : 11);
    final double buttonTextSize = isSmallScreen ? 10 : (isMediumScreen ? 11 : (isLargeScreen ? 13 : 12));
    final double iconSize = isSmallScreen ? 20 : (isLargeScreen ? 24 : 22);
    final double avatarSize = isSmallScreen ? 56.0 : (isLargeScreen ? 72.0 : 64.0);
    final double langFontSize = isSmallScreen ? 9 : (isLargeScreen ? 11 : 10);
    final double langPaddingH = isSmallScreen ? 5 : (isLargeScreen ? 8 : 6);
    final double langPaddingV = isSmallScreen ? 2 : (isLargeScreen ? 4 : 3);

    return Card(
      margin: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 6 : 8,
        horizontal: isSmallScreen ? 12 : 16,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      shadowColor: Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Avatar Section with Voice Button Overlay
              Column(
                children: [
                  Stack(
                    children: [
                      // Animated pulse ring for online status - only when online
                      if (isListenerOnline)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(
                                      0.3 * (1 - _pulseController.value),
                                    ),
                                    blurRadius: 8 + (8 * _pulseController.value),
                                    spreadRadius: 2 * _pulseController.value,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      // Avatar with border - Click to toggle voice
                      GestureDetector(
                        onTap: _toggleVoice,
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: (avatarSize - 6) / 2,
                            backgroundImage: widget.imagePath.startsWith('http')
                                ? NetworkImage(widget.imagePath)
                                : AssetImage(widget.imagePath) as ImageProvider,
                            onBackgroundImageError: (_, __) {},
                          ),
                        ),
                      ),
                      // Online indicator
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: isSmallScreen ? 14 : 16,
                          height: isSmallScreen ? 14 : 16,
                          decoration: BoxDecoration(
                            color: isListenerOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: (isListenerOnline ? Colors.green : Colors.grey).withOpacity(0.5),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Small speaker icon when playing
                      if (isPlaying)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withOpacity(0.9),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              Icons.volume_up,
                              color: Colors.white,
                              size: isSmallScreen ? 16 : 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  // Age badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      "${widget.age} Y",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: isSmallScreen ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(width: isSmallScreen ? 10 : 14),

              // Expert Info Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name with verified badge (max 8 characters)
                    Row(
                      children: [
                        Text(
                          _getTruncatedName(widget.name),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: nameFontSize,
                            color: Colors.black87,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.verified,
                          size: iconSize,
                          color: Colors.blue.shade400,
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 3),
                    // Location
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: iconSize,
                          color: Colors.black45,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            widget.city,
                            style: TextStyle(
                              fontSize: cityFontSize,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 3 : 4),
                    // Topic chip (single line, no overflow)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 6 : 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        widget.topic,
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: topicFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    // Rating with stars
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 5 : 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: isSmallScreen ? 12 : 14,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            widget.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: ratingFontSize,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons Section
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Call button — shows "Busy" when listener is busy
                  ElevatedButton.icon(
                    // Busy → tap shows snackbar; Online → call; Offline → disabled
                    onPressed: isListenerBusy
                        ? _handleCallNow
                        : (isListenerOnline ? _handleCallNow : null),
                    icon: Icon(
                      isListenerBusy ? Icons.phone_disabled : Icons.call,
                      size: isSmallScreen ? 14 : 16,
                    ),
                    label: Text(
                      isListenerBusy ? "Busy" : "Call Now",
                      style: TextStyle(
                        fontSize: buttonTextSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isListenerBusy
                          ? Colors.orange.shade400
                          : (isListenerOnline ? Colors.pinkAccent : Colors.grey),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      disabledForegroundColor: Colors.white70,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : (isMediumScreen ? 12 : 16),
                        vertical: isSmallScreen ? 8 : 10,
                      ),
                      elevation: (isListenerOnline && !isListenerBusy) ? 2 : 0,
                      shadowColor: (isListenerOnline && !isListenerBusy) ? Colors.pinkAccent.withOpacity(0.5) : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  // Language and Rate section
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Languages badge
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: widget.languages.asMap().entries.map((entry) {
                          final String lang = entry.value;
                          return Container(
                            margin: EdgeInsets.only(bottom: isSmallScreen ? 2 : 3),
                            padding: EdgeInsets.symmetric(
                              horizontal: langPaddingH,
                              vertical: langPaddingV,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                              border: Border.all(color: Colors.blue.withOpacity(0.3)),
                            ),
                            child: Text(
                              lang,
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: langFontSize,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(width: isSmallScreen ? 4 : 6),
                      // Rate badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 10,
                          vertical: isSmallScreen ? 4 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.rate,
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: isSmallScreen ? 10 : 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (widget.secondaryRate != null && widget.secondaryRate!.isNotEmpty)
                              Text(
                                widget.secondaryRate!,
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: isSmallScreen ? 8 : 10,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}