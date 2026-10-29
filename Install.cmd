@echo off
setlocal
title Proton qBittorrent Port Sync Setup
set "PROTON_QBIT_SETUP_ROOT=%~dp0"
echo Proton qBittorrent Port Sync
echo.
echo This installs the scripts included in this extracted release folder.
echo Continue only if you downloaded it from SeanShaffer88/proton-qbit-port-sync.
echo.
choice /C YN /N /M "Run setup? [Y/N] "
if errorlevel 2 exit /b 0
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -Command "$ErrorActionPreference='Stop'; try { foreach($name in @('Setup.ps1','Install.ps1','Watch-Port.ps1','Uninstall.ps1','PortSync.psm1')) { Unblock-File -LiteralPath (Join-Path $env:PROTON_QBIT_SETUP_ROOT $name) }; & (Join-Path $env:PROTON_QBIT_SETUP_ROOT 'Setup.ps1') } catch { Write-Host ('Setup failed: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }"
set "SETUP_RESULT=%ERRORLEVEL%"
echo.
pause
exit /b %SETUP_RESULT%
