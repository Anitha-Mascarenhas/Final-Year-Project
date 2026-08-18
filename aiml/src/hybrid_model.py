from __future__ import annotations

from pathlib import Path
from typing import Optional

import tensorflow as tf
from tensorflow.keras import layers

from config import IMAGE_SIZE, LEARNING_RATE, MODEL_DIR
from utils import ensure_dir


class HybridModelTrainer:
    """Build and train a multimodal hybrid network combining image and tabular inputs."""

    def __init__(self, model_dir: Path = MODEL_DIR):
        self.model_dir = ensure_dir(model_dir)
        self.model: Optional[tf.keras.Model] = None

    def build_model(
        self,
        num_classes: int,
        measurement_feature_dim: int,
        cv_feature_dim: int,
        image_embedding_dim: int = 128,
    ) -> tf.keras.Model:
        image_input = layers.Input(shape=(*IMAGE_SIZE, 3), name="image_input")
        base_model = tf.keras.applications.MobileNetV2(
            input_shape=(*IMAGE_SIZE, 3),
            include_top=False,
            weights="imagenet",
            pooling="avg",
        )
        base_model.trainable = False
        image_embedding = base_model(image_input, training=False)
        image_embedding = layers.Dense(image_embedding_dim, activation="relu", name="image_embedding")(image_embedding)

        measurement_input = layers.Input(shape=(measurement_feature_dim,), name="measurement_input")
        measurement_branch = layers.Dense(64, activation="relu")(measurement_input)
        measurement_branch = layers.Dense(32, activation="relu")(measurement_branch)

        cv_input = layers.Input(shape=(cv_feature_dim,), name="cv_input")
        cv_branch = layers.Dense(64, activation="relu")(cv_input)
        cv_branch = layers.Dense(32, activation="relu")(cv_branch)

        merged = layers.concatenate([image_embedding, measurement_branch, cv_branch], name="fusion_layer")
        merged = layers.Dropout(0.4)(merged)
        merged = layers.Dense(128, activation="relu")(merged)
        merged = layers.Dense(64, activation="relu")(merged)
        output = layers.Dense(num_classes, activation="softmax", name="output_layer")(merged)

        model = tf.keras.Model(inputs=[image_input, measurement_input, cv_input], outputs=output, name="hybrid_model")
        assert model.output_shape[-1] == num_classes, (
            f"Hybrid model output size {model.output_shape[-1]} does not match num_classes {num_classes}."
        )
        model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE),
            loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=False),
            metrics=[
                tf.keras.metrics.SparseCategoricalAccuracy(name="sparse_categorical_accuracy"),
            ],
        )
        self.model = model
        return model

    def save(self, path: Path) -> None:
        ensure_dir(path.parent)
        if self.model is None:
            raise ValueError("Model must be built or trained before saving.")
        self.model.save(path)

    def load(self, path: Path) -> tf.keras.Model:
        self.model = tf.keras.models.load_model(path)
        return self.model
