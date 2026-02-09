import 'package:flutter/material.dart';
import 'dart:async';
import '../widgets/top_bar.dart';
import '../actions/calling.dart';
import '../../services/listener_service.dart';
import '../../services/socket_service.dart';
import '../../services/incoming_call_overlay_service.dart';
import '../../services/storage_service.dart';
import '../../services/call_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool isOnline = true; // Default to online, but will update from socket
  late AnimationController _pulseController;
  StreamSubscription<List<IncomingCall>>? _callsSubscription;
  StreamSubscription<Map<String, bool>>? _statusSub;
  StreamSubscription<bool>? _connectionSub; // Added: For connection state
  Timer? _heartbeatTimer; // Heartbeat timer
  final IncomingCallOverlayService _overlayService = IncomingCallOverlayService();
  final ListenerService _listenerService = ListenerService();
  List<IncomingCall> incomingCalls = [];
  String? _listenerUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (isOnline) { // Added: Start pulsing if online
      _pulseController.repeat(reverse: true);
    }
    _setupCallsListener();
    _startHeartbeat(); // Start heartbeat
    
    // CRITICAL: Ensure listener:join is emitted when home screen loads
    // This marks listener as online in backend's listenerSockets map
    SocketService().setListenerOnline(true);
    
    _listenerUserId = null;
    // Get listenerUserId once
    StorageService().getUserId().then((id) {
      if (!mounted) return;
      setState(() { _listenerUserId = id; });
      // --- FIX: Listen for real-time status, no default offline ---
      _statusSub = SocketService().listenerStatusStream.listen((map) {
        if (_listenerUserId != null && map.containsKey(_listenerUserId)) {
          final newOnline = map[_listenerUserId!]!;
          if (isOnline != newOnline && mounted) {
            setState(() {
              isOnline = newOnline;
            });
            if (isOnline) {
              _pulseController.repeat(reverse: true);
            } else {
              _pulseController.stop();
            }
            print('[LIFECYCLE] listenerStatusStream: ${_listenerUserId!} online=$newOnline');
          }
        }
      });
      _connectionSub = SocketService().onConnectionStateChange.listen((connected) {
        if (!connected && mounted) {
          setState(() => isOnline = false);
          _pulseController.stop();
        }
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // NOTE: Main lifecycle handling is done in main.dart at app-level
    // This is kept for home-screen specific UI updates only
    if (_listenerUserId == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        // Re-emit listener:join to ensure online status after resume
        SocketService().emitListenerOnline();
        // Restart heartbeat
        _startHeartbeat();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // NOTE: Don't emit offline here - handled in main.dart
        // Listener stays online in background to receive calls
        _heartbeatTimer?.cancel();
        break;
      default:
        break;
    }
  }

  void _setupCallsListener() {
    incomingCalls = List.from(_overlayService.incomingCalls);
    _callsSubscription = _overlayService.onCallsUpdated.listen((calls) {
      if (!mounted) return;
      if (!isOnline) return;
      setState(() {
        incomingCalls = List.from(calls);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _callsSubscription?.cancel();
    _statusSub?.cancel();
    _connectionSub?.cancel(); // Added: Cancel connection subscription
    _heartbeatTimer?.cancel(); // Cancel heartbeat
    super.dispose();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Send heartbeat every 20 seconds (backend interval is 30s)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      if (isOnline) {
        await _listenerService.sendHeartbeat();
      }
    });
    // Send initial heartbeat
    _listenerService.sendHeartbeat();
  }

  // Toggle logic removed

  void _viewCallerProfile(IncomingCall call) {
    // Show caller profile in a bottom sheet
    final avatarImage = _getAvatarImage(call.callerAvatar);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.blue.withOpacity(0.2),
              backgroundImage: avatarImage,
              child: avatarImage == null
                  ? const Icon(Icons.person, size: 50, color: Colors.blue)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              call.callerName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Topic: ${call.topic ?? 'General'}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Language: ${call.language ?? 'English'}',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Helper to get avatar image from URL (handles both assets and network URLs)
  ImageProvider? _getAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')) {
      return NetworkImage(avatarUrl);
    }
    if (avatarUrl.startsWith('assets/')) {
      return AssetImage(avatarUrl);
    }
    // Handle other formats if needed
    return null;
  }

  void _acceptCall(IncomingCall call) async {
    // Navigate to Calling screen with call details
    if (!mounted) return;
    
    try {
      // Remove from incoming calls list
      _overlayService.removeCallFromList(call.callId);

      // ── FIX: Navigate IMMEDIATELY to prevent the 1-second flicker ──
      // Previously, `await callService.updateCallStatus(...)` ran BEFORE
      // navigation, so the home screen was visible for ~1 s between
      // tapping Accept and seeing the Calling screen. Now we navigate
      // first and fire the API call + socket emit in the background.
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Calling(
            callerName: call.callerName,
            callerAvatar: call.callerAvatar,
            channelName: call.callId,
            callId: call.callId,
            callerId: call.callerId,
          ),
        ),
      );

      // Fire-and-forget: update backend status + notify peer
      SocketService().acceptCall(
        callId: call.callId,
        callerId: call.callerId,
      );
      CallService().updateCallStatus(
        callId: call.callId,
        status: 'ongoing',
      );
    } catch (e) {
      print('Error accepting call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _rejectCall(IncomingCall call) {
    // Use overlay service to handle reject
    _overlayService.rejectCallFromList(call);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Call declined'),
        backgroundColor: Colors.red.shade400,
      ),
    );
  }

  // Heartbeat logic removed
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isOnline
                    ? const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                      )
                    : LinearGradient(
                        colors: [Colors.grey, Colors.grey],
                      ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isOnline ? Colors.green : Colors.grey)
                        .withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 16 + (_pulseController.value * 8),
                        height: 16 + (_pulseController.value * 8),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                          boxShadow: isOnline
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : [],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12), // Added: Space for text
                  Text(
                    isOnline ? 'Online' : 'Offline', // Added: Status text
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !isOnline
                  ? _buildOfflineView()
                  : incomingCalls.isEmpty
                      ? _buildNoCallsView()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: incomingCalls.length,
                          itemBuilder: (_, i) =>
                              _buildIncomingCallCard(incomingCalls[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomingCallCard(IncomingCall call) {
    final minutes = call.waitTimeSeconds ~/ 60;
    final seconds = call.waitTimeSeconds % 60;
    final waitTimeStr = minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? Colors.green : Colors.grey,
        ),
        boxShadow: [
          BoxShadow(
            color: isOnline ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            leading: GestureDetector(
              onTap: () => _viewCallerProfile(call),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isOnline ? Colors.blue.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                    backgroundImage: _getAvatarImage(call.callerAvatar),
                    child: _getAvatarImage(call.callerAvatar) == null
                        ? Icon(Icons.person, size: 28, color: isOnline ? Colors.blue : Colors.grey)
                        : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.visibility,
                          size: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            title: Text(
              call.callerName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(call.topic ?? 'General'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  call.language ?? 'English',
                  style: TextStyle(
                    color: isOnline ? Colors.pinkAccent : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  waitTimeStr,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: isOnline ? () => _rejectCall(call) : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Listener is offline'), backgroundColor: Colors.grey),
                        );
                      },
                      icon: Icon(Icons.call_end, color: Colors.red, size: 20),
                      label: const Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: isOnline ? () => _acceptCall(call) : () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Listener is offline'), backgroundColor: Colors.grey),
                        );
                      },
                      icon: Icon(Icons.call, size: 20),
                      label: const Text(
                        'Ans Call',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        elevation: 2,
                      ),
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

  Widget _buildNoCallsView() => const Center(
        child: Text(
          'Waiting for calls...',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF880E4F),
          ),
        ),
      );

  Widget _buildOfflineView() => const Center(
        child: Text(
          'You are Offline',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF880E4F),
          ),
        ),
      );
}