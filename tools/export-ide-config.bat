@echo off
rem ======================================================================
rem  export-ide-config.bat  -  save the IntelliJ settings of THIS PC into ide-config.zip
rem  (put the file into the "installers" folder; INSTALL.bat applies it on the other PCs)
rem  Run it on a CLEAN college PC after you set IntelliJ up once by hand.
rem ======================================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0.."
set "KIT_DIR=%CD%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Raw -Encoding UTF8 -LiteralPath '%~dp0export-ide-config.ps1' | Invoke-Expression"
echo.
if not defined OIPZ_NOPAUSE pause
exit /b %errorlevel%
