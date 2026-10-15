@echo off
echo ============================================
echo  EduVerse - ADB Port Forwarding Setup
echo ============================================
echo.

REM Find ADB
set ADB="%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"

echo Checking connected devices...
%ADB% devices
echo.

echo Setting up port forwarding (phone -> PC backend)...
%ADB% reverse tcp:5083 tcp:5083

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] Success! Port 5083 is now forwarded.
    echo.
    echo  In the Android app:
    echo  - Tap "Server URL" on the login screen
    echo  - Select the "USB" preset  (localhost:5083)
    echo  - Tap "Test Connection" to verify
    echo  - Sign in!
    echo.
) else (
    echo.
    echo [ERROR] ADB failed. Make sure:
    echo   1. Phone is connected via USB cable
    echo   2. USB Debugging is ON (Settings > Developer Options)
    echo   3. You accepted the "Allow USB Debugging?" dialog on your phone
    echo.
)

echo ============================================
echo  PC Ethernet IP (USB adapter): 192.168.100.107
echo  Backend API: http://192.168.100.107:5083/api
echo.
echo  NOTE: Your phone is on a different subnet (172.32.x.x).
echo  USB ADB reverse (above) is the RECOMMENDED connection method.
echo  If using Wi-Fi, connect phone to the SAME network as the PC.
echo ============================================
echo.
pause
