<#
.SYNOPSIS
    Joins this MonCastle installation to a central MonCastle console as a remote MonCastle server.
.DESCRIPTION
    On the central console an administrator opens Monitor > MonCastle servers > Add MonCastle server and copies the
    one-time join code. Run this script on the remote server and paste the code when asked. The code carries the
    server's secret, so it is read as a secure string and handed to Node in an environment variable, never on a
    command line or in a log. The secret is kept in data\secrets (encrypted store) and config\moncastle.config.json
    gets "infra": { "role": "remote", ... }.
    Afterwards start MonCastle as usual (launcher, service or Start-MonCastle.cmd). The server checks in every 30 seconds
    and appears on the central console with its utilisation; assign devices to it from there.
.PARAMETER Leave
    Turns this server back into a stand-alone console (removes the infra section from the configuration).
.EXAMPLE
    .\launcher\Join-MonCastleServer.ps1
#>
[CmdletBinding()]
param([switch]$Leave)
$root = Split-Path $PSScriptRoot -Parent
$cfgFile = Join-Path $root 'config\moncastle.config.json'
# source tree (server\index.js) or user package (moncastle.js + app.mcpak, its own runtime\node.exe)
$entry = if (Test-Path (Join-Path $root 'moncastle.js')) { 'moncastle.js' } else { 'server/index.js' }
$nodeExe = if (Test-Path (Join-Path $root 'runtime\node.exe')) { Join-Path $root 'runtime\node.exe' } else { 'node' }
if ($Leave) {
    if (Test-Path $cfgFile) {
        $c = Get-Content $cfgFile -Raw | ConvertFrom-Json
        $c.PSObject.Properties.Remove('infra')
        $c | ConvertTo-Json -Depth 10 | Set-Content $cfgFile -Encoding UTF8
    }
    Write-Host 'This server is a stand-alone MonCastle console again. Remove it on the central console too.'
    return
}
$sec = Read-Host 'Paste the join code (MCJ1.…)' -AsSecureString
$code = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
if ($code -notmatch '^\s*MCJ1\.[A-Za-z0-9_-]+\s*$') { throw 'That is not a MonCastle join code.' }
try {
    $env:MC_JOIN = $code.Trim()
    Push-Location $root
    & $nodeExe $entry
    if ($LASTEXITCODE) { throw 'Joining failed; see the message above.' }
    Write-Host 'Joined. Restart MonCastle on this server (service or launcher) to start as a remote MonCastle server.'
} finally {
    Remove-Item Env:MC_JOIN -ErrorAction SilentlyContinue
    Pop-Location
    $code = $null
}
