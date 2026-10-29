#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$QbitConfigPath = (Join-Path $env:APPDATA 'qBittorrent\qBittorrent.ini'),
    [string]$ProtonLogPath = (Join-Path $env:LOCALAPPDATA 'Proton\Proton VPN\Logs\client-logs.txt'),
    [string]$AdapterName = 'ProtonVPN',
    [ValidateRange(1024,65535)][int]$ApiPort = 18765,
    [ValidateRange(5,60)][int]$PollSeconds = 10,
    [pscredential]$ExistingWebUICredential,
    [switch]$NoStart
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'This installer supports Windows only.' }
Import-Module (Join-Path $PSScriptRoot 'PortSync.psm1') -Force
if (Get-Process -Name qbittorrent -ErrorAction SilentlyContinue) { throw 'Exit qBittorrent completely (including the tray icon), then retry.' }
$root = Join-Path $env:LOCALAPPDATA 'ProtonQbitPortSync'
if (Test-Path (Join-Path $root 'config.json')) { throw 'Already installed. Uninstall with -RestoreWebUI, then move the retained runtime directory aside before reinstalling.' }
$ini = [IO.File]::ReadAllText($QbitConfigPath)
$binding = Get-IniValue $ini 'BitTorrent' 'Session\Interface'
$interfaceName = Get-IniValue $ini 'BitTorrent' 'Session\InterfaceName'
if ([string]::IsNullOrWhiteSpace($binding) -or $binding -eq '0' -or $interfaceName -ne $AdapterName) {
    throw "Bind qBittorrent to '$AdapterName' in Options > Advanced > Network interface first."
}
if (!(Test-Path -LiteralPath $ProtonLogPath)) { throw 'Proton log not found. Open Proton VPN, or supply -ProtonLogPath.' }
$webEnabled = (Get-IniValue $ini 'Preferences' 'WebUI\Enabled') -eq 'true'
if ($webEnabled -and !$ExistingWebUICredential) { throw 'Web UI already enabled. Supply -ExistingWebUICredential (Get-Credential) and its -ApiPort. Existing credentials will not be overwritten.' }
if (!$webEnabled -and $ExistingWebUICredential) { throw 'ExistingWebUICredential requires an already enabled Web UI.' }
if ($webEnabled -and ((Get-IniValue $ini 'Preferences' 'WebUI\Address') -ne '127.0.0.1' -or [int](Get-IniValue $ini 'Preferences' 'WebUI\Port') -ne $ApiPort)) {
    throw 'Existing Web UI must listen only on 127.0.0.1 at -ApiPort. Configure it in qBittorrent first.'
}
if (Get-NetTCPConnection -LocalPort $ApiPort -State Listen -ErrorAction SilentlyContinue) { throw 'API port is already in use.' }
New-Item -ItemType Directory -Path $root -Force | Out-Null
# Restrict runtime files, including the encrypted credential, to this Windows user and SYSTEM.
$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
& icacls.exe $root /inheritance:r /grant:r "*${sid}:(OI)(CI)F" '*S-1-5-18:(OI)(CI)F' | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to restrict runtime directory permissions.' }
Copy-Item -LiteralPath $QbitConfigPath -Destination (Join-Path $root 'qBittorrent.before-install.ini')
$credential = $ExistingWebUICredential
if (!$webEnabled) {
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 32; $rng.GetBytes($bytes)
    $password = [Convert]::ToBase64String($bytes)
    $salt = New-Object byte[] 16; $rng.GetBytes($salt); $rng.Dispose()
    $derive = [Security.Cryptography.Rfc2898DeriveBytes]::new($password, $salt, 100000, [Security.Cryptography.HashAlgorithmName]::SHA512)
    $hash = [Convert]::ToBase64String($salt) + ':' + [Convert]::ToBase64String($derive.GetBytes(64)); $derive.Dispose()
    $credential = [pscredential]::new('portsync', (ConvertTo-SecureString $password -AsPlainText -Force))
    $ini = Set-IniValues $ini 'Preferences' ([ordered]@{
        'WebUI\Enabled' = 'true'; 'WebUI\Address' = '127.0.0.1'; 'WebUI\Port' = "$ApiPort"
        'WebUI\Username' = 'portsync'; 'WebUI\Password_PBKDF2' = ('"@ByteArray(' + $hash + ')"')
        'WebUI\LocalHostAuth' = 'true'; 'WebUI\AuthSubnetWhitelistEnabled' = 'false'
        'WebUI\UseUPnP' = 'false'
    })
    [IO.File]::WriteAllText($QbitConfigPath, $ini, [Text.UTF8Encoding]::new($false))
    $password = $null
}
$credential | Export-Clixml -LiteralPath (Join-Path $root 'credential.xml')
@{
    SchemaVersion = 1; ProtonLogPath = $ProtonLogPath; AdapterName = $AdapterName
    BaseUrl = "http://127.0.0.1:$ApiPort"; PollSeconds = $PollSeconds; ExpectedInterface = $binding
    QbitConfigPath = $QbitConfigPath; ConfiguredWebUI = !$webEnabled
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'config.json') -Encoding UTF8
foreach ($file in @('PortSync.psm1','Watch-Port.ps1','Uninstall.ps1')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $root -Force }
$engine = Join-Path $PSHOME 'powershell.exe'
if ($PSVersionTable.PSEdition -eq 'Core') { $engine = Join-Path $PSHOME 'pwsh.exe' }
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Proton qBittorrent Port Sync.lnk'))
$shortcut.TargetPath = $engine
$shortcut.Arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -File "' + (Join-Path $root 'Watch-Port.ps1') + '"'
$shortcut.WorkingDirectory = $root; $shortcut.WindowStyle = 7; $shortcut.Save()
if (!$NoStart) { Start-Process -FilePath $engine -ArgumentList $shortcut.Arguments -WindowStyle Hidden }
Write-Output "Installed in $root. Starts at sign-in; waits until Proton VPN and qBittorrent are running."
