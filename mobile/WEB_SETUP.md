# Web Setup Guide for Social Authentication

The mobile app uses Google and Facebook authentication, which requires additional setup for web platforms.

## Current Status

⚠️ **Social login is currently configured for mobile only**. When running on Chrome/Web, the social login buttons will show a message asking users to use the mobile app.

## To Enable Google Sign-In for Web

### 1. Create Google OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable "Google+ API"
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client ID"
5. Choose "Web application"
6. Add authorized JavaScript origins:
   - `http://localhost` (for development)
   - Your production URL
7. Add authorized redirect URIs:
   - `http://localhost` (for development)
   - Your production URL
8. Copy the **Client ID**

### 2. Update web/index.html

Add this meta tag in the `<head>` section of `web/index.html`:

```html
<head>
  <!-- ... other tags ... -->
  
  <!-- Google Sign-In -->
  <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
  
  <!-- ... other tags ... -->
</head>
```

Replace `YOUR_CLIENT_ID` with your actual Google OAuth Client ID.

### 3. Update login.dart

The code already handles Google Sign-In gracefully. Once you add the meta tag, Google Sign-In will work automatically on web.

## To Enable Facebook Login for Web

### 1. Configure Facebook App

1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create or select your app
3. Add "Facebook Login" product
4. Go to Settings → Basic
5. Add your website URL
6. Go to Facebook Login → Settings
7. Add Valid OAuth Redirect URIs:
   - `http://localhost` (for development)
   - Your production URL

### 2. Update web/index.html

Add the Facebook SDK in `web/index.html`:

```html
<head>
  <!-- ... other tags ... -->
  
  <!-- Facebook SDK -->
  <script>
    window.fbAsyncInit = function() {
      FB.init({
        appId      : 'YOUR_FACEBOOK_APP_ID',
        cookie     : true,
        xfbml      : true,
        version    : 'v18.0'
      });
    };

    (function(d, s, id){
       var js, fjs = d.getElementsByTagName(s)[0];
       if (d.getElementById(id)) {return;}
       js = d.createElement(s); js.id = id;
       js.src = "https://connect.facebook.net/en_US/sdk.js";
       fjs.parentNode.insertBefore(js, fjs);
     }(document, 'script', 'facebook-jssdk'));
  </script>
  
  <!-- ... other tags ... -->
</head>
```

### 3. Uncomment Facebook Login Code

In `lib/login/login.dart`, uncomment the Facebook login implementation in `_handleFacebookLogin()` method.

## Testing on Mobile

For Android/iOS, social login works without web-specific configuration:

### Android
```bash
flutter run -d android
```

### iOS
```bash
flutter run -d ios
```

The Google and Facebook SDKs are already configured in the native projects.

## Alternative: Skip Web Testing

For development, you can:
1. Test the API integration using mobile emulators/devices
2. Use the backend API endpoints directly
3. The rest of the app functionality works fine on web (listeners, calls, chats, etc.)

## Production Deployment

When deploying to production:
1. Update all OAuth redirect URLs to your production domain
2. Update the meta tags with production client IDs
3. Configure CORS in your backend to allow your domain
4. Test thoroughly on both mobile and web platforms
