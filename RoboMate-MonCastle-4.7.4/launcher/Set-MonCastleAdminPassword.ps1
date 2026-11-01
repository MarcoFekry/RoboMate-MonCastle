<#
.SYNOPSIS
    Sets or changes the MonCastle administrator override password.
.DESCRIPTION
    Without a valid licence the console does not open, except for an administrator who signs in with this
    override password (for example to enter a new licence or recover from an expired one).
    Only a salted scrypt hash is stored, in data\secrets\override.json. The password is never written anywhere in clear text.
.EXAMPLE
    .\launcher\Set-MonCastleAdminPassword.ps1
#>
[CmdletBinding()]
param()
$root = Split-Path $PSScriptRoot -Parent
# source tree (server\index.js) or user package (moncastle.js + app.mcpak, its own runtime\node.exe)
$entry = if (Test-Path (Join-Path $root 'moncastle.js')) { 'moncastle.js' } else { 'server/index.js' }
$nodeExe = if (Test-Path (Join-Path $root 'runtime\node.exe')) { Join-Path $root 'runtime\node.exe' } else { 'node' }
$a = Read-Host 'New override password (12+ characters)' -AsSecureString
$b = Read-Host 'Repeat' -AsSecureString
$plainA = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($a))
$plainB = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($b))
if ($plainA -ne $plainB) { throw 'The passwords do not match.' }
try {
    $env:MC_OVERRIDE_PASSWORD = $plainA
    Push-Location $root
    if ($entry -eq 'moncastle.js') { & $nodeExe moncastle.js --tool set-override-password } else { & node tools/set-override-password.js }
    if ($LASTEXITCODE) { throw 'Could not set the password.' }
} finally {
    Remove-Item Env:MC_OVERRIDE_PASSWORD -ErrorAction SilentlyContinue
    Pop-Location
    $plainA = $plainB = $null
}
