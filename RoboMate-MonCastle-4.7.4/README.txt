RoboMate MonCastle 4.7.4

Start:     RoboMate.MonCastle.Launcher.exe (or launcher\Start-MonCastle.cmd)
Install:   MonCastle-Setup.exe checks and installs the prerequisites (PowerShell 7, RSAT modules, firewall rule, service).
Service:   launcher\Install-MonCastleService.ps1 -Account CORP\svc-moncastle$
Override:  launcher\Set-MonCastleAdminPassword.ps1
Join:      launcher\Join-MonCastleServer.ps1 (remote MonCastle server)

The application is in app.mcpak (encrypted, integrity-checked) and runs from memory. Your data is kept
encrypted in the data folder. Open the console at http://robomatemoncastle:5050 after starting.
