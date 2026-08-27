$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$Python = Join-Path $ProjectDir ".venv\Scripts\python.exe"
$GpuTest = Join-Path $ProjectDir "gpu-test.py"
$CudaBin = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.2\bin"

Write-Host ""
Write-Host "==============================================="
Write-Host "          immich-ml-kepler GPU test"
Write-Host "==============================================="
Write-Host ""

if (-not (Test-Path $Python)) {
    Write-Host "ERROR: Python virtual environment not found."
    Write-Host "Run install.ps1 first."
    exit 1
}

if (-not (Test-Path $GpuTest)) {
    Write-Host "ERROR: gpu-test.py not found."
    exit 1
}

if (-not (Test-Path $CudaBin)) {
    Write-Host "ERROR: CUDA 10.2 runtime not found."
    exit 1
}

$env:PATH = "$CudaBin;$env:PATH"

Write-Host "NVIDIA GPU:"
Write-Host ""

try {
    & nvidia-smi `
        --query-gpu=name,driver_version,memory.total `
        --format=csv,noheader
}
catch {
    Write-Host "WARNING: nvidia-smi could not be executed."
}

Write-Host ""
Write-Host "Running a real CLIP inference through ONNX Runtime..."
Write-Host ""

& $Python $GpuTest

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "==============================================="
    Write-Host "                 TEST FAILED"
    Write-Host "==============================================="
    exit 1
}

Write-Host ""
Write-Host "==============================================="
Write-Host "                 TEST PASSED"
Write-Host "==============================================="
Write-Host ""