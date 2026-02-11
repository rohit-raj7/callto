import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import '../../services/call_service.dart';

class ListenerRatingScreen extends StatefulWidget {
  final String callId;
  final String listenerName;
  final String listenerAvatar;

  const ListenerRatingScreen({
    super.key,
    required this.callId,
    required this.listenerName,
    required this.listenerAvatar,
  });

  @override
  State<ListenerRatingScreen> createState() => _ListenerRatingScreenState();
}

class _ListenerRatingScreenState extends State<ListenerRatingScreen>
    with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  double _rating = 0.0;
  bool _isSubmitting = false;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _updateRating(double value) {
    if (_isSubmitting) return;
    setState(() {
      _rating = value;
    });
  }

  Future<void> _submitRating() async {
    if (_isSubmitting || _rating <= 0) return;
    setState(() {
      _isSubmitting = true;
    });

    final result = await _callService.submitRating(
      callId: widget.callId,
      rating: _rating,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavBar()),
      );
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.error ?? 'Failed to submit rating')),
    );
  }

  void _skipRating() {
    if (_isSubmitting) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BottomNavBar()),
    );
  }

  ImageProvider? _avatarImage() {
    if (widget.listenerAvatar.isEmpty) return null;
    if (widget.listenerAvatar.startsWith('http://') ||
        widget.listenerAvatar.startsWith('https://')) {
      return NetworkImage(widget.listenerAvatar);
    }
    if (widget.listenerAvatar.startsWith('assets/')) {
      return AssetImage(widget.listenerAvatar);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Card(
                  elevation: 6,
                  shadowColor: Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.pinkAccent.withOpacity(0.2),
                          backgroundImage: _avatarImage(),
                          child: _avatarImage() == null
                              ? const Icon(Icons.person, size: 40, color: Colors.white70)
                              : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.listenerName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Rate Your Call Experience',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your feedback helps improve listener quality',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 22),
                        _StarRating(
                          value: _rating,
                          onChanged: _isSubmitting ? null : _updateRating,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _rating == 0 ? 'Select a rating' : '${_rating.toStringAsFixed(1)}/5',
                          style: TextStyle(
                            fontSize: 14,
                            color: _rating == 0
                                ? Colors.grey.shade500
                                : theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed:
                                (_isSubmitting || _rating == 0) ? null : _submitRating,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  )
                                : const Text('Submit'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _isSubmitting ? null : _skipRating,
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;
  final int starCount;

  const _StarRating({
    required this.value,
    required this.onChanged,
    this.starCount = 5,
  });

  double _valueForPosition(int index, double dx, double starWidth) {
    final isHalf = dx <= starWidth / 2;
    final rawValue = (index + (isHalf ? 0.5 : 1.0));
    return rawValue < 1.0 ? 1.0 : rawValue;
  }

  @override
  Widget build(BuildContext context) {
    const double starSize = 36;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        final starValue = index + 1;
        final isFull = value >= starValue;
        final isHalf = !isFull && value >= starValue - 0.5;

        return GestureDetector(
          onTapDown: onChanged == null
              ? null
              : (details) {
                  final newValue = _valueForPosition(
                    index,
                    details.localPosition.dx,
                    starSize,
                  );
                  onChanged!(newValue);
                },
          child: Stack(
            children: [
              Icon(
                Icons.star_border,
                size: starSize,
                color: Colors.amber.shade400,
              ),
              if (isHalf)
                ClipRect(
                  clipper: _HalfClipper(),
                  child: Icon(
                    Icons.star,
                    size: starSize,
                    color: Colors.amber.shade400,
                  ),
                ),
              if (isFull)
                Icon(
                  Icons.star,
                  size: starSize,
                  color: Colors.amber.shade400,
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _HalfClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width / 2, size.height);

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}
