import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
    /// Default Cloudinary video URL (direct .mp4 link)
    static const String _defaultVideoUrl =
      'https://res.cloudinary.com/dxxwkuqwc/video/upload/Z._Z_gjzaba.mp4';

  Timer? _ticker;
  Duration _remainingDuration = Duration.zero;
  bool _expiryNotified = false;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
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

    if (oldWidget.offer.offerId != widget.offer.offerId) {
      _disposeVideoPlayer();
      _initVideoPlayer();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _disposeVideoPlayer();
    super.dispose();
  }

  void _disposeVideoPlayer() {
    _videoController?.dispose();
    _videoController = null;
    _videoReady = false;
    _videoError = false;
  }

  void _initVideoPlayer() {
    final videoUrl = _resolveVideoUrl();
    final uri = Uri.tryParse(videoUrl);
    if (uri == null) {
      if (mounted) setState(() => _videoError = true);
      return;
    }

    final controller = VideoPlayerController.networkUrl(uri);
    _videoController = controller;

    controller.initialize().then((_) {
      if (!mounted) return;
      controller.setLooping(true);
      controller.setVolume(1.0); // always unmuted
      controller.play();
      setState(() {
        _videoReady = true;
        _videoError = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _videoReady = false;
        _videoError = true;
      });
    });
  }

  /// Convert a Cloudinary embed URL to a direct MP4 URL, or use as-is if
  /// already a direct link.
  String _resolveVideoUrl() {
    final offerUrl = widget.offer.videoUrl;
    if (offerUrl != null && offerUrl.trim().isNotEmpty) {
      return _toDirectUrl(offerUrl.trim());
    }
    return _defaultVideoUrl;
  }

  /// If the URL is a Cloudinary embed link, extract cloud_name + public_id
  /// and build the direct res.cloudinary.com MP4 URL.
  String _toDirectUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return _defaultVideoUrl;

    // Already a direct video file link (mp4/webm/mov)
    final path = uri.path.toLowerCase();
    if (path.endsWith('.mp4') ||
        path.endsWith('.webm') ||
        path.endsWith('.mov')) {
      return rawUrl;
    }

    // Cloudinary embed player URL (with query params)
    if (uri.host.contains('cloudinary.com')) {
      // Try to extract from query parameters
      final cloudName = uri.queryParameters['cloud_name'];
      final publicId = uri.queryParameters['public_id'];
      if (cloudName != null && publicId != null) {
        return 'https://res.cloudinary.com/$cloudName/video/upload/$publicId.mp4';
      }
      // Try to extract from path (e.g. /embed/dxxwkuqwc/Z._Z_gjzaba)
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 3 && pathSegments[0] == 'embed') {
        final cloudNameFromPath = pathSegments[1];
        final publicIdFromPath = pathSegments[2];
        return 'https://res.cloudinary.com/$cloudNameFromPath/video/upload/$publicIdFromPath.mp4';
      }
    }

    // If it's some other URL, try it directly—video_player might handle it
    return rawUrl;
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

  Widget _buildVideoSurface() {
    if (_videoError) {
      return Container(
        color: const Color(0xFF11193D),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              color: Colors.white.withValues(alpha: 0.5),
              size: 40,
            ),
            const SizedBox(height: 6),
            Text(
              'Video unavailable',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (!_videoReady || _videoController == null) {
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

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final isShortScreen = screenHeight < 700;

        // Responsive sizing
        final headlineSize =
            isShortScreen ? 36.0 : (compact ? 42.0 : 48.0);
        final titleSize =
            isShortScreen ? 13.0 : (compact ? 14.0 : 16.0);
        final subtextSize =
            isShortScreen ? 13.0 : (compact ? 14.0 : 16.0);
        final buttonFontSize =
            isShortScreen ? 22.0 : (compact ? 26.0 : 30.0);
        final buttonHeight =
            isShortScreen ? 42.0 : (compact ? 48.0 : 52.0);
        final videoAspect =
            isShortScreen ? 2.2 : (compact ? 1.7 : 1.8);
        final verticalPad = isShortScreen ? 10.0 : 14.0;
        final innerGap = isShortScreen ? 8.0 : 14.0;
        final postVideoGap = isShortScreen ? 10.0 : 16.0;

        // Constrain max height to avoid overflow
        final maxBannerHeight = screenHeight * 0.68;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxBannerHeight),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              verticalPad, verticalPad, verticalPad, verticalPad + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: const Color(0x66A4B9FF), width: 1.15),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF161D4B),
                  Color(0xFF1B327D),
                  Color(0xFF0C1236),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timer row + close button
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: isShortScreen ? 6 : 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color:
                                  Colors.white.withValues(alpha: 0.25),
                            ),
                            gradient: const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Color(0xFFE24A5D),
                                Color(0xFF3549A8),
                              ],
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
                              Icon(
                                Icons.alarm_rounded,
                                color: Colors.white,
                                size: isShortScreen ? 12 : 14,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '${widget.offer.countdownPrefix} ${_formatCountdown(_remainingDuration)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize:
                                        isShortScreen ? 11 : 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: widget.onClose,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: isShortScreen ? 30 : 34,
                          height: isShortScreen ? 30 : 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: isShortScreen ? 18 : 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: innerGap),

                  // Title
                  Text(
                    widget.offer.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: titleSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Headline
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
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
                  ),
                  const SizedBox(height: 2),

                  // Subtext
                  Text(
                    widget.offer.subtext,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.94),
                      fontSize: subtextSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: innerGap),

                  // Video
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
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
                        colors: [
                          Color(0x33426CC2),
                          Color(0x11506DA7),
                        ],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: videoAspect,
                        child: _buildVideoSurface(),
                      ),
                    ),
                  ),
                  SizedBox(height: postVideoGap),

                  // CTA Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const WalletScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        height: buttonHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xFFFF4081),
                              Color(0xFFFF6090),
                            ],
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x55FF4081),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.offer.buttonText,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
