import 'dart:typed_data';
import 'api_service.dart';
import 'api_config.dart';
import '../models/listener_model.dart';

/// Service for managing listener-related API calls
class ListenerService {
  static final ListenerService _instance = ListenerService._internal();
  factory ListenerService() => _instance;
  ListenerService._internal();

  final ApiService _api = ApiService();

  /// Get all listeners with optional filters
  Future<ListenerResult> getListeners({
    String? specialty,
    String? language,
    bool? isOnline,
    double? minRating,
    String? city,
    String sortBy = 'rating',
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'sort_by': sortBy,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    
    if (specialty != null) queryParams['specialty'] = specialty;
    if (language != null) queryParams['language'] = language;
    if (isOnline != null) queryParams['is_online'] = isOnline.toString();
    if (minRating != null) queryParams['min_rating'] = minRating.toString();
    if (city != null) queryParams['city'] = city;

    print('[LISTENER_SERVICE] Fetching listeners with params: $queryParams');
    
    final response = await _api.get(
      ApiConfig.listeners,
      queryParams: queryParams,
    );

    print('[LISTENER_SERVICE] Response success: ${response.isSuccess}, data keys: ${response.data?.keys}');

    if (response.isSuccess) {
      final List<dynamic> listenersJson = response.data['listeners'] ?? [];
      print('[LISTENER_SERVICE] Raw listeners count from API: ${listenersJson.length}');
      
      final listeners = <Listener>[];
      for (var json in listenersJson) {
        try {
          final listener = Listener.fromJson(json);
          listeners.add(listener);
        } catch (e) {
          print('[LISTENER_SERVICE] Error parsing listener JSON: $e, data: $json');
        }
      }
      
      print('[LISTENER_SERVICE] Parsed listeners count: ${listeners.length}');
      
      return ListenerResult(
        success: true,
        listeners: listeners,
        count: response.data['count'] ?? listeners.length,
      );
    } else {
      print('[LISTENER_SERVICE] Error: ${response.error}');
      return ListenerResult(
        success: false,
        error: response.error ?? 'Failed to fetch listeners',
      );
    }
  }

  /// Search listeners by query
  Future<ListenerResult> searchListeners(String query) async {
    final response = await _api.get(
      ApiConfig.listenerSearch,
      queryParams: {'q': query},
    );

    if (response.isSuccess) {
      final List<dynamic> listenersJson = response.data['listeners'] ?? [];
      final listeners = listenersJson
          .map((json) => Listener.fromJson(json))
          .toList();
      
      return ListenerResult(
        success: true,
        listeners: listeners,
        count: response.data['count'] ?? listeners.length,
      );
    } else {
      return ListenerResult(
        success: false,
        error: response.error ?? 'Search failed',
      );
    }
  }

  /// Get listener profile by ID
  Future<ListenerDetailResult> getListenerById(String listenerId) async {
    final response = await _api.get('${ApiConfig.listeners}/$listenerId');

    if (response.isSuccess) {
      final listener = Listener.fromJson(response.data['listener']);
      
      return ListenerDetailResult(
        success: true,
        listener: listener,
        stats: response.data['stats'],
        recentRatings: response.data['recent_ratings'],
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to fetch listener',
      );
    }
  }

  /// Create listener profile (become a listener)
  Future<ListenerDetailResult> becomeListener({
    required String professionalName,
    String? originalName,
    int? age,
    required List<String> specialties,
    required List<String> languages,
    required double ratePerMinute,
    int? experienceYears,
    String? education,
    List<String>? certifications,
    String? avatarUrl,
    String? city,
  }) async {
    final requestBody = {
      'professional_name': professionalName,
      if (originalName != null && originalName.isNotEmpty) 'original_name': originalName,
      if (age != null) 'age': age,
      'specialties': specialties,
      'languages': languages,
      'rate_per_minute': ratePerMinute,
      if (experienceYears != null) 'experience_years': experienceYears,
      if (education != null) 'education': education,
      if (certifications != null && certifications.isNotEmpty) 'certifications': certifications,
      if (avatarUrl != null && avatarUrl.isNotEmpty) 'profile_image': avatarUrl,
      if (city != null && city.isNotEmpty) 'city': city,
    };

    print('becomeListener request body: $requestBody');

    final response = await _api.post(
      ApiConfig.listeners,
      body: requestBody,
    );

    print('becomeListener response: ${response.isSuccess}, error: ${response.error}');

    if (response.isSuccess) {
      final listener = Listener.fromJson(response.data['listener']);
      
      return ListenerDetailResult(
        success: true,
        listener: listener,
        message: response.data['message'],
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to create listener profile',
      );
    }
  }

  /// Update listener profile
  Future<ListenerDetailResult> updateListener(
    String listenerId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _api.put(
      '${ApiConfig.listeners}/$listenerId',
      body: updates,
    );

    if (response.isSuccess) {
      final listener = Listener.fromJson(response.data['listener']);
      
      return ListenerDetailResult(
        success: true,
        listener: listener,
        message: response.data['message'],
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to update listener profile',
      );
    }
  }

  /// Update listener online status
  Future<bool> updateOnlineStatus(String listenerId, bool isOnline) async {
    final response = await _api.put(
      '${ApiConfig.listeners}/$listenerId/status',
      body: {'is_online': isOnline},
    );

    return response.isSuccess;
  }

  /// Send heartbeat to update last active timestamp
  Future<bool> sendHeartbeat() async {
    final response = await _api.post(
      '${ApiConfig.listeners}/heartbeat',
      body: {},
    );

    return response.isSuccess;
  }

  /// Get current user's listener profile
  Future<ListenerDetailResult> getMyProfile() async {
    final response = await _api.get('${ApiConfig.listeners}/me/profile');

    if (response.isSuccess) {
      final listener = Listener.fromJson(response.data['listener']);
      return ListenerDetailResult(
        success: true,
        listener: listener,
        stats: response.data['stats'],
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to fetch my listener profile',
      );
    }
  }

  /// Update listener experiences
  Future<ListenerDetailResult> updateExperiences(String listenerId, List<String> experiences) async {
    final response = await _api.put(
      '${ApiConfig.listeners}/$listenerId/experiences',
      body: {'experiences': experiences},
    );

    if (response.isSuccess) {
      final data = response.data;
      return ListenerDetailResult(
        success: true,
        message: data['message'] ?? 'Experiences updated',
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to update experiences',
      );
    }
  }

  /// Add or update payment details for listener
  Future<ListenerDetailResult> addPaymentDetails(String listenerId, Map<String, dynamic> details) async {
    final response = await _api.post(
      '${ApiConfig.listeners}/$listenerId/payment-details',
      body: details,
    );

    if (response.isSuccess) {
      return ListenerDetailResult(
        success: true,
        message: response.data['message'],
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to save payment details',
      );
    }
  }

  /// Upload voice file to Cloudinary via backend (returns secure_url)
  Future<ListenerDetailResult> uploadVoiceFile({
    required Uint8List fileBytes,
    required String filename,
    required String mimeType,
  }) async {
    final response = await _api.uploadMultipart(
      ApiConfig.uploadVoice,
      fileBytes: fileBytes,
      filename: filename,
      fieldName: 'voiceFile',
      mimeType: mimeType,
    );

    if (response.isSuccess) {
      return ListenerDetailResult(
        success: true,
        message: response.data['secure_url'],
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to upload voice file',
      );
    }
  }

  /// Update voice verification for a listener (sends Cloudinary URL)
  Future<ListenerDetailResult> updateVoiceVerification({
    required String listenerId,
    required String voiceUrl,
  }) async {
    final response = await _api.put(
      '${ApiConfig.listeners}/$listenerId/voice-verification',
      body: {
        'voice_url': voiceUrl,
      },
    );

    if (response.isSuccess) {
      return ListenerDetailResult(
        success: true,
        message: response.data['message'] ?? 'Voice verification updated',
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to update voice verification',
      );
    }
  }

  /// Update payment details for current listener
  Future<ListenerDetailResult> updatePaymentDetails(Map<String, dynamic> details) async {
    final response = await _api.put(
      '${ApiConfig.listeners}/me/payment-details',
      body: details,
    );

    if (response.isSuccess) {
      return ListenerDetailResult(
        success: true,
        message: response.data['message'] ?? 'Payment details updated successfully',
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to update payment details',
      );
    }
  }

  /// Reapply for verification after rejection (max 3 attempts)
  Future<ListenerDetailResult> reapplyForVerification() async {
    final response = await _api.post(
      '${ApiConfig.listeners}/me/reapply',
      body: {},
    );

    if (response.isSuccess) {
      return ListenerDetailResult(
        success: true,
        message: response.data['message'] ?? 'Reapplication submitted successfully',
      );
    } else {
      return ListenerDetailResult(
        success: false,
        error: response.error ?? 'Failed to submit reapplication',
      );
    }
  }
}

/// Result class for list of listeners
class ListenerResult {
  final bool success;
  final List<Listener> listeners;
  final int count;
  final String? error;

  ListenerResult({
    required this.success,
    this.listeners = const [],
    this.count = 0,
    this.error,
  });
}

/// Result class for single listener
class ListenerDetailResult {
  final bool success;
  final Listener? listener;
  final Map<String, dynamic>? stats;
  final List<dynamic>? recentRatings;
  final String? message;
  final String? error;

  ListenerDetailResult({
    required this.success,
    this.listener,
    this.stats,
    this.recentRatings,
    this.message,
    this.error,
  });
}
