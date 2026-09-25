"""Export the existing DeepLabV3+ upper-arm segmentation model to TFLite.

The Keras model (experiments/upper_arm_segmentation/deeplabv3/model.py with its trained
weights) is converted UNCHANGED: input [1,512,512,3] -> output [1,512,512,2] logits.
A parity check compares TFLite vs Keras argmax masks on a real dataset image.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np

from .config import ARTIFACT_DIR, DEEPLAB_ARCH, DEEPLAB_WEIGHTS

TFLITE_NAME = "hybrid_production_segmentation.tflite"


def _load_keras_deeplab():
    arch_dir = str(Path(DEEPLAB_ARCH).parent)
    if arch_dir not in sys.path:
        sys.path.insert(0, arch_dir)
    from model import build_deeplabv3plus  # type: ignore

    model = build_deeplabv3plus(input_shape=(512, 512, 3), num_classes=2)
    model.load_weights(str(DEEPLAB_WEIGHTS))
    return model


def main() -> None:
    import tensorflow as tf

    out_path = ARTIFACT_DIR / TFLITE_NAME
    if not out_path.exists():
        print("Loading existing DeepLabV3+ Keras model...")
        model = _load_keras_deeplab()
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        out_path.write_bytes(tflite_model)
        print(f"saved {out_path} ({out_path.stat().st_size / 1e6:.1f} MB)")

    # ---- parity check ----
    import cv2

    keras_model = _load_keras_deeplab()
    interpreter = tf.lite.Interpreter(model_path=str(out_path))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    print(f"tflite input {inp['shape']} -> output {out['shape']}")

    img_path = sorted((ARTIFACT_DIR.parents[1] / "dataset" / "ANTHROVISION" / "frontal1").glob("*.jpg"))[0]
    img = cv2.imread(str(img_path))[:, :, ::-1]
    img_r = cv2.resize(img, (512, 512)).astype(np.float32) / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    x = ((img_r - mean) / std).astype(np.float32)[None]

    logits_k = keras_model(x, training=False).numpy()
    interpreter.set_tensor(inp["index"], x)
    interpreter.invoke()
    logits_t = interpreter.get_tensor(out["index"])

    mask_k = logits_k.argmax(-1)[0]
    mask_t = logits_t.argmax(-1)[0]
    agreement = float((mask_k == mask_t).mean())
    print(f"mask pixel agreement keras vs tflite: {agreement:.4f}")
    assert agreement > 0.99, "TFLite segmentation mask deviates from Keras"
    print("DeepLabV3+ TFLite export validated.")


if __name__ == "__main__":
    main()
