# Mobile App API Integration

This document describes the API integration between the Flutter mobile app and the backend API at `https://call-to2.vercel.app/`.

## API Base URL

```
https://call-to2.vercel.app/api
```

## Services

The following services are available in `lib/services/`:

### 1. AuthService (`auth_service.dart`)
- `socialLogin(provider, token)` - Login with Google/Facebook
- `completeRegistration(...)` - Complete user profile after social login
- `logout()` - Log out user
- `checkLoginStatus()` - Check if user is logged in

### 2. UserService (`user_service.dart`)
- `getProfile()` - Get current user profile
- `updateProfile(...)` - Update user profile
- `getUserById(userId)` - Get user by ID
- `addLanguage(...)` - Add language preference
- `getLanguages()` - Get user languages
- `getWallet()` - Get wallet balance

### 3. ListenerService (`listener_service.dart`)
- `getListeners(...)` - Get all listeners with filters
- `searchListeners(query)` - Search listeners
- `getListenerById(listenerId)` - Get listener details
- `becomeListener(...)` - Create listener profile
- `updateListener(...)` - Update listener profile
- `updateOnlineStatus(...)` - Update online status

### 4. CallService (`call_service.dart`)
- `initiateCall(listenerId, callType)` - Start a call
- `getCallById(callId)` - Get call details
- `updateCallStatus(...)` - Update call status
- `getCallHistory(...)` - Get call history
- `getActiveCalls()` - Get active calls
- `rateCall(...)` - Rate a completed call

### 5. ChatService (`chat_service.dart`)
- `getChats()` - Get all chats
- `createOrGetChat(otherUserId)` - Create/get chat
- `getChatById(chatId)` - Get chat details
- `getChatMessages(...)` - Get messages
- `sendMessage(...)` - Send a message
- `markAsRead(chatId)` - Mark messages as read

## Models

Data models are in `lib/models/`:
- `User` - User data
- `Listener` - Listener profile data
- `Call` - Call data
- `Chat` / `Message` - Chat and message data

## Authentication

The app uses JWT tokens for authentication:
1. User logs in via Google/Facebook
2. Backend returns JWT token
3. Token is stored locally using `SharedPreferences`
4. Token is sent with every API request in `Authorization` header

## Dependencies Added

```yaml
dependencies:
  http: ^1.2.0                    # HTTP client
  shared_preferences: ^2.2.2      # Local storage
  google_sign_in: ^6.2.1          # Google authentication
  flutter_facebook_auth: ^7.0.1   # Facebook authentication
```

## Setup

1. Run `flutter pub get` to install dependencies
2. Configure Google Sign-In in Firebase Console
3. Configure Facebook App in Facebook Developer Console
4. Update Android/iOS native configurations

## Google Sign-In Setup (Android)

1. Add `google-services.json` to `android/app/`
2. Configure SHA-1 fingerprint in Firebase Console

## Facebook Login Setup (Android)

1. Add to `android/app/src/main/res/values/strings.xml`:
```xml
<string name="facebook_app_id">YOUR_APP_ID</string>
<string name="fb_login_protocol_scheme">fbYOUR_APP_ID</string>
<string name="facebook_client_token">YOUR_CLIENT_TOKEN</string>
```

2. Update `AndroidManifest.xml` with Facebook meta-data

## Usage Example

```dart
import 'package:call_u/services/services.dart';
import 'package:call_u/models/models.dart';

// Login
final authResult = await AuthService().socialLogin(
  provider: 'google',
  token: googleIdToken,
);

if (authResult.success) {
  // User is logged in
  final user = authResult.user;
}

// Get listeners
final result = await ListenerService().getListeners(
  isOnline: true,
  limit: 20,
);

if (result.success) {
  final listeners = result.listeners;
}
```
