# Shared by MonCastle-Engines.ps1 and Invoke-MCEngine.ps1: resolves the app, data and scripts folders the same way
# the console server does (config\moncastle.config.json: dataDir, scripts.source/localPath).
$script:MCTaskPath = '\RoboMate\MonCastle\Engines\'
$script:MCTaskPrefix = 'RMC_'
# engines installed before 4.6 were named MC_<id>; they keep working and move to RMC_<id> on the next Install
$script:MCLegacyPrefix = 'MC_'
function Get-MCEngineId([string]$TaskName) {
    if ($TaskName.StartsWith($MCTaskPrefix)) { $TaskName.Substring($MCTaskPrefix.Length) } elseif ($TaskName.StartsWith($MCLegacyPrefix)) { $TaskName.Substring($MCLegacyPrefix.Length) } else { $null }
}

function Get-MCEnginePaths {
    $root = Split-Path $PSScriptRoot -Parent
    $cfgFile = if ($env:MC_CONFIG) { $env:MC_CONFIG } else { Join-Path $root 'config\moncastle.config.json' }
    $cfg = $null
    if (Test-Path $cfgFile) { $cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json }
    $dataDir = if ($cfg -and $cfg.dataDir) { $cfg.dataDir } else { 'data' }
    if (-not [IO.Path]::IsPathRooted($dataDir)) { $dataDir = Join-Path $root $dataDir }
    $scriptsDir = Join-Path $dataDir 'scripts'
    if ($cfg -and $cfg.scripts -and $cfg.scripts.source -eq 'local' -and $cfg.scripts.localPath) {
        $scriptsDir = $cfg.scripts.localPath
        if (-not [IO.Path]::IsPathRooted($scriptsDir)) { $scriptsDir = Join-Path $root $scriptsDir }
    }
    $engines = Join-Path $dataDir 'engines'
    foreach ($d in @($engines, (Join-Path $dataDir 'inbox'), (Join-Path $dataDir 'logs'))) {
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    $port = if ($cfg -and $cfg.port) { [int]$cfg.port } else { 5050 }
    $scheme = if ($cfg -and $cfg.tls -and $cfg.tls.enabled -eq $false) { 'http' } else { 'https' }
    [pscustomobject]@{
        Root = $root; Data = $dataDir; Console = "${scheme}://127.0.0.1:$port"; Scripts = $scriptsDir; Engines = $engines
        Inbox = Join-Path $dataDir 'inbox'; Log = Join-Path $dataDir 'logs\engines.log'
        Manifest = Join-Path $scriptsDir 'manifest.json'
    }
}

# a GET to the local console with the engine token (loopback only)
function Invoke-MCConsole($Paths, [string]$Route) {
    $tokenFile = Join-Path $Paths.Data 'secrets\engine.token'
    if (-not (Test-Path $tokenFile)) { throw "The console has not created $tokenFile yet. Start the console once." }
    $p = @{ Uri = "$($Paths.Console)/api/$Route"; Headers = @{ 'X-MC-Engine' = (Get-Content $tokenFile -Raw).Trim() }; TimeoutSec = 30 }
    if ($Paths.Console -like 'https*' -and (Get-Command Invoke-RestMethod).Parameters.ContainsKey('SkipCertificateCheck')) { $p.SkipCertificateCheck = $true }
    Invoke-RestMethod @p
}

# By default the console keeps the script library in memory (nothing on disk), so the collector list comes from the console.
# With scripts.cache = disk (or a local scripts folder) it is read from manifest.json as before.
function Get-MCCollectors($Paths) {
    if (Test-Path $Paths.Manifest) { return @((Get-Content $Paths.Manifest -Raw | ConvertFrom-Json).scripts | Where-Object { $_.kind -eq 'collector' }) }
    try { return @((Invoke-MCConsole $Paths 'engine/manifest').scripts) }
    catch { throw "The script library is held in memory by the console, and the console did not answer ($($_.Exception.Message)). Start the console, or set scripts.cache to disk in config\moncastle.config.json." }
}

# '15m', '6h', '1d' -> TimeSpan
function ConvertTo-MCInterval([string]$Every) {
    if ($Every -notmatch '^\s*(\d+)\s*([smhd])\s*$') { return $null }
    $n = [int]$Matches[1]
    switch ($Matches[2].ToLower()) {
        's' { [TimeSpan]::FromSeconds([Math]::Max(60, $n)) }
        'm' { [TimeSpan]::FromMinutes($n) }
        'h' { [TimeSpan]::FromHours($n) }
        'd' { [TimeSpan]::FromDays($n) }
    }
}

function Write-MCEngineLog($Paths, [string]$Line) {
    try { Add-Content -Path $Paths.Log -Value ('{0:s} {1}' -f (Get-Date), ($Line -replace '\s*\r?\n\s*', ' ')) -Encoding utf8 } catch { }
}

# Credentials (MC_CREDS) and extra monitored targets (MC_EXTRA_TARGETS) for one collector, from the local console.
# The console only answers loopback calls that carry the token in data\secrets\engine.token (readable by the service account).
function Get-MCEngineContext($Paths, [string]$Id) {
    $tokenFile = Join-Path $Paths.Data 'secrets\engine.token'
    if (-not (Test-Path $tokenFile)) { return $null }
    try {
        $h = @{ 'X-MC-Engine' = (Get-Content $tokenFile -Raw).Trim() }
        $p = @{ Uri = "$($Paths.Console)/api/engine/context?script=$([uri]::EscapeDataString($Id))"; Headers = $h; TimeoutSec = 15 }
        if ($Paths.Console -like 'https*' -and (Get-Command Invoke-RestMethod).Parameters.ContainsKey('SkipCertificateCheck')) { $p.SkipCertificateCheck = $true }
        return Invoke-RestMethod @p
    }
    catch { Write-MCEngineLog $Paths "$Id could not get credentials from the console ($($_.Exception.Message)); running with the engine account"; return $null }
}
