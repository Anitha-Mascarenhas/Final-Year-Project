from __future__ import annotations

from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf

from config import CLASS_NAMES, MODEL_DIR
from features import CVFeaturePipeline, MeasurementFeaturePipeline
from utils import load_joblib


class Predictor:
    """Reusable inference utilities for measurement-only, image-only, and hybrid pipelines."""

    def __init__(
        self,
        measurement_pipeline_path: Path = MODEL_DIR / "measurement_pipeline.joblib",
        cv_pipeline_path: Path = MODEL_DIR / "cv_pipeline.joblib",
        label_encoder_path: Path = MODEL_DIR / "label_encoder.pkl",
    ):
        self.measurement_pipeline = MeasurementFeaturePipeline().load(measurement_pipeline_path)
        self.cv_pipeline = CVFeaturePipeline().load(cv_pipeline_path)
        self.label_encoder = load_joblib(label_encoder_path)

    def predict_measurement(self, df) -> dict[str, Any]:
        features = self.measurement_pipeline.transform(df)
        return self._predict_tabular(features)

    def predict_image(self, image_tensor: np.ndarray, model: tf.keras.Model) -> dict[str, Any]:
        image_tensor = np.expand_dims(image_tensor, axis=0).astype(np.float32)
        probabilities = model.predict(image_tensor, verbose=0)[0]
        return self._format_prediction(probabilities)

    def predict_hybrid(
        self,
        image_tensor: np.ndarray,
        measurement_df,
        cv_df,
        model: tf.keras.Model,
    ) -> dict[str, Any]:
        image_tensor = np.asarray(image_tensor, dtype=np.float32)
        if image_tensor.ndim == 3:
            image_tensor = np.expand_dims(image_tensor, axis=0)
        measurement_features = self.measurement_pipeline.transform(measurement_df)
        cv_features = self.cv_pipeline.transform(cv_df)
        probabilities = model.predict(
            {
                "image_input": image_tensor,
                "measurement_input": measurement_features,
                "cv_input": cv_features,
            },
            verbose=0,
        )
        return self._format_prediction(probabilities[0])

    def _predict_tabular(self, features: np.ndarray) -> dict[str, Any]:
        raise NotImplementedError("Measurement-only prediction requires a tabular classifier.")

    def _format_prediction(self, probabilities: np.ndarray) -> dict[str, Any]:
        best_index = int(np.argmax(probabilities))
        return {
            "prediction": CLASS_NAMES[best_index],
            "confidence": float(probabilities[best_index]),
            "probabilities": {CLASS_NAMES[i]: float(probabilities[i]) for i in range(len(CLASS_NAMES))},
        }


class TFLitePredictor:
    """Wrapper for running inference using a TensorFlow Lite model."""

    def __init__(self, tflite_model_path: Path):
        self.interpreter = tf.lite.Interpreter(model_path=str(tflite_model_path))
        self.interpreter.allocate_tensors()
        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()

    def infer(self, image_tensor: np.ndarray) -> dict[str, Any]:
        input_index = self.input_details[0]["index"]
        self.interpreter.set_tensor(input_index, image_tensor.astype(np.float32))
        self.interpreter.invoke()
        probabilities = self.interpreter.get_tensor(self.output_details[0]["index"])[0]
        best_index = int(np.argmax(probabilities))
        return {
            "prediction": CLASS_NAMES[best_index],
            "confidence": float(probabilities[best_index]),
            "probabilities": {CLASS_NAMES[i]: float(probabilities[i]) for i in range(len(CLASS_NAMES))},
        }
