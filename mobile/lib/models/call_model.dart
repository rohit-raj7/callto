/// Call model matching backend Call schema
class Call {
  final String callId;
  final String callerId;
  final String listenerId;
  final String callType;
  final String status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final double ratePerMinute;
  final double? totalCost;
  // FIX: Added listenerEarn field — the actual payout amount calculated
  // by backend using admin-set listener_payout_per_min rate. This must be
  // used instead of totalCost for listener earnings display.
  final double? listenerEarn;
  final DateTime? createdAt;

  // Joined data
  final String? callerName;
  final String? callerAvatar;
  final String? listenerName;
  final String? listenerAvatar;
  final String? listenerUserId;
  final bool? listenerOnline;

  Call({
    required this.callId,
    required this.callerId,
    required this.listenerId,
    this.callType = 'audio',
    this.status = 'pending',
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.ratePerMinute = 0,
    this.totalCost,
    this.listenerEarn,
    this.createdAt,
    this.callerName,
    this.callerAvatar,
    this.listenerName,
    this.listenerAvatar,
    this.listenerUserId,
    this.listenerOnline,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse doubles from string or numeric values
    double parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Helper to safely parse booleans from various formats
    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true' || value == 't' || value == '1';
      if (value is int) return value == 1;
      return false;
    }

    return Call(
      callId: json['call_id']?.toString() ?? '',
      callerId: json['caller_id']?.toString() ?? '',
      listenerId: json['listener_id']?.toString() ?? '',
      callType: json['call_type'] ?? 'audio',
      status: json['status'] ?? 'pending',
      startedAt: json['started_at'] != null 
          ? DateTime.tryParse(json['started_at'].toString()) 
          : null,
      endedAt: json['ended_at'] != null 
          ? DateTime.tryParse(json['ended_at'].toString()) 
          : null,
      durationSeconds: json['duration_seconds'],
      ratePerMinute: parseDouble(json['rate_per_minute']),
      totalCost: json['total_cost'] != null 
          ? parseDouble(json['total_cost']) 
          : null,
      // FIX: Parse listener_earn from backend — this is the actual payout
      // calculated as callDurationMinutes * listener_payout_per_min (from DB)
      listenerEarn: json['listener_earn'] != null
          ? parseDouble(json['listener_earn'])
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
      callerName: json['caller_name'],
      callerAvatar: json['caller_avatar'],
      listenerName: json['listener_name'] ?? json['professional_name'] ?? json['listener_display_name'],
      listenerAvatar: json['listener_avatar'] ?? json['profile_image'],
      listenerUserId: json['listener_user_id']?.toString(),
      listenerOnline: parseBool(json['listener_online']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'caller_id': callerId,
      'listener_id': listenerId,
      'call_type': callType,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'rate_per_minute': ratePerMinute,
      'total_cost': totalCost,
      'listener_earn': listenerEarn,
      'created_at': createdAt?.toIso8601String(),
      'listener_user_id': listenerUserId,
      'listener_online': listenerOnline,
    };
  }

  /// Get formatted duration
  String get formattedDuration {
    if (durationSeconds == null) return '0:00';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get formatted cost
  String get formattedCost {
    if (totalCost == null) return '₹0';
    return '₹${totalCost!.toStringAsFixed(2)}';
  }

  /// Check if call is active
  bool get isActive {
    return status == 'pending' || status == 'ringing' || status == 'ongoing';
  }

  /// Check if call is completed
  bool get isCompleted => status == 'completed';

  /// Check if call was missed
  bool get isMissed => status == 'missed';
}

/// Call status enum
enum CallStatus {
  pending,
  ringing,
  ongoing,
  completed,
  missed,
  rejected,
  cancelled,
}

extension CallStatusExtension on CallStatus {
  String get value {
    switch (this) {
      case CallStatus.pending:
        return 'pending';
      case CallStatus.ringing:
        return 'ringing';
      case CallStatus.ongoing:
        return 'ongoing';
      case CallStatus.completed:
        return 'completed';
      case CallStatus.missed:
        return 'missed';
      case CallStatus.rejected:
        return 'rejected';
      case CallStatus.cancelled:
        return 'cancelled';
    }
  }
}
