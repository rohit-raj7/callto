import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../screens/random_call_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/recents_screen.dart';
import '../../services/offer_banner_controller.dart';

class BottomNavBar extends StatefulWidget {
  const BottomNavBar({super.key});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  int _currentIndex = 0;
  final OfferBannerController _offerCtrl = OfferBannerController();

  late final List<Widget> _screens;

  void _goHome() {
    if (!mounted) return;
    setState(() {
      _currentIndex = 0;
    });
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      const HomeScreen(),
      RandomCallScreen(onBackToHome: _goHome),
      const ChatScreen(),
      const RecentsScreen(),
    ];
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
          // Banner reappears every time the user switches to Call tab
          if (index == 0) {
            _offerCtrl.resetDismiss();
            _offerCtrl.refresh();
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.call),
            label: 'Call',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shuffle),
            label: 'Random Call',
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
