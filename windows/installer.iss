; Per-user GitPulse installer. Keep AppId stable across upgrades.
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Never change the AppId: it is how Windows knows a new version is the same
; app and updates it in place. Also referenced by windows/package-manifests.py
; as PRODUCT_CODE (AppId + "_is1") — keep the two in step.
AppId={{302D74EA-C6EF-4F3F-B7DA-377E938CAC27}
AppName=GitPulse
AppVersion={#AppVersion}
AppVerName=GitPulse {#AppVersion}
AppPublisher=Muddyblack
AppPublisherURL=https://github.com/Muddyblack/kde-gitpulse
AppSupportURL=https://github.com/Muddyblack/kde-gitpulse/issues
DefaultDirName={autopf}\GitPulse
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..
OutputBaseFilename=GitPulse-Setup-{#AppVersion}
SetupIconFile=..\dist\gitpulse.ico
UninstallDisplayIcon={app}\GitPulse.exe
UninstallDisplayName=GitPulse
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The running app is stopped in [Code] instead of by the Restart Manager,
; which would ask the user about a tray app with no window to close.
CloseApplications=no

[Tasks]
; Offered on a first install only. On an update it would apply the choice
; remembered from that install, turning autostart back on for someone who had
; switched it off since; left out, the Run value stays as it is.
Name: "autostart"; Description: "Start GitPulse when I sign in"; Flags: unchecked; Check: not IsUpgrade
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\dist\GitPulse\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; An update replaces the whole bundle: files a new PyInstaller build no
; longer has must not linger next to the ones it does.
Type: filesandordirs; Name: "{app}\_internal"

[Icons]
Name: "{autoprograms}\GitPulse"; Filename: "{app}\GitPulse.exe"
Name: "{autodesktop}\GitPulse"; Filename: "{app}\GitPulse.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "GitPulse"; ValueData: """{app}\GitPulse.exe"""; Tasks: autostart
; Removed on uninstall whichever of the two turned it on.
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: none; ValueName: "GitPulse"; Flags: uninsdeletevalue

[Run]
Filename: "{app}\GitPulse.exe"; Description: "{cm:LaunchProgram,GitPulse}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM ""GitPulse.exe"""; Flags: runhidden; RunOnceId: "StopGitPulse"

[Code]
var
  WasRunning: Boolean;

// An earlier install is there: its uninstaller is registered under AppId
// (with the doubled brace undone) plus "_is1". Keep the GUID in step with
// AppId above and with PRODUCT_CODE in windows/package-manifests.py.
function IsUpgrade: Boolean;
var
  Uninstaller: String;
begin
  Result := RegQueryStringValue(HKCU, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{302D74EA-C6EF-4F3F-B7DA-377E938CAC27}_is1', 'UninstallString', Uninstaller);
end;

// Stop a running copy before its files are replaced. taskkill exits 0 when it
// stopped something and 128 when nothing was running.
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  WasRunning := Exec(ExpandConstant('{sys}\taskkill.exe'), '/F /IM "GitPulse.exe"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) and (ResultCode = 0);
  Result := '';
end;

// A silent update (/SILENT, winget) skips the [Run] entry's checkbox, which
// would leave the app stopped until the next sign-in: start it again when it
// was running before.
procedure CurStepChanged(CurStep: TSetupStep);
var
  ResultCode: Integer;
begin
  if (CurStep = ssPostInstall) and WizardSilent and WasRunning then
    ExecAsOriginalUser(ExpandConstant('{app}\GitPulse.exe'), '', '', SW_SHOWNORMAL, ewNoWait, ResultCode);
end;
