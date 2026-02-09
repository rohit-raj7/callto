import 'dart:async';
import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../services/chat_state_manager.dart';
import '../services/storage_service.dart';
import '../user/actions/charting.dart' as user_chat;
import '../listener/actions/charting.dart' as listener_chat;

class InAppChatNotificationService {
  static final InAppChatNotificationService _instance =
      InAppChatNotificationService._internal();
  factory InAppChatNotificationService() => _instance;
  InAppChatNotificationService._internal();

  final SocketService _socketService = SocketService();
  final ChatStateManager _chatStateManager = ChatStateManager();
  final StorageService _storageService = StorageService();

  StreamSubscription<Map<String, dynamic>>? _subscription;
  OverlayEntry? _overlayEntry;
  Timer? _dismissTimer;
  bool _initialized = false;
  GlobalKey<NavigatorState>? _navigatorKey;

  final Set<String> _recentMessageIds = {};

  void initialize(GlobalKey<NavigatorState> navigatorKey) {
    if (_initialized) return;
    _initialized = true;
    _navigatorKey = navigatorKey;

    _subscription = _socketService.onChatNotification.listen(_handleMessage);
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _removeOverlay();
    _initialized = false;
  }

  void _handleMessage(Map<String, dynamic> data) async {
    final chatId = data['chatId']?.toString();
    final message = data['message'] as Map<String, dynamic>?;
    if (chatId == null || message == null) return;

    if (!_chatStateManager.shouldShowNotification(chatId)) return;

    final messageId = message['message_id']?.toString();
    if (messageId != null && _recentMessageIds.contains(messageId)) return;

    if (messageId != null) {
      _recentMessageIds.add(messageId);
      Timer(const Duration(seconds: 30), () {
        _recentMessageIds.remove(messageId);
      });
    }

    final senderId = message['sender_id']?.toString();
    final senderName = message['sender_name']?.toString() ?? 'New message';
    final senderAvatar = message['sender_avatar']?.toString();
    final content = message['message_content']?.toString() ?? '';

    _showBanner(
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      messagePreview: content,
    );
  }

  void _showBanner({
    required String chatId,
    required String senderName,
    required String messagePreview,
    String? senderId,
    String? senderAvatar,
  }) {
    final context = _navigatorKey?.currentState?.overlay?.context;
    if (context == null) return;

    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return _ChatBanner(
          senderName: senderName,
          senderAvatar: senderAvatar,
          messagePreview: messagePreview,
          onTap: () => _handleTap(
            chatId: chatId,
            senderId: senderId,
            senderName: senderName,
            senderAvatar: senderAvatar,
          ),
          onDismiss: _removeOverlay,
        );
      },
    );

    _navigatorKey?.currentState?.overlay?.insert(_overlayEntry!);

    _dismissTimer?.cancel();
    _dismissTimer = Timer(const Duration(seconds: 4), () {
      _removeOverlay();
    });
  }

  Future<void> _handleTap({
    required String chatId,
    required String senderName,
    required String? senderId,
    required String? senderAvatar,
  }) async {
    _removeOverlay();

    final navigator = _navigatorKey?.currentState;
    if (navigator == null) return;

    _socketService.setActivelyViewingChat(chatId);

    final isListener = await _storageService.getIsListener();

    if (isListener) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => listener_chat.ChatPage(
            expertName: senderName,
            imagePath: 'assets/images/khushi.jpg',
            chatId: chatId,
            otherUserId: senderId,
            otherUserAvatar: senderAvatar,
          ),
        ),
      );
      return;
    }

    navigator.push(
      MaterialPageRoute(
        builder: (_) => user_chat.ChatPage(
          expertName: senderName,
          imagePath: 'assets/images/khushi.jpg',
          chatId: chatId,
          otherUserId: senderId,
          otherUserAvatar: senderAvatar,
        ),
      ),
    );
  }

  void _removeOverlay() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _ChatBanner extends StatefulWidget {
  final String senderName;
  final String? senderAvatar;
  final String messagePreview;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ChatBanner({
    required this.senderName,
    required this.senderAvatar,
    required this.messagePreview,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_ChatBanner> createState() => _ChatBannerState();
}

class _ChatBannerState extends State<_ChatBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _offset = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ImageProvider? _resolveAvatar(String? avatar) {
    if (avatar == null || avatar.isEmpty) return null;
    if (avatar.startsWith('http')) return NetworkImage(avatar);
    return AssetImage(avatar);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = _resolveAvatar(widget.senderAvatar);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SlideTransition(
          position: _offset,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFFFF1F5),
                      backgroundImage: avatar,
                      child: avatar == null
                          ? const Icon(Icons.person,
                              size: 22, color: Colors.pinkAccent)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.senderName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF2A2A2A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.messagePreview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close, size: 18),
                      color: Colors.grey.shade500,
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
