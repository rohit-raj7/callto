import 'package:flutter/material.dart';
import 'audio_device_manager.dart';

/// Bottom sheet that lists available audio output routes
/// and lets the user pick one.
class UserAudioRouteBottomSheet extends StatelessWidget {
  final UserAudioDeviceManager manager;

  const UserAudioRouteBottomSheet({super.key, required this.manager});

  static Future<void> show(BuildContext context, UserAudioDeviceManager manager) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => UserAudioRouteBottomSheet(manager: manager),
    );
  }

  IconData _iconFor(UserAudioRoute route) {
    switch (route) {
      case UserAudioRoute.earpiece:
        return Icons.phone_in_talk;
      case UserAudioRoute.speaker:
        return Icons.volume_up;
      case UserAudioRoute.bluetooth:
        return Icons.bluetooth_audio;
      case UserAudioRoute.wiredHeadset:
        return Icons.headset;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routes = manager.availableRoutes.toList();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A3C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Audio Output',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...routes.map((route) {
              final isSelected = route == manager.currentRoute;
              return ListTile(
                leading: Icon(
                  _iconFor(route),
                  color: isSelected ? Colors.pinkAccent : Colors.white70,
                ),
                title: Text(
                  manager.labelFor(route),
                  style: TextStyle(
                    color: isSelected ? Colors.pinkAccent : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.pinkAccent, size: 22)
                    : null,
                onTap: () {
                  manager.selectRoute(route);
                  Navigator.pop(context);
                },
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
