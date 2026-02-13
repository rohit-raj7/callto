import 'package:flutter/material.dart';
import '../../../services/user_service.dart';

class AppRatingPage extends StatefulWidget {
  const AppRatingPage({super.key});

  @override
  State<AppRatingPage> createState() => _AppRatingPageState();
}

class _AppRatingPageState extends State<AppRatingPage> {
  final UserService _userService = UserService();
  final TextEditingController _feedbackController = TextEditingController();
  final FocusNode _feedbackFocusNode = FocusNode();

  double _rating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    _feedbackFocusNode.dispose();
    super.dispose();
  }

  String _ratingLabel(double value) {
    if (value >= 4.5) return 'Excellent';
    if (value >= 3.5) return 'Great';
    if (value >= 2.5) return 'Good';
    if (value >= 1.5) return 'Fair';
    if (value > 0) return 'Needs Improvement';
    return 'Tap stars to rate';
  }

  Future<void> _submit() async {
    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a star rating'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await _userService.submitAppRating(
      rating: _rating,
      feedback: _feedbackController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Thanks for your feedback!'),
          backgroundColor: Colors.green[700],
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.error ?? 'Unable to submit feedback right now'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  Widget _buildStar(int index) {
    final isSelected = index <= _rating;
    return IconButton(
      onPressed: _isSubmitting
          ? null
          : () {
              setState(() => _rating = index.toDouble());
              if (!_feedbackFocusNode.hasFocus) {
                _feedbackFocusNode.requestFocus();
              }
            },
      icon: Icon(
        isSelected ? Icons.star_rounded : Icons.star_border_rounded,
        size: 38,
        color: isSelected ? const Color(0xFFFFB800) : Colors.grey.shade400,
      ),
      splashRadius: 24,
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _ratingLabel(_rating);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 238, 214, 226),
      appBar: AppBar(
        title: const Text(
          'Rate App',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How was your experience?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your rating and feedback help us improve the app quality. '
                    'You can update your previous rating anytime.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: List.generate(
                        5,
                        (index) => _buildStar(index + 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _rating > 0
                            ? const Color(0xFF1E3A8A)
                            : Colors.grey,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _feedbackController,
                    focusNode: _feedbackFocusNode,
                    enabled: !_isSubmitting,
                    minLines: 5,
                    maxLines: 7,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Feedback',
                      hintText: 'Tell us what you liked or what we can improve',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF2563EB),
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5C8A),
                        disabledBackgroundColor: const Color(0xFF93C5FD),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Save Rating',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
