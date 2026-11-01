<#
.SYNOPSIS
    Installs (or removes) the MonCastle console as a Windows service so collectors keep running without a signed-in user.
.DESCRIPTION
    Uses a scheduled task that starts at boot under a dedicated service account (recommended: a gMSA with the
    rights your collectors need). No third-party service wrapper is required.
.EXAMPLE
    .\Install-MonCastleService.ps1 -Account 'CORP\svc-moncastle$'
.EXAMPLE
    .\Install-MonCastleService.ps1 -Remove
#>
#Requires -RunAsAdministrator
[CmdletBinding(SupportsShouldProcess)]
param([string]$Account = 'NT AUTHORITY\SYSTEM', [switch]$Remove, [string]$TaskName = 'RoboMate MonCastle Console')
$root = Split-Path $PSScriptRoot -Parent
# source tree (server\index.js) or user package (moncastle.js + app.mcpak, its own runtime\node.exe)
$entry = if (Test-Path (Join-Path $root 'moncastle.js')) { 'moncastle.js' } else { 'server/index.js' }
$nodeExe = if (Test-Path (Join-Path $root 'runtime\node.exe')) { Join-Path $root 'runtime\node.exe' } else { 'node' }
if ($Remove) {
    if ($PSCmdlet.ShouldProcess($TaskName, 'Unregister')) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Write-Host "Removed $TaskName" }
    return
}
$node = if ($nodeExe -ne 'node') { $nodeExe } else { (Get-Command node -ErrorAction Stop).Source }
$action = New-ScheduledTaskAction -Execute $node -Argument $entry -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
$principal = if ($Account -like '*$') { New-ScheduledTaskPrincipal -UserId $Account -LogonType Password -RunLevel Highest } else { New-ScheduledTaskPrincipal -UserId $Account -LogonType ServiceAccount -RunLevel Highest }
if ($PSCmdlet.ShouldProcess($TaskName, "Register as $Account")) {
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Installed and started '$TaskName' as $Account. Data folder: $root\data (restrict it to that account)."
}
