import io
import json
import os
from typing import Optional

import numpy as np
import onnxruntime as ort

from PIL import Image, ImageOps
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import PlainTextResponse

from tokenizer import SimpleTokenizer


# ------------------------------------------------------------
# Configurazione
# ------------------------------------------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

TEXT_MODEL = os.path.join(
    BASE_DIR,
    "models",
    "text-opset13.onnx",
)

VISUAL_MODEL = os.path.join(
    BASE_DIR,
    "models",
    "visual-opset13.onnx",
)

SUPPORTED_MODEL = "ViT-B-32__openai"

CLIP_SIZE = 224

CLIP_MEAN = np.array(
    [0.48145466, 0.4578275, 0.40821073],
    dtype=np.float32,
).reshape(1, 1, 3)

CLIP_STD = np.array(
    [0.26862954, 0.26130258, 0.27577711],
    dtype=np.float32,
).reshape(1, 1, 3)


# ------------------------------------------------------------
# Applicazione
# ------------------------------------------------------------

app = FastAPI(
    title="immich-ml-kepler",
)


# ------------------------------------------------------------
# Tokenizer
# ------------------------------------------------------------

tokenizer = SimpleTokenizer()


# ------------------------------------------------------------
# ONNX Runtime
# ------------------------------------------------------------

providers = [
    "CUDAExecutionProvider",
    "CPUExecutionProvider",
]

text_session = ort.InferenceSession(
    TEXT_MODEL,
    providers=providers,
)

visual_session = ort.InferenceSession(
    VISUAL_MODEL,
    providers=providers,
)


# ------------------------------------------------------------
# Utility
# ------------------------------------------------------------

def serialize_embedding(embedding):
    return json.dumps(
        embedding[0].astype(np.float32).tolist(),
        separators=(",", ":"),
    )


def check_model(model_config):
    if not isinstance(model_config, dict):
        raise HTTPException(
            status_code=422,
            detail="Invalid model configuration",
        )

    model_name = model_config.get("modelName")

    if model_name != SUPPORTED_MODEL:
        raise HTTPException(
            status_code=400,
            detail=(
                "Unsupported model: "
                + str(model_name)
                + ". Supported model: "
                + SUPPORTED_MODEL
            ),
        )


def preprocess_image(image_bytes):
    image = Image.open(
        io.BytesIO(image_bytes)
    )

    image = ImageOps.exif_transpose(image)
    image = image.convert("RGB")

    image_width, image_height = image.size

    width, height = image.size

    if width < height:
        new_width = CLIP_SIZE
        new_height = int(
            height * CLIP_SIZE / width
        )
    else:
        new_height = CLIP_SIZE
        new_width = int(
            width * CLIP_SIZE / height
        )

    image = image.resize(
        (new_width, new_height),
        Image.Resampling.BICUBIC,
    )

    left = (
        new_width - CLIP_SIZE
    ) // 2

    top = (
        new_height - CLIP_SIZE
    ) // 2

    image = image.crop(
        (
            left,
            top,
            left + CLIP_SIZE,
            top + CLIP_SIZE,
        )
    )

    array = np.asarray(
        image,
        dtype=np.float32,
    ) / 255.0

    array = (
        array - CLIP_MEAN
    ) / CLIP_STD

    array = np.transpose(
        array,
        (2, 0, 1),
    )

    array = np.expand_dims(
        array,
        axis=0,
    ).astype(np.float32)

    return (
        array,
        image_width,
        image_height,
    )


# ------------------------------------------------------------
# Health check
# ------------------------------------------------------------

@app.get("/ping")
def ping():
    return PlainTextResponse(
        "pong"
    )


# ------------------------------------------------------------
# Immich /predict
# ------------------------------------------------------------

@app.post("/predict")
async def predict(
    entries: str = Form(...),
    image: Optional[UploadFile] = File(default=None),
    text: Optional[str] = Form(default=None),
):
    # --------------------------------------------------------
    # Parsing entries
    # --------------------------------------------------------

    try:
        config = json.loads(entries)
    except Exception:
        raise HTTPException(
            status_code=422,
            detail="Invalid request format",
        )

    if not isinstance(config, dict):
        raise HTTPException(
            status_code=422,
            detail="Invalid request format",
        )

    clip_config = config.get("clip")

    if not isinstance(clip_config, dict):
        raise HTTPException(
            status_code=400,
            detail="Unsupported machine learning task",
        )

    textual_config = clip_config.get(
        "textual"
    )

    visual_config = clip_config.get(
        "visual"
    )

    # --------------------------------------------------------
    # CLIP textual
    # --------------------------------------------------------

    if textual_config is not None:
        check_model(
            textual_config
        )

        if text is None:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Text input required "
                    "for textual CLIP"
                ),
            )

        tokens, eot_index = (
            tokenizer.tokenize(text)
        )

        embedding = text_session.run(
            None,
            {
                "text": tokens,
                "eot_index": eot_index,
            },
        )[0]

        return {
            "clip": serialize_embedding(
                embedding
            )
        }

    # --------------------------------------------------------
    # CLIP visual
    # --------------------------------------------------------

    if visual_config is not None:
        check_model(
            visual_config
        )

        if image is None:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Image input required "
                    "for visual CLIP"
                ),
            )

        image_bytes = await image.read()

        try:
            (
                tensor,
                image_width,
                image_height,
            ) = preprocess_image(
                image_bytes
            )
        except Exception as error:
            raise HTTPException(
                status_code=400,
                detail=(
                    "Invalid image: "
                    + str(error)
                ),
            )

        embedding = visual_session.run(
            None,
            {
                "image": tensor,
            },
        )[0]

        return {
            "clip": serialize_embedding(
                embedding
            ),
            "imageHeight": image_height,
            "imageWidth": image_width,
        }

    # --------------------------------------------------------
    # Task non supportato
    # --------------------------------------------------------

    raise HTTPException(
        status_code=400,
        detail="Unsupported machine learning task",
    )