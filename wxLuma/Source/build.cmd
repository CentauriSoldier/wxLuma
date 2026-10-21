@echo off
setlocal
if "%~2"=="" (
    echo Run from an x64 Visual Studio Developer Command Prompt:
    echo build.cmd "Lua 5.4 include folder" "lua54.lib path"
    exit /b 1
)
pushd "%~dp0"
cl /nologo /W4 /WX /O2 /MT /I"%~1" test.c "%~2" /Fe:"..\test.exe" /link /SUBSYSTEM:WINDOWS /DELAYLOAD:lua54.dll delayimp.lib user32.lib shell32.lib
set "result=%errorlevel%"
popd
exit /b %result%