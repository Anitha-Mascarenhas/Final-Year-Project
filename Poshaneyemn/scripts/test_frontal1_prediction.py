"""
Standalone inference script for the completed frontal1-only balanced binary model.

Model:
    experiments/image_model_frontal1_only/artifacts/binary_child_level.tflite

This is the experimental frontal1-only binary child-level model trained on
AnthroVision only. It is NOT the production PoshanEye model and is not
connected to the backend, Flutter app, or any production artifact.

Preprocessing matches the training pipeline exactly:
    - decode JPEG
    - resize to 224x224 (bicubic)
    - apply tf.keras.applications.mobilenet_v2.preprocess_input
      (result in [-1, 1])
    - float32, shape (1, 224, 224, 3)

The single output is the malnourished probability. The healthy probability
is 1 - malnourished_probability. Threshold 0.5 is used for the predicted
class.

Usage:
    ..\.venv\Scripts\python.exe scripts\test_frontal1_prediction.py <path_to_image>
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow.keras.applications import mobilenet_v2


MODEL_PATH = Path(__file__).resolve().parents[1] / "experiments" / "image_model_frontal1_only" / "artifacts" / "binary_child_level.tflite"
THRESHOLD = 0.5


def main(image_path: str) -> None:
    image_path_obj = Path(image_path)
    if not image_path_obj.is_file():
        print(f"ERROR: file not found: {image_path}")
        sys.exit(1)

    print("Model: frontal1-only balanced binary child-level experiment")
    print(f"Model file: {MODEL_PATH}")
    print(f"Image: {image_path_obj}")
    print(f"Threshold: {THRESHOLD}")
    print("-" * 70)

    interpreter = tf.lite.Interpreter(model_path=str(MODEL_PATH))
    interpreter.allocate_tensors()
    input_index = interpreter.get_input_details()[0]["index"]
    output_index = interpreter.get_output_details()[0]["index"]

    # Preprocess exactly as in training:
    # decode -> resize 224x224 -> mobilenet_v2.preprocess_input -> float32
    img = tf.io.read_file(str(image_path_obj))
    img = tf.image.decode_jpeg(img, channels=3)
    img = tf.image.resize(img, [224, 224], method="bicubic")
    img = tf.cast(img, tf.float32)
    img = mobilenet_v2.preprocess_input(img)
    img = tf.expand_dims(img, 0)  # (1, 224, 224, 3)

    interpreter.set_tensor(input_index, img.numpy())
    interpreter.invoke()
    malnourished_prob = float(interpreter.get_tensor(output_index).ravel()[0])

    healthy_prob = 1.0 - malnourished_prob
    predicted_class = "malnourished" if malnourished_prob >= THRESHOLD else "healthy"

    print(f"malnourished probability: {malnourished_prob:.6f}")
    print(f"healthy probability:      {healthy_prob:.6f}")
    print(f"predicted class:          {predicted_class}")
    print("-" * 70)
    print("IMPORTANT: This is the experimental frontal1-only binary model.")
    print("It is not the production PoshanEye model and is not deployed.")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path_to_image>")
        sys.exit(1)
    main(sys.argv[1])
