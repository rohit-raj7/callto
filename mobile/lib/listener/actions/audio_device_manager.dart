import 'package:flutter/foundation.dart';
import '../../services/agora_service.dart';

/// Represents an audio output route.
enum AudioRoute { earpiece, speaker, bluetooth, wiredHeadset }

/// Manages audio device detection and route switching.
///
/// Uses Agora's onAudioRoutingChanged callback for real-time updates.
/// Falls back gracefully on platforms where detection is unsupported.
class AudioDeviceManager extends ChangeNotifier {
  final AgoraService _agoraService;

  AudioRoute _currentRoute = AudioRoute.earpiece;
  AudioRoute get currentRoute => _currentRoute;

  /// Tracks which routes are currently available.
  Set<AudioRoute> _availableRoutes = {AudioRoute.earpiece, AudioRoute.speaker};
  Set<AudioRoute> get availableRoutes => _availableRoutes;

  bool _disposed = false;

  AudioDeviceManager({required AgoraService agoraService})
      : _agoraService = agoraService;

  // ── Route info helpers ──

  String get routeLabel {
    switch (_currentRoute) {
      case AudioRoute.earpiece:
        return 'Earpiece';
      case AudioRoute.speaker:
        return 'Speaker';
      case AudioRoute.bluetooth:
        return 'Bluetooth';
      case AudioRoute.wiredHeadset:
        return 'Headphones';
    }
  }

  String labelFor(AudioRoute route) {
    switch (route) {
      case AudioRoute.earpiece:
        return 'Earpiece';
      case AudioRoute.speaker:
        return 'Speaker';
      case AudioRoute.bluetooth:
        return 'Bluetooth';
      case AudioRoute.wiredHeadset:
        return 'Headphones';
    }
  }

  // ── Agora audio routing callback ──

  /// Called from Agora's [onAudioRoutingChanged].
  /// Maps Agora's int routing value to our [AudioRoute] enum.
  void onAudioRoutingChanged(int routing) {
    if (_disposed) return;

    // Agora routing constants (from Agora docs):
    //  -1 = default, 0 = headset, 1 = earpiece, 2 = headset (no mic),
    //   3 = speakerphone, 4 = loudspeaker, 5 = bluetooth, 6 = USB
    AudioRoute newRoute;
    switch (routing) {
      case 0:
      case 2:
        newRoute = AudioRoute.wiredHeadset;
        _addAvailableRoute(AudioRoute.wiredHeadset);
        break;
      case 1:
        newRoute = AudioRoute.earpiece;
        break;
      case 3:
      case 4:
        newRoute = AudioRoute.speaker;
        break;
      case 5:
        newRoute = AudioRoute.bluetooth;
        _addAvailableRoute(AudioRoute.bluetooth);
        break;
      default:
        newRoute = AudioRoute.earpiece;
    }

    if (_currentRoute != newRoute) {
      _currentRoute = newRoute;
      debugPrint('AudioDeviceManager: route changed → $newRoute');
      notifyListeners();
    }
  }

  void _addAvailableRoute(AudioRoute route) {
    if (!_availableRoutes.contains(route)) {
      _availableRoutes = {..._availableRoutes, route};
      notifyListeners();
    }
  }

  // ── User actions ──

  /// Switch to a specific audio route.
  void selectRoute(AudioRoute route) {
    if (_disposed) return;
    if (_currentRoute == route) return;

    switch (route) {
      case AudioRoute.speaker:
        _agoraService.setEnableSpeakerphone(true);
        break;
      case AudioRoute.earpiece:
        _agoraService.setEnableSpeakerphone(false);
        break;
      case AudioRoute.bluetooth:
        // Agora routes to bluetooth automatically when available and
        // speakerphone is off. On most devices setting speakerphone
        // off when BT is connected will route to BT.
        _agoraService.setEnableSpeakerphone(false);
        break;
      case AudioRoute.wiredHeadset:
        // Similar to BT — system auto-routes when plugged in
        _agoraService.setEnableSpeakerphone(false);
        break;
    }

    _currentRoute = route;
    debugPrint('AudioDeviceManager: user selected → $route');
    notifyListeners();
  }

  /// Cycles to next available route (tap shortcut).
  void cycleRoute() {
    final routes = _availableRoutes.toList();
    if (routes.length <= 1) return;
    final idx = routes.indexOf(_currentRoute);
    final next = routes[(idx + 1) % routes.length];
    selectRoute(next);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
