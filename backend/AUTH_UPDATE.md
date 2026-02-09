# Backend Authentication Update - OTP Removed, Social Login Only

## Changes Made

### ✅ REMOVED Endpoints:
1. **POST /api/auth/send-otp** - Removed OTP sending
2. **POST /api/auth/verify-otp** - Removed OTP verification
3. **POST /api/auth/login** - Removed email/password login
4. All OTP-related helper functions removed

### ✅ KEPT Endpoints:
1. **POST /api/auth/social-login** - Google & Facebook login
2. **POST /api/auth/register** - Complete profile after social login
3. **GET /api/auth/me** - Get current user info

---

## New Authentication Flow

### Step 1: Social Login
**POST** `/api/auth/social-login`

```json
{
  "provider": "google",           // or "facebook"
  "provider_user_id": "12345...",
  "email": "user@example.com",
  "full_name": "John Doe",
  "display_name": "John",
  "avatar_url": "https://...",
  "fcm_token": "firebase_token"
}
```

**Response:**
```json
{
  "message": "Login successful",
  "token": "JWT_TOKEN",
  "user": { ...user data },
  "isNewUser": true/false
}
```

### Step 2: Complete Profile (After Social Login)
**POST** `/api/auth/register` (Requires JWT token from step 1)

```json
{
  "email": "user@example.com",
  "full_name": "John Doe",
  "display_name": "John",
  "gender": "Male",              // or "Female" (creates listener)
  "date_of_birth": "1995-05-20",
  "city": "Delhi",
  "country": "India",
  "avatar_url": "https://...",
  "bio": "Bio text",
  "fcm_token": "firebase_token",
  
  // If Female (Listener):
  "original_name": "Real Name",
  "rate_per_minute": 5.00,
  "languages": ["Hindi", "English"]
}
```

**Response:**
```json
{
  "message": "Profile updated successfully",
  "user": { ...user data },
  "accountType": "user" or "listener"
  // If listener, also includes:
  "listener": { ...listener data }
}
```

### Step 3: Get Current User
**GET** `/api/auth/me` (Requires JWT token)

**Response:**
```json
{
  "user": { ...user data }
}
```

---

## Mobile Flow Alignment

### Mobile App Flow (login.dart):
```
1. Launch App
2. Show Login Screen
3. User clicks "Login with Google" or "Login with Facebook"
4. Receive provider data
5. Call POST /api/auth/social-login
6. Get JWT token
7. Navigate to Gender Selection
8. Select Gender (Male/Female)
9. Fill Profile Details
10. Call POST /api/auth/register with gender
11. Backend creates User or Listener profile based on gender
12. Navigate to appropriate dashboard
```

### Backend Support:
✅ Social login with Google/Facebook  
✅ Automatic user creation  
✅ Gender-based account routing (Male=User, Female=Listener)  
✅ Listener profile auto-creation  
✅ Experience selection endpoint  
✅ Voice verification endpoint  
✅ Payment details endpoint  

---

## Import Changes

**Removed imports:**
- `import bcrypt from 'bcryptjs';` (no longer needed)

**Kept imports:**
- `import jwt from 'jsonwebtoken';`
- `import User from '../models/User.js';`
- `import Listener from '../models/Listener.js';`
- `import { pool } from '../db.js';`
- `import { authenticate } from '../middleware/auth.js';`

---

## Environment Variables (No Longer Needed)

These variables are no longer used:
- `ENABLE_PHONE_OTP`
- `ENABLE_EMAIL_PASSWORD`
- `OTP_EXPIRY_TIME`
- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_PHONE_NUMBER`

---

## Database Tables (No Longer Used)

The following table is no longer needed:
- `otp_verification` - Can be dropped

```sql
DROP TABLE IF EXISTS otp_verification CASCADE;
```

---

## Summary

| Aspect | Before | After |
|--------|--------|-------|
| Login Methods | OTP, Email/Password, Google, Facebook | Google, Facebook Only |
| Lines of Code | 431 | 217 |
| Complexity | High (3 auth methods) | Low (1 auth method) |
| Mobile Alignment | Partial | ✅ Complete |
| Registration | Phone-based | Google/Facebook-based |

---

## Next Steps

1. Update frontend mobile app if needed
2. Remove OTP table from database
3. Remove unused environment variables from `.env`
4. Test social login flow end-to-end
5. Deploy to production
