@echo off
rem Starts MonCastle with generated demo data (no licence, no PowerShell collection needed).
where pwsh >nul 2>nul && (pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-MonCastle.ps1" -Demo) || (powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-MonCastle.ps1" -Demo)
if errorlevel 1 pause
