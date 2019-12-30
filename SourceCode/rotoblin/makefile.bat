@echo off
setlocal
pushd %~dp0
REM Makefile for building only the rotoblin.smx file.  
REM If you need to create a release, run the create_release script instead.

set "PLUGIN_SRC_DIR=src\scripting"
set "PLUGIN_NAME=rotoblin.main"
set "BUILD_DEST_DIR=build"
set "RELEASE_NAME=build\rotoblin"
set "SPCOMP=bin\sourcepawn\spcomp.exe"

echo --------------------------------------------
echo Building %PLUGIN_NAME%.sp ...
echo --------------------------------------------

if not exist %BUILD_DEST_DIR% (
mkdir %BUILD_DEST_DIR%
) 

"%SPCOMP%" -D%PLUGIN_SRC_DIR% "%PLUGIN_NAME%.sp"
move /Y "%PLUGIN_SRC_DIR%\%PLUGIN_NAME%.smx" "%RELEASE_NAME%.smx" 

echo --------------------------------------------
echo Built %PLUGIN_NAME%.sp as %RELEASE_NAME%.smx
echo --------------------------------------------

pause
popd
endlocal