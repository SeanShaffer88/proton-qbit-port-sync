#requires -Version 5.1
param([string]$DataDirectory = (Join-Path $env:LOCALAPPDATA 'ProtonQbitPortSync'), [switch]$Once)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'PortSync.psm1') -Force
$config = Get-Content -LiteralPath (Join-Path $DataDirectory 'config.json') -Raw | ConvertFrom-Json
$credential = Import-Clixml -LiteralPath (Join-Path $DataDirectory 'credential.xml')
$mutex = [Threading.Mutex]::new($false, 'Local\ProtonQbitPortSync')
if (!$mutex.WaitOne(0)) { exit }
$lastMessage = ''
function Write-Status([string]$Message) {
    if ($Message -eq $script:lastMessage) { return }
    $script:lastMessage = $Message
    $log = Join-Path $DataDirectory 'sync.log'
    if ((Test-Path $log) -and (Get-Item $log).Length -gt 262144) { Move-Item -LiteralPath $log -Destination ($log + '.previous') -Force }
    Add-Content -LiteralPath $log -Value ((Get-Date -Format o) + ' ' + $Message)
    if ($Once) { Write-Output $Message }
}
try {
    do {
        try {
            $vpn = Get-NetAdapter -Name $config.AdapterName -ErrorAction SilentlyContinue
            if (!$vpn -or $vpn.Status -ne 'Up' -or !(Get-Process -Name qbittorrent -ErrorAction SilentlyContinue)) {
                Write-Status 'Waiting for connected VPN and running qBittorrent.'
            } else {
                $port = Get-ProtonForwardedPort -Lines (Get-Content -LiteralPath $config.ProtonLogPath -Tail 500)
                if (!$port) { Write-Status 'Waiting for a fresh successful Proton port-forwarding lease.' }
                else {
                    $changed = Invoke-QbitPortSync -BaseUrl $config.BaseUrl -Credential $credential -Port $port -ExpectedInterface $config.ExpectedInterface
                    if ($changed) { Write-Status "Updated and verified torrent port $port; VPN binding preserved." }
                    else { Write-Status "Torrent port $port matches Proton VPN." }
                }
            }
        } catch { Write-Status ('Sync deferred: ' + $_.Exception.Message) }
        if (!$Once) { Start-Sleep -Seconds $config.PollSeconds }
    } while (!$Once)
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
