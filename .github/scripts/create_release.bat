
rem The new package will be saved here
set PACK_DIR=%CD%\updater-release

rem Prepare target dir
mkdir %PACK_DIR%

rem Read version number
for /f tokens^=2delims^=^" %%a in ('findstr "MajorVersionNr" src\updater.lpi') do (set UP_MAJOR=%%a)
for /f tokens^=2delims^=^" %%a in ('findstr "MinorVersionNr" src\updater.lpi') do (set UP_MINOR=%%a)
set UP_VER=%UP_MAJOR%.%UP_MINOR%

rem Set processor architecture
set CPU_TARGET=i386
set OS_TARGET=win32

call :updater

rem Set processor architecture
set CPU_TARGET=x86_64
set OS_TARGET=win64

call :updater

GOTO:EOF

:updater
  rem Build updater
  lazbuild.exe --os=%OS_TARGET% --cpu=%CPU_TARGET% --bm=release src\updater.lpi

  rem Create *.7z archive
  "%ProgramFiles%\7-Zip\7z.exe" a -mx9 %PACK_DIR%\updater-%UP_VER%.%CPU_TARGET%-%OS_TARGET%.zip updater.exe

  rem Clean
  rm -rf lib
  del /Q *.exe

GOTO:EOF
