import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Storage service for persisting data locally
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userDataKey = 'user_data';
  static const String _isListenerKey = 'is_listener';
  static const String _genderKey = 'gender';
  static const String _emailKey = 'email';
  static const String _userProfileCompleteKey = 'user_profile_complete';
  static const String _listenerProfileCompleteKey = 'listener_profile_complete';
  static const String _displayNameKey = 'display_name';
  static const String _cityKey = 'city';
  static const String _avatarUrlKey = 'avatar_url';
  static const String _languageKey = 'language';
  static const String _formDataKey = 'form_data';
  static const String _dobKey = 'dob';
  static const String _mobileKey = 'mobile';
  static const String _deletedMessagesKey = 'deleted_messages'; // For local delete for me
  static const String _deletedForEveryoneKey = 'deleted_for_everyone'; // For delete for everyone placeholders
  static const String _callRateConfigKey = 'call_rate_config';
  
    /// Save date of birth
    Future<void> saveDob(String dob) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_dobKey, dob);
    }

    /// Get date of birth
    Future<String?> getDob() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dobKey);
    }

    /// Save mobile number
    Future<void> saveMobile(String mobile) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_mobileKey, mobile);
    }

    /// Get mobile number
    Future<String?> getMobile() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_mobileKey);
    }

  Future<void> saveCallRateConfig(Map<String, dynamic> config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_callRateConfigKey, jsonEncode(config));
  }

  Future<Map<String, dynamic>?> getCallRateConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_callRateConfigKey);
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }
  
  // Listener-specific keys
  static const String _listenerProfessionalNameKey = 'listener_professional_name';
  static const String _listenerOriginalNameKey = 'listener_original_name';
  static const String _listenerAgeKey = 'listener_age';
  static const String _listenerCityKey = 'listener_city';
  static const String _listenerAvatarUrlKey = 'listener_avatar_url';
  static const String _listenerLanguageKey = 'listener_language';
  static const String _listenerExperiencesKey = 'listener_experiences';
  static const String _listenerRatePerMinuteKey = 'listener_rate_per_minute';
  static const String _listenerVoiceVerifiedKey = 'listener_voice_verified';
  static const String _listenerVoiceUrlKey = 'listener_voice_url';
  static const String _listenerVoiceLocalPathKey = 'listener_voice_local_path';
  static const String _listenerVoiceBase64Key = 'listener_voice_base64';
  static const String _listenerVoiceMimeTypeKey = 'listener_voice_mime_type';
  static const String _listenerSpecialtiesKey = 'listener_specialties';

  /// Save authentication token
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  /// Get authentication token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Clear authentication token
  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// Save user ID
  Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  /// Save email
  Future<void> saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_emailKey, email);
  }

  /// Get email
  Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  /// Save user data as JSON string
  Future<void> saveUserData(String userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userDataKey, userData);
  }

  /// Get user data
  Future<String?> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userDataKey);
  }

  /// Save listener status
  Future<void> saveIsListener(bool isListener) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isListenerKey, isListener);
  }

  /// Get listener status
  Future<bool> getIsListener() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isListenerKey) ?? false;
  }

  /// Save user profile completion flag
  Future<void> saveUserProfileComplete(bool isComplete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_userProfileCompleteKey, isComplete);
  }

  /// Get user profile completion flag
  Future<bool> getUserProfileComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_userProfileCompleteKey) ?? false;
  }

  /// Save listener profile completion flag
  Future<void> saveListenerProfileComplete(bool isComplete) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_listenerProfileCompleteKey, isComplete);
  }

  /// Get listener profile completion flag
  Future<bool> getListenerProfileComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_listenerProfileCompleteKey) ?? false;
  }

  /// Save gender
  Future<void> saveGender(String gender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_genderKey, gender);
  }

  /// Get gender
  Future<String?> getGender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_genderKey);
  }

  /// Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear all stored data (logout)
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userDataKey);
    await prefs.remove(_isListenerKey);
    await prefs.remove(_genderKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_userProfileCompleteKey);
    await prefs.remove(_listenerProfileCompleteKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_cityKey);
    await prefs.remove(_avatarUrlKey);
    await prefs.remove(_languageKey);
    await prefs.remove(_formDataKey);
  }

  /// Clear user profile data (but keep auth identity)
  Future<void> clearUserProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_genderKey);
    await prefs.remove(_displayNameKey);
    await prefs.remove(_cityKey);
    await prefs.remove(_avatarUrlKey);
    await prefs.remove(_languageKey);
    await prefs.remove(_dobKey);
    await prefs.remove(_mobileKey);
    await prefs.remove(_userProfileCompleteKey);
  }

  /// Save display name
  Future<void> saveDisplayName(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayNameKey, displayName);
  }

  /// Get display name
  Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  /// Save city
  Future<void> saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, city);
  }

  /// Get city
  Future<String?> getCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cityKey);
  }

  /// Save avatar URL
  Future<void> saveAvatarUrl(String avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarUrlKey, avatarUrl);
  }

  /// Get avatar URL
  Future<String?> getAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarUrlKey);
  }

  /// Save language
  Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, language);
  }

  /// Get language
  Future<String?> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey);
  }

  /// Get all user form data as map
  Future<Map<String, String?>> getUserFormData() async {
    return {
      'gender': await getGender(),
      'displayName': await getDisplayName(),
      'city': await getCity(),
      'avatarUrl': await getAvatarUrl(),
      'language': await getLanguage(),
      'dob': await getDob(),
      'mobile': await getMobile(),
    };
  }

  // ============ LISTENER FORM DATA METHODS ============

  /// Save listener professional name (display name)
  Future<void> saveListenerProfessionalName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerProfessionalNameKey, name);
  }

  /// Get listener professional name
  Future<String?> getListenerProfessionalName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerProfessionalNameKey);
  }

  /// Save listener original name
  Future<void> saveListenerOriginalName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerOriginalNameKey, name);
  }

  /// Get listener original name
  Future<String?> getListenerOriginalName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerOriginalNameKey);
  }

  /// Save listener age
  Future<void> saveListenerAge(int age) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_listenerAgeKey, age);
  }

  /// Get listener age
  Future<int?> getListenerAge() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_listenerAgeKey);
  }

  /// Save listener city
  Future<void> saveListenerCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerCityKey, city);
  }

  /// Get listener city
  Future<String?> getListenerCity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerCityKey);
  }

  /// Save listener avatar URL
  Future<void> saveListenerAvatarUrl(String avatarUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerAvatarUrlKey, avatarUrl);
  }

  /// Get listener avatar URL
  Future<String?> getListenerAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerAvatarUrlKey);
  }

  /// Save listener language
  Future<void> saveListenerLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerLanguageKey, language);
  }

  /// Get listener language
  Future<String?> getListenerLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerLanguageKey);
  }

  /// Save listener single experience (primary concern)
  Future<void> saveListenerExperience(String experience) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerExperiencesKey, experience);
  }

  /// Get listener single experience
  Future<String> getListenerExperience() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerExperiencesKey) ?? '';
  }

  /// Backward compatibility: Save experiences list (deprecated, kept for compatibility)
  @Deprecated('Use saveListenerExperience instead')
  Future<void> saveListenerExperiences(List<String> experiences) async {
    final prefs = await SharedPreferences.getInstance();
    if (experiences.isNotEmpty) {
      // Save as single string - just the first one or join them
      await prefs.setString(_listenerExperiencesKey, experiences.first);
    } else {
      await prefs.setString(_listenerExperiencesKey, '');
    }
  }

  /// Backward compatibility: Get experiences list
  @Deprecated('Use getListenerExperience instead')
  Future<List<String>> getListenerExperiences() async {
    final prefs = await SharedPreferences.getInstance();
    final exp = prefs.getString(_listenerExperiencesKey) ?? '';
    return exp.isNotEmpty ? [exp] : [];
  }

  /// Save listener rate per minute
  Future<void> saveListenerRatePerMinute(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_listenerRatePerMinuteKey, rate);
  }

  /// Get listener rate per minute
  Future<double> getListenerRatePerMinute() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_listenerRatePerMinuteKey) ?? 1.0;
  }

  /// Save listener voice verification status
  Future<void> saveListenerVoiceVerified(bool verified) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_listenerVoiceVerifiedKey, verified);
  }

  /// Get listener voice verification status
  Future<bool> getListenerVoiceVerified() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_listenerVoiceVerifiedKey) ?? false;
  }

  /// Save listener voice URL (Google Drive link)
  Future<void> saveListenerVoiceUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerVoiceUrlKey, url);
  }

  /// Get listener voice URL
  Future<String?> getListenerVoiceUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerVoiceUrlKey);
  }

  /// Save listener voice local file path
  Future<void> saveListenerVoiceLocalPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerVoiceLocalPathKey, path);
  }

  /// Get listener voice local file path
  Future<String?> getListenerVoiceLocalPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerVoiceLocalPathKey);
  }

  /// Save listener voice base64 data (for upload after listener creation)
  Future<void> saveListenerVoiceBase64(String base64Data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerVoiceBase64Key, base64Data);
  }

  /// Get listener voice base64 data
  Future<String?> getListenerVoiceBase64() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerVoiceBase64Key);
  }

  /// Save listener voice mime type
  Future<void> saveListenerVoiceMimeType(String mimeType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_listenerVoiceMimeTypeKey, mimeType);
  }

  /// Get listener voice mime type
  Future<String?> getListenerVoiceMimeType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_listenerVoiceMimeTypeKey);
  }

  /// Save listener specialties
  Future<void> saveListenerSpecialties(List<String> specialties) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_listenerSpecialtiesKey, specialties);
  }

  /// Get listener specialties
  Future<List<String>> getListenerSpecialties() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_listenerSpecialtiesKey) ?? [];
  }

  /// Get all listener form data as map
  Future<Map<String, dynamic>> getListenerFormData() async {
    return {
      'professionalName': await getListenerProfessionalName(),
      'originalName': await getListenerOriginalName(),
      'age': await getListenerAge(),
      'city': await getListenerCity(),
      'avatarUrl': await getListenerAvatarUrl(),
      'language': await getListenerLanguage(),
      'experience': await getListenerExperience(), // Single experience string
      'ratePerMinute': await getListenerRatePerMinute(),
      'voiceVerified': await getListenerVoiceVerified(),
      'specialties': await getListenerSpecialties(),
    };
  }

  /// Clear all listener form data
  Future<void> clearListenerFormData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_listenerProfessionalNameKey);
    await prefs.remove(_listenerOriginalNameKey);
    await prefs.remove(_listenerAgeKey);
    await prefs.remove(_listenerCityKey);
    await prefs.remove(_listenerAvatarUrlKey);
    await prefs.remove(_listenerLanguageKey);
    await prefs.remove(_listenerExperiencesKey);
    await prefs.remove(_listenerRatePerMinuteKey);
    await prefs.remove(_listenerVoiceVerifiedKey);
    await prefs.remove(_listenerVoiceUrlKey);
    await prefs.remove(_listenerVoiceLocalPathKey);
    await prefs.remove(_listenerVoiceBase64Key);
    await prefs.remove(_listenerVoiceMimeTypeKey);
    await prefs.remove(_listenerSpecialtiesKey);
  }

  // ============================================
  // MESSAGE DELETE STORAGE (WhatsApp-like delete feature)
  // ============================================

  /// Add a message ID to local "deleted for me" list
  /// These messages are hidden only on this device
  Future<void> addDeletedForMe(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_deletedMessagesKey) ?? [];
    if (!deleted.contains(messageId)) {
      deleted.add(messageId);
      await prefs.setStringList(_deletedMessagesKey, deleted);
    }
  }

  /// Get all message IDs deleted locally (delete for me)
  Future<Set<String>> getDeletedForMe() async {
    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_deletedMessagesKey) ?? [];
    return deleted.toSet();
  }

  /// Check if a message is deleted for me
  Future<bool> isDeletedForMe(String messageId) async {
    final deleted = await getDeletedForMe();
    return deleted.contains(messageId);
  }

  /// Add a message ID to "deleted for everyone" placeholder list
  /// These show "This message was deleted" on both devices
  Future<void> addDeletedForEveryone(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_deletedForEveryoneKey) ?? [];
    if (!deleted.contains(messageId)) {
      deleted.add(messageId);
      await prefs.setStringList(_deletedForEveryoneKey, deleted);
    }
  }

  /// Get all message IDs deleted for everyone
  Future<Set<String>> getDeletedForEveryone() async {
    final prefs = await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_deletedForEveryoneKey) ?? [];
    return deleted.toSet();
  }

  /// Check if a message was deleted for everyone
  Future<bool> isDeletedForEveryone(String messageId) async {
    final deleted = await getDeletedForEveryone();
    return deleted.contains(messageId);
  }

  /// Remove a message ID from deleted lists (if needed for cleanup)
  Future<void> removeFromDeletedLists(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    
    final deletedForMe = prefs.getStringList(_deletedMessagesKey) ?? [];
    deletedForMe.remove(messageId);
    await prefs.setStringList(_deletedMessagesKey, deletedForMe);
    
    final deletedForEveryone = prefs.getStringList(_deletedForEveryoneKey) ?? [];
    deletedForEveryone.remove(messageId);
    await prefs.setStringList(_deletedForEveryoneKey, deletedForEveryone);
  }
}
