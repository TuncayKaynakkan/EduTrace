#Requires -Version 5
<#
  EduTrace release build:
    1. Backend  -> installer\build\backend\EduTraceEngine.exe (PyInstaller, UAC admin)
    2. Frontend -> flutter build windows --release
    3. Installer -> installer\Output\EduTrace-Setup-<version>.exe (Inno Setup 6)
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host '== 1/3 Backend (PyInstaller) ==' -ForegroundColor Cyan
Set-Location "$root\backend"
python -m pip install -q -r requirements.txt pyinstaller
python -m PyInstaller --noconfirm --clean --onedir --noconsole --name EduTraceEngine `
  --collect-submodules engineio --collect-submodules socketio `
  --collect-all scapy --hidden-import sklearn.ensemble --hidden-import google.genai `
  --distpath "$root\installer\build" --workpath "$root\installer\build\work" `
  --icon "$root\flutter_application_1\windows\runner\resources\app_icon.ico" `
  --specpath "$root\installer\build" edutrace_ultimate.py
if ($LASTEXITCODE -ne 0) { throw 'PyInstaller failed' }

Write-Host '== 2/3 Flutter (Windows release) ==' -ForegroundColor Cyan
Set-Location "$root\flutter_application_1"
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }

Write-Host '== 3/3 Installer (Inno Setup) ==' -ForegroundColor Cyan
$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 not found. Install: winget install JRSoftware.InnoSetup' }
& $iscc "$root\installer\edutrace.iss"
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup failed' }
Write-Host 'Done -> installer\Output' -ForegroundColor Green
