@echo off
rem ----------------------------------------------------------------------
rem  Usage: wait-server.bat PORT
rem  Waits up to 10 seconds until the game server answers.
rem  Exit code 0 = server answers.  1 = no answer.
rem  (If PowerShell is not available we cannot check - then we say "OK".)
rem ----------------------------------------------------------------------
powershell -NoProfile -Command "for($i=0;$i -lt 40;$i++){try{Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 http://127.0.0.1:%~1/api/version | Out-Null; exit 0}catch{Start-Sleep -Milliseconds 250}}; exit 1" >nul 2>nul
if errorlevel 9009 exit /b 0
exit /b %errorlevel%
