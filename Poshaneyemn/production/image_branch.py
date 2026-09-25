"""MobileNetV2 image FEATURE EXTRACTOR (not a classifier).

The legacy ``models/image_best.h5`` model is Image -> MobileNetV2 -> Dense(128, relu)
-> Dense(4, softmax). The production pipeline keeps only the penultimate
``image_dense`` layer output (a 128-d image embedding) and drops the legacy 4-class
head entirely. The fused vector (image + CV + segmentation + anthropometric features)
is classified by the preserved RBF-SVM instead.
"""

from __future__ import annotations

from pathlib import Path

import numpy as np
import tensorflow as tf

from .config import IMAGE_INPUT_SIZE, LEGACY_IMAGE_MODEL

EMBEDDING_LAYER_NAME = "image_dense"  # penultimate Dense(128, relu) of the legacy model


def load_image_feature_extractor(model_path: Path | None = None) -> tf.keras.Model:
    """Build the frozen 128-d image feature extractor from the legacy trained model.

    Layer used: ``image_dense`` (Dense(128, activation='relu')) whose input is the
    MobileNetV2 global-average-pooled 1280-d embedding; the legacy 4-class softmax
    head is discarded.
    """
    model_path = Path(model_path) if model_path else Path(LEGACY_IMAGE_MODEL)
    legacy = tf.keras.models.load_model(model_path, compile=False)
    embedding = legacy.get_layer(EMBEDDING_LAYER_NAME).output
    extractor = tf.keras.Model(inputs=legacy.inputs, outputs=embedding,
                               name="hybrid_production_image_feature_extractor")
    extractor.trainable = False
    return extractor


def preprocess_for_extractor(image_rgb: np.ndarray) -> np.ndarray:
    """Resize to 224x224 and apply MobileNetV2 preprocess_input (scale to [-1, 1])."""
    img = tf.convert_to_tensor(image_rgb, dtype=tf.float32)
    img = tf.image.resize(img, IMAGE_INPUT_SIZE)
    return tf.keras.applications.mobilenet_v2.preprocess_input(img).numpy()


def extract_image_features(extractor: tf.keras.Model, image_rgb: np.ndarray) -> np.ndarray:
    """Run the extractor on one RGB uint8/hfloat image -> 128-d float32 embedding."""
    batch = preprocess_for_extractor(image_rgb)[None, ...]
    emb = extractor.predict(batch, verbose=0)
    return np.asarray(emb, dtype=np.float32).reshape(-1)


def export_image_extractor_tflite(output_path: Path, model_path: Path | None = None) -> Path:
    """Convert ONLY the feature extractor to TFLite (input [1,224,224,3] -> output [1,128])."""
    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    extractor = load_image_feature_extractor(model_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(extractor)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    output_path.write_bytes(tflite_model)
    return output_path


def tflite_extract_image_features(tflite_path: Path, image_rgb: np.ndarray) -> np.ndarray:
    """Interpreter-based extraction (mirrors the Flutter side exactly)."""
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    batch = preprocess_for_extractor(image_rgb).astype(np.float32)[None, ...]
    interpreter.set_tensor(inp["index"], batch)
    interpreter.invoke()
    return interpreter.get_tensor(out["index"]).reshape(-1)
