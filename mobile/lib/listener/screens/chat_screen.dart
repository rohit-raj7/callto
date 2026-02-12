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
  bool _isSelectionMode = false;
  final Set<String> _selectedChatIds = <String>{};
  final Set<String> _archivedChatIds = <String>{};

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

    _notificationSubscription = _socketService.onChatNotification.listen((
      data,
    ) {
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

  void _openChat(Chat chat) {
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
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Colors.pinkAccent,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
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

              // Chat List
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
        'Chat with Users',
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
    final isSelected = _selectedChatIds.contains(chat.chatId);
    final isArchived = _archivedChatIds.contains(chat.chatId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFF1F5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? Colors.pinkAccent
              : const Color(0xFFE91E63).withOpacity(0.3),
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
                    if (_isSelectionMode)
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.pinkAccent
                                : Colors.white,
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chat.otherUserName ?? 'User',
                              style: TextStyle(
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 16,
                              ),
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
                      if (chat.lastMessage != null)
                        Text(
                          chat.lastMessage!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? Colors.black87
                                : Colors.grey.shade600,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
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
                        if (_isSelectionMode) {
                          _toggleChatSelection(chat.chatId);
                          return;
                        }
                        _openChat(chat);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextButton(onPressed: _loadChats, child: const Text('Refresh')),
        ],
      ),
    );
  }
}
