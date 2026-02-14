import 'dart:convert';
import 'api_service.dart';
import 'api_config.dart';
import 'storage_service.dart';
import '../models/user_model.dart';

/// Authentication Service for handling login/signup
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  final StorageService _storage = StorageService();

  User? _currentUser;
  User? get currentUser => _currentUser;

  /// Social login with Google or Facebook
  /// Returns true if login successful, false otherwise
  Future<AuthResult> socialLogin({
    required String provider,
    required String token,
    String? fcmToken,
  }) async {
    final response = await _api.post(
      ApiConfig.socialLogin,
      body: {
        'provider': provider,
        'token': token,
        if (fcmToken != null) 'fcm_token': fcmToken,
      },
    );

    if (response.isSuccess) {
      final data = response.data;
      final isNewUser = data['isNewUser'] ?? false;
      
      // Save token
      await _storage.saveToken(data['token']);
      
      // Parse and save user
      final user = User.fromJson(data['user']);
      _currentUser = user;
      await _storage.saveUserId(user.userId);
      if (user.email != null && user.email!.isNotEmpty) {
        await _storage.saveEmail(user.email!);
      }

      if (isNewUser) {
        await _storage.clearUserProfileData();
        await _storage.clearListenerFormData();
        await _storage.saveIsListener(false);
        await _storage.saveUserProfileComplete(false);
        await _storage.saveListenerProfileComplete(false);
      } else {
        await _storage.saveUserData(jsonEncode(data['user']));
        // Persist commonly used profile fields to local storage so profile pages
        // show data after subsequent logins without requiring extra onboarding steps.
        try {
          if (user.displayName != null && user.displayName!.isNotEmpty) {
            await _storage.saveDisplayName(user.displayName!);
          }
          if (user.city != null && user.city!.isNotEmpty) {
            await _storage.saveCity(user.city!);
          }
          if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
            await _storage.saveAvatarUrl(user.avatarUrl!);
          }
          if (user.gender != null && user.gender!.isNotEmpty) {
            await _storage.saveGender(user.gender!);
          }
        } catch (_) {
          // Ignore any storage errors here; profile page will fallback to defaults.
        }

        // Check if listener
        if (user.accountType == 'listener') {
          await _storage.saveIsListener(true);
          await _storage.saveListenerProfileComplete(true);
        }

        // Mark user profile as complete if backend data indicates so
        if (user.hasCompleteProfile) {
          await _storage.saveUserProfileComplete(true);
        }
      }
      
      return AuthResult(
        success: true,
        user: user,
        isNewUser: isNewUser,
        message: data['message'],
      );
    } else {
      return AuthResult(
        success: false,
        error: response.error ?? 'Login failed',
      );
    }
  }

  /// Complete profile registration after social login
  Future<AuthResult> completeRegistration({
    String? email,
    String? fullName,
    String? displayName,
    String? gender,
    String? dateOfBirth,
    String? city,
    String? country,
    String? bio,
  }) async {
    final response = await _api.post(
      ApiConfig.register,
      body: {
        if (email != null) 'email': email,
        if (fullName != null) 'full_name': fullName,
        if (displayName != null) 'display_name': displayName,
        if (gender != null) 'gender': gender,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (bio != null) 'bio': bio,
      },
    );

    if (response.isSuccess) {
      final user = User.fromJson(response.data['user']);
      _currentUser = user;
      await _storage.saveUserData(jsonEncode(response.data['user']));
      
      return AuthResult(
        success: true,
        user: user,
        message: response.data['message'],
      );
    } else {
      return AuthResult(
        success: false,
        error: response.error ?? 'Registration failed',
      );
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      await _api.post(ApiConfig.logout);
    } catch (e) {
      // Ignore logout API errors
    }
    
    _currentUser = null;
    await _storage.clearAll();
  }

  /// Check if user is logged in and load user data
  Future<bool> checkLoginStatus() async {
    final isLoggedIn = await _storage.isLoggedIn();
    
    if (isLoggedIn) {
      final userData = await _storage.getUserData();
      if (userData != null) {
        try {
          _currentUser = User.fromJson(jsonDecode(userData));
        } catch (e) {
          // Invalid stored data
          await _storage.clearAll();
          return false;
        }
      }
      return true;
    }
    
    return false;
  }

  /// Refresh user data from server
  Future<User?> refreshUserData() async {
    final response = await _api.get(ApiConfig.userProfile);
    
    if (response.isSuccess) {
      final user = User.fromJson(response.data['user']);
      _currentUser = user;
      await _storage.saveUserData(jsonEncode(response.data['user']));
      // Also persist a few profile fields locally so UI can immediately reflect them
      try {
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          await _storage.saveDisplayName(user.displayName!);
        }
        if (user.city != null && user.city!.isNotEmpty) {
          await _storage.saveCity(user.city!);
        }
        if (user.avatarUrl != null && user.avatarUrl!.isNotEmpty) {
          await _storage.saveAvatarUrl(user.avatarUrl!);
        }
        if (user.gender != null && user.gender!.isNotEmpty) {
          await _storage.saveGender(user.gender!);
        }
        if (user.email != null && user.email!.isNotEmpty) {
          await _storage.saveEmail(user.email!);
        }
      } catch (_) {
        // ignore
      }
      // Ensure local listener flag matches backend
      if (user.accountType == 'listener') {
        await _storage.saveIsListener(true);
        await _storage.saveListenerProfileComplete(true);
      } else {
        await _storage.saveIsListener(false);
      }
      if (user.hasCompleteProfile) {
        await _storage.saveUserProfileComplete(true);
      }
      return user;
    }
    
    return null;
  }
}

/// Auth result class
class AuthResult {
  final bool success;
  final User? user;
  final bool isNewUser;
  final String? message;
  final String? error;

  AuthResult({
    required this.success,
    this.user,
    this.isNewUser = false,
    this.message,
    this.error,
  });
}
