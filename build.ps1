# Builds PCTracker.exe (single file, no console window).
#   powershell -ExecutionPolicy Bypass -File .\build.ps1
#
# PyInstaller's scratch directories are kept outside OneDrive: syncing clients
# lock files mid-build and cause random "Access is denied" failures.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
    Write-Host "==> creating virtual environment"
    python -m venv "$root\.venv"
    & $python -m pip install --upgrade pip --quiet
    & $python -m pip install -r "$root\requirements.txt" --quiet
}

$work = Join-Path $env:TEMP "pctracker-pyinstaller"
if (Test-Path $work) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }

New-Item -ItemType Directory -Force -Path "$root\assets" | Out-Null
& $python -c "from pctracker.icon import save_ico; save_ico(r'$root\assets\pctracker.ico')"

Write-Host "==> compiling"
& $python -m compileall -q "$root\pctracker" "$root\run.py"
if ($LASTEXITCODE -ne 0) { throw "compileall failed" }

Write-Host "==> running self test from source"
& $python "$root\run.py" --selftest
if ($LASTEXITCODE -ne 0) { throw "self test failed" }

Write-Host "==> packaging"
& $python -m PyInstaller `
    --noconfirm --clean --onefile --windowed --noupx `
    --name PCTracker `
    --icon "$root\assets\pctracker.ico" `
    --hidden-import pystray._win32 `
    --distpath "$work\dist" `
    --workpath "$work\build" `
    --specpath "$work" `
    "$root\run.py"
if ($LASTEXITCODE -ne 0) { throw "pyinstaller failed" }

Copy-Item "$work\dist\PCTracker.exe" "$root\PCTracker.exe" -Force
$size = [math]::Round((Get-Item "$root\PCTracker.exe").Length / 1MB, 2)
Write-Host "==> done: $root\PCTracker.exe ($size MB)"
