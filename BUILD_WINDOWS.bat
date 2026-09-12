@echo off
setlocal
cd /d "%~dp0"
echo === TACTIX Windows build ===
where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter SDK is not available in PATH.
  pause
  exit /b 1
)
call flutter doctor -v
if errorlevel 1 (
  echo [WARN] flutter doctor reports an environment problem.
)
call flutter clean
if errorlevel 1 exit /b 1
call flutter pub get
if errorlevel 1 exit /b 1
call flutter analyze
if errorlevel 1 exit /b 1
call flutter build windows --release
if errorlevel 1 (
  echo.
  echo [ERROR] Windows build failed.
  echo Check Visual Studio Desktop development with C++ and Windows SDK.
  echo The executable, when successful, is under:
  echo build\windows\x64\runner\Release\
  pause
  exit /b 1
)
echo.
echo [OK] Windows release built.
echo build\windows\x64\runner\Release\
pause
