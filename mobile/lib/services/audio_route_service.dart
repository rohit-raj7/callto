import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Supported audio output modes.
///
/// Naming matches calling UX:
/// - [speaker] for loudspeaker
/// - [headset] for wired earphones/headset
/// - [bluetooth] for BT audio
enum AudioMode {
  speaker,
  headset,
  bluetooth,
}

/// State for audio routing.
@immutable
class AudioRouteState {
  final AudioMode currentMode;
  final Set<AudioMode> availableModes;
  final AudioMode? userSelectedMode;
  final String? lastError;

  const AudioRouteState({
    required this.currentMode,
    required this.availableModes,
    this.userSelectedMode,
    this.lastError,
  });

  AudioRouteState copyWith({
    AudioMode? currentMode,
    Set<AudioMode>? availableModes,
    AudioMode? userSelectedMode,
    bool clearUserSelectedMode = false,
    String? lastError,
    bool clearLastError = false,
  }) {
    return AudioRouteState(
      currentMode: currentMode ?? this.currentMode,
      availableModes: availableModes ?? this.availableModes,
      userSelectedMode: clearUserSelectedMode ? null : (userSelectedMode ?? this.userSelectedMode),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  AudioMode get effectiveMode => userSelectedMode ?? currentMode;
}

/// Audio routing + device detection bridge.
///
/// This service is designed to work with optional native integrations:
/// - MethodChannel: `com.callto/audio_route`
///     - `getAudioRoute` -> String ("speaker" | "headset" | "bluetooth" ...)
///     - `getAvailableAudioRoutes` -> List<String>
///     - `setAudioRoute` (args: {"route": <string>})
/// - EventChannel: `com.callto/audio_route_events`
///     - emits either a String route or a Map with keys:
///         - `current`: String
///         - `available`: List<String>
///
/// If native plugins are missing, it safely falls back to polling + speaker mode.
class AudioRouteService {
  static const MethodChannel _method = MethodChannel('com.callto/audio_route');
  static const EventChannel _events = EventChannel('com.callto/audio_route_events');

  final ValueNotifier<AudioRouteState> state = ValueNotifier<AudioRouteState>(
    const AudioRouteState(
      currentMode: AudioMode.speaker,
      availableModes: {AudioMode.speaker},
    ),
  );

  StreamSubscription<dynamic>? _eventSub;
  Timer? _pollTimer;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Try event-based updates first; fall back to polling if missing.
    try {
      _eventSub = _events.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (Object e) {
          debugPrint('AudioRouteService event error: $e');
        },
      );
    } on MissingPluginException {
      debugPrint('AudioRouteService: EventChannel plugin missing');
      _eventSub = null;
    } catch (e) {
      debugPrint('AudioRouteService: EventChannel unavailable ($e)');
      _eventSub = null;
    }

    // Always do an initial refresh.
    try {
      await refresh();
    } catch (e) {
      debugPrint('AudioRouteService: Initial refresh failed ($e)');
    }

    // Poll as a safety net (also covers environments without event channel).
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
  }

  void dispose() {
    _eventSub?.cancel();
    _pollTimer?.cancel();
    state.dispose();
  }

  /// Pull current route + available routes from platform.
  Future<void> refresh() async {
    try {
      final Set<AudioMode> available = await _getAvailableModesSafe();
      final AudioMode current = await _getCurrentModeSafe();

      // Ensure speaker is always available.
      available.add(AudioMode.speaker);

      final AudioRouteState prev = state.value;
      AudioRouteState next = prev.copyWith(
        availableModes: available,
        currentMode: current,
        clearLastError: true,
      );

      // Default routing rules (wired > bluetooth > speaker).
      final AudioMode defaultMode = _defaultModeFor(available);

      // If user-selected mode becomes unavailable, clear it.
      if (next.userSelectedMode != null && !available.contains(next.userSelectedMode)) {
        next = next.copyWith(clearUserSelectedMode: true);
      }

      // If no user override, keep currentMode aligned with defaults.
      if (next.userSelectedMode == null && next.currentMode != defaultMode) {
        next = next.copyWith(currentMode: defaultMode);
        // Best effort apply.
        unawaited(_applyRouteSafe(defaultMode));
      }

      state.value = next;
    } on MissingPluginException {
      // Expected if no native integration is provided.
    } catch (e) {
      debugPrint('AudioRouteService: Error refreshing audio route ($e)');
      state.value = state.value.copyWith(lastError: e.toString());
    }
  }

  /// Manual selection overrides auto routing.
  Future<void> setUserMode(AudioMode mode) async {
    final Set<AudioMode> available = state.value.availableModes;
    if (!available.contains(mode)) return;

    state.value = state.value.copyWith(userSelectedMode: mode);
    await _applyRouteSafe(mode);
  }

  /// Cycles through only available modes:
  /// Speaker → Headset → Bluetooth → Speaker
  Future<void> cycleUserMode() async {
    final ordered = <AudioMode>[AudioMode.speaker, AudioMode.headset, AudioMode.bluetooth];
    final available = state.value.availableModes;

    final cycle = ordered.where(available.contains).toList(growable: false);
    if (cycle.isEmpty) {
      await setUserMode(AudioMode.speaker);
      return;
    }

    final AudioMode current = state.value.effectiveMode;
    final int idx = cycle.indexOf(current);
    final AudioMode next = cycle[(idx >= 0 ? (idx + 1) : 0) % cycle.length];
    await setUserMode(next);
  }

  // -------------------- Platform event handling --------------------

  void _handleEvent(dynamic event) {
    try {
      if (event is String) {
        _updateFromPlatform(route: event, available: null);
        return;
      }

      if (event is Map) {
        final dynamic current = event['current'];
        final dynamic available = event['available'];
        _updateFromPlatform(
          route: current is String ? current : null,
          available: available is List ? available : null,
        );
      }
    } catch (e) {
      debugPrint('AudioRouteService: failed to parse event: $e');
    }
  }

  void _updateFromPlatform({String? route, List<dynamic>? available}) {
    final Set<AudioMode> availableModes = {
      ...state.value.availableModes,
      AudioMode.speaker,
    };

    if (available != null) {
      availableModes
        ..clear()
        ..add(AudioMode.speaker)
        ..addAll(available.whereType<String>().map(_parseMode).whereType<AudioMode>());
    }

    final AudioMode? parsedCurrent = route == null ? null : _parseMode(route);

    AudioRouteState next = state.value.copyWith(
      availableModes: availableModes,
      currentMode: parsedCurrent ?? state.value.currentMode,
      clearLastError: true,
    );

    // Enforce availability.
    if (!availableModes.contains(next.currentMode)) {
      next = next.copyWith(currentMode: _defaultModeFor(availableModes));
    }

    // If user override becomes invalid, clear it.
    if (next.userSelectedMode != null && !availableModes.contains(next.userSelectedMode)) {
      next = next.copyWith(clearUserSelectedMode: true);
    }

    // If no user override, follow default.
    if (next.userSelectedMode == null) {
      final def = _defaultModeFor(availableModes);
      if (next.currentMode != def) {
        next = next.copyWith(currentMode: def);
      }
    }

    state.value = next;
  }

  // -------------------- Helpers --------------------

  AudioMode _defaultModeFor(Set<AudioMode> available) {
    if (available.contains(AudioMode.headset)) return AudioMode.headset;
    if (available.contains(AudioMode.bluetooth)) return AudioMode.bluetooth;
    return AudioMode.speaker;
  }

  AudioMode? _parseMode(String raw) {
    final v = raw.toLowerCase().trim();
    if (v.contains('bluetooth') || v == 'bt') return AudioMode.bluetooth;
    if (v.contains('headset') || v.contains('headphone') || v.contains('wired') || v == 'earphones') {
      return AudioMode.headset;
    }
    if (v.contains('speaker')) return AudioMode.speaker;
    return null;
  }

  Future<AudioMode> _getCurrentModeSafe() async {
    try {
      final String route = await _method.invokeMethod('getAudioRoute');
      return _parseMode(route) ?? AudioMode.speaker;
    } on PlatformException catch (e) {
      debugPrint('AudioRouteService getAudioRoute PlatformException: ${e.message}');
      return AudioMode.speaker;
    } on MissingPluginException {
      return AudioMode.speaker;
    } catch (e) {
      debugPrint('AudioRouteService getAudioRoute error: $e');
      return AudioMode.speaker;
    }
  }

  Future<Set<AudioMode>> _getAvailableModesSafe() async {
    try {
      final dynamic raw = await _method.invokeMethod('getAvailableAudioRoutes');
      if (raw is List) {
        return raw.whereType<String>().map(_parseMode).whereType<AudioMode>().toSet();
      }
      return {AudioMode.speaker};
    } on PlatformException {
      return {AudioMode.speaker};
    } on MissingPluginException {
      return {AudioMode.speaker};
    } catch (e) {
      debugPrint('AudioRouteService getAvailableAudioRoutes error: $e');
      return {AudioMode.speaker};
    }
  }

  Future<void> _applyRouteSafe(AudioMode mode) async {
    final String route;
    switch (mode) {
      case AudioMode.speaker:
        route = 'speaker';
        break;
      case AudioMode.headset:
        route = 'headset';
        break;
      case AudioMode.bluetooth:
        route = 'bluetooth';
        break;
    }

    try {
      await _method.invokeMethod('setAudioRoute', <String, dynamic>{'route': route});
    } on PlatformException catch (e) {
      debugPrint('AudioRouteService setAudioRoute PlatformException: ${e.message}');
      state.value = state.value.copyWith(lastError: e.message ?? 'setAudioRoute failed');
    } on MissingPluginException {
      // No native implementation; ignore.
    } catch (e) {
      debugPrint('AudioRouteService setAudioRoute error: $e');
      state.value = state.value.copyWith(lastError: e.toString());
    }
  }
}
