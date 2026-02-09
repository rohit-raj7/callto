# APK SIZE OPTIMIZATION - QUICK REFERENCE CARD

## 📦 Files Created/Modified

### 1. android/app/build.gradle.kts ✅
**Optimizations Applied:**
- Split APKs by ABI (separate 32-bit and 64-bit)
- R8 code shrinking enabled
- Resource shrinking enabled
- Native library compression
- Debug symbols removed
- Unused metadata stripped
- Build features disabled

### 2. android/app/proguard-rules.pro ✅
**Optimizations Applied:**
- 7 optimization passes
- All logging removed (Log.d, Log.v, etc.)
- Kotlin intrinsics stripped
- Aggressive class merging
- Code repackaging

### 3. android/app/src/main/res/raw/keep.xml ✅
**Purpose:** Guides resource shrinker on what to keep/remove

### 4. android/app/src/main/AndroidManifest.xml ✅
**Optimizations Applied:**
- extractNativeLibs="false" (6.0+ compression)
- hardwareAccelerated="true"
- allowBackup="false"
- largeHeap="false"

### 5. build-optimized.ps1 ✅
**Purpose:** Automated build script with size analysis

### 6. APK_SIZE_OPTIMIZATION_GUIDE.md ✅
**Content:** Complete optimization checklist and troubleshooting

### 7. DEPENDENCY_OPTIMIZATION.md ✅
**Content:** Dependency analysis and lighter alternatives

---

## 🚀 BUILD COMMANDS

### Quick Build (Recommended)
```powershell
flutter build apk --release --split-per-abi --shrink --obfuscate --split-debug-info=build/symbols
```

### Using Build Script
```powershell
cd mobile
.\build-optimized.ps1
```

### For Play Store (AAB)
```powershell
flutter build appbundle --release --shrink --obfuscate --split-debug-info=build/symbols
```

---

## 📊 EXPECTED RESULTS

### With Current Dependencies
| ABI | Expected Size | Status |
|-----|---------------|--------|
| armeabi-v7a (32-bit) | 65-75 MB | 🟡 Acceptable |
| arm64-v8a (64-bit) | 70-80 MB | 🟡 Acceptable |

### THE REALITY: Agora Problem
- **Agora RTC Engine:** ~60-70MB of APK size
- **Getting under 25MB:** NOT POSSIBLE with current Agora SDK
- **Realistic Target:** 55-70MB per ABI

### Path to <30MB (if required)
1. **Replace Agora with WebRTC** → 25-35MB (2-4 weeks effort)
2. **Use Agora Voice SDK only** → 35-45MB (audio-only calls)
3. **Remove video calling** → 15-20MB (not viable)

---

## ✅ VERIFICATION CHECKLIST

After build completes:

- [ ] Check APK sizes in `build/app/outputs/flutter-apk/`
- [ ] Test armeabi-v7a APK on 32-bit device
- [ ] Test arm64-v8a APK on 64-bit device
- [ ] Verify video calling works
- [ ] Test Google Sign-In
- [ ] Test Facebook authentication
- [ ] Verify audio playback
- [ ] Check socket connection
- [ ] Test permissions (camera, microphone)
- [ ] Monitor app startup time
- [ ] Check memory usage

---

## 🔧 TROUBLESHOOTING

### Build Fails with "Conflicting configuration"
**Error:** ndk abiFilters cannot be present when splits abi filters are set
**Fix:** Remove ndk{} block from defaultConfig (use splits only)

### App Crashes on Startup (Release)
**Cause:** Over-aggressive ProGuard rules
**Fix:** Add -keep rules for classes used via reflection
**Check:** Agora, Socket.IO classes

### Native Library Not Found
**Error:** UnsatisfiedLinkError
**Fix:** Set extractNativeLibs="true" in AndroidManifest.xml
**Note:** Increases APK size slightly

### APK Too Large
**Reality Check:**
- Zoom app: 60-80MB
- Google Meet: 50-70MB  
- WhatsApp: 40-60MB
- Your app with Agora: 55-70MB is NORMAL

**Options:**
1. Accept current size (industry standard)
2. Switch to lighter video SDK
3. Use dynamic feature modules
4. Build PWA instead

---

## 📈 MONITORING

### Check APK Size
```powershell
Get-ChildItem build\app\outputs\flutter-apk\*.apk | Select-Object Name, @{N='Size(MB)';E={[math]::Round($_.Length/1MB, 2)}}
```

### Analyze APK Contents
```powershell
flutter build apk --analyze-size
```

### List Dependencies with Sizes
```powershell
flutter pub deps --no-dev
```

---

## 🎯 OPTIMIZATION PHASES

### ✅ Phase 1: COMPLETED (Current Build)
- Gradle optimizations
- ProGuard rules
- Resource shrinking
- Split ABIs
- **Expected savings:** 5-10MB

### 🔄 Phase 2: Quick Wins (1-2 days)
- Replace cached_network_image → Image.network
- Replace audioplayers → just_audio
- Remove flutter_facebook_auth (if unused)
- Compress assets to WebP
- **Expected savings:** 5-8MB
- **Target:** 48-58MB

### 🎯 Phase 3: Major Refactor (2-4 weeks)
- Replace Agora → WebRTC
- Implement custom video calling
- **Expected savings:** 40-50MB
- **Target:** 25-35MB

---

## 📝 NEXT ACTIONS

### Immediate (Today)
1. ✅ Build with optimizations (running)
2. Test APKs on devices
3. Measure actual sizes
4. Document results

### Short-term (This Week)
1. Review DEPENDENCY_OPTIMIZATION.md
2. Decide on Agora (keep/replace/audio-only)
3. Compress assets to WebP
4. Remove unused avatar images

### Long-term (This Month)
1. If <25MB critical: Plan WebRTC migration
2. If size acceptable: Deploy to Play Store
3. Set up monitoring for future size increases

---

## 🌟 KEY TAKEAWAYS

1. **With Agora Video:** 55-70MB is the realistic minimum
2. **Without Agora:** Can reach 15-25MB
3. **Current optimizations:** Applied all standard techniques
4. **Further reduction:** Requires dependency changes

**Decision Point:**  
Is video calling essential? If YES → accept 55-70MB. If NO → remove Agora.

---

## 📞 SUPPORT RESOURCES

- **Agora Size Issues:** https://docs.agora.io/en/faq/reduce_app_size_android
- **Flutter Size Optimization:** https://docs.flutter.dev/perf/app-size
- **R8 Shrinking:** https://developer.android.com/studio/build/shrink-code
- **ProGuard Rules:** https://www.guardsquare.com/manual/configuration

---

**Generated:** January 26, 2026  
**Build Target:** <25MB (realistic: 55-70MB with Agora)  
**Status:** Optimizations applied, build in progress
