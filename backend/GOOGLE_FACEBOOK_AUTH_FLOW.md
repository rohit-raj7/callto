# Authentication Flow - Google & Facebook Only

## ✅ Complete Authentication Endpoints

### 1. LOGIN & INITIAL REGISTRATION (Combined)
**POST** `/api/auth/social-login`

This endpoint handles both login and registration with Google/Facebook.

**Request:**
```json
{
  "provider": "google",              // or "facebook"
  "token": "eyJhbGciOiJSUzI1NiIsImtpZCI6...",  // Google ID token or Facebook access token
  "fcm_token": "firebase_messaging_token"      // Optional
}
```

**Response (New User):**
```json
{
  "message": "Login successful",
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "full_name": "John Doe",
    "display_name": "John",
    "avatar_url": "https://lh3.googleusercontent.com/...",
    "gender": null,
    "city": null,
    "account_type": "user",
    "is_verified": true,
    "auth_provider": "google",
    "created_at": "2026-01-19T10:00:00Z"
  },
  "isNewUser": true
}
```

**What happens:**
- ✅ Checks if user exists with this provider_user_id
- ✅ If not found but email exists, links provider to existing user
- ✅ If completely new, creates new user
- ✅ Marks user as verified
- ✅ Returns JWT token (valid 30 days)
- ✅ Returns `isNewUser: true/false` to know if onboarding needed

---

### 2. COMPLETE PROFILE & SETUP ACCOUNT TYPE
**POST** `/api/auth/register`

This endpoint completes the user profile and determines if they're a regular user or listener.

**Required:** JWT Token from `/social-login` endpoint

**Request Header:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

**Request Body:**
```json
{
  "full_name": "John Doe",
  "display_name": "John",
  "gender": "Male",                    // ← IMPORTANT: Determines account type
  "date_of_birth": "1995-05-20",
  "city": "Delhi",
  "country": "India",
  "avatar_url": "https://...",
  "bio": "I love listening and helping others",
  "email": "user@example.com",
  "fcm_token": "firebase_token",

  // FOR FEMALE USERS (Listeners) - REQUIRED:
  "original_name": "Real Name (Private)",
  "rate_per_minute": 5.00,
  "languages": ["Hindi", "English"]
}
```

**Response (Male User):**
```json
{
  "message": "Profile updated successfully",
  "user": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "full_name": "John Doe",
    "display_name": "John",
    "gender": "Male",
    "city": "Delhi",
    "account_type": "user",
    "avatar_url": "https://...",
    "is_verified": true
  },
  "accountType": "user"
}
```

**Response (Female User - Listener):**
```json
{
  "message": "Listener profile created successfully",
  "user": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "full_name": "Jane Doe",
    "display_name": "Jane",
    "gender": "Female",
    "city": "Delhi",
    "account_type": "listener",
    "avatar_url": "https://..."
  },
  "listener": {
    "listener_id": "660e8400-e29b-41d4-a716-446655440000",
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "original_name": "Real Name",
    "professional_name": "Jane",
    "languages": ["Hindi", "English"],
    "rate_per_minute": 5.00,
    "experiences": [],
    "is_verified": false,
    "voice_verified": false
  },
  "accountType": "listener"
}
```

**What happens:**
- ✅ Requires valid JWT token from social login
- ✅ Checks gender
- ✅ If Male → Creates regular user account
- ✅ If Female → Creates listener profile + user account
- ✅ Updates all profile information
- ✅ Returns account type so frontend knows which dashboard to show

---

### 3. GET CURRENT USER INFO
**GET** `/api/auth/me`

Get information about the currently logged-in user.

**Required:** JWT Token

**Request Header:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
```

**Response:**
```json
{
  "user": {
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "full_name": "John Doe",
    "display_name": "John",
    "gender": "Male",
    "city": "Delhi",
    "account_type": "user",
    "avatar_url": "https://...",
    "is_verified": true,
    "auth_provider": "google",
    "created_at": "2026-01-19T10:00:00Z"
  }
}
```

---

## 📱 Complete Mobile App Flow

```
1. App Launches
   ↓
2. Show Login Screen (login.dart)
   ↓
3. User Taps "Login with Google" or "Login with Facebook"
   ↓
4. Provider opens OAuth consent screen
   ↓
5. User grants permission
   ↓
6. Receive: access_token/id_token from provider
   ↓
7. Call: POST /api/auth/social-login
   - Send provider data
   ↓
8. Backend Response:
   - JWT token ✅
   - User info ✅
   - isNewUser: true/false ✅
   ↓
9. Save JWT token locally (SecureStorage)
   ↓
10. IF isNewUser = true → Navigate to Gender Selection
    ELSE → Navigate to Dashboard
   ↓
11. User Selects Gender (Male/Female)
    ↓
12. Fill Profile Details:
    - Full Name
    - Display Name
    - City, Country
    - Bio
    - If Female: Original Name, Rate/min, Languages
    ↓
13. Call: POST /api/auth/register
    - Send Authorization: Bearer JWT_TOKEN
    - Send profile data with gender
    ↓
14. Backend Response:
    - Updated user profile ✅
    - accountType: "user" or "listener" ✅
    - If listener: listener profile ✅
    ↓
15. IF accountType = "user" → Show User Dashboard (HomeScreen for users)
    ELSE → Show Listener Dashboard (HomeScreen for listeners)
    ↓
16. User Can Now:
    - Browse & call listeners (if user)
    - Accept calls (if listener)
    - Update profile, payment, experiences, etc.
```

---

## 🔐 Security Features

✅ **JWT Authentication**
- Token expires in 30 days
- Required for all profile/sensitive operations

✅ **Provider Validation**
- Only Google and Facebook allowed
- Invalid providers rejected

✅ **Email Linking**
- If email already exists, links provider instead of creating duplicate

✅ **Account Type Routing**
- Gender automatically determines account type
- Prevents confusion about user role

✅ **Verified on Social Login**
- All social logins auto-verified (they pass OAuth)
- No need for additional verification

---

## 🚫 What's NOT in This Flow

❌ OTP/SMS verification - REMOVED
❌ Email/password login - REMOVED
❌ Manual email verification - NOT NEEDED (OAuth verified)
❌ Multiple auth methods confusion - SIMPLIFIED to Google & Facebook only

---

## ✅ Summary

| Feature | Status |
|---------|--------|
| Google Login | ✅ Supported |
| Facebook Login | ✅ Supported |
| Email/Password | ❌ Removed |
| OTP | ❌ Removed |
| Account Type Routing | ✅ Automatic (by gender) |
| Listener Profile Creation | ✅ Auto-created for females |
| JWT Authentication | ✅ Secure 30-day tokens |
| Social Linking | ✅ Email-based linking |

**Both LOGIN and REGISTRATION use Google/Facebook only!** 🎉
