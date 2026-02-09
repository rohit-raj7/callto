import 'package:flutter/material.dart';
import '../screens/home_screen.dart'; 
import '../screens/chat_screen.dart';
import '../screens/recents_screen.dart';
import '../../services/incoming_call_overlay_service.dart';
import '../../services/socket_service.dart';
import '../../main.dart' show ensureGlobalCallHandler;

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0;
  final IncomingCallOverlayService _overlayService = IncomingCallOverlayService();
  final SocketService _socketService = SocketService();

  final List<Widget> _screens = const [
    HomeScreen(), 
    ChatScreen(),
    RecentsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize overlay service and ensure listener is marked online
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeListenerServices();
    });
  }
  
  /// Initialize listener services for incoming calls
  /// CRITICAL: This ensures listener stays online while navigating between pages
  Future<void> _initializeListenerServices() async {
    // Initialize overlay service with current context
    await _overlayService.initialize(context);
    
    // CRITICAL: Ensure listener is marked online when using the app
    // This call emits listener:join to backend, marking listener as available for calls
    await _socketService.setListenerOnline(true);
    
    // Ensure the global incoming call subscription in main.dart is active.
    // At app startup _initializeGlobalCallHandler may have skipped because
    // isListener was false (first login). This re-triggers it.
    ensureGlobalCallHandler();
    
    print('[LISTENER NAV] Listener services initialized, marked as online');
  }

  @override
  void dispose() {
    // Don't full dispose - just clear context
    _overlayService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Call',
          ),
          
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Recents',
          ),
        ],
      ),
    );
  }
}
