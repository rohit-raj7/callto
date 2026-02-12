import 'api_service.dart';
import 'api_config.dart';
import '../models/chat_model.dart';

/// Service for managing chat-related API calls
class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final ApiService _api = ApiService();

  /// Get all chats for current user
  Future<ChatListResult> getChats() async {
    final response = await _api.get(ApiConfig.chats);

    if (response.isSuccess) {
      final List<dynamic> chatsJson = response.data['chats'] ?? [];
      final chats = chatsJson.map((json) => Chat.fromJson(json)).toList();

      return ChatListResult(
        success: true,
        chats: chats,
        count: response.data['count'] ?? chats.length,
      );
    } else {
      return ChatListResult(
        success: false,
        error: response.error ?? 'Failed to fetch chats',
      );
    }
  }

  /// Create or get existing chat with another user
  Future<ChatResult> createOrGetChat(String otherUserId) async {
    final response = await _api.post(
      ApiConfig.chats,
      body: {'other_user_id': otherUserId},
    );

    if (response.isSuccess) {
      final chat = Chat.fromJson(response.data['chat']);

      return ChatResult(
        success: true,
        chat: chat,
        message: response.data['message'],
      );
    } else {
      return ChatResult(
        success: false,
        error: response.error ?? 'Failed to create chat',
      );
    }
  }

  /// Get chat by ID
  Future<ChatResult> getChatById(String chatId) async {
    final response = await _api.get('${ApiConfig.chats}/$chatId');

    if (response.isSuccess) {
      final chat = Chat.fromJson(response.data['chat']);

      return ChatResult(success: true, chat: chat);
    } else {
      return ChatResult(
        success: false,
        error: response.error ?? 'Failed to fetch chat',
      );
    }
  }

  /// Get messages in a chat
  Future<MessageListResult> getChatMessages({
    required String chatId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _api.get(
      '${ApiConfig.chats}/$chatId/messages',
      queryParams: {'limit': limit.toString(), 'offset': offset.toString()},
    );

    if (response.isSuccess) {
      final List<dynamic> messagesJson = response.data['messages'] ?? [];
      final messages = messagesJson
          .map((json) => Message.fromJson(json))
          .toList();

      return MessageListResult(
        success: true,
        messages: messages,
        count: response.data['count'] ?? messages.length,
      );
    } else {
      return MessageListResult(
        success: false,
        error: response.error ?? 'Failed to fetch messages',
      );
    }
  }

  /// Send a message in a chat
  Future<MessageResult> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    final response = await _api.post(
      '${ApiConfig.chats}/$chatId/messages',
      body: {
        'message_content': content,
        'message_type': messageType,
        if (mediaUrl != null) 'media_url': mediaUrl,
      },
    );

    if (response.isSuccess) {
      final message = Message.fromJson(response.data['data']);

      return MessageResult(success: true, message: message);
    } else {
      return MessageResult(
        success: false,
        error: response.error ?? 'Failed to send message',
        errorCode: response.errorCode,
      );
    }
  }

  /// Mark messages as read
  Future<bool> markAsRead(String chatId) async {
    final response = await _api.put('${ApiConfig.chats}/$chatId/read');
    return response.isSuccess;
  }

  /// Delete/deactivate a chat
  Future<bool> deleteChat(String chatId) async {
    final response = await _api.delete('${ApiConfig.chats}/$chatId');
    return response.isSuccess;
  }

  /// Clear all messages from a chat while keeping the chat in the list
  Future<bool> clearChat(String chatId) async {
    final response = await _api.delete('${ApiConfig.chats}/$chatId/messages');
    return response.isSuccess;
  }
}

/// Result class for single chat
class ChatResult {
  final bool success;
  final Chat? chat;
  final String? message;
  final String? error;

  ChatResult({required this.success, this.chat, this.message, this.error});
}

/// Result class for list of chats
class ChatListResult {
  final bool success;
  final List<Chat> chats;
  final int count;
  final String? error;

  ChatListResult({
    required this.success,
    this.chats = const [],
    this.count = 0,
    this.error,
  });
}

/// Result class for single message
class MessageResult {
  final bool success;
  final Message? message;
  final String? error;
  final String? errorCode;

  MessageResult({required this.success, this.message, this.error, this.errorCode});
}

/// Result class for list of messages
class MessageListResult {
  final bool success;
  final List<Message> messages;
  final int count;
  final String? error;

  MessageListResult({
    required this.success,
    this.messages = const [],
    this.count = 0,
    this.error,
  });
}
