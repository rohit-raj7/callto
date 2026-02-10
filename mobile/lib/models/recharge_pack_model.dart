class RechargePack {
  final String id;
  final double amount;
  final double extraPercentOrAmount;
  final String? badgeText;
  final int sortOrder;

  RechargePack({
    required this.id,
    required this.amount,
    required this.extraPercentOrAmount,
    this.badgeText,
    required this.sortOrder,
  });

  factory RechargePack.fromJson(Map<String, dynamic> json) {
    return RechargePack(
      id: json['id'],
      amount: double.parse(json['amount'].toString()),
      extraPercentOrAmount: double.parse(json['extra_percent_or_amount'].toString()),
      badgeText: json['badge_text'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'extra_percent_or_amount': extraPercentOrAmount,
      'badge_text': badgeText,
      'sort_order': sortOrder,
    };
  }
}
