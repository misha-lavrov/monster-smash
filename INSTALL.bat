@echo off
rem ======================================================================
rem  INSTALL.bat  -  one double-click to prepare a PC for the masterclass
rem
rem    * installs Git, JDK and IntelliJ IDEA from the installers folder
rem      next to the folder monster-smash (any name) - what is already installed is skipped
rem    * does NOT copy the game - it works right where this folder lies (for example on D:)
rem    * creates desktop shortcuts and checks the PC
rem
rem  Windows will ask for permission (UAC) - press "Yes".
rem  All the work is done by tools\install.ps1 (readable, with comments).
rem ======================================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "KIT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Raw -Encoding UTF8 -LiteralPath '%~dp0tools\install.ps1' | Invoke-Expression"
set "RC=%errorlevel%"
echo.
if not defined OIPZ_NOPAUSE pause
exit /b %RC%
