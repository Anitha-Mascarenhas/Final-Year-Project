from __future__ import annotations

from pathlib import Path
from typing import Iterable

import numpy as np
import pandas as pd
import tensorflow as tf

from config import BATCH_SIZE, IMAGE_SIZE


def _filter_existing_image_samples(
    image_paths: Iterable[str],
    labels: Iterable[int],
) -> tuple[list[str], list[int]]:
    paths = [str(path) for path in image_paths]
    labels_list = list(labels)
    total = len(paths)
    valid_mask = [bool(path) and Path(path).exists() for path in paths]
    valid_count = int(sum(valid_mask))
    removed_count = total - valid_count
    print(
        f"[ImageDataset] Total samples: {total}, valid samples: {valid_count}, removed samples: {removed_count}"
    )
    filtered_paths = [path for path, valid in zip(paths, valid_mask) if valid]
    filtered_labels = [label for label, valid in zip(labels_list, valid_mask) if valid]
    assert all(Path(path).exists() for path in filtered_paths), "All image paths must exist before building the dataset."
    return filtered_paths, filtered_labels


def preprocess_image(image_path: tf.Tensor) -> tf.Tensor:
    """Read and normalize an image from disk."""
    image = tf.io.read_file(image_path)
    image = tf.image.decode_image(image, channels=3, expand_animations=False)
    image = tf.image.resize(image, IMAGE_SIZE)
    image = tf.cast(image, tf.float32) / 255.0
    return image


def image_path_to_tensor(image_path: tf.Tensor, label: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
    """Map an image path and label into a processed tensor pair."""
    return preprocess_image(image_path), label


def build_image_dataset(
    image_paths: Iterable[str],
    labels: Iterable[int],
    batch_size: int = BATCH_SIZE,
    shuffle: bool = True,
) -> tf.data.Dataset:
    """Create a tf.data dataset for supervised image classification."""
    paths, labels = _filter_existing_image_samples(image_paths, labels)
    if len(paths) == 0:
        raise ValueError("No existing image files were found for dataset creation.")

    paths_tensor = tf.constant(paths, dtype=tf.string)
    labels_tensor = tf.constant(labels, dtype=tf.int32)
    dataset = tf.data.Dataset.from_tensor_slices((paths_tensor, labels_tensor))
    if shuffle:
        dataset = dataset.shuffle(buffer_size=len(paths), seed=42)
    dataset = dataset.map(image_path_to_tensor, num_parallel_calls=tf.data.AUTOTUNE)
    dataset = dataset.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return dataset


def build_hybrid_dataset(
    image_paths: Iterable[str],
    measurement_features: np.ndarray,
    cv_features: np.ndarray,
    labels: Iterable[int],
    batch_size: int = BATCH_SIZE,
    shuffle: bool = True,
) -> tf.data.Dataset:
    """Create a tf.data dataset for multimodal hybrid training."""
    paths, labels = _filter_existing_image_samples(image_paths, labels)
    if len(paths) == 0:
        raise ValueError("No existing image files were found for hybrid dataset creation.")

    measurement_array = np.asarray(measurement_features, dtype=np.float32)
    cv_array = np.asarray(cv_features, dtype=np.float32)
    if measurement_array.ndim != 2 or cv_array.ndim != 2:
        raise ValueError(
            "Measurement and CV feature arrays must be 2D arrays with shape [num_samples, feature_dim]."
        )
    if measurement_array.shape[0] != len(paths) or cv_array.shape[0] != len(paths):
        raise ValueError(
            "Measurement/CV feature arrays must have the same number of rows as filtered image paths. "
            f"Found {measurement_array.shape[0]} measurement rows, {cv_array.shape[0]} CV rows, and {len(paths)} image paths."
        )

    paths_tensor = tf.constant(paths, dtype=tf.string)
    measurement_tensor = tf.constant(measurement_array, dtype=tf.float32)
    cv_tensor = tf.constant(cv_array, dtype=tf.float32)
    labels_tensor = tf.constant(labels, dtype=tf.int32)
    if labels_tensor.shape.ndims is not None and labels_tensor.shape.ndims != 1:
        if labels_tensor.shape.ndims == 2 and labels_tensor.shape[-1] == 1:
            labels_tensor = tf.reshape(labels_tensor, [-1])
        else:
            raise ValueError(
                "Labels must be a 1D vector of integer class IDs for sparse_categorical_crossentropy. "
                "One-hot encoded labels are not supported by this hybrid dataset builder."
            )

    dataset = tf.data.Dataset.from_tensor_slices(({
        "image_input": paths_tensor,
        "measurement_input": measurement_tensor,
        "cv_input": cv_tensor,
    }, labels_tensor))
    if shuffle:
        dataset = dataset.shuffle(buffer_size=len(paths), seed=42)

    def map_inputs(inputs, label):
        image_tensor = preprocess_image(inputs["image_input"])
        return {
            "image_input": image_tensor,
            "measurement_input": inputs["measurement_input"],
            "cv_input": inputs["cv_input"],
        }, label

    dataset = dataset.map(map_inputs, num_parallel_calls=tf.data.AUTOTUNE)
    dataset = dataset.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return dataset
