@echo off
rem ======================================================================
rem  stop.bat  -  stop the game server
rem ======================================================================
chcp 65001 >nul
cd /d "%~dp0"
if not defined PORT set "PORT=8765"
call "%~dp0tools\stop.bat"
echo.
echo  Server stopped (if it was running).
ping -n 3 127.0.0.1 >nul
exit /b 0
