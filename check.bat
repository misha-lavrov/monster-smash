@echo off
rem ======================================================================
rem  check.bat  -  is THIS PC ready for the masterclass?  (about 15 seconds)
rem  It checks: JDK, git, project files, compile, and starts the server
rem  for a moment on a separate port (8799) to make sure it answers.
rem ======================================================================
chcp 65001 >nul
setlocal
cd /d "%~dp0"
set "PORT=8799"
set "FAILS=0"
set "JV=0"
if not exist out mkdir out

echo.
echo  =====================================================
echo    PC CHECK  -  masterclass "Monster Smash"
echo  =====================================================
echo.

rem ---- 1. JDK ----------------------------------------------------------
call "%~dp0tools\jdk.bat"
if not defined JAVAC goto jdk_missing
"%JAVAC%" -version > out\ver.txt 2>&1
set "VERLINE="
set /p VERLINE=<out\ver.txt
for /f "tokens=2 delims=. " %%v in ("%VERLINE%") do set "JV=%%v"
if %JV% LSS 17 goto jdk_old
echo  [ OK ] JDK: %VERLINE%
goto git_check

:jdk_missing
echo  [FAIL] JDK not found - need Java 17 or newer
set /a FAILS+=1
goto git_check

:jdk_old
echo  [FAIL] JDK is too old: %VERLINE%  - need Java 17 or newer
set /a FAILS+=1
set "JAVAC="

rem ---- 2. git ----------------------------------------------------------
:git_check
where git >nul 2>nul
if errorlevel 1 goto git_missing
set "GITV=git"
for /f "delims=" %%g in ('git --version') do set "GITV=%%g"
echo  [ OK ] %GITV%
goto idea_check

:git_missing
echo  [WARN] git not found - fine only if the folder was copied by USB (reset then uses _original, and nothing is kept in git stash)

rem ---- 2b. IntelliJ IDEA (the kids work in it) --------------------------
:idea_check
set "IDEA="
for /d %%D in ("%ProgramFiles%\JetBrains\IntelliJ IDEA*" "%LocalAppData%\Programs\IntelliJ IDEA*") do if exist "%%~D\bin\idea64.exe" set "IDEA=%%~D"
if defined IDEA goto idea_ok
echo  [WARN] IntelliJ IDEA not found - stations are meant to use it (without it: any editor + the start.bat shortcut)
goto files_check

:idea_ok
echo  [ OK ] IntelliJ IDEA: %IDEA%

rem ---- 3. project files ------------------------------------------------
:files_check
set "MISSING="
if not exist "src\Main.java"  set "MISSING=src\Main.java"
if not exist "web\index.html" set "MISSING=web\index.html"
if not exist "web\app.js"     set "MISSING=web\app.js"
if not exist "web\style.css"  set "MISSING=web\style.css"
if defined MISSING goto files_bad
echo  [ OK ] project files are in place
goto build_check

:files_bad
echo  [FAIL] file is missing: %MISSING%
set /a FAILS+=1
goto info_checks

rem ---- 4. compile ------------------------------------------------------
:build_check
if not defined JAVAC goto info_checks
"%JAVAC%" -J-Dfile.encoding=UTF-8 -J-Dstdout.encoding=UTF-8 -J-Dstderr.encoding=UTF-8 -encoding UTF-8 -d out src\Main.java > out\build.log 2>&1
if errorlevel 1 goto build_bad
echo  [ OK ] the program compiles
goto run_check

:build_bad
echo  [FAIL] compile error - see out\build.log
set /a FAILS+=1
goto info_checks

rem ---- 5. start the server for a moment and ask it ----------------------
:run_check
set "JOPTS=-Dfile.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8 -Xmx128m -XX:+UseSerialGC"
start "OIPZ-CHECK" /min cmd /c ""%JAVA%" %JOPTS% -cp out Main %PORT% > out\check.log 2>&1"
call "%~dp0tools\wait-server.bat" %PORT%
if errorlevel 1 goto run_bad
powershell -NoProfile -Command "try{ $r=Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://127.0.0.1:%PORT%/api/state; if($r.Content -like '*monster*'){exit 0}else{exit 1} }catch{exit 1}" >nul 2>nul
if errorlevel 1 goto run_bad
echo  [ OK ] the game server starts and answers
call :kill_check
goto info_checks

:run_bad
echo  [FAIL] the server did not answer - see out\check.log
set /a FAILS+=1
call :kill_check

rem ---- 6. information (never a failure) --------------------------------
:info_checks
echo.
set "RAMGB="
for /f %%m in ('powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)" 2^>nul') do set "RAMGB=%%m"
if defined RAMGB echo  [INFO] RAM: %RAMGB% GB  - IntelliJ is comfortable from 8 GB, otherwise use an editor + start.bat

set "PORT=8765"
powershell -NoProfile -Command "if(Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue){exit 1}else{exit 0}" >nul 2>nul
if errorlevel 1 goto port_busy
echo  [ OK ] port 8765 is free
goto station_info

:port_busy
echo  [INFO] port 8765 is in use right now - the game is probably running, that is fine

:station_info
if exist "STATION" goto is_station
echo  [INFO] no STATION file - this is a developer PC, reset.bat will ask before erasing
goto summary

:is_station
echo  [ OK ] STATION marker is present - reset.bat works without questions

rem ---- result ----------------------------------------------------------
:summary
echo.
if %FAILS%==0 goto all_ok
type "tools\text\check-fail.txt"
goto done

:all_ok
type "tools\text\check-ok.txt"

:done
echo.
if not defined NOPAUSE pause
exit /b %FAILS%

:kill_check
taskkill /F /T /FI "WINDOWTITLE eq OIPZ-CHECK" >nul 2>nul
powershell -NoProfile -Command "Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }" >nul 2>nul
exit /b 0
