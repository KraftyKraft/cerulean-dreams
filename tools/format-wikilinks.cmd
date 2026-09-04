@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "BASH_EXE="

where bash.exe >nul 2>nul
if %ERRORLEVEL%==0 (
    set "BASH_EXE=bash.exe"
) else if exist "%ProgramFiles%\Git\bin\bash.exe" (
    set "BASH_EXE=%ProgramFiles%\Git\bin\bash.exe"
) else if exist "%ProgramFiles(x86)%\Git\bin\bash.exe" (
    set "BASH_EXE=%ProgramFiles(x86)%\Git\bin\bash.exe"
)

if not defined BASH_EXE (
    echo Could not find bash. Install Git for Windows: https://gitforwindows.org/
    exit /b 1
)

"%BASH_EXE%" "%SCRIPT_DIR%format-wikilinks.sh" %*
exit /b %ERRORLEVEL%
