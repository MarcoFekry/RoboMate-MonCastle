<#
.SYNOPSIS
    Runs one MonCastle monitoring engine (a collector script). This is what each engine's scheduled task starts.
.DESCRIPTION
    - Skips the run when the console has not confirmed a valid licence in the last 72 hours (data\engines\licence.json).
    - Asks the local console for the saved device credentials and extra targets of this collector (MC_CREDS,
      MC_EXTRA_TARGETS); when the console is down the collector runs with the engine account.
    - Scripts held in memory (the default): asks the local console for the collector and the files it needs, checks the
      SHA-256 again and runs it from memory; nothing is written to disk. Disk cache (scripts.cache = disk): checks the
      collector's SHA-256 against manifest.json, then runs it through Modules\MonCastle.Core\Invoke-MCScript.ps1.
    - Drops the result envelope into data\inbox, where the console server picks it up, and writes the engine's
      status to data\engines\<id>.json. The console does not have to be running; results wait in the inbox.
.EXAMPLE
    pwsh -File engine\Invoke-MCEngine.ps1 -Id mon.compute
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[\w.-]+$')][string]$Id)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Engine.Common.ps1')
$paths = Get-MCEnginePaths
$statusFile = Join-Path $paths.Engines "$Id.json"
$started = Get-Date

function Save-Status([string]$Status, [string]$Message, $Count) {
    $s = [ordered]@{
        id = $Id; lastRun = $started.ToUniversalTime().ToString('o'); finished = (Get-Date).ToUniversalTime().ToString('o')
        durationSec = [int]((Get-Date) - $started).TotalSeconds; lastStatus = $Status; message = $Message; count = $Count; host = 'task'
    }
    $s | ConvertTo-Json -Compress | Set-Content -Path $statusFile -Encoding utf8
    Write-MCEngineLog $paths "$Id $Status $Message"
}

try {
    # licence: the console server refreshes this file while the licence is valid
    $lic = Join-Path $paths.Engines 'licence.json'
    $ok = $false
    if (Test-Path $lic) {
        $l = Get-Content $lic -Raw | ConvertFrom-Json
        $ok = $l.valid -and ((Get-Date) - [datetime]$l.checked).TotalHours -lt 72
    }
    if (-not $ok) { Save-Status 'skipped' 'Licence not confirmed by the console in the last 72 hours; engine paused.' 0; exit 0 }

    $s = Get-MCCollectors $paths | Where-Object { $_.id -eq $Id } | Select-Object -First 1
    if (-not $s) { throw "Engine $Id is not in manifest.json any more. Remove its task or sync the scripts." }
    $onDisk = Test-Path $paths.Manifest
    if ($onDisk) {
        $file = Join-Path $paths.Scripts $s.path
        if ((Get-FileHash -Path $file -Algorithm SHA256).Hash.ToLower() -ne $s.sha256) { throw "Integrity check failed for $($s.path); sync the scripts again." }
        $runner = Join-Path $paths.Scripts 'Modules\MonCastle.Core\Invoke-MCScript.ps1'
    } else {
        $bundle = Invoke-MCConsole $paths "engine/bundle?script=$([uri]::EscapeDataString($Id))"
        $files = ($bundle.payload | ConvertFrom-Json).files
        $text = [Convert]::FromBase64String([string]$files.PSObject.Properties[$s.path].Value)
        $sha = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($text)).Replace('-', '').ToLower()
        if ($sha -ne $s.sha256) { throw "Integrity check failed for $($s.path) (held in memory by the console)." }
        $hostArg = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes([string]$bundle.host))
    }

    $env:MC_PARAMS = '{}'
    $env:MONCASTLE_HOME = $paths.Data
    $env:MC_CONFIRMED = ''
    $env:MC_WHATIF = ''
    # saved device credentials and the devices whose monitoring options use this collector (console is optional)
    $ctx = Get-MCEngineContext $paths $Id
    # since 4.7.4 an engine reads nothing until it is configured in the console (targets, devices, or enabled by hand)
    if ($ctx -and [string]$ctx.MC_NOT_CONFIGURED -eq '1') { Save-Status 'skipped' 'Not configured: choose its targets in the console (Monitoring engines > engine > Targets).' 0; exit 0 }
    $env:MC_CREDS = if ($ctx) { [string]$ctx.MC_CREDS } else { '' }
    $env:MC_EXTRA_TARGETS = if ($ctx) { [string]$ctx.MC_EXTRA_TARGETS } else { '' }
    $env:MC_TARGETS_ONLY = if ($ctx) { [string]$ctx.MC_TARGETS_ONLY } else { '' }
    $env:MC_EXCLUDE_TARGETS = if ($ctx) { [string]$ctx.MC_EXCLUDE_TARGETS } else { '' }
    $env:MC_TARGET_SCOPE = if ($ctx) { [string]$ctx.MC_TARGET_SCOPE } else { '' }
    $env:MC_TARGET_INFO = if ($ctx) { [string]$ctx.MC_TARGET_INFO } else { '' }
    $pwsh = (Get-Process -Id $PID).Path
    if ($onDisk) {
        Push-Location $paths.Scripts
        try { $out = & $pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runner -Script $s.path 2>&1 | Out-String }
        finally { Pop-Location; $env:MC_CREDS = $null }
    } else {
        # the collector and its files go to the child on standard input; MC_SCRIPT names the one to run
        $env:MC_SCRIPT = $s.path
        try { $out = [string]$bundle.payload | & $pwsh -NoProfile -NonInteractive -ExecutionPolicy Bypass -OutputFormat Text -EncodedCommand $hostArg 2>&1 | Out-String }
        finally { $env:MC_CREDS = $null; $env:MC_SCRIPT = $null; $bundle = $null }
    }
    $out = $out -replace "$([char]27)\[[0-9;]*m", ''

    $a = $out.LastIndexOf('##MONCASTLE-RESULT-BEGIN##'); $b = $out.LastIndexOf('##MONCASTLE-RESULT-END##')
    if ($a -lt 0 -or $b -le $a) {
        $msg = 'No result from the collector. ' + $out.Trim()
        throw $msg.Substring(0, [Math]::Min(2000, $msg.Length))
    }
    $json = $out.Substring($a + 26, $b - $a - 26)
    $result = $json | ConvertFrom-Json

    # hand the result to the console (atomic: write then rename); keep at most 5 waiting results per engine
    $name = '{0}_{1:yyyyMMddHHmmss}.json' -f $Id, (Get-Date)
    $tmp = Join-Path $paths.Inbox ($name + '.tmp')
    Set-Content -Path $tmp -Value $json -Encoding utf8
    Move-Item -Path $tmp -Destination (Join-Path $paths.Inbox $name) -Force
    Get-ChildItem $paths.Inbox -Filter "$($Id)_*.json" | Sort-Object Name -Descending | Select-Object -Skip 5 | Remove-Item -Force -ErrorAction SilentlyContinue

    $status = if ($result.status -eq 'error') { 'error' } elseif (@($result.warnings).Count) { 'warning' } else { 'ok' }
    Save-Status $status ([string]$result.message) $result.count
    if ($status -eq 'error') { exit 1 }
}
catch {
    Save-Status 'error' $_.Exception.Message 0
    exit 1
}
