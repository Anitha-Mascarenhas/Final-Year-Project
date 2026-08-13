from __future__ import annotations

from pathlib import Path
from typing import Any

import tensorflow as tf

from config import LABELS_FILENAME, MODEL_DIR
from utils import save_json, ensure_dir


class ModelExporter:
    """Export trained TensorFlow models for Flutter inference."""

    def __init__(self, model_dir: Path = MODEL_DIR):
        self.model_dir = ensure_dir(model_dir)

    def export_tflite(self, keras_model_path: Path, output_path: Path) -> Path:
        model = tf.keras.models.load_model(keras_model_path)
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        ensure_dir(output_path.parent)
        output_path.write_bytes(tflite_model)
        return output_path

    def save_label_map(self, class_names: list[str], output_path: Path) -> Path:
        payload = {i: name for i, name in enumerate(class_names)}
        ensure_dir(output_path.parent)
        save_json(output_path, payload)
        return output_path


class FlutterInferenceWrapper:
    """Provide a structure for a Flutter-compatible model input and output contract."""

    def __init__(self, class_names: list[str]):
        self.class_names = class_names

    def build_response(self, probabilities: list[float]) -> dict[str, Any]:
        best_index = int(tf.argmax(probabilities, axis=-1).numpy())
        return {
            "prediction": self.class_names[best_index],
            "confidence": float(probabilities[best_index]),
            "probabilities": {self.class_names[i]: float(probabilities[i]) for i in range(len(self.class_names))},
        }
