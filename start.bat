@echo off
rem ======================================================================
rem  start.bat  -  build the program and (re)start the game server
rem
rem  Double-click = restart with the NEW code. This window closes by itself,
rem  the server keeps running in a minimized window (title OIPZ-SERVER-8765).
rem
rem    start.bat show   run the server in THIS window (you can see its log)
rem    start.bat open   also open the browser when the server is ready
rem ======================================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if not defined PORT set "PORT=8765"
set "SHOW="
set "OPEN="
if /i "%~1"=="show" set "SHOW=1"
if /i "%~1"=="open" set "OPEN=1"
if /i "%~2"=="show" set "SHOW=1"
if /i "%~2"=="open" set "OPEN=1"
if not exist out mkdir out

echo.
echo  =====================================================
echo    MONSTER SMASH  -  starting...
echo  =====================================================

call "%~dp0tools\jdk.bat"
if not defined JAVAC goto no_jdk

call "%~dp0tools\stop.bat"

echo  [1/3] Building the program...
"%JAVAC%" -J-Dfile.encoding=UTF-8 -J-Dstdout.encoding=UTF-8 -J-Dstderr.encoding=UTF-8 -encoding UTF-8 -d out src\Main.java > out\build.log 2>&1
if errorlevel 1 goto compile_error

set "JOPTS=-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8 -Xmx128m -XX:+UseSerialGC"

if defined SHOW goto run_here

echo  [2/3] Starting the server...
start "OIPZ-SERVER-%PORT%" /min cmd /c ""%JAVA%" %JOPTS% -cp out Main %PORT% > out\server.log 2>&1"

echo  [3/3] Waiting for the server to answer...
call "%~dp0tools\wait-server.bat" %PORT%
if errorlevel 1 goto server_failed

echo.
echo  READY!   http://localhost:%PORT%
if defined OPEN start "" "http://localhost:%PORT%"
exit /b 0

:run_here
echo  [2/3] Running the server in this window. Close the window to stop it.
echo.
"%JAVA%" %JOPTS% -cp out Main %PORT%
echo.
echo  Server stopped.
pause
exit /b 0

:no_jdk
echo.
echo  ERROR: JDK not found.
call "%~dp0tools\msgbox.bat" "tools\text\no-jdk.txt"
exit /b 1

:compile_error
echo.
echo  ERROR: there is a mistake in the code - see the message window.
copy /b "tools\text\compile-error.txt" + "out\build.log" "out\msg.txt" >nul
call "%~dp0tools\msgbox.bat" "out\msg.txt"
exit /b 1

:server_failed
echo.
echo  ERROR: the server did not start - see the message window.
copy /b "tools\text\server-failed.txt" + "out\server.log" "out\msg.txt" >nul
call "%~dp0tools\msgbox.bat" "out\msg.txt"
exit /b 1
