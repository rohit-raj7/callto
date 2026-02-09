/// Agora Chat Configuration
/// 
/// This file provides consistent channel/room ID generation and user identity
/// management shared between Agora voice calls and Socket.IO chat messaging.
/// 
/// Both systems use the same:
/// - User identity (userId)
/// - Channel/Room naming conventions
/// - Session ID generation
library;

class AgoraChatConfig {
  /// Generate a consistent chat room ID for two users
  /// The room ID is deterministic - same two users always get the same room ID
  static String generateChatRoomId(String user1Id, String user2Id) {
    // Sort IDs to ensure consistency regardless of who initiates
    final sortedIds = [user1Id, user2Id]..sort();
    return 'chat_${sortedIds[0]}_${sortedIds[1]}';
  }

  /// Generate a unique session ID for a chat session
  /// Used for tracking message sessions
  static String generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generate Agora channel name from chat ID
  /// Ensures voice calls within a chat session use consistent channel names
  static String getVoiceChannelFromChatId(String chatId) {
    return 'voice_$chatId';
  }

  /// Parse user IDs from a chat room ID
  static List<String>? parseUserIdsFromRoomId(String roomId) {
    if (!roomId.startsWith('chat_')) return null;
    
    final parts = roomId.substring(5).split('_');
    if (parts.length != 2) return null;
    
    return parts;
  }

  /// Check if a user is part of a chat room
  static bool isUserInRoom(String roomId, String userId) {
    final userIds = parseUserIdsFromRoomId(roomId);
    if (userIds == null) return false;
    return userIds.contains(userId);
  }

  /// Get the other user's ID from a chat room ID
  static String? getOtherUserId(String roomId, String currentUserId) {
    final userIds = parseUserIdsFromRoomId(roomId);
    if (userIds == null) return null;
    
    if (userIds[0] == currentUserId) return userIds[1];
    if (userIds[1] == currentUserId) return userIds[0];
    return null;
  }

  /// Configuration for message types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeAudio = 'audio';
  static const String messageTypeVideo = 'video';
  static const String messageTypeFile = 'file';

  /// Chat event names (matching backend Socket.IO events)
  static const String eventJoin = 'chat:join';
  static const String eventLeave = 'chat:leave';
  static const String eventSend = 'chat:send';
  static const String eventMessage = 'chat:message';
  static const String eventHistory = 'chat:history';
  static const String eventTyping = 'chat:typing';
  static const String eventUserTyping = 'chat:user_typing';
  static const String eventRead = 'chat:read';
  static const String eventMessagesRead = 'chat:messages_read';
  static const String eventError = 'chat:error';
}
