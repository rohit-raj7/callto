// lib/screens/voice_selection_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'payment.dart';
import '../../services/storage_service.dart';

// Conditional imports for dart:io (mobile only)
import 'voice_io_stub.dart'
    if (dart.library.io) 'voice_io_real.dart' as voice_io;

class VoiceSelectionPage extends StatefulWidget {
  final String? selectedLanguage;
  const VoiceSelectionPage({super.key, this.selectedLanguage});

  @override
  State<VoiceSelectionPage> createState() => _VoiceSelectionPageState();
}

class _VoiceSelectionPageState extends State<VoiceSelectionPage> {
  // Recording state
  bool _isRecording = false;
  bool _hasRecorded = false;
  bool _isPlaying = false;
  bool _isUploading = false;
  String? _recordedFilePath;
  Uint8List? _webRecordingBytes;

  // Timer for recording duration
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  // Recorder & Player
  late AudioRecorder _recorder;
  final AudioPlayer _player = AudioPlayer();

  // Consistent color palette
  final Color primaryColor = const Color(0xFFFF4081);
  final Color backgroundColor = const Color(0xFFFCE4EC);
  final Color textPrimary = const Color(0xFF880E4F);

  final String verificationTextHi = """
Namaste! Dosti bahut khaas hoti hai. 
Acchhe dost hamesha saath dete hain. 
Dost khushi badhate hain aur dukh kam karte hain. 
Unke bina sab adhoora hai. Dhanyavaad!
""";

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _loadSavedRecording();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  /// Load any previously saved recording path
  Future<void> _loadSavedRecording() async {
    final storageService = StorageService();
    final savedPath = await storageService.getListenerVoiceLocalPath();
    if (savedPath != null && savedPath.isNotEmpty) {
      if (kIsWeb) {
        // Web blob URLs don't persist across sessions
        return;
      }
      final exists = voice_io.fileExists(savedPath);
      if (exists) {
        setState(() {
          _recordedFilePath = savedPath;
          _hasRecorded = true;
        });
      }
    }
  }

  // ==================== RECORDING ====================

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
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
        filePath =
            '$dir/voice_verification_${DateTime.now().millisecondsSinceEpoch}.m4a';
        config = const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
        );
      }

      await _recorder.start(config, path: filePath);

      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
        _hasRecorded = false;
        _recordedFilePath = null;
      });

      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });
      });
    } catch (e) {
      debugPrint('Recording start error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _recorder.stop();

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

      final storageService = StorageService();
      await storageService.saveListenerVoiceLocalPath(path);

      setState(() {
        _isRecording = false;
        _hasRecorded = true;
        _recordedFilePath = path;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recording saved! (${_recordingSeconds}s)'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Recording stop error: $e');
      setState(() => _isRecording = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error stopping recording: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  // ==================== PLAYBACK ====================

  Future<void> _playRecording() async {
    if (_recordedFilePath == null) return;

    try {
      if (_isPlaying) {
        await _player.stop();
        setState(() => _isPlaying = false);
        return;
      }

      _player.onPlayerComplete.listen((_) {
        if (mounted) setState(() => _isPlaying = false);
      });

      if (kIsWeb) {
        await _player.play(UrlSource(_recordedFilePath!));
      } else {
        await _player.play(DeviceFileSource(_recordedFilePath!));
      }

      setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('Playback error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playback failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== RE-RECORD ====================

  Future<void> _reRecord() async {
    await _player.stop();
    setState(() {
      _hasRecorded = false;
      _isPlaying = false;
      _recordedFilePath = null;
      _webRecordingBytes = null;
      _recordingSeconds = 0;
    });
    _startRecording();
  }

  // ==================== UPLOAD TO BACKEND ====================

  /// Get audio bytes and mime type for upload
  Future<Map<String, dynamic>?> _getAudioData() async {
    Uint8List? bytes;
    String mimeType;

    if (kIsWeb && _webRecordingBytes != null) {
      bytes = _webRecordingBytes;
      mimeType = 'audio/ogg';
    } else if (!kIsWeb && _recordedFilePath != null) {
      bytes = voice_io.readFileBytes(_recordedFilePath!);
      mimeType = 'audio/m4a';
    } else {
      return null;
    }

    if (bytes == null || bytes.isEmpty) return null;

    return {
      'base64': base64Encode(bytes),
      'mimeType': mimeType,
    };
  }

  // ==================== SAVE & CONTINUE ====================

  Future<void> _saveAndContinue() async {
    if (!_hasRecorded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete voice verification first'),
          backgroundColor: primaryColor,
        ),
      );
      return;
    }

    await _player.stop();
    setState(() => _isUploading = true);

    try {
      // Get audio data as base64
      final audioData = await _getAudioData();

      if (audioData == null) {
        setState(() => _isUploading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No recording data available'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Save audio locally — will be uploaded after listener profile is created in PaymentPage
      final storageService = StorageService();
      await storageService.saveListenerVoiceBase64(audioData['base64']);
      await storageService.saveListenerVoiceMimeType(audioData['mimeType']);
      await storageService.saveListenerVoiceVerified(true);

      debugPrint('Voice recording saved locally (${audioData['mimeType']})');

      if (!mounted) return;
      setState(() => _isUploading = false);

      // Navigate to PaymentPage
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PaymentPage()),
      );
    } catch (e) {
      debugPrint('Save & continue error: $e');
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _skip() {
    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Voice Verification',
          style: TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.03),

                // Title with icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.record_voice_over_rounded,
                    size: 48,
                    color: primaryColor,
                  ),
                ),
                
                const SizedBox(height: 20),

                // Title
                Text(
                  'Audio Verification',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // Instruction
                Text(
                  'Please record an audio of you saying the lines below for verification.',
                  style: TextStyle(
                    fontSize: 15,
                    color: textPrimary.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: screenHeight * 0.04),

                // Verification Text Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_quote_rounded,
                        color: primaryColor,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Namaste! Dosti bahut khaas hoti hai. '
                        'Acchhe dost hamesha saath dete hain. '
                        'Dost khushi badhate hain aur dukh kam karte hain. '
                        'Unke bina sab adhoora hai. Dhanyavaad!',
                        style: TextStyle(
                          fontSize: 16,
                          color: textPrimary,
                          height: 1.7,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.04),

                // Recording Timer (visible during recording)
                if (_isRecording)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _formatDuration(_recordingSeconds),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade600,
                      ),
                    ),
                  ),

                // Microphone Button
                GestureDetector(
                  onTap: _isUploading ? null : _toggleRecording,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording
                          ? Colors.red
                          : _hasRecorded
                              ? Colors.green
                              : primaryColor,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording
                                  ? Colors.red
                                  : _hasRecorded
                                      ? Colors.green
                                      : primaryColor)
                              .withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording
                          ? Icons.stop_rounded
                          : _hasRecorded
                              ? Icons.check_rounded
                              : Icons.mic_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status text
                Text(
                  _isRecording
                      ? 'Recording... Tap to stop'
                      : _hasRecorded
                          ? 'Recording Complete ✓'
                          : 'Tap to Record',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _isRecording
                        ? Colors.red.shade600
                        : _hasRecorded
                            ? Colors.green.shade600
                            : textPrimary,
                  ),
                ),

                // Playback & Re-record controls
                if (_hasRecorded && !_isRecording) ...[
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _playRecording,
                        icon: Icon(
                          _isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                        label: Text(_isPlaying ? 'Stop' : 'Preview'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: _isUploading ? null : _reRecord,
                        icon: const Icon(Icons.refresh_rounded, size: 22),
                        label: const Text('Re-record'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade700,
                          side: BorderSide(color: Colors.orange.shade700),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  if (_recordingSeconds > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Duration: ${_formatDuration(_recordingSeconds)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: textPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                ],

                SizedBox(height: screenHeight * 0.05),

                // Bottom Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isUploading ? null : _skip,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: primaryColor, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 16,
                            color: primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isUploading ? null : _saveAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 4,
                        ),
                        child: _isUploading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


