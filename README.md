# immich-ml-kepler

Machine Learning module for [Immich](https://github.com/immich-app/immich) compatible with old nVidia GPUs with the Kepler architecture.

## Stack
`Genuine Immich installation --> **immich-ml-kepler** --> ONNX Runtime 1.6 --> cuDNN 8.0.3 --> CUDA 10.2 --> Hardware`

We shall be using [Immich's `ViT-B-32__openai`](https://huggingface.co/immich-app/ViT-B-32__openai) on legacy hardware with minimal modifications

## Windows
`immich-ml-kepler` correctly works on Windows using a GTX 730

<img src="/demos/windows_test_3.jpg" alt="Windows Test 3">
