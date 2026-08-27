# immich-ml-kepler

Machine Learning module for [Immich](https://github.com/immich-app/immich) compatible with old nVidia GPUs with Kepler architecture.

## Current status
Working on Windows x64 with an NVIDIA GeForce GT 730 (`sm_35`). Kepler also comes in the `sm_30` version. This has not been tested yet. A Linux-compatible script is on the way

## Stack
`Genuine Immich installation --(http)--> **immich-ml-kepler** --> ONNX Runtime 1.6 --> cuDNN 8.0.3 --> CUDA 10.2 --> Hardware`

## Supported Models
- [`ViT-B-32__openai`](https://huggingface.co/immich-app/ViT-B-32__openai) (Semantic Search)
  - The original `.onnx` files were too new for ONNX runtime 1.6 (`IR version 9` and `opset 19`). We used the weighs of OpenAI ViT-B-32 to build a opset
    13 version compatible with our runtime with PyTorch. You can verify that the cosine difference between the original model and ours is 1    (well, not exactly, but in the order of 10^-7 which is probably a rounding error). Do not use text-opset13.onnx in official Immich builds because it is incompatible.
- Face recognition not yet supported.
- OCR not yet supported

## Windows
<img src="/demos/windows_test_3.jpg" alt="Windows Test 3">
<img src="/demos/windows_test_2.jpg" alt="Windows Test 2">
<img src="/demos/windows_test.jpg" alt="Windows Test 1">
