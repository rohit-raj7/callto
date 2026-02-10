import 'api_service.dart';
import 'api_config.dart';
import '../models/call_model.dart';

/// Service for managing call-related API calls
class CallService {
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  final ApiService _api = ApiService();

  /// Initiate a new call
  Future<CallResult> initiateCall({
    required String listenerId,
    String callType = 'audio',
  }) async {
    final response = await _api.post(
      ApiConfig.calls,
      body: {
        'listener_id': listenerId,
        'call_type': callType,
      },
    );

    if (response.isSuccess) {
      final call = Call.fromJson(response.data['call']);
      
      return CallResult(
        success: true,
        call: call,
        message: response.data['message'],
      );
    } else {
      return CallResult(
        success: false,
        error: response.error ?? 'Failed to initiate call',
      );
    }
  }

  /// Get call details by ID
  Future<CallResult> getCallById(String callId) async {
    final response = await _api.get('${ApiConfig.calls}/$callId');

    if (response.isSuccess) {
      final call = Call.fromJson(response.data['call']);
      
      return CallResult(
        success: true,
        call: call,
      );
    } else {
      return CallResult(
        success: false,
        error: response.error ?? 'Failed to fetch call',
      );
    }
  }

  /// Update call status
  Future<CallResult> updateCallStatus({
    required String callId,
    required String status,
    int? durationSeconds,
  }) async {
    final response = await _api.put(
      '${ApiConfig.calls}/$callId/status',
      body: {
        'status': status,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
      },
    );

    if (response.isSuccess) {
      final call = Call.fromJson(response.data['call']);
      
      return CallResult(
        success: true,
        call: call,
        message: response.data['message'],
      );
    } else {
      return CallResult(
        success: false,
        error: response.error ?? 'Failed to update call status',
      );
    }
  }

  /// Finalize call billing
  Future<CallEndResult> endCall({
    required String callId,
    required int durationSeconds,
  }) async {
    final response = await _api.post(
      ApiConfig.callEnd,
      body: {
        'callId': callId,
        'durationSeconds': durationSeconds,
      },
    );

    if (response.isSuccess) {
      final call = response.data['call'] != null
          ? Call.fromJson(response.data['call'])
          : null;
      final summary = response.data['billing'] != null
          ? CallBillingSummary.fromJson(response.data['billing'])
          : null;
      return CallEndResult(
        success: true,
        call: call,
        summary: summary,
        message: response.data['message'],
      );
    } else {
      return CallEndResult(
        success: false,
        error: response.error ?? 'Failed to end call',
      );
    }
  }

  /// Get user's call history
  Future<CallListResult> getCallHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _api.get(
      ApiConfig.callHistory,
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    if (response.isSuccess) {
      final List<dynamic> callsJson = response.data['calls'] ?? [];
      final calls = callsJson.map((json) => Call.fromJson(json)).toList();
      
      return CallListResult(
        success: true,
        calls: calls,
        count: response.data['count'] ?? calls.length,
      );
    } else {
      return CallListResult(
        success: false,
        error: response.error ?? 'Failed to fetch call history',
      );
    }
  }

  /// Get listener's call history (shows callers who called this listener)
  Future<CallListResult> getListenerCallHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _api.get(
      ApiConfig.listenerCallHistory,
      queryParams: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );

    if (response.isSuccess) {
      final List<dynamic> callsJson = response.data['calls'] ?? [];
      final calls = callsJson.map((json) => Call.fromJson(json)).toList();
      
      return CallListResult(
        success: true,
        calls: calls,
        count: response.data['count'] ?? calls.length,
      );
    } else {
      return CallListResult(
        success: false,
        error: response.error ?? 'Failed to fetch call history',
      );
    }
  }

  /// Submit a listener rating for a call
  Future<RatingSubmitResult> submitRating({
    required String callId,
    required double rating,
  }) async {
    final response = await _api.post(
      ApiConfig.submitRating,
      body: {
        'callId': callId,
        'rating': rating,
      },
    );

    if (response.isSuccess) {
      return RatingSubmitResult(
        success: true,
        message: response.data['message'],
      );
    }

    return RatingSubmitResult(
      success: false,
      error: response.error ?? 'Failed to submit rating',
    );
  }

  /// Get user's active calls
  Future<CallListResult> getActiveCalls() async {
    final response = await _api.get(ApiConfig.activeCalls);

    if (response.isSuccess) {
      final List<dynamic> callsJson = response.data['calls'] ?? [];
      final calls = callsJson.map((json) => Call.fromJson(json)).toList();
      
      return CallListResult(
        success: true,
        calls: calls,
        count: response.data['count'] ?? calls.length,
      );
    } else {
      return CallListResult(
        success: false,
        error: response.error ?? 'Failed to fetch active calls',
      );
    }
  }

  Future<RateConfigResult> getCallRates() async {
    final response = await _api.get(ApiConfig.callRates);

    if (response.isSuccess) {
      final rateConfig = RateConfig.fromJson(response.data);
      return RateConfigResult(
        success: true,
        rateConfig: rateConfig,
      );
    } else {
      return RateConfigResult(
        success: false,
        error: response.error ?? 'Failed to fetch call rates',
      );
    }
  }

  /// Rate a call
  Future<bool> rateCall({
    required String callId,
    required int rating,
    String? reviewText,
  }) async {
    final response = await _api.post(
      '${ApiConfig.calls}/$callId/rating',
      body: {
        'rating': rating,
        if (reviewText != null) 'review_text': reviewText,
      },
    );

    return response.isSuccess;
  }
}

/// Result class for single call
class CallResult {
  final bool success;
  final Call? call;
  final String? message;
  final String? error;

  CallResult({
    required this.success,
    this.call,
    this.message,
    this.error,
  });
}

/// Result class for list of calls
class CallListResult {
  final bool success;
  final List<Call> calls;
  final int count;
  final String? error;

  CallListResult({
    required this.success,
    this.calls = const [],
    this.count = 0,
    this.error,
  });
}

class RatingSubmitResult {
  final bool success;
  final String? message;
  final String? error;

  RatingSubmitResult({
    required this.success,
    this.message,
    this.error,
  });
}

class CallBillingSummary {
  final int minutes;
  final double userCharge;
  final int durationSeconds;

  CallBillingSummary({
    required this.minutes,
    required this.userCharge,
    required this.durationSeconds,
  });

  factory CallBillingSummary.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return CallBillingSummary(
      minutes: parseInt(json['minutes']),
      userCharge: parseDouble(json['userCharge'] ?? json['user_charge']),
      durationSeconds: parseInt(json['durationSeconds'] ?? json['duration_seconds']),
    );
  }
}

class CallEndResult {
  final bool success;
  final Call? call;
  final CallBillingSummary? summary;
  final String? message;
  final String? error;

  CallEndResult({
    required this.success,
    this.call,
    this.summary,
    this.message,
    this.error,
  });
}

class RateConfig {
  final double normalPerMinuteRate;
  final bool firstTimeOfferEnabled;
  final int? offerMinutesLimit;
  final double? offerFlatPrice;

  RateConfig({
    required this.normalPerMinuteRate,
    required this.firstTimeOfferEnabled,
    this.offerMinutesLimit,
    this.offerFlatPrice,
  });

  factory RateConfig.fromJson(Map<String, dynamic> json) {
    return RateConfig(
      normalPerMinuteRate: _parseDouble(
        json['normalPerMinuteRate'] ?? json['normal_per_minute_rate'],
      ),
      firstTimeOfferEnabled:
          json['firstTimeOfferEnabled'] == true || json['first_time_offer_enabled'] == true,
      offerMinutesLimit: _parseInt(
        json['offerMinutesLimit'] ?? json['offer_minutes_limit'],
      ),
      offerFlatPrice: _parseDouble(
        json['offerFlatPrice'] ?? json['offer_flat_price'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'normalPerMinuteRate': normalPerMinuteRate,
      'firstTimeOfferEnabled': firstTimeOfferEnabled,
      'offerMinutesLimit': offerMinutesLimit,
      'offerFlatPrice': offerFlatPrice,
    };
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

class RateConfigResult {
  final bool success;
  final RateConfig? rateConfig;
  final String? error;

  RateConfigResult({
    required this.success,
    this.rateConfig,
    this.error,
  });
}
