/// Chat model matching backend Chat schema
class Chat {
  final String chatId;
  final String user1Id;
  final String user2Id;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;

  // Joined data
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? lastMessage;
  final int unreadCount;

  Chat({
    required this.chatId,
    required this.user1Id,
    required this.user2Id,
    this.lastMessageAt,
    this.createdAt,
    this.otherUserName,
    this.otherUserAvatar,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      chatId: json['chat_id']?.toString() ?? '',
      user1Id: json['user1_id']?.toString() ?? '',
      user2Id: json['user2_id']?.toString() ?? '',
      // FIX: Parse timestamps as UTC — server stores/sends UTC timestamps
      lastMessageAt: _parseAsUtc(json['last_message_at']?.toString()),
      createdAt: _parseAsUtc(json['created_at']?.toString()),
      otherUserName: json['other_user_name'],
      otherUserAvatar: json['other_user_avatar'],
      lastMessage: json['last_message'],
      unreadCount: _parseInt(json['unread_count']),
    );
  }

  /// Parse a timestamp string as UTC.
  /// DEVICE-TIME FIX: Backend sends UTC ISO strings (with 'Z' suffix).
  /// The db.js type parser appends 'Z' to raw TIMESTAMP values since all
  /// database sessions are forced to UTC. If timezone info is missing,
  /// we force UTC to prevent displaying raw UTC values as local time.
  /// The client then calls .toLocal() to convert to device timezone.
  static DateTime? _parseAsUtc(String? value) {
    if (value == null || value.isEmpty) return null;
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    // If already UTC (has 'Z' or offset in string), return as-is
    if (dt.isUtc) return dt;
    // No timezone info in string — treat as UTC since backend stores UTC
    return DateTime.utc(
      dt.year, dt.month, dt.day,
      dt.hour, dt.minute, dt.second,
      dt.millisecond, dt.microsecond,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'user1_id': user1Id,
      'user2_id': user2Id,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

/// Message model matching backend Message schema
class Message {
  final String messageId;
  final String chatId;
  final String senderId;
  final String messageType;
  final String messageContent;
  final String? mediaUrl;
  final bool isRead;
  final DateTime? createdAt;

  // Joined data
  final String? senderName;
  final String? senderAvatar;

  Message({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    this.messageType = 'text',
    required this.messageContent,
    this.mediaUrl,
    this.isRead = false,
    this.createdAt,
    this.senderName,
    this.senderAvatar,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: json['message_id']?.toString() ?? '',
      chatId: json['chat_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      messageType: json['message_type'] ?? 'text',
      messageContent: json['message_content'] ?? '',
      mediaUrl: json['media_url'],
      isRead: _parseBool(json['is_read']),
      // FIX: Parse timestamp as UTC — server sends UTC ISO strings
      createdAt: Chat._parseAsUtc(json['created_at']?.toString()),
      senderName: json['sender_name'],
      senderAvatar: json['sender_avatar'],
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true' || value == '1';
    if (value is int) return value == 1;
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'chat_id': chatId,
      'sender_id': senderId,
      'message_type': messageType,
      'message_content': messageContent,
      'media_url': mediaUrl,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Check if message is from the specified user
  bool isFromUser(String userId) => senderId == userId;

  /// Get formatted time — converts UTC timestamp to device local time for display.
  /// DEVICE-TIME FIX: createdAt is always stored as UTC (from server or forced
  /// via _parseAsUtc). Calling .toLocal() converts to the device's timezone,
  /// so the displayed time matches the user's actual device/system clock.
  /// No hardcoded timezone offsets are used — .toLocal() uses the OS timezone.
  String get formattedTime {
    if (createdAt == null) return '';
    // createdAt is always UTC (from server or forced via _parseAsUtc)
    // .toLocal() converts to the device's timezone for correct display
    final local = createdAt!.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}

/// Message type enum
enum MessageType {
  text,
  image,
  audio,
  video,
}

extension MessageTypeExtension on MessageType {
  String get value {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.audio:
        return 'audio';
      case MessageType.video:
        return 'video';
    }
  }
}
