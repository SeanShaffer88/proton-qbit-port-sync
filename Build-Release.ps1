#requires -Version 5.1
param([ValidatePattern('^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$')][string]$Version = '0.2.0', [string]$OutputDirectory = (Join-Path $PSScriptRoot 'dist'))
$ErrorActionPreference = 'Stop'
$files = @('Install.cmd','Setup.ps1','Install.ps1','Watch-Port.ps1','Uninstall.ps1','PortSync.psm1','README.md','LICENSE')
foreach ($file in $files) { if (!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $file))) { throw "Missing release file: $file" } }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$zip = Join-Path $OutputDirectory "proton-qbit-port-sync-$Version-windows.zip"
Compress-Archive -LiteralPath @($files | ForEach-Object { Join-Path $PSScriptRoot $_ }) -DestinationPath $zip -Force
$artifacts = @($zip)
$setup = Join-Path $OutputDirectory "proton-qbit-port-sync-$Version-setup.exe"
if (Test-Path $setup) { $artifacts += $setup }
$sums = foreach ($artifact in $artifacts) {
    $hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $([IO.Path]::GetFileName($artifact))"
}
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'SHA256SUMS.txt'), (($sums -join "`n") + "`n"), [Text.UTF8Encoding]::new($false))
Write-Output $zip
