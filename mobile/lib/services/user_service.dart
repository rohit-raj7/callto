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
      
      return UserResult(
        success: true,
        user: user,
      );
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
      
      return UserResult(
        success: true,
        user: user,
      );
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
      body: {
        'language': language,
        'proficiency_level': proficiencyLevel,
      },
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
    final response = await _api.delete('${ApiConfig.userLanguages}/$languageId');
    return response.isSuccess;
  }

  /// Get wallet balance
  Future<WalletResult> getWallet() async {
    final response = await _api.get(ApiConfig.userWallet);

    if (response.isSuccess) {
      final data = response.data is Map ? response.data as Map : <String, dynamic>{};
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
  Future<WalletResult> addBalance(double amount, {String? paymentId}) async {
    final response = await _api.post(
      '${ApiConfig.userWallet}/add',
      body: {
        'amount': amount,
        if (paymentId != null) 'payment_id': paymentId,
        'payment_method': 'razorpay',
      },
    );

    if (response.isSuccess) {
      return WalletResult(
        success: true,
        balance: _safeParseDouble(response.data['balance']),
        message: response.data['message'],
      );
    } else {
      return WalletResult(
        success: false,
        error: response.error ?? 'Failed to add balance',
      );
    }
  }
}

/// Result class for user operations
class UserResult {
  final bool success;
  final User? user;
  final String? message;
  final String? error;

  UserResult({
    required this.success,
    this.user,
    this.message,
    this.error,
  });
}

/// Result class for wallet operations
class WalletResult {
  final bool success;
  final double balance;
  final List<dynamic> transactions;
  final String? message;
  final String? error;

  WalletResult({
    required this.success,
    this.balance = 0,
    this.transactions = const [],
    this.message,
    this.error,
  });
}
