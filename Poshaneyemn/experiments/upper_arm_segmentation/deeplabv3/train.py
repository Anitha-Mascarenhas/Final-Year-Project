"""
Training script for DeepLabV3+ (MobileNetV2 backbone) Upper-Arm Segmentation.
"""

import sys
import json
import random
from pathlib import Path
import numpy as np
import pandas as pd
import tensorflow as tf

from config import (
    IMAGES_DIR,
    MASKS_DIR,
    TRAIN_CSV,
    VAL_CSV,
    TEST_CSV,
    BEST_MODEL_PATH,
    LAST_MODEL_PATH,
    TRAINING_HISTORY_CSV,
    TEST_METRICS_JSON,
    TEST_PREDICTIONS_DIR,
    BATCH_SIZE,
    LEARNING_RATE,
    WEIGHT_DECAY,
    MAX_EPOCHS,
    EARLY_STOPPING_PATIENCE,
    RANDOM_SEED,
    CE_WEIGHT,
    DICE_WEIGHT
)
from model import build_deeplabv3plus
from dataset import create_dataset
from losses_metrics import CombinedLoss, compute_batch_metrics


def set_seed(seed=42):
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)


def run_training():
    set_seed(RANDOM_SEED)

    print("=" * 65)
    print("DEEPLABV3+ (MOBILENETV2) UPPER-ARM SEGMENTATION TRAINING")
    print(f"Random seed: {RANDOM_SEED}")
    print("=" * 65)

    # 1. Dataset verification
    df_train = pd.read_csv(TRAIN_CSV)
    df_val = pd.read_csv(VAL_CSV)
    df_test = pd.read_csv(TEST_CSV)

    print(f"Train images: {len(df_train)}")
    print(f"Validation images: {len(df_val)}")
    print(f"Test images: {len(df_test)}")

    # Verify counts
    assert len(df_train) == 172, f"Expected 172 train images, found {len(df_train)}"
    assert len(df_val) == 37, f"Expected 37 validation images, found {len(df_val)}"
    assert len(df_test) == 37, f"Expected 37 test images, found {len(df_test)}"

    # Verify corresponding masks exist for all splits
    for name, df in [("train", df_train), ("val", df_val), ("test", df_test)]:
        for _, row in df.iterrows():
            img_p = IMAGES_DIR / row["image_name"]
            msk_p = MASKS_DIR / row["mask_name"]
            if not img_p.exists():
                raise FileNotFoundError(f"{name}: Image {img_p} missing!")
            if not msk_p.exists():
                raise FileNotFoundError(f"{name}: Mask {msk_p} missing!")

    print("Verified: All 246 split images have corresponding physical JPG and PNG masks on disk.")

    # 2. Build Datasets
    print(f"\nBuilding tf.data pipelines (batch_size={BATCH_SIZE})...")
    train_ds = create_dataset(
        TRAIN_CSV, IMAGES_DIR, MASKS_DIR, batch_size=BATCH_SIZE, is_training=True, seed=RANDOM_SEED
    )
    val_ds = create_dataset(
        VAL_CSV, IMAGES_DIR, MASKS_DIR, batch_size=BATCH_SIZE, is_training=False
    )
    test_ds = create_dataset(
        TEST_CSV, IMAGES_DIR, MASKS_DIR, batch_size=BATCH_SIZE, is_training=False
    )

    # 3. Build Model & Optimizer
    print("\nInstantiating DeepLabV3+ with pretrained MobileNetV2 backbone...")
    model = build_deeplabv3plus(input_shape=(512, 512, 3), num_classes=2)
    optimizer = tf.keras.optimizers.AdamW(
        learning_rate=LEARNING_RATE, weight_decay=WEIGHT_DECAY
    )
    loss_fn = CombinedLoss(ce_weight=CE_WEIGHT, dice_weight=DICE_WEIGHT)

    # 4. Training Loop with Custom Gradient & Step Tracking
    history = []
    best_val_dice = -1.0
    best_epoch = 0
    patience_counter = 0

    print(f"\nStarting training for up to {MAX_EPOCHS} epochs (Early stopping patience: {EARLY_STOPPING_PATIENCE})...\n")

    @tf.function
    def train_step(images, masks):
        with tf.GradientTape() as tape:
            logits = model(images, training=True)
            loss_val = loss_fn(masks, logits)
        grads = tape.gradient(loss_val, model.trainable_variables)
        optimizer.apply_gradients(zip(grads, model.trainable_variables))
        return loss_val, logits

    @tf.function
    def val_step(images, masks):
        logits = model(images, training=False)
        loss_val = loss_fn(masks, logits)
        return loss_val, logits

    for epoch in range(1, MAX_EPOCHS + 1):
        # Training Phase
        train_loss_list = []
        train_y_true = []
        train_y_pred = []

        for x_batch, y_batch in train_ds:
            loss_val, logits = train_step(x_batch, y_batch)
            train_loss_list.append(float(loss_val.numpy()))
            train_y_true.append(y_batch.numpy())
            train_y_pred.append(logits.numpy())

        train_loss = float(np.mean(train_loss_list))
        train_metrics = compute_batch_metrics(
            np.concatenate(train_y_true, axis=0),
            np.concatenate(train_y_pred, axis=0)
        )

        # Validation Phase
        val_loss_list = []
        val_y_true = []
        val_y_pred = []

        for x_val, y_val in val_ds:
            loss_val, logits = val_step(x_val, y_val)
            val_loss_list.append(float(loss_val.numpy()))
            val_y_true.append(y_val.numpy())
            val_y_pred.append(logits.numpy())

        val_loss = float(np.mean(val_loss_list))
        val_metrics = compute_batch_metrics(
            np.concatenate(val_y_true, axis=0),
            np.concatenate(val_y_pred, axis=0)
        )

        val_dice = val_metrics["dice"]
        val_iou = val_metrics["iou"]

        print(
            f"Epoch {epoch:02d}/{MAX_EPOCHS:02d} | "
            f"Train Loss: {train_loss:.4f}, Dice: {train_metrics['dice']:.4f}, IoU: {train_metrics['iou']:.4f} | "
            f"Val Loss: {val_loss:.4f}, Dice: {val_dice:.4f}, IoU: {val_iou:.4f}"
        )

        history.append({
            "epoch": epoch,
            "train_loss": round(train_loss, 5),
            "val_loss": round(val_loss, 5),
            "train_dice": round(train_metrics["dice"], 5),
            "val_dice": round(val_dice, 5),
            "train_iou": round(train_metrics["iou"], 5),
            "val_iou": round(val_iou, 5)
        })

        # Save Last Model Checkpoint
        model.save_weights(str(LAST_MODEL_PATH))

        # Checkpoint Best Model based on Validation Dice
        if val_dice > best_val_dice:
            best_val_dice = val_dice
            best_epoch = epoch
            patience_counter = 0
            model.save_weights(str(BEST_MODEL_PATH))
            print(f"  --> Saved new best model checkpoint! (Val Dice: {best_val_dice:.4f})")
        else:
            patience_counter += 1
            if patience_counter >= EARLY_STOPPING_PATIENCE:
                print(f"\n[Early Stopping Triggered] No improvement in validation Dice for {EARLY_STOPPING_PATIENCE} epochs.")
                break

    # Save training history
    df_hist = pd.DataFrame(history)
    df_hist.to_csv(TRAINING_HISTORY_CSV, index=False)
    print(f"\nSaved training history to {TRAINING_HISTORY_CSV}")

    # 5. Evaluate Best Model on HELD-OUT TEST SPLIT
    print("\n" + "=" * 65)
    print("EVALUATING BEST MODEL ON HELD-OUT TEST SPLIT (N=37)")
    print("=" * 65)

    model.load_weights(str(BEST_MODEL_PATH))
    print(f"Loaded weights from {BEST_MODEL_PATH.name} (from Epoch {best_epoch})")

    TEST_PREDICTIONS_DIR.mkdir(parents=True, exist_ok=True)

    test_y_true = []
    test_y_pred = []
    test_loss_list = []

    # Also save predicted masks for test images
    test_img_list = df_test["image_name"].tolist()
    pred_idx = 0

    for x_test, y_test in test_ds:
        loss_val, logits = val_step(x_test, y_test)
        test_loss_list.append(float(loss_val.numpy()))
        test_y_true.append(y_test.numpy())
        test_y_pred.append(logits.numpy())

        # Save binary mask for each test image
        preds_batch = np.argmax(logits.numpy(), axis=-1).astype(np.uint8)
        for i in range(len(preds_batch)):
            if pred_idx < len(test_img_list):
                img_n = test_img_list[pred_idx]
                stem = Path(img_n).stem
                out_p = TEST_PREDICTIONS_DIR / f"{stem}.png"
                # Save as binary PNG (values {0, 1})
                from PIL import Image
                Image.fromarray(preds_batch[i]).save(out_p)
                pred_idx += 1

    test_metrics = compute_batch_metrics(
        np.concatenate(test_y_true, axis=0),
        np.concatenate(test_y_pred, axis=0)
    )
    test_metrics["test_loss"] = float(np.mean(test_loss_list))
    test_metrics["best_epoch"] = best_epoch
    test_metrics["best_val_dice"] = float(best_val_dice)

    with open(TEST_METRICS_JSON, "w", encoding="utf-8") as f:
        json.dump(test_metrics, f, indent=4)

    print(f"\nSaved test metrics to {TEST_METRICS_JSON}")
    print("\n--- FINAL TEST RESULTS ---")
    print(f"Foreground Dice    : {test_metrics['dice']:.4f}")
    print(f"Foreground IoU     : {test_metrics['iou']:.4f}")
    print(f"Precision          : {test_metrics['precision']:.4f}")
    print(f"Recall             : {test_metrics['recall']:.4f}")
    print(f"Pixel Accuracy     : {test_metrics['pixel_accuracy']:.4f}")
    print(f"Best Val Dice      : {best_val_dice:.4f} (Epoch {best_epoch})")
    print("=" * 65)


if __name__ == "__main__":
    run_training()
