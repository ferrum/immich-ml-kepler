# immich-ml-kepler

Machine Learning module for [Immich](https://github.com/immich-app/immich) compatible with old nVidia GPUs with Kepler architecture.

This project keeps Immich itself completely untouched. It just installs the necessary dependencies and spins up a server capable of connecting to Immich's remote Machine Learning feature.

```text
Immich
    ↓ HTTP POST
immich-ml-kepler
    ↓
ONNX Runtime GPU 1.6.0
    ↓
cuDNN 8.0.3
    ↓
CUDA 10.2
    ↓
NVIDIA Kepler GPU
```

## Current status
Working on Windows x64 with an NVIDIA GeForce GT 730 (`sm_35`). Kepler also comes in the `sm_30` version. This has not been tested yet. A Linux-compatible script is on the way

## Supported Models
- [`ViT-B-32__openai`](https://huggingface.co/immich-app/ViT-B-32__openai) (Semantic Search)
  - The original `.onnx` files were too new for ONNX runtime 1.6 (`IR version 9` and `opset 19`). We used the weighs of OpenAI ViT-B-32 to build a opset
    13 version compatible with our runtime with PyTorch. You can verify that the cosine difference between the original model and ours is 1    (well, not exactly, but in the order of 10^-7 which is probably a rounding error). Do not use text-opset13.onnx in official Immich builds because it is incompatible.
- Face recognition not yet supported.
- OCR not yet supported

## What the bundle contains
 
The repository is split between platform-independent content and a platform-specific runtime bundle.
 
### Platform independent
 
Identical on every platform, no changes required:
 
| Item | Notes |
|---|---|
| `server.py` | FastAPI application, no OS-specific code |
| `tokenizer.py` | local CLIP BPE tokenizer |
| `bpe_simple_vocab_16e6.txt.gz` | BPE merge table |
| `models/text-opset13.onnx` | patched text encoder |
| `models/visual-opset13.onnx` | visual encoder |
| `requirements.txt` | pinned Python dependencies |
 
### Platform specific
 
Provided per platform, because these are compiled binaries:
 
| Component | Version | Why it is needed |
|---|---|---|
| Python interpreter | 3.7 x64 | the only version the ONNX Runtime wheel targets |
| ONNX Runtime GPU wheel | 1.6.0 | last release built against CUDA 10.2 |
| CUDA runtime libraries | 10.2 | last CUDA supporting Kepler; only `cudart`, `cublas`, `cufft`, `curand`, `cusolver`, `cusparse` are installed |
| cuDNN | 8.0.3 | required by the ONNX Runtime CUDA execution provider |
| zlib (`zlibwapi.dll`, Windows) | — | undocumented cuDNN 8 dependency; without it the CUDA provider fails to initialize |
| Python dependency wheels | see `requirements.txt` | shipped locally so installation works fully offline |

### Deliberately not bundled
 
The NVIDIA display driver is not bundled. The CUDA 10.2 installer contains a 2019-era driver. Installing it would downgrade the driver for the entire machine. The installer explicitly selects individual CUDA components so the driver is never touched.
 
## Requirements
 
A working NVIDIA driver that still supports your GPU must already be installed. Driver branch 470 is the last one supporting Kepler on both Windows and Linux, and it reached end of maintenance in 2024. 


## Windows

### Installation

Open PowerShell in the project directory and run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\install.ps1
```

1. checks the bundled files
2. elevates itself to Administrator when necessary
3. looks for an existing Python 3.7 x64 installation
4. installs bundled Python 3.7.9 if Python 3.7 x64 is not available
5. checks CUDA 10.2 runtime libraries
6. installs only the required CUDA 10.2 components when missing
7. does **not** install the old NVIDIA display driver bundled with CUDA
8. extracts and installs cuDNN 8.0.3 when missing
9. installs `zlibwapi.dll` when missing
10. creates the project `.venv`
11. installs Python runtime dependencies
12. installs ONNX Runtime GPU 1.6.0
13. verifies `CUDAExecutionProvider`
14. verifies that both ONNX model files are present

### Starting the server

Run:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\start.ps1
```

Default address:

```text
http://0.0.0.0:3003
```

Health check:

```text
GET /ping
```

Expected response:

```text
pong
```

Screenshots:

<img src="/demos/windows_test_3.jpg" alt="Windows Test 3">
<img src="/demos/windows_test_2.jpg" alt="Windows Test 2">
<img src="/demos/windows_test.jpg" alt="Windows Test 1">

