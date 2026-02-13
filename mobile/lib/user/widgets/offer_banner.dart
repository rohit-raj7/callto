import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  static const String _defaultVideoUrl =
      'https://video.be/pPzO-dA0tDo?si=RMMNdZufvTGBwmY5';
  static const String _fallbackVideoId = 'pPzO-dA0tDo';

  Timer? _ticker;
  Duration _remainingDuration = Duration.zero;
  bool _expiryNotified = false;
  bool _videoReady = false;
  late final YoutubePlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _setupVideoController();
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
    _videoController.close();
    super.dispose();
  }

  void _setupVideoController() {
    final videoId = _extractYoutubeVideoId(_defaultVideoUrl);

    _videoController = YoutubePlayerController(
      params: const YoutubePlayerParams(
        autoPlay: true,
        mute: true,
        loop: true,
        showControls: false,
        showFullscreenButton: false,
        strictRelatedVideos: true,
        enableCaption: false,
        playsInline: true,
      ),
    );

    _videoController.loadVideoById(videoId: videoId);
    _videoReady = true;
  }

  String _extractYoutubeVideoId(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) return _fallbackVideoId;

    final host = uri.host.toLowerCase();

    if (host.contains('youtu.be') || host.contains('video.be')) {
      if (uri.pathSegments.isNotEmpty) {
        final shortId = uri.pathSegments.first;
        if (_looksLikeYoutubeId(shortId)) {
          return shortId;
        }
      }
    }

    final queryId = uri.queryParameters['v'];
    if (queryId != null && _looksLikeYoutubeId(queryId)) {
      return queryId;
    }

    for (final segment in uri.pathSegments.reversed) {
      if (_looksLikeYoutubeId(segment)) {
        return segment;
      }
    }

    return _fallbackVideoId;
  }

  bool _looksLikeYoutubeId(String value) {
    return RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value.trim());
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

  Widget _sparkle(double size, {double opacity = 0.7}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: opacity * 0.7),
            blurRadius: size * 2,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSurface() {
    if (!_videoReady) {
      return Container(
        color: const Color(0xFF11193D),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    return YoutubePlayer(controller: _videoController);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final headlineSize = compact ? 46.0 : 52.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x66A4B9FF), width: 1.15),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF161D4B), Color(0xFF1B327D), Color(0xFF0C1236)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 70,
                left: 14,
                child: _sparkle(3.5),
              ),
              Positioned(
                top: 182,
                right: 16,
                child: Text(
                  '%',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                bottom: 110,
                left: 26,
                child: _sparkle(2.8, opacity: 0.6),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Color(0xFFE24A5D), Color(0xFF3549A8)],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.alarm_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${widget.offer.countdownPrefix} ${_formatCountdown(_remainingDuration)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.offer.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.offer.headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF94E589),
                      fontSize: headlineSize,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.offer.subtext,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: compact ? 15 : 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFA0CCFF),
                        width: 2,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x77498CFF),
                          blurRadius: 22,
                          spreadRadius: -6,
                        ),
                      ],
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x33426CC2), Color(0x11506DA7)],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: compact ? 1.55 : 1.7,
                        child: _buildVideoSurface(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Ink(
                        height: compact ? 50 : 54,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.24),
                          ),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF1C8AFF), Color(0xFF7855FF)],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x550D4EAA),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.offer.buttonText,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 28 : 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
