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
