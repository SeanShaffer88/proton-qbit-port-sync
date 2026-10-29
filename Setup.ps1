#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Write-Host ''
Write-Host 'Proton qBittorrent Port Sync - Setup' -ForegroundColor Cyan
Write-Host '-----------------------------------'
Write-Host 'Before installing:'
Write-Host '  1. Enable port forwarding in your paid Proton VPN app.'
Write-Host '  2. In qBittorrent > Options > Advanced, select the ProtonVPN network interface.'
Write-Host '  3. Exit qBittorrent completely, including its tray icon.'
Write-Host ''
Write-Host 'Setup installs a hidden watcher for your Windows account and starts it at sign-in.'
Write-Host 'Its authenticated qBittorrent API listens only on this PC. No administrator rights needed.'
Write-Host ''
if ((Read-Host 'Ready to install? [Y/N]') -notmatch '^(?i)y(es)?$') { Write-Host 'Setup cancelled.'; return }
$configPath = Join-Path $env:APPDATA 'qBittorrent\qBittorrent.ini'
$logPath = Join-Path $env:LOCALAPPDATA 'Proton\Proton VPN\Logs\client-logs.txt'
Import-Module (Join-Path $PSScriptRoot 'PortSync.psm1') -Force
$options = @{}
if (Test-Path -LiteralPath $configPath) {
    $ini = [IO.File]::ReadAllText($configPath)
    $adapter = Get-IniValue $ini 'BitTorrent' 'Session\InterfaceName'
    if ($adapter -match '(?i)proton') { $options.AdapterName = $adapter }
    if ((Get-IniValue $ini 'Preferences' 'WebUI\Enabled') -eq 'true') {
        Write-Host 'Your existing Web UI will be used; its settings will not be replaced.'
        Write-Host 'It must be configured to listen only on 127.0.0.1.'
        $options.ApiPort = [int](Get-IniValue $ini 'Preferences' 'WebUI\Port')
        $options.ExistingWebUICredential = Get-Credential -Message 'Enter your existing qBittorrent Web UI login'
    }
}
& (Join-Path $PSScriptRoot 'Install.ps1') @options
Write-Host ''
Write-Host 'Installation complete. Open qBittorrent normally.' -ForegroundColor Green
Write-Host 'The watcher updates the incoming port automatically while both apps are running.'
