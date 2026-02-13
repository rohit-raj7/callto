import 'dart:convert';
import 'api_service.dart';
import 'api_config.dart';
import 'storage_service.dart';
import '../models/user_model.dart';

/// Service for managing user-related API calls
class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  /// Helper to safely parse doubles from string or numeric values
  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Get current user's profile
  Future<UserResult> getProfile() async {
    final response = await _api.get(ApiConfig.userProfile);

    if (response.isSuccess) {
      final user = User.fromJson(response.data['user']);
      await _storage.saveUserData(jsonEncode(response.data['user']));

      return UserResult(success: true, user: user);
    } else {
      return UserResult(
        success: false,
        error: response.error ?? 'Failed to fetch profile',
      );
    }
  }

  /// Update user profile
  Future<UserResult> updateProfile({
    String? email,
    String? fullName,
    String? displayName,
    String? gender,
    String? dateOfBirth,
    String? city,
    String? country,
    String? avatarUrl,
    String? bio,
  }) async {
    final body = <String, dynamic>{};
    if (email != null) body['email'] = email;
    if (fullName != null) body['full_name'] = fullName;
    if (displayName != null) body['display_name'] = displayName;
    if (gender != null) body['gender'] = gender;
    if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
    if (city != null) body['city'] = city;
    if (country != null) body['country'] = country;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (bio != null) body['bio'] = bio;

    final response = await _api.put(ApiConfig.userProfile, body: body);

    if (response.isSuccess) {
      final user = User.fromJson(response.data['user']);
      await _storage.saveUserData(jsonEncode(response.data['user']));

      return UserResult(
        success: true,
        user: user,
        message: response.data['message'],
      );
    } else {
      return UserResult(
        success: false,
        error: response.error ?? 'Failed to update profile',
      );
    }
  }

  /// Get user by ID (public profile)
  Future<UserResult> getUserById(String userId) async {
    final response = await _api.get('${ApiConfig.apiBase}/users/$userId');

    if (response.isSuccess) {
      final user = User.fromJson(response.data['user']);

      return UserResult(success: true, user: user);
    } else {
      return UserResult(
        success: false,
        error: response.error ?? 'Failed to fetch user',
      );
    }
  }

  /// Add language preference
  Future<bool> addLanguage({
    required String language,
    String proficiencyLevel = 'Basic',
  }) async {
    final response = await _api.post(
      ApiConfig.userLanguages,
      body: {'language': language, 'proficiency_level': proficiencyLevel},
    );

    return response.isSuccess;
  }

  /// Get user languages
  Future<List<Map<String, dynamic>>> getLanguages() async {
    final response = await _api.get('${ApiConfig.userLanguages}/me');

    if (response.isSuccess) {
      final List<dynamic> languagesJson = response.data['languages'] ?? [];
      return languagesJson.cast<Map<String, dynamic>>();
    }

    return [];
  }

  /// Delete language
  Future<bool> deleteLanguage(String languageId) async {
    final response = await _api.delete(
      '${ApiConfig.userLanguages}/$languageId',
    );
    return response.isSuccess;
  }

  /// Get wallet balance
  Future<WalletResult> getWallet() async {
    final response = await _api.get(ApiConfig.userWallet);

    if (response.isSuccess) {
      final data = response.data is Map
          ? response.data as Map
          : <String, dynamic>{};
      final wallet = data['wallet'] is Map ? data['wallet'] as Map : data;
      final transactions = wallet['transactions'] ?? data['transactions'] ?? [];
      return WalletResult(
        success: true,
        balance: _safeParseDouble(wallet['balance']),
        transactions: transactions is List ? transactions : [],
      );
    } else {
      return WalletResult(
        success: false,
        error: response.error ?? 'Failed to fetch wallet',
      );
    }
  }

  /// Add balance to wallet
  Future<WalletResult> addBalance(
    double amount, {
    String? paymentId,
    String? packId,
  }) async {
    final response = await _api.post(
      '${ApiConfig.userWallet}/add',
      body: {
        'amount': amount,
        if (paymentId != null) 'payment_id': paymentId,
        if (packId != null) 'pack_id': packId,
        'payment_method': 'razorpay',
      },
    );

    if (response.isSuccess) {
      return WalletResult(
        success: true,
        balance: _safeParseDouble(response.data['balance']),
        bonusAmount: _safeParseDouble(response.data['bonus_amount']),
        totalCredited: _safeParseDouble(response.data['total_credited']),
        message: response.data['message'],
      );
    } else {
      return WalletResult(
        success: false,
        error: response.error ?? 'Failed to add balance',
      );
    }
  }

  /// Submit app rating and feedback
  Future<ActionResult> submitAppRating({
    required double rating,
    String? feedback,
  }) async {
    final response = await _api.post(
      ApiConfig.submitAppRating,
      body: {
        'rating': rating,
        if (feedback != null && feedback.trim().isNotEmpty)
          'feedback': feedback.trim(),
      },
    );

    if (response.isSuccess) {
      return ActionResult(
        success: true,
        message:
            response.data['message']?.toString() ?? 'Thanks for your feedback!',
      );
    }

    return ActionResult(
      success: false,
      error: response.error ?? 'Failed to submit app rating',
    );
  }

  /// Block another user
  Future<ActionResult> blockUser(String blockedUserId, {String? reason}) async {
    final response = await _api.post(
      '${ApiConfig.apiBase}/users/block/$blockedUserId',
      body: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    if (response.isSuccess) {
      return ActionResult(
        success: true,
        message:
            response.data['message']?.toString() ?? 'User blocked successfully',
      );
    }

    return ActionResult(
      success: false,
      error: response.error ?? 'Failed to block user',
    );
  }

  /// Unblock a user
  Future<ActionResult> unblockUser(String blockedUserId) async {
    final response = await _api.delete(
      '${ApiConfig.apiBase}/users/block/$blockedUserId',
    );

    if (response.isSuccess) {
      return ActionResult(
        success: true,
        message:
            response.data['message']?.toString() ??
            'User unblocked successfully',
      );
    }

    return ActionResult(
      success: false,
      error: response.error ?? 'Failed to unblock user',
    );
  }

  /// Get users blocked by the current user
  Future<List<BlockedUser>> getBlockedUsers() async {
    final response = await _api.get('${ApiConfig.apiBase}/users/blocked');
    if (!response.isSuccess) return [];

    final List<dynamic> blockedJson = response.data['blocked_users'] ?? [];
    return blockedJson
        .whereType<Map>()
        .map((json) => BlockedUser.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Check if current user has blocked a specific user
  Future<bool> isUserBlocked(String userId) async {
    final blockedUsers = await getBlockedUsers();
    return blockedUsers.any((blockedUser) => blockedUser.userId == userId);
  }

  /// Report another user
  Future<ActionResult> reportUser(
    String reportedUserId, {
    String reportType = 'chat',
    String? description,
  }) async {
    final response = await _api.post(
      '${ApiConfig.apiBase}/users/report/$reportedUserId',
      body: {
        'report_type': reportType,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );

    if (response.isSuccess) {
      return ActionResult(
        success: true,
        message:
            response.data['message']?.toString() ??
            'Report submitted successfully',
      );
    }

    return ActionResult(
      success: false,
      error: response.error ?? 'Failed to submit report',
    );
  }
}

/// Result class for user operations
class UserResult {
  final bool success;
  final User? user;
  final String? message;
  final String? error;

  UserResult({required this.success, this.user, this.message, this.error});
}

/// Result class for wallet operations
class WalletResult {
  final bool success;
  final double balance;
  final double bonusAmount;
  final double totalCredited;
  final List<dynamic> transactions;
  final String? message;
  final String? error;

  WalletResult({
    required this.success,
    this.balance = 0,
    this.bonusAmount = 0,
    this.totalCredited = 0,
    this.transactions = const [],
    this.message,
    this.error,
  });
}

/// Generic result for simple action endpoints
class ActionResult {
  final bool success;
  final String? message;
  final String? error;

  ActionResult({required this.success, this.message, this.error});
}

class BlockedUser {
  final String userId;
  final String? displayName;
  final String? avatarUrl;
  final String? reason;
  final DateTime? blockedAt;

  BlockedUser({
    required this.userId,
    this.displayName,
    this.avatarUrl,
    this.reason,
    this.blockedAt,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      reason: json['reason']?.toString(),
      blockedAt: json['blocked_at'] != null
          ? DateTime.tryParse(json['blocked_at'].toString())
          : null,
    );
  }
}
