import 'package:flutter/foundation.dart';
import '../../services/agora_service.dart';

/// Represents an audio output route.
enum UserAudioRoute { earpiece, speaker, bluetooth, wiredHeadset }

/// Manages audio device detection and route switching on the user side.
///
/// Uses Agora's onAudioRoutingChanged callback for real-time updates.
/// Falls back gracefully on platforms where detection is unsupported.
class UserAudioDeviceManager extends ChangeNotifier {
  final AgoraService _agoraService;

  UserAudioRoute _currentRoute = UserAudioRoute.earpiece;
  UserAudioRoute get currentRoute => _currentRoute;

  /// Tracks which routes are currently available.
  Set<UserAudioRoute> _availableRoutes = {
    UserAudioRoute.earpiece,
    UserAudioRoute.speaker,
  };
  Set<UserAudioRoute> get availableRoutes => _availableRoutes;

  bool _disposed = false;

  UserAudioDeviceManager({required AgoraService agoraService})
      : _agoraService = agoraService;

  // ── Route info helpers ──

  String get routeLabel {
    switch (_currentRoute) {
      case UserAudioRoute.earpiece:
        return 'Earpiece';
      case UserAudioRoute.speaker:
        return 'Speaker';
      case UserAudioRoute.bluetooth:
        return 'Bluetooth';
      case UserAudioRoute.wiredHeadset:
        return 'Headphones';
    }
  }

  String labelFor(UserAudioRoute route) {
    switch (route) {
      case UserAudioRoute.earpiece:
        return 'Earpiece';
      case UserAudioRoute.speaker:
        return 'Speaker';
      case UserAudioRoute.bluetooth:
        return 'Bluetooth';
      case UserAudioRoute.wiredHeadset:
        return 'Headphones';
    }
  }

  // ── Agora audio routing callback ──

  /// Called from Agora's [onAudioRoutingChanged].
  /// Maps Agora's int routing value to our [UserAudioRoute] enum.
  void onAudioRoutingChanged(int routing) {
    if (_disposed) return;

    // Agora routing constants (from Agora docs):
    //  -1 = default, 0 = headset, 1 = earpiece, 2 = headset (no mic),
    //   3 = speakerphone, 4 = loudspeaker, 5 = bluetooth, 6 = USB
    UserAudioRoute newRoute;
    switch (routing) {
      case 0:
      case 2:
        newRoute = UserAudioRoute.wiredHeadset;
        _addAvailableRoute(UserAudioRoute.wiredHeadset);
        break;
      case 1:
        newRoute = UserAudioRoute.earpiece;
        break;
      case 3:
      case 4:
        newRoute = UserAudioRoute.speaker;
        break;
      case 5:
        newRoute = UserAudioRoute.bluetooth;
        _addAvailableRoute(UserAudioRoute.bluetooth);
        break;
      default:
        newRoute = UserAudioRoute.earpiece;
    }

    if (_currentRoute != newRoute) {
      _currentRoute = newRoute;
      debugPrint('UserAudioDeviceManager: route changed → $newRoute');
      notifyListeners();
    }
  }

  void _addAvailableRoute(UserAudioRoute route) {
    if (!_availableRoutes.contains(route)) {
      _availableRoutes = {..._availableRoutes, route};
      notifyListeners();
    }
  }

  // ── User actions ──

  /// Switch to a specific audio route.
  void selectRoute(UserAudioRoute route) {
    if (_disposed) return;
    if (_currentRoute == route) return;

    switch (route) {
      case UserAudioRoute.speaker:
        _agoraService.setEnableSpeakerphone(true);
        break;
      case UserAudioRoute.earpiece:
        _agoraService.setEnableSpeakerphone(false);
        break;
      case UserAudioRoute.bluetooth:
        // Agora routes to bluetooth automatically when available and
        // speakerphone is off. On most devices setting speakerphone
        // off when BT is connected will route to BT.
        _agoraService.setEnableSpeakerphone(false);
        break;
      case UserAudioRoute.wiredHeadset:
        // Similar to BT — system auto-routes when plugged in
        _agoraService.setEnableSpeakerphone(false);
        break;
    }

    _currentRoute = route;
    debugPrint('UserAudioDeviceManager: user selected → $route');
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
