@echo off
rem ======================================================================
rem  slides.bat  -  open the presentation (web\slides.html) in Chrome.
rem  It also starts the game server if it is not running, so the live
rem  buttons on the slides ("ask the real server") work.
rem  In the browser: F11 = full screen, arrows = next/previous slide.
rem ======================================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if not defined PORT set "PORT=8765"

call "%~dp0tools\wait-server.bat" %PORT% now
if not errorlevel 1 goto open_slides
call "%~dp0start.bat" noopen

:open_slides
call "%~dp0tools\open-browser.bat" "http://localhost:%PORT%/slides.html"
exit /b 0
