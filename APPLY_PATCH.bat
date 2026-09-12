@echo off
setlocal
if not exist "pubspec.yaml" (
  echo [ERROR] Run this file from the Flutter project root.
  pause
  exit /b 1
)
if not exist "lib\main.dart" (
  echo [ERROR] lib\main.dart was not found.
  pause
  exit /b 1
)
copy /Y "lib\main.dart" "lib\main_before_tactic_ui.dart" >nul
copy /Y "PATCH\lib\main.dart" "lib\main.dart" >nul
if errorlevel 1 (
  echo [ERROR] Failed to replace lib\main.dart
  pause
  exit /b 1
)
echo [OK] New TACTIX military UI installed.
echo [OK] Backup: lib\main_before_tactic_ui.dart
pause
