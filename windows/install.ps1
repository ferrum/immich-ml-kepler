$ErrorActionPreference = "Stop"

# ============================================================
# immich-ml-kepler - Windows installer
# ============================================================

$ProjectDir = $PSScriptRoot

$InstallersDir = Join-Path $ProjectDir "installers"
$WheelsDir     = Join-Path $ProjectDir "wheels"
$RuntimeDir    = Join-Path $ProjectDir "runtime"

$PythonInstaller = Join-Path $InstallersDir "python-3.7.9-amd64.exe"
$CudaInstaller   = Join-Path $InstallersDir "cuda_10.2.89_441.22_win10.exe"
$CudnnArchive    = Join-Path $InstallersDir "cudnn-10.2-windows10-x64-v8.0.3.33.zip"
$ZlibArchive     = Join-Path $InstallersDir "zlib123dllx64.zip"

$OrtWheel = Join-Path $WheelsDir "onnxruntime_gpu-1.6.0-cp37-cp37m-win_amd64.whl"

$Requirements = Join-Path $ProjectDir "requirements.txt"

$BundledPythonDir = Join-Path $RuntimeDir "python37"
$BundledPythonExe = Join-Path $BundledPythonDir "python.exe"

$VenvDir    = Join-Path $ProjectDir ".venv"
$VenvPython = Join-Path $VenvDir "Scripts\python.exe"

$CudaDir = "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v10.2"
$CudaBin = Join-Path $CudaDir "bin"

$CudnnDll = Join-Path $CudaBin "cudnn64_8.dll"
$ZlibDll  = Join-Path $CudaBin "zlibwapi.dll"


# ============================================================
# Helper: validate Python 3.7 x64
# ============================================================

function Test-Python37X64 {

    param(
        [string]$PythonPath
    )

    if (-not $PythonPath) {
        return $false
    }

    if (-not (Test-Path $PythonPath)) {
        return $false
    }

    try {

        $Result = & $PythonPath -c "import sys,struct; print('OK' if sys.version_info[:2] == (3,7) and struct.calcsize('P') * 8 == 64 else 'NO')" 2>$null

        return ($Result -eq "OK")
    }
    catch {
        return $false
    }
}


# ============================================================
# Helper: find an existing Python 3.7 x64 installation
# ============================================================

function Find-Python37 {

    Write-Host "Searching for an existing Python 3.7 x64 installation..."

    # --------------------------------------------------------
    # Python Launcher
    # --------------------------------------------------------

    $Launcher = Get-Command "py.exe" -ErrorAction SilentlyContinue

    if ($Launcher) {

        try {

            $Candidate = & py.exe -3.7 -c "import sys; print(sys.executable)" 2>$null

            if (Test-Python37X64 $Candidate) {

                Write-Host "[OK] Existing Python 3.7 x64 found"
                Write-Host $Candidate
                Write-Host ""

                return $Candidate
            }
        }
        catch {
        }
    }


    # --------------------------------------------------------
    # Common installation locations
    # --------------------------------------------------------

    $Candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python37\python.exe"),
        "C:\Program Files\Python37\python.exe",
        "C:\Python37\python.exe",
        $BundledPythonExe
    )

    foreach ($Candidate in $Candidates) {

        if (Test-Python37X64 $Candidate) {

            Write-Host "[OK] Existing Python 3.7 x64 found"
            Write-Host $Candidate
            Write-Host ""

            return $Candidate
        }
    }


    # --------------------------------------------------------
    # Python registry entries
    # --------------------------------------------------------

    $RegistryPaths = @(
        "HKCU:\Software\Python\PythonCore\3.7\InstallPath",
        "HKLM:\Software\Python\PythonCore\3.7\InstallPath"
    )

    foreach ($RegistryPath in $RegistryPaths) {

        if (Test-Path $RegistryPath) {

            try {

                $InstallPath = (Get-Item $RegistryPath).GetValue("")

                if ($InstallPath) {

                    $Candidate = Join-Path $InstallPath "python.exe"

                    if (Test-Python37X64 $Candidate) {

                        Write-Host "[OK] Existing Python 3.7 x64 found"
                        Write-Host $Candidate
                        Write-Host ""

                        return $Candidate
                    }
                }
            }
            catch {
            }
        }
    }

    return $null
}


# ============================================================
# Banner
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "         immich-ml-kepler installer"
Write-Host "==============================================="
Write-Host ""


# ============================================================
# Check bundled installation files
# ============================================================

$RequiredFiles = @(
    $PythonInstaller,
    $CudaInstaller,
    $CudnnArchive,
    $ZlibArchive,
    $OrtWheel,
    $Requirements
)

foreach ($File in $RequiredFiles) {

    if (-not (Test-Path $File)) {

        Write-Host "ERROR: required file not found:"
        Write-Host $File
        exit 1
    }
}

Write-Host "[OK] Installation bundle is complete"
Write-Host ""


# ============================================================
# Administrator privileges
#
# CUDA, cuDNN and zlib are installed under Program Files.
# ============================================================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object Security.Principal.WindowsPrincipal(
    $CurrentIdentity
)

$IsAdmin = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {

    Write-Host "Administrator privileges are required."
    Write-Host "Restarting installer as Administrator..."
    Write-Host ""

    $Arguments = @(
        "-NoProfile",
        "-NoExit",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$PSCommandPath`""
    )

    Start-Process `
        -FilePath "powershell.exe" `
        -Verb RunAs `
        -ArgumentList $Arguments

    exit
}


# ============================================================
# Runtime directory
# ============================================================

New-Item `
    -ItemType Directory `
    -Force `
    -Path $RuntimeDir `
    | Out-Null


# ============================================================
# Find or install Python 3.7 x64
# ============================================================

$PythonExe = Find-Python37


if (-not $PythonExe) {

    Write-Host "Python 3.7 x64 was not found."
    Write-Host "Installing bundled Python 3.7.9..."
    Write-Host ""

    $PythonLog = Join-Path $ProjectDir "python-install.log"

    $PythonArgs = @(
        "/quiet",
        "InstallAllUsers=0",
        "TargetDir=`"$BundledPythonDir`"",
        "Include_launcher=0",
        "Include_pip=1",
        "Include_test=0",
        "Include_doc=0",
        "Include_tcltk=0",
        "Include_tools=0",
        "Include_symbols=0",
        "Include_debug=0",
        "AssociateFiles=0",
        "Shortcuts=0",
        "PrependPath=0",
        "/log",
        "`"$PythonLog`""
    )

    $Process = Start-Process `
        -FilePath $PythonInstaller `
        -ArgumentList $PythonArgs `
        -Wait `
        -PassThru

    if ($Process.ExitCode -ne 0) {

        Write-Host "ERROR: Python installation failed."
        Write-Host "Exit code: $($Process.ExitCode)"
        Write-Host ""
        Write-Host "Installer log:"
        Write-Host $PythonLog
        exit 1
    }


    if (-not (Test-Python37X64 $BundledPythonExe)) {

        Write-Host "ERROR: Python 3.7.9 was not found after installation."
        Write-Host ""
        Write-Host "Installer log:"
        Write-Host $PythonLog
        exit 1
    }

    $PythonExe = $BundledPythonExe

    Write-Host "[OK] Bundled Python 3.7.9 installed"
    Write-Host $PythonExe
    Write-Host ""
}


# ============================================================
# CUDA 10.2 runtime
#
# The NVIDIA display driver is NOT installed.
#
# Only the CUDA components required by ONNX Runtime GPU
# are installed.
# ============================================================

$CudaRequiredDlls = @(
    "cudart64_102.dll",
    "cublas64_10.dll",
    "cublasLt64_10.dll",
    "cufft64_10.dll",
    "curand64_10.dll",
    "cusolver64_10.dll",
    "cusparse64_10.dll"
)

$CudaReady = $true

foreach ($Dll in $CudaRequiredDlls) {

    if (-not (Test-Path (Join-Path $CudaBin $Dll))) {
        $CudaReady = $false
    }
}


if ($CudaReady) {

    Write-Host "[OK] CUDA 10.2 runtime already installed"
    Write-Host ""
}
else {

    Write-Host "Installing CUDA 10.2 runtime..."
    Write-Host ""
    Write-Host "The NVIDIA display driver will NOT be installed."
    Write-Host ""

    $CudaArgs = @(
        "-s",
        "cudart_10.2",
        "cublas_10.2",
        "cufft_10.2",
        "curand_10.2",
        "cusolver_10.2",
        "cusparse_10.2"
    )

    $Process = Start-Process `
        -FilePath $CudaInstaller `
        -ArgumentList $CudaArgs `
        -Wait `
        -PassThru

    if ($Process.ExitCode -ne 0) {

        Write-Host "ERROR: CUDA 10.2 installation failed."
        Write-Host "Exit code: $($Process.ExitCode)"
        exit 1
    }
}


# ============================================================
# Verify CUDA libraries
# ============================================================

foreach ($Dll in $CudaRequiredDlls) {

    $DllPath = Join-Path $CudaBin $Dll

    if (-not (Test-Path $DllPath)) {

        Write-Host "ERROR: missing CUDA library:"
        Write-Host $DllPath
        exit 1
    }
}

Write-Host "[OK] CUDA 10.2 runtime"
Write-Host ""


# ============================================================
# Install cuDNN 8.0.3
# ============================================================

if (Test-Path $CudnnDll) {

    Write-Host "[OK] cuDNN 8.0.3 already installed"
    Write-Host ""
}
else {

    Write-Host "Installing cuDNN 8.0.3..."
    Write-Host ""

    $TempCudnn = Join-Path $env:TEMP "immich-kepler-cudnn"

    if (Test-Path $TempCudnn) {

        Remove-Item `
            -Recurse `
            -Force `
            $TempCudnn
    }

    Expand-Archive `
        -Path $CudnnArchive `
        -DestinationPath $TempCudnn `
        -Force

    $CudnnBin = Join-Path $TempCudnn "cuda\bin"

    if (-not (Test-Path $CudnnBin)) {

        Write-Host "ERROR: invalid cuDNN archive structure."
        exit 1
    }

    Copy-Item `
        -Path (Join-Path $CudnnBin "*.dll") `
        -Destination $CudaBin `
        -Force

    Remove-Item `
        -Recurse `
        -Force `
        $TempCudnn
}


if (-not (Test-Path $CudnnDll)) {

    Write-Host "ERROR: cuDNN was not installed correctly."
    exit 1
}

Write-Host "[OK] cuDNN 8.0.3"
Write-Host ""


# ============================================================
# Install zlibwapi.dll
# ============================================================

if (Test-Path $ZlibDll) {

    Write-Host "[OK] zlibwapi.dll already installed"
    Write-Host ""
}
else {

    Write-Host "Installing zlibwapi.dll..."
    Write-Host ""

    $TempZlib = Join-Path $env:TEMP "immich-kepler-zlib"

    if (Test-Path $TempZlib) {

        Remove-Item `
            -Recurse `
            -Force `
            $TempZlib
    }

    Expand-Archive `
        -Path $ZlibArchive `
        -DestinationPath $TempZlib `
        -Force

    $SourceZlib = Join-Path `
        $TempZlib `
        "dll_x64\zlibwapi.dll"

    if (-not (Test-Path $SourceZlib)) {

        Write-Host "ERROR: zlibwapi.dll was not found inside the archive."
        exit 1
    }

    Copy-Item `
        $SourceZlib `
        $ZlibDll `
        -Force

    Remove-Item `
        -Recurse `
        -Force `
        $TempZlib
}


if (-not (Test-Path $ZlibDll)) {

    Write-Host "ERROR: zlibwapi.dll was not installed correctly."
    exit 1
}

Write-Host "[OK] zlibwapi.dll"
Write-Host ""


# ============================================================
# Create project virtual environment
# ============================================================

if (Test-Path $VenvPython) {

    Write-Host "[OK] Python virtual environment already exists"
    Write-Host ""
}
else {

    Write-Host "Creating Python virtual environment..."
    Write-Host ""

    & $PythonExe -m venv $VenvDir

    if ($LASTEXITCODE -ne 0) {

        Write-Host "ERROR: virtual environment creation failed."
        exit 1
    }
}


if (-not (Test-Path $VenvPython)) {

    Write-Host "ERROR: virtual environment Python executable not found."
    exit 1
}

Write-Host "[OK] Python virtual environment"
Write-Host ""


# ============================================================
# Install Python dependencies from the local wheelhouse
#
# No Internet connection is required.
# ============================================================

Write-Host ""
Write-Host "Installing Python runtime dependencies from local wheelhouse..."
Write-Host ""

& $VenvPython -m pip install `
    --no-index `
    --find-links $WheelsDir `
    -r $Requirements

if ($LASTEXITCODE -ne 0) {

    Write-Host "ERROR: offline Python dependency installation failed."
    exit 1
}


# ============================================================
# Install ONNX Runtime GPU 1.6.0
# ============================================================

Write-Host ""
Write-Host "Installing ONNX Runtime GPU 1.6.0..."
Write-Host ""

& $VenvPython -m pip install `
    --no-index `
    --find-links $WheelsDir `
    --force-reinstall `
    --no-deps `
    $OrtWheel

if ($LASTEXITCODE -ne 0) {

    Write-Host "ERROR: ONNX Runtime installation failed."
    exit 1
}


# ============================================================
# Add CUDA libraries to this process
# ============================================================

$env:PATH = "$CudaBin;$env:PATH"


# ============================================================
# Verify ONNX Runtime
# ============================================================

Write-Host ""
Write-Host "Checking ONNX Runtime..."
Write-Host ""

& $VenvPython -c "import onnxruntime as ort; print('ONNX Runtime:', ort.__version__); print('Providers:', ort.get_available_providers()); assert ort.__version__ == '1.6.0'; assert 'CUDAExecutionProvider' in ort.get_available_providers()"

if ($LASTEXITCODE -ne 0) {

    Write-Host ""
    Write-Host "ERROR: CUDAExecutionProvider is not available."
    exit 1
}


# ============================================================
# Verify ONNX models
# ============================================================

Write-Host ""
Write-Host "Checking ONNX models..."
Write-Host ""

$TextModel = Join-Path $ProjectDir "models\text-opset13.onnx"
$VisualModel = Join-Path $ProjectDir "models\visual-opset13.onnx"

if (-not (Test-Path $TextModel)) {

    Write-Host "ERROR: text ONNX model is missing."
    exit 1
}

if (-not (Test-Path $VisualModel)) {

    Write-Host "ERROR: visual ONNX model is missing."
    exit 1
}

Write-Host "[OK] ONNX models"
Write-Host ""


# ============================================================
# Installation completed
# ============================================================

Write-Host ""
Write-Host "==============================================="
Write-Host "         INSTALLATION COMPLETED"
Write-Host "==============================================="
Write-Host ""
Write-Host "immich-ml-kepler is ready."
Write-Host ""
Write-Host "Start the server with:"
Write-Host ""
Write-Host "  powershell.exe -ExecutionPolicy Bypass -File .\start.ps1"
Write-Host ""
Write-Host "Server address:"
Write-Host ""
Write-Host "  http://127.0.0.1:3003"
Write-Host ""