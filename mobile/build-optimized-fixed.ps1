########################################
# OPTIMIZED APK BUILD SCRIPT
# Builds smallest possible APK with all optimizations
########################################

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  OPTIMIZED APK BUILD - Target: <25MB per ABI" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean previous build artifacts
Write-Host "[1/6] Cleaning previous builds..." -ForegroundColor Yellow
flutter clean
if ($LASTEXITCODE -ne 0) {
    Write-Host "Clean failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Clean completed" -ForegroundColor Green
Write-Host ""

# Step 2: Get dependencies
Write-Host "[2/6] Fetching dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "Dependency fetch failed!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Dependencies fetched" -ForegroundColor Green
Write-Host ""

# Step 3: Analyze package size before build
Write-Host "[3/6] Analyzing dependencies..." -ForegroundColor Yellow
flutter pub deps --no-dev | Select-String "agora|audioplayers|cached_network|google_sign|facebook" | Write-Host
Write-Host ""

# Step 4: Build optimized APK
Write-Host "[4/6] Building optimized APK with:" -ForegroundColor Yellow
Write-Host "  - Split per ABI (separate APKs for each architecture)" -ForegroundColor Gray
Write-Host "  - Code shrinking enabled (R8/ProGuard)" -ForegroundColor Gray
Write-Host "  - Obfuscation enabled (smaller & more secure)" -ForegroundColor Gray
Write-Host "  - Debug symbols stripped" -ForegroundColor Gray
Write-Host ""

flutter build apk --release --split-per-abi --shrink --obfuscate --split-debug-info=build/symbols

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed! Check errors above." -ForegroundColor Red
    exit 1
}
Write-Host "✓ Build completed successfully" -ForegroundColor Green
Write-Host ""

# Step 5: Display APK sizes
Write-Host "[5/6] APK Size Analysis:" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Cyan

$apkPath = "build\app\outputs\flutter-apk\"
$apks = Get-ChildItem -Path $apkPath -Filter "app-*-release.apk" | Sort-Object Name

$totalSize = 0
foreach ($apk in $apks) {
    $sizeMB = [math]::Round($apk.Length / 1MB, 2)
    $totalSize += $sizeMB
    
    $color = "Green"
    if ($sizeMB -gt 25) { $color = "Yellow" }
    if ($sizeMB -gt 30) { $color = "Red" }
    
    Write-Host ("  {0,-40} {1,8} MB" -f $apk.Name, $sizeMB) -ForegroundColor $color
}

Write-Host "------------------------------------------------" -ForegroundColor Cyan
Write-Host ("  Total Size (all ABIs):                  {0,8} MB" -f $totalSize) -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 6: Size recommendations
Write-Host "[6/6] Optimization Report:" -ForegroundColor Yellow

if ($totalSize -lt 50) {
    Write-Host "✓ EXCELLENT: Total size is under 50MB" -ForegroundColor Green
} else {
    Write-Host "⚠ WARNING: Total size exceeds 50MB" -ForegroundColor Yellow
}
Write-Host ""

# Check individual APK sizes
$maxApk = $apks | Sort-Object Length -Descending | Select-Object -First 1
if ($maxApk) {
    $maxSizeMB = [math]::Round($maxApk.Length / 1MB, 2)

    if ($maxSizeMB -le 25) {
        Write-Host "✓ SUCCESS: All APKs are under 25MB target!" -ForegroundColor Green
    } elseif ($maxSizeMB -le 30) {
        Write-Host "✓ GOOD: APKs are under 30MB (acceptable)" -ForegroundColor Green
    } else {
        Write-Host "⚠ ATTENTION: Largest APK is $maxSizeMB MB" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Size Reduction Recommendations:" -ForegroundColor Cyan
        Write-Host "  1. Agora SDK is ~70MB - Consider audio-only version" -ForegroundColor Gray
        Write-Host "  2. Compress images in assets/ folder to WebP format" -ForegroundColor Gray
        Write-Host "  3. Remove unused profile avatar images" -ForegroundColor Gray
        Write-Host "  4. Consider lazy-loading heavy features" -ForegroundColor Gray
    }
}
Write-Host ""

# APK location
Write-Host "APK Location:" -ForegroundColor Cyan
Write-Host "  $((Get-Location).Path)\$apkPath" -ForegroundColor White
Write-Host ""

# Symbol files location (for crash reports)
Write-Host "Debug Symbols (for crash analysis):" -ForegroundColor Cyan
Write-Host "  $((Get-Location).Path)\build\symbols" -ForegroundColor White
Write-Host ""

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Build completed! Ready for testing/distribution" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Cyan
