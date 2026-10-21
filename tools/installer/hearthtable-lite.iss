; Compiled only from the tested player payload and a clean git source archive.
#ifndef ProductVersion
  #error ProductVersion is required
#endif
#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
[Setup]
AppId={{01CA6C5C-5407-4A80-80AD-A7C70B4FB60D}
AppName=Hearthtable Lite
AppVersion={#ProductVersion}
AppPublisher=WonderingMage
AppPublisherURL=https://github.com/WonderingMage/Hearthtable
DefaultDirName={pf32}\Hearthtable Lite
DefaultGroupName=Hearthtable Lite
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Hearthtable-Lite-{#ProductVersion}-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
LicenseFile={#PayloadDir}\Source\{#ProductVersion}\LICENSE.txt
UninstallDisplayIcon={app}\Hearthtable Lite.exe
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
#ifdef SigningEnabled
SignTool=hearthsign
SignedUninstaller=yes
#endif
[Files]
Source: "{#PayloadDir}\Hearthtable_Lite_Portable.exe"; DestDir: "{app}"; DestName: "Hearthtable Lite.exe"; Flags: ignoreversion
Source: "{#PayloadDir}\Source\{#ProductVersion}\*"; DestDir: "{app}\Source\{#ProductVersion}"; Flags: ignoreversion recursesubdirs createallsubdirs
[Icons]
Name: "{commondesktop}\Hearthtable Lite"; Filename: "{app}\Hearthtable Lite.exe"; WorkingDir: "{app}"; Comment: "DM-led fifth edition virtual tabletop"
Name: "{group}\Hearthtable Lite"; Filename: "{app}\Hearthtable Lite.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall Hearthtable Lite"; Filename: "{uninstallexe}"
[Run]
Filename: "{app}\Hearthtable Lite.exe"; Description: "Launch Hearthtable Lite"; Flags: nowait postinstall skipifsilent runasoriginaluser
; AppData is deliberately absent from Files/Dirs/UninstallDelete: saves, scene
; caches, verified updates and rollback backups survive install and uninstall.
