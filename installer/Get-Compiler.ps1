$ErrorActionPreference = 'Stop'
$version = '7.1.1'
$expected = '8a5a6711c3766a6e5fb74f280ba0e3551e719ce94538d901fdbd1f8f9920b3f0'
$tools = Join-Path ([IO.Path]::GetTempPath()) 'portsync-build-tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null
$setup = Join-Path $tools 'innosetup.exe'
Invoke-WebRequest -Uri "https://github.com/jrsoftware/issrc/releases/download/is-7_1_1/innosetup-$version-x64.exe" -OutFile $setup
if ((Get-FileHash $setup -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Compiler download checksum mismatch.' }
$destination = Join-Path $tools 'InnoSetup'
$process = Start-Process -FilePath $setup -ArgumentList ('/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /NOICONS /DIR="' + $destination + '"') -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "Compiler installation failed: $($process.ExitCode)" }
Write-Output (Join-Path $destination 'ISCC.exe')
