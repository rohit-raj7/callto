import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/agora_service.dart';
import '../../services/agora_api.dart';
import '../../services/socket_service.dart';
import '../../services/call_service.dart';
import 'audio_device_manager.dart';

/// Single source of truth for call state on the USER side.
/// UI renders strictly based on this enum — no multi-flag toggling.
enum UserCallState { calling, connecting, connected, ended }

/// Controller that owns all call logic for the user-side calling screen.
/// Widget only listens and renders — zero business logic in the UI.
class UserCallController extends ChangeNotifier {
  // ── Constructor params ──
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

  UserCallController({
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

  // ── Services (singletons) ──
  final AgoraService _agoraService = AgoraService();
  final SocketService _socketService = SocketService();
  final CallService _callService = CallService();

  // ── Audio ──
  late final AudioPlayer _audioPlayer = AudioPlayer();
  late final UserAudioDeviceManager audioDeviceManager =
      UserAudioDeviceManager(agoraService: _agoraService);

  // ── Subscriptions (cancel in dispose) ──
  StreamSubscription? _callConnectedSub;
  StreamSubscription? _callEndedSub;
  StreamSubscription? _callRejectedSub;

  // ── State ──
  UserCallState _callState = UserCallState.calling;
  UserCallState get callState => _callState;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  int _callDuration = 0;
  int get callDuration => _callDuration;

  String? _connectionError;
  String? get connectionError => _connectionError;

  String? _currentChannelName;
  String? _callId;

  String? get callId => _callId ?? _currentChannelName;

  Timer? _callTimer;
  Timer? _noAnswerTimer;
  bool _disposed = false;

  CallBillingSummary? _billingSummary;
  CallBillingSummary? get billingSummary => _billingSummary;

  // ── Public helpers ──
  String get formattedDuration {
    final mins = (_callDuration ~/ 60).toString().padLeft(2, '0');
    final secs = (_callDuration % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }


  String get statusText {
    if (_connectionError != null) return _connectionError!;
    switch (_callState) {
      case UserCallState.calling:
        return 'Calling…';
      case UserCallState.connecting:
        return 'Connecting…';
      case UserCallState.connected:
        return formattedDuration;
      case UserCallState.ended:
        return 'Call Ended';
    }
  }

  // ── Lifecycle ──

  /// Call once from initState.
  Future<void> initialize() async {
    _setupSocketListeners();
    await _playRingtone();

    if (channelName != null) {
      // Backward compatibility: channel already created
      _callId = channelName;
      await _initAgora();
    } else {
      await _initiateCallAndConnect();
    }
  }

  // ── Socket listeners (single subscription each) ──

  void _setupSocketListeners() {
    _callConnectedSub = _socketService.onCallConnected.listen((data) {
      debugPrint('UserCallController: socket call:connected received');
      _transitionTo(UserCallState.connected);
    });

    _callEndedSub = _socketService.onCallEnded.listen((data) {
      debugPrint('UserCallController: socket call:ended – ${data['reason'] ?? 'unknown'}');
      if (data['code'] == 'LISTENER_OFFLINE') {
        _setError(data['error'] ?? 'Listener is offline');
        Future.delayed(const Duration(seconds: 2), () {
          if (!_disposed) endCall();
        });
      } else {
        endCall();
      }
    });

    _callRejectedSub = _socketService.onCallRejected.listen((data) {
      debugPrint('UserCallController: call rejected');
      _setError('Call was declined');
      Future.delayed(const Duration(seconds: 2), () {
        if (!_disposed) endCall();
      });
    });

    // VERIFICATION: Handle call:failed events for verification failures
    _socketService.onCallFailed.listen((data) {
      debugPrint('UserCallController: call failed – ${data['reason'] ?? 'unknown'}');
      final reason = data['reason']?.toString() ?? '';
      final message = data['message']?.toString();
      
      // Handle listener verification failure
      if (reason == 'listener_not_approved') {
        _setError(message ?? 'This listener is not available for calls at the moment');
      } else if (reason == 'listener_offline') {
        _setError('Listener is currently offline');
      } else if (reason == 'verification_check_failed') {
        _setError('Unable to verify listener status. Please try again');
      } else {
        _setError(message ?? 'Call failed. Please try again');
      }
      
      _stopRingtone();
      Future.delayed(const Duration(seconds: 3), () {
        if (!_disposed) endCall();
      });
    });
  }

  // ── Internal state machine ──

  /// Moves forward only. Prevents backward transitions and duplicate updates.
  void _transitionTo(UserCallState next) {
    if (_disposed) return;
    if (_callState == next) return;
    // Only forward transitions allowed (calling→connecting→connected→ended)
    if (next.index <= _callState.index && next != UserCallState.ended) return;

    debugPrint('UserCallController: $_callState → $next');
    _callState = next;

    if (next == UserCallState.connected) {
      _stopRingtone();
      _noAnswerTimer?.cancel();
      _startCallTimer();
    } else if (next == UserCallState.ended) {
      _stopRingtone();
      _noAnswerTimer?.cancel();
      _callTimer?.cancel();
    }

    notifyListeners();
  }

  // ── Call initiation ──

  Future<void> _initiateCallAndConnect() async {
    debugPrint('UserCallController: Initiating call to listener...');

    final connected = await _socketService.connect();
    if (!connected) {
      _setError('Failed to connect. Please try again.');
      return;
    }

    final callResult = await _callService.initiateCall(
      listenerId: listenerDbId ?? listenerId ?? '',
      callType: 'audio',
    );

    if (!callResult.success) {
      _setError(callResult.error ?? 'Failed to initiate call');
      _stopRingtone();
      _scheduleAutoClose();
      return;
    }

    _callId = callResult.call!.callId;
    debugPrint('UserCallController: Call created with ID: $_callId');

    final targetUserId = listenerId;
    if (targetUserId != null && _callId != null) {
      _socketService.initiateCall(
        callId: _callId!,
        listenerId: targetUserId,
        callerName: userName,
        callerAvatar: userAvatar,
        topic: topic ?? 'General',
        language: language ?? 'English',
        gender: gender,
      );
    }

    await _initAgora();
  }

  // ── Agora init + join ──

  Future<void> _initAgora() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      _setError('Microphone permission denied');
      return;
    }

    final channel = _callId ?? channelName ??
        'call_${listenerId ?? DateTime.now().millisecondsSinceEpoch}';
    _currentChannelName = channel;

    debugPrint('UserCallController: joining channel $channel');

    // Fetch token
    final tokenResult = await _agoraService.fetchToken(channelName: channel);
    if (!tokenResult.success || tokenResult.token == null) {
      _setError(tokenResult.error ?? 'Failed to get call token');
      _stopRingtone();
      _scheduleAutoClose();
      return;
    }

    // Init engine
    final initialized = await _agoraService.initEngine(appId: AgoraConfig.appId);
    if (!initialized) {
      _setError('Failed to initialize call engine');
      _stopRingtone();
      return;
    }

    // Register Agora event handler
    _agoraService.registerEventHandler(RtcEngineEventHandler(
      onJoinChannelSuccess: (connection, elapsed) {
        debugPrint('UserCallController: joined channel ${connection.channelId}');
        _transitionTo(UserCallState.connecting);
      },
      onUserJoined: (connection, remoteUid, elapsed) {
        debugPrint('UserCallController: listener joined call, UID: $remoteUid');
        _transitionTo(UserCallState.connected);
      },
      onUserOffline: (connection, remoteUid, reason) {
        debugPrint('UserCallController: listener left $remoteUid');
        endCall();
      },
      onError: (err, msg) {
        debugPrint('UserCallController: Agora error $err – $msg');
        if (_callState != UserCallState.connected && !_disposed) {
          _setError('Call error: $msg');
        }
      },
      onConnectionStateChanged: (connection, state, reason) {
        debugPrint('UserCallController: conn state $state reason $reason');
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
      _stopRingtone();
      _scheduleAutoClose();
    } else {
      _currentChannelName = channel;
      _socketService.joinedChannel(
        callId: channel,
        channelName: channel,
      );

      // No-answer timeout (45 seconds)
      _noAnswerTimer = Timer(const Duration(seconds: 45), () {
        if (!_disposed &&
            _callState != UserCallState.connected &&
            _callState != UserCallState.ended) {
          _setError('No answer');
          _stopRingtone();
          Future.delayed(const Duration(seconds: 2), () {
            if (!_disposed) endCall();
          });
        }
      });
    }
  }

  // ── User actions ──

  void toggleMute() {
    if (_disposed || _callState == UserCallState.ended) return;
    _isMuted = !_isMuted;
    _agoraService.muteLocalAudio(_isMuted);
    notifyListeners();
  }

  void selectAudioRoute(UserAudioRoute route) {
    audioDeviceManager.selectRoute(route);
  }

  /// End the call. Safe to call multiple times.
  Future<void> endCall() async {
    if (_callState == UserCallState.ended) return;

    final wasConnected = _callState == UserCallState.connected;
    _transitionTo(UserCallState.ended);

    // Update backend
    final cid = _callId ?? _currentChannelName;
    if (cid != null) {
      final status = wasConnected || _callDuration > 0 ? 'completed' : 'cancelled';
      if (status == 'completed') {
        final result = await _callService.endCall(
          callId: cid,
          durationSeconds: _callDuration,
        );
        if (result.success && result.summary != null) {
          _billingSummary = result.summary;
          notifyListeners();
        }
      } else {
        await _callService.updateCallStatus(
          callId: cid,
          status: status,
          durationSeconds: _callDuration > 0 ? _callDuration : null,
        );
      }
    }

    // Clean up Agora
    await _agoraService.reset();

    // Notify peer
    if (listenerId != null && _currentChannelName != null) {
      _socketService.endCall(
        callId: _currentChannelName!,
        otherUserId: listenerId!,
      );
    }
    if (_currentChannelName != null) {
      _socketService.leftChannel(channelName: _currentChannelName!);
    }
  }

  // ── Audio ──

  Future<void> _playRingtone() async {
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('voice/sample.mp3'));
    } catch (e) {
      debugPrint('UserCallController: ringtone error: $e');
    }
  }

  void _stopRingtone() {
    try {
      _audioPlayer.stop();
    } catch (_) {}
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
    _stopRingtone();
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
    _callRejectedSub?.cancel();
    _noAnswerTimer?.cancel();
    _callTimer?.cancel();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    audioDeviceManager.dispose();
    if (_currentChannelName != null) {
      _socketService.leftChannel(channelName: _currentChannelName!);
    }
    super.dispose();
  }
}
