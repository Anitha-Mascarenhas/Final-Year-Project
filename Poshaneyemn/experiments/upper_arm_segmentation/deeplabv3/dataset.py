"""
Dataset loader and augmentation for Upper-Arm Segmentation.
"""

from pathlib import Path
from typing import Tuple
import numpy as np
import pandas as pd
from PIL import Image
import tensorflow as tf


def load_image_and_mask(
    image_path: Path, mask_path: Path, target_size: Tuple[int, int] = (512, 512)
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Loads and preprocesses a single image and mask pair:
    - Image: RGB, resized to target_size with bilinear interpolation, normalized via ImageNet [0, 1] / mean-std
    - Mask: resized to target_size with NEAREST-NEIGHBOR interpolation, values strictly in {0, 1}
    """
    # 1. Load Image
    with Image.open(image_path) as img:
        img_rgb = img.convert("RGB")
        img_resized = img_rgb.resize(target_size, Image.Resampling.BILINEAR)
        img_arr = np.array(img_resized, dtype=np.float32)

    # ImageNet normalization: mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]
    img_arr = img_arr / 255.0
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
    img_norm = (img_arr - mean) / std

    # 2. Load Mask
    with Image.open(mask_path) as msk:
        # STRICTLY nearest-neighbor interpolation to prevent interpolation artifacts
        msk_resized = msk.resize(target_size, Image.Resampling.NEAREST)
        msk_arr = np.array(msk_resized, dtype=np.int32)

    # Ensure binary {0, 1}
    msk_bin = (msk_arr > 0).astype(np.int32)
    return img_norm, msk_bin


def augment_pair(img: tf.Tensor, msk: tf.Tensor) -> Tuple[tf.Tensor, tf.Tensor]:
    """
    Lightweight, synchronized augmentation for training set:
    - Random horizontal flip (50% prob)
    """
    # Random horizontal flip
    if tf.random.uniform(()) > 0.5:
        img = tf.image.flip_left_right(img)
        msk = tf.image.flip_left_right(msk)

    return img, msk


def create_dataset(
    csv_path: Path,
    images_dir: Path,
    masks_dir: Path,
    batch_size: int = 4,
    is_training: bool = False,
    shuffle_buffer: int = 200,
    seed: int = 42
) -> tf.data.Dataset:
    """
    Creates a tf.data.Dataset pipeline from split CSV.
    """
    df = pd.read_csv(csv_path)
    img_paths = [str(images_dir / row["image_name"]) for _, row in df.iterrows()]
    mask_paths = [str(masks_dir / row["mask_name"]) for _, row in df.iterrows()]

    def py_load_fn(img_p_bytes, msk_p_bytes):
        img_p = Path(img_p_bytes.numpy().decode("utf-8"))
        msk_p = Path(msk_p_bytes.numpy().decode("utf-8"))
        img_arr, msk_arr = load_image_and_mask(img_p, msk_p)
        return img_arr, msk_arr

    def tf_load_fn(img_p, msk_p):
        img, msk = tf.py_function(py_load_fn, [img_p, msk_p], [tf.float32, tf.int32])
        img.set_shape((512, 512, 3))
        msk.set_shape((512, 512))
        return img, msk

    ds = tf.data.Dataset.from_tensor_slices((img_paths, mask_paths))

    if is_training:
        ds = ds.shuffle(buffer_size=shuffle_buffer, seed=seed, reshuffle_each_iteration=True)

    ds = ds.map(tf_load_fn, num_parallel_calls=tf.data.AUTOTUNE)

    if is_training:
        def tf_aug_fn(img, msk):
            msk_3d = tf.expand_dims(msk, -1)
            img_aug, msk_aug_3d = augment_pair(img, msk_3d)
            return img_aug, tf.squeeze(msk_aug_3d, -1)
        ds = ds.map(tf_aug_fn, num_parallel_calls=tf.data.AUTOTUNE)

    ds = ds.batch(batch_size)
    ds = ds.prefetch(tf.data.AUTOTUNE)
    return ds
