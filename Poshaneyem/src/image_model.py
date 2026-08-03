from __future__ import annotations

from pathlib import Path
from typing import Optional

import tensorflow as tf
from tensorflow.keras import layers
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.callbacks import (
    EarlyStopping,
    ModelCheckpoint,
    ReduceLROnPlateau,
    TensorBoard,
)

from config import (
    BATCH_SIZE,
    IMAGE_SIZE,
    LEARNING_RATE,
    LOG_DIR,
    MODEL_DIR,
    TFLITE_FILENAME,
    VALIDATION_SIZE,
    EPOCHS,
)
from utils import ensure_dir


class ImageModelTrainer:
    """Build and train a transfer learning image classification model."""

    def __init__(self, model_dir: Path = MODEL_DIR, log_dir: Path = LOG_DIR):
        self.model_dir = ensure_dir(model_dir)
        self.log_dir = ensure_dir(log_dir)
        self.model: Optional[tf.keras.Model] = None

    def build_model(self, num_classes: int, loss: tf.keras.losses.Loss, metrics: list[tf.keras.metrics.Metric]) -> tf.keras.Model:
        base_model = MobileNetV2(
            input_shape=(*IMAGE_SIZE, 3),
            include_top=False,
            weights="imagenet",
            pooling="avg",
        )
        base_model.trainable = False

        inputs = layers.Input(shape=(*IMAGE_SIZE, 3), name="image_input")
        x = base_model(inputs, training=False)
        x = layers.Dropout(0.3)(x)
        x = layers.Dense(128, activation="relu", name="image_dense")(x)
        outputs = layers.Dense(num_classes, activation="softmax", name="image_output")(x)

        model = tf.keras.Model(inputs=inputs, outputs=outputs, name="mobilenet_image_model")
        assert model.output_shape[-1] == num_classes, (
            f"Model output size {model.output_shape[-1]} does not match num_classes {num_classes}."
        )
        model.compile(
            optimizer=tf.keras.optimizers.Adam(learning_rate=LEARNING_RATE),
            loss=loss,
            metrics=metrics,
        )
        self.model = model
        return model

    def train(
        self,
        train_dataset: tf.data.Dataset,
        validation_dataset: tf.data.Dataset,
        num_classes: int,
        epochs: int = EPOCHS,
    ) -> tf.keras.callbacks.History:
        if self.model is None:
            loss = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=False)
            metrics = [
                tf.keras.metrics.SparseCategoricalAccuracy(name="sparse_categorical_accuracy"),
                tf.keras.metrics.SparseTopKCategoricalAccuracy(k=3, name="sparse_top_3_accuracy"),
            ]
            self.build_model(num_classes=num_classes, loss=loss, metrics=metrics)

        checkpoint_path = self.model_dir / "image_best.h5"
        callbacks = [
            EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True),
            ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=3, verbose=1),
            ModelCheckpoint(checkpoint_path, monitor="val_loss", save_best_only=True, verbose=1),
            TensorBoard(log_dir=self.log_dir / "image_model"),
        ]

        # Inspect a single batch for shape compatibility before training begins.
        for image_batch, label_batch in train_dataset.take(1):
            print("[ImageModel] sample batch image shape:", image_batch.shape)
            print("[ImageModel] sample batch label shape:", label_batch.shape)
            sample_output = self.model(image_batch, training=False)
            print("[ImageModel] model output shape:", sample_output.shape)
            break

        history = self.model.fit(
            train_dataset,
            validation_data=validation_dataset,
            epochs=epochs,
            callbacks=callbacks,
        )
        self.model = tf.keras.models.load_model(checkpoint_path)
        return history

    def save_tflite(self, path: Path) -> None:
        if self.model is None:
            raise ValueError("Model must be trained before conversion.")
        ensure_dir(path.parent)
        converter = tf.lite.TFLiteConverter.from_keras_model(self.model)
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_model = converter.convert()
        path.write_bytes(tflite_model)

    def save(self, path: Path) -> None:
        ensure_dir(path.parent)
        if self.model is None:
            raise ValueError("Model must be built or trained before saving.")
        self.model.save(path)

    def load(self, path: Path) -> tf.keras.Model:
        self.model = tf.keras.models.load_model(path)
        return self.model
