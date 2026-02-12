import 'dart:async';
import 'package:flutter/material.dart';
import '../actions/charting.dart';
import '../../services/chat_service.dart';
import '../../services/socket_service.dart';
import '../../models/chat_model.dart';
import '../../models/listener_model.dart' as models;
import '../../services/listener_service.dart';
import '../../ui/skeleton_loading_ui/chat_item_skeleton.dart';

/// Resolve avatar string to the correct ImageProvider.
/// Asset paths (e.g. 'assets/...') → AssetImage, URLs → NetworkImage.
ImageProvider? _resolveAvatar(String? avatar) {
  if (avatar == null || avatar.isEmpty) return null;
  if (avatar.startsWith('http')) return NetworkImage(avatar);
  return AssetImage(avatar);
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
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = <String>{};
  final Set<String> _archivedChatIds = <String>{};

  // Real-time online status tracking
  Map<String, bool> _onlineStatus = {};

  // Stream subscriptions
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  StreamSubscription<Map<String, bool>>? _statusSubscription;

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
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    // Listen for new messages to update chat list in-place (no full reload)
    _messageSubscription = _socketService.onChatMessage.listen((data) {
      if (mounted) {
        _updateChatFromMessage(data);
      }
    });

    // Listen for notifications (when NOT in a chat room)
    _notificationSubscription = _socketService.onChatNotification.listen((
      data,
    ) {
      if (mounted) {
        _updateChatFromMessage(data);
      }
    });

    // Track listener online/offline status in real-time
    _statusSubscription = _socketService.listenerStatusStream.listen((
      statusMap,
    ) {
      if (mounted) {
        setState(() {
          _onlineStatus = statusMap;
        });
      }
    });
  }

  /// Update a single chat in-place from a socket message instead of reloading all chats
  void _updateChatFromMessage(Map<String, dynamic> data) {
    final chatId = data['chatId']?.toString();
    final messageData = data['message'] as Map<String, dynamic>?;
    if (chatId == null || messageData == null) {
      // Fallback: reload from API if data is incomplete
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
        // Update existing chat in-place
        final old = _chats[idx];
        final senderId = messageData['sender_id']?.toString() ?? '';
        // Determine the current user from chat participants
        final currentUserIsUser1 = old.user1Id != senderId;
        final isFromOther = currentUserIsUser1
            ? senderId == old.user2Id
            : senderId == old.user1Id;
        _chats[idx] = Chat(
          chatId: old.chatId,
          user1Id: old.user1Id,
          user2Id: old.user2Id,
          lastMessageAt: createdAt,
          createdAt: old.createdAt,
          otherUserName: old.otherUserName,
          otherUserAvatar: old.otherUserAvatar,
          lastMessage: messageContent,
          unreadCount: isFromOther ? old.unreadCount + 1 : old.unreadCount,
        );
        // Move this chat to the top
        final updated = _chats.removeAt(idx);
        _chats.insert(0, updated);
      } else {
        // New chat arrived – reload to get full details
        _loadChats();
      }
    });
  }

  Future<void> _loadChats() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final result = await _chatService.getChats();

      if (result.success) {
        // Also snapshot online status
        _onlineStatus = Map.from(_socketService.listenerOnlineMap);

        setState(() {
          _chats = result.chats;
          final chatIds = _chats.map((chat) => chat.chatId).toSet();
          _selectedChatIds.removeWhere((id) => !chatIds.contains(id));
          _archivedChatIds.removeWhere((id) => !chatIds.contains(id));
          if (_selectedChatIds.isEmpty) {
            _isSelectionMode = false;
          }
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

  List<Chat> _sortChatsByRecent(List<Chat> chats) {
    final sorted = List<Chat>.from(chats);
    sorted.sort((a, b) {
      final aTime =
          a.lastMessageAt ??
          a.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.lastMessageAt ??
          b.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  List<Chat> get _filteredChats {
    final sorted = _sortChatsByRecent(_chats);
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return sorted;

    return sorted.where((chat) {
      final name = chat.otherUserName?.toLowerCase() ?? '';
      final lastMessage = chat.lastMessage?.toLowerCase() ?? '';
      return name.contains(query) || lastMessage.contains(query);
    }).toList();
  }

  /// Check if the other user in a chat is online
  bool _isOtherUserOnline(Chat chat) {
    return _onlineStatus[chat.user2Id] == true ||
        _onlineStatus[chat.user1Id] == true;
  }

  /// Open the new-chat picker to start a conversation with any listener
  void _openNewChatPicker() async {
    final selectedListener = await showModalBottomSheet<models.Listener>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ListenerPickerSheet(),
    );

    if (selectedListener != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatPage(
            expertName: selectedListener.professionalName ?? 'Expert',
            imagePath: 'assets/images/khushi.jpg',
            otherUserId: selectedListener.userId,
            otherUserAvatar: selectedListener.avatarUrl,
          ),
        ),
      ).then((_) => _loadChats());
    }
  }

  void _openChat(Chat chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          expertName: chat.otherUserName ?? 'Expert',
          imagePath: 'assets/images/khushi.jpg',
          chatId: chat.chatId,
          otherUserAvatar: chat.otherUserAvatar,
        ),
      ),
    ).then(_handleChatPageResult);
  }

  void _handleChatPageResult(dynamic result) {
    if (!mounted) return;

    if (result is Map && result['deletedChatId'] is String) {
      final deletedChatId = result['deletedChatId'] as String;
      setState(() {
        _chats.removeWhere((chat) => chat.chatId == deletedChatId);
        _selectedChatIds.remove(deletedChatId);
        _archivedChatIds.remove(deletedChatId);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
      });
      return;
    }

    _loadChats();
  }

  void _startSelectionMode(String chatId) {
    setState(() {
      _isSelectionMode = true;
      _selectedChatIds
        ..clear()
        ..add(chatId);
    });
  }

  void _toggleChatSelection(String chatId) {
    setState(() {
      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }

      if (_selectedChatIds.isEmpty) {
        _isSelectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    if (!_isSelectionMode) return;
    setState(() {
      _isSelectionMode = false;
      _selectedChatIds.clear();
    });
  }

  bool get _allFilteredChatsSelected {
    final filtered = _filteredChats;
    if (filtered.isEmpty) return false;
    return filtered.every((chat) => _selectedChatIds.contains(chat.chatId));
  }

  void _selectAllOrUnselectAll() {
    final filteredIds = _filteredChats.map((chat) => chat.chatId).toSet();
    if (filteredIds.isEmpty) return;

    setState(() {
      final allSelected = filteredIds.every(
        (chatId) => _selectedChatIds.contains(chatId),
      );
      if (allSelected) {
        _selectedChatIds.removeAll(filteredIds);
        if (_selectedChatIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _isSelectionMode = true;
        _selectedChatIds.addAll(filteredIds);
      }
    });
  }

  void _handlePrimaryMenuAction(String action) {
    if (action == 'select_all') {
      _selectAllOrUnselectAll();
    }
  }

  Future<void> _handleSelectionMenuAction(String action) async {
    switch (action) {
      case 'select_all':
        _selectAllOrUnselectAll();
        break;
      case 'archive':
        _toggleDraftArchiveForSelectedChats();
        break;
      case 'clear':
        await _clearSelectedChats();
        break;
      case 'delete':
        await _deleteSelectedChats();
        break;
    }
  }

  Future<void> _deleteSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;

    final selectedIds = _selectedChatIds.toList(growable: false);
    final selectedIdSet = selectedIds.toSet();
    final confirmed = await _showConfirmationDialog(
      title: 'Delete selected chats?',
      content:
          'This will remove ${selectedIds.length} selected chat(s) from your chat list.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final results = await Future.wait(
      selectedIds.map((chatId) => _chatService.deleteChat(chatId)),
    );

    final failedIdSet = <String>{};
    for (int index = 0; index < selectedIds.length; index++) {
      if (!results[index]) {
        failedIdSet.add(selectedIds[index]);
      }
    }

    if (!mounted) return;

    setState(() {
      _chats.removeWhere(
        (chat) =>
            selectedIdSet.contains(chat.chatId) &&
            !failedIdSet.contains(chat.chatId),
      );
      _archivedChatIds.removeWhere(
        (chatId) =>
            selectedIdSet.contains(chatId) && !failedIdSet.contains(chatId),
      );
      _selectedChatIds.clear();
      _isSelectionMode = false;
    });

    if (failedIdSet.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Deleted ${selectedIds.length - failedIdSet.length} chat(s). ${failedIdSet.length} failed.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${selectedIds.length} chat(s)')),
    );
  }

  void _toggleDraftArchiveForSelectedChats() {
    if (_selectedChatIds.isEmpty) return;

    final selectedIds = Set<String>.from(_selectedChatIds);
    final allArchived = selectedIds.every(_archivedChatIds.contains);

    setState(() {
      if (allArchived) {
        _archivedChatIds.removeAll(selectedIds);
      } else {
        _archivedChatIds.addAll(selectedIds);
      }
      _selectedChatIds.clear();
      _isSelectionMode = false;
    });

    // TODO: Persist draft/archive state via backend endpoint when available.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allArchived
              ? 'Chats moved back to inbox'
              : 'Chats marked as draft/archived',
        ),
      ),
    );
  }

  Future<void> _clearSelectedChats() async {
    if (_selectedChatIds.isEmpty) return;

    final selectedIds = _selectedChatIds.toList(growable: false);
    final selectedIdSet = selectedIds.toSet();
    final confirmed = await _showConfirmationDialog(
      title: 'Clear selected chats?',
      content:
          'Messages for ${selectedIds.length} selected chat(s) will be cleared.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    final results = await Future.wait(
      selectedIds.map((chatId) => _chatService.clearChat(chatId)),
    );
    final failedIdSet = <String>{};
    for (int index = 0; index < selectedIds.length; index++) {
      if (!results[index]) {
        failedIdSet.add(selectedIds[index]);
      }
    }

    if (!mounted) return;

    setState(() {
      _chats = _chats.map((chat) {
        if (!selectedIdSet.contains(chat.chatId) ||
            failedIdSet.contains(chat.chatId)) {
          return chat;
        }
        return Chat(
          chatId: chat.chatId,
          user1Id: chat.user1Id,
          user2Id: chat.user2Id,
          lastMessageAt: null,
          createdAt: chat.createdAt,
          otherUserName: chat.otherUserName,
          otherUserAvatar: chat.otherUserAvatar,
          lastMessage: null,
          unreadCount: 0,
        );
      }).toList();
      _selectedChatIds.clear();
      _isSelectionMode = false;
    });

    if (failedIdSet.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Cleared ${selectedIds.length - failedIdSet.length} chat(s). ${failedIdSet.length} failed.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Selected chats cleared')));
  }

  Future<bool> _showConfirmationDialog({
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

  // ============================================
  // BUILD
  // ============================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        floatingActionButton: _isSelectionMode
            ? null
            : FloatingActionButton(
                backgroundColor: Colors.pinkAccent,
                onPressed: _openNewChatPicker,
                child: const Icon(Icons.chat, color: Colors.white),
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
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.pinkAccent,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 15,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide(
                        color: Colors.pinkAccent.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: const BorderSide(color: Colors.pinkAccent),
                    ),
                  ),
                ),
              ),

              // Chat list or empty state
              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    if (_isSelectionMode) {
      final allSelected = _allFilteredChatsSelected;
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.pinkAccent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          '${_selectedChatIds.length} selected',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: Icon(
              allSelected ? Icons.deselect : Icons.select_all,
              color: Colors.white,
            ),
            tooltip: allSelected ? 'Unselect all' : 'Select all',
            onPressed: _filteredChats.isEmpty ? null : _selectAllOrUnselectAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            tooltip: 'Delete',
            onPressed: _selectedChatIds.isEmpty ? null : _deleteSelectedChats,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) => _handleSelectionMenuAction(value),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'select_all',
                child: Text(allSelected ? 'Unselect all' : 'Select all'),
              ),
              const PopupMenuItem<String>(
                value: 'archive',
                child: Text('Draft/Archive'),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear chat'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      );
    }

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.pinkAccent,
      title: const Text(
        'Chats',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: _handlePrimaryMenuAction,
          itemBuilder: (context) => [
            if (_filteredChats.isNotEmpty)
              const PopupMenuItem<String>(
                value: 'select_all',
                child: Text('Select all'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    final chats = _filteredChats;

    if (chats.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadChats,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: chats.length,
        itemBuilder: (context, index) => _buildChatTile(chats[index]),
      ),
    );
  }

  // ============================================
  // WhatsApp-style chat tile
  // ============================================

  Widget _buildChatTile(Chat chat) {
    final hasUnread = chat.unreadCount > 0;
    final isOnline = _isOtherUserOnline(chat);
    final isSelected = _selectedChatIds.contains(chat.chatId);
    final isArchived = _archivedChatIds.contains(chat.chatId);

    return InkWell(
      onLongPress: () {
        if (_isSelectionMode) {
          _toggleChatSelection(chat.chatId);
        } else {
          _startSelectionMode(chat.chatId);
        }
      },
      onTap: () {
        if (_isSelectionMode) {
          _toggleChatSelection(chat.chatId);
          return;
        }
        _openChat(chat);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.pinkAccent.withOpacity(0.12)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: Colors.pinkAccent.withOpacity(0.15),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFFFF1F5),
                  backgroundImage: _resolveAvatar(chat.otherUserAvatar),
                  onBackgroundImageError:
                      (chat.otherUserAvatar != null &&
                          chat.otherUserAvatar!.isNotEmpty &&
                          chat.otherUserAvatar!.startsWith('http'))
                      ? (_, __) {} // silently ignore network errors
                      : null,
                  child:
                      (chat.otherUserAvatar == null ||
                          chat.otherUserAvatar!.isEmpty)
                      ? const Icon(
                          Icons.person,
                          size: 30,
                          color: Colors.pinkAccent,
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.grey.shade400,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                if (_isSelectionMode)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.pinkAccent : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.pinkAccent,
                          width: 1.5,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Name + last message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.otherUserName ?? 'Expert',
                          style: TextStyle(
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isArchived)
                        const Icon(
                          Icons.archive_outlined,
                          size: 14,
                          color: Colors.pinkAccent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (isArchived)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: Text(
                        'Draft/Archived',
                        style: TextStyle(
                          color: Colors.pinkAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    chat.lastMessage ?? 'Tap to start chatting',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasUnread ? Colors.black87 : Colors.grey.shade600,
                      fontWeight: hasUnread
                          ? FontWeight.w500
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Timestamp + unread badge
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
                const SizedBox(height: 6),
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.pinkAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      chat.unreadCount > 99
                          ? '99+'
                          : chat.unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // Helpers
  // ============================================

  /// Parse a timestamp string as UTC. Server sends UTC ISO strings.
  /// DEVICE-TIME FIX: If timezone info is missing, force UTC to prevent
  /// wrong time display. Client converts to local via .toLocal().
  static DateTime? _parseAsUtc(String? value) {
    if (value == null || value.isEmpty) return null;
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    if (dt.isUtc) return dt;
    return DateTime.utc(
      dt.year,
      dt.month,
      dt.day,
      dt.hour,
      dt.minute,
      dt.second,
      dt.millisecond,
      dt.microsecond,
    );
  }

  String _formatTime(DateTime timestamp) {
    // DEVICE-TIME FIX: Convert UTC timestamp to device local time for correct display.
    // No hardcoded offsets — .toLocal() uses the device's OS timezone setting.
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.inDays == 0 && now.day == local.day) {
      final h = local.hour;
      final m = local.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'PM' : 'AM';
      final dh = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$dh:$m $period';
    } else if (diff.inDays <= 1 && now.day != local.day) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    } else {
      return '${local.day}/${local.month}/${local.year % 100}';
    }
  }

  Widget _buildEmptyState() {
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
            'Tap the + button to start a conversation',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openNewChatPicker,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'New Chat',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// Bottom-sheet listener picker (start new chat with any listener)
// ============================================

class _ListenerPickerSheet extends StatefulWidget {
  const _ListenerPickerSheet();

  @override
  State<_ListenerPickerSheet> createState() => _ListenerPickerSheetState();
}

class _ListenerPickerSheetState extends State<_ListenerPickerSheet> {
  final ListenerService _listenerService = ListenerService();
  final SocketService _socketService = SocketService();

  List<models.Listener> _listeners = [];
  bool _isLoading = true;
  String _search = '';
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Fetch ALL listeners (online + offline)
      final result = await _listenerService.getListeners(
        sortBy: 'rating',
        limit: 100,
      );
      if (result.success && mounted) {
        setState(() {
          _listeners = result.listeners;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<models.Listener> get _filtered {
    if (_search.isEmpty) return _listeners;
    final q = _search.toLowerCase();
    return _listeners.where((l) {
      final name = l.professionalName?.toLowerCase() ?? '';
      final specs = l.specialties.join(' ').toLowerCase();
      return name.contains(q) || specs.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Start New Chat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF880E4F),
              ),
            ),
            const SizedBox(height: 8),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search experts...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.pinkAccent,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFFFF1F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.pinkAccent,
                      ),
                    )
                  : _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No experts found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final l = _filtered[i];
                        final online =
                            _socketService.listenerOnlineMap[l.userId] ??
                            l.isOnline;
                        return ListTile(
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: const Color(0xFFFFF1F5),
                                backgroundImage: _resolveAvatar(l.avatarUrl),
                                child:
                                    (l.avatarUrl == null ||
                                        l.avatarUrl!.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        size: 26,
                                        color: Colors.pinkAccent,
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: online
                                        ? Colors.green
                                        : Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            l.professionalName ?? 'Expert',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            l.specialties.isNotEmpty
                                ? l.specialties.first
                                : (online ? 'Online' : 'Offline'),
                            style: TextStyle(
                              color: online ? Colors.pinkAccent : Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                          trailing: Text(
                            online ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: online ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => Navigator.pop(context, l),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
