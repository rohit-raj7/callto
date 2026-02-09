import 'package:flutter/material.dart';

/// Reusable circular action button for user-side call screen.
/// Material 3 styled with ripple, label, and active state.
class UserCallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;
  final VoidCallback onTap;

  const UserCallActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = isActive
        ? (activeColor ?? Colors.white.withOpacity(0.25))
        : (inactiveColor ?? Colors.white.withOpacity(0.10));
    final Color fg = isActive ? Colors.white : Colors.white70;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: fg, size: size * 0.43),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// The red end-call button — always prominent.
class UserEndCallButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const UserEndCallButton({
    super.key,
    required this.onTap,
    this.size = 68,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.red,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          child: InkWell(
            onTap: onTap,
            splashColor: Colors.red.shade900,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(Icons.call_end, color: Colors.white, size: size * 0.42),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'End',
          style: TextStyle(
            color: Colors.red,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
