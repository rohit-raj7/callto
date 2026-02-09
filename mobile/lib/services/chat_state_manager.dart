import 'dart:async';

/// Global singleton to track chat screen state across the app.
/// This enables WhatsApp-like behavior where notifications are only shown
/// when the user is NOT actively viewing the chat screen.
class ChatStateManager {
  static final ChatStateManager _instance = ChatStateManager._internal();
  factory ChatStateManager() => _instance;
  ChatStateManager._internal();

  // ============================================
  // STATE TRACKING
  // ============================================

  /// Whether the chat screen is currently visible/active
  bool _isChatScreenActive = false;

  /// The currently active chat ID (null if not on chat screen)
  String? _activeChatId;

  /// Whether the app is in foreground
  bool _isAppInForeground = true;

  /// Current user ID
  String? _currentUserId;

  /// StreamController to notify listeners of state changes
  final StreamController<ChatState> _stateController = 
      StreamController<ChatState>.broadcast();

  // ============================================
  // GETTERS
  // ============================================

  /// Check if chat screen is currently active
  bool get isChatScreenActive => _isChatScreenActive;

  /// Get the currently active chat ID
  String? get activeChatId => _activeChatId;

  /// Check if app is in foreground
  bool get isAppInForeground => _isAppInForeground;

  /// Get current user ID
  String? get currentUserId => _currentUserId;

  /// Stream of chat state changes
  Stream<ChatState> get stateStream => _stateController.stream;

  /// Check if a specific chat is currently being viewed
  bool isViewingChat(String chatId) {
    return _isChatScreenActive && _activeChatId == chatId;
  }

  /// Check if user should receive notification for a message
  /// Returns false if user is currently viewing the chat (WhatsApp behavior)
  bool shouldShowNotification(String chatId) {
    // Don't show notification if:
    // 1. App is in foreground AND
    // 2. User is on chat screen AND
    // 3. The message is for the currently active chat
    if (_isAppInForeground && _isChatScreenActive && _activeChatId == chatId) {
      return false;
    }
    return true;
  }

  // ============================================
  // SETTERS / STATE UPDATES
  // ============================================

  /// Set the current user ID
  void setCurrentUserId(String? userId) {
    _currentUserId = userId;
    _notifyStateChange();
  }

  /// Called when user enters a chat screen
  void enterChatScreen(String chatId) {
    print('[ChatStateManager] Entering chat screen: $chatId');
    _isChatScreenActive = true;
    _activeChatId = chatId;
    _notifyStateChange();
  }

  /// Called when user leaves a chat screen
  void leaveChatScreen() {
    print('[ChatStateManager] Leaving chat screen (was: $_activeChatId)');
    _isChatScreenActive = false;
    _activeChatId = null;
    _notifyStateChange();
  }

  /// Called when app goes to foreground
  void appResumed() {
    print('[ChatStateManager] App resumed (foreground)');
    _isAppInForeground = true;
    _notifyStateChange();
  }

  /// Called when app goes to background
  void appPaused() {
    print('[ChatStateManager] App paused (background)');
    _isAppInForeground = false;
    // Note: We don't clear activeChatId here so we know what chat
    // the user was viewing when they return
    _notifyStateChange();
  }

  /// Get current state as object
  ChatState get currentState => ChatState(
    isChatScreenActive: _isChatScreenActive,
    activeChatId: _activeChatId,
    isAppInForeground: _isAppInForeground,
    currentUserId: _currentUserId,
  );

  void _notifyStateChange() {
    _stateController.add(currentState);
  }

  /// Dispose resources
  void dispose() {
    _stateController.close();
  }
}

/// Immutable state object for chat state
class ChatState {
  final bool isChatScreenActive;
  final String? activeChatId;
  final bool isAppInForeground;
  final String? currentUserId;

  ChatState({
    required this.isChatScreenActive,
    this.activeChatId,
    required this.isAppInForeground,
    this.currentUserId,
  });

  @override
  String toString() {
    return 'ChatState(active: $isChatScreenActive, chatId: $activeChatId, foreground: $isAppInForeground, userId: $currentUserId)';
  }
}
