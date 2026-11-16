@echo off
rem ----------------------------------------------------------------------
rem  Usage: open-browser.bat URL
rem  Opens the URL in Google Chrome when it is installed, otherwise in the default browser.
rem
rem  Test hooks (not needed in normal life):
rem    OIPZ_NOBROWSER=1       only print the URL, do not open anything
rem    OIPZ_BROWSER_FLAGS=..  extra Chrome flags, e.g. --user-data-dir=C:\temp\profile
rem ----------------------------------------------------------------------
if defined OIPZ_NOBROWSER (
  echo  [test] would open %~1
  exit /b 0
)

set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"
if defined CHROME goto chrome

start "" "%~1"
exit /b 0

:chrome
start "" "%CHROME%" %OIPZ_BROWSER_FLAGS% "%~1"
exit /b 0
