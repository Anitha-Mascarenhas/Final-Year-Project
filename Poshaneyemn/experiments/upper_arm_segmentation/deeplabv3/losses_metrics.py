"""
Losses and Evaluation Metrics for Binary Upper-Arm Segmentation.
"""

import tensorflow as tf
import numpy as np


class CombinedLoss(tf.keras.losses.Loss):
    """
    Combined Segmentation Loss: 0.5 * SparseCategoricalCrossentropy + 0.5 * DiceLoss
    Ensures numerical stability with smoothing epsilon.
    """
    def __init__(self, ce_weight=0.5, dice_weight=0.5, smooth=1e-6, name="combined_loss"):
        super().__init__(name=name)
        self.ce_weight = ce_weight
        self.dice_weight = dice_weight
        self.smooth = smooth
        self.scce = tf.keras.losses.SparseCategoricalCrossentropy(from_logits=True)

    def call(self, y_true, y_pred):
        """
        y_true: (batch, H, W) integer {0, 1}
        y_pred: (batch, H, W, 2) logits
        """
        # 1. Cross-Entropy Loss
        ce_loss = self.scce(y_true, y_pred)

        # 2. Dice Loss for Foreground (class 1)
        probs = tf.nn.softmax(y_pred, axis=-1)
        fg_probs = probs[..., 1]  # shape (batch, H, W)
        fg_true = tf.cast(y_true == 1, tf.float32)  # shape (batch, H, W)

        # Flatten spatial dims per batch item
        fg_probs_flat = tf.reshape(fg_probs, [tf.shape(fg_probs)[0], -1])
        fg_true_flat = tf.reshape(fg_true, [tf.shape(fg_true)[0], -1])

        intersection = tf.reduce_sum(fg_probs_flat * fg_true_flat, axis=-1)
        union = tf.reduce_sum(fg_probs_flat, axis=-1) + tf.reduce_sum(fg_true_flat, axis=-1)

        dice_per_batch = (2.0 * intersection + self.smooth) / (union + self.smooth)
        dice_loss = 1.0 - tf.reduce_mean(dice_per_batch)

        return self.ce_weight * ce_loss + self.dice_weight * dice_loss


def compute_batch_metrics(y_true: np.ndarray, y_pred_logits: np.ndarray, smooth: float = 1e-6) -> dict:
    """
    Computes segmentation metrics across a batch or dataset:
    - Foreground Dice
    - Foreground IoU / Jaccard
    - Precision
    - Recall
    - Pixel Accuracy
    """
    # Prediction: argmax over class axis -> binary mask {0, 1}
    y_pred_bin = np.argmax(y_pred_logits, axis=-1).astype(np.int32)
    y_true_bin = (y_true == 1).astype(np.int32)

    tp = np.sum((y_pred_bin == 1) & (y_true_bin == 1))
    fp = np.sum((y_pred_bin == 1) & (y_true_bin == 0))
    fn = np.sum((y_pred_bin == 0) & (y_true_bin == 1))
    tn = np.sum((y_pred_bin == 0) & (y_true_bin == 0))

    # Foreground Dice
    dice = (2.0 * tp + smooth) / (2.0 * tp + fp + fn + smooth)

    # Foreground IoU
    iou = (tp + smooth) / (tp + fp + fn + smooth)

    # Precision & Recall
    precision = (tp + smooth) / (tp + fp + smooth)
    recall = (tp + smooth) / (tp + fn + smooth)

    # Pixel Accuracy
    pixel_acc = (tp + tn) / (tp + tn + fp + fn)

    return {
        "dice": float(dice),
        "iou": float(iou),
        "precision": float(precision),
        "recall": float(recall),
        "pixel_accuracy": float(pixel_acc),
        "tp": int(tp),
        "fp": int(fp),
        "fn": int(fn),
        "tn": int(tn)
    }
