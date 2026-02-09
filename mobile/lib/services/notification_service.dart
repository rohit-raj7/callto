import 'dart:async';
import 'api_service.dart';
import 'api_config.dart';
import '../models/notification_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final ApiService _api = ApiService();
  final StreamController<AppNotification> _incomingController = StreamController.broadcast();

  Stream<AppNotification> get onIncomingNotification => _incomingController.stream;

  Future<FetchResult> fetchNotifications({int page = 1, int limit = 20}) async {
    final res = await _api.get(ApiConfig.notificationsMy, queryParams: {
      'page': '$page',
      'limit': '$limit',
    });
    if (!res.isSuccess) {
      return FetchResult(success: false, notifications: const [], error: res.error ?? 'Failed');
    }
    final list = (res.data['notifications'] as List? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return FetchResult(success: true, notifications: list);
  }

  Future<bool> markAsRead(String id) async {
    final res = await _api.post(ApiConfig.notificationsMarkRead, body: {'id': id});
    return res.isSuccess;
  }

  Future<int> unreadCount() async {
    final res = await _api.get(ApiConfig.notificationsUnreadCount);
    if (!res.isSuccess) return 0;
    final c = res.data['count'];
    if (c is int) return c;
    if (c is String) return int.tryParse(c) ?? 0;
    return 0;
  }

  void handleIncomingNotification(Map<String, dynamic> payload) {
    final n = AppNotification.fromJson(payload);
    _incomingController.add(n);
  }
}

class FetchResult {
  final bool success;
  final List<AppNotification> notifications;
  final String? error;

  FetchResult({
    required this.success,
    required this.notifications,
    this.error,
  });
}

