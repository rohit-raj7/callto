/// User model matching backend User schema
class User {
  final String userId;
  final String? listenerId;
  final String? phoneNumber;
  final String? email;
  final String? authProvider;
  final String? googleId;
  final String? facebookId;
  final String? fullName;
  final String? displayName;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? city;
  final String? country;
  final String? avatarUrl;
  final String? bio;
  final String accountType;
  final bool isVerified;
  final bool isActive;
  final double walletBalance;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final bool isFirstTimeUser;
  final bool offerUsed;
  final int? offerMinutesLimit;
  final double? offerFlatPrice;

  User({
    required this.userId,
    this.listenerId,
    this.phoneNumber,
    this.email,
    this.authProvider,
    this.googleId,
    this.facebookId,
    this.fullName,
    this.displayName,
    this.gender,
    this.dateOfBirth,
    this.city,
    this.country,
    this.avatarUrl,
    this.bio,
    this.accountType = 'user',
    this.isVerified = false,
    this.isActive = true,
    this.walletBalance = 0,
    this.createdAt,
    this.lastLoginAt,
    this.isFirstTimeUser = false,
    this.offerUsed = false,
    this.offerMinutesLimit,
    this.offerFlatPrice,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id']?.toString() ?? '',
      listenerId: json['listener_id']?.toString(),
      phoneNumber: json['phone_number'],
      email: json['email'],
      authProvider: json['auth_provider'],
      googleId: json['google_id'],
      facebookId: json['facebook_id'],
      fullName: json['full_name'],
      displayName: json['display_name'],
      gender: json['gender'],
      dateOfBirth: json['date_of_birth'] != null 
          ? DateTime.tryParse(json['date_of_birth']) 
          : null,
      city: json['city'],
      country: json['country'],
      avatarUrl: json['avatar_url'],
      bio: json['bio'],
      accountType: json['account_type'] ?? 'user',
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      walletBalance: _safeParseDouble(json['wallet_balance']),
      isFirstTimeUser: json['is_first_time_user'] ?? false,
      offerUsed: json['offer_used'] ?? false,
      offerMinutesLimit: _safeParseInt(json['offer_minutes_limit']),
      offerFlatPrice: _safeParseDouble(json['offer_flat_price']),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      lastLoginAt: json['last_login_at'] != null 
          ? DateTime.tryParse(json['last_login_at']) 
          : null,
    );
  }

  /// Helper to safely parse doubles from string or numeric values
  static double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int? _safeParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'listener_id': listenerId,
      'phone_number': phoneNumber,
      'email': email,
      'auth_provider': authProvider,
      'google_id': googleId,
      'facebook_id': facebookId,
      'full_name': fullName,
      'display_name': displayName,
      'gender': gender,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'city': city,
      'country': country,
      'avatar_url': avatarUrl,
      'bio': bio,
      'account_type': accountType,
      'is_verified': isVerified,
      'is_active': isActive,
      'wallet_balance': walletBalance,
      'is_first_time_user': isFirstTimeUser,
      'offer_used': offerUsed,
      'offer_minutes_limit': offerMinutesLimit,
      'offer_flat_price': offerFlatPrice,
      'created_at': createdAt?.toIso8601String(),
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }

  /// Check if user has a complete profile
  bool get hasCompleteProfile {
    return displayName != null && 
           displayName!.isNotEmpty && 
           gender != null;
  }

  /// Get initials for avatar
  String get initials {
    if (displayName != null && displayName!.isNotEmpty) {
      final parts = displayName!.split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName![0].toUpperCase();
    }
    if (fullName != null && fullName!.isNotEmpty) {
      return fullName![0].toUpperCase();
    }
    return 'U';
  }

  /// Check if user is a listener
  bool get isListener => accountType == 'listener';
}
