; EduTrace installer (Inno Setup 6)
#define AppName "EduTrace"
#define AppVersion "1.0.0"
#define AppPublisher "EduTrace"

[Setup]
AppId={{B7C2D6E4-3F1A-4E58-9A21-ED07ACE00001}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir=Output
OutputBaseFilename=EduTrace-Setup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
WizardStyle=modern
UninstallDisplayName={#AppName}
SetupIconFile=..\flutter_application_1\windows\runner\resources\app_icon.ico
UninstallIconFile=..\flutter_application_1\windows\runner\resources\app_icon.ico

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstü kısayolu oluştur"; GroupDescription: "Ek görevler:"

[Dirs]
Name: "{commonappdata}\EduTrace"; Permissions: users-modify

[Files]
Source: "build\EduTraceEngine\*"; DestDir: "{app}\engine"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\flutter_application_1\build\windows\x64\runner\Release\*"; DestDir: "{app}\app"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\backend\.env.example"; DestDir: "{commonappdata}\EduTrace"; DestName: ".env"; Flags: onlyifdoesntexist uninsneveruninstall

[Icons]
Name: "{group}\EduTrace"; Filename: "{app}\app\EduTrace.exe"
Name: "{group}\EduTrace Motoru (Yonetici)"; Filename: "{app}\engine\EduTraceEngine.exe"; WorkingDir: "{app}\engine"
Name: "{group}\Ayar dosyasi (.env)"; Filename: "notepad.exe"; Parameters: """{commonappdata}\EduTrace\.env"""
Name: "{group}\{#AppName} Kaldir"; Filename: "{uninstallexe}"
Name: "{autodesktop}\EduTrace"; Filename: "{app}\app\EduTrace.exe"; Tasks: desktopicon

[Run]
Filename: "schtasks"; Parameters: "/Create /TN ""EduTraceEngine"" /TR """"{app}\engine\EduTraceEngine.exe"""" /SC ONLOGON /RL HIGHEST /F"; Flags: runhidden
Filename: "https://npcap.com/#download"; Description: "Npcap indir (paket yakalama surucusu)"; Flags: postinstall shellexec skipifsilent; Check: not IsNpcapInstalled
Filename: "{app}\engine\EduTraceEngine.exe"; Description: "EduTrace motorunu baslat"; Flags: postinstall nowait skipifsilent runascurrentuser
Filename: "{app}\app\EduTrace.exe"; Description: "EduTrace panelini ac"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "schtasks"; Parameters: "/Delete /TN ""EduTraceEngine"" /F"; Flags: runhidden
Filename: "taskkill"; Parameters: "/F /IM EduTraceEngine.exe"; Flags: runhidden

[Code]
function IsNpcapInstalled(): Boolean;
begin
  Result := FileExists(ExpandConstant('{sys}\Npcap\wpcap.dll')) or 
            FileExists(ExpandConstant('{sys}\wpcap.dll')) or
            RegKeyExists(HKLM, 'SYSTEM\CurrentControlSet\Services\npcap');
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ErrorCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    if not IsNpcapInstalled() then
    begin
      if MsgBox('EduTrace ağ trafiğini ve tehditleri analiz edebilmek için Npcap sürücüsüne ihtiyaç duyar.' + #13#10 + #13#10 +
                'Bilgisayarınızda Npcap tespit edilemedi. Şimdi resmi indirme sayfasını açmak ister misiniz?', 
                mbConfirmation, MB_YESNO) = IDYES then
      begin
        ShellExec('open', 'https://npcap.com/#download', '', '', SW_SHOWNORMAL, ewNoWait, ErrorCode);
      end;
    end;
  end;
end;
