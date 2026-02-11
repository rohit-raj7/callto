import 'package:flutter/material.dart';

/// Skeleton shimmer widget for the profile card only.
/// Drop this into the profile page in place of the profile card while loading.
class ProfileCardSkeleton extends StatefulWidget {
  const ProfileCardSkeleton({super.key});

  @override
  State<ProfileCardSkeleton> createState() => _ProfileCardSkeletonState();
}

class _ProfileCardSkeletonState extends State<ProfileCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _shimmer({required Widget child}) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                Colors.grey.shade300,
                Colors.grey.shade100,
                Colors.grey.shade300,
              ],
              stops: const [0, .5, 1],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _shimmer(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFC7D8), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5C8A).withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar circle with pink border (matches the real profile image)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFF5C8A), width: 3),
              ),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Right side – name, details, buttons
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name placeholder
                  _rect(width: 120, height: 18),
                  const SizedBox(height: 8),
                  // Gender • City placeholder
                  _rect(width: 160, height: 14),
                  const SizedBox(height: 6),
                  // Rating placeholder
                  _rect(width: 130, height: 14),
                  const SizedBox(height: 14),
                  // Two buttons row
                  Row(
                    children: [
                      Expanded(child: _buttonOutline()),
                      const SizedBox(width: 8),
                      Expanded(child: _buttonFilled()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rect({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _buttonOutline() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF5C8A), width: 2),
      ),
    );
  }

  Widget _buttonFilled() {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFFFF5C8A),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

/// Legacy alias so existing imports keep working.
/// Wraps [ProfileCardSkeleton] in a plain Scaffold.
class ProfileSkeletonScreen extends StatelessWidget {
  const ProfileSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: const ProfileCardSkeleton(),
        ),
      ),
    );
  }
}
