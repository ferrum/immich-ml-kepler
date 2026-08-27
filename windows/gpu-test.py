import os
import sys
import time

import numpy as np
import onnxruntime as ort

from tokenizer import SimpleTokenizer


PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))

MODEL_PATH = os.path.join(
    PROJECT_DIR,
    "models",
    "text-opset13.onnx",
)


def fail(message):
    print("")
    print("GPU TEST FAILED")
    print(message)
    sys.exit(1)


print("ONNX Runtime:", ort.__version__)
print("Available providers:", ort.get_available_providers())

if ort.__version__ != "1.6.0":
    fail("Unexpected ONNX Runtime version.")

if "CUDAExecutionProvider" not in ort.get_available_providers():
    fail("CUDAExecutionProvider is not available.")

if not os.path.isfile(MODEL_PATH):
    fail("Text ONNX model was not found.")

tokenizer = SimpleTokenizer()

tokens, eot_index = tokenizer.tokenize(
    "a photo of a cat"
)

print("")
print("Creating CUDA inference session...")

session = ort.InferenceSession(
    MODEL_PATH,
    providers=[
        "CUDAExecutionProvider",
        "CPUExecutionProvider",
    ],
)

print("Session providers:", session.get_providers())

if "CUDAExecutionProvider" not in session.get_providers():
    fail("The inference session did not load CUDAExecutionProvider.")

print("")
print("Running real CLIP inference...")

start = time.perf_counter()

embedding = session.run(
    None,
    {
        "text": tokens,
        "eot_index": eot_index,
    },
)[0]

elapsed = time.perf_counter() - start

if embedding.shape != (1, 512):
    fail(
        "Unexpected embedding shape: "
        + str(embedding.shape)
    )

if not np.isfinite(embedding).all():
    fail("Embedding contains invalid values.")

norm = float(
    np.linalg.norm(embedding)
)

if norm < 0.9 or norm > 1.1:
    fail(
        "Unexpected embedding norm: "
        + str(norm)
    )

print("")
print("Embedding shape:", embedding.shape)
print("Embedding norm:", norm)
print(
    "Inference time: %.4f s"
    % elapsed
)
print(
    "First 5 values:",
    embedding[0, :5].tolist(),
)

print("")
print("GPU TEST PASSED")
print(
    "CUDAExecutionProvider successfully "
    "executed the CLIP inference."
)