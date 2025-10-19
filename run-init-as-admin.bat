@echo off
echo ==========================================
echo Remote Lab Setup - Auto Run as Admin
echo ==========================================
echo.
echo Choose execution mode:
echo 1. Single run (check server once and exit)
echo 2. Background service (continuous polling)
echo 3. Background service with custom interval
echo.
set /p choice="Enter your choice (1-3): "

if "%choice%"=="1" goto single_run
if "%choice%"=="2" goto background_run
if "%choice%"=="3" goto custom_background
goto single_run

:single_run
echo Starting single execution mode...
powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File %~dp0init.ps1' -Verb RunAs"
goto end

:background_run
echo Starting background service mode (30 second intervals)...
powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File %~dp0init.ps1 -BackgroundMode' -Verb RunAs -WindowStyle Hidden"
goto end

:custom_background
set /p interval="Enter polling interval in seconds (default 30): "
if "%interval%"=="" set interval=30
echo Starting background service mode (%interval% second intervals)...
powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File %~dp0init.ps1 -BackgroundMode -PollInterval %interval%' -Verb RunAs -WindowStyle Hidden"
goto end

:end
echo.
echo Script execution initiated.
if "%choice%"=="2" (
    echo Background service is running. Check log file: C:\Windows\Temp\RemoteLabSetup.log
    echo To stop the service, open Task Manager and end the PowerShell process.
) else if "%choice%"=="3" (
    echo Background service is running. Check log file: C:\Windows\Temp\RemoteLabSetup.log
    echo To stop the service, open Task Manager and end the PowerShell process.
) else (
    echo Check the PowerShell window for progress.
)
echo.
pause
