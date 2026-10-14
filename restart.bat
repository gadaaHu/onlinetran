@echo off
title EduVerse - Restart Server
color 0A

echo ============================================
echo      EduVerse - Restarting Application
echo ============================================
echo.

:: Kill backend on port 5083
echo [1/4] Stopping backend (port 5083)...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":5083 "') do taskkill /f /pid %%a >nul 2>&1
echo       Done.

:: Kill frontend on port 8081
echo [2/4] Stopping frontend (port 8081)...
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":8081 "') do taskkill /f /pid %%a >nul 2>&1
taskkill /f /im dart.exe >nul 2>&1
echo       Done.

timeout /t 2 /nobreak >nul

:: Start backend
echo [3/4] Starting Backend...
start "EduVerse Backend" cmd /k "cd /d "%~dp0Backend" && dotnet run"
echo       Waiting 6s for backend to initialize...
timeout /t 6 /nobreak >nul

:: Serve pre-built web app with Python HTTP server
echo [4/4] Starting Frontend (serving build\web on port 8081)...
start "EduVerse Frontend" cmd /k "cd /d "%~dp0frontend\build\web" && python -m http.server 8081"

:: Open browser automatically after 2 seconds
timeout /t 2 /nobreak >nul
start "" "http://localhost:8081"

echo.
echo ============================================
echo  Services launched in separate windows!
echo.
echo  Backend  : http://localhost:5083
echo  Frontend : http://localhost:8081  (auto-opened)
echo ============================================
echo.
pause
