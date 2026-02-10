import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'socket_service.dart';
import 'call_service.dart';
import '../listener/actions/calling.dart';

/// Global service to show incoming call overlay anywhere in the app
class IncomingCallOverlayService {
  static final IncomingCallOverlayService _instance = IncomingCallOverlayService._internal();
  factory IncomingCallOverlayService() => _instance;
  IncomingCallOverlayService._internal();

  final SocketService _socketService = SocketService();
  StreamSubscription<IncomingCall>? _subscription;
  StreamSubscription<Map<String, dynamic>>? _callEndedSubscription;
  OverlayEntry? _overlayEntry;
  BuildContext? _context;
  bool _isInitialized = false;
  
  // ── Ringtone ──
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  bool _isRinging = false;
  
  // ── Active call flag ──
  /// True when the listener is already on an active call.
  /// New incoming calls are silently rejected while this is true.
  bool _isInActiveCall = false;
  
  // Track incoming calls for the list view
  final List<IncomingCall> _incomingCalls = [];
  final StreamController<List<IncomingCall>> _callsController = 
      StreamController<List<IncomingCall>>.broadcast();
  
  // Stream to notify when a call is handled (accepted/rejected) from home screen
  // This allows main.dart to close its dialog when call is handled elsewhere
  final StreamController<String> _callHandledController = 
      StreamController<String>.broadcast();
  
  /// Stream of incoming calls list for UI
  Stream<List<IncomingCall>> get onCallsUpdated => _callsController.stream;
  
  /// Stream that emits callId when a call is handled (from home screen list)
  Stream<String> get onCallHandled => _callHandledController.stream;
  
  /// Get current incoming calls
  List<IncomingCall> get incomingCalls => List.unmodifiable(_incomingCalls);

  /// Initialize the overlay service with a context
  /// Also connects socket if not already connected
  Future<void> initialize(BuildContext context) async {
    if (_isInitialized) {
      // Just update context
      _context = context;
      return;
    }
    
    _context = context;
    _isInitialized = true;
    
    // Connect socket first
    final connected = await _socketService.connect();
    if (!connected) {
      print('IncomingCallOverlayService: Failed to connect socket');
      _isInitialized = false;
      return;
    }
    
    // Subscribe to incoming calls
    _subscription = _socketService.onIncomingCall.listen((call) {
      print('IncomingCallOverlayService: Received call from ${call.callerName}');
      _handleIncomingCall(call);
    });

    // Subscribe to call:ended — if caller cancels before answer, remove from queue
    _callEndedSubscription = _socketService.onCallEnded.listen((data) {
      final callId = data['callId']?.toString();
      final reason = data['reason']?.toString() ?? '';
      if (callId != null && callId.isNotEmpty) {
        _handleCallerCancelled(callId, reason);
      }
    });
    
    print('IncomingCallOverlayService initialized');
  }
  
  void _handleIncomingCall(IncomingCall call) {
    // If listener is already on an active call, silently reject
    if (_isInActiveCall) {
      print('IncomingCallOverlayService: Ignoring incoming call ${call.callId} — already in active call');
      // Auto-reject so the caller gets immediate feedback
      _socketService.rejectCall(
        callId: call.callId,
        callerId: call.callerId,
      );
      CallService().updateCallStatus(
        callId: call.callId,
        status: 'missed',
      );
      return;
    }
    
    if (!_incomingCalls.any((c) => c.callId == call.callId)) {
      _incomingCalls.add(call);
      _callsController.add(List.from(_incomingCalls));
      print('IncomingCallOverlayService: Added call ${call.callId} to list (${_incomingCalls.length} active)');
      
      // Start ringtone when first incoming call arrives
      _startRingtone();
    }
  }

  /// Called when we receive a call:ended socket event.
  /// If the callId matches a pending incoming call, remove it (caller cancelled).
  void _handleCallerCancelled(String callId, String reason) {
    final hadCall = _incomingCalls.any((c) => c.callId == callId);
    if (!hadCall) return; // Not a pending incoming call we're tracking

    print('IncomingCallOverlayService: Caller cancelled call $callId (reason: $reason) — removing from queue');

    _incomingCalls.removeWhere((c) => c.callId == callId);
    _callsController.add(List.from(_incomingCalls));
    _stopRingtoneIfEmpty();
    _removeOverlay();

    // Notify main.dart to close its dialog if showing this call
    _callHandledController.add(callId);
  }

  // ── Ringtone ──

  /// Play sample.mp3 in a loop until accept/reject/timeout
  Future<void> _startRingtone() async {
    if (_isRinging) return; // already playing
    _isRinging = true;
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('voice/sample.mp3'));
      print('IncomingCallOverlayService: Ringtone started');
    } catch (e) {
      print('IncomingCallOverlayService: Ringtone error: $e');
      _isRinging = false;
    }
  }

  /// Stop ringtone (only when no pending incoming calls remain)
  void _stopRingtoneIfEmpty() {
    if (_incomingCalls.isEmpty) {
      _stopRingtone();
    }
  }

  /// Force-stop ringtone immediately
  void _stopRingtone() {
    if (!_isRinging) return;
    _isRinging = false;
    try {
      _ringtonePlayer.stop();
      print('IncomingCallOverlayService: Ringtone stopped');
    } catch (_) {}
  }

  /// Call this when listener goes offline to clear overlays and calls
  void forceOfflineCleanup() {
    _removeOverlay();
    _stopRingtone();
    _isInActiveCall = false;
    _incomingCalls.clear();
    _callsController.add(List.from(_incomingCalls));
  }
  
  /// Update context (call when navigating)
  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Dispose the service - but keep socket connected for singleton reuse
  void dispose() {
    // Don't cancel subscription or disconnect socket for singleton
    // Just remove overlay and clear context
    _removeOverlay();
    _context = null;
    // Don't set _isInitialized = false since we want to reuse
  }
  
  /// Full cleanup - only call on app shutdown
  void fullDispose() {
    _subscription?.cancel();
    _subscription = null;
    _callEndedSubscription?.cancel();
    _callEndedSubscription = null;
    _removeOverlay();
    _stopRingtone();
    _ringtonePlayer.dispose();
    _isInActiveCall = false;
    _incomingCalls.clear();
    _isInitialized = false;
    _context = null;
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _acceptCall(IncomingCall call) async {
    _removeOverlay();
    _isInActiveCall = true;
    
    // Remove from list
    _incomingCalls.removeWhere((c) => c.callId == call.callId);
    _callsController.add(List.from(_incomingCalls));
    _stopRingtoneIfEmpty();

    // ── FIX: Navigate IMMEDIATELY to prevent the 1-second flicker ──
    // Previously, `await callService.updateCallStatus(...)` ran BEFORE
    // navigation, so the underlying page was visible for ~1 s between
    // overlay removal and Calling screen push. Now we navigate first
    // and fire the API call + socket emit in the background.
    if (_context != null) {
      Navigator.of(_context!).push(
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
    }

    // Fire-and-forget: update backend status + notify peer
    _socketService.acceptCall(
      callId: call.callId,
      callerId: call.callerId,
    );
    CallService().updateCallStatus(
      callId: call.callId,
      status: 'ongoing',
    );
  }

  void _rejectCall(IncomingCall call) async {
    _removeOverlay();
    
    // Remove from list
    _incomingCalls.removeWhere((c) => c.callId == call.callId);
    _callsController.add(List.from(_incomingCalls));
    _stopRingtoneIfEmpty();

    // Update call status to rejected
    final callService = CallService();
    await callService.updateCallStatus(
      callId: call.callId,
      status: 'rejected',
    );

    // Notify socket that call is rejected
    _socketService.rejectCall(
      callId: call.callId,
      callerId: call.callerId,
    );
  }
  
  /// Accept call from list view (not overlay)
  /// Notifies main.dart to close its dialog via onCallHandled stream
  void acceptCallFromList(IncomingCall call) {
    // Notify main.dart to close its dialog BEFORE accepting
    _callHandledController.add(call.callId);
    _acceptCall(call);
  }
  
  /// Reject call from list view (not overlay)
  /// Notifies main.dart to close its dialog via onCallHandled stream
  void rejectCallFromList(IncomingCall call) {
    // Notify main.dart to close its dialog BEFORE rejecting
    _callHandledController.add(call.callId);
    _rejectCall(call);
  }
  
  /// Remove call from list by ID (used when handling accept/reject directly)
  void removeCallFromList(String callId) {
    _incomingCalls.removeWhere((c) => c.callId == callId);
    _callsController.add(List.from(_incomingCalls));
    _stopRingtoneIfEmpty();
    // Also notify main.dart
    _callHandledController.add(callId);
  }

  /// Call this when the active call ends so the listener can receive new calls.
  void clearActiveCall() {
    _isInActiveCall = false;
    print('IncomingCallOverlayService: Active call cleared — ready for new calls');
  }
}

/// Incoming call overlay widget
class _IncomingCallOverlayWidget extends StatefulWidget {
  final IncomingCall call;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingCallOverlayWidget({
    required this.call,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_IncomingCallOverlayWidget> createState() => _IncomingCallOverlayWidgetState();
}

class _IncomingCallOverlayWidgetState extends State<_IncomingCallOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _slideAnimation;
  Timer? _autoDeclineTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(begin: -200, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();

    // Auto-decline after 30 seconds
    _autoDeclineTimer = Timer(const Duration(seconds: 30), () {
      widget.onReject();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _autoDeclineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          );
        },
        child: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xFFFF4081).withOpacity(0.2),
                      backgroundImage: widget.call.callerAvatar != null &&
                              widget.call.callerAvatar!.startsWith('http')
                          ? NetworkImage(widget.call.callerAvatar!)
                          : null,
                      child: widget.call.callerAvatar == null ||
                              !widget.call.callerAvatar!.startsWith('http')
                          ? const Icon(Icons.person, size: 30, color: Color(0xFFFF4081))
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.call.callerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Incoming Call • ${widget.call.topic ?? 'General'}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Reject button
                    GestureDetector(
                      onTap: widget.onReject,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    // Accept button
                    GestureDetector(
                      onTap: widget.onAccept,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call,
                          color: Colors.white,
                          size: 28,
                        ),
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
