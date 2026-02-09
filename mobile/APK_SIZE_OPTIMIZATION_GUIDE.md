# APK SIZE OPTIMIZATION CHECKLIST
## Target: Reduce from 75MB+ to under 25MB per ABI

### ✅ Completed Optimizations

#### 1. Build Configuration (build.gradle.kts)
- [x] Enable split-per-abi (separate APK per architecture)
- [x] Exclude x86/x86_64 architectures (~30% reduction)
- [x] Enable R8 code shrinking (isMinifyEnabled = true)
- [x] Enable resource shrinking (isShrinkResources = true)
- [x] Remove debug symbols (debugSymbolLevel = NONE)
- [x] Compress native libraries (useLegacyPackaging = false)
- [x] Exclude unused metadata files
- [x] Disable unused build features (viewBinding, dataBinding, etc.)

#### 2. ProGuard Rules (proguard-rules.pro)
- [x] Aggressive optimization passes (7 passes)
- [x] Remove all logging (Log.d, Log.v, Log.i, Log.w, Log.e)
- [x] Remove Kotlin intrinsics checks
- [x] Enable class merging and repackaging
- [x] Keep only essential Flutter/plugin classes

#### 3. Manifest Optimizations (AndroidManifest.xml)
- [x] Set extractNativeLibs="false" (Android 6.0+)
- [x] Enable hardware acceleration
- [x] Disable backup (allowBackup="false")
- [x] Set largeHeap="false"

#### 4. Resource Optimization
- [x] Created keep.xml for resource shrinker guidance
- [x] Exclude unused META-INF files
- [x] Remove Kotlin metadata files

---

### 🔄 Recommended Next Steps

#### 5. Asset Optimization (Manual - High Impact)
- [ ] **Convert images to WebP format** (50-80% size reduction)
  ```powershell
  # Install cwebp tool, then run:
  Get-ChildItem assets -Recurse -Include *.jpg,*.png | ForEach-Object {
      cwebp -q 80 $_.FullName -o ($_.FullName -replace '\.(jpg|png)$', '.webp')
  }
  ```
- [ ] **Reduce login images** (currently 15 images @ ~3MB total)
  - Keep only 5-7 most impactful images
  - Resize to max 1920x1080 (current may be higher)
- [ ] **Remove bundled profile avatars** (30+ images @ ~0.3MB)
  - Load avatars from server/CDN instead
  - Or include only 5 default avatars
- [ ] **Compress audio files**
  - Convert sample.mp3 to lower bitrate (64kbps for voice)

#### 6. Dependency Analysis (Critical for Size)
Current heavy dependencies:
- **agora_rtc_engine: ^6.3.2** (~70-80MB) ⚠️ MAJOR ISSUE
  - [ ] Option A: Use audio-only SDK (50% smaller)
  - [ ] Option B: Accept larger APK (Agora is essential for video)
  - [ ] Option C: Explore alternatives (WebRTC, Twilio)
  
- **audioplayers: ^5.2.1** (~3-5MB)
  - [ ] Consider just_audio (lighter alternative)
  
- **cached_network_image: ^3.4.1** (~2-3MB)
  - [ ] Replace with flutter_cache_manager (lighter)
  - [ ] Or use simple Image.network with caching

- **google_sign_in: ^6.2.1** (~5-8MB)
  - [ ] Keep (essential for auth)
  
- **flutter_facebook_auth: ^7.0.1** (~4-6MB)
  - [ ] Remove if Facebook login rarely used
  - [ ] Or implement web-based OAuth (no SDK needed)

#### 7. Code Optimization
- [ ] Run `flutter pub deps` to find transitive dependencies
- [ ] Remove unused imports in Dart files
- [ ] Use tree-shaking with `--split-debug-info`
- [ ] Enable deferred loading for heavy features

#### 8. Native Library Optimization
- [ ] Check if Agora includes unused codecs
- [ ] Remove video codecs if audio-only
- [ ] Strip all symbol tables from .so files

---

### 📊 Expected Size Breakdown (After Full Optimization)

| Component | Current Size | Optimized Size | Savings |
|-----------|-------------|----------------|---------|
| Agora RTC SDK | 70-80 MB | 70-80 MB (or 30-40 MB audio-only) | 0-40 MB |
| Flutter Engine | 8-10 MB | 6-8 MB (with R8) | 2 MB |
| Dart Code | 5-8 MB | 3-4 MB (obfuscated) | 3 MB |
| Other Plugins | 10-15 MB | 8-10 MB | 3 MB |
| Assets | 3-4 MB | 1-2 MB (WebP) | 2 MB |
| **TOTAL (arm64)** | **96 MB** | **88-104 MB** or **48-64 MB** | **8-48 MB** |

**Realistic Target with Video Agora: 55-65 MB per ABI**  
**Realistic Target with Audio-Only Agora: 35-45 MB per ABI**  
**Under 25 MB: Only possible without Agora or with major feature removal**

---

### 🚨 Critical Reality Check

**The Agora SDK Problem:**
- Agora RTC Engine with video support is inherently large (60-80MB)
- This is due to multiple video codecs, audio processing, and native libraries
- Your APK will likely be **55-70MB per ABI minimum** with full Agora

**Options to Reach <25MB Target:**
1. **Remove Agora entirely** - Not viable if video calls are core feature
2. **Use Agora Voice SDK only** - Gets to ~35-45MB
3. **Switch to WebRTC** - Lighter but requires more custom implementation
4. **Accept 55-70MB** - Industry standard for video calling apps

**Comparison with Similar Apps:**
- Zoom: 60-80MB
- Google Meet: 50-70MB
- WhatsApp: 40-60MB (with video calling)
- Discord: 70-90MB

---

### 🛠️ Troubleshooting Guide

#### Build Fails with R8 Errors
```
Solution: Check proguard-rules.pro for missing -keep rules
Add -dontwarn for problematic classes
```

#### App Crashes on Startup
```
Symptom: Release build crashes, debug works fine
Solution: Over-aggressive ProGuard rules
Fix: Add -keep rules for classes used via reflection
Check: Agora, Socket.IO, Firebase classes
```

#### Native Library Loading Fails
```
Symptom: UnsatisfiedLinkError in release build
Solution: extractNativeLibs="false" incompatible with some libraries
Fix: Set extractNativeLibs="true" in AndroidManifest.xml
```

#### APK Still Too Large After Optimization
```
Solution: Analyze APK content
1. Build > Analyze APK in Android Studio
2. Check lib/ folder - should only have armeabi-v7a or arm64-v8a
3. Check assets/ folder - convert images to WebP
4. Check classes.dex - should be obfuscated and small
```

#### Different APK Size on Play Store
```
Reason: Google Play applies additional compression
Actual download size is ~15-20% smaller than APK size
Use Android App Bundle (.aab) for best compression
```

---

### 📱 Build Commands Reference

```powershell
# Standard optimized build (recommended)
./build-optimized.ps1

# Manual build with all optimizations
flutter build apk --release --split-per-abi --shrink --obfuscate --split-debug-info=build/symbols

# Build Android App Bundle (for Play Store)
flutter build appbundle --release --shrink --obfuscate --split-debug-info=build/symbols

# Analyze APK size breakdown
flutter build apk --release --analyze-size

# Test release build on device
flutter install --release
```

---

### 📋 Pre-Release Checklist

- [ ] Test on multiple devices (ARM32 and ARM64)
- [ ] Verify video calling works
- [ ] Check Google/Facebook login
- [ ] Test audio playback
- [ ] Verify socket connections
- [ ] Check for any missing resources
- [ ] Test offline functionality
- [ ] Verify crash reporting works (check debug symbols)
- [ ] Performance test (startup time, memory usage)
- [ ] Security audit (ProGuard mapping file secured)

---

### 📈 Size Monitoring

Keep track of APK size after each release:
```
Release 1.0.0: XX MB
Release 1.1.0: XX MB (+/- X MB)
```

Monitor dependencies:
```powershell
flutter pub deps --json > deps.json
# Analyze deps.json for size contributors
```

---

### 💡 Alternative Approaches

If <25MB is absolutely required:

1. **Progressive App (PWA)**
   - Build Flutter web version
   - No app store limitations
   - Smaller initial download
   - Requires internet connection

2. **Modular Architecture**
   - Base app: 15-20MB
   - Download video calling module on-demand
   - Use Flutter deferred components
   - More complex implementation

3. **Native Video SDK**
   - Remove Flutter video plugins
   - Implement video calling in native Android
   - Use platform channels
   - Smaller but requires native expertise

---

**Generated by:** APK Optimization Assistant  
**Target:** Flutter Android App Size Reduction  
**Date:** January 2026
