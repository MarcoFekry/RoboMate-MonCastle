@echo off
rem RoboMate MonCastle launcher. Double-click to start the console and open it in the browser.
where pwsh >nul 2>nul && (pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-MonCastle.ps1" %*) || (powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-MonCastle.ps1" %*)
if errorlevel 1 pause
