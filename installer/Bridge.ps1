#requires -Version 5.1
param([ValidateSet('Check','Install','Uninstall')][string]$Mode, [string]$ErrorFile)
$ErrorActionPreference = 'Stop'
# A setup launched from PowerShell 7 can inherit its module search path.
# Use the Windows PowerShell engine's own modules for Windows PowerShell 5.1.
$env:PSModulePath = Join-Path $PSHOME 'Modules'
$root = Join-Path $env:LOCALAPPDATA 'ProtonQbitPortSync'
try {
    if ($Mode -eq 'Uninstall') {
        if (Test-Path (Join-Path $root 'config.json')) { & (Join-Path $root 'Uninstall.ps1') }
        exit 0
    }
    Import-Module (Join-Path $PSScriptRoot 'PortSync.psm1') -Force
    if (Get-Process -Name qbittorrent -ErrorAction SilentlyContinue) { throw 'Please exit qBittorrent completely, including its tray icon, then click Install again.' }
    $configPath = Join-Path $root 'config.json'
    if (Test-Path $configPath) {
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        if ($config.SchemaVersion -ne 1 -or !(Test-Path (Join-Path $root 'credential.xml'))) { throw 'The existing installation is incomplete. See the README for recovery instructions.' }
        if ($Mode -eq 'Check') { exit 0 }
        # Update the scripts while preserving this user's credentials and settings.
        & (Join-Path $root 'Uninstall.ps1')
        foreach ($file in @('PortSync.psm1','Watch-Port.ps1','Uninstall.ps1')) { Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $root -Force }
        $engine = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Startup')) 'Proton qBittorrent Port Sync.lnk'))
        $shortcut.TargetPath = $engine
        $shortcut.Arguments = '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -WindowStyle Hidden -File "' + (Join-Path $root 'Watch-Port.ps1') + '"'
        $shortcut.WorkingDirectory = $root; $shortcut.WindowStyle = 7; $shortcut.Save()
        Start-Process -FilePath $engine -ArgumentList $shortcut.Arguments -WindowStyle Hidden
        exit 0
    }
    $iniPath = Join-Path $env:APPDATA 'qBittorrent\qBittorrent.ini'
    if (!(Test-Path $iniPath)) { throw 'qBittorrent settings were not found. Install and open qBittorrent once before installing Port Sync.' }
    $ini = [IO.File]::ReadAllText($iniPath)
    $adapter = Get-IniValue $ini 'BitTorrent' 'Session\InterfaceName'
    $binding = Get-IniValue $ini 'BitTorrent' 'Session\Interface'
    if ($adapter -notmatch '(?i)proton' -or [string]::IsNullOrWhiteSpace($binding) -or $binding -eq '0') { throw 'In qBittorrent, open Tools > Options > Advanced and select the Proton VPN network interface. Then exit qBittorrent and retry.' }
    if ((Get-IniValue $ini 'Preferences' 'WebUI\Enabled') -eq 'true') { throw 'An existing qBittorrent Web UI was detected. This wizard will not overwrite its credentials. Use the ZIP installer to reuse your existing Web UI login.' }
    if (!(Test-Path (Join-Path $env:LOCALAPPDATA 'Proton\Proton VPN\Logs\client-logs.txt'))) { throw 'Open Proton VPN once and enable port forwarding, then retry installation.' }
    if (Get-NetTCPConnection -LocalPort 18765 -State Listen -ErrorAction SilentlyContinue) { throw 'Local port 18765 is already in use. Use the ZIP installer to select a different API port.' }
    if ($Mode -eq 'Install') { & (Join-Path $PSScriptRoot 'Install.ps1') -AdapterName $adapter }
} catch {
    if ($ErrorFile) { [IO.File]::WriteAllText($ErrorFile, $_.Exception.Message, [Text.UTF8Encoding]::new($false)) }
    exit 1
}
