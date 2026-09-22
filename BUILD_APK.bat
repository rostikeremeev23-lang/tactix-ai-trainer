@echo off
setlocal
if not exist "pubspec.yaml" (
  echo [ERROR] Run this file from the Flutter project root.
  pause
  exit /b 1
)
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter SDK is not available in PATH.
  echo Install Flutter and Android SDK, then reopen the terminal.
  pause
  exit /b 1
)
echo === TACTIX mobile release ===
call flutter clean
if errorlevel 1 exit /b 1
call flutter pub get
if errorlevel 1 exit /b 1
call flutter analyze
if errorlevel 1 exit /b 1
call flutter build apk --release --dart-define=TACTIX_API_URL=https://tactix-api.onrender.com --dart-define=AI_BACKEND_URL=https://tactix-api.onrender.com
if errorlevel 1 exit /b 1
echo.
echo [OK] APK built at:
echo build\app\outputs\flutter-apk\app-release.apk
pause
