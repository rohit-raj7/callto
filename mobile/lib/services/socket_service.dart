import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'api_config.dart';
import 'storage_service.dart';
import 'chat_state_manager.dart';

/// Incoming call data model
class IncomingCall {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String? topic;
  final String? language;
  final String? gender;
  final int? age;
  final DateTime timestamp;
  int waitTimeSeconds;

  IncomingCall({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    this.topic,
    this.language,
    this.gender,
    this.age,
    required this.timestamp,
    this.waitTimeSeconds = 0,
  });

  factory IncomingCall.fromJson(Map<String, dynamic> json) {
    final avatarUrl = json['caller_avatar'] ?? json['callerAvatar'];
    print('[IncomingCall] Parsing call - callerName: ${json['caller_name'] ?? json['callerName']}, callerAvatar: $avatarUrl');
    return IncomingCall(
      callId: json['call_id']?.toString() ?? json['callId']?.toString() ?? '',
      callerId: json['caller_id']?.toString() ?? json['callerId']?.toString() ?? '',
      callerName: json['caller_name'] ?? json['callerName'] ?? 'Unknown',
      callerAvatar: avatarUrl,
      topic: json['topic'],
      language: json['language'] ?? 'English',
      gender: json['gender'],
      age: json['age'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'call_id': callId,
    'caller_id': callerId,
    'caller_name': callerName,
    'caller_avatar': callerAvatar,
    'topic': topic,
    'language': language,
    'gender': gender,
    'age': age,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Socket service for real-time communication
class SocketService {
    // Private controller fields - Call related
    StreamController<IncomingCall>? _incomingCallController;
    StreamController<Map<String, dynamic>>? _callAcceptedController;
    StreamController<Map<String, dynamic>>? _callRejectedController;
    StreamController<Map<String, dynamic>>? _callFailedController;
    StreamController<Map<String, dynamic>>? _callEndedController;
    StreamController<Map<String, dynamic>>? _callConnectedController;
    StreamController<bool>? _connectionStateController;
    StreamController<String>? _userOnlineController;
    StreamController<String>? _userOfflineController;
    
    // Private controller fields - Chat related
    StreamController<Map<String, dynamic>>? _chatMessageController;
    StreamController<Map<String, dynamic>>? _chatHistoryController;
    StreamController<Map<String, dynamic>>? _chatTypingController;
    StreamController<Map<String, dynamic>>? _chatReadController;
    StreamController<Map<String, dynamic>>? _chatErrorController;
    StreamController<Map<String, dynamic>>? _chatNotificationController;
    StreamController<Map<String, dynamic>>? _messageDeletedController; // For delete_message events
  StreamController<Map<String, dynamic>>? _appNotificationController;
    
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? _socket;
  final StorageService _storage = StorageService();
  final ChatStateManager _chatStateManager = ChatStateManager();
  bool _isConnected = false;
  String? _listenerUserId;
  final Map<String, bool> listenerOnlineMap = {}; // Tracks all listeners' online status
  final StreamController<Map<String, bool>> _listenerStatusController = StreamController.broadcast();
  bool _connecting = false;
  final bool _listenerRegistered = false;
  
  // Track joined chat rooms
  final Set<String> _joinedChatRooms = {};
  
  // Track which chat room user is actively viewing (for notification suppression)
  String? _activelyViewingChatId;
  
  // User info for chat
  String? _userName;
  String? _userAvatar;
  
  void _log(String msg) {
    print('[SOCKET] $msg');
  }

  // Getters that lazily create controllers if needed
  StreamController<IncomingCall> get _incomingCall {
    _incomingCallController ??= StreamController<IncomingCall>.broadcast();
    return _incomingCallController!;
  }
  // Public stream for incoming-call event
  Stream<IncomingCall> get onIncomingCallEvent => _incomingCall.stream;
  
  StreamController<Map<String, dynamic>> get _callAccepted {
    _callAcceptedController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _callAcceptedController!;
  }
  
  StreamController<Map<String, dynamic>> get _callRejected {
    _callRejectedController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _callRejectedController!;
  }
  
  StreamController<Map<String, dynamic>> get _callFailed {
    _callFailedController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _callFailedController!;
  }
  
  StreamController<Map<String, dynamic>> get _callEnded {
    _callEndedController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _callEndedController!;
  }
  
  StreamController<Map<String, dynamic>> get _callConnected {
    _callConnectedController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _callConnectedController!;
  }
  
  StreamController<bool> get _connectionState {
    _connectionStateController ??= StreamController<bool>.broadcast();
    return _connectionStateController!;
  }

  StreamController<String> get _userOnline {
    _userOnlineController ??= StreamController<String>.broadcast();
    return _userOnlineController!;
  }

  StreamController<String> get _userOffline {
    _userOfflineController ??= StreamController<String>.broadcast();
    return _userOfflineController!;
  }

  // Chat-related getters for lazy controller creation
  StreamController<Map<String, dynamic>> get _chatMessage {
    _chatMessageController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _chatMessageController!;
  }

  StreamController<Map<String, dynamic>> get _chatHistory {
    _chatHistoryController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _chatHistoryController!;
  }

  StreamController<Map<String, dynamic>> get _chatTyping {
    _chatTypingController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _chatTypingController!;
  }

  StreamController<Map<String, dynamic>> get _chatRead {
    _chatReadController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _chatReadController!;
  }

  StreamController<Map<String, dynamic>> get _chatError {
    _chatErrorController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _chatErrorController!;
  }

  StreamController<Map<String, dynamic>> get _chatNotification {
    _chatNotificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _chatNotificationController!;
  }

  StreamController<Map<String, dynamic>> get _messageDeleted {
    _messageDeletedController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _messageDeletedController!;
  }
  StreamController<Map<String, dynamic>> get _appNotification {
    _appNotificationController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _appNotificationController!;
  }

  // Public streams - Call related
  Stream<IncomingCall> get onIncomingCall => _incomingCall.stream;
  Stream<Map<String, dynamic>> get onCallAccepted => _callAccepted.stream;
  Stream<Map<String, dynamic>> get onCallRejected => _callRejected.stream;
  Stream<Map<String, dynamic>> get onCallFailed => _callFailed.stream;
  Stream<Map<String, dynamic>> get onCallEnded => _callEnded.stream;
  Stream<Map<String, dynamic>> get onCallConnected => _callConnected.stream;
  Stream<bool> get onConnectionStateChange => _connectionState.stream;
  Stream<String> get onUserOnline => _userOnline.stream;
  Stream<String> get onUserOffline => _userOffline.stream;

  // Public streams - Chat related
  Stream<Map<String, dynamic>> get onChatMessage => _chatMessage.stream;
  Stream<Map<String, dynamic>> get onChatHistory => _chatHistory.stream;
  Stream<Map<String, dynamic>> get onChatTyping => _chatTyping.stream;
  Stream<Map<String, dynamic>> get onChatMessagesRead => _chatRead.stream;
  Stream<Map<String, dynamic>> get onChatError => _chatError.stream;
  Stream<Map<String, dynamic>> get onChatNotification => _chatNotification.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeleted.stream; // For delete_message events
  Stream<Map<String, dynamic>> get onAppNotification => _appNotification.stream;

  bool get isConnected => _socket?.connected ?? false;
  
  // Completer for waiting on connection
  Completer<bool>? _connectionCompleter;
  String? _currentUserId;


  /// Heartbeat timer
  Timer? _heartbeatTimer;

  /// Connect to the socket server and setup listeners
  Future<bool> connect() async {
    if (_isConnected) return true;
    if (_connecting) {
      if (_connectionCompleter != null) return _connectionCompleter!.future;
      return false;
    }
    
    _connecting = true;
    _connectionCompleter = Completer<bool>();
    
    final userId = await _storage.getUserId();
    if (userId == null) {
      _log('No userId found, cannot connect');
      _connecting = false;
      _connectionCompleter!.complete(false);
      return false;
    }
    
    _currentUserId = userId;
    _log('Connecting socket for userId=$userId');
    
    _socket?.dispose();
    _socket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(1000)
          .setExtraHeaders({'Connection': 'keep-alive'})
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      _connecting = false;
      _log('Socket connected: id=${_socket!.id}');
      _connectionState.add(true);
      
      // Update ChatStateManager with current user ID
      _chatStateManager.setCurrentUserId(userId);
      
      // Always join as user - send user data for chat functionality
      _log('Emitting user:join $userId');
      _socket!.emit('user:join', {
        'userId': userId,
        'userName': _userName,
        'userAvatar': _userAvatar,
        'activelyViewingChatId': _activelyViewingChatId, // For notification suppression
      });
      
      // Also join as listener if we were a listener
      if (_listenerOnline) {
        _log('Emitting listener:join $userId');
        _socket!.emit('listener:join', userId);
      }
      
      // Re-join any chat rooms we were in
      for (final chatId in _joinedChatRooms) {
        _socket!.emit('chat:join', {
          'chatId': chatId,
          'isActivelyViewing': chatId == _activelyViewingChatId,
        });
      }
      
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(true);
      }
    });

    _socket!.onConnectError((err) {
      _isConnected = false;
      _connecting = false;
      _log('Socket connect error: $err');
      _connectionState.add(false);
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(false);
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _log('Socket disconnected');
      _connectionState.add(false);
    });

    // --- RE-REGISTER ALL LISTENERS ON EVERY NEW SOCKET INSTANCE ---
    _socket!.on('listener_status', (data) {
      if (data is Map && data['listenerUserId'] != null && data['online'] != null) {
        final id = data['listenerUserId'].toString();
        final online = data['online'] == true;
        listenerOnlineMap[id] = online;
        _listenerStatusController.add(Map.from(listenerOnlineMap));
      }
    });

    _socket!.on('listeners:initial_status', (data) {
      _log('Received initial listener status: $data');
      if (data is List) {
        // Clear old online status (optional, but good for sync)
        listenerOnlineMap.clear();
        for (var id in data) {
          listenerOnlineMap[id.toString()] = true;
        }
        _listenerStatusController.add(Map.from(listenerOnlineMap));
      }
    });

    _socket!.on('incoming-call', (data) {
      _log('Incoming call received: $data');
      try {
        if (data is Map<String, dynamic>) {
          _incomingCall.add(IncomingCall.fromJson(data));
        } else if (data is Map) {
          _incomingCall.add(IncomingCall.fromJson(Map<String, dynamic>.from(data)));
        }
      } catch (e) {
        _log('Error parsing incoming-call: $e');
      }
    });

    _socket!.on('call:accepted', (data) {
      _callAccepted.add(data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data));
    });
    _socket!.on('call:rejected', (data) {
      _callRejected.add(data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data));
    });
    _socket!.on('call:failed', (data) {
      _log('Call failed: $data');
      // VERIFICATION: Handle call failures including listener_not_approved
      final failureData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
      _callFailed.add(failureData);
    });
    _socket!.on('call:ended', (data) {
      _callEnded.add(data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data));
    });
    _socket!.on('call:connected', (data) {
      _callConnected.add(data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data));
    });

    // --- CHAT EVENT LISTENERS ---
    // WhatsApp-style: chat:message is for real-time UI updates when user is in chat room
    _socket!.on('chat:message', (data) {
      _log('Chat message received: $data');
      try {
        final messageData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        final chatId = messageData['chatId']?.toString();
        
        // Always emit to the stream - ChatPage will handle displaying it
        _chatMessage.add(messageData);
        
        _log('Message for chat $chatId, activelyViewing: $_activelyViewingChatId');
      } catch (e) {
        _log('Error parsing chat:message: $e');
      }
    });

    _socket!.on('chat:history', (data) {
      _log('Chat history received');
      try {
        final historyData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        _chatHistory.add(historyData);
      } catch (e) {
        _log('Error parsing chat:history: $e');
      }
    });

    _socket!.on('chat:user_typing', (data) {
      _log('User typing event: $data');
      try {
        final typingData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        _chatTyping.add(typingData);
      } catch (e) {
        _log('Error parsing chat:user_typing: $e');
      }
    });

    _socket!.on('chat:messages_read', (data) {
      _log('Messages read event: $data');
      try {
        final readData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        _chatRead.add(readData);
      } catch (e) {
        _log('Error parsing chat:messages_read: $e');
      }
    });

    _socket!.on('chat:error', (data) {
      _log('Chat error: $data');
      try {
        final errorData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        _chatError.add(errorData);
      } catch (e) {
        _log('Error parsing chat:error: $e');
      }
    });

    // Listen for new message notifications (for chat list updates)
    // WhatsApp-style: Only process notification if NOT actively viewing that chat
    _socket!.on('chat:new_message_notification', (data) {
      _log('New message notification received: $data');
      try {
        final notificationData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        final chatId = notificationData['chatId']?.toString();
        
        // Check if user is actively viewing this chat - if so, don't emit notification
        final shouldNotify = _chatStateManager.shouldShowNotification(chatId ?? '');
        
        if (shouldNotify) {
          _log('Emitting notification - user not viewing chat $chatId');
          _chatNotification.add(notificationData);
        } else {
          _log('Suppressing notification - user viewing chat $chatId');
        }
      } catch (e) {
        _log('Error parsing chat:new_message_notification: $e');
      }
    });

    // Listen for message deleted events (WhatsApp-style delete for everyone)
    _socket!.on('message:deleted', (data) {
      _log('Message deleted event received: $data');
      try {
        final deleteData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        _messageDeleted.add(deleteData);
      } catch (e) {
        _log('Error parsing message:deleted: $e');
      }
    });
    _socket!.on('app:notification', (data) {
      _log('App notification received: $data');
      try {
        final notifData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
        _appNotification.add(notifData);
      } catch (e) {
        _log('Error parsing app:notification: $e');
      }
    });

    _socket!.connect();
    // Wait for actual connection (with timeout) instead of returning true immediately.
    // On Android the TCP handshake takes real time; returning early caused
    // setListenerOnline to check _socket.connected before it was true,
    // so listener:join was never emitted and incoming calls were lost.
    return _connectionCompleter!.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        _log('Socket connect timed out');
        _connecting = false;
        if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
          _connectionCompleter!.complete(false);
        }
        return false;
      },
    );
  }

  /// Connect to the socket server ONCE and setup listeners (Alias for connect for compatibility)
  Future<void> connectListener() async {
    await connect();
  }

  /// Emit online (app resumed/foreground)
  void emitListenerOnline() {
    if (_isConnected && _currentUserId != null) {
      _log('Emitting listener:join (online) $_currentUserId');
      _socket!.emit('listener:join', _currentUserId);
    }
  }

  /// Emit offline (app paused/detached)
  void emitListenerOffline() {
    if (_isConnected && _currentUserId != null) {
      _log('Emitting listener:offline $_currentUserId');
      _socket!.emit('listener:offline', { 'listenerUserId': _currentUserId });
    }
  }

  /// For user screens: subscribe to online map
  Stream<Map<String, bool>> get listenerStatusStream => _listenerStatusController.stream;

  /// For listener screens: check own online
  bool get isListenerOnline => _currentUserId != null && listenerOnlineMap[_currentUserId!] == true;

  // Getter and setter for listenerOnline
  bool _listenerOnline = false;
  bool get listenerOnline => _listenerOnline;
  set listenerOnline(bool value) => _listenerOnline = value;

  /// Set listener online/offline and update presence
  /// CRITICAL: This controls whether listener can receive incoming calls
  Future<void> setListenerOnline(bool online) async {
    listenerOnline = online;
    final userId = await _storage.getUserId();
    
    if (!online) {
      // Listener going offline - emit offline event but keep socket for chat
      if (_socket != null && _socket!.connected && userId != null) {
        print('[LISTENER] Going offline, emitting listener:offline for userId: $userId');
        _socket!.emit('listener:offline', { 'listenerUserId': userId });
      }
      // NOTE: Don't disconnect socket - keep it for chat functionality
    } else {
      // Listener going online - connect socket and emit online events
      print('[LISTENER] Going online, connecting socket...');
      final connected = await connect();
      if (connected && _socket != null && _socket!.connected && userId != null) {
        print('[LISTENER] Socket connected, emitting user:join and listener:join for userId: $userId');
        _socket!.emit('user:join', {
          'userId': userId,
          'userName': _userName,
          'userAvatar': _userAvatar,
        });
        _socket!.emit('listener:join', userId);
      }
    }
  }

  /// Handle app going to background - notify server and update state
  /// WhatsApp-style: Keep socket connected but notify of background state
  /// IMPORTANT: For listeners, keep socket connected to receive incoming calls
  Future<void> onAppBackground() async {
    _log('App going to background');
    _chatStateManager.appPaused();
    
    final userId = await _storage.getUserId();
    if (_socket != null && _socket!.connected && userId != null) {
      // Notify server that user is in background (for notification decisions)
      _socket!.emit('user:app_state', {
        'userId': userId,
        'state': 'background',
        'activelyViewingChatId': null, // No longer actively viewing any chat
      });
      
      // CRITICAL FIX: For listeners, keep socket connected to receive incoming calls
      // Only notify background state, but DO NOT disconnect or emit offline
      if (listenerOnline) {
        _log('Listener going to background - keeping socket connected for incoming calls');
        // Keep socket connected! Listener should still receive calls in background
        // Just notify server about background state (already done above)
      }
      // For regular users, we could disconnect but WhatsApp-style keeps connected
      // so chat messages arrive in real-time
    }
  }

  /// Handle app coming to foreground - reconnect if needed and update state
  /// WhatsApp-style: Restore socket connection and notify server
  Future<void> onAppForeground() async {
    _log('App coming to foreground');
    _chatStateManager.appResumed();
    
    // Always try to connect when app comes to foreground
    final connected = await connect();
    
    if (connected && _socket != null && _socket!.connected) {
      final userId = await _storage.getUserId();
      if (userId != null) {
        // Notify server that user is in foreground
        _socket!.emit('user:app_state', {
          'userId': userId,
          'state': 'foreground',
          'activelyViewingChatId': _activelyViewingChatId,
        });
        
        // CRITICAL: For listeners, always re-emit listener:join to ensure online status
        // This ensures listener is marked online in backend's listenerSockets map
        if (listenerOnline) {
          _log('Listener coming to foreground - re-emitting listener:join');
          _socket!.emit('user:join', {
            'userId': userId,
            'userName': _userName,
            'userAvatar': _userAvatar,
          });
          _socket!.emit('listener:join', userId);
        }
      }
    }
  }

  /// Emit user online status (for regular users, not just listeners)
  Future<void> emitUserOnline() async {
    final userId = await _storage.getUserId();
    if (_socket != null && _socket!.connected && userId != null) {
      _log('Emitting user:online for $userId');
      _socket!.emit('user:join', {
        'userId': userId,
        'userName': _userName,
        'userAvatar': _userAvatar,
        'activelyViewingChatId': _activelyViewingChatId,
      });
    }
  }

  /// Emit user offline status (for regular users, not just listeners)
  Future<void> emitUserOffline() async {
    final userId = await _storage.getUserId();
    if (_socket != null && _socket!.connected && userId != null) {
      _log('Emitting user:offline for $userId');
      _socket!.emit('user:offline', { 'userId': userId });
    }
  }

  /// Disconnect from the socket server
  void disconnect() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Initiate a call (emit to server)
  void initiateCall({
    required String callId,
    required String listenerId,
    required String callerName,
    String? callerAvatar,
    String? topic,
    String? language,
    String? gender,
    int? age,
  }) {
    _log('Initiating call $callId to $listenerId');
    _socket?.emit('call:initiate', {
      'callId': callId,
      'callerId': _currentUserId, // Add callerId
      'listenerId': listenerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'topic': topic,
      'language': language,
      'gender': gender,
      'age': age,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void emitCallJoined({required String callId, String? otherUserId}) {
    _log('Emitting call:joined for $callId');
    _socket?.emit('call:joined', {
      'callId': callId,
      'otherUserId': otherUserId,
    });
  }

  /// Accept an incoming call
  void acceptCall({required String callId, required String callerId}) {
    _log('Accepting call $callId from $callerId');
    _socket?.emit('call:accept', {
      'callId': callId,
      'callerId': callerId,
    });
  }

  /// Reject an incoming call
  void rejectCall({required String callId, required String callerId}) {
    _log('Rejecting call $callId from $callerId');
    _socket?.emit('call:reject', {
      'callId': callId,
      'callerId': callerId,
    });
  }

  /// End a call
  void endCall({required String callId, String? otherUserId, String? reason}) {
    _log('Ending call $callId');
    _socket?.emit('call:end', {
      'callId': callId,
      'otherUserId': otherUserId,
      'reason': reason ?? 'user_ended',
    });
  }

  /// Notify that user joined a channel (for web simulation)
  void joinedChannel({
    required String callId,
    required String channelName,
  }) {
    print('Socket: Emitting call:joined for channel $channelName');
    _socket?.emit('call:joined', {
      'callId': callId,
      'channelName': channelName,
    });
  }

  /// Notify that user left a channel
  void leftChannel({
    required String channelName,
  }) {
    _socket?.emit('call:left', {
      'channelName': channelName,
    });
  }

  // ============================================
  // CHAT METHODS
  // ============================================

  /// Set user info for chat messages
  void setUserInfo({String? userName, String? userAvatar}) {
    _userName = userName;
    _userAvatar = userAvatar;
  }

  /// Join a chat room AND start actively viewing it (WhatsApp-style)
  /// This will suppress notifications for this chat while it's open
  void joinChatRoom(String chatId) {
    if (_socket == null || !_isConnected) {
      _log('Cannot join chat room - socket not connected');
      return;
    }

    // Track that we're actively viewing this chat
    _activelyViewingChatId = chatId;
    _chatStateManager.enterChatScreen(chatId);

    if (_joinedChatRooms.contains(chatId)) {
      _log('Already in chat room: $chatId, updating active viewing status');
      // Still emit to let server know we're actively viewing
      _socket!.emit('chat:set_active_viewing', {
        'chatId': chatId,
        'isActivelyViewing': true,
      });
      return;
    }

    _log('Joining chat room: $chatId (actively viewing)');
    _socket!.emit('chat:join', {
      'chatId': chatId,
      'isActivelyViewing': true,
    });
    _joinedChatRooms.add(chatId);
  }

  /// Leave a chat room AND stop actively viewing it
  void leaveChatRoom(String chatId) {
    if (_socket == null || !_isConnected) {
      _log('Cannot leave chat room - socket not connected');
      return;
    }

    // Clear active viewing state
    if (_activelyViewingChatId == chatId) {
      _activelyViewingChatId = null;
      _chatStateManager.leaveChatScreen();
    }

    _log('Leaving chat room: $chatId');
    _socket!.emit('chat:leave', {'chatId': chatId});
    _joinedChatRooms.remove(chatId);
  }

  /// Leave all chat rooms
  void leaveAllChatRooms() {
    for (final chatId in _joinedChatRooms.toList()) {
      leaveChatRoom(chatId);
    }
    _activelyViewingChatId = null;
    _chatStateManager.leaveChatScreen();
  }

  /// Set the actively viewing chat without joining/leaving room
  /// Useful when navigating to chat from notification
  void setActivelyViewingChat(String? chatId) {
    _activelyViewingChatId = chatId;
    if (chatId != null) {
      _chatStateManager.enterChatScreen(chatId);
      // Notify server
      if (_socket != null && _isConnected) {
        _socket!.emit('chat:set_active_viewing', {
          'chatId': chatId,
          'isActivelyViewing': true,
        });
      }
    } else {
      _chatStateManager.leaveChatScreen();
    }
  }

  /// Get the currently active chat ID
  String? get activelyViewingChatId => _activelyViewingChatId;

  /// Send a chat message
  void sendChatMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? mediaUrl,
  }) {
    if (_socket == null || !_isConnected) {
      _log('Cannot send message - socket not connected');
      _chatError.add({'error': 'Not connected to server'});
      return;
    }

    _log('Sending message to chat: $chatId');
    _socket!.emit('chat:send', {
      'chatId': chatId,
      'content': content,
      'messageType': messageType,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
    });
  }

  /// Send typing indicator
  void sendTypingIndicator({required String chatId, required bool isTyping}) {
    if (_socket == null || !_isConnected) return;

    _socket!.emit('chat:typing', {
      'chatId': chatId,
      'isTyping': isTyping,
    });
  }

  /// Mark chat messages as read
  void markChatAsRead(String chatId) {
    if (_socket == null || !_isConnected) return;

    _log('Marking chat as read: $chatId');
    _socket!.emit('chat:read', {'chatId': chatId});
  }

  /// Delete a message for everyone (WhatsApp-style)
  /// This permanently deletes from backend DB and broadcasts to both users
  void deleteMessageForEveryone({
    required String messageId,
    required String chatId,
    required String receiverId,
  }) {
    if (_socket == null || !_isConnected) {
      _log('Cannot delete message - socket not connected');
      _chatError.add({'error': 'Not connected to server'});
      return;
    }

    _log('Deleting message for everyone: $messageId');
    _socket!.emit('delete_message', {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': _currentUserId,
      'receiverId': receiverId,
    });
  }

  /// Check if connected to a specific chat room
  bool isInChatRoom(String chatId) => _joinedChatRooms.contains(chatId);

  /// Get list of joined chat rooms
  Set<String> get joinedChatRooms => Set.unmodifiable(_joinedChatRooms);

  /// Dispose all resources - Note: For singleton, we just disconnect, don't close controllers
  /// since they may be reused. Controllers are recreated lazily if needed.
  void dispose() {
    disconnect();
    _joinedChatRooms.clear();
    // Close and null out controllers so they can be recreated
    _incomingCallController?.close();
    _incomingCallController = null;
    _callAcceptedController?.close();
    _callAcceptedController = null;
    _callRejectedController?.close();
    _callRejectedController = null;
    _callEndedController?.close();
    _callEndedController = null;
    _callConnectedController?.close();
    _callConnectedController = null;
    _connectionStateController?.close();
    _connectionStateController = null;
    _userOnlineController?.close();
    _userOnlineController = null;
    _userOfflineController?.close();
    _userOfflineController = null;
    // Chat controllers
    _chatMessageController?.close();
    _chatMessageController = null;
    _chatHistoryController?.close();
    _chatHistoryController = null;
    _chatTypingController?.close();
    _chatTypingController = null;
    _chatReadController?.close();
    _chatReadController = null;
    _chatErrorController?.close();
    _chatErrorController = null;
    _chatNotificationController?.close();
    _chatNotificationController = null;
    _messageDeletedController?.close();
    _messageDeletedController = null;
    _appNotificationController?.close();
    _appNotificationController = null;
  }
}
