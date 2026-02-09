import 'package:flutter/material.dart';
import 'call_controller.dart';
import 'audio_device_manager.dart';
import 'call_action_button.dart';
import 'audio_route_bottom_sheet.dart';

/// ──────────────────────────────────────────────────────────────────
/// User-side calling screen — professional mobile call UI.
///
/// Key improvements:
///  • Single UserCallState enum as source of truth (no multi-flag toggling).
///  • UserCallController owns all logic; widget only renders.
///  • One subscription per socket event (no duplicates).
///  • mounted-safe rebuilds via ChangeNotifier (no setState after dispose).
///  • Forward-only state transitions prevent UI glitches after pickup.
///  • Audio route detection with bottom sheet selector.
///  • Material 3 styled action buttons with ripple (always responsive).
///  • Bluetooth / headphone detection shown in UI automatically.
/// ──────────────────────────────────────────────────────────────────
class Calling extends StatefulWidget {
  final String callerName;
  final String callerAvatar;
  final String userName;
  final String? userAvatar;
  final String? channelName;
  final String? listenerId;
  final String? listenerDbId;
  final String? topic;
  final String? language;
  final String? gender;

  const Calling({
    super.key,
    required this.callerName,
    required this.callerAvatar,
    this.userName = 'You',
    this.userAvatar,
    this.channelName,
    this.listenerId,
    this.listenerDbId,
    this.topic,
    this.language,
    this.gender,
  });

  @override
  State<Calling> createState() => _CallingState();
}

class _CallingState extends State<Calling>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final UserCallController _controller;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = UserCallController(
      callerName: widget.callerName,
      callerAvatar: widget.callerAvatar,
      userName: widget.userName,
      userAvatar: widget.userAvatar,
      channelName: widget.channelName,
      listenerId: widget.listenerId,
      listenerDbId: widget.listenerDbId,
      topic: widget.topic,
      language: widget.language,
      gender: widget.gender,
    );

    _controller.addListener(_onControllerChanged);
    _controller.audioDeviceManager.addListener(_onAudioChanged);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _controller.initialize();
  }

  void _onControllerChanged() {
    if (!mounted) return;

    if (_controller.callState == UserCallState.ended) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.pop(context);
      });
    }

    setState(() {});
  }

  void _onAudioChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _controller.endCall();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.audioDeviceManager.removeListener(_onAudioChanged);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Avatar helper ──

  ImageProvider? _getAvatarImage(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return NetworkImage(url);
    }
    if (url.startsWith('assets/')) return AssetImage(url);
    return null;
  }

  // ── Audio route icon ──

  IconData _audioRouteIcon(UserAudioRoute route) {
    switch (route) {
      case UserAudioRoute.earpiece:
        return Icons.phone_in_talk;
      case UserAudioRoute.speaker:
        return Icons.volume_up;
      case UserAudioRoute.bluetooth:
        return Icons.bluetooth_audio;
      case UserAudioRoute.wiredHeadset:
        return Icons.headset;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color errorColor = Theme.of(context).colorScheme.error;
    const Color bgTop = Color(0xFF0A0E21);
    const Color bgBottom = Color(0xFF0D1B2A);

    final callState = _controller.callState;
    final isConnected = callState == UserCallState.connected;
    final isEnded = callState == UserCallState.ended;
    final audioMgr = _controller.audioDeviceManager;

    // Responsive sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;
    final brandFontSize = isSmallScreen ? 30.0 : (isMediumScreen ? 34.0 : 38.0);
    final avatarSize = isSmallScreen ? 80.0 : (isMediumScreen ? 90.0 : 100.0);
    final statusFontSize = isSmallScreen ? 16.0 : 18.0;
    final durationFontSize = isSmallScreen ? 20.0 : 22.0;
    final horizontalPadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);
    final topBarPadding = isSmallScreen ? 12.0 : 16.0;
    final chipFontSize = isSmallScreen ? 11.0 : 13.0;
    final chipPaddingH = isSmallScreen ? 14.0 : 18.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgTop, primary.withOpacity(0.06), bgBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──
              _buildTopBar(primary, audioMgr),

              const Spacer(flex: 3),

              // ── Brand Name ──
              _buildBrandName(primary, errorColor),

              const SizedBox(height: 14),

              // ── Status indicator ──
              _buildStatusIndicator(primary, callState),

              const Spacer(flex: 2),

              // ── Avatar row ──
              _buildAvatarRow(primary, isConnected),

              const Spacer(flex: 4),

              // ── Bottom action bar (always visible, always tappable) ──
              _buildActionBar(primary, isEnded, audioMgr),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar with audio device chip ──

  Widget _buildTopBar(Color primary, UserAudioDeviceManager audioMgr) {
    final route = audioMgr.currentRoute;
    final Color chipColor = _chipColorFor(route);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final topBarPadding = isSmallScreen ? 12.0 : 16.0;
    final chipPaddingH = isSmallScreen ? 14.0 : 18.0;
    final chipFontSize = isSmallScreen ? 11.0 : 13.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: topBarPadding, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => _controller.endCall(),
            ),
          ),
          const Spacer(),
          // Audio device chip — auto updates icon on device change
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: GestureDetector(
              key: ValueKey(route),
              onTap: () =>
                  UserAudioRouteBottomSheet.show(context, audioMgr),
              child: Container(
                padding:
                    EdgeInsets.symmetric(horizontal: chipPaddingH, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: chipColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_audioRouteIcon(route),
                        color: chipColor, size: isSmallScreen ? 16 : 18),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Flexible(
                      child: Text(
                        _chipTextFor(route),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: chipFontSize,
                          color: chipColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  String _chipTextFor(UserAudioRoute route) {
    switch (route) {
      case UserAudioRoute.bluetooth:
        return 'Bluetooth Connected';
      case UserAudioRoute.wiredHeadset:
        return 'Using Headphones';
      case UserAudioRoute.speaker:
        return 'Using Speaker';
      case UserAudioRoute.earpiece:
        return 'Earpiece';
    }
  }

  Color _chipColorFor(UserAudioRoute route) {
    switch (route) {
      case UserAudioRoute.bluetooth:
        return Colors.blueAccent;
      case UserAudioRoute.wiredHeadset:
        return Colors.greenAccent;
      case UserAudioRoute.speaker:
        return Colors.white70;
      case UserAudioRoute.earpiece:
        return Colors.white70;
    }
  }

  // ── Brand name ──

  Widget _buildBrandName(Color primary, Color errorColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;
    final brandFontSize = isSmallScreen ? 30.0 : (isMediumScreen ? 34.0 : 38.0);

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: brandFontSize,
          fontWeight: FontWeight.bold,
          fontFamily: 'Cursive',
        ),
        children: [
          TextSpan(
            text: 'Ca',
            style: TextStyle(color: primary, fontStyle: FontStyle.italic),
          ),
          const TextSpan(text: 'll', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'to', style: TextStyle(color: errorColor)),
        ],
      ),
    );
  }

  // ── Status indicator ──

  Widget _buildStatusIndicator(Color primary, UserCallState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _statusContent(primary, state),
    );
  }

  Widget _statusContent(Color primary, UserCallState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final statusFontSize = isSmallScreen ? 16.0 : 18.0;
    final durationFontSize = isSmallScreen ? 20.0 : 22.0;

    switch (state) {
      case UserCallState.calling:
      case UserCallState.connecting:
        final hasError = _controller.connectionError != null;
        return Row(
          key: const ValueKey('connecting'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasError)
              SizedBox(
                width: isSmallScreen ? 18 : 20,
                height: isSmallScreen ? 18 : 20,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  strokeWidth: 2.5,
                ),
              )
            else
              Icon(Icons.error_outline,
                  color: Theme.of(context).colorScheme.error, 
                  size: isSmallScreen ? 18 : 20),
            SizedBox(width: isSmallScreen ? 8 : 10),
            Flexible(
              child: Text(
                _controller.statusText,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: statusFontSize,
                  fontWeight: FontWeight.w600,
                  color: hasError
                      ? Theme.of(context).colorScheme.error
                      : Colors.greenAccent,
                ),
              ),
            ),
          ],
        );

      case UserCallState.connected:
        return Row(
          key: const ValueKey('connected'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isSmallScreen ? 8 : 10,
              height: isSmallScreen ? 8 : 10,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.5),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            SizedBox(width: isSmallScreen ? 8 : 10),
            Text(
              _controller.formattedDuration,
              style: TextStyle(
                fontSize: durationFontSize,
                fontWeight: FontWeight.w700,
                color: Colors.green,
                letterSpacing: 1,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );

      case UserCallState.ended:
        return const Text(
          key: ValueKey('ended'),
          'Call Ended',
          style: TextStyle(fontSize: 16, color: Colors.white54),
        );
    }
  }

  // ── Avatar row ──

  Widget _buildAvatarRow(Color primary, bool isConnected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;
    final horizontalPadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          // Left – Listener
          Expanded(child: _buildAvatarCard(
            widget.callerAvatar,
            widget.callerName,
            primary,
            isConnected,
          )),

          // Center – animated call icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildCallIconCenter(primary, isConnected),
          ),

          // Right – Current user
          Expanded(child: _buildAvatarCard(
            widget.userAvatar,
            widget.userName,
            primary,
            isConnected,
          )),
        ],
      ),
    );
  }

  Widget _buildAvatarCard(
      String? imageUrl, String name, Color primary, bool isConnected) {
    final avatarImage = _getAvatarImage(imageUrl);
    final Color borderColor =
        isConnected ? Colors.green.withOpacity(0.6) : primary.withOpacity(0.6);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;
    final avatarSize = isSmallScreen ? 80.0 : (isMediumScreen ? 90.0 : 100.0);
    final nameFontSize = isSmallScreen ? 14.0 : 16.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 3),
            boxShadow: [
              BoxShadow(
                color: borderColor.withOpacity(0.25),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: ClipOval(
            child: avatarImage != null
                ? Image(
                    image: avatarImage,
                    fit: BoxFit.cover,
                    width: avatarSize,
                    height: avatarSize,
                    errorBuilder: (_, __, ___) => _fallbackAvatar(),
                  )
                : _fallbackAvatar(),
          ),
        ),
        SizedBox(height: isSmallScreen ? 8 : 12),
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: nameFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFFB39DDB),
      child: const Icon(Icons.person, size: 50, color: Colors.white70),
    );
  }

  Widget _buildCallIconCenter(Color primary, bool isConnected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final iconSize = isSmallScreen ? 40.0 : 48.0;
    final phoneIconSize = isSmallScreen ? 20.0 : 24.0;

    if (isConnected) {
      return Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.green.withOpacity(0.15),
          border: Border.all(color: Colors.green.withOpacity(0.4), width: 2),
        ),
        child: Icon(Icons.phone, color: Colors.green, size: phoneIconSize),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(
          isSmallScreen ? 2 : 3,
          (i) => AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, _) => Icon(
              Icons.chevron_right,
              size: isSmallScreen ? 16 : 18,
              color: primary.withOpacity(
                0.25 + 0.75 * ((_pulseController.value + i * 0.25) % 1.0),
              ),
            ),
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulseSize = isSmallScreen ? 8.0 : 12.0;
                return Container(
                  width: iconSize + 4 + (pulseSize * _pulseController.value),
                  height: iconSize + 4 + (pulseSize * _pulseController.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary
                          .withOpacity(0.2 * (1 - _pulseController.value)),
                      width: 2,
                    ),
                  ),
                );
              },
            ),
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.15),
                border: Border.all(color: primary.withOpacity(0.4), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.phone, color: primary, size: phoneIconSize),
            ),
          ],
        ),
        ...List.generate(
          isSmallScreen ? 2 : 3,
          (i) => AnimatedBuilder(
            animation: _pulseController,
            builder: (ctx, _) => Icon(
              Icons.chevron_left,
              size: isSmallScreen ? 16 : 18,
              color: primary.withOpacity(
                0.25 + 0.75 * ((_pulseController.value + i * 0.25) % 1.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  ACTION BAR — always at bottom, always responsive
  // ══════════════════════════════════════════════════════════════

  Widget _buildActionBar(
      Color primary, bool isEnded, UserAudioDeviceManager audioMgr) {
    final isMuted = _controller.isMuted;
    final currentRoute = audioMgr.currentRoute;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final actionBarPadding = isSmallScreen ? 20.0 : 32.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: actionBarPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ── Mic toggle ──
          UserCallActionButton(
            icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: isMuted ? 'Unmute' : 'Mute',
            isActive: isMuted,
            activeColor: Colors.red.withOpacity(0.3),
            onTap: isEnded ? () {} : () => _controller.toggleMute(),
          ),

          // ── End call ──
          UserEndCallButton(
            onTap: isEnded ? () {} : () => _controller.endCall(),
          ),

          // ── Audio route selector (replaces old speaker toggle) ──
          UserCallActionButton(
            icon: _audioRouteIcon(currentRoute),
            label: audioMgr.routeLabel,
            isActive: currentRoute == UserAudioRoute.speaker,
            onTap: isEnded
                ? () {}
                : () => UserAudioRouteBottomSheet.show(context, audioMgr),
          ),
        ],
      ),
    );
  }
}
