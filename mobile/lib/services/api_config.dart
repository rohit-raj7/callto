
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
//   static final String baseUrl = kDebugMode
//       ? (kIsWeb 
//           ? 'http://localhost:3002' 
//           : (defaultTargetPlatform == TargetPlatform.android 
//               ? 'http://10.0.2.2:3002' 
//               : 'http://localhost:3002')t)
//       : 'https://callto-4.onrender.com';
// 
  static final String baseUrl =
      dotenv.env['API_BASE_URL']?.trim().isNotEmpty == true
          ? dotenv.env['API_BASE_URL']!.trim()
          : 'https://call1.onrender.com';

  // static final String baseUrl ='http://localhost:3002';
      

  static final String socketUrl = baseUrl;

  static final String apiBase = '$baseUrl/api';

  static final String socialLogin = '$apiBase/auth/social-login';
  static final String register = '$apiBase/auth/register';
  static final String logout = '$apiBase/auth/logout';
  static final String deleteAccountRequest = '$apiBase/account/delete-request';

  static final String userProfile = '$apiBase/users/profile';
  static final String userLanguages = '$apiBase/users/languages';
  static final String userWallet = '$apiBase/users/wallet';

  static final String listeners = '$apiBase/listeners';
  static final String listenerSearch = '$apiBase/listeners/search';

  static final String calls = '$apiBase/calls';
  static final String callEnd = '$apiBase/calls/end';
  static final String callHistory = '$apiBase/calls/history/me';
  static final String listenerCallHistory = '$apiBase/calls/history/listener';
  static final String activeCalls = '$apiBase/calls/active/me';
  static final String agoraToken = '$apiBase/calls/agora/token';
  static final String callRates = '$apiBase/config/call-rates';
  static final String submitRating = '$apiBase/ratings/submit';

  static final String chats = '$apiBase/chats';
  static final String contactMessages = '$apiBase/contacts';
  static final String notificationsMy = '$apiBase/notifications/my';
  static final String notificationsMarkRead = '$apiBase/notifications/mark-read';
  static final String notificationsUnreadCount = '$apiBase/notifications/unread-count';

  static final String health = '$apiBase/health';

  // Voice upload
  static final String uploadVoice = '$apiBase/listeners/upload-voice';

  static final Duration timeout = const Duration(seconds: 60);
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}
