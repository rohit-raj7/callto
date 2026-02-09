# Call To - Backend API

Complete backend API server for the Call To mobile application - a platform connecting users with listeners/experts for voice/video calls and chat.

## 🚀 Features

- **Authentication**: Google/Facebook social login, JWT authentication (phone OTP optional)
- **User Management**: Profile management, avatars, languages, preferences
- **Listener Profiles**: Expert profiles with specialties, ratings, availability
- **Calls**: Audio/Video call management with WebRTC signaling
- **Real-time Chat**: WebSocket-based instant messaging
- **Ratings & Reviews**: Call rating system
- **Wallet & Transactions**: Payment tracking
- **Real-time Features**: Socket.IO for live updates, call signaling

## 📋 Prerequisites

- Node.js (v14 or higher)
- PostgreSQL (AWS RDS recommended)
- npm or yarn
- AWS Account (for RDS, S3)
- (Optional) Twilio Account (for SMS OTP)

## 🛠️ Installation

1. **Install dependencies**
```bash
npm install
```

2. **Configure environment variables**
```bash
cp .env.example .env
# Edit .env with your actual credentials
```

3. **Setup database**
```bash
# Connect to your PostgreSQL database and run:
psql -h your-rds-host -U postgres -d call_to_db -f database.sql
```

4. **Start the server**
```bash
# Development
npm run dev

# Production
npm start
```

## 📁 Project Structure

```
backend/
├── index.js                 # Main server file
├── db.js                    # Database connection
├── package.json
├── database.sql             # Database schema
├── .env.example            # Environment variables template
├── config/
│   └── config.js           # App configuration
├── models/
│   ├── User.js             # User model
│   ├── Listener.js         # Listener/Expert model
│   ├── Call.js             # Call model
│   ├── Chat.js             # Chat & Message models
│   └── Rating.js           # Rating model
├── routes/
│   ├── auth.js             # Authentication routes
│   ├── users.js            # User routes
│   ├── listeners.js        # Listener routes
│   ├── calls.js            # Call routes
│   └── chats.js            # Chat routes
├── middleware/
│   └── auth.js             # Authentication middleware
└── utils/
    └── validators.js       # Request validators
```

## 🔌 API Endpoints

### Authentication
- `POST /api/auth/social-login` - Login/register with Google/Facebook
- `POST /api/auth/register` - Complete user profile after login
- `GET /api/auth/me` - Get current user

#### Optional (phone OTP)
Phone OTP routes are disabled by default. Set `ENABLE_PHONE_OTP=true` to enable:
- `POST /api/auth/send-otp` - Send OTP to phone
- `POST /api/auth/verify-otp` - Verify OTP and login/register

### Users
- `GET /api/users/profile` - Get user profile
- `PUT /api/users/profile` - Update profile
- `GET /api/users/:user_id` - Get user by ID
- `POST /api/users/languages` - Add language
- `GET /api/users/wallet` - Get wallet
- `POST /api/users/favorites/:listener_id` - Add favorite
- `GET /api/users/favorites` - Get favorites

### Listeners
- `GET /api/listeners` - Get all listeners (with filters)
- `GET /api/listeners/search?q=` - Search listeners
- `GET /api/listeners/:listener_id` - Get listener profile
- `POST /api/listeners` - Create listener profile
- `PUT /api/listeners/:listener_id` - Update profile
- `GET /api/listeners/:listener_id/ratings` - Get ratings

### Calls
- `POST /api/calls` - Initiate call
- `GET /api/calls/:call_id` - Get call details
- `PUT /api/calls/:call_id/status` - Update call status
- `GET /api/calls/history/me` - Get call history
- `POST /api/calls/:call_id/rating` - Rate call

### Chats
- `GET /api/chats` - Get all chats
- `POST /api/chats` - Create/get chat
- `GET /api/chats/:chat_id/messages` - Get messages
- `POST /api/chats/:chat_id/messages` - Send message

## 🗄️ Database Schema

See `database.sql` for complete schema including users, listeners, calls, chats, messages, ratings, transactions, and more.

## 🚀 Quick Start

```bash
# Install dependencies
npm install

# Setup environment
cp .env.example .env

# Run database schema
psql -h your-host -U postgres -d call_to_db -f database.sql

# Start development server
npm run dev
```

## Security Notes

- Never commit `.env` file to version control
- Use strong JWT secrets in production
- Enable SSL for AWS RDS connections
- Configure proper CORS origins

## Usage

The `index.js` file includes:
- Database connection setup with connection pooling
- Test connection function
- Sample CRUD operations (commented out)
- Reusable query execution function

Uncomment the sample operations in the `main()` function to test creating tables and inserting data.
