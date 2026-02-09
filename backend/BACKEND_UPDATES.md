# Backend Updates Based on Mobile App Requirements

## Summary
Updated the backend to match the mobile app's listener onboarding flow and call management features.

---

## 1. DATABASE SCHEMA UPDATES (database.sql)

### Listeners Table - New Fields:
- `original_name VARCHAR(100)` - Real name of listener (private)
- `experiences TEXT[]` - Array of personal experiences (Love Failure, Job Loss, etc.)
- `voice_verified BOOLEAN` - Voice verification status
- `voice_verification_url TEXT` - URL to stored voice recording

### New Table: listener_payment_details
Stores payment information for listeners with two methods:
- **UPI Payment Method**: UPI ID, Aadhaar Number, PAN Number, Name as per PAN
- **Bank Transfer Method**: Account Number, IFSC Code, Bank Name, Account Holder Name, PAN/Aadhaar

---

## 2. LISTENER MODEL UPDATES (models/Listener.js)

### Updated Methods:
1. **`create(listenerData)`** - Now accepts:
   - `original_name` - Real name
   - `experiences` - Array of experiences
   - All other existing fields

2. **NEW: `updateVoiceVerification(listener_id, voice_url)`**
   - Updates voice_verified status and stores voice recording URL

3. **NEW: `updateExperiences(listener_id, experiences)`**
   - Updates listener's personal experiences array

4. **NEW: `getRandomAvailable(limit, excludeListenerId)`**
   - Retrieves random available listeners for random call matching
   - Optional exclusion of specific listener

---

## 3. LISTENERS ROUTE UPDATES (routes/listeners.js)

### New Endpoints:

#### 1. PUT `/api/listeners/:listener_id/experiences`
Updates listener's personal experiences
- **Requires**: Authentication
- **Body**: `{ experiences: ["Love Failure", "Job Loss", ...] }`
- **Returns**: Updated experiences array

#### 2. PUT `/api/listeners/:listener_id/voice-verification`
Mark voice as verified
- **Requires**: Authentication
- **Body**: `{ voice_url: "https://..." }`
- **Returns**: voice_verified boolean

#### 3. POST `/api/listeners/:listener_id/payment-details`
Save listener's payment details (UPI or Bank)
- **Requires**: Authentication
- **Body** (UPI):
  ```json
  {
    "payment_method": "upi",
    "upi_id": "user@bank",
    "aadhaar_number": "123456789012",
    "pan_number": "ABCDE1234F",
    "name_as_per_pan": "Full Name"
  }
  ```
- **Body** (Bank):
  ```json
  {
    "payment_method": "bank",
    "account_number": "1234567890",
    "ifsc_code": "SBIN0001234",
    "bank_name": "State Bank of India",
    "account_holder_name": "Full Name",
    "pan_aadhaar_bank": "ABCDE1234F"
  }
  ```

#### 4. GET `/api/listeners/random`
Get random available listeners for random calls
- **Params**: `limit` (default: 1), `exclude` (listener_id to exclude)
- **Returns**: Array of random listeners

---

## 4. AUTH ROUTE UPDATES (routes/auth.js)

### Updated: POST `/api/auth/register`

Now supports gender-based account type assignment:
- **If gender = "Male"**: Creates regular user account (account_type: 'user')
- **If gender = "Female"**: Creates listener account (account_type: 'listener')

#### New Body Parameters:
```json
{
  "gender": "Female",
  "original_name": "Real Name",
  "display_name": "Professional Name",
  "rate_per_minute": 5.00,
  "languages": ["Hindi", "English"],
  ...other existing fields
}
```

#### Response:
- For listeners: Returns listener profile + user data
- For users: Returns user data

---

## 5. CALLS ROUTE UPDATES (routes/calls.js)

### New Endpoint: POST `/api/calls/random`

Initiates a random call with a random available listener
- **Requires**: Authentication
- **Body**: `{ call_type: "audio" }`
- **Returns**: Call object + listener details (name, rating, city)

---

## 6. CALL FLOW MATCHING

### Mobile App Flow → Backend Implementation:

1. **Login** → OTP Verification
   - `POST /api/auth/send-otp`
   - `POST /api/auth/verify-otp`

2. **Gender Selection** → Account Type Routing
   - Male → User Account
   - Female → Listener Account

3. **Listener Onboarding Flow**:
   - Profile Setup → `POST /api/auth/register`
   - Experience Selection → `PUT /api/listeners/:id/experiences`
   - Voice Verification → `PUT /api/listeners/:id/voice-verification`
   - Payment Setup → `POST /api/listeners/:id/payment-details`

4. **User Call Flow**:
   - Browse Listeners → `GET /api/listeners` (with filters)
   - Random Call → `POST /api/calls/random`
   - Regular Call → `POST /api/calls`
   - Rate Call → `POST /api/calls/:id/rating`

5. **Listener Dashboard**:
   - Incoming Calls via WebSocket
   - Accept/Reject Calls via WebSocket events

---

## 7. DATABASE MIGRATION NOTES

To apply these changes:
```sql
-- Drop existing listeners table if needed
DROP TABLE IF EXISTS listeners CASCADE;

-- Re-run the database.sql file with new schema
-- Or execute the ALTER TABLE statements:

ALTER TABLE listeners ADD COLUMN original_name VARCHAR(100);
ALTER TABLE listeners ADD COLUMN experiences TEXT[] DEFAULT '{}';
ALTER TABLE listeners ADD COLUMN voice_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE listeners ADD COLUMN voice_verification_url TEXT;

-- Create payment details table
CREATE TABLE listener_payment_details (
  ... (see database.sql for full schema)
);
```

---

## 8. KEY FEATURES ADDED

✅ **Listener Registration Flow** - Complete onboarding from login to payment setup
✅ **Personal Experiences** - Listeners can select what problems they've faced
✅ **Voice Verification** - Audio verification for listeners
✅ **Flexible Payment** - UPI or Bank transfer support
✅ **Random Call Matching** - Connect users with random available listeners
✅ **Gender-Based Routing** - Automatic account type assignment based on gender

---

## 9. NEXT STEPS (OPTIONAL)

- Implement file upload for voice verification (multipart/form-data)
- Add payment verification workflow
- Add listener availability scheduling
- Implement random call preference filters (by language, speciality, rating)
- Add notification system for incoming calls
