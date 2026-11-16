@echo off
rem ----------------------------------------------------------------------
rem  Stops the game server if it is running. Safe to call when nothing runs.
rem  Uses variable PORT (default 8765).
rem ----------------------------------------------------------------------
if not defined PORT set "PORT=8765"
taskkill /F /T /FI "WINDOWTITLE eq OIPZ-SERVER-%PORT%" >nul 2>nul
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }" >nul 2>nul
exit /b 0
