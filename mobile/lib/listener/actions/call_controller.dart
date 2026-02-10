import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart' hide AudioDeviceManager, AudioRoute;
import 'package:permission_handler/permission_handler.dart';

import '../../services/agora_service.dart';
import '../../services/agora_api.dart';
import '../../services/socket_service.dart';
import '../../services/call_service.dart';
import '../../services/incoming_call_overlay_service.dart';
import 'audio_device_manager.dart';

/// Single source of truth for call state.
/// UI renders strictly based on this enum — no multi-flag toggling.
enum CallState { calling, connecting, connected, ended }

/// Controller that owns all call logic, streams, and lifecycle.
/// Widget only listens and renders — zero business logic in the UI.
class CallController extends ChangeNotifier {
  // ── Constructor params ──
  final String? callerName;
  final String? callerAvatar;
  final String? channelName;
  final String? callId;
  final String? callerId;

  /// When [isAccepted] is true the listener already accepted the incoming
  /// call, so the controller starts in [CallState.connecting] immediately
  /// (skipping the "Calling…" state and its connecting sound).
  final bool isAccepted;

  CallController({
    this.callerName,
    this.callerAvatar,
    this.channelName,
    this.callId,
    this.callerId,
    this.isAccepted = false,
  });

  // ── Services (singletons) ──
  final AgoraService _agoraService = AgoraService();
  final SocketService _socketService = SocketService();
  final CallService _callService = CallService();

  // ── Audio ──
  late final AudioPlayer _audioPlayer = AudioPlayer();
  late final AudioDeviceManager audioDeviceManager =
      AudioDeviceManager(agoraService: _agoraService);

  // ── Subscriptions (cancel in dispose) ──
  StreamSubscription? _callConnectedSub;
  StreamSubscription? _callEndedSub;

  // ── State ── (initial value set in constructor body via isAccepted)
  late CallState _callState;
  CallState get callState => _callState;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  int _callDuration = 0;
  int get callDuration => _callDuration;

  String? _connectionError;
  String? get connectionError => _connectionError;

  String? _resolvedChannel;

  Timer? _callTimer;
  bool _disposed = false;

  // Initialize _callState based on whether call was already accepted
  // (delayed init because 'isAccepted' is a final field set in constructor)
  CallState _resolveInitialState() =>
      isAccepted ? CallState.connecting : CallState.calling;

  // ── Public helpers ──
  String get formattedDuration {
    final mins = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDuration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get statusText {
    switch (_callState) {
      case CallState.calling:
        return 'Calling…';
      case CallState.connecting:
        return 'Connecting…';
      case CallState.connected:
        return formattedDuration;
      case CallState.ended:
        return 'Call Ended';
    }
  }

  // ── Lifecycle ──

  /// Call once from initState. Sets up listeners, audio, Agora.
  Future<void> initialize() async {
    _callState = _resolveInitialState();
    _setupSocketListeners();
    // Only play connecting beep if the call hasn't been accepted yet
    if (!isAccepted) {
      _playConnectingSound();
    }
    await _initAgora();
  }

  // ── Socket listeners (single subscription each) ──

  void _setupSocketListeners() {
    _callConnectedSub = _socketService.onCallConnected.listen((data) {
      debugPrint('CallController: socket call:connected received');
      _transitionTo(CallState.connected);
    });

    _callEndedSub = _socketService.onCallEnded.listen((data) {
      debugPrint('CallController: socket call:ended – ${data['reason'] ?? 'unknown'}');
      endCall();
    });
  }

  // ── Internal state machine ──

  /// Moves to a new state only if the transition is valid.
  /// Prevents backward transitions and duplicate updates.
  void _transitionTo(CallState next) {
    if (_disposed) return;
    if (_callState == next) return;
    // Only forward transitions allowed (calling→connecting→connected→ended)
    if (next.index <= _callState.index && next != CallState.ended) return;

    debugPrint('CallController: $_callState → $next');
    _callState = next;

    if (next == CallState.connected) {
      _stopAudio();
      _startCallTimer();
    } else if (next == CallState.ended) {
      _stopAudio();
      _callTimer?.cancel();
    }

    notifyListeners();
  }

  // ── Audio ──

  Future<void> _playConnectingSound() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      await _audioPlayer.play(AssetSource('voice/sample.mp3'));
      // Stop after 2 s — just a notification beep, not a ringtone
      Future.delayed(const Duration(seconds: 2), () {
        if (!_disposed && _callState != CallState.connected) {
          _audioPlayer.stop();
        }
      });
    } catch (e) {
      debugPrint('CallController: audio play error: $e');
    }
  }

  void _stopAudio() {
    try {
      _audioPlayer.stop();
    } catch (_) {}
  }

  // ── Agora init + join ──

  Future<void> _initAgora() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _setError('Microphone permission denied');
      return;
    }

    final channel = channelName ?? callId ?? 'call_${DateTime.now().millisecondsSinceEpoch}';
    debugPrint('CallController: joining channel $channel');

    // Fetch token
    final tokenResult = await _agoraService.fetchToken(channelName: channel);
    if (!tokenResult.success || tokenResult.token == null) {
      _setError(tokenResult.error ?? 'Failed to get call token');
      _scheduleAutoClose();
      return;
    }

    // Init engine
    final initialized = await _agoraService.initEngine(appId: AgoraConfig.appId);
    if (!initialized) {
      _setError('Failed to initialize call engine');
      return;
    }

    // Register Agora event handler
    _agoraService.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('CallController: joined channel ${connection.channelId}');
        _stopAudio();
        _transitionTo(CallState.connecting);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        debugPrint('CallController: remote user joined $remoteUid');
        _transitionTo(CallState.connected);
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('CallController: remote user left $remoteUid');
        endCall();
      },
      onError: (err, msg) {
        debugPrint('CallController: Agora error $err – $msg');
        if (_callState != CallState.connected && !_disposed) {
          _setError('Call error: $msg');
        }
      },
      onConnectionStateChanged: (connection, state, reason) {
        debugPrint('CallController: conn state $state reason $reason');
        if (state == ConnectionStateType.connectionStateFailed) {
          String errorMsg = 'Connection failed';
          if (reason == ConnectionChangedReasonType.connectionChangedTokenExpired) {
            errorMsg = 'Call session expired. Please try again.';
          } else if (reason == ConnectionChangedReasonType.connectionChangedRejectedByServer) {
            errorMsg = 'Connection rejected. Please try again.';
          } else if (reason == ConnectionChangedReasonType.connectionChangedInvalidToken) {
            errorMsg = 'Invalid call token. Please try again.';
          }
          _setError(errorMsg);
          endCall();
        }
      },
      onAudioRoutingChanged: (routing) {
        // Forward to AudioDeviceManager for icon updates
        audioDeviceManager.onAudioRoutingChanged(routing);
      },
    ));

    // Join channel
    final joined = await _agoraService.joinChannel(
      token: tokenResult.token!,
      channelName: channel,
      uid: tokenResult.uid ?? 0,
    );

    if (!joined) {
      _setError('Failed to join call');
      _scheduleAutoClose();
    } else {
      _resolvedChannel = channel;
      _socketService.joinedChannel(
        callId: callId ?? channel,
        channelName: channel,
      );
    }
  }

  // ── User actions ──

  void toggleMute() {
    if (_disposed) return;
    _isMuted = !_isMuted;
    _agoraService.muteLocalAudio(_isMuted);
    notifyListeners();
  }

  void selectAudioRoute(AudioRoute route) {
    audioDeviceManager.selectRoute(route);
  }

  /// End the call. Safe to call multiple times — no-ops after first.
  Future<void> endCall() async {
    if (_callState == CallState.ended) return;

    // Capture state before transitioning
    final wasConnected = _callState == CallState.connected;
    final durationSnapshot = _callDuration;

    // 1. Stop timer & audio IMMEDIATELY
    _callTimer?.cancel();
    _callTimer = null;
    _stopAudio();
    _transitionTo(CallState.ended);

    // 2. Disconnect Agora FIRST — stops audio instantly for both sides
    debugPrint('[CALL-L] Disconnecting Agora engine');
    await _agoraService.reset();

    // 3. Notify peer via socket IMMEDIATELY
    if (callerId != null && _resolvedChannel != null) {
      _socketService.endCall(
        callId: callId ?? _resolvedChannel!,
        otherUserId: callerId!,
      );
    }
    if (_resolvedChannel != null) {
      _socketService.leftChannel(channelName: _resolvedChannel!);
    }

    // 4. Update backend (billing / status) — can happen after disconnect
    debugPrint('[CALL-L] Updating backend');
    final cid = callId ?? _resolvedChannel;
    if (cid != null) {
      try {
        final status = wasConnected || durationSnapshot > 0
            ? 'completed'
            : 'cancelled';
        if (status == 'completed') {
          await _callService.endCall(
            callId: cid,
            durationSeconds: durationSnapshot,
          );
        } else {
          await _callService.updateCallStatus(
            callId: cid,
            status: status,
            durationSeconds: durationSnapshot > 0 ? durationSnapshot : null,
          );
        }
      } catch (e) {
        debugPrint('[CALL-L] Backend update error: $e');
      }
    }
    debugPrint('[CALL-L] Cleanup done');

    // 5. Clear active call flag so listener can receive new incoming calls
    IncomingCallOverlayService().clearActiveCall();
  }

  // ── Internals ──

  void _startCallTimer() {
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      _callDuration++;
      notifyListeners();
    });
  }

  void _setError(String msg) {
    if (_disposed) return;
    _connectionError = msg;
    _stopAudio();
    notifyListeners();
  }

  void _scheduleAutoClose() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!_disposed) endCall();
    });
  }

  // ── Dispose ──

  @override
  void dispose() {
    _disposed = true;
    _callConnectedSub?.cancel();
    _callEndedSub?.cancel();
    _callTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    audioDeviceManager.dispose();
    if (_resolvedChannel != null) {
      _socketService.leftChannel(channelName: _resolvedChannel!);
    }
    // Don't call _agoraService.dispose() here — it's a singleton
    // and reset() was already called in endCall()
    super.dispose();
  }
}
