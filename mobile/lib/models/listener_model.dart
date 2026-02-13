/// Listener model matching backend Listener schema
class Listener {
  final String listenerId;
  final String userId;
  final String? professionalName;
  final int? age;
  final List<String> specialties;
  final List<String> languages;
  final double ratePerMinute;
  final bool isOnline;
  final bool isAvailable;
  final bool isApproved;
  final bool isBusy;
  final double rating;
  final int totalCalls;
  final int totalMinutes;
  final int? experienceYears;
  final String? education;
  final List<String> certifications;
  final String? avatarUrl;
  final String? bio;
  final String? city;
  final String? country;
  final String? mobileNumber;
  final DateTime? createdAt;
  final Map<String, dynamic>? paymentInfo;
  final String? verificationStatus;
  final String? rejectionReason;
  final int reapplyAttempts;

  Listener({
    required this.listenerId,
    required this.userId,
    this.professionalName,
    this.age,
    this.specialties = const [],
    this.languages = const [],
    this.ratePerMinute = 0,
    this.isOnline = false,
    this.isAvailable = true,
    this.isApproved = false,
    this.isBusy = false,
    this.rating = 0,
    this.totalCalls = 0,
    this.totalMinutes = 0,
    this.experienceYears,
    this.education,
    this.certifications = const [],
    this.avatarUrl,
    this.bio,
    this.city,
    this.country,
    this.mobileNumber,
    this.createdAt,
    this.paymentInfo,
    this.verificationStatus,
    this.rejectionReason,
    this.reapplyAttempts = 0,
  });

  factory Listener.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse doubles from string or numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Listener(
      listenerId: json['listener_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      professionalName: json['professional_name'],
      age: json['age'],
      specialties: _parseStringList(json['specialties']),
      languages: _parseStringList(json['languages']),
      ratePerMinute: parseDouble(json['user_rate_per_min'] ?? json['rate_per_minute']),
      isOnline: json['is_online'] ?? false,
      isAvailable: json['is_available'] ?? true,
      isApproved: json['is_approved'] ?? false,
      isBusy: json['is_busy'] ?? false,
      rating: parseDouble(json['rating'] ?? json['average_rating']),
      totalCalls: json['total_calls'] ?? 0,
      totalMinutes: json['total_minutes'] ?? 0,
      experienceYears: json['experience_years'],
      education: json['education'],
      certifications: _parseStringList(json['certifications']),
      avatarUrl: json['avatar_url'] ?? json['profile_image'],
      bio: json['bio'],
      city: json['city'],
      country: json['country'],
      mobileNumber: json['mobile_number'],
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) 
          : null,
      paymentInfo: json['payment_info'] is Map ? Map<String, dynamic>.from(json['payment_info']) : null,
      verificationStatus: json['verification_status'],
      rejectionReason: json['rejection_reason'],
      reapplyAttempts: json['reapply_attempts'] ?? 0,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      // Handle PostgreSQL array format {a,b,c}
      if (value.startsWith('{') && value.endsWith('}')) {
        return value.substring(1, value.length - 1).split(',');
      }
      return [value];
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'listener_id': listenerId,
      'user_id': userId,
      'professional_name': professionalName,
      'age': age,
      'specialties': specialties,
      'languages': languages,
      'rate_per_minute': ratePerMinute,
      'user_rate_per_min': ratePerMinute,
      'is_online': isOnline,
      'is_available': isAvailable,
      'is_approved': isApproved,
      'is_busy': isBusy,
      'rating': rating,
      'total_calls': totalCalls,
      'total_minutes': totalMinutes,
      'experience_years': experienceYears,
      'education': education,
      'certifications': certifications,
      'avatar_url': avatarUrl,
      'bio': bio,
      'city': city,
      'country': country,
      'mobile_number': mobileNumber,
      'created_at': createdAt?.toIso8601String(),
      'payment_info': paymentInfo,
      'verification_status': verificationStatus,
      'rejection_reason': rejectionReason,
      'reapply_attempts': reapplyAttempts,
    };
  }

  /// Get formatted rate string
  String get formattedRate => '₹${ratePerMinute.toStringAsFixed(0)}/min';

  /// Get first specialty
  String get primarySpecialty => specialties.isNotEmpty ? specialties.first : 'General';

  /// Get formatted languages
  String get formattedLanguages => languages.join(' · ');

  /// Get location string
  String get location {
    if (city != null && country != null) {
      return '$city, $country';
    }
    return city ?? country ?? 'Unknown';
  }
}
