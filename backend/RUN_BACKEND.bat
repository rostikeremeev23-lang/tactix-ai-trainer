@echo off
setlocal
cd /d "%~dp0"
if not exist "server.py" (
  echo [ERROR] server.py not found.
  pause
  exit /b 1
)
where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Python not found in PATH.
  pause
  exit /b 1
)
echo === TACTIX backend ===
python -m uvicorn server:app --host 0.0.0.0 --port 8000
pause
