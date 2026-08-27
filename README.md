# immich-ml-kepler

Machine Learning module for [Immich](https://github.com/immich-app/immich) compatible with old nVidia GPUs with the Kepler architecture which are not officially supported by Immich

## Stack
`Genuine Immich installation --> **immich-ml-kepler** --> ONNX Runtime 1.6 --> cuDNN 8.0.3 --> CUDA 10.2 --> Hardware`

## Windows
Windows machine with GT 730 correctly works in a test environment. This proves that it is possible to perform machine learning tagging using [Immich's `ViT-B-32__openai`](https://huggingface.co/immich-app/ViT-B-32__openai) on legacy hardware. A package will soon be provided.

Test with a picture of my cat:


<img src="/demos/windows_test.jpg" alt="Windows Test">

<img src="/demos/windows_test_2.jpg" alt="Windows Test 2">
