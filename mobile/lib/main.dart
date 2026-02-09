import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'login/login.dart';
import 'gender/gender_selection.dart';
import 'user/widgets/bottom_nav_bar.dart' as user_bottom_nav_bar;
import 'listener/widgets/bottom_nav_bar.dart' as listener_bottom_nav_bar;
import 'user/user_form/intro_screen.dart';
import 'listener/listener_form/intro_screen.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/listener_service.dart';
import 'services/socket_service.dart';
import 'services/chat_state_manager.dart';
import 'services/incoming_call_overlay_service.dart';
import 'services/call_service.dart';
import 'services/in_app_chat_notification_service.dart';
import 'listener/actions/calling.dart';
import 'models/user_model.dart';

/// Global navigator key for showing incoming call overlay anywhere in the app
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Call from listener BottomNavBar (or anywhere) to ensure the global
/// incoming-call subscription is active. Needed because at app startup
/// the user might not have been identified as a listener yet.
void ensureGlobalCallHandler() {
  _ConnectoAppState._instance?._initializeGlobalCallHandler();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ConnectoApp());
}

class ConnectoApp extends StatefulWidget {
  const ConnectoApp({super.key});

  @override
  State<ConnectoApp> createState() => _ConnectoAppState();
}

class _ConnectoAppState extends State<ConnectoApp> with WidgetsBindingObserver {
  final SocketService _socketService = SocketService();
  final ChatStateManager _chatStateManager = ChatStateManager();
  final StorageService _storageService = StorageService();
  final IncomingCallOverlayService _overlayService = IncomingCallOverlayService();
  final InAppChatNotificationService _chatNotificationService =
      InAppChatNotificationService();
  
  // Global incoming call handling for listeners
  StreamSubscription<IncomingCall>? _incomingCallSubscription;
  StreamSubscription<String>? _callHandledSubscription;
  bool _isShowingIncomingCall = false;
  String? _currentlyShowingCallId; // Track which call dialog is showing

  /// Singleton reference so ensureGlobalCallHandler() can reach this state.
  static _ConnectoAppState? _instance;

  @override
  void initState() {
    super.initState();
    _instance = this;
    WidgetsBinding.instance.addObserver(this);
    // Initialize global incoming call listener after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGlobalCallHandler();
      _chatNotificationService.initialize(navigatorKey);
    });
  }

  /// Initialize global incoming call handler for listeners.
  /// Safe to call multiple times — cancels previous subscription first.
  /// Called from initState AND from BottomNavBar when entering listener mode,
  /// to ensure the subscription exists even if isListener was false at startup.
  Future<void> _initializeGlobalCallHandler() async {
    final isListener = await _storageService.getIsListener();
    if (!isListener) return;
    
    // Avoid duplicate subscription
    if (_incomingCallSubscription != null) {
      print('[MAIN] Global incoming call handler already active');
      return;
    }
    
    print('[MAIN] Setting up global incoming call handler for listener');
    
    // Subscribe to incoming calls at app-level
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = _socketService.onIncomingCall.listen((call) {
      print('[MAIN] Global handler received incoming call from ${call.callerName}');
      _showIncomingCallDialog(call);
    });
    
    // Subscribe to call handled events from home screen
    // This allows us to close the dialog when call is handled from home screen list
    _callHandledSubscription?.cancel();
    _callHandledSubscription = _overlayService.onCallHandled.listen((callId) {
      print('[MAIN] Call $callId was handled from home screen');
      if (_isShowingIncomingCall && _currentlyShowingCallId == callId) {
        // Close the dialog - call was handled from home screen
        _dismissIncomingCallDialog();
      }
    });
  }
  
  /// Dismiss the currently showing incoming call dialog
  void _dismissIncomingCallDialog() {
    if (_isShowingIncomingCall && navigatorKey.currentContext != null) {
      try {
        Navigator.of(navigatorKey.currentContext!).pop();
      } catch (e) {
        print('[MAIN] Error dismissing dialog: $e');
      }
    }
    _isShowingIncomingCall = false;
    _currentlyShowingCallId = null;
  }

  /// Show incoming call as a full-screen dialog that works on any page
  void _showIncomingCallDialog(IncomingCall call) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('[MAIN] No navigator context available');
      return;
    }
    
    // Prevent showing multiple incoming call dialogs
    if (_isShowingIncomingCall) {
      print('[MAIN] Already showing incoming call dialog');
      return;
    }
    
    // NOTE: We no longer gate on _socketService.listenerOnline here.
    // If the backend sent us an incoming-call socket event, the backend
    // already verified the listener is online (in listenerSockets map).
    // The old client-side check caused false negatives on Android where
    // listenerOnline was still false due to connect() timing issues.
    
    _isShowingIncomingCall = true;
    _currentlyShowingCallId = call.callId;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _IncomingCallDialog(
        call: call,
        onAccept: () async {
          Navigator.of(dialogContext).pop();
          _isShowingIncomingCall = false;
          _currentlyShowingCallId = null;
          await _acceptCall(call, context);
        },
        onReject: () async {
          Navigator.of(dialogContext).pop();
          _isShowingIncomingCall = false;
          _currentlyShowingCallId = null;
          await _rejectCall(call);
        },
      ),
    ).then((_) {
      _isShowingIncomingCall = false;
      _currentlyShowingCallId = null;
    });
  }

  Future<void> _acceptCall(IncomingCall call, BuildContext context) async {
    try {
      // Remove from overlay service list (in case it's also shown there)
      _overlayService.removeCallFromList(call.callId);

      // ── FIX: Navigate IMMEDIATELY to prevent the 1-second flicker ──
      // Previously, `await callService.updateCallStatus(...)` ran BEFORE
      // navigation, so the home screen was visible for ~1 s between
      // dialog dismiss and Calling screen push. Now we navigate first
      // and fire the API call + socket emit in the background.
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => Calling(
            callerName: call.callerName,
            callerAvatar: call.callerAvatar,
            channelName: call.callId,
            callId: call.callId,
            callerId: call.callerId,
          ),
        ),
      );

      // Fire-and-forget: update backend status + notify peer
      _socketService.acceptCall(callId: call.callId, callerId: call.callerId);
      CallService().updateCallStatus(callId: call.callId, status: 'ongoing');
    } catch (e) {
      print('[MAIN] Error accepting call: $e');
    }
  }

  Future<void> _rejectCall(IncomingCall call) async {
    try {
      // Remove from overlay service list (in case it's also shown there)
      _overlayService.removeCallFromList(call.callId);
      
      final callService = CallService();
      await callService.updateCallStatus(callId: call.callId, status: 'rejected');
      _socketService.rejectCall(callId: call.callId, callerId: call.callerId);
    } catch (e) {
      print('[MAIN] Error rejecting call: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingCallSubscription?.cancel();
    _callHandledSubscription?.cancel();
    _chatNotificationService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[LIFECYCLE] AppLifecycleState: $state');
    switch (state) {
      case AppLifecycleState.resumed:
        // WhatsApp-style: App came to foreground
        // Update ChatStateManager first (immediate state update)
        _chatStateManager.appResumed();
        // Then handle socket connection and server notification
        _socketService.onAppForeground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // WhatsApp-style: App went to background or was killed
        // Update ChatStateManager first
        _chatStateManager.appPaused();
        // Then handle socket and server notification
        _socketService.onAppBackground();
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Use global navigator key
      debugShowCheckedModeBanner: false,
      title: 'Callto',
      theme: ThemeData(
        primarySwatch: Colors.pink,
        scaffoldBackgroundColor: const Color(0xFFFCE4EC),
      ),
      home: const SplashScreen(),
    );
  }
}

/// Incoming call dialog widget - shown globally on any page
class _IncomingCallDialog extends StatefulWidget {
  final IncomingCall call;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _IncomingCallDialog({
    required this.call,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<_IncomingCallDialog> {
  Timer? _autoDeclineTimer;

  @override
  void initState() {
    super.initState();
    // Auto-decline after 30 seconds
    _autoDeclineTimer = Timer(const Duration(seconds: 30), () {
      widget.onReject();
    });
  }

  @override
  void dispose() {
    _autoDeclineTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Incoming Call',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 60,
                backgroundColor: const Color(0xFFFF4081).withOpacity(0.2),
                backgroundImage: widget.call.callerAvatar != null &&
                        widget.call.callerAvatar!.startsWith('http')
                    ? NetworkImage(widget.call.callerAvatar!)
                    : null,
                child: widget.call.callerAvatar == null ||
                        !widget.call.callerAvatar!.startsWith('http')
                    ? const Icon(Icons.person, size: 60, color: Color(0xFFFF4081))
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                widget.call.callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.call.topic ?? 'General',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 80),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  Column(
                    children: [
                      GestureDetector(
                        onTap: widget.onReject,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Decline',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  // Accept button
                  Column(
                    children: [
                      GestureDetector(
                        onTap: widget.onAccept,
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accept',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Splash screen to check login status
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  final StorageService _storageService = StorageService();
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(milliseconds: 500));

    final isLoggedIn = await _authService.checkLoginStatus();

    if (!mounted) return;

    if (isLoggedIn) {
      // Connect socket for all logged-in users (WhatsApp-style: always connected)
      // This enables real-time chat functionality for both users and listeners
      await _socketService.connect();
      
      // Refresh user data from backend to ensure we know if the user is a listener
      try {
        final user = await _authService.refreshUserData();

        if (user != null) {
          // Set user info for socket (used in chat messages)
          _socketService.setUserInfo(
            userName: user.displayName,
            userAvatar: user.avatarUrl,
          );
        }

        await _routeByProfileState(user);
      } catch (e) {
        // If refresh fails, fall back to local storage checks
        print('Failed to refresh user data: $e');
        await _routeByProfileState(null);
      }
    } else {
      // User is not logged in
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _routeByProfileState(User? user) async {
    final gender = await _storageService.getGender();
    final listenerComplete = await _storageService.getListenerProfileComplete();
    final userComplete = await _storageService.getUserProfileComplete();

    if (listenerComplete || user?.accountType == 'listener') {
      await _storageService.saveIsListener(true);
      await _maybeRefreshListenerProfile(user);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const listener_bottom_nav_bar.BottomNavBar()),
      );
      return;
    }

    if (userComplete) {
      await _storageService.saveIsListener(false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const user_bottom_nav_bar.BottomNavBar()),
      );
      return;
    }

    if (gender == 'Female') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BecomeHostOnboarding()),
      );
      return;
    }

    if (gender == 'Male') {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const GenderSelectionPage()),
    );
  }

  Future<void> _maybeRefreshListenerProfile(User? user) async {
    // Socket will be connected by IncomingCallOverlayService in BottomNavBar
    try {
      final listenerService = ListenerService();
      final profileResult = await listenerService.getMyProfile();
      if (profileResult.success && profileResult.listener != null) {
        if (profileResult.listener!.avatarUrl != null) {
          await _storageService.saveListenerAvatarUrl(profileResult.listener!.avatarUrl!);
        }
        _socketService.setUserInfo(
          userName: profileResult.listener!.professionalName ?? user?.displayName,
          userAvatar: profileResult.listener!.avatarUrl ?? user?.avatarUrl,
        );
      }
    } catch (e) {
      print('Failed to fetch listener profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCE4EC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/login/homelogo.png',
              height: 100,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.phone_in_talk,
                  size: 80,
                  color: Colors.pinkAccent,
                );
              },
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              color: Colors.pinkAccent,
            ),
          ],
        ),
      ),
    );
  }
}
