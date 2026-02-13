class OfferModel {
  final String offerId;
  final bool isActive;
  final String title;
  final String headline;
  final String subtext;
  final String buttonText;
  final String countdownPrefix;
  final double rechargeAmount;
  final double discountedAmount;
  final double minWalletBalance;
  final DateTime? startsAt;
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
    required this.rechargeAmount,
    required this.discountedAmount,
    required this.minWalletBalance,
    this.startsAt,
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
        fallback: 'Offer ends in',
      ),
      rechargeAmount: _safeParseDouble(
        json['rechargeAmount'] ?? json['recharge_amount'],
      ),
      discountedAmount: _safeParseDouble(
        json['discountedAmount'] ?? json['discounted_amount'],
      ),
      minWalletBalance: _safeParseDouble(
        json['minWalletBalance'] ?? json['min_wallet_balance'],
        fallback: 5,
      ),
      startsAt: _safeParseDate(json['startsAt'] ?? json['starts_at']),
      expiresAt: _safeParseDate(json['expiresAt'] ?? json['expires_at']),
      updatedAt: _safeParseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  bool get hasExpired {
    final end = expiresAt;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  bool get hasStarted {
    final start = startsAt;
    if (start == null) return true;
    return !DateTime.now().isBefore(start);
  }

  bool get isLiveNow => isActive && hasStarted && !hasExpired;

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

  static double _safeParseDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  static DateTime? _safeParseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
