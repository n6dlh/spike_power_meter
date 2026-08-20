$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot
$python = Join-Path $projectRoot ".venv\Scripts\python.exe"

if (-not (Test-Path -LiteralPath $python)) {
    throw "Virtual environment not found. Create it with: py -m venv .venv"
}

& $python -m pip install -r (Join-Path $projectRoot "requirements-build.txt")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $python -m PyInstaller `
    --noconfirm `
    --clean `
    --distpath (Join-Path $projectRoot "dist") `
    --workpath (Join-Path $projectRoot "build\pyinstaller") `
    (Join-Path $projectRoot "DellPowerMeter.spec")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Built: $projectRoot\dist\Spike Power Meter.exe"
