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

# The closed-source Pro add-on lives in a private repo next to this one
# (or wherever EDUTRACE_PRO points). Without it the build is the free edition.
$proDir = if ($env:EDUTRACE_PRO) { $env:EDUTRACE_PRO } else { Join-Path (Split-Path -Parent $root) 'EduTrace-Pro' }
$proArgs = @()
if (Test-Path (Join-Path $proDir 'edutrace_pro\__init__.py')) {
  Write-Host "   Pro eklentisi ekleniyor: $proDir" -ForegroundColor Yellow
  python -m pip install -q -r (Join-Path $proDir 'requirements.txt')
  $proArgs = @('--paths', $proDir, '--hidden-import', 'edutrace_pro', '--collect-submodules', 'edutrace_pro',
               '--collect-all', 'reportlab')
} else {
  Write-Host '   Pro eklentisi bulunamadi: ucretsiz surum derleniyor.' -ForegroundColor Yellow
}

# --noupx: UPX-packed binaries that sniff traffic and change the firewall are a classic
# antivirus false positive; the size saving is not worth it.
python -m PyInstaller --noconfirm --clean --onedir --noconsole --noupx --name EduTraceEngine `
  --collect-submodules engineio --collect-submodules socketio `
  --collect-all scapy --hidden-import sklearn.ensemble --hidden-import google.genai `
  @proArgs `
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
