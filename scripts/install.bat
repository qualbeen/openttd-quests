@echo off
setlocal

set "SCRIPT_DIR=%~dp0.."
set "GS_DIR=%SCRIPT_DIR%\gamescript"
set "DEST=%USERPROFILE%\Documents\OpenTTD\game\openttd-quests"

if not exist "%GS_DIR%" (
    echo Error: gamescript directory not found at %GS_DIR%
    exit /b 1
)

if exist "%DEST%" rmdir /s /q "%DEST%"
mkdir "%DEST%"
xcopy /s /e /q "%GS_DIR%\*" "%DEST%\"

echo Installed to %DEST%
echo Start OpenTTD → New Game → AI/Game Script Settings → select 'OpenTTD Quests'
