<#
.SYNOPSIS
    Installs RoboMate MonCastle and its prerequisites (the engine behind MonCastle-Setup.exe; also runs on its own).
.DESCRIPTION
    Copies the user package to the install folder and prepares the server:
      - prerequisites: PowerShell 7, RSAT (Active Directory, DNS, DHCP, Group Policy, failover clustering), print
        management, Hyper-V module, WinRM, and the optional PowerShell modules (dbatools, SqlServer, VMware PowerCLI,
        SecretManagement) and database client tools (psql, mysql, mongosh, redis-cli, sqlplus)
      - Windows firewall rule for the console port, hosts entry for robomatemoncastle
      - data folder readable only by the service account, SYSTEM and administrators
      - administrator override password, licence key, optional join to a central MonCastle console
      - the console as a service (scheduled task at startup under the chosen account), Start menu entries and
        an entry in Apps & features
    Secrets are read from environment variables, never from parameters, so they do not show up in process lists or logs:
      MC_OVERRIDE_PASSWORD   administrator override password (12+ characters)
      MC_LICENSE_KEY         licence key (serial), 320RMC...
      MC_JOIN                join code from the central console (MCJ1....), for a remote MonCastle server
      MC_SETUP_SVC_PASSWORD  password of the service account (not needed for SYSTEM or a gMSA ending in $)
    Progress is written as lines "##STEP|id|state|text" (state: run, ok, warn, fail, skip) for the setup app;
    -CheckOnly writes "##CHECK|id|present|detail" lines and changes nothing.
.EXAMPLE
    .\launcher\Install-MonCastle.ps1 -Unattended -Components PowerShell7, RSAT, WinRM
.EXAMPLE
    .\launcher\Install-MonCastle.ps1 -CheckOnly
.EXAMPLE
    .\launcher\Install-MonCastle.ps1 -Uninstall -InstallDir 'C:\Program Files\RoboMate\MonCastle'
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [string]$InstallDir = (Join-Path $env:ProgramFiles 'RoboMate\MonCastle'),
    [string]$SourceDir = (Split-Path $PSScriptRoot -Parent),
    [ValidateRange(1, 65535)][int]$Port = 5050,
    [string]$PublicName = 'robomatemoncastle',
    [string]$ServiceAccount = 'NT AUTHORITY\SYSTEM',
    # PowerShell7, RSAT, PrintManagement, HyperV, Clustering, WinRM, SecretManagement, dbatools, SqlServer, PowerCLI, DatabaseClients
    # (a list, or one comma-separated string when called with -File)
    [string[]]$Components = @('PowerShell7', 'RSAT', 'PrintManagement', 'WinRM', 'SecretManagement', 'dbatools'),
    [switch]$NoService,
    [switch]$NoFirewall,
    [switch]$NoHosts,
    [switch]$NoShortcuts,
    [switch]$Unattended,
    [switch]$CheckOnly,
    [switch]$Uninstall,
    [switch]$RemoveData
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$TaskName = 'RoboMate MonCastle Console'
$RuleName = 'RoboMate MonCastle Console'
$UninstallKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RoboMateMonCastle'
$LogFile = Join-Path $env:TEMP ('MonCastle-Setup-{0:yyyyMMdd-HHmmss}.log' -f (Get-Date))
$script:Failed = 0

function Step([string]$Id, [string]$State, [string]$Text) {
    $line = "##STEP|$Id|$State|$Text"
    Write-Output $line
    Add-Content -Path $LogFile -Value ('{0:s} {1}' -f (Get-Date), $line) -ErrorAction SilentlyContinue
    if ($State -eq 'fail') { $script:Failed++ }
}
function Check([string]$Id, [bool]$Present, [string]$Detail) { Write-Output "##CHECK|$Id|$(if ($Present) { 'yes' } else { 'no' })|$Detail" }
function Invoke-Step([string]$Id, [string]$Text, [scriptblock]$Body, [switch]$Optional) {
    Step $Id 'run' $Text
    try { $r = & $Body; Step $Id 'ok' $(if ($r -is [string] -and $r) { $r } else { $Text }) }
    catch { Step $Id $(if ($Optional) { 'warn' } else { 'fail' }) ("$Text`: " + $_.Exception.Message) }
}
$IsServer = (Get-CimInstance Win32_OperatingSystem).ProductType -ne 1
function Test-Module([string]$Name) { [bool](Get-Module -ListAvailable -Name $Name) }
function Get-Pwsh { $c = Get-Command pwsh -ErrorAction SilentlyContinue; if ($c) { $c.Source } elseif (Test-Path "$env:ProgramFiles\PowerShell\7\pwsh.exe") { "$env:ProgramFiles\PowerShell\7\pwsh.exe" } }
function Install-WindowsPart([string[]]$Features, [string[]]$Capabilities) {
    # Windows Server: features; Windows 10/11: Features on Demand (needs Windows Update or a FoD source)
    if ($IsServer) { $r = Install-WindowsFeature -Name $Features -IncludeManagementTools -ErrorAction Stop; if (-not $r.Success) { throw "Install-WindowsFeature $($Features -join ', ') did not succeed" } }
    else { foreach ($c in $Capabilities) { if ((Get-WindowsCapability -Online -Name $c).State -ne 'Installed') { Add-WindowsCapability -Online -Name $c -ErrorAction Stop | Out-Null } } }
}
function Install-GalleryModule([string]$Name) {
    if (-not (Get-PackageProvider -ListAvailable -Name NuGet -ErrorAction SilentlyContinue | Where-Object { $_.Version -ge '2.8.5.201' })) { Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null }
    $offline = Join-Path $SourceDir "prereqs\modules\$Name"
    if (Test-Path $offline) { Copy-Item $offline (Join-Path $env:ProgramFiles 'WindowsPowerShell\Modules') -Recurse -Force; return "$Name copied from the package" }
    Install-Module -Name $Name -Scope AllUsers -Force -AllowClobber -Repository PSGallery -ErrorAction Stop
    $pw = Get-Pwsh
    # modules for PowerShell 7 live in their own folder; install there too so the engines (pwsh) find them
    if ($pw) { & $pw -NoProfile -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module -Name $Name -Scope AllUsers -Force -AllowClobber -ErrorAction Stop" | Out-Null }
    "$Name installed"
}
function Install-Winget([string]$Id) {
    $w = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $w) { throw 'winget is not available on this server; install the package by hand' }
    & $w.Source install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements --scope machine | Out-Null
    if ($LASTEXITCODE -and $LASTEXITCODE -ne -1978335189) { throw "winget install $Id exited with $LASTEXITCODE" }   # -1978335189 = already installed
}

# ---------------------------------------------------------------- what each component is and how to check it
$Catalog = [ordered]@{
    PowerShell7      = @{ Name = 'PowerShell 7 (runs the engines)'; Test = { [bool](Get-Pwsh) }; Install = {
            $msi = Get-ChildItem (Join-Path $SourceDir 'prereqs') -Filter 'PowerShell-7*-win-x64.msi' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($msi) { $p = Start-Process msiexec.exe -ArgumentList '/i', "`"$($msi.FullName)`"", '/qn', '/norestart', 'ADD_PATH=1', 'ENABLE_PSREMOTING=0' -Wait -PassThru; if ($p.ExitCode -notin 0, 3010) { throw "msiexec exited with $($p.ExitCode)" }; 'PowerShell 7 installed from the package' }
            else { Install-Winget 'Microsoft.PowerShell'; 'PowerShell 7 installed with winget' } } }
    RSAT             = @{ Name = 'RSAT: Active Directory, DNS, DHCP, Group Policy'; Test = { (Test-Module ActiveDirectory) -and (Test-Module DnsServer) -and (Test-Module GroupPolicy) }; Install = {
            Install-WindowsPart @('RSAT-AD-PowerShell', 'RSAT-DNS-Server', 'RSAT-DHCP', 'GPMC') @('Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0', 'Rsat.Dns.Tools~~~~0.0.1.0', 'Rsat.DHCP.Tools~~~~0.0.1.0', 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0') } }
    PrintManagement  = @{ Name = 'Print management module'; Test = { Test-Module PrintManagement }; Install = { Install-WindowsPart @('RSAT-Print-Services') @('Print.Management.Console~~~~0.0.1.0') } }
    HyperV           = @{ Name = 'Hyper-V PowerShell module'; Test = { Test-Module Hyper-V }; Install = { if ($IsServer) { Install-WindowsFeature Hyper-V-PowerShell -ErrorAction Stop | Out-Null } else { Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Management-PowerShell -All -NoRestart -ErrorAction Stop | Out-Null } } }
    Clustering       = @{ Name = 'Failover clustering module'; Test = { Test-Module FailoverClusters }; Install = { Install-WindowsPart @('RSAT-Clustering-PowerShell') @('Rsat.FailoverCluster.Management.Tools~~~~0.0.1.0') } }
    WinRM            = @{ Name = 'WinRM (PowerShell remoting)'; Test = { (Get-Service WinRM -ErrorAction SilentlyContinue).Status -eq 'Running' }; Install = { Enable-PSRemoting -Force -SkipNetworkProfileCheck | Out-Null; Set-Service WinRM -StartupType Automatic; 'WinRM enabled' } }
    SecretManagement = @{ Name = 'SecretManagement (credential vault for scripts)'; Test = { Test-Module Microsoft.PowerShell.SecretManagement }; Install = { Install-GalleryModule 'Microsoft.PowerShell.SecretManagement' } }
    dbatools         = @{ Name = 'dbatools (SQL Server collectors)'; Test = { Test-Module dbatools }; Install = { Install-GalleryModule 'dbatools' } }
    SqlServer        = @{ Name = 'SqlServer module'; Test = { Test-Module SqlServer }; Install = { Install-GalleryModule 'SqlServer' } }
    PowerCLI         = @{ Name = 'VMware PowerCLI (VMware collector)'; Test = { Test-Module VMware.VimAutomation.Core }; Install = { Install-GalleryModule 'VMware.PowerCLI' } }
    DatabaseClients  = @{ Name = 'Database client tools (psql, mysql, mongosh, redis-cli)'; Test = { [bool]((Get-Command psql, mysql, mongosh -ErrorAction SilentlyContinue) | Select-Object -First 1) }; Install = {
            # best effort: each client is optional, a missing one only affects that engine's collector
            $done = @(); $missed = @()
            foreach ($id in 'PostgreSQL.PostgreSQL.16', 'Oracle.MySQL', 'MongoDB.Shell') { try { Install-Winget $id; $done += $id } catch { $missed += $id } }
            if ($missed) { throw "installed $($done -join ', '); not installed: $($missed -join ', ') (install those clients by hand; redis-cli and sqlplus come with Redis/Memurai and Oracle Instant Client)" }
            "installed $($done -join ', ')" } }
}

$Components = @($Components | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ })
foreach ($k in $Components) { if (-not $Catalog.Contains($k)) { throw "Unknown component '$k'. Use: $($Catalog.Keys -join ', ')" } }

# ---------------------------------------------------------------- check only
if ($CheckOnly) {
    $os = Get-CimInstance Win32_OperatingSystem
    Check 'os' ([version]$os.Version -ge [version]'10.0.14393') "$($os.Caption) $($os.Version)"
    $drive = (Split-Path $InstallDir -Qualifier); $free = (Get-PSDrive ($drive.TrimEnd(':'))).Free
    Check 'disk' ($free -gt 2GB) ('{0:N1} GB free on {1}' -f ($free / 1GB), $drive)
    Check 'runtime' (Test-Path (Join-Path $SourceDir 'runtime\node.exe')) 'Node.js runtime in the package'
    foreach ($k in $Catalog.Keys) { $ok = $false; try { $ok = [bool](& $Catalog[$k].Test) } catch { }; Check $k $ok $Catalog[$k].Name }
    $inUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
    Check 'port' (-not $inUse) $(if ($inUse) { "port $Port is in use by process $($inUse[0].OwningProcess)" } else { "port $Port is free" })
    Check 'installed' (Test-Path (Join-Path $InstallDir 'moncastle.js')) $(if (Test-Path (Join-Path $InstallDir 'moncastle.js')) { "MonCastle is already installed in $InstallDir (upgrade keeps the data)" } else { 'new installation' })
    return
}

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    Invoke-Step 'service' 'Stop and remove the MonCastle service' { if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue; Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false } ; Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$InstallDir*" } | Stop-Process -Force }
    Invoke-Step 'firewall' 'Remove the firewall rule' { Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule } -Optional
    Invoke-Step 'https' 'Remove the HTTPS certificate from the trusted store' { Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like '*O=RoboMate MonCastle*' } | Remove-Item } -Optional
    Invoke-Step 'hosts' 'Remove the hosts entry' { $h = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'; (Get-Content $h) | Where-Object { $_ -notmatch '# RoboMate MonCastle console' } | Set-Content $h -Encoding ascii } -Optional
    Invoke-Step 'shortcuts' 'Remove the Start menu entries' { Remove-Item (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\RoboMate MonCastle') -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item $UninstallKey -Recurse -Force -ErrorAction SilentlyContinue } -Optional
    Invoke-Step 'files' $(if ($RemoveData) { 'Remove the program and its data' } else { 'Remove the program (the data folder is kept)' }) {
        Get-ChildItem $InstallDir -Force | Where-Object { $RemoveData -or $_.Name -notin 'data', 'config' } | Remove-Item -Recurse -Force
        if ($RemoveData) { Remove-Item $InstallDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Step 'done' $(if ($script:Failed) { 'fail' } else { 'ok' }) $(if ($script:Failed) { "Uninstall finished with $($script:Failed) problem(s); log: $LogFile" } else { 'MonCastle was removed.' })
    return
}

# ---------------------------------------------------------------- install
Step 'start' 'ok' "Installing RoboMate MonCastle to $InstallDir (log: $LogFile)"
if ($env:MC_OVERRIDE_PASSWORD -and $env:MC_OVERRIDE_PASSWORD.Length -lt 12) { Step 'override' 'fail' 'The override password must have 12 or more characters.'; return }
if ($env:MC_LICENSE_KEY -and $env:MC_LICENSE_KEY -notmatch '^\s*320RMC') { Step 'licence' 'fail' 'The licence key must start with 320RMC.'; return }
if ($env:MC_JOIN -and $env:MC_JOIN -notmatch '^\s*MCJ1\.[A-Za-z0-9_-]+\s*$') { Step 'join' 'fail' 'That is not a MonCastle join code (MCJ1....).'; return }

foreach ($k in $Components) {
    $c = $Catalog[$k]; $present = $false; try { $present = [bool](& $c.Test) } catch { }
    if ($present) { Step "pre-$k" 'ok' "$($c.Name): already installed"; continue }
    Invoke-Step "pre-$k" "Install $($c.Name)" $c.Install -Optional:($k -notin 'PowerShell7')
}

Invoke-Step 'stop' 'Stop a running MonCastle console' {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue }
    Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$InstallDir*" } | Stop-Process -Force
}

Invoke-Step 'files' "Copy MonCastle to $InstallDir" {
    $src = (Resolve-Path $SourceDir).Path.TrimEnd('\'); $dst = $InstallDir.TrimEnd('\')
    if ($src -ieq $dst) { return 'MonCastle already runs from this folder' }
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    # data and config belong to the installation: an upgrade never overwrites them
    & robocopy.exe $src $dst /E /R:2 /W:2 /NFL /NDL /NJH /NJS /NP /XD (Join-Path $src 'data') (Join-Path $src 'config') (Join-Path $src 'prereqs') | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
    New-Item -ItemType Directory -Force -Path (Join-Path $dst 'config') | Out-Null
    $ex = Join-Path $src 'config\moncastle.config.example.json'
    if (Test-Path $ex) { Copy-Item $ex (Join-Path $dst 'config') -Force }
    "Program files copied to $dst"
}
$node = Join-Path $InstallDir 'runtime\node.exe'
if (-not (Test-Path $node)) { $n = Get-Command node -ErrorAction SilentlyContinue; $node = if ($n) { $n.Source } else { $null } }
if (-not $node) { Step 'runtime' 'fail' 'No Node.js runtime: the package has no runtime\node.exe and Node.js is not installed.'; return }
$entry = if (Test-Path (Join-Path $InstallDir 'moncastle.js')) { 'moncastle.js' } else { 'server\index.js' }
function Invoke-Tool([string]$Tool) {
    $ErrorActionPreference = 'Continue'   # Windows PowerShell turns stderr of a native command into an error under Stop
    Push-Location $InstallDir
    try { $out = if ($entry -eq 'moncastle.js') { & $node moncastle.js --tool $Tool 2>&1 } else { & $node "tools\$Tool.js" 2>&1 }; if ($LASTEXITCODE) { throw (($out | Out-String).Trim()) }; ($out | Out-String).Trim() }
    finally { Pop-Location }
}

Invoke-Step 'config' 'Write the configuration' {
    $file = Join-Path $InstallDir 'config\moncastle.config.json'
    $cfg = if (Test-Path $file) { Get-Content $file -Raw | ConvertFrom-Json } elseif (Test-Path (Join-Path $InstallDir 'config\moncastle.config.example.json')) { Get-Content (Join-Path $InstallDir 'config\moncastle.config.example.json') -Raw | ConvertFrom-Json } else { [pscustomobject]@{} }
    foreach ($kv in @{ port = $Port; publicName = $PublicName; encryptData = $true }.GetEnumerator()) { if ($cfg.PSObject.Properties[$kv.Key]) { $cfg.($kv.Key) = $kv.Value } else { $cfg | Add-Member $kv.Key $kv.Value } }
    $cfg | ConvertTo-Json -Depth 10 | Set-Content $file -Encoding UTF8
    "Port $Port, name $PublicName, data encrypted at rest"
}

Invoke-Step 'acl' 'Restrict the data folder' {
    $data = Join-Path $InstallDir 'data'
    New-Item -ItemType Directory -Force -Path $data | Out-Null
    $acct = if ($ServiceAccount -match '^(NT AUTHORITY\\)?SYSTEM$') { '*S-1-5-18' } else { $ServiceAccount }
    & icacls.exe $data /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' "${acct}:(OI)(CI)M" /T /C /Q | Out-Null
    if ($LASTEXITCODE) { throw "icacls exited with $LASTEXITCODE" }
    "Only SYSTEM, Administrators and $ServiceAccount can open $data"
}

if ($env:MC_OVERRIDE_PASSWORD) { Invoke-Step 'override' 'Set the administrator override password' { $r = Invoke-Tool 'set-override-password'; Remove-Item Env:MC_OVERRIDE_PASSWORD -ErrorAction SilentlyContinue; 'Override password set (only its hash is stored)' } }
elseif (-not (Test-Path (Join-Path $InstallDir 'data\secrets\override.json'))) { Step 'override' 'warn' 'No override password set yet: run launcher\Set-MonCastleAdminPassword.ps1 before the first start.' }

if ($env:MC_LICENSE_KEY) { Invoke-Step 'licence' 'Register the licence key' { $r = Invoke-Tool 'set-licence'; Remove-Item Env:MC_LICENSE_KEY -ErrorAction SilentlyContinue; $r } -Optional }
else { Step 'licence' 'skip' 'No licence key given: enter it in the console (Settings > Licence) on first start.' }

if ($env:MC_JOIN) {
    Invoke-Step 'join' 'Join the central MonCastle console' {
        $ErrorActionPreference = 'Continue'
        Push-Location $InstallDir
        try { $out = & $node $entry 2>&1; if ($LASTEXITCODE) { throw (($out | Out-String).Trim()) } } finally { Pop-Location; Remove-Item Env:MC_JOIN -ErrorAction SilentlyContinue }
        'Joined as a remote MonCastle server'
    }
}

if (-not $NoFirewall) { Invoke-Step 'firewall' "Allow TCP $Port in Windows Firewall" { Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule; New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Domain, Private | Out-Null; "Inbound TCP $Port allowed (domain and private networks)" } -Optional }
if (-not $NoHosts) {
    Invoke-Step 'hosts' "Make $PublicName resolve on this server" {
        $h = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
        $lines = @(Get-Content $h -ErrorAction SilentlyContinue | Where-Object { $_ -notmatch '# RoboMate MonCastle console' })
        $lines += "127.0.0.1`t$PublicName`t# RoboMate MonCastle console"
        Set-Content $h $lines -Encoding ascii
        "$PublicName added to the hosts file (other computers need a DNS record)"
    } -Optional
}

Invoke-Step 'https' 'Create the HTTPS certificate and trust it on this machine' {
    $r = & (Join-Path $InstallDir 'launcher\Trust-MonCastleCertificate.ps1') -InstallDir $InstallDir
    ($r | Out-String).Trim()
} -Optional

if (-not $NoService) {
    Invoke-Step 'service' "Run the console as a service under $ServiceAccount" {
        $action = New-ScheduledTaskAction -Execute $node -Argument $entry -WorkingDirectory $InstallDir
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $settings = New-ScheduledTaskSettingsSet -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        if ($ServiceAccount -match '^(NT AUTHORITY\\)?(SYSTEM|NETWORK SERVICE|LOCAL SERVICE)$') {
            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal (New-ScheduledTaskPrincipal -UserId $ServiceAccount -LogonType ServiceAccount -RunLevel Highest) -Force | Out-Null
        } elseif ($ServiceAccount -like '*$') {
            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal (New-ScheduledTaskPrincipal -UserId $ServiceAccount -LogonType Password -RunLevel Highest) -Force | Out-Null
        } else {
            if (-not $env:MC_SETUP_SVC_PASSWORD) { throw "The password of $ServiceAccount is needed (MC_SETUP_SVC_PASSWORD), or use SYSTEM or a gMSA" }
            Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -User $ServiceAccount -Password $env:MC_SETUP_SVC_PASSWORD -RunLevel Highest -Force | Out-Null
            Remove-Item Env:MC_SETUP_SVC_PASSWORD -ErrorAction SilentlyContinue
        }
        Start-ScheduledTask -TaskName $TaskName
        "Service '$TaskName' starts with Windows and restarts on failure"
    }
}

if (-not $NoShortcuts) {
    Invoke-Step 'shortcuts' 'Add Start menu entries and Apps & features' {
        $menu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\RoboMate MonCastle'
        New-Item -ItemType Directory -Force -Path $menu | Out-Null
        $sh = New-Object -ComObject WScript.Shell
        $exe = Join-Path $InstallDir 'RoboMate.MonCastle.Launcher.exe'
        if (Test-Path $exe) { $l = $sh.CreateShortcut((Join-Path $menu 'MonCastle Launcher.lnk')); $l.TargetPath = $exe; $l.WorkingDirectory = $InstallDir; $l.Save() }
        $u = $sh.CreateShortcut((Join-Path $menu 'RoboMate MonCastle.url')); $u.TargetPath = "https://${PublicName}:$Port/"; $u.Save()
        $ver = try { (Get-Content (Join-Path $InstallDir 'version.json') -Raw | ConvertFrom-Json).version } catch { '' }
        $setup = Join-Path $InstallDir 'MonCastle-Setup.exe'
        New-Item -Path $UninstallKey -Force | Out-Null
        $props = @{ DisplayName = 'RoboMate MonCastle'; DisplayVersion = $ver; Publisher = 'RoboMate'; InstallLocation = $InstallDir; DisplayIcon = (Join-Path $InstallDir 'moncastle.ico'); NoModify = 1; NoRepair = 0
            UninstallString = $(if (Test-Path $setup) { "`"$setup`" /uninstall" } else { "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\launcher\Install-MonCastle.ps1`" -Uninstall -InstallDir `"$InstallDir`"" }) }
        foreach ($p in $props.GetEnumerator()) { New-ItemProperty -Path $UninstallKey -Name $p.Key -Value $p.Value -Force | Out-Null }
        'Start menu: RoboMate MonCastle'
    } -Optional
}

if (-not $NoService) {
    Invoke-Step 'verify' 'Wait for the console to answer' {
        try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
        $deadline = (Get-Date).AddSeconds(60)
        do { try { if ((Invoke-RestMethod "https://localhost:$Port/api/status" -TimeoutSec 3).product -eq 'RoboMate MonCastle') { return "Console ready at https://${PublicName}:$Port/" } } catch { }; Start-Sleep -Seconds 2 } while ((Get-Date) -lt $deadline)
        throw "the console did not answer on port $Port within 60 seconds (see $InstallDir\data\logs)"
    } -Optional
}
Step 'done' $(if ($script:Failed) { 'fail' } else { 'ok' }) $(if ($script:Failed) { "Setup finished with $($script:Failed) problem(s). Log: $LogFile" } else { "MonCastle is installed. Open https://${PublicName}:$Port/" })
