@echo off
rem ----------------------------------------------------------------------
rem  Usage: wait-server.bat PORT [page | now]
rem
rem    (nothing)  waits up to 10 seconds until the game server answers
rem    page       the same, and then waits up to 1.5 s to see whether the game page
rem               is open in a browser (the page asks the server every half second)
rem    now        one quick check, no waiting
rem
rem  Exit codes:  0 = the server answers (with "page": and a game page is open)
rem               3 = the server answers, but no game page is open  (only with "page")
rem               1 = no answer
rem  If PowerShell is not available we cannot check - then we say "OK".
rem ----------------------------------------------------------------------
powershell -NoProfile -Command "$p=%~1; $mode='%~2'; if($mode -eq 'now'){ try{ Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 ('http://127.0.0.1:'+$p+'/api/version')|Out-Null; exit 0 }catch{ exit 1 } }; $up=$false; for($i=0;$i -lt 40;$i++){ try{ Invoke-WebRequest -UseBasicParsing -TimeoutSec 1 ('http://127.0.0.1:'+$p+'/api/version')|Out-Null; $up=$true; break }catch{ Start-Sleep -Milliseconds 250 } }; if(-not $up){ exit 1 }; if($mode -ne 'page'){ exit 0 }; for($i=0;$i -lt 10;$i++){ try{ if((Invoke-RestMethod -TimeoutSec 1 ('http://127.0.0.1:'+$p+'/api/pages')).open){ exit 0 } }catch{}; Start-Sleep -Milliseconds 150 }; exit 3" >nul 2>nul
if errorlevel 9009 exit /b 0
exit /b %errorlevel%
