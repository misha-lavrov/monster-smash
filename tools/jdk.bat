@echo off
rem ----------------------------------------------------------------------
rem  Finds a JDK (we need javac). Sets variables JAVAC and JAVA.
rem  Search order:
rem    1) portable folder  jdk\   (copied from a USB stick - nothing to install)
rem    2) JAVA_HOME
rem    3) PATH
rem    4) JDK downloaded by IntelliJ  (%USERPROFILE%\.jdks)
rem    5) folders where JDK installers put it (Eclipse Adoptium, Java, Microsoft, Corretto, Zulu)
rem  No "setlocal" here on purpose: the variables must stay for the caller.
rem ----------------------------------------------------------------------
set "JAVAC="
set "JAVA="

if exist "%~dp0..\jdk\bin\javac.exe" goto portable
if not defined JAVA_HOME goto try_path
if exist "%JAVA_HOME%\bin\javac.exe" goto java_home

:try_path
where javac >nul 2>nul
if not errorlevel 1 goto on_path

for /d %%D in ("%USERPROFILE%\.jdks\*") do if exist "%%~D\bin\javac.exe" call :set_jdk "%%~D"
if defined JAVAC exit /b 0

for /d %%D in ("%ProgramFiles%\Eclipse Adoptium\jdk-*" "%ProgramFiles%\Java\jdk-*" "%ProgramFiles%\Microsoft\jdk-*" "%ProgramFiles%\Amazon Corretto\jdk*" "%ProgramFiles%\Zulu\zulu-*" "C:\Java\jdk*") do if exist "%%~D\bin\javac.exe" call :set_jdk "%%~D"
exit /b 0

:portable
call :set_jdk "%~dp0..\jdk"
exit /b 0

:java_home
call :set_jdk "%JAVA_HOME%"
exit /b 0

:on_path
set "JAVAC=javac"
set "JAVA=java"
exit /b 0

:set_jdk
for %%I in ("%~1") do set "JAVAC=%%~fI\bin\javac.exe"
for %%I in ("%~1") do set "JAVA=%%~fI\bin\java.exe"
exit /b 0
