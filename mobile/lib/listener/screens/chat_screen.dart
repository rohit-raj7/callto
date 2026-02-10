import 'dart:async';
import 'package:flutter/material.dart';
import '../actions/charting.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../models/chat_model.dart';
import '../../ui/skeleton_loading_ui/chat_item_skeleton.dart';

/// Resolve avatar string to the correct ImageProvider.
/// Asset paths (e.g. 'assets/...') → AssetImage, URLs → NetworkImage.
ImageProvider? _resolveAvatar(String? avatar) {
  if (avatar == null || avatar.isEmpty) return null;
  // if (avatar.startsWith('http')) return NetworkImage(avatar);
  if (avatar.startsWith('assets/')) return AssetImage(avatar);
  return null;
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final SocketService _socketService = SocketService();
  
  List<Chat> _chats = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Stream subscriptions cleaned up on dispose
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    // In-place chat list update on new messages (no full reload)
    _messageSubscription = _socketService.onChatMessage.listen((data) {
      if (mounted) _updateChatFromMessage(data);
    });
    
    _notificationSubscription = _socketService.onChatNotification.listen((data) {
      if (mounted) _updateChatFromMessage(data);
    });
  }

  /// Update a single chat in-place from a socket message instead of full API reload
  void _updateChatFromMessage(Map<String, dynamic> data) {
    final chatId = data['chatId']?.toString();
    final messageData = data['message'] as Map<String, dynamic>?;
    if (chatId == null || messageData == null) {
      _loadChats();
      return;
    }

    final messageContent = messageData['message_content']?.toString() ?? '';
    // FIX: Parse timestamp as UTC — server sends UTC ISO strings.
    // Fallback to DateTime.now() only if created_at is missing.
    final createdAt = messageData['created_at'] != null
        ? _parseAsUtc(messageData['created_at'].toString())
        : DateTime.now().toUtc();

    setState(() {
      final idx = _chats.indexWhere((c) => c.chatId == chatId);
      if (idx != -1) {
        final old = _chats[idx];
        final senderId = messageData['sender_id']?.toString() ?? '';
        // Simple: listener is always a participant; increment unread count
        _chats[idx] = Chat(
          chatId: old.chatId,
          user1Id: old.user1Id,
          user2Id: old.user2Id,
          lastMessageAt: createdAt,
          createdAt: old.createdAt,
          otherUserName: old.otherUserName,
          otherUserAvatar: old.otherUserAvatar,
          lastMessage: messageContent,
          unreadCount: old.unreadCount + 1,
        );
        final updated = _chats.removeAt(idx);
        _chats.insert(0, updated);
      } else {
        // New chat — reload to get full details
        _loadChats();
      }
    });
  }

  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _chatService.getChats();

      if (result.success) {
        setState(() {
          _chats = result.chats;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to load chats';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading chats: $e';
        _isLoading = false;
      });
    }
  }

  List<Chat> get _filteredChats {
    if (_searchQuery.isEmpty) return _chats;
    
    return _chats.where((chat) {
      final name = chat.otherUserName?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.pinkAccent,
        title: const Text(
          'Chat with Users',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFEBEE), Color(0xFFFCE4EC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search chats...',
                  prefixIcon: const Icon(Icons.search, color: Colors.pinkAccent),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.pinkAccent.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Colors.pinkAccent),
                  ),
                ),
              ),
            ),

            // Chat List
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: 8,
        itemBuilder: (context, index) {
          final left = index % 2 == 0;
          return ChatItemSkeleton(isLeft: left);
        },
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadChats,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final chats = _filteredChats;

    if (chats.isEmpty) {
      return _buildNoChatsView();
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: chats.length,
        itemBuilder: (context, index) {
          final chat = chats[index];
          return _buildChatCard(chat);
        },
      ),
    );
  }

  Widget _buildChatCard(Chat chat) {
    final hasUnread = chat.unreadCount > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE91E63).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE91E63).withOpacity(0.1),
            blurRadius: 12,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  expertName: chat.otherUserName ?? 'User',
                  imagePath: 'assets/images/khushi.jpg',
                  chatId: chat.chatId,
                  otherUserAvatar: chat.otherUserAvatar,
                ),
              ),
            ).then((_) => _loadChats()); // Refresh when returning
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFFFF1F5),
                      backgroundImage: _resolveAvatar(chat.otherUserAvatar),
                      onBackgroundImageError: (chat.otherUserAvatar != null &&
                              chat.otherUserAvatar!.isNotEmpty &&
                              chat.otherUserAvatar!.startsWith('http'))
                          ? (_, __) {} // silently ignore network errors
                          : null,
                      child: (chat.otherUserAvatar == null ||
                              chat.otherUserAvatar!.isEmpty)
                          ? const Icon(Icons.person, size: 30, color: Colors.pinkAccent)
                          : null,
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.pinkAccent,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.otherUserName ?? 'User',
                        style: TextStyle(
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (chat.lastMessage != null)
                        Text(
                          chat.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread ? Colors.black87 : Colors.grey.shade600,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (chat.lastMessageAt != null)
                      Text(
                        _formatTime(chat.lastMessageAt!),
                        style: TextStyle(
                          color: hasUnread ? Colors.pinkAccent : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              expertName: chat.otherUserName ?? 'User',
                              imagePath: 'assets/images/khushi.jpg',
                              chatId: chat.chatId,
                              otherUserAvatar: chat.otherUserAvatar,
                            ),
                          ),
                        ).then((_) => _loadChats());
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        "Reply",
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Parse a timestamp string as UTC. Server sends UTC ISO strings.
  /// DEVICE-TIME FIX: If timezone info is missing, force UTC to prevent
  /// wrong time display. Client converts to local via .toLocal().
  static DateTime? _parseAsUtc(String? value) {
    if (value == null || value.isEmpty) return null;
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    if (dt.isUtc) return dt;
    return DateTime.utc(
      dt.year, dt.month, dt.day,
      dt.hour, dt.minute, dt.second,
      dt.millisecond, dt.microsecond,
    );
  }

  String _formatTime(DateTime timestamp) {
    // DEVICE-TIME FIX: Convert UTC timestamp to device local time for correct display.
    // No hardcoded offsets — .toLocal() uses the device's OS timezone setting.
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final difference = now.difference(local);

    if (difference.inDays == 0 && now.day == local.day) {
      final hour = local.hour;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    } else if (difference.inDays <= 1 && now.day != local.day) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${local.day}/${local.month}';
    }
  }

  Widget _buildNoChatsView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.pinkAccent.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF880E4F),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When users message you, they\'ll appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: _loadChats,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }
}
