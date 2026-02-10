import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'api_service.dart';
import 'api_config.dart';

/// Token fetch result
class TokenResult {
  final bool success;
  final String? token;
  final int? uid;
  final String? error;

  TokenResult({
    required this.success,
    this.token,
    this.uid,
    this.error,
  });
}

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isInChannel = false;
  String? _currentChannel;
  int? _localUid;
  RtcEngineEventHandler? _currentEventHandler;
  bool _isDisposing = false;

  bool get isInitialized => _isInitialized;
  bool get isInChannel => _isInChannel;
  String? get currentChannel => _currentChannel;
  int? get localUid => _localUid;

  /// Fetch token from backend
  Future<TokenResult> fetchToken({required String channelName}) async {
    try {
      debugPrint('AgoraService: Fetching token for channel: $channelName');
      
      final apiService = ApiService();
      final response = await apiService.post(
        ApiConfig.agoraToken,
        body: {
          'channel_name': channelName,
          'uid': 0, // Let Agora assign UID
        },
      );

      if (response.isSuccess) {
        final data = response.data;
        debugPrint('AgoraService: Token fetched successfully');
        return TokenResult(
          success: true,
          token: data['token'],
          uid: data['uid'],
        );
      } else {
        debugPrint('AgoraService: Token fetch failed: ${response.statusCode} - ${response.error}');
        return TokenResult(
          success: false,
          error: response.error ?? 'Failed to get token: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('AgoraService: Token fetch error: $e');
      return TokenResult(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  /// Initialize the Agora RTC Engine (AUDIO-ONLY)
  Future<bool> initEngine({required String appId}) async {
    if (_isInitialized) {
      debugPrint('AgoraService: Already initialized');
      return true;
    }

    try {
      debugPrint('AgoraService: Initializing Agora RTC Engine (AUDIO-ONLY) with appId: $appId');
      
      // Check if we are on web and if AgoraRTC is available
      if (kIsWeb) {
        debugPrint('AgoraService: Running on Web, checking for AgoraRTC SDK...');
        // We can't easily check for JS objects here without dart:js, 
        // but the try-catch below will catch the "createIrisApiEngine is undefined" error
      }

      try {
        _engine = createAgoraRtcEngine();
      } catch (e) {
        debugPrint('AgoraService: createAgoraRtcEngine failed - $e');
        if (e.toString().contains('createIrisApiEngine')) {
          debugPrint('AgoraService: Iris API Engine not found. This usually means native/web dependencies are missing.');
        }
        return false;
      }
      
      if (_engine == null) {
        debugPrint('AgoraService: Failed to create engine instance');
        return false;
      }

      await _engine!.initialize(RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      // AUDIO-ONLY: Enable audio and disable video explicitly
      await _engine!.enableAudio();
      await _engine!.disableVideo(); // Explicitly disable video for optimization
      
      // Optimize audio profile for voice calls
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard, // Optimized for speech
        scenario: AudioScenarioType.audioScenarioChatroom,
      );

      // Set default audio route to speakerphone
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);

      _isInitialized = true;
      debugPrint('AgoraService: Initialization complete (AUDIO-ONLY mode)');
      return true;
    } catch (e) {
      debugPrint('AgoraService: Initialization failed - $e');
      return false;
    }
  }

  /// Register event handlers for Agora events
  void registerEventHandler(RtcEngineEventHandler handler) {
    if (_engine == null) {
      debugPrint('AgoraService: Engine not initialized, cannot register handler');
      return;
    }
    
    // Unregister previous handler if exists
    if (_currentEventHandler != null) {
      _engine!.unregisterEventHandler(_currentEventHandler!);
    }
    
    _currentEventHandler = handler;
    _engine!.registerEventHandler(handler);
    debugPrint('AgoraService: Event handler registered');
  }
  
  /// Unregister current event handler
  void unregisterEventHandler() {
    if (_engine != null && _currentEventHandler != null) {
      _engine!.unregisterEventHandler(_currentEventHandler!);
      _currentEventHandler = null;
      debugPrint('AgoraService: Event handler unregistered');
    }
  }

  /// Join a voice channel (AUDIO-ONLY)
  Future<bool> joinChannel({
    required String token,
    required String channelName,
    required int uid,
  }) async {
    if (!_isInitialized) {
      debugPrint('AgoraService: Not initialized');
      return false;
    }

    if (_isInChannel) {
      debugPrint('AgoraService: Already in a channel, leaving first...');
      await leaveChannel();
    }

    try {
      debugPrint('AgoraService: Joining channel $channelName with uid $uid (AUDIO-ONLY)');
      
      await _engine!.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          // AUDIO-ONLY configuration
          autoSubscribeAudio: true,
          autoSubscribeVideo: false, // Explicitly disable video subscription
          publishMicrophoneTrack: true,
          publishCameraTrack: false, // Explicitly disable camera publishing
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );

      _isInChannel = true;
      _currentChannel = channelName;
      _localUid = uid;
      return true;
    } catch (e) {
      debugPrint('AgoraService: Failed to join channel - $e');
      return false;
    }
  }

  /// Leave the current channel
  Future<void> leaveChannel() async {
    try {
      if (_engine != null && _isInChannel) {
        debugPrint('AgoraService: Leaving channel $_currentChannel');
        await _engine!.leaveChannel();
      }
      
      _isInChannel = false;
      _currentChannel = null;
      _localUid = null;
    } catch (e) {
      debugPrint('AgoraService: Failed to leave channel - $e');
    }
  }

  /// Mute/unmute local audio
  Future<void> muteLocalAudio(bool mute) async {
    try {
      if (_engine != null) {
        debugPrint('AgoraService: ${mute ? "Muting" : "Unmuting"} local audio');
        await _engine!.muteLocalAudioStream(mute);
      }
    } catch (e) {
      debugPrint('AgoraService: Failed to mute local audio - $e');
    }
  }

  /// Switch audio output between speaker and earpiece
  Future<void> setEnableSpeakerphone(bool enable) async {
    try {
      if (_engine != null) {
        debugPrint('AgoraService: ${enable ? "Enabling" : "Disabling"} speakerphone');
        await _engine!.setEnableSpeakerphone(enable);
      }
    } catch (e) {
      debugPrint('AgoraService: Failed to set speakerphone - $e');
    }
  }

  /// Dispose the Agora engine
  Future<void> dispose() async {
    // Prevent concurrent dispose calls
    if (_isDisposing) {
      debugPrint('AgoraService: Already disposing, skipping');
      return;
    }
    
    _isDisposing = true;
    
    try {
      // Unregister event handler first to prevent callbacks during dispose
      unregisterEventHandler();
      
      if (_engine != null) {
        if (_isInChannel) {
          await _engine!.leaveChannel();
        }
        await _engine!.release();
        _engine = null;
      }
      
      _isInitialized = false;
      _isInChannel = false;
      _currentChannel = null;
      _localUid = null;

      debugPrint('AgoraService: Disposed');
    } catch (e) {
      debugPrint('AgoraService: Failed to dispose - $e');
    } finally {
      _isDisposing = false;
    }
  }
  
  /// Reset the service state without full dispose (for reinitialization)
  Future<void> reset() async {
    await dispose();
    // Small delay to ensure cleanup is complete
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
