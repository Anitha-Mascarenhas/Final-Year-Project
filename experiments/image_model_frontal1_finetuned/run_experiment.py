#!/usr/bin/env python3
"""
Child-level balanced BINARY fine-tuning experiment (AnthroVision only, frontal1 only).

Same 1,282 balanced children and same child-level split as the previous frontal1-only
experiment (897 train / 192 validation / 193 test, zero child overlap). Each child
contributes exactly one frontal1 image.

Pipeline:
  1. Build base MobileNetV2 (ImageNet, frozen) + binary classifier head.
  2. Train the head with freeze + augmentation + early stopping + LR reduction.
  3. Unfreeze the last ~25 MobileNetV2 layers and fine-tune with a much smaller LR.
  4. Select the best checkpoint from PHASE 2 validation balanced accuracy.
  5. Choose the classification threshold from the validation set only.
  6. Evaluate ONCE on the untouched test set with that threshold.
  7. Export Keras + TFLite and compare Keras vs TFLite.

Nothing under Poshaneyemn/models/ or any production artifact is modified.
All outputs go under experiments/image_model_frontal1_finetuned/.
"""
from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

import numpy as np
import tensorflow as tf
from tensorflow.keras import applications, layers, models, optimizers
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from tensorflow.keras.layers import RandomContrast, RandomFlip, RandomTranslation, RandomZoom
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)

HERE = Path(__file__).resolve().parent
ARTIFACT_DIR = HERE / "artifacts"
RESULT_DIR = HERE / "results"
FRECONAL1_MANIFEST = HERE.parent / "image_model_frontal1_only" / "frontal1_manifest.json"

IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
HEAD_LR = 1e-4
FT_LR = 5e-6
FT_UNFROZEN_LAST_N = 25
HEAD_EPOCHS = 20
FT_EPOCHS = 25
EARLY_STOP_PATIENCE = 6
LR_PATIENCE = 3
MIN_DELTA = 1e-4
DROPOUT_RATE = 0.3
RANDOM_STATE = 42
CLASS_NAMES = ["healthy", "malnourished"]
THRESHOLD_CANDIDATES = [t / 100.0 for t in range(10, 91, 1)]
HEALTHY_RECALL_FLOOR = 0.55


def preprocess_image(path: str) -> tf.Tensor:
    img = tf.io.read_file(path)
    img = tf.image.decode_jpeg(img, channels=3)
    img = tf.image.resize(img, IMAGE_SIZE, method="bicubic")
    img = tf.cast(img, tf.float32)
    img = applications.mobilenet_v2.preprocess_input(img)
    return img


def build_augment():
    return tf.keras.Sequential(
        [
            RandomFlip("horizontal"),
            RandomContrast(0.1),
            RandomTranslation(height_factor=0.05, width_factor=0.05, fill_mode="nearest"),
            RandomZoom(height_factor=0.05, width_factor=0.05, fill_mode="nearest"),
        ],
        name="train_augment",
    )


def build_base():
    return applications.MobileNetV2(
        input_shape=(IMAGE_SIZE[0], IMAGE_SIZE[1], 3),
        include_top=False,
        weights="imagenet",
        pooling="avg",
    )


def build_head_model(base: tf.keras.Model):
    base.trainable = False
    inputs = layers.Input(shape=(IMAGE_SIZE[0], IMAGE_SIZE[1], 3), name="image_input")
    x = applications.mobilenet_v2.preprocess_input(inputs)
    x = base(x, training=False)
    x = layers.Dropout(DROPOUT_RATE)(x)
    x = layers.Dense(32, activation="relu")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="malnourished_prob")(x)
    model = models.Model(inputs, outputs, name="mobilenetv2_binary_frontal1")
    model.compile(
        optimizer=optimizers.Adam(learning_rate=HEAD_LR),
        loss="binary_crossentropy",
        metrics=[
            "accuracy",
            tf.keras.metrics.BalancedAccuracy(name="balanced_accuracy"),
            tf.keras.metrics.Recall(name="recall_malnourished"),
            tf.keras.metrics.Precision(name="precision_malnourished"),
        ],
    )
    return model


def build_finetune_model(base: tf.keras.Model, unfreeze_last_n: int = FT_UNFROZEN_LAST_N):
    base.trainable = False
    for layer in base.layers[-unfreeze_last_n:]:
        layer.trainable = True

    inputs = layers.Input(shape=(IMAGE_SIZE[0], IMAGE_SIZE[1], 3), name="image_input")
    x = applications.mobilenet_v2.preprocess_input(inputs)
    x = base(x, training=True)
    x = layers.Dropout(DROPOUT_RATE)(x)
    x = layers.Dense(32, activation="relu")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="malnourished_prob")(x)
    model = models.Model(inputs, outputs, name="mobilenetv2_binary_frontal1_finetuned")
    model.compile(
        optimizer=optimizers.Adam(learning_rate=FT_LR),
        loss="binary_crossentropy",
        metrics=[
            "accuracy",
            tf.keras.metrics.BalancedAccuracy(name="balanced_accuracy"),
            tf.keras.metrics.Recall(name="recall_malnourished"),
            tf.keras.metrics.Precision(name="precision_malnourished"),
        ],
    )
    return model


def build_tf_dataset(paths, labels, augment=False, shuffle=True, cache_dir=None):
    ds = tf.data.Dataset.from_tensor_slices((list(paths), list(labels)))
    if shuffle:
        ds = ds.shuffle(len(paths), seed=RANDOM_STATE, reshuffle_each_iteration=True)
    if cache_dir:
        ds = ds.cache(cache_dir)
    if augment:
        ds = ds.map(
            lambda p, l: (build_augment()(preprocess_image(p)), l),
            num_parallel_calls=tf.data.AUTOTUNE,
        )
    else:
        ds = ds.map(
            lambda p, l: (preprocess_image(p), l),
            num_parallel_calls=tf.data.AUTOTUNE,
        )
    return ds.batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)


def threshold_metrics(y_true, probabilities, threshold=0.5):
    y_true = np.asarray(y_true).astype(int)
    probabilities = np.asarray(probabilities, dtype=float)
    y_pred = (probabilities >= threshold).astype(int)
    tn = int(((y_true == 0) & (y_pred == 0)).sum())
    fp = int(((y_true == 0) & (y_pred == 1)).sum())
    fn = int(((y_true == 1) & (y_pred == 0)).sum())
    tp = int(((y_true == 1) & (y_pred == 1)).sum())
    healthy_recall = recall_score(1 - y_true, 1 - y_pred, zero_division=0)
    return {
        "n": int(len(y_true)),
        "threshold": float(threshold),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "precision_malnourished": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall_malnourished": float(recall_score(y_true, y_pred, zero_division=0)),
        "f1_malnourished": float(f1_score(y_true, y_pred, zero_division=0)),
        "recall_healthy": float(healthy_recall),
        "mean_probability": float(probabilities.mean()),
        "predicted_malnourished": int(y_pred.sum()),
        "confusion_matrix": {
            "tn": tn,
            "fp": fp,
            "fn": fn,
            "tp": tp,
            "_rows": "true",
            "_cols": "predicted",
            "labels": [[0, 1]],
        },
    }


def binary_metrics(y_true, probabilities):
    m = threshold_metrics(y_true, probabilities)
    if len(set(y_true.tolist())) > 1:
        m["roc_auc"] = float(roc_auc_score(y_true, probabilities))
    else:
        m["roc_auc"] = None
    return m


def tflite_predict(interpreter, paths, batch_size=BATCH_SIZE):
    input_index = interpreter.get_input_details()[0]["index"]
    output_index = interpreter.get_output_details()[0]["index"]
    probs = []
    for i in range(0, len(paths), batch_size):
        batch_paths = paths[i : i + batch_size]
        batch_imgs = np.array(
            [preprocess_image(p).numpy() for p in batch_paths], dtype=np.float32
        )
        interpreter.set_tensor(input_index, batch_imgs)
        interpreter.invoke()
        probs.append(interpreter.get_tensor(output_index).ravel())
    return np.concatenate(probs)


def select_threshold(y_true, probabilities, healthy_recall_floor=HEALTHY_RECALL_FLOOR):
    best_threshold = 0.5
    best_balanced = -1.0
    best_metrics = None
    for t in THRESHOLD_CANDIDATES:
        m = threshold_metrics(y_true, probabilities, t)
        if m["recall_healthy"] < healthy_recall_floor:
            continue
        if m["balanced_accuracy"] > best_balanced:
            best_balanced = m["balanced_accuracy"]
            best_threshold = t
            best_metrics = m
    if best_metrics is None:
        best_balanced = -1.0
        for t in THRESHOLD_CANDIDATES:
            m = threshold_metrics(y_true, probabilities, t)
            if m["balanced_accuracy"] > best_balanced:
                best_balanced = m["balanced_accuracy"]
                best_threshold = t
                best_metrics = m
    return float(best_threshold), best_metrics


def subgroup_recall(test_tags, probabilities, manifest):
    tag_to_subgroup = {
        it["tag"]: it.get("subgroup", "unknown") for it in (test_items if outer_manifest is None else outer_manifest["splits"]["test"]["items"])
    }
    prob_by_tag = {tag: [] for tag in set(test_tags)}
    for tag, prob in zip(test_tags, probabilities.tolist()):
        prob_by_tag[tag].append(float(prob))
    child_probs = {tag: float(np.mean(v)) for tag, v in prob_by_tag.items()}
    child_preds = {tag: 1 if child_probs[tag] >= 0.5 else 0 for tag in child_probs}
    subgroup_stats = {}
    for sub in ["underweight", "stunted and underweight", "stunted"]:
        tags_in_sub = [it["tag"] for it in (test_items if outer_manifest is None else outer_manifest["splits"]["test"]["items"]) if it.get("subgroup") == sub]
        if not tags_in_sub:
            subgroup_stats[sub] = {"n_children": 0, "recall": None, "mean_probability": None}
            continue
        y_true = [1 if tag_to_subgroup[t] != "healthy" else 0 for t in tags_in_sub]
        y_pred = [child_preds[t] for t in tags_in_sub]
        sub_probs = [child_probs[t] for t in tags_in_sub]
        subgroup_stats[sub] = {
            "n_children": len(tags_in_sub),
            "recall": float(recall_score(y_true, y_pred, zero_division=0)),
            "mean_probability": float(np.mean(sub_probs)) if sub_probs else None,
        }
    return subgroup_stats


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    RESULT_DIR.mkdir(parents=True, exist_ok=True)

    manifest_raw = json.loads(FRECONAL1_MANIFEST.read_text(encoding="utf-8-sig"))
    if isinstance(manifest_raw, dict) and "splits" in manifest_raw:
        outer_manifest = manifest_raw
        manifest = manifest_raw["splits"]
    else:
        outer_manifest = None
        manifest = manifest_raw

    train_items = manifest["train"]["items"]
    val_items = manifest["validation"]["items"]
    test_items = manifest["test"]["items"]

    train_paths = [it["path"] for it in train_items]
    train_labels = [int(it["label"]) for it in train_items]
    train_tags = [it["tag"] for it in train_items]

    val_paths = [it["path"] for it in val_items]
    val_labels = [int(it["label"]) for it in val_items]
    val_tags = [it["tag"] for it in val_items]

    test_paths = [it["path"] for it in test_items]
    test_labels = [int(it["label"]) for it in test_items]
    test_tags = [it["tag"] for it in test_items]

    print("child-level frontal1 train split:", len(train_paths))
    print("  healthy:", sum(train_labels), "malnourished:", int(len(train_labels) - sum(train_labels)))
    print("child-level frontal1 validation split:", len(val_paths))
    print("  healthy:", sum(val_labels), "malnourished:", int(len(val_labels) - sum(val_labels)))
    print("child-level frontal1 test split:", len(test_paths))
    print("  healthy:", sum(test_labels), "malnourished:", int(len(test_labels) - sum(test_labels)))
    print(f"threshold candidates: {len(THRESHOLD_CANDIDATES)} in [0.10, 0.90]")
    print(f"healthy recall floor for thresholding: {HEALTHY_RECALL_FLOOR}")
    print("-" * 70)

    cache_dir = os.path.join(str(HERE), "cache", "train_cache.tfdata")

    print(f"PHASE 1: train frozen MobileNetV2 + head for up to {HEAD_EPOCHS} epochs")
    t0 = time.time()
    base = build_base()
    head_model = build_head_model(base)

    head_callbacks = [
        EarlyStopping(
            monitor="val_balanced_accuracy",
            patience=EARLY_STOP_PATIENCE,
            min_delta=MIN_DELTA,
            mode="max",
            restore_best_weights=True,
        ),
        ReduceLROnPlateau(
            monitor="val_balanced_accuracy",
            patience=LR_PATIENCE,
            min_delta=MIN_DELTA,
            factor=0.5,
            mode="max",
        ),
        ModelCheckpoint(
            filepath=str(ARTIFACT_DIR / "head_best.keras"),
            monitor="val_balanced_accuracy",
            save_best_only=True,
        ),
    ]

    head_ds = build_tf_dataset(train_paths, train_labels, augment=True, shuffle=True, cache_dir=cache_dir)
    val_ds = build_tf_dataset(val_paths, val_labels, augment=False, shuffle=False)
    test_ds = build_tf_dataset(test_paths, test_labels, augment=False, shuffle=False)

    head_history = head_model.fit(
        head_ds,
        validation_data=val_ds,
        epochs=HEAD_EPOCHS,
        callbacks=head_callbacks,
        verbose=1,
    )
    print(f"PHASE 1 training finished in {time.time() - t0:.1f}s")

    head_model = models.load_model(ARTIFACT_DIR / "head_best.keras")
    val_probs_head = head_model.predict(val_ds, verbose=0).ravel()
    head_val_metrics = binary_metrics(np.array(val_labels), val_probs_head)
    print(f"PHASE 1 validation balanced accuracy: {head_val_metrics['balanced_accuracy']:.4f}")

    print(f"PHASE 2: fine-tune last {FT_UNFROZEN_LAST_N} MobileNetV2 layers for up to {FT_EPOCHS} epochs")
    t0 = time.time()
    ft_model = build_finetune_model(base, FT_UNFROZEN_LAST_N)

    ft_train_ds = build_tf_dataset(train_paths, train_labels, augment=True, shuffle=True, cache_dir=cache_dir)
    ft_callbacks = [
        EarlyStopping(
            monitor="val_balanced_accuracy",
            patience=EARLY_STOP_PATIENCE,
            min_delta=MIN_DELTA,
            mode="max",
            restore_best_weights=True,
        ),
        ReduceLROnPlateau(
            monitor="val_balanced_accuracy",
            patience=LR_PATIENCE,
            min_delta=MIN_DELTA,
            factor=0.5,
            mode="max",
        ),
        ModelCheckpoint(
            filepath=str(ARTIFACT_DIR / "finetuned_best.keras"),
            monitor="val_balanced_accuracy",
            save_best_only=True,
        ),
    ]

    ft_history = ft_model.fit(
        ft_train_ds,
        validation_data=val_ds,
        epochs=FT_EPOCHS,
        callbacks=ft_callbacks,
        verbose=1,
    )
    print(f"PHASE 2 training finished in {time.time() - t0:.1f}s")

    best_ft = models.load_model(ARTIFACT_DIR / "finetuned_best.keras")
    ft_epoch = int(np.argmin(ft_history.history["val_loss"]) + 1)

    val_probs_ft = best_ft.predict(val_ds, verbose=0).ravel()
    ft_val_metrics = binary_metrics(np.array(val_labels), val_probs_ft)
    print(f"PHASE 2 best validation balanced accuracy: {ft_val_metrics['balanced_accuracy']:.4f}")
    print(f"PHASE 2 best validation loss epoch index (1-based): {ft_epoch}")

    print("selecting threshold on validation set ...")
    best_threshold, threshold_metrics_val = select_threshold(
        np.array(val_labels), val_probs_ft, healthy_recall_floor=HEALTHY_RECALL_FLOOR
    )
    print(f"selected threshold: {best_threshold:.2f}")
    print(
        "validation @ threshold -> balanced accuracy:",
        round(threshold_metrics_val["balanced_accuracy"], 4),
        "healthy recall:",
        round(threshold_metrics_val["recall_healthy"], 4),
    )
    print("-" * 70)

    print("evaluating on untouched test set ...")
    test_probs_ft = best_ft.predict(test_ds, verbose=0).ravel()
    test_metrics_ft = threshold_metrics(np.array(test_labels), test_probs_ft, best_threshold)
    test_roc = roc_auc_score(np.array(test_labels), test_probs_ft) if len(set(test_labels)) > 1 else None
    test_metrics_ft["roc_auc"] = float(test_roc) if test_roc is not None else None

    print("TEST (Keras, finetuned, threshold=%.2f):" % best_threshold)
    for k, v in test_metrics_ft.items():
        if k != "confusion_matrix":
            print(f"  {k}: {v}")

    converter = tf.lite.TFLiteConverter.from_keras_model(best_ft)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_bytes = converter.convert()
    tflite_path = ARTIFACT_DIR / "finetuned_best.tflite"
    tflite_path.write_bytes(tflite_bytes)
    print(f"wrote tflite: {tflite_path.stat().st_size} bytes")

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    tflite_probs = tflite_predict(interpreter, test_paths)
    tflite_metrics = threshold_metrics(np.array(test_labels), tflite_probs, best_threshold)
    tflite_roc = roc_auc_score(np.array(test_labels), tflite_probs) if len(set(test_labels)) > 1 else None
    tflite_metrics["roc_auc"] = float(tflite_roc) if tflite_roc is not None else None

    print("TEST (TFLite, finetuned, threshold=%.2f):" % best_threshold)
    for k, v in tflite_metrics.items():
        if k != "confusion_matrix":
            print(f"  {k}: {v}")

    test_subgroup = subgroup_recall(test_tags, test_probs_ft, manifest)
    print("TEST subgroup recall (Keras):")
    for sub, info in test_subgroup.items():
        print(f"  {sub}: n_children={info['n_children']} recall={info['recall']} mean_prob={info['mean_probability']}")

    out = {
        "experiment": "image_model_frontal1_finetuned",
        "trained_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "config": {
            "image_size": list(IMAGE_SIZE),
            "batch_size": BATCH_SIZE,
            "head_lr": HEAD_LR,
            "ft_lr": FT_LR,
            "ft_unfrozen_last_n": FT_UNFROZEN_LAST_N,
            "head_epochs": HEAD_EPOCHS,
            "ft_epochs": FT_EPOCHS,
            "early_stop_patience": EARLY_STOP_PATIENCE,
            "lr_patience": LR_PATIENCE,
            "min_delta": MIN_DELTA,
            "dropout_rate": DROPOUT_RATE,
            "random_state": RANDOM_STATE,
            "threshold_candidates": THRESHOLD_CANDIDATES,
            "healthy_recall_floor": HEALTHY_RECALL_FLOOR,
        },
        "split": {
            "train_children": len(train_paths),
            "validation_children": len(val_paths),
            "test_children": len(test_paths),
        },
        "phase1": {
            "checkpoint": str(ARTIFACT_DIR / "head_best.keras"),
            "validation_balanced_accuracy": head_val_metrics["balanced_accuracy"],
        },
        "phase2": {
            "checkpoint": str(ARTIFACT_DIR / "finetuned_best.keras"),
            "best_epoch_1based": ft_epoch,
            "validation_balanced_accuracy": ft_val_metrics["balanced_accuracy"],
            "validation_metrics": {k: v for k, v in ft_val_metrics.items() if k != "confusion_matrix"},
        },
        "threshold_selection": {
            "threshold": best_threshold,
            "validation_balanced_accuracy_at_threshold": threshold_metrics_val["balanced_accuracy"],
            "validation_recall_healthy_at_threshold": threshold_metrics_val["recall_healthy"],
            "validation_recall_malnourished_at_threshold": threshold_metrics_val["recall_malnourished"],
        },
        "test_keras": test_metrics_ft,
        "test_tflite": tflite_metrics,
        "test_subgroup_recall_keras": test_subgroup,
    }

    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    (RESULT_DIR / "metrics.json").write_text(json.dumps(out, indent=2))
    print("wrote", RESULT_DIR / "metrics.json")

    baseline_path = HERE.parent / "image_model_frontal1_only" / "results" / "metrics.json"
    if baseline_path.exists():
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        b_test = baseline.get("test_metrics_keras") or baseline.get("test_metrics", {})
        comparison = {
            "baseline_path": str(baseline_path),
            "baseline_test_accuracy": b_test.get("accuracy"),
            "baseline_test_balanced_accuracy": b_test.get("balanced_accuracy"),
            "baseline_test_recall_malnourished": b_test.get("recall_malnourished"),
            "baseline_test_recall_healthy": b_test.get("recall_healthy"),
            "baseline_test_roc_auc": b_test.get("roc_auc"),
            "baseline_confusion_matrix": b_test.get("confusion_matrix_array"),
            "finetuned_test_accuracy": test_metrics_ft["accuracy"],
            "finetuned_test_balanced_accuracy": test_metrics_ft["balanced_accuracy"],
            "finetuned_test_recall_malnourished": test_metrics_ft["recall_malnourished"],
            "finetuned_test_recall_healthy": test_metrics_ft["recall_healthy"],
            "finetuned_test_roc_auc": test_metrics_ft["roc_auc"],
            "finetuned_confusion_matrix": test_metrics_ft["confusion_matrix_array"],
        }
        (RESULT_DIR / "comparison.json").write_text(json.dumps(comparison, indent=2))
        print("wrote", RESULT_DIR / "comparison.json")


if __name__ == "__main__":
    main()
