import 'package:flutter/material.dart';

class ProfileSkeletonScreen extends StatefulWidget {
  const ProfileSkeletonScreen({super.key});

  @override
  State<ProfileSkeletonScreen> createState() => _ProfileSkeletonScreenState();
}

class _ProfileSkeletonScreenState extends State<ProfileSkeletonScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
          ..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------- shimmer wrapper ----------
  Widget shimmer({required Widget child}) {
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
    return Scaffold(
      backgroundColor: const Color(0xffF7F7F7),
      body: shimmer(
        child: SafeArea(
          child: Column(
            children: [

              // ---------------- HEADER ----------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xffFAD7E2),
                ),
                child: Row(
                  children: [
                    _circle(28),
                    const SizedBox(width: 14),
                    _rect(width: 150, height: 22),
                    const Spacer(),
                    _pill(width: 90, height: 36),
                    const SizedBox(width: 12),
                    _circle(40),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ---------------- PROFILE CARD ----------------
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(18),
                decoration: _card(),
                child: Column(
                  children: [

                    Row(
                      children: [
                        _circle(86),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _rect(width: 120, height: 18),
                            const SizedBox(height: 10),
                            _rect(width: 160, height: 14),
                            const SizedBox(height: 8),
                            _rect(width: 110, height: 14),
                          ],
                        )
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(child: _button()),
                        const SizedBox(width: 12),
                        Expanded(child: _button()),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ---------------- MENU TILES ----------------
              _menuTile(),
              _menuTile(),
              _menuTile(),
              _menuTile(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- components ----------

  Widget _rect({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _circle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _pill({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
      ),
    );
  }

  Widget _button() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _menuTile() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Row(
        children: [
          _circle(26),
          const SizedBox(width: 16),
          _rect(width: 160, height: 16),
          const Spacer(),
          _circle(18),
        ],
      ),
    );
  }

  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          blurRadius: 6,
          color: Colors.black.withOpacity(.05),
          offset: const Offset(0, 2),
        )
      ],
    );
  }
}
