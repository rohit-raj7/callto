# Mobile App Updates - Listener Verification System

## Overview
This document outlines the changes made to the Flutter mobile app to support the listener verification system and ensure only approved listeners can receive calls and messages.

## Date
February 7, 2026

## Summary

**✅ GOOD NEWS**: The mobile app requires **MINIMAL CHANGES** because it already uses backend APIs that have been protected with verification checks.

### How Protection Works

1. **Backend Filtering** (Primary Protection)
   - All listener list APIs now filter by `verificationStatus = 'approved'`
   - Non-approved listeners never reach the mobile app
   - Users cannot see, call, or chat with unapproved listeners

2. **Mobile App Integration**
   - App uses `ListenerService` to fetch listeners via `/api/listeners`
   - App uses `CallService` to initiate calls via `/api/calls`
   - App uses `ChatService` to create chats via `/api/chats`
   - All protected by backend verification checks

3. **Error Handling**
   - Call errors shown via Socket.io `call:failed` events
   - Chat errors shown via API error responses
   - User-friendly messages replace technical backend errors

## Files Modified

### 1. Socket Service Error Handling

**File**: `mobile/lib/services/socket_service.dart`

**Changes**:
- Added `_callFailedController` stream controller
- Added public `onCallFailed` stream
- Enhanced `call:failed` event handler to broadcast failures
- Supports new `listener_not_approved` failure reason

**Code Added**:
```dart
// Controller field
StreamController<Map<String, dynamic>>? _callFailedController;

// Getter
StreamController<Map<String, dynamic>> get _callFailed {
  _callFailedController ??= StreamController<Map<String, dynamic>>.broadcast();
  return _callFailedController!;
}

// Public stream
Stream<Map<String, dynamic>> get onCallFailed => _callFailed.stream;

// Event handler
_socket!.on('call:failed', (data) {
  _log('Call failed: $data');
  // VERIFICATION: Handle call failures including listener_not_approved
  final failureData = data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data);
  _callFailed.add(failureData);
});
```

### 2. Call Controller Error Handling

**File**: `mobile/lib/user/actions/call_controller.dart`

**Changes**:
- Added listener for `onCallFailed` stream
- Handles `listener_not_approved` reason
- Displays user-friendly error messages
- Auto-closes call after showing error

**Code Added**:
```dart
// VERIFICATION: Handle call:failed events for verification failures
_socketService.onCallFailed.listen((data) {
  debugPrint('UserCallController: call failed – ${data['reason'] ?? 'unknown'}');
  final reason = data['reason']?.toString() ?? '';
  final message = data['message']?.toString();
  
  // Handle listener verification failure
  if (reason == 'listener_not_approved') {
    _setError(message ?? 'This listener is not available for calls at the moment');
  } else if (reason == 'listener_offline') {
    _setError('Listener is currently offline');
  } else if (reason == 'verification_check_failed') {
    _setError('Unable to verify listener status. Please try again');
  } else {
    _setError(message ?? 'Call failed. Please try again');
  }
  
  _stopRingtone();
  Future.delayed(const Duration(seconds: 3), () {
    if (!_disposed) endCall();
  });
});
```

### 3. Chat Page Error Handling

**Files**: 
- `mobile/lib/user/actions/charting.dart`
- `mobile/lib/listener/actions/charting.dart`

**Changes**:
- Enhanced error handling for chat creation failures
- Enhanced error messages for message sending failures
- Converts backend "not approved" errors to user-friendly messages
- Displays errors with increased duration for better visibility

**Code Added (Chat Creation)**:
```dart
final result = await _chatService.createOrGetChat(widget.otherUserId!);
if (result.success && result.chat != null) {
  _chatId = result.chat!.chatId;
} else {
  // VERIFICATION: Handle listener verification failures
  final error = result.error ?? 'Failed to create chat';
  final userFriendlyError = error.toLowerCase().contains('not approved') 
      ? 'This listener is not available for chat at the moment'
      : error;
  
  setState(() {
    _errorMessage = userFriendlyError;
    _isLoading = false;
  });
  return;
}
```

**Code Added (Message Sending)**:
```dart
} else {
  // Show error and remove optimistic message
  setState(() {
    _messages.removeWhere((m) => m.messageId == tempId);
  });
  if (mounted) {
    // VERIFICATION: Show user-friendly error for verification failures
    final error = result.error ?? 'Failed to send message';
    final userFriendlyError = error.toLowerCase().contains('not approved') 
        ? 'This listener is not available for chat at the moment'
        : error;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(userFriendlyError),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
```

## Existing Protection (No Changes Needed)

### 1. Listener Service
**File**: `mobile/lib/services/listener_service.dart`

**Already Protected**:
- `getListeners()` → Calls `/api/listeners` → Backend filters approved only
- `searchListeners()` → Calls `/api/listeners/search` → Backend filters approved only
- `getListenerById()` → Shows individual listener → Backend validates

**How It Works**:
```dart
Future<ListenerResult> getListeners({...}) async {
  // Calls backend API which now includes verification filter
  final response = await _api.get(ApiConfig.listeners, queryParams: queryParams);
  // Only approved listeners are returned
  return ListenerResult(success: true, listeners: listeners);
}
```

### 2. Call Service
**File**: `mobile/lib/services/call_service.dart`

**Already Protected**:
- `initiateCall()` → Calls `/api/calls` → Backend checks verification before creating call

**How It Works**:
```dart
Future<CallResult> initiateCall({required String listenerId, ...}) async {
  final response = await _api.post(ApiConfig.calls, body: {...});
  // Backend returns 403 error if listener not approved
  if (response.isSuccess) {
    return CallResult(success: true, call: call);
  } else {
    return CallResult(success: false, error: response.error); // "Listener not approved yet"
  }
}
```

### 3. Chat Service
**File**: `mobile/lib/services/chat_service.dart`

**Already Protected**:
- `createOrGetChat()` → Calls `/api/chats` → Backend checks verification before creating chat
- `sendMessage()` → Calls `/api/chats/:id/messages` → Backend validates on each message

**How It Works**:
```dart
Future<ChatResult> createOrGetChat(String otherUserId) async {
  final response = await _api.post(ApiConfig.chats, body: {'other_user_id': otherUserId});
  // Backend returns 403 error if listener not approved
  if (response.isSuccess) {
    return ChatResult(success: true, chat: chat);
  } else {
    return ChatResult(success: false, error: response.error); // "Listener not approved yet"
  }
}
```

## Error Messages Shown to Users

### Call Failures
| Scenario | Error Message Displayed |
|----------|------------------------|
| Listener not approved | "This listener is not available for calls at the moment" |
| Listener offline | "Listener is currently offline" |
| Verification check failed | "Unable to verify listener status. Please try again" |
| Other failures | "Call failed. Please try again" |

### Chat Failures
| Scenario | Error Message Displayed |
|----------|------------------------|
| Listener not approved (chat creation) | "This listener is not available for chat at the moment" |
| Listener not approved (message send) | "This listener is not available for chat at the moment" |
| Failed to create chat | "Failed to create chat" |
| Failed to send message | "Failed to send message" |

## Testing Checklist

### Listener Visibility Tests
- [ ] Login as user
- [ ] Open listener list screen
- [ ] Verify only approved listeners are shown
- [ ] Search for listeners - only approved shown
- [ ] Unapproved listeners do not appear anywhere

### Call Protection Tests
- [ ] Attempt to call approved listener → Works normally
- [ ] Try to call unapproved listener (via direct link/ID) → Shows error
- [ ] Error message: "This listener is not available for calls at the moment"
- [ ] Call screen closes after 3 seconds
- [ ] No call session is created

### Chat Protection Tests
- [ ] Start chat with approved listener → Works normally
- [ ] Try to chat with unapproved listener → Shows error
- [ ] Error message (chat creation): "This listener is not available for chat at the moment"
- [ ] Chat screen shows error, no messages can be sent
- [ ] Try sending message to unapproved listener → Shows error
- [ ] Error message (send): "This listener is not available for chat at the moment"
- [ ] Error shown in red SnackBar for 4 seconds
- [ ] Message not sent, removed from chat UI

### Socket.io Tests
- [ ] Call initiation blocked at socket level for unapproved listeners
- [ ] `call:failed` event received with `listener_not_approved` reason
- [ ] User sees error message immediately
- [ ] No ring tone plays for failed calls

## Backend API Protection Summary

All mobile API calls are protected:

| API Endpoint | Protection | Mobile Service |
|--------------|------------|----------------|
| `GET /api/listeners` | Filters approved only | ListenerService.getListeners() |
| `GET /api/listeners/search` | Filters approved only | ListenerService.searchListeners() |
| `POST /api/calls` | Blocks if not approved | CallService.initiateCall() |
| `POST /api/chats` | Blocks if not approved | ChatService.createOrGetChat() |
| `POST /api/chats/:id/messages` | Blocks if not approved | ChatService.sendMessage() |
| Socket: `call:initiate` | Checks verification | SocketService.initiateCall() |

## Flow Diagrams

### Call Flow with Verification

```
User opens app
    ↓
Fetch listeners (ListenerService.getListeners())
    ↓
Backend filters: only approved listeners returned
    ↓
User sees approved listeners only
    ↓
User taps to call a listener
    ↓
CallService.initiateCall() → POST /api/calls
    ↓
Backend checks: verificationStatus = 'approved'?
    ├─ YES → Call created, socket forwarded
    └─ NO → 403 error returned
            ↓
            CallResult(success: false, error: "Listener not approved yet")
            ↓
            Error displayed to user
            ↓
            Call screen closes
```

### Chat Flow with Verification

```
User opens app
    ↓
Sees only approved listeners in list
    ↓
User taps to chat with listener
    ↓
ChatService.createOrGetChat() → POST /api/chats
    ↓
Backend checks: verificationStatus = 'approved'?
    ├─ YES → Chat created
    └─ NO → 403 error returned
            ↓
            ChatResult(success: false, error: "Listener not approved yet")
            ↓
            Error message shown in chat screen
            ↓
            Cannot send messages
```

## Security Benefits

1. **Multi-Layer Protection**
   - Backend filters at query level (primary)
   - Backend validates at API level (secondary)
   - Socket layer validates at connection level (tertiary)

2. **No Client-Side Bypass**
   - All filtering done server-side
   - Mobile app cannot bypass checks
   - Even if user has direct listener ID, backend blocks

3. **Real-time Protection**
   - Socket.io validates before forwarding calls
   - Prevents unapproved listeners from receiving notifications
   - Immediate failure feedback to users

## Deployment Steps

### 1. Backend Deployment (Do First)
```bash
cd backend
git pull
node scripts/addVerificationStatus.js  # Run migration
npm restart
```

### 2. Mobile App Deployment
```bash
cd mobile
git pull
flutter pub get
flutter build apk --release  # For Android
# or
flutter build ios --release  # For iOS
```

### 3. Verification
- Test listener lists show only approved
- Test call attempts to unapproved listeners fail gracefully
- Test chat creation fails for unapproved listeners
- Verify error messages are user-friendly

## Backward Compatibility

✅ **Fully Compatible**:
- Existing listeners auto-approved by migration
- No breaking changes to API contracts
- Error responses clearly indicate reason
- Mobile app gracefully handles new error messages

## No Additional Mobile Changes Needed

The following do **NOT** need updates:
- ❌ Listener list screens - backend filters
- ❌ Search screens - backend filters
- ❌ Listener profile screen - backend validates
- ❌ Random call screen - backend filters
- ❌ Call history - already shows only past calls
- ❌ Chat list - already shows only existing chats

## Summary

**Total Files Modified**: 4
1. `mobile/lib/services/socket_service.dart` - Added call:failed stream
2. `mobile/lib/user/actions/call_controller.dart` - Enhanced call error handling
3. `mobile/lib/user/actions/charting.dart` - Enhanced chat error handling
4. `mobile/lib/listener/actions/charting.dart` - Enhanced chat error handling

**Lines of Code Added**: ~100 lines

**Key Achievement**: Full verification protection with minimal mobile app changes, thanks to proper architecture and backend-first security. Both calls and chats now show user-friendly error messages when attempting to contact unapproved listeners.

---

**Implementation Status**: ✅ COMPLETE

All verification checks are in place. The mobile app is fully protected and only shows/allows interaction with approved listeners.
