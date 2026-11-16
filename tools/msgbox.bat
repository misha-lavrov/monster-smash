@echo off
rem ----------------------------------------------------------------------
rem  Usage: msgbox.bat <text-file>
rem  Shows a message window. First line of the file = window title,
rem  the rest = the message (UTF-8). Shows at most 26 lines.
rem  If the variable OIPZ_NOGUI is set, prints to the console instead (for tests).
rem ----------------------------------------------------------------------
if defined OIPZ_NOGUI goto console
powershell -NoProfile -Command "$t=@(Get-Content -Encoding UTF8 -LiteralPath '%~1'); Add-Type -AssemblyName System.Windows.Forms; $body=(($t | Select-Object -Skip 1 -First 26) -join [Environment]::NewLine); [void][System.Windows.Forms.MessageBox]::Show($body,$t[0],'OK','Warning')" >nul 2>nul
if errorlevel 1 goto fallback
exit /b 0

:fallback
type "%~1"
echo.
pause
exit /b 0

:console
type "%~1"
exit /b 0
