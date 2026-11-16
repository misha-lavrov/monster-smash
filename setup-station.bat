@echo off
rem ======================================================================
rem  setup-station.bat  -  one-time setup of a PC as a masterclass STATION
rem    1) creates the STATION marker (reset.bat then works without questions)
rem    2) saves a backup copy _original when git is not available
rem    3) creates 3 shortcuts on the desktop (start / reset / stop)
rem    4) runs check.bat
rem  Run it ONCE on a fresh (unchanged) copy of the project.
rem ======================================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0"

echo.
echo  =====================================================
echo    Setting up this PC as a masterclass STATION
echo  =====================================================
echo.

type nul > STATION
echo  [1/4] STATION marker created

set "NEEDCOPY="
where git >nul 2>nul
if errorlevel 1 set "NEEDCOPY=1"
if not exist "%~dp0.git" set "NEEDCOPY=1"
if defined NEEDCOPY goto copy_original
echo  [2/4] git is available - a backup copy is not needed
goto shortcuts

:copy_original
if exist "%~dp0_original\src\Main.java" goto have_copy
robocopy "%~dp0src" "%~dp0_original\src" /MIR /NFL /NDL /NJH /NJS /NP >nul
robocopy "%~dp0web" "%~dp0_original\web" /MIR /NFL /NDL /NJH /NJS /NP >nul
echo  [2/4] git is not available - saved the backup copy in _original
goto shortcuts

:have_copy
echo  [2/4] the backup copy _original already exists

:shortcuts
powershell -NoProfile -Command "Get-Content -Raw -Encoding UTF8 -LiteralPath 'tools\shortcuts.ps1' | Invoke-Expression" >nul 2>nul
if errorlevel 1 goto shortcuts_failed
echo  [3/4] desktop shortcuts created
goto run_check

:shortcuts_failed
echo  [3/4] could not create shortcuts - make them by hand (right click - Send to - Desktop)

:run_check
echo  [4/4] running the PC check...
set "NOPAUSE=1"
call "%~dp0check.bat"
echo.
pause
exit /b 0
