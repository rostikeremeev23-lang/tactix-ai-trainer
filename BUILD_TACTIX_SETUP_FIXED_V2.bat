@echo off
setlocal
cd /d "%~dp0"

echo ==========================================
echo TACTIX - FINAL WINDOWS SETUP
echo ==========================================
echo.

echo [1/3] Building fresh Windows release...
call flutter build windows --release --dart-define=TACTIX_API_URL=https://tactix-api.onrender.com --dart-define=AI_BACKEND_URL=https://tactix-api.onrender.com
if errorlevel 1 (
  echo.
  echo ERROR: Flutter build failed.
  pause
  exit /b 1
)

if not exist "build\windows\x64\runner\Release\TACTIX.exe" (
  echo.
  echo ERROR: TACTIX.exe was not found in the Release folder.
  echo Available EXE files:
  dir /b "build\windows\x64\runner\Release\*.exe"
  pause
  exit /b 1
)

echo [2/3] Looking for Inno Setup 6...
set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"

if not exist "%ISCC%" (
  echo.
  echo ERROR: Inno Setup 6 was not found.
  pause
  exit /b 1
)

echo [3/3] Building TACTIX_Setup.exe...
"%ISCC%" "TACTIX_Setup_FIXED.iss"
if errorlevel 1 (
  echo.
  echo ERROR: Inno Setup build failed.
  pause
  exit /b 1
)

echo.
echo ==========================================
echo DONE
echo ==========================================
echo Installer:
echo %CD%\installer\TACTIX_Setup.exe
echo.
pause
