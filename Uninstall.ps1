#requires -Version 5.1
[CmdletBinding()]
param([switch]$RestoreWebUI)
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:LOCALAPPDATA 'ProtonQbitPortSync'
$configFile = Join-Path $root 'config.json'
if (!(Test-Path $configFile)) { throw 'No installation found.' }
$config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json
if ($RestoreWebUI -and (Get-Process -Name qbittorrent -ErrorAction SilentlyContinue)) { throw 'Exit qBittorrent before restoring Web UI settings.' }
Get-CimInstance Win32_Process | Where-Object {
    $_.Name -in @('powershell.exe','pwsh.exe') -and $_.CommandLine -like ('*' + (Join-Path $root 'Watch-Port.ps1') + '*')
} | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
$link = Join-Path ([Environment]::GetFolderPath('Startup')) 'Proton qBittorrent Port Sync.lnk'
if (Test-Path -LiteralPath $link) { Remove-Item -LiteralPath $link }
if ($RestoreWebUI -and $config.ConfiguredWebUI) {
    Import-Module (Join-Path $root 'PortSync.psm1') -Force
    $ini = [IO.File]::ReadAllText($config.QbitConfigPath)
    # This installer only enables Web UI when it was previously disabled.
    # Disable it again without rolling back torrents, port, or unrelated preferences.
    $ini = Set-IniValues $ini 'Preferences' @{ 'WebUI\Enabled' = 'false' }
    [IO.File]::WriteAllText($config.QbitConfigPath, $ini, [Text.UTF8Encoding]::new($false))
}
Write-Output "Watcher stopped and startup removed. Runtime files and backup retained in $root."
Write-Output 'Remove that directory manually if you no longer need its encrypted credential and backup.'
