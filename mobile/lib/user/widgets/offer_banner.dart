import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/offer_model.dart';
import '../nav/profile/wallet.dart';

class OfferBanner extends StatefulWidget {
  const OfferBanner({
    super.key,
    required this.offer,
    required this.onClose,
    this.onExpired,
  });

  final OfferModel offer;
  final VoidCallback onClose;
  final VoidCallback? onExpired;

  @override
  State<OfferBanner> createState() => _OfferBannerState();
}

class _OfferBannerState extends State<OfferBanner> {
  Timer? _ticker;
  Duration _remainingDuration = Duration.zero;
  bool _expiryNotified = false;

  @override
  void initState() {
    super.initState();
    _syncRemainingDuration();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncRemainingDuration();
    });
  }

  @override
  void didUpdateWidget(covariant OfferBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offer.offerId != widget.offer.offerId ||
        oldWidget.offer.expiresAt != widget.offer.expiresAt) {
      _expiryNotified = false;
      _syncRemainingDuration();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncRemainingDuration() {
    final remaining = widget.offer.remainingDuration;
    if (!mounted) return;
    setState(() {
      _remainingDuration = remaining;
    });

    if (remaining <= Duration.zero && !_expiryNotified) {
      _expiryNotified = true;
      widget.onExpired?.call();
    }
  }

  String _formatCountdown(Duration duration) {
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final headlineSize = compact ? 24.0 : 28.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7E5F), Color(0xFFFC4A8B)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${widget.offer.countdownPrefix} ${_formatCountdown(_remainingDuration)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.offer.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.offer.headline,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: headlineSize,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.offer.subtext,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WalletScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDD2F7D),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    widget.offer.buttonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
