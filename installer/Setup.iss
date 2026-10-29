#ifndef AppVersion
  #define AppVersion "0.2.0"
#endif
[Setup]
AppId={{048FA788-B2EC-4CA3-9A4C-2B538835CB98}
AppName=Proton qBittorrent Port Sync
AppVersion={#AppVersion}
AppPublisher=Sean Shaffer
AppPublisherURL=https://github.com/SeanShaffer88/proton-qbit-port-sync
AppSupportURL=https://github.com/SeanShaffer88/proton-qbit-port-sync/issues
DefaultDirName={localappdata}\Programs\ProtonQbitPortSync
DisableDirPage=yes
DefaultGroupName=Proton qBittorrent Port Sync
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
MinVersion=10.0
WizardStyle=modern
LicenseFile=..\LICENSE
OutputDir=..\dist
OutputBaseFilename=proton-qbit-port-sync-{#AppVersion}-setup
Compression=lzma2
SolidCompression=yes
UninstallDisplayName=Proton qBittorrent Port Sync
CloseApplications=no
SetupLogging=yes
InfoBeforeFile=Requirements.txt

[Files]
Source: "..\Install.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\PortSync.psm1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Watch-Port.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Uninstall.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Bridge.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\README.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\PortSync.psm1"; Flags: dontcopy
Source: "Bridge.ps1"; Flags: dontcopy

[Icons]
Name: "{group}\Uninstall Port Sync"; Filename: "{uninstallexe}"
Name: "{group}\Project and help"; Filename: "https://github.com/SeanShaffer88/proton-qbit-port-sync"

[UninstallRun]
Filename: "{sys}\WindowsPowerShell\v1.0\powershell.exe"; Parameters: "-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File ""{app}\Bridge.ps1"" -Mode Uninstall"; Flags: runhidden waituntilterminated; RunOnceId: "StopPortSync"

[Code]
function RunBridge(const Directory, Mode: String; var Detail: String): Boolean;
var ExitCode: Integer; ErrorFile, Args: String; ErrorText: AnsiString;
begin
  ErrorFile := ExpandConstant('{tmp}\portsync-error.txt');
  DeleteFile(ErrorFile);
  Args := '-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File "' + Directory + '\Bridge.ps1" -Mode ' + Mode + ' -ErrorFile "' + ErrorFile + '"';
  Result := Exec(ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe'), Args, Directory, SW_HIDE, ewWaitUntilTerminated, ExitCode);
  Result := Result and (ExitCode = 0);
  if not Result then begin
    Detail := 'Setup could not configure Port Sync. Your Windows organization policy may restrict PowerShell. See the setup log for details.';
    if LoadStringFromFile(ErrorFile, ErrorText) then Detail := String(ErrorText);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var Detail: String;
begin
  ExtractTemporaryFile('PortSync.psm1');
  ExtractTemporaryFile('Bridge.ps1');
  if not RunBridge(ExpandConstant('{tmp}'), 'Check', Detail) then Result := Detail;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var Detail: String;
begin
  if CurStep = ssPostInstall then
    if not RunBridge(ExpandConstant('{app}'), 'Install', Detail) then RaiseException(Detail);
end;
