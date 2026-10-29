param([Parameter(Mandatory=$true)][string]$SetupExe)
$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true') { throw 'Installer smoke tests require an isolated GitHub Actions runner.' }
$fixture = Join-Path $env:RUNNER_TEMP ('portsync-smoke-' + [guid]::NewGuid().ToString('N'))
$env:APPDATA = Join-Path $fixture 'Roaming'
$env:LOCALAPPDATA = Join-Path $fixture 'Local'
$qbitFolder = Join-Path $env:APPDATA 'qBittorrent'
$logFolder = Join-Path $env:LOCALAPPDATA 'Proton\Proton VPN\Logs'
New-Item -ItemType Directory -Path $qbitFolder,$logFolder -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $qbitFolder 'qBittorrent.ini'), "[BitTorrent]`r`nSession\Interface=iftype53_test`r`nSession\InterfaceName=ProtonVPN`r`nSession\Port=12345`r`n[Preferences]`r`nWebUI\Enabled=false`r`n")
[IO.File]::WriteAllText((Join-Path $logFolder 'client-logs.txt'), '')
$app = Join-Path $fixture 'App'
$runtime = Join-Path $env:LOCALAPPDATA 'ProtonQbitPortSync'
$exe = (Resolve-Path $SetupExe).Path
function Run-Setup([string]$LogName) {
    $log = Join-Path $fixture $LogName
    $process = Start-Process -FilePath $exe -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="' + $app + '" /LOG="' + $log + '"') -WindowStyle Hidden -PassThru
    if (!$process.WaitForExit(90000)) { throw 'Installer process timed out.' }
    if ($process.ExitCode -ne 0) { Get-Content $log -Tail 50; throw "Installer failed: $($process.ExitCode)" }
}
Run-Setup 'fresh.log'
if (!(Test-Path (Join-Path $runtime 'config.json')) -or !(Test-Path (Join-Path $app 'unins000.exe'))) { throw 'Fresh install did not create configuration and native uninstaller.' }
$credentialHash = (Get-FileHash (Join-Path $runtime 'credential.xml')).Hash
$configBefore = Get-Content (Join-Path $runtime 'config.json') -Raw
Run-Setup 'upgrade.log'
if ((Get-FileHash (Join-Path $runtime 'credential.xml')).Hash -ne $credentialHash) { throw 'Upgrade changed encrypted credentials.' }
if ((Get-Content (Join-Path $runtime 'config.json') -Raw) -ne $configBefore) { throw 'Upgrade changed user configuration.' }
$uninstall = Start-Process -FilePath (Join-Path $app 'unins000.exe') -ArgumentList '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART' -WindowStyle Hidden -PassThru
if (!$uninstall.WaitForExit(90000)) { throw 'Uninstaller process timed out.' }
if ($uninstall.ExitCode -ne 0) { throw 'Native uninstall failed.' }
$shortcut = Join-Path ([Environment]::GetFolderPath('Startup')) 'Proton qBittorrent Port Sync.lnk'
if (Test-Path $shortcut) { throw 'Startup shortcut remained after uninstall.' }
if (!(Test-Path (Join-Path $runtime 'config.json'))) { throw 'Uninstall unexpectedly removed retained user configuration.' }
Write-Output 'Passed native installer smoke tests: fresh install, credential-preserving upgrade, native uninstall, startup removal, and retained settings.'
