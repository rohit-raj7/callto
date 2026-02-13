class OfferModel {
  final String offerId;
  final bool isActive;
  final String title;
  final String headline;
  final String subtext;
  final String buttonText;
  final String countdownPrefix;
  final String? videoUrl;
  final double minWalletBalance;
  final DateTime? expiresAt;
  final DateTime? updatedAt;

  OfferModel({
    required this.offerId,
    required this.isActive,
    required this.title,
    required this.headline,
    required this.subtext,
    required this.buttonText,
    required this.countdownPrefix,
    this.videoUrl,
    required this.minWalletBalance,
    this.expiresAt,
    this.updatedAt,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    return OfferModel(
      offerId: _safeString(json['offerId'] ?? json['offer_id']),
      isActive: json['isActive'] == true || json['is_active'] == true,
      title: _safeString(json['title'], fallback: 'Limited Time Offer'),
      headline: _safeString(json['headline'], fallback: 'Flat 25% OFF'),
      subtext: _safeString(
        json['subtext'],
        fallback: 'on recharge of \u20B9100',
      ),
      buttonText: _safeString(
        json['buttonText'] ?? json['button_text'],
        fallback: 'Recharge for \u20B975',
      ),
      countdownPrefix: _safeString(
        json['countdownPrefix'] ?? json['countdown_prefix'],
        fallback: 'Offer ends in 12h',
      ),
      videoUrl: _safeNullableString(json['videoUrl'] ?? json['video_url']),
      minWalletBalance: _safeParseDouble(
        json['minWalletBalance'] ?? json['min_wallet_balance'],
        fallback: 5,
      ),
      expiresAt: _safeParseDate(json['expiresAt'] ?? json['expires_at']),
      updatedAt: _safeParseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  bool get hasExpired {
    final end = expiresAt;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  bool get isLiveNow => isActive && !hasExpired;

  Duration get remainingDuration {
    final end = expiresAt;
    if (end == null) return Duration.zero;
    final now = DateTime.now();
    if (end.isBefore(now)) return Duration.zero;
    return end.difference(now);
  }

  static String _safeString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static String? _safeNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double _safeParseDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  Map<String, dynamic> toJson() => {
    'offerId': offerId,
    'isActive': isActive,
    'title': title,
    'headline': headline,
    'subtext': subtext,
    'buttonText': buttonText,
    'countdownPrefix': countdownPrefix,
    'videoUrl': videoUrl,
    'minWalletBalance': minWalletBalance,
    'expiresAt': expiresAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static DateTime? _safeParseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
