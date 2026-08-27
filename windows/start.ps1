$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$Python = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$CudaBin = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.2\bin"

Write-Host ""
Write-Host "==============================================="
Write-Host "              immich-ml-kepler"
Write-Host "==============================================="
Write-Host ""

if (-not (Test-Path $Python)) {
    Write-Host "ERROR: Python virtual environment not found:"
    Write-Host $Python
    Write-Host ""
    Write-Host "Run install.ps1 first."
    exit 1
}

if (-not (Test-Path $CudaBin)) {
    Write-Host "ERROR: CUDA 10.2 was not found:"
    Write-Host $CudaBin
    Write-Host ""
    Write-Host "Run install.ps1 first."
    exit 1
}

$env:PATH = "$CudaBin;$env:PATH"

Write-Host "[OK] Python runtime:"
Write-Host $Python
Write-Host ""

Write-Host "[OK] CUDA runtime:"
Write-Host $CudaBin
Write-Host ""

Write-Host "Starting immich-ml-kepler..."
Write-Host ""
Write-Host "Server address:"
Write-Host "  http://0.0.0.0:3003"
Write-Host ""
Write-Host "Press CTRL+C to stop the server."
Write-Host ""

& $Python -m uvicorn server:app `
    --app-dir $ProjectDir `
    --host 0.0.0.0 `
    --port 3003