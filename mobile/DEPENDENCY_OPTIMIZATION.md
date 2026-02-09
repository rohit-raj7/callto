# DEPENDENCY OPTIMIZATION RECOMMENDATIONS
# Analysis of current dependencies and lighter alternatives

## Current Heavy Dependencies (Size Impact)

### 🔴 CRITICAL SIZE ISSUES

#### 1. agora_rtc_engine: ^6.3.2 (~70-80 MB)
**Current Impact:** 70-80% of your APK size
**Problem:** Includes full video SDK with multiple codecs
**Options:**
```yaml
# Option A: Keep current (if video calling is essential)
agora_rtc_engine: ^6.3.2  # 70-80 MB

# Option B: Audio-only SDK (50% smaller)
# Requires separate Agora Voice SDK package
# agora_rtc_engine_voice: ^x.x.x  # ~30-40 MB

# Option C: WebRTC alternative (lighter)
# flutter_webrtc: ^0.9.36  # ~15-20 MB
# Pros: Smaller, more control
# Cons: Requires custom signaling, more complexity
```

**Recommendation:** 
- If video is essential: Keep Agora (accept 55-70MB APK)
- If audio-only acceptable: Switch to Agora Voice SDK
- If have dev resources: Migrate to WebRTC

---

### 🟡 MEDIUM SIZE ISSUES

#### 2. cached_network_image: ^3.4.1 (~2-3 MB)
**Current Impact:** 2-3 MB
**Problem:** Heavy with many transitive dependencies
**Alternative:**
```yaml
# Replace with lighter option:
flutter_cache_manager: ^3.3.1  # ~1 MB
# Use with Image.network directly

# Or use optimized_cached_image:
optimized_cached_image: ^3.1.0  # ~1.5 MB
```

**Implementation:**
```dart
// OLD:
CachedNetworkImage(imageUrl: url)

// NEW:
Image.network(
  url,
  cacheWidth: 500,  // Resize for memory efficiency
  cacheHeight: 500,
)
```

#### 3. audioplayers: ^5.2.1 (~3-5 MB)
**Current Impact:** 3-5 MB
**Problem:** Includes multiple audio backend implementations
**Alternative:**
```yaml
# Option A: just_audio (recommended)
just_audio: ^0.9.34  # ~1-2 MB
# Smaller, better maintained, similar API

# Option B: assets_audio_player
assets_audio_player: ^3.1.1  # ~2 MB
```

**Migration Effort:** Medium (API similar but not identical)

#### 4. google_sign_in: ^6.2.1 (~5-8 MB)
**Current Impact:** 5-8 MB
**Problem:** Includes full Google Play Services
**Alternative:**
```yaml
# No lighter alternative for native Google Sign-In
# Keep this if Google auth is essential

# For web-only alternative:
google_sign_in_web: ^0.12.1  # Much smaller but web-only
# Won't work for native Android
```

**Recommendation:** Keep (essential for auth)

#### 5. flutter_facebook_auth: ^7.0.1 (~4-6 MB)
**Current Impact:** 4-6 MB
**Problem:** Includes Facebook SDK
**Alternative:**
```yaml
# Option A: Remove if rarely used
# Implement web-based OAuth instead

# Option B: flutter_login_facebook
flutter_login_facebook: ^1.9.0  # ~2-3 MB (lighter)
```

**Recommendation:** Remove if <20% of users use Facebook login

---

### 🟢 SMALL/OPTIMIZED DEPENDENCIES (Keep)

#### 6. http: ^1.2.0 (~0.5 MB) ✅
**Current Impact:** Minimal
**Status:** Already optimized
**No change needed**

#### 7. shared_preferences: ^2.2.2 (~0.3 MB) ✅
**Current Impact:** Minimal
**Status:** Lightweight
**No change needed**

#### 8. socket_io_client: ^3.0.2 (~1-2 MB) ✅
**Current Impact:** Small
**Status:** Necessary for real-time features
**No change needed**

#### 9. permission_handler: ^11.3.1 (~1-2 MB) ✅
**Current Impact:** Small
**Status:** Essential for Agora permissions
**No change needed**

#### 10. intl: ^0.20.2 (~0.2 MB) ✅
**Current Impact:** Minimal
**Status:** Lightweight
**No change needed**

---

## 📊 Size Impact Summary

| Dependency | Current Size | Optimized Alternative | Potential Savings |
|------------|-------------|----------------------|-------------------|
| agora_rtc_engine | 70-80 MB | WebRTC / Voice SDK | 40-60 MB |
| cached_network_image | 2-3 MB | flutter_cache_manager | 1-2 MB |
| audioplayers | 3-5 MB | just_audio | 2-3 MB |
| google_sign_in | 5-8 MB | (keep) | 0 MB |
| flutter_facebook_auth | 4-6 MB | Remove / lighter alt | 2-4 MB |
| **TOTAL POTENTIAL** | **84-102 MB** | **Optimized** | **45-69 MB** |

---

## 🎯 Recommended Optimization Strategy

### Phase 1: Quick Wins (Low effort, 5-8 MB savings)
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # REPLACE cached_network_image
  # cached_network_image: ^3.4.1
  flutter_cache_manager: ^3.3.1
  
  # REPLACE audioplayers
  # audioplayers: ^5.2.1
  just_audio: ^0.9.34
  
  # REMOVE if Facebook login <20% usage
  # flutter_facebook_auth: ^7.0.1
  
  # KEEP essential
  animated_text_kit: ^4.2.2
  cupertino_icons: ^1.0.8
  http: ^1.2.0
  shared_preferences: ^2.2.2
  google_sign_in: ^6.2.1
  agora_rtc_engine: ^6.3.2  # Keep for now
  permission_handler: ^11.3.1
  socket_io_client: ^3.0.2
  intl: ^0.20.2
  web: ^1.1.0
```

**Expected APK Size:** 60-70 MB per ABI

### Phase 2: Major Refactor (High effort, 40-60 MB savings)
```yaml
dependencies:
  # REPLACE Agora with WebRTC
  # agora_rtc_engine: ^6.3.2
  flutter_webrtc: ^0.9.36
  
  # Plus Phase 1 optimizations
```

**Expected APK Size:** 25-35 MB per ABI
**Effort:** 2-4 weeks development + testing

---

## 🔧 Migration Code Examples

### 1. Replace cached_network_image

**Before:**
```dart
import 'package:cached_network_image/cached_network_image.dart';

CachedNetworkImage(
  imageUrl: userAvatarUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
)
```

**After:**
```dart
Image.network(
  userAvatarUrl,
  cacheWidth: 500,
  cacheHeight: 500,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator();
  },
  errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
)
```

### 2. Replace audioplayers with just_audio

**Before:**
```dart
import 'package:audioplayers/audioplayers.dart';

final player = AudioPlayer();
await player.play(AssetSource('voice/sample.mp3'));
await player.pause();
await player.stop();
```

**After:**
```dart
import 'package:just_audio/just_audio.dart';

final player = AudioPlayer();
await player.setAsset('assets/voice/sample.mp3');
await player.play();
await player.pause();
await player.stop();
```

### 3. Remove flutter_facebook_auth (if needed)

**Option A: Remove completely**
- Remove from pubspec.yaml
- Remove Facebook button from login screen
- Remove Facebook-related code

**Option B: Implement web OAuth**
```dart
// Use url_launcher to open Facebook web OAuth
import 'package:url_launcher/url_launcher.dart';

Future<void> loginWithFacebook() async {
  final authUrl = 'https://www.facebook.com/v12.0/dialog/oauth?...';
  if (await canLaunchUrl(Uri.parse(authUrl))) {
    await launchUrl(Uri.parse(authUrl));
  }
  // Handle callback with redirect_uri
}
```

---

## 🧪 Testing Checklist After Dependency Changes

- [ ] Image loading works (cached_network_image → Image.network)
- [ ] Audio playback works (audioplayers → just_audio)
- [ ] Facebook login removed or replaced
- [ ] App builds successfully
- [ ] No runtime errors
- [ ] APK size measured and reduced
- [ ] Performance is acceptable
- [ ] Memory usage is stable

---

## 📦 Alternative: Modular Approach

For large features like video calling, consider dynamic feature modules:

```gradle
// android/app/build.gradle.kts
android {
    dynamicFeatures = mutableSetOf(
        ":features:videocalling"
    )
}
```

This allows:
- Base APK: 15-20 MB (without Agora)
- Video module: Downloaded on-demand (~70 MB)
- User only downloads video calling if they use it

**Complexity:** High (requires Android App Bundle + dynamic features)

---

## 🎓 Dependency Audit Command

Run periodically to monitor dependency sizes:

```powershell
# List all dependencies with versions
flutter pub deps --no-dev

# Analyze Flutter app size
flutter build apk --analyze-size --target-platform=android-arm64

# Check for outdated dependencies
flutter pub outdated

# Find unused dependencies
flutter pub deps --json | ConvertFrom-Json | Select-Object name, version
```

---

**Recommendation:**
1. **Immediate:** Apply Phase 1 optimizations (5-8 MB savings, 1-2 days work)
2. **Short-term:** Evaluate Agora necessity (is video essential?)
3. **Long-term:** Consider WebRTC migration if <25MB is critical requirement

**Realistic targets:**
- With current dependencies: 55-65 MB
- With Phase 1 optimizations: 48-58 MB  
- With Phase 2 (WebRTC): 25-35 MB
