@echo off
cd /d "%~dp0"

echo Starting EduVerse Backend...
start "EduVerse Backend" cmd /k "cd /d "%~dp0Backend" && dotnet run"

echo Starting EduVerse Frontend...
start "EduVerse Frontend" cmd /k "cd /d "%~dp0frontend" && flutter run -d web-server --web-port=50454"

echo Both services have been launched in new windows!
echo Backend is running on port 5083
echo Frontend is running on port 50454

