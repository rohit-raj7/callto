import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/socket_service.dart';
import '../../services/chat_service.dart';
import '../../services/storage_service.dart';
import '../../services/chat_state_manager.dart';
import '../../models/chat_model.dart';
import '../nav/profile/wallet.dart';

class ChatPage extends StatefulWidget {
  final String expertName;
  final String imagePath;
  final String? chatId; // Chat ID from backend
  final String? otherUserId; // The other user's ID
  final String? otherUserAvatar;

  const ChatPage({
    super.key,
    required this.expertName,
    required this.imagePath,
    this.chatId,
    this.otherUserId,
    this.otherUserAvatar,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final SocketService _socketService = SocketService();
  final ChatService _chatService = ChatService();
  final StorageService _storage = StorageService();
  final ChatStateManager _chatStateManager = ChatStateManager();

  final List<Message> _messages = [];
  final AudioPlayer _lowBalancePlayer = AudioPlayer();
  String? _chatId;
  String? _currentUserId;
  String? _otherUserId; // Track other user's ID for delete for everyone
  bool _isLoading = true;
  bool _isTyping = false;
  bool _otherUserTyping = false;
  final bool _otherUserOnline =
      true; // Assume online initially since they're a listener
  String? _errorMessage;
  bool _showLowBalanceOverlay = false;

  // Track if we've received history from socket
  bool _historyReceived = false;

  // WhatsApp-style delete: Track locally deleted messages
  Set<String> _deletedForMe = {};
  Set<String> _deletedForEveryone = {};

  // Stream subscriptions
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _historySubscription;
  StreamSubscription<Map<String, dynamic>>? _typingSubscription;
  StreamSubscription<Map<String, dynamic>>? _errorSubscription;
  StreamSubscription<Map<String, dynamic>>? _readSubscription;
  StreamSubscription<Map<String, dynamic>>?
  _deleteSubscription; // For delete events

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer to handle app background/foreground
    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes while on chat screen
    // WhatsApp-style: keep connection but update viewing state
    switch (state) {
      case AppLifecycleState.resumed:
        print('[ChatPage] App resumed - re-joining chat room');
        _chatStateManager.appResumed();
        if (_chatId != null) {
          _socketService.joinChatRoom(_chatId!);
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        print('[ChatPage] App paused/inactive');
        _chatStateManager.appPaused();
        break;
      default:
        break;
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Get current user ID
      _currentUserId = await _storage.getUserId();

      if (_currentUserId == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Load locally deleted message IDs for WhatsApp-style delete
      _deletedForMe = await _storage.getDeletedForMe();
      _deletedForEveryone = await _storage.getDeletedForEveryone();

      // If we already have a chatId, use it
      if (widget.chatId != null) {
        _chatId = widget.chatId;
      } else if (widget.otherUserId != null) {
        // Create or get chat with the other user
        final result = await _chatService.createOrGetChat(widget.otherUserId!);
        if (result.success && result.chat != null) {
          _chatId = result.chat!.chatId;
        } else {
          // VERIFICATION: Handle listener verification failures
          final error = result.error ?? 'Failed to create chat';
          final userFriendlyError = error.toLowerCase().contains('not approved')
              ? 'This listener is not available for chat at the moment'
              : error;

          setState(() {
            _errorMessage = userFriendlyError;
            _isLoading = false;
          });
          return;
        }
      } else {
        setState(() {
          _errorMessage = 'No chat ID or user ID provided';
          _isLoading = false;
        });
        return;
      }

      // Set other user ID for delete for everyone feature
      _otherUserId = widget.otherUserId;
      await _resolveOtherUserIdIfNeeded();

      // Ensure socket is connected
      final connected = await _socketService.connect();
      if (!connected) {
        setState(() {
          _errorMessage = 'Failed to connect to server';
          _isLoading = false;
        });
        return;
      }

      // Setup socket listeners BEFORE joining room
      _setupSocketListeners();

      // Join the chat room - this will:
      // 1. Join socket room for real-time messages
      // 2. Update ChatStateManager to track we're viewing this chat
      // 3. Tell server we're actively viewing (no notifications)
      _socketService.joinChatRoom(_chatId!);

      // Also load messages from API as fallback (in case socket history doesn't arrive)
      _loadMessagesFromApi();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing chat: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _resolveOtherUserIdIfNeeded() async {
    if (_otherUserId != null && _otherUserId!.isNotEmpty) return;
    if (_chatId == null || _currentUserId == null) return;

    final result = await _chatService.getChatById(_chatId!);
    if (!result.success || result.chat == null) return;

    final chat = result.chat!;
    _otherUserId = chat.user1Id == _currentUserId ? chat.user2Id : chat.user1Id;
  }

  /// Load messages from REST API as fallback
  Future<void> _loadMessagesFromApi() async {
    if (_chatId == null) return;

    // Short wait for socket history, then load from API if not received
    await Future.delayed(const Duration(milliseconds: 200));

    if (!_historyReceived && mounted) {
      print('[ChatPage] Socket history not received, loading from API');
      try {
        final result = await _chatService.getChatMessages(
          chatId: _chatId!,
          limit: 50,
          offset: 0,
        );

        if (result.success && mounted && !_historyReceived) {
          setState(() {
            _messages.clear();
            _messages.addAll(result.messages);
          });
          _scrollToBottom();

          // Mark messages as read
          _socketService.markChatAsRead(_chatId!);
        }
      } catch (e) {
        print('[ChatPage] Error loading messages from API: $e');
      }
    }
  }

  void _setupSocketListeners() {
    // Listen for incoming messages (real-time)
    // WhatsApp-style: Messages appear instantly without refresh
    _messageSubscription = _socketService.onChatMessage.listen((data) {
      final chatId = data['chatId']?.toString();
      if (chatId == _chatId && data['message'] != null) {
        final messageData = data['message'] as Map<String, dynamic>;
        final message = Message.fromJson(messageData);

        print(
          '[ChatPage] Received message from socket: ${message.messageContent} (senderId: ${message.senderId})',
        );
        print(
          '[ChatPage] TIMESTAMP DEBUG: raw=${messageData['created_at']}, parsed=${message.createdAt}, isUtc=${message.createdAt?.isUtc}, local=${message.createdAt?.toLocal()}',
        );

        setState(() {
          // Check if this is confirmation of our own message (replace optimistic)
          if (message.senderId == _currentUserId) {
            // Find and replace the optimistic message with same content
            final optimisticIndex = _messages.indexWhere(
              (m) =>
                  m.messageId.startsWith('temp_') &&
                  m.messageContent == message.messageContent,
            );

            if (optimisticIndex != -1) {
              print(
                '[ChatPage] Replacing optimistic message with confirmed message',
              );
              // DEVICE-TIME FIX: Preserve the device local timestamp from the
              // optimistic message for display. This ensures the sent message
              // time always matches the device clock when the user pressed send
              // (WhatsApp-style). Server time is only used for ordering/storage.
              final deviceTime = _messages[optimisticIndex].createdAt;
              _messages[optimisticIndex] = Message(
                messageId: message.messageId,
                chatId: message.chatId,
                senderId: message.senderId,
                messageType: message.messageType,
                messageContent: message.messageContent,
                mediaUrl: message.mediaUrl,
                isRead: message.isRead,
                createdAt: deviceTime, // Use device time, not server time
                senderName: message.senderName,
                senderAvatar: message.senderAvatar,
              );
              return; // Already updated
            }
          }

          // Check for duplicates by messageId
          if (!_messages.any((m) => m.messageId == message.messageId)) {
            _messages.add(message);
            print('[ChatPage] Added new message to list');
          } else {
            print('[ChatPage] Message already exists, skipping duplicate');
          }
        });
        _scrollToBottom();

        // Mark as read if from other user (we're viewing the chat)
        if (message.senderId != _currentUserId) {
          _socketService.markChatAsRead(_chatId!);
        }
      }
    });

    // Listen for chat history (sent when joining room)
    _historySubscription = _socketService.onChatHistory.listen((data) {
      final chatId = data['chatId']?.toString();
      if (chatId == _chatId && data['messages'] != null) {
        _historyReceived = true;
        final messagesList = data['messages'] as List;

        print('[ChatPage] Received history: ${messagesList.length} messages');

        setState(() {
          _messages.clear();
          for (var msgData in messagesList) {
            _messages.add(Message.fromJson(Map<String, dynamic>.from(msgData)));
          }
        });
        _scrollToBottom();

        // Mark messages as read
        _socketService.markChatAsRead(_chatId!);
      }
    });

    // Listen for typing indicators
    _typingSubscription = _socketService.onChatTyping.listen((data) {
      final chatId = data['chatId']?.toString();
      if (chatId == _chatId && data['userId'] != _currentUserId) {
        setState(() {
          _otherUserTyping = data['isTyping'] == true;
        });
      }
    });

    // Listen for read receipts
    _readSubscription = _socketService.onChatMessagesRead.listen((data) {
      final chatId = data['chatId']?.toString();
      if (chatId == _chatId) {
        // Could update UI to show read status
        print('[ChatPage] Messages marked as read by ${data['readBy']}');
      }
    });

    // Listen for errors
    _errorSubscription = _socketService.onChatError.listen((data) {
      if (mounted) {
        final errorCode = data['code']?.toString();
        final errorMessage = data['message']?.toString() ?? data['error']?.toString() ?? 'An error occurred';

        if (errorCode == 'LOW_BALANCE') {
          // Remove the last optimistic message (the one that was blocked)
          setState(() {
            final lastTempIndex = _messages.lastIndexWhere(
              (m) => m.messageId.startsWith('temp_'),
            );
            if (lastTempIndex != -1) {
              _messages.removeAt(lastTempIndex);
            }
            _showLowBalanceOverlay = true;
          });
          _playLowBalanceSound();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });

    // WhatsApp-style: Listen for message deleted events
    _deleteSubscription = _socketService.onMessageDeleted.listen((data) {
      final messageId = data['messageId']?.toString();
      final chatId = data['chatId']?.toString();

      if (messageId != null && (chatId == _chatId || chatId == null)) {
        print('[ChatPage] Message deleted event received: $messageId');

        // Save to local storage as "deleted for everyone"
        _storage.addDeletedForEveryone(messageId);

        // Update local state
        setState(() {
          _deletedForEveryone.add(messageId);
        });
      }
    });
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Leave chat room - this updates ChatStateManager and notifies server
    if (_chatId != null) {
      _socketService.leaveChatRoom(_chatId!);
    }

    // Cancel subscriptions
    _messageSubscription?.cancel();
    _historySubscription?.cancel();
    _typingSubscription?.cancel();
    _readSubscription?.cancel();
    _errorSubscription?.cancel();
    _deleteSubscription?.cancel();

    _lowBalancePlayer.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _chatId == null || _currentUserId == null) return;

    _controller.clear();
    _sendTypingIndicator(false);

    // Create temporary message ID for optimistic update
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // DEVICE-TIME FIX: Use device local time for instant display.
    // This timestamp matches the user's device clock at the moment they pressed send.
    // It is NOT replaced by server time when the server confirms the message.
    final optimisticMessage = Message(
      messageId: tempId,
      chatId: _chatId!,
      senderId: _currentUserId!,
      senderName: 'You',
      messageType: 'text',
      messageContent: text,
      createdAt: DateTime.now(), // Device local time — matches user's clock
      isRead: false,
    );

    setState(() {
      _messages.add(optimisticMessage);
    });
    _scrollToBottom();

    // Try socket first (for real-time delivery to other user)
    if (_socketService.isConnected) {
      print('[ChatPage] Sending message via socket');
      _socketService.sendChatMessage(chatId: _chatId!, content: text);
    } else {
      // Socket not connected - try to reconnect and use API fallback
      print('[ChatPage] Socket not connected, using API fallback');
      try {
        final result = await _chatService.sendMessage(
          chatId: _chatId!,
          content: text,
        );

        if (result.success && result.message != null) {
          // Replace optimistic message with real one
          setState(() {
            final index = _messages.indexWhere((m) => m.messageId == tempId);
            if (index != -1) {
              _messages[index] = result.message!;
            }
          });
        } else {
          // Show error and remove optimistic message
          setState(() {
            _messages.removeWhere((m) => m.messageId == tempId);
          });
          if (mounted) {
            // Check for LOW_BALANCE error
            if (result.errorCode == 'LOW_BALANCE') {
              setState(() {
                _showLowBalanceOverlay = true;
              });
              _playLowBalanceSound();
            } else {
              // VERIFICATION: Show user-friendly error for verification failures
              final error = result.error ?? 'Failed to send message';
              final userFriendlyError =
                  error.toLowerCase().contains('not approved')
                  ? 'This listener is not available for chat at the moment'
                  : error;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(userFriendlyError),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        }
      } catch (e) {
        print('[ChatPage] Error sending message: $e');
        // Remove optimistic message on error
        setState(() {
          _messages.removeWhere((m) => m.messageId == tempId);
        });
      }

      // Try to reconnect socket for future messages
      _socketService.connect().then((_) {
        if (_chatId != null) {
          _socketService.joinChatRoom(_chatId!);
        }
      });
    }
  }

  void _sendTypingIndicator(bool typing) {
    if (_isTyping != typing && _chatId != null) {
      _isTyping = typing;
      _socketService.sendTypingIndicator(chatId: _chatId!, isTyping: typing);
    }
  }

  /// Play low balance alert sound
  void _playLowBalanceSound() {
    try {
      _lowBalancePlayer.stop();
      _lowBalancePlayer.play(AssetSource('voice/low_balance.mp3'));
    } catch (e) {
      print('[ChatPage] Error playing low balance sound: $e');
    }
  }

  void _scrollToBottom() {
    // With reverse: true ListView, scroll to 0.0 means bottom (latest messages)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Returns a date header string if the message is the first on that day
  String? _dateSeparator(int index) {
    // Messages are in chronological order, but the ListView is reversed,
    // so index 0 = newest. We compare with the NEXT index (older message).
    if (index == _messages.length - 1) {
      return _formatDate(_messages[_messages.length - 1 - index].createdAt);
    }
    final current = _messages[_messages.length - 1 - index];
    final previous = _messages[_messages.length - 2 - index];
    if (current.createdAt != null && previous.createdAt != null) {
      final curLocal = current.createdAt!.toLocal();
      final prevLocal = previous.createdAt!.toLocal();
      if (curLocal.day != prevLocal.day ||
          curLocal.month != prevLocal.month ||
          curLocal.year != prevLocal.year) {
        return _formatDate(current.createdAt);
      }
    }
    return null;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0 && now.day == local.day) return 'Today';
    if (diff.inDays == 1 || (diff.inDays == 0 && now.day != local.day))
      return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';
    final local = timestamp.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // ============================================
  // WhatsApp-style Delete Message Feature
  // ============================================

  /// Show WhatsApp-style delete options dialog on long-press
  void _showDeleteOptions(Message message, bool isUserMessage) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Delete for Me option (available for all messages)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.grey),
                title: const Text('Delete for Me'),
                subtitle: const Text(
                  'This message will be removed from your device only',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteForMe(message);
                },
              ),

              // Delete for Everyone option (only for sender's own messages)
              if (isUserMessage) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text(
                    'Delete for Everyone',
                    style: TextStyle(color: Colors.red),
                  ),
                  subtitle: const Text(
                    'This message will be deleted for everyone',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteForEveryone(message);
                  },
                ),
              ],

              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.close, color: Colors.grey),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Delete message for current user only (local delete)
  /// Message is hidden from UI but not deleted from backend
  void _deleteForMe(Message message) async {
    // Save to local storage
    await _storage.addDeletedForMe(message.messageId);

    // Update UI immediately
    setState(() {
      _deletedForMe.add(message.messageId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted for you'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show confirmation dialog before deleting for everyone
  void _confirmDeleteForEveryone(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete for Everyone?'),
        content: const Text(
          'This message will be permanently deleted for everyone in this chat. '
          'Others will see "This message was deleted".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteForEveryone(message);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Delete message for everyone (backend delete + broadcast)
  /// Backend permanently deletes from DB, both users see "This message was deleted"
  void _deleteForEveryone(Message message) async {
    if (_chatId == null) return;

    // Emit socket event to delete from backend
    _socketService.deleteMessageForEveryone(
      messageId: message.messageId,
      chatId: _chatId!,
      receiverId: _otherUserId ?? '',
    );

    // Optimistically update UI (will also be updated when we receive the delete event)
    await _storage.addDeletedForEveryone(message.messageId);
    setState(() {
      _deletedForEveryone.add(message.messageId);
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted for everyone'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleConversationMenuSelection(String action) async {
    switch (action) {
      case 'clear':
        await _clearChatMessages();
        break;
      case 'delete':
        await _deleteChatConversation();
        break;
    }
  }

  Future<void> _clearChatMessages() async {
    final chatId = _chatId;
    if (chatId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat is not ready yet')));
      return;
    }

    final confirmed = await _showChatActionConfirmation(
      title: 'Clear chat?',
      content: 'This removes messages from this screen for now.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final cleared = await _chatService.clearChat(chatId);
    if (!mounted) return;

    if (!cleared) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to clear chat')));
      return;
    }

    setState(() {
      _messages.clear();
      _otherUserTyping = false;
      _deletedForMe.clear();
      _deletedForEveryone.clear();
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Chat cleared successfully')));
  }

  Future<void> _deleteChatConversation() async {
    final chatId = _chatId;
    if (chatId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chat is not ready yet')));
      return;
    }

    final confirmed = await _showChatActionConfirmation(
      title: 'Delete chat?',
      content: 'This chat will be removed from your chat list.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final deleted = await _chatService.deleteChat(chatId);
    if (!mounted) return;

    if (!deleted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete chat')));
      return;
    }

    Navigator.pop(context, {'deletedChatId': chatId});
  }

  Future<bool> _showChatActionConfirmation({
    required String title,
    required String content,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: destructive
                ? TextButton.styleFrom(foregroundColor: Colors.red)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFEBEE),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.pinkAccent),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFFEBEE),
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _initializeChat();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFEBEE),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Column(
        children: [
          // Messages List (reversed for bottom-anchored scrolling)
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              reverse: true, // newest at bottom, auto-anchored
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length + (_otherUserTyping ? 1 : 0),
              itemBuilder: (context, index) {
                // Typing indicator at visual bottom (index 0 when reversed)
                if (_otherUserTyping && index == 0) {
                  return _buildTypingIndicator();
                }

                final msgIndex = _otherUserTyping ? index - 1 : index;
                // Reversed: index 0 = newest, so map back
                final message = _messages[_messages.length - 1 - msgIndex];
                final isUser = message.senderId == _currentUserId;

                // WhatsApp-style: Skip messages deleted for me
                if (_deletedForMe.contains(message.messageId)) {
                  return const SizedBox.shrink();
                }

                final isDeletedForEveryone = _deletedForEveryone.contains(
                  message.messageId,
                );

                // Date separator
                final dateSep = _dateSeparator(msgIndex);

                return Column(
                  children: [
                    if (dateSep != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              dateSep,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    GestureDetector(
                      onLongPress: isDeletedForEveryone
                          ? null
                          : () => _showDeleteOptions(message, isUser),
                      child: Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.only(
                            left: 14,
                            right: 10,
                            top: 8,
                            bottom: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDeletedForEveryone
                                ? Colors.grey.shade200
                                : (isUser
                                      ? Colors.pinkAccent
                                      : const Color(0xFFFFE4EC)),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isUser
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: isUser
                                  ? Radius.zero
                                  : const Radius.circular(16),
                            ),
                          ),
                          child: isDeletedForEveryone
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.block,
                                      size: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'This message was deleted',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: isUser
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.messageContent,
                                      style: TextStyle(
                                        color: isUser
                                            ? Colors.white
                                            : Colors.black87,
                                        fontSize: 15,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Time + read receipt inside bubble
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatTime(message.createdAt),
                                          style: TextStyle(
                                            color: isUser
                                                ? Colors.white70
                                                : Colors.grey.shade500,
                                            fontSize: 11,
                                          ),
                                        ),
                                        if (isUser) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            message.messageId.startsWith(
                                                  'temp_',
                                                )
                                                ? Icons
                                                      .access_time // pending
                                                : (message.isRead
                                                      ? Icons
                                                            .done_all // read
                                                      : Icons
                                                            .done), // delivered
                                            size: 14,
                                            color: message.isRead
                                                ? Colors.lightBlueAccent
                                                : Colors.white70,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Type your message...",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: const Color(0xFFFFF1F5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(
                          color: Colors.pinkAccent,
                          width: 1,
                        ),
                      ),
                    ),
                    onChanged: (text) {
                      _sendTypingIndicator(text.isNotEmpty);
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                    tooltip: 'Send message',
                  ),
                ),
              ],
            ),
          ),
        ],
      ), // end Column

          // Low balance overlay (shown over chat when balance is insufficient)
          if (_showLowBalanceOverlay) _buildLowBalanceOverlay(),
        ],
      ), // end Stack
    );
  }

  /// Low balance overlay — displayed over the chat screen (matches design mockup).
  Widget _buildLowBalanceOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          // Dismiss overlay when tapping outside the card
          setState(() {
            _showLowBalanceOverlay = false;
          });
        },
        child: Container(
          color: Colors.black.withOpacity(0.35),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // Prevent dismiss when tapping the card itself
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 36),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warning icon
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFFA726),
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  const Text(
                    'Low balance to continue\nchat',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subtitle
                  const Text(
                    'Insufficient balance. Please recharge\nto continue this conversation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF757575),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Add Balance button (filled)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showLowBalanceOverlay = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF78909C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Add Balance',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // View Plans button (outlined)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _showLowBalanceOverlay = false;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5C6BC0),
                        side: const BorderSide(
                          color: Color(0xFF5C6BC0),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'View Plans',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.pinkAccent,
      elevation: 2,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFFFF1F5),
            backgroundImage: _resolveAvatar(widget.otherUserAvatar),
            onBackgroundImageError:
                (widget.otherUserAvatar != null &&
                    widget.otherUserAvatar!.isNotEmpty &&
                    widget.otherUserAvatar!.startsWith('http'))
                ? (_, __) {}
                : null,
            child:
                (widget.otherUserAvatar == null ||
                    widget.otherUserAvatar!.isEmpty)
                ? const Icon(Icons.person, size: 20, color: Colors.pinkAccent)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.expertName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              if (_otherUserTyping)
                const Text(
                  'typing...',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                  ),
                )
              else if (_otherUserOnline)
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Online',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) => _handleConversationMenuSelection(value),
          itemBuilder: (context) => const [
            PopupMenuItem<String>(value: 'clear', child: Text('Clear chat')),
            PopupMenuItem<String>(value: 'delete', child: Text('Delete chat')),
          ],
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFFFFE4EC),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBouncingDot(0),
            const SizedBox(width: 4),
            _buildBouncingDot(200),
            const SizedBox(width: 4),
            _buildBouncingDot(400),
          ],
        ),
      ),
    );
  }

  Widget _buildBouncingDot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  /// Resolve avatar string to the correct ImageProvider.
  /// Asset paths (e.g. 'assets/...') → AssetImage, URLs → NetworkImage.
  static ImageProvider? _resolveAvatar(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    if (avatar.startsWith('http')) return NetworkImage(avatar);
    return AssetImage(avatar);
  }
}
