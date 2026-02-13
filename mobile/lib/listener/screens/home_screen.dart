import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import '../widgets/top_bar.dart';
import '../actions/calling.dart';
import '../../services/listener_service.dart';
import '../../services/socket_service.dart';
import '../../services/incoming_call_overlay_service.dart';
import '../../services/storage_service.dart';
import '../../services/call_service.dart';

// Conditional imports for dart:io (mobile only)
import '../listener_form/voice_io_stub.dart'
    if (dart.library.io) '../listener_form/voice_io_real.dart' as voice_io;

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

  // Verification status state
  String _verificationStatus = 'approved'; // default to approved until loaded
  String? _rejectionReason;
  int _reapplyAttempts = 0;
  bool _verificationLoading = true;
  bool _reapplying = false;
  String? _listenerId; // Listener ID for voice upload

  // Voice re-recording state (used when rejected for voice)
  bool _isVoiceRejection = false;
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isPlaying = false;
  bool _isUploadingVoice = false;
  bool _voiceUploaded = false;
  String? _recordedFilePath;
  Uint8List? _webRecordingBytes;
  Timer? _voiceRecordingTimer;
  int _recordingSeconds = 0;
  late AudioRecorder _audioRecorder;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = AudioRecorder();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    if (isOnline) { // Added: Start pulsing if online
      _pulseController.repeat(reverse: true);
    }
    _setupCallsListener();
    _startHeartbeat(); // Start heartbeat
    _fetchVerificationStatus(); // Fetch verification status
    
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
    _voiceRecordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
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

  /// Fetch verification status from backend
  Future<void> _fetchVerificationStatus() async {
    try {
      final result = await _listenerService.getMyProfile();
      if (!mounted) return;
      if (result.success && result.listener != null) {
        final reason = result.listener!.rejectionReason ?? '';
        setState(() {
          _verificationStatus = result.listener!.verificationStatus ?? 'approved';
          _rejectionReason = result.listener!.rejectionReason;
          _reapplyAttempts = result.listener!.reapplyAttempts;
          _listenerId = result.listener!.listenerId;
          _isVoiceRejection = reason.toLowerCase().contains('voice');
          _verificationLoading = false;
        });
      } else {
        setState(() {
          _verificationLoading = false;
        });
      }
    } catch (e) {
      print('[HOME] Error fetching verification status: $e');
      if (mounted) {
        setState(() {
          _verificationLoading = false;
        });
      }
    }
  }

  /// Handle reapply for verification
  Future<void> _handleReapply() async {
    if (_reapplying) return;
    setState(() => _reapplying = true);
    try {
      final result = await _listenerService.reapplyForVerification();
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _verificationStatus = 'reapplied';
          _rejectionReason = null;
          _reapplyAttempts += 1;
          _reapplying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reapplication submitted! Your profile will be reviewed again.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _reapplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to reapply'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _reapplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== VOICE RE-RECORDING (for voice rejection) ====================

  Future<void> _startVoiceRecording() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      _webRecordingBytes = null;

      RecordConfig config;
      String filePath = '';

      if (kIsWeb) {
        config = const RecordConfig(
          encoder: AudioEncoder.opus,
          sampleRate: 44100,
          numChannels: 1,
        );
      } else {
        final dir = voice_io.getAppDocumentsPath();
        filePath = '$dir/voice_rerecord_${DateTime.now().millisecondsSinceEpoch}.m4a';
        config = const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        );
      }

      await _audioRecorder.start(config, path: filePath);

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _hasRecorded = false;
        _recordedFilePath = null;
        _voiceUploaded = false;
      });

      _voiceRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _recordingSeconds++);
      });
    } catch (e) {
      debugPrint('Recording start error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recording failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      _voiceRecordingTimer?.cancel();
      final path = await _audioRecorder.stop();

      if (path == null || path.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording failed — no data captured'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isRecording = false);
        return;
      }

      if (kIsWeb) {
        try {
          final response = await http.get(Uri.parse(path));
          if (response.statusCode == 200) {
            _webRecordingBytes = response.bodyBytes;
          }
        } catch (e) {
          debugPrint('Failed to fetch web blob: $e');
        }
      }

      setState(() {
        _isRecording = false;
        _hasRecorded = true;
        _recordedFilePath = path;
      });
    } catch (e) {
      debugPrint('Recording stop error: $e');
      setState(() => _isRecording = false);
    }
  }

  void _toggleVoiceRecording() {
    if (_isRecording) {
      _stopVoiceRecording();
    } else {
      _startVoiceRecording();
    }
  }

  Future<void> _playVoiceRecording() async {
    if (_recordedFilePath == null) return;
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        setState(() => _isPlaying = false);
        return;
      }

      _audioPlayer.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });

      if (kIsWeb) {
        await _audioPlayer.play(UrlSource(_recordedFilePath!));
      } else {
        await _audioPlayer.play(DeviceFileSource(_recordedFilePath!));
      }
      setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('Playback error: $e');
    }
  }

  Future<void> _reRecordVoice() async {
    await _audioPlayer.stop();
    setState(() {
      _hasRecorded = false;
      _isPlaying = false;
      _recordedFilePath = null;
      _webRecordingBytes = null;
      _recordingSeconds = 0;
      _voiceUploaded = false;
    });
    _startVoiceRecording();
  }

  Future<void> _uploadVoiceAndSave() async {
    if (_recordedFilePath == null || _listenerId == null) return;

    await _audioPlayer.stop();
    setState(() => _isUploadingVoice = true);

    try {
      // Get audio bytes
      Uint8List? bytes;
      String mimeType;
      String filename;

      if (kIsWeb && _webRecordingBytes != null) {
        bytes = _webRecordingBytes;
        mimeType = 'audio/ogg';
        filename = 'voice_rerecord.ogg';
      } else if (!kIsWeb && _recordedFilePath != null) {
        bytes = voice_io.readFileBytes(_recordedFilePath!);
        mimeType = 'audio/m4a';
        filename = 'voice_rerecord.m4a';
      } else {
        setState(() => _isUploadingVoice = false);
        return;
      }

      if (bytes == null || bytes.isEmpty) {
        setState(() => _isUploadingVoice = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recording data available'), backgroundColor: Colors.red),
        );
        return;
      }

      // Upload to Cloudinary via backend
      final uploadResult = await _listenerService.uploadVoiceFile(
        fileBytes: bytes,
        filename: filename,
        mimeType: mimeType,
      );

      if (!uploadResult.success || uploadResult.message == null) {
        setState(() => _isUploadingVoice = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadResult.error ?? 'Voice upload failed'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final voiceUrl = uploadResult.message!;

      // Update voice verification URL on backend
      final updateResult = await _listenerService.updateVoiceVerification(
        listenerId: _listenerId!,
        voiceUrl: voiceUrl,
      );

      if (!mounted) return;

      if (updateResult.success) {
        setState(() {
          _isUploadingVoice = false;
          _voiceUploaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice uploaded successfully! You can now reapply.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() => _isUploadingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(updateResult.error ?? 'Failed to update voice'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Voice upload error: $e');
      if (!mounted) return;
      setState(() => _isUploadingVoice = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

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
              child: _verificationLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _verificationStatus == 'pending'
                      ? _buildPendingView()
                      : _verificationStatus == 'rejected'
                          ? _buildRejectedView()
                          : _verificationStatus == 'reapplied'
                              ? _buildReappliedView()
                              : !isOnline
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

  /// Build pending verification view
  Widget _buildPendingView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 56,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Verification Pending',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your profile is under review. You\'ll be able to receive calls once your profile is verified by our team.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'This usually takes 24-48 hours',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// Build rejected verification view with reason and reapply
  Widget _buildRejectedView() => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Rejected icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_rounded,
                size: 56,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Verification Rejected',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Unfortunately, your profile could not be verified.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            // Rejection reason card
            if (_rejectionReason != null && _rejectionReason!.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.report_problem_rounded, size: 18, color: Colors.red.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Reason for Rejection',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _rejectionReason!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

            // ═══════════ VOICE RE-RECORDING SECTION ═══════════
            if (_isVoiceRejection && _reapplyAttempts < 3) ...[
              const SizedBox(height: 20),
              _buildVoiceRecordingSection(),
            ],

            const SizedBox(height: 24),
            // Reapply section
            if (_reapplyAttempts < 3) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Want to try again?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isVoiceRejection && !_voiceUploaded
                          ? 'Please record and upload your voice above before reapplying.'
                          : 'Fix the issues mentioned above and reapply. You have ${3 - _reapplyAttempts} attempt${3 - _reapplyAttempts == 1 ? '' : 's'} remaining.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_reapplying || (_isVoiceRejection && !_voiceUploaded))
                            ? null
                            : _handleReapply,
                        icon: _reapplying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.refresh_rounded,
                                color: (_isVoiceRejection && !_voiceUploaded)
                                    ? Colors.grey.shade400
                                    : Colors.white,
                              ),
                        label: Text(
                          _reapplying
                              ? 'Submitting...'
                              : (_isVoiceRejection && !_voiceUploaded)
                                  ? 'Upload Voice to Reapply'
                                  : 'Reapply for Verification',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_isVoiceRejection && !_voiceUploaded)
                              ? Colors.grey.shade300
                              : Colors.blue.shade600,
                          foregroundColor: (_isVoiceRejection && !_voiceUploaded)
                              ? Colors.grey.shade500
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Icon(Icons.support_agent, size: 32, color: Colors.grey.shade600),
                    const SizedBox(height: 10),
                    Text(
                      'Maximum reapply attempts reached',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Please contact our support team for further assistance.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );

  /// Voice recording section widget for voice rejection
  Widget _buildVoiceRecordingSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade50, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.mic_rounded, size: 20, color: Colors.deepPurple.shade700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Re-record Your Voice',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Record a clear voice sample to continue',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              if (_voiceUploaded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                      const SizedBox(width: 4),
                      Text(
                        'Uploaded',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Verification text to read
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote, size: 16, color: Colors.deepPurple.shade300),
                    const SizedBox(width: 6),
                    Text(
                      'Read this text aloud:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Namaste! Dosti bahut khaas hoti hai.\nAcchhe dost hamesha saath dete hain.\nDost khushi badhate hain aur dukh kam karte hain.\nUnke bina sab adhoora hai. Dhanyavaad!',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.deepPurple.shade700,
                    height: 1.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recording controls
          if (!_hasRecorded && !_isRecording) ...[
            // Initial state — show record button
            Center(
              child: GestureDetector(
                onTap: _startVoiceRecording,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic, color: Colors.white, size: 32),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap to start recording',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ] else if (_isRecording) ...[
            // Recording in progress
            Center(
              child: Column(
                children: [
                  // Timer
                  Text(
                    '${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Recording...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Stop button
                  GestureDetector(
                    onTap: _stopVoiceRecording,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300, width: 3),
                      ),
                      child: Icon(Icons.stop_rounded, color: Colors.red.shade600, size: 36),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap to stop',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ] else if (_hasRecorded) ...[
            // Recorded — show playback + re-record + upload
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Duration info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.audiotrack_rounded, size: 18, color: Colors.deepPurple.shade400),
                      const SizedBox(width: 6),
                      Text(
                        'Recording: ${_recordingSeconds}s',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Action buttons row
                  Row(
                    children: [
                      // Play/Stop
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _playVoiceRecording,
                          icon: Icon(
                            _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                            size: 20,
                          ),
                          label: Text(_isPlaying ? 'Stop' : 'Play'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.deepPurple.shade600,
                            side: BorderSide(color: Colors.deepPurple.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Re-record
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _voiceUploaded ? null : _reRecordVoice,
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('Re-record'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange.shade700,
                            side: BorderSide(color: Colors.orange.shade300),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Upload button
                  if (!_voiceUploaded)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingVoice ? null : _uploadVoiceAndSave,
                        icon: _isUploadingVoice
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 20),
                        label: Text(_isUploadingVoice ? 'Uploading...' : 'Upload Voice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build reapplied (waiting for re-review) view
  Widget _buildReappliedView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.update_rounded,
                  size: 56,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Reapplication Under Review',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Your reapplication has been submitted and is being reviewed. We\'ll update your status soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Attempt $_reapplyAttempts of 3',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

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