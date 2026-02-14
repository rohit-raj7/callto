import 'package:flutter/material.dart';
import '../nav/profile.dart';
import '../nav/profile/wallet.dart';
import '../../services/storage_service.dart';
import '../../services/user_service.dart';

class TopBar extends StatefulWidget {
  const TopBar({super.key});

  @override
  State<TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<TopBar> {
  late Future<String?> _avatarFuture;
  final UserService _userService = UserService();
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _avatarFuture = StorageService().getAvatarUrl();
    _loadWalletBalance();
  }

  Future<void> _loadWalletBalance() async {
    final result = await _userService.getWallet();
    if (mounted && result.success) {
      setState(() {
        _walletBalance = result.balance;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: BottomCurveClipper(),
      child: Container(
        width: double.infinity,
        // color: Colors.pinkAccent, 
        color: const Color.fromARGB(255, 235, 155, 238),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 25),
        child: Column(
          children: [
            // 🔝 Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 👈 LEFT SIDE (Profile + Wallet)
                Row(
                  children: [
                    // 👤 Profile Icon
                    GestureDetector(
                      onTap: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                        );
                        if (result != null) {
                          setState(() {
                            _avatarFuture = StorageService().getAvatarUrl();
                          });
                        }
                        // Reload wallet balance when returning from profile
                        _loadWalletBalance();
                      },
                      child: FutureBuilder<String?>(
                        future: _avatarFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            final imageUrl = snapshot.data!;
                            return CircleAvatar(
                              radius: 20,
                              backgroundImage: imageUrl.startsWith('http')
                                  ? NetworkImage(imageUrl)
                                  : AssetImage(imageUrl),
                            );
                          }
                          return const CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                AssetImage('assets/images/male_profile/avatar2.jpg'),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    // 💰 Wallet Balance (RIGHT of Profile)
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WalletScreen(),
                          ),
                        );
                        // Reload wallet balance when returning
                        _loadWalletBalance();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEB5B98), Color(0xFFFF8BA7)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEB5B98).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "₹${_walletBalance.toStringAsFixed(2)}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 👉 RIGHT SIDE (Logo)
                Image.asset(
                  'assets/login/logo.png',
                  height: 36,
                  fit: BoxFit.contain,
                ),
              ],
            ),

            const SizedBox(height: 12),
 
          // 🔔 Promotion Banner
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF6B46C1), // Deep Purple
                    Color(0xFF9333EA), // Purple
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              child: Row(
                children: const [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "Now text your ",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                          TextSpan(
                            text: "Favourite Experts ",
                            style: TextStyle(
                              color: Color(0xFFFBBF24), // Amber
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                          TextSpan(
                            text: "@ ₹4/min only!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.shuffle, color: Colors.white70, size: 20),
                ],
              ),
            ),

           
// ----------------------------
          ],
        ),
      ),
    );
  }
}

class BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 30,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
