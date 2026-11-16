@echo off
rem ======================================================================
rem  reset.bat  -  return the game to its ORIGINAL code and restart it
rem
rem    reset.bat          reset + start the server      (the "red button")
rem    reset.bat norun    reset only  (use it together with IntelliJ)
rem
rem  What is reset: ONLY the folders src and web.
rem  How: git (git checkout + git clean).  No git?  Then the copy in _original.
rem  Safety: on a PC without the file STATION it asks before erasing anything.
rem ======================================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if not defined PORT set "PORT=8765"
if not exist out mkdir out

if exist "%~dp0STATION" goto go
echo.
echo  WARNING: this is not a "station" PC (the file STATION was not found).
echo  All changes in the folders src and web will be ERASED for good!
choice /c YN /n /m "  Continue? (Y = yes, N = no): "
if errorlevel 2 exit /b 1

:go
echo.
echo  Resetting the game to the original code...
call "%~dp0tools\stop.bat"

where git >nul 2>nul
if errorlevel 1 goto from_copy
if not exist "%~dp0.git" goto from_copy

git -c safe.directory=* checkout HEAD -- src web
if errorlevel 1 goto from_copy
git -c safe.directory=* clean -fdq -- src web
goto restored

:from_copy
if not exist "%~dp0_original\src\Main.java" goto cannot_reset
robocopy "%~dp0_original\src" "%~dp0src" /MIR /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto cannot_reset
robocopy "%~dp0_original\web" "%~dp0web" /MIR /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto cannot_reset

:restored
echo  Done - the code is original again.
if /i "%~1"=="norun" exit /b 0
call "%~dp0start.bat"
exit /b 0

:cannot_reset
echo.
echo  ERROR: cannot reset (no git repository and no _original copy).
call "%~dp0tools\msgbox.bat" "tools\text\cannot-reset.txt"
exit /b 1
