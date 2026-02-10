import 'package:flutter/material.dart';
import 'call_controller.dart';
import 'audio_device_manager.dart';
import 'call_action_button.dart';
import 'audio_route_bottom_sheet.dart';

/// ──────────────────────────────────────────────────────────────────
/// Listener-side calling screen — professional mobile call UI.
///
/// ── FLICKER FIX ──
/// Root cause: all three accept-call paths (main.dart dialog,
/// home_screen list, incoming_call_overlay) ran
///   `await callService.updateCallStatus(...)` BEFORE navigating
///   to this screen. The ~1 s network round-trip left the home
///   screen visible between the dialog dismiss and the Calling
///   push, creating the "hide then reopen" flicker.
///
/// Fix: navigation now happens IMMEDIATELY on accept (before any
/// async API call). The API update and socket emit are
/// fire-and-forget, running after the Calling screen is already
/// on screen. Additionally:
///  • isAccepted=true starts state at CallState.connecting
///    (never shows "Calling…" flash).
///  • Forward-only state machine prevents backward transitions.
///  • Single subscription per socket event — no duplicates.
///
/// ── UI ──
/// Matches the user-side calling.dart layout:
///  • Gradient background, top bar with audio device chip
///  • "Callto" brand name, AnimatedSwitcher status indicator
///  • Dual-avatar row (caller + listener)
///  • Material 3 action buttons with ripple
/// ──────────────────────────────────────────────────────────────────
class Calling extends StatefulWidget {
  final String? callerName;
  final String? callerAvatar;
  final String? channelName;
  final String? callId;
  final String? callerId;

  /// When true, the controller starts in [CallState.connecting]
  /// instead of [CallState.calling] — no "Calling…" flash.
  final bool isAccepted;

  const Calling({
    super.key,
    this.callerName,
    this.callerAvatar,
    this.channelName,
    this.callId,
    this.callerId,
    this.isAccepted = true,
  });

  @override
  State<Calling> createState() => _CallingState();
}

class _CallingState extends State<Calling>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late final CallController _controller;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = CallController(
      callerName: widget.callerName,
      callerAvatar: widget.callerAvatar,
      channelName: widget.channelName,
      callId: widget.callId,
      callerId: widget.callerId,
      isAccepted: widget.isAccepted,
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

    if (_controller.callState == CallState.ended) {
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
    // if (url.startsWith('http')) return NetworkImage(url);
    if (url.startsWith('assets/')) return AssetImage(url);
    return null;
  }

  // ── Audio route icon ──

  IconData _audioRouteIcon(AudioRoute route) {
    switch (route) {
      case AudioRoute.earpiece:
        return Icons.phone_in_talk;
      case AudioRoute.speaker:
        return Icons.volume_up;
      case AudioRoute.bluetooth:
        return Icons.bluetooth_audio;
      case AudioRoute.wiredHeadset:
        return Icons.headset;
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD — matches user-side calling.dart layout
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color errorColor = Theme.of(context).colorScheme.error;
    const Color bgTop = Color(0xFF0A0E21);
    const Color bgBottom = Color(0xFF0D1B2A);

    final callState = _controller.callState;
    final isConnected = callState == CallState.connected;
    final isEnded = callState == CallState.ended;
    final audioMgr = _controller.audioDeviceManager;

    // Responsive sizing based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;

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
              // ── Top bar with audio device chip ──
              _buildTopBar(primary, audioMgr),

              const Spacer(flex: 3),

              // ── Brand Name ──
              _buildBrandName(primary, errorColor),

              const SizedBox(height: 14),

              // ── Status indicator ──
              _buildStatusIndicator(primary, callState),

              const Spacer(flex: 2),

              // ── Avatar row (caller + listener) ──
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

  Widget _buildTopBar(Color primary, AudioDeviceManager audioMgr) {
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
          // Audio device chip — auto-updates on device change
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: GestureDetector(
              key: ValueKey(route),
              onTap: () => AudioRouteBottomSheet.show(context, audioMgr),
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

  String _chipTextFor(AudioRoute route) {
    switch (route) {
      case AudioRoute.bluetooth:
        return 'Bluetooth Connected';
      case AudioRoute.wiredHeadset:
        return 'Using Headphones';
      case AudioRoute.speaker:
        return 'Using Speaker';
      case AudioRoute.earpiece:
        return 'Earpiece';
    }
  }

  Color _chipColorFor(AudioRoute route) {
    switch (route) {
      case AudioRoute.bluetooth:
        return Colors.blueAccent;
      case AudioRoute.wiredHeadset:
        return Colors.greenAccent;
      case AudioRoute.speaker:
        return Colors.white70;
      case AudioRoute.earpiece:
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

  Widget _buildStatusIndicator(Color primary, CallState state) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _statusContent(primary, state),
    );
  }

  Widget _statusContent(Color primary, CallState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final statusFontSize = isSmallScreen ? 16.0 : 18.0;
    final durationFontSize = isSmallScreen ? 20.0 : 22.0;

    switch (state) {
      case CallState.calling:
      case CallState.connecting:
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
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.greenAccent),
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

      case CallState.connected:
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

      case CallState.ended:
        return const Text(
          key: ValueKey('ended'),
          'Call Ended',
          style: TextStyle(fontSize: 16, color: Colors.white54),
        );
    }
  }

  // ── Avatar row (caller + listener) ──

  Widget _buildAvatarRow(Color primary, bool isConnected) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;
    final horizontalPadding = isSmallScreen ? 12.0 : (isMediumScreen ? 16.0 : 20.0);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          // Left – Caller (the user who made the call)
          Expanded(
            child: _buildAvatarCard(
              widget.callerAvatar,
              widget.callerName ?? 'Caller',
              primary,
              isConnected,
            ),
          ),

          // Center – animated call icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildCallIconCenter(primary, isConnected),
          ),

          // Right – Listener (you)
          Expanded(
            child: _buildAvatarCard(
              null,
              'You',
              primary,
              isConnected,
            ),
          ),
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
                    errorBuilder: (_, __, ___) => _fallbackAvatar(avatarSize),
                  )
                : _fallbackAvatar(avatarSize),
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

  Widget _fallbackAvatar([double size = 100]) {
    final iconSize = size * 0.5;
    return Container(
      width: size,
      height: size,
      color: const Color(0xFFB39DDB),
      child: Icon(Icons.person, size: iconSize, color: Colors.white70),
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
      Color primary, bool isEnded, AudioDeviceManager audioMgr) {
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
          CallActionButton(
            icon: isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            label: isMuted ? 'Unmute' : 'Mute',
            isActive: isMuted,
            activeColor: Colors.red.withOpacity(0.3),
            onTap: isEnded ? () {} : () => _controller.toggleMute(),
          ),

          // ── End call ──
          EndCallButton(
            onTap: isEnded ? () {} : () => _controller.endCall(),
          ),

          // ── Audio route selector ──
          CallActionButton(
            icon: _audioRouteIcon(currentRoute),
            label: audioMgr.routeLabel,
            isActive: currentRoute == AudioRoute.speaker,
            onTap: isEnded
                ? () {}
                : () => AudioRouteBottomSheet.show(context, audioMgr),
          ),
        ],
      ),
    );
  }
}
