<#
.SYNOPSIS
    RoboMate MonCastle launcher: checks prerequisites, starts the console server and opens the browser.
.DESCRIPTION
    - Verifies Node.js 18+ and PowerShell 7 (pwsh), and the RSAT / module prerequisites the scripts use.
    - Creates config\moncastle.config.json from the example on first run.
    - Starts the server (hidden) unless it is already listening, waits until /api/status answers, then opens the console.
    The licence token is entered in the browser on first launch; it is never passed on the command line.
.EXAMPLE
    .\launcher\Start-MonCastle.ps1
.EXAMPLE
    .\launcher\Start-MonCastle.ps1 -Demo      # generated data, no PowerShell collection
#>
[CmdletBinding()]
param(
    [int]$Port,
    [switch]$Demo,
    [switch]$NoBrowser,
    [switch]$SkipChecks
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
# source tree (server\index.js) or user package (moncastle.js + app.mcpak, its own runtime\node.exe)
$entry = if (Test-Path (Join-Path $root 'moncastle.js')) { 'moncastle.js' } else { 'server/index.js' }
$nodeExe = if (Test-Path (Join-Path $root 'runtime\node.exe')) { Join-Path $root 'runtime\node.exe' } else { 'node' }
$cfgFile = Join-Path $root 'config\moncastle.config.json'
$example = Join-Path $root 'config\moncastle.config.example.json'

function Write-Step($text, $ok = $true) { Write-Host ('  [{0}] {1}' -f ($(if ($ok) { 'ok' } else { '!!' })), $text) -ForegroundColor $(if ($ok) { 'Green' } else { 'Yellow' }) }

Write-Host ''
Write-Host '  RoboMate MonCastle' -ForegroundColor Cyan
Write-Host '  -------------------' -ForegroundColor DarkCyan

if (-not (Test-Path $cfgFile)) { Copy-Item $example $cfgFile; Write-Step "created $cfgFile from the example" }
$cfg = Get-Content $cfgFile -Raw | ConvertFrom-Json
if (-not $Port) { $Port = if ($cfg.port) { [int]$cfg.port } else { 5050 } }
$scheme = if ($cfg.tls -and $cfg.tls.enabled -eq $false) { 'http' } else { 'https' }
$name = if ($cfg.publicName) { $cfg.publicName } else { 'robomatemoncastle' }
$probe = "${scheme}://localhost:$Port/"
$url = "${scheme}://${name}:$Port/"

# make https://robomatemoncastle:5050 resolve on this machine (hosts file; other PCs need a DNS record, see README)
$hosts = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$resolves = $false
try { $resolves = [bool]([System.Net.Dns]::GetHostAddresses($name)) } catch { }
if (-not $resolves -and (Test-Path $hosts)) {
    $line = "127.0.0.1`t$name`t# RoboMate MonCastle console"
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    try {
        if ($isAdmin) { Add-Content -Path $hosts -Value $line -Encoding ascii }
        else { Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList '-NoProfile', '-Command', "Add-Content -Path '$hosts' -Value \"$line\" -Encoding ascii" }
        Write-Step "added $name to the hosts file"
    } catch { Write-Step "could not add $name to the hosts file; using $name.localhost (Edge and Chrome resolve it to this PC)" $false; $url = "${scheme}://${name}.localhost:$Port/" }
} elseif ($resolves) { Write-Step "$name resolves" }

if (-not $SkipChecks) {
    $node = Get-Command $nodeExe -ErrorAction SilentlyContinue
    if (-not $node) { throw 'Node.js 18 or newer is required: https://nodejs.org (or winget install OpenJS.NodeJS.LTS).' }
    $ver = [version]((& $nodeExe --version).TrimStart('v'))
    if ($ver.Major -lt 18) { throw "Node.js $ver is too old; install 18 or newer." }
    Write-Step "Node.js $ver"
    if (-not $Demo) {
        $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
        if ($pwsh) { Write-Step "PowerShell $((& pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'))" } else { Write-Step 'PowerShell 7 (pwsh) not found: scripts cannot run. winget install Microsoft.PowerShell' $false }
        foreach ($m in 'ActiveDirectory', 'DhcpServer', 'FailoverClusters', 'Hyper-V', 'dbatools', 'VMware.PowerCLI') {
            if (Get-Module -ListAvailable -Name $m) { Write-Step "module $m" } else { Write-Step "module $m missing (only the scripts that use it are affected)" $false }
        }
    }
}

if (-not $Demo -and -not (Test-Path (Join-Path $root 'data\secrets\override.json'))) {
    Write-Step 'no administrator override password set yet (needed to open the console without a licence)' $false
    if ((Read-Host '  Set it now? [Y/n]') -notmatch '^[nN]') { & (Join-Path $PSScriptRoot 'Set-MonCastleAdminPassword.ps1') }
}

# HTTPS: the console's certificate trusted on this machine (asks for administrator approval once)
if ($scheme -eq 'https') {
    $trust = Join-Path $PSScriptRoot 'Trust-MonCastleCertificate.ps1'
    $null = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $trust -InstallDir $root -Check
    if ($LASTEXITCODE -eq 3) {
        try { Start-Process -FilePath 'powershell.exe' -Verb RunAs -Wait -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$trust`"", '-InstallDir', "`"$root`""; Write-Step 'HTTPS certificate trusted on this machine' }
        catch { Write-Step 'the HTTPS certificate is not trusted yet: browsers will warn until you run launcher\Trust-MonCastleCertificate.ps1 as administrator' $false }
    } elseif ($LASTEXITCODE -eq 0) { Write-Step 'HTTPS certificate trusted' }
}

function Test-Console {
    $irm = @{ Uri = $probe + 'api/status'; TimeoutSec = 2 }
    # loopback probe only: the certificate check is skipped for this one request
    if ($scheme -eq 'https' -and $PSVersionTable.PSVersion.Major -ge 7) { $irm.SkipCertificateCheck = $true }
    $old = [Net.ServicePointManager]::ServerCertificateValidationCallback
    if ($scheme -eq 'https' -and $PSVersionTable.PSVersion.Major -lt 7) { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; [Net.ServicePointManager]::ServerCertificateValidationCallback = { $true } }
    try { (Invoke-RestMethod @irm).product -eq 'RoboMate MonCastle' } catch { $false } finally { [Net.ServicePointManager]::ServerCertificateValidationCallback = $old }
}

if (Test-Console) {
    Write-Step "console already running at $url"
} else {
    $env:MC_PORT = $Port
    if ($Demo) { $env:MC_MODE = 'demo' }
    $logDir = Join-Path $root 'data\logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $p = Start-Process -FilePath $nodeExe -ArgumentList @($entry) -WorkingDirectory $root -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput (Join-Path $logDir 'server.out.log') -RedirectStandardError (Join-Path $logDir 'server.err.log')
    Write-Step "server started (PID $($p.Id)), waiting for it to answer"
    $deadline = (Get-Date).AddSeconds(30)
    while (-not (Test-Console)) {
        if ((Get-Date) -gt $deadline -or $p.HasExited) { throw "The server did not start. See $logDir\server.err.log" }
        Start-Sleep -Milliseconds 400
    }
    Write-Step "console ready at $url"
}
if (-not $NoBrowser) {
    # the default browser, as a normal tab
    Start-Process $url
}
Write-Host ''
Write-Host "  Stop it with:  Stop-Process -Name node   (or use the Windows service, see launcher\Install-MonCastleService.ps1)" -ForegroundColor DarkGray
