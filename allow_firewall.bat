@echo off
echo ========================================================
echo  Allowing EduVerse Backend (Port 5083) in Firewall
echo ========================================================
echo.

netsh advfirewall firewall add rule name="EduVerse Backend 5083" dir=in action=allow protocol=TCP localport=5083

if %ERRORLEVEL% EQU 0 (
    echo.
    echo [SUCCESS] Inbound traffic on port 5083 is now allowed!
    echo Your phone can now connect over Wi-Fi to:
    echo http://172.32.182.21:5083/api
    echo.
) else (
    echo.
    echo [ERROR] Administrative privileges required.
    echo Please right-click "allow_firewall.bat" and choose "Run as administrator".
    echo.
)

pause
