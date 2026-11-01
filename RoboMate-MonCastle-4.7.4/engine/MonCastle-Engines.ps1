<#
.SYNOPSIS
    Manages the MonCastle monitoring engines: one Windows scheduled task per collector, under \RoboMate\MonCastle\Engines\.
    Used by the launcher and the console.
.DESCRIPTION
    Actions (Id is a collector id such as mon.compute, or All):
      List                     engines with task state, interval, last and next run, and the last result
      Install   [-Id] [-User]  creates or updates the engine tasks (default: all collectors, run as SYSTEM).
                               For another account, put its password in the MC_ENGINE_PASSWORD environment variable.
      Uninstall [-Id]          removes engine tasks
      Enable | Disable         enables or disables engines (Disable also stops a running engine)
      Start | Stop | Restart   runs an engine now, stops it, or stops and starts it
      SetInterval -Every 15m   changes how often an engine runs (s, m, h or d)
    Output: one JSON document between ##MC-ENGINES-BEGIN## and ##MC-ENGINES-END##.
    Changing tasks needs an elevated session.
.EXAMPLE
    pwsh -File engine\MonCastle-Engines.ps1 -Action Install
.EXAMPLE
    pwsh -File engine\MonCastle-Engines.ps1 -Action Disable -Id mon.vmware
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet('List', 'Install', 'Uninstall', 'Enable', 'Disable', 'Start', 'Stop', 'Restart', 'SetInterval')][string]$Action,
    [ValidatePattern('^(All|[\w.-]+)$')][string]$Id = 'All',
    [string]$Every,
    [string]$User
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Engine.Common.ps1')

function Out-MC($obj) {
    '##MC-ENGINES-BEGIN##'
    $obj | ConvertTo-Json -Depth 6 -Compress
    '##MC-ENGINES-END##'
}

function Get-EngineTasks {
    @(Get-ScheduledTask -TaskPath $MCTaskPath -ErrorAction SilentlyContinue)
}

function Get-Interval($task) {
    $r = @($task.Triggers)[0].Repetition.Interval
    if (-not $r) { return $null }
    $t = [Xml.XmlConvert]::ToTimeSpan($r)
    if ($t.TotalDays -ge 1 -and $t.TotalDays % 1 -eq 0) { return '{0}d' -f $t.TotalDays }
    if ($t.TotalHours -ge 1 -and $t.TotalHours % 1 -eq 0) { return '{0}h' -f $t.TotalHours }
    '{0}m' -f [int]$t.TotalMinutes
}

function Get-EngineList($paths) {
    $collectors = Get-MCCollectors $paths
    $tasks = @{}
    foreach ($t in Get-EngineTasks) { $tasks[$t.TaskName] = $t }
    foreach ($c in $collectors) {
        $t = if ($tasks[$MCTaskPrefix + $c.id]) { $tasks[$MCTaskPrefix + $c.id] } else { $tasks[$MCLegacyPrefix + $c.id] }
        $st = $null
        $sf = Join-Path $paths.Engines "$($c.id).json"
        if (Test-Path $sf) { try { $st = Get-Content $sf -Raw | ConvertFrom-Json } catch { } }
        $info = if ($t) { $t | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue }
        [ordered]@{
            id = $c.id; title = $c.title; category = $c.category; resource = $c.resource; schedule = $c.schedule
            installed = [bool]$t
            state = if ($t) { [string]$t.State } else { 'NotInstalled' }
            every = if ($t) { Get-Interval $t } else { $c.schedule }
            runAs = if ($t) { $t.Principal.UserId } else { $null }
            lastRun = if ($info -and $info.LastRunTime -and $info.LastRunTime.Year -gt 2000) { $info.LastRunTime.ToUniversalTime().ToString('o') } elseif ($st) { $st.lastRun } else { $null }
            nextRun = if ($info -and $info.NextRunTime) { $info.NextRunTime.ToUniversalTime().ToString('o') } else { $null }
            taskResult = if ($info) { $info.LastTaskResult } else { $null }
            lastStatus = if ($st) { $st.lastStatus } else { $null }
            message = if ($st) { $st.message } else { $null }
            count = if ($st) { $st.count } else { $null }
            durationSec = if ($st) { $st.durationSec } else { $null }
        }
    }
}

function Register-Engine($paths, $c, [string]$every, $existing) {
    $span = ConvertTo-MCInterval $every
    if (-not $span) { $span = [TimeSpan]::FromHours(1) }
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) { $pwsh = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe' }
    if (-not (Test-Path $pwsh)) { throw 'PowerShell 7 (pwsh.exe) is required for the engines. Install it from https://aka.ms/powershell.' }
    $runner = Join-Path $PSScriptRoot 'Invoke-MCEngine.ps1'
    $action = New-ScheduledTaskAction -Execute $pwsh -Argument ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "{0}" -Id {1}' -f $runner, $c.id) -WorkingDirectory $paths.Root
    # stagger first runs so the engines do not all start together
    $first = (Get-Date).AddMinutes(1 + ((([int[]][char[]]$c.id) | Measure-Object -Sum).Sum % 10))
    $trigger = New-ScheduledTaskTrigger -Once -At $first -RepetitionInterval $span
    $limit = if ($span.TotalMinutes -lt 60) { $span } else { [TimeSpan]::FromHours(1) }
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit $limit
    $reg = @{ TaskPath = $MCTaskPath; TaskName = $MCTaskPrefix + $c.id; Description = "MonCastle engine: $($c.title)"; Action = $action; Trigger = $trigger; Settings = $settings; Force = $true }
    $account = if ($User) { $User } elseif ($existing -and $existing.Principal.UserId -and $existing.Principal.UserId -ne 'SYSTEM') { $existing.Principal.UserId } else { $null }
    if ($account -and $env:MC_ENGINE_PASSWORD) { $reg.User = $account; $reg.Password = $env:MC_ENGINE_PASSWORD; $reg.RunLevel = 'Highest' }
    elseif ($account -and -not $User) { $reg.Principal = $existing.Principal }
    elseif ($account) { throw "Set MC_ENGINE_PASSWORD to the password of $account." }
    else { $reg.Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest }
    $task = Register-ScheduledTask @reg
    if ($existing -and $existing.State -eq 'Disabled') { $task | Disable-ScheduledTask | Out-Null }
}

try {
    $paths = Get-MCEnginePaths
    $tasks = Get-EngineTasks
    $pick = {
        param($list)
        if ($Id -eq 'All') { $list } else { @($list | Where-Object { (Get-MCEngineId $_.TaskName) -eq $Id }) }
    }
    $done = @()
    switch ($Action) {
        'List' { }
        'Install' {
            $collectors = Get-MCCollectors $paths
            if ($Id -ne 'All') { $collectors = @($collectors | Where-Object { $_.id -eq $Id }); if (-not $collectors) { throw "No collector $Id in manifest.json." } }
            foreach ($c in $collectors) {
                $existing = $tasks | Where-Object { $_.TaskName -eq ($MCTaskPrefix + $c.id) } | Select-Object -First 1
                $legacy = $tasks | Where-Object { $_.TaskName -eq ($MCLegacyPrefix + $c.id) } | Select-Object -First 1
                if (-not $existing) { $existing = $legacy }
                $every = if ($existing) { Get-Interval $existing } else { $c.schedule }
                Register-Engine $paths $c $every $existing
                if ($legacy) { $legacy | Stop-ScheduledTask -ErrorAction SilentlyContinue; $legacy | Unregister-ScheduledTask -Confirm:$false }
                $done += $c.id
            }
            # engines whose collector left the manifest are removed
            if ($Id -eq 'All') {
                $ids = $collectors.id
                foreach ($t in Get-EngineTasks) { if ($ids -notcontains (Get-MCEngineId $t.TaskName)) { $t | Unregister-ScheduledTask -Confirm:$false } }
            }
        }
        'Uninstall' {
            foreach ($t in (& $pick $tasks)) { $t | Stop-ScheduledTask -ErrorAction SilentlyContinue; $t | Unregister-ScheduledTask -Confirm:$false; $done += $t.TaskName }
            if (-not (Get-EngineTasks)) {
                try {
                    $svc = New-Object -ComObject Schedule.Service; $svc.Connect()
                    $svc.GetFolder('\RoboMate\MonCastle').DeleteFolder('Engines', 0)
                    $svc.GetFolder('\RoboMate').DeleteFolder('MonCastle', 0)
                    if (-not @($svc.GetFolder('\RoboMate').GetFolders(0)).Count -and -not @($svc.GetFolder('\RoboMate').GetTasks(1)).Count) { $svc.GetFolder('\').DeleteFolder('RoboMate', 0) }
                } catch { }
            }
        }
        'Enable' { foreach ($t in (& $pick $tasks)) { $t | Enable-ScheduledTask | Out-Null; $done += $t.TaskName } }
        'Disable' { foreach ($t in (& $pick $tasks)) { $t | Stop-ScheduledTask -ErrorAction SilentlyContinue; $t | Disable-ScheduledTask | Out-Null; $done += $t.TaskName } }
        'Start' { foreach ($t in (& $pick $tasks)) { if ($t.State -ne 'Disabled') { $t | Start-ScheduledTask; $done += $t.TaskName } } }
        'Stop' { foreach ($t in (& $pick $tasks)) { $t | Stop-ScheduledTask -ErrorAction SilentlyContinue; $done += $t.TaskName } }
        'Restart' {
            foreach ($t in (& $pick $tasks)) {
                if ($t.State -eq 'Disabled') { continue }
                $t | Stop-ScheduledTask -ErrorAction SilentlyContinue
                $t | Start-ScheduledTask
                $done += $t.TaskName
            }
        }
        'SetInterval' {
            if (-not (ConvertTo-MCInterval $Every)) { throw 'Use an interval like 5m, 1h or 24h.' }
            $collectors = Get-MCCollectors $paths
            foreach ($t in (& $pick $tasks)) {
                $c = $collectors | Where-Object { $_.id -eq (Get-MCEngineId $t.TaskName) } | Select-Object -First 1
                if ($c) { Register-Engine $paths $c $Every $t; if ($t.TaskName.StartsWith($MCLegacyPrefix)) { $t | Unregister-ScheduledTask -Confirm:$false }; $done += $MCTaskPrefix + $c.id }
            }
        }
    }
    if ($Action -ne 'List') { Write-MCEngineLog $paths ("{0} {1}: {2}" -f $Action, $Id, ($done -join ', ')) }
    if ($Action -ne 'List' -and $Action -ne 'Install' -and $Action -ne 'Uninstall' -and -not $done.Count) {
        throw $(if ($Id -eq 'All') { 'No engines are installed as scheduled tasks yet. Use Install first.' } else { "Engine $Id is not installed as a scheduled task." })
    }
    $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Out-MC ([ordered]@{ ok = $true; action = $Action; id = $Id; changed = $done; admin = $admin; taskPath = $MCTaskPath; engines = @(Get-EngineList $paths) })
}
catch {
    $msg = $_.Exception.Message
    if ($msg -match 'Access is denied|0x80070005') { $msg = 'Access is denied. Changing the engines needs administrator rights (run the launcher or the console service as an administrator).' }
    Out-MC ([ordered]@{ ok = $false; action = $Action; id = $Id; error = $msg })
    exit 1
}
