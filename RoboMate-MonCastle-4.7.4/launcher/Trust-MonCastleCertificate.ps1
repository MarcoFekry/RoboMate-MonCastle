<#
.SYNOPSIS
    Makes sure the console has its HTTPS certificate and trusts it on this machine (Local Machine > Trusted Root
    Certification Authorities), so browsers on this server open https://robomatemoncastle:5050 without a warning.
.DESCRIPTION
    Runs the console once with --make-cert, which creates data\tls\moncastle.cer when there is none (or renews it) and
    prints its thumbprint. Older RoboMate MonCastle certificates are removed from the store. Needs administrator rights;
    the setup app runs it during installation and the launcher asks for approval when the certificate is not trusted yet.
    Other PCs: import data\tls\moncastle.cer (or download it from https://<console>/api/tls/moncastle.cer), deploy it by
    Group Policy, or put a certificate from your company CA in config\moncastle.config.json (tls.cert / tls.key).
.PARAMETER Check
    Only report whether the current certificate is trusted (exit code 0 = trusted, 3 = not trusted). No admin rights needed.
#>
[CmdletBinding()]
param(
    [string]$InstallDir = (Split-Path $PSScriptRoot -Parent),
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$node = if (Test-Path (Join-Path $InstallDir 'runtime\node.exe')) { Join-Path $InstallDir 'runtime\node.exe' } else { (Get-Command node -ErrorAction Stop).Source }
$entry = @('moncastle.js', 'server\index.js') | ForEach-Object { Join-Path $InstallDir $_ } | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $entry) { throw "No MonCastle server found in $InstallDir" }

Push-Location $InstallDir
try { $out = & $node $entry --make-cert 2>&1 } finally { Pop-Location }
if ($LASTEXITCODE) { throw ('Could not create the HTTPS certificate: ' + (($out | Out-String).Trim())) }
$info = ($out | Where-Object { "$_" -match '^\{' } | Select-Object -Last 1) | ConvertFrom-Json
if ($info.source -ne 'self-signed') { Write-Output "The console uses the certificate from the configuration ($($info.thumbprint)); trust its issuing CA instead."; exit 0 }

$store = 'Cert:\LocalMachine\Root'
$trusted = [bool](Get-ChildItem $store | Where-Object Thumbprint -eq $info.thumbprint)
if ($Check) { if ($trusted) { Write-Output "trusted $($info.thumbprint)"; exit 0 } else { Write-Output "not-trusted $($info.thumbprint)"; exit 3 } }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Run this as administrator: trusting a certificate for the whole machine needs administrator rights.' }
# older MonCastle certificates (renewed or another install) leave the store
Get-ChildItem $store | Where-Object { $_.Subject -like '*O=RoboMate MonCastle*' -and $_.Thumbprint -ne $info.thumbprint } | Remove-Item -ErrorAction SilentlyContinue
if (-not $trusted) { Import-Certificate -FilePath $info.cer -CertStoreLocation $store | Out-Null }
Write-Output "HTTPS certificate trusted on this machine ($($info.thumbprint), valid until $(([datetime]$info.validTo).ToString('yyyy-MM-dd')), names: $($info.names -join ', '))"
