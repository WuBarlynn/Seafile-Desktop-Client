#define MyAppName "Seafile"
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif
#ifndef MyAppArch
  #define MyAppArch "x64"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{7C8E4D3A-2F6B-4C1D-9A5E-1B0F3D6A9C42}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher=Seafile
AppPublisherURL=https://www.seafile.com/
AppSupportURL=https://forum.seafile.com/
DefaultDirName={autopf}\Seafile
DefaultGroupName=Seafile
DisableProgramGroupPage=yes
DisableDirPage=auto
OutputDir={#OutputDir}
OutputBaseFilename=Seafile-{#MyAppVersion}-windows-{#MyAppArch}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\seafile_desktop.exe
PrivilegesRequired=admin
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Seafile"; Filename: "{app}\seafile_desktop.exe"
Name: "{autodesktop}\Seafile"; Filename: "{app}\seafile_desktop.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\seafile_desktop.exe"; Description: "Launch Seafile"; Flags: nowait postinstall skipifsilent
