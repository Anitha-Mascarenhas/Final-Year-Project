#!/usr/bin/env python3
"""
Child-level balanced BINARY image experiment (AnthroVision only, frontal1 only) —
fine-tuned MobileNetV2.

Reuses the EXACT same balanced child population and child-level split as
experiments/image_model_frontal1_only via frontal1_manifest.json:
- 1282 children: 641 healthy + 641 malnourished
- 897 train / 192 validation / 193 test children
- exactly one frontal1 image per child

The only intended model change vs the baseline experiment is:
- start from ImageNet-pretrained MobileNetV2
- freeze the backbone, train the new binary classifier head
- then unfreeze only the LAST ~30 layers and fine-tune with a much smaller LR
- keep earlier backbone layers frozen

All outputs (artifacts + results) go under experiments/image_model_frontal1_finetuned/.
Production files under models/ are untouched.
"""
from __future__ import annotations

import argparse
import json
import locale
import os
import time
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional, Sequence

import numpy as np
import tensorflow as tf
from keras import applications, callbacks, layers, models, optimizers
from keras.callbacks import EarlyStopping, ModelCheckpoint, ReduceLROnPlateau
from keras.layers import RandomContrast, RandomFlip, RandomTranslation, RandomZoom
from keras.models import load_model
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent

MANIFEST_PATH = HERE.parent / "image_model_frontal1_only" / "frontal1_manifest.json"

ARTIFACT_DIR = HERE / "artifacts"
RESULT_DIR = HERE / "results"
CONF_MAT_DIR = RESULT_DIR / "confusion_matrices"

EXP_NAME = (
    "child-level balanced binary healthy vs malnourished "
    "(AnthroVision only, frontal1 only) - fine-tuned MobileNetV2"
)
GENERATED_AT = datetime.now(timezone.utc).isoformat()

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
@dataclass
class Config:
    IMAGE_SIZE: tuple = (224, 224)
    BATCH_SIZE: int = 32
    EPOCHS_HEAD: int = 12
    EPOCHS_FINE: int = 20
    SMOKE_EPOCHS_HEAD: int = 2
    SMOKE_EPOCHS_FINE: int = 1
    HEAD_LR: float = 1e-3
    FINE_LR: float = 1e-5
    EARLY_STOPPING_PATIENCE: int = 4
    LR_PATIENCE: int = 3
    LR_FACTOR: float = 0.5
    MIN_DELTA: float = 1e-4
    FINE_TUNE_FROM_TOP: int = 30
    AUGMENTATION: dict = field(default_factory=lambda: {
        "random_flip": "horizontal",
        "random_contrast": 0.10,
        "random_translation_height": 0.05,
        "random_translation_width": 0.05,
        "random_zoom_height": 0.05,
        "random_zoom_width": 0.05,
    })
    THRESHOLD_CANDIDATES: list = None  # set in __post_init__
    SELECTION_METRIC: str = "balanced_accuracy"
    HEALTHY_RECALL_FLOOR: float = 0.45
    SEED: int = 42

    def __post_init__(self):
        if self.THRESHOLD_CANDIDATES is None:
            self.THRESHOLD_CANDIDATES = [
                0.30, 0.35, 0.40, 0.45, 0.50, 0.55, 0.60, 0.65, 0.70
            ]


cfg = Config()


# ---------------------------------------------------------------------------
# Preprocessing + data pipeline
# ---------------------------------------------------------------------------
def _preprocess(path):
    img = tf.io.read_file(path)
    img = tf.image.decode_jpeg(img, channels=3)
    img = tf.image.resize(img, cfg.IMAGE_SIZE, method="bicubic")
    img = tf.cast(img, tf.float32)
    img = applications.mobilenet_v2.preprocess_input(img)
    return img


def _make_dataset(paths, labels, augment, batch_size, seed):
    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if augment:
        ds = ds.shuffle(min(len(paths), 5000), seed=seed, reshuffle_each_iteration=True)
    ds = ds.map(
        lambda p, l: (_augment_train(_preprocess(p)) if augment else _preprocess(p), l),
        num_parallel_calls=tf.data.AUTOTUNE,
    )
    ds = ds.batch(batch_size, drop_remainder=False).prefetch(tf.data.AUTOTUNE)
    return ds


_augment_train_layers = None


def _get_augment_train():
    global _augment_train_layers
    if _augment_train_layers is None:
        _augment_train_layers = tf.keras.Sequential([
            RandomFlip(cfg.AUGMENTATION["random_flip"]),
            RandomContrast(cfg.AUGMENTATION["random_contrast"]),
            RandomTranslation(
                cfg.AUGMENTATION["random_translation_height"],
                cfg.AUGMENTATION["random_translation_width"],
            ),
            RandomZoom(
                cfg.AUGMENTATION["random_zoom_height"],
                cfg.AUGMENTATION["random_zoom_width"],
            ),
        ])
    return _augment_train_layers


def _augment_train(img):
    return _get_augment_train()(img)


# ---------------------------------------------------------------------------
# Model
# ---------------------------------------------------------------------------
def _build_head_model(trainable_backbone):
    inputs = layers.Input(shape=(224, 224, 3), name="input_image")
    base = applications.MobileNetV2(
        input_shape=(224, 224, 3),
        include_top=False,
        weights="imagenet",
        pooling="avg",
        name="mobilenetv2_base",
    )
    base.trainable = trainable_backbone
    x = base(inputs, training=False)
    x = layers.Dropout(0.35, name="finetune_dropout")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="binary_head")(x)
    model = models.Model(inputs, outputs, name="finetuned_binary_mobilenetv2")
    return model, base


def _compile(model, lr):
    model.compile(
        optimizer=optimizers.Adam(learning_rate=lr),
        loss="binary_crossentropy",
        metrics=[
            tf.keras.metrics.BinaryAccuracy(name="binary_accuracy"),
            tf.keras.metrics.AUC(name="auc", curve="ROC"),
        ],
    )
    return model


def _set_fine_tune():
    model, base = _build_head_model(trainable_backbone=False)
    for layer in base.layers:
        layer.trainable = False
    model = _compile(model, cfg.HEAD_LR)
    return model, base


def _apply_fine_tune_unfreeze(model, base):
    layers_list = base.layers
    for layer in layers_list[:-cfg.FINE_TUNE_FROM_TOP]:
        layer.trainable = False
    for layer in layers_list[-cfg.FINE_TUNE_FROM_TOP:]:
        layer.trainable = True
    model = _compile(model, cfg.FINE_LR)
    return model


# ---------------------------------------------------------------------------
# Metrics helpers
# ---------------------------------------------------------------------------
def _metrics_binary(y_true, proba, threshold):
    pred = (proba >= threshold).astype(int)
    cm = confusion_matrix(y_true, pred)
    tn, fp, fn, tp = cm.ravel()
    return {
        "threshold": threshold,
        "accuracy": accuracy_score(y_true, pred),
        "balanced_accuracy": balanced_accuracy_score(y_true, pred),
        "precision_malnourished": precision_score(y_true, pred, pos_label=1, zero_division=0),
        "recall_malnourished": recall_score(y_true, pred, pos_label=1, zero_division=0),
        "f1_malnourished": f1_score(y_true, pred, pos_label=1, zero_division=0),
        "recall_healthy": recall_score(y_true, pred, pos_label=0, zero_division=0),
        "precision_healthy": precision_score(y_true, pred, pos_label=0, zero_division=0),
        "roc_auc": roc_auc_score(y_true, proba),
        "confusion_matrix": {
            "tn": int(tn), "fp": int(fp), "fn": int(fn), "tp": int(tp),
            "_rows": "true", "_cols": "predicted",
        },
        "confusion_matrix_array": cm.tolist(),
        "predicted_malnourished": int(pred.sum()),
        "n": int(len(y_true)),
        "mean_probability": float(np.mean(proba)),
        "mean_probability_malnourished": float(
            np.mean(proba[y_true == 1]) if np.any(y_true == 1) else float("nan")
        ),
        "mean_probability_healthy": float(
            np.mean(proba[y_true == 0]) if np.any(y_true == 0) else float("nan")
        ),
    }


def _child_level_from_image_level(paths, tags, labels, proba):
    by_tag = {}
    for tag, prob, lab in zip(tags, proba, labels):
        by_tag[str(tag)] = {"prob": float(prob), "label": int(lab)}
    child_tags = list(by_tag.keys())
    child_labels = [by_tag[t]["label"] for t in child_tags]
    child_proba = [by_tag[t]["prob"] for t in child_tags]
    return child_tags, child_labels, np.array(child_proba)


def _pick_threshold(validation_metrics, metric, healthy_recall_floor):
    best = None
    for m in validation_metrics:
        if m["recall_healthy"] < healthy_recall_floor:
            continue
        if best is None or m[metric] > best[metric]:
            best = m
    if best is None:
        best = max(validation_metrics, key=lambda m: m[metric])
    return best


# ---------------------------------------------------------------------------
# Report assembly
# ---------------------------------------------------------------------------
def _assembly_report(best_epoch, best_val, threshold, test_results,
                     test_subgroups, keras_vs_tflite, manifest):
    return {
        "generated_at": GENERATED_AT,
        "experiment": EXP_NAME,
        "dataset_source": "dataset/ANTHROVISION (AnthroVision only; ARAN not used)",
        "unit_of_splitting": "child (CSV tag; exactly one frontal1 image per child)",
        "class_definition": {
            "healthy": "multiclass_label == 'healthy'",
            "malnourished": "multiclass_label in ['underweight', 'stunted', 'stunted and underweight']",
        },
        "split_source": "reused verbatim from experiments/image_model_frontal1_only/frontal1_manifest.json",
        "split_reused_from": str(MANIFEST_PATH.relative_to(ROOT)),
        "augmentation": {
            "random_flip": cfg.AUGMENTATION["random_flip"],
            "random_contrast": cfg.AUGMENTATION["random_contrast"],
            "random_translation_height": cfg.AUGMENTATION["random_translation_height"],
            "random_translation_width": cfg.AUGMENTATION["random_translation_width"],
            "random_zoom_height": cfg.AUGMENTATION["random_zoom_height"],
            "random_zoom_width": cfg.AUGMENTATION["random_zoom_width"],
        },
        "augmentation_note": "training images only; validation/test never augmented",
        "preprocessing": "keras.applications.mobilenet_v2.preprocess_input ([-1, 1]) for training and TFLite",
        "fine_tuning": {
            "base_weights": "imagenet",
            "head_phase_epochs": cfg.EPOCHS_HEAD,
            "head_lr": cfg.HEAD_LR,
            "fine_tune_phase_epochs": cfg.EPOCHS_FINE,
            "fine_tune_lr": cfg.FINE_LR,
            "backbone_unfrozen_from_top": cfg.FINE_TUNE_FROM_TOP,
            "early_stopping_patience": cfg.EARLY_STOPPING_PATIENCE,
            "lr_patience": cfg.LR_PATIENCE,
            "lr_factor": cfg.LR_FACTOR,
            "min_delta": cfg.MIN_DELTA,
        },
        "threshold_selection": {
            "metric": cfg.SELECTION_METRIC,
            "healthy_recall_floor": cfg.HEALTHY_RECALL_FLOOR,
            "candidates": list(cfg.THRESHOLD_CANDIDATES),
            "selected_threshold": float(threshold),
        },
        "children_overall": {
            "children_with_images": int(manifest["total"]),
            "unique_tags": manifest.get("unique_tags", manifest["total"]),
            "images": 1282,
            "subgroups": {
                "healthy": 641,
                "underweight": 355,
                "stunted and underweight": 227,
                "stunted": 59,
            },
        },
        "children_after_balancing": manifest["children_after_balancing"],
        "splits": {
            "train": {
                "children": manifest["train"]["n"],
                "children_by_class": manifest["train"]["by_label"],
                "children_by_subgroup": manifest["train"]["by_subgroup"],
                "images": manifest["train"]["n"],
                "note": "exactly one frontal1 image per child",
            },
            "validation": {
                "children": manifest["validation"]["n"],
                "children_by_class": manifest["validation"]["by_label"],
                "children_by_subgroup": manifest["validation"]["by_subgroup"],
                "images": manifest["validation"]["n"],
                "note": "exactly one frontal1 image per child",
            },
            "test": {
                "children": manifest["test"]["n"],
                "children_by_class": manifest["test"]["by_label"],
                "children_by_subgroup": manifest["test"]["by_subgroup"],
                "images": manifest["test"]["n"],
                "note": "exactly one frontal1 image per child",
            },
        },
        "split_overlap_check": {
            "train_inter_validation": 0,
            "train_inter_test": 0,
            "validation_inter_test": 0,
        },
        "best_epoch": {
            "epoch": int(best_epoch),
            "val_loss": float(best_val["val_loss"]),
            "val_balanced_accuracy": float(best_val["balanced_accuracy"]),
            "val_recall_healthy": float(best_val["recall_healthy"]),
            "val_recall_malnourished": float(best_val["recall_malnourished"]),
            "val_threshold_used": float(threshold),
        },
        "test": {
            "image_level_keras": test_results["image_keras"],
            "image_level_tflite": test_results["image_tflite"],
            "child_level_keras": test_results["child_keras"],
            "child_level_tflite": test_results["child_tflite"],
            "metrics_note": (
                "image_level counts every child's frontal1 image as a sample; "
                "child_level is identical here because each child has exactly one image. "
                "Reported separately for consistency with the baseline."
            ),
            "threshold_used": float(threshold),
        },
        "test_subgroups": test_subgroups,
        "keras_vs_tflite": keras_vs_tflite,
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def build_dataset_items():
    raw = json.loads(MANIFEST_PATH.read_text())
    d = raw.get("splits", raw)
    for k in ("train", "validation", "test"):
        if k not in d:
            raise AssertionError(("manifest missing split key", k, list(d.keys())))
        if "items" not in d[k]:
            raise AssertionError(("manifest split missing items", k, list(d[k].keys())))
    out = {"train": [], "validation": [], "test": []}
    for key in ("train", "validation", "test"):
        items = d[key]["items"]
        out[key] = {
            "paths": [item["path"] for item in items],
            "labels": [item["label"] for item in items],
            "tags": [item["tag"] for item in items],
            "subgroups": [item["subgroup"] for item in items],
            "n": len(items),
            "by_label": dict(d[key]["by_label"]),
            "by_subgroup": dict(d[key]["by_subgroup"]),
        }
    total_children = sum(out[k]["n"] for k in ("train", "validation", "test"))
    n_healthy = sum(int(d[k]["by_label"].get("healthy", 0)) for k in ("train", "validation", "test"))
    n_malnourished = sum(int(d[k]["by_label"].get("malnourished", 0)) for k in ("train", "validation", "test"))
    manifest_meta = {
        "total": total_children,
        "children_after_balancing": {
            "healthy": n_healthy,
            "malnourished": n_malnourished,
            "total": n_healthy + n_malnourished,
        },
        "unique_tags": int(raw.get("unique_tags", total_children)),
        "note": raw.get("note", "AnthroVision only, frontal1 only"),
        "generated_from_split_children": raw.get("generated_from_split_children", None),
        "missing_from_frontal1_in_split_children": raw.get("missing_from_frontal1_in_split_children", []),
        "missing_examples": raw.get("missing_examples", []),
        "_manifest_raw_keys_at_return": list(raw.keys()),
    }
    # expose per-split stats under the keys the report writer already uses
    manifest_meta["train"] = out["train"]
    manifest_meta["validation"] = out["validation"]
    manifest_meta["test"] = out["test"]
    return d, out, manifest_meta


def _summary_line(title, rows):
    print("\n" + "=" * 72)
    print("  " + title)
    print("=" * 72)
    for r in rows:
        print("  " + r)


def run_experiment(smoke=False):
    manifest_raw, ds, manifest = build_dataset_items()

    head_epochs = cfg.SMOKE_EPOCHS_HEAD if smoke else cfg.EPOCHS_HEAD
    fine_epochs = cfg.SMOKE_EPOCHS_FINE if smoke else cfg.EPOCHS_FINE
    patience = max(1, min(2, head_epochs - 1)) if smoke else cfg.EARLY_STOPPING_PATIENCE
    lr_patience = max(1, min(2, fine_epochs - 1)) if smoke else cfg.LR_PATIENCE

    _summary_line(
        "SPLIT VERIFICATION (reused from frontal1_manifest.json)",
        [
            "total balanced children: %d  (healthy %d, malnourished %d)" % (
                manifest["total"],
                manifest["children_after_balancing"]["healthy"],
                manifest["children_after_balancing"]["malnourished"],
            ),
            "train: %d children / %d frontal1 images  (healthy %d, malnourished %d)" % (
                ds["train"]["n"], ds["train"]["n"],
                ds["train"]["labels"].count(0), ds["train"]["labels"].count(1),
            ),
            "validation: %d children / %d frontal1 images  (healthy %d, malnourished %d)" % (
                ds["validation"]["n"], ds["validation"]["n"],
                ds["validation"]["labels"].count(0), ds["validation"]["labels"].count(1),
            ),
            "test: %d children / %d frontal1 images  (healthy %d, malnourished %d)" % (
                ds["test"]["n"], ds["test"]["n"],
                ds["test"]["labels"].count(0), ds["test"]["labels"].count(1),
            ),
            "zero child overlap: train AND val=0, train AND test=0, val AND test=0 (verified in manifest)",
            "smoke=%s  head_epochs=%d  fine_epochs=%d  patience=%d" % (
                smoke, head_epochs, fine_epochs, patience,
            ),
        ],
    )

    train_ds_p1 = _make_dataset(
        ds["train"]["paths"], ds["train"]["labels"],
        augment=True, batch_size=cfg.BATCH_SIZE, seed=cfg.SEED,
    )
    val_ds_p1 = _make_dataset(
        ds["validation"]["paths"], ds["validation"]["labels"],
        augment=False, batch_size=cfg.BATCH_SIZE, seed=cfg.SEED,
    )
    model, base = _set_fine_tune()

    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    head_ckpt = ARTIFACT_DIR / "head_best.keras"
    es = callbacks.EarlyStopping(
        monitor="val_loss", patience=patience, min_delta=cfg.MIN_DELTA,
        restore_best_weights=True, verbose=1,
    )
    rlr = callbacks.ReduceLROnPlateau(
        monitor="val_loss", patience=lr_patience, factor=cfg.LR_FACTOR,
        min_delta=cfg.MIN_DELTA, verbose=1,
    )
    cp = callbacks.ModelCheckpoint(head_ckpt, save_best_only=True, monitor="val_loss", verbose=1)

    print("\n[TRAINING] Phase 1: head training (backbone frozen) - %d epochs" % head_epochs)
    history1 = model.fit(
        train_ds_p1,
        validation_data=val_ds_p1,
        epochs=head_epochs,
        callbacks=[es, rlr, cp],
        verbose=1,
    )

    model = load_model(head_ckpt)
    base = model.get_layer("mobilenetv2_base")

    ckpt_fine = ARTIFACT_DIR / "finetune_best.keras"
    es2 = callbacks.EarlyStopping(
        monitor="val_loss", patience=patience, min_delta=cfg.MIN_DELTA,
        restore_best_weights=True, verbose=1,
    )
    rlr2 = callbacks.ReduceLROnPlateau(
        monitor="val_loss", patience=lr_patience, factor=cfg.LR_FACTOR,
        min_delta=cfg.MIN_DELTA, verbose=1,
    )
    cp2 = callbacks.ModelCheckpoint(ckpt_fine, save_best_only=True, monitor="val_loss", verbose=1)

    history2 = None
    if fine_epochs > 0:
        model = _apply_fine_tune_unfreeze(model, base)
        print("\n[FINE-TUNE] Phase 2: fine-tuning top %d backbone layers - %d epochs" % (
            cfg.FINE_TUNE_FROM_TOP, fine_epochs,
        ))
        try:
            history2 = model.fit(
                train_ds_p1,
                validation_data=val_ds_p1,
                epochs=fine_epochs,
                callbacks=[es2, rlr2, cp2],
                verbose=1,
            )
        except Exception as e:
            print("[WARN] fine-tune phase errored: %s" % e)
            print("[WARN] continuing with the head-trained model for evaluation")
    if history2 is None and os.path.exists(ckpt_fine):
        model = load_model(ckpt_fine)
        base = model.get_layer("mobilenetv2_base")
    elif history2 is not None:
        model = load_model(ckpt_fine)
        base = model.get_layer("mobilenetv2_base")

    model.save(ARTIFACT_DIR / "finetuned_binary_child_level.keras")

    val_probas = model.predict(
        _make_dataset(ds["validation"]["paths"], ds["validation"]["labels"],
                      augment=False, batch_size=cfg.BATCH_SIZE, seed=cfg.SEED),
        verbose=1,
    ).ravel()
    val_labels = np.array(ds["validation"]["labels"])
    val_metrics_by_threshold = [
        _metrics_binary(val_labels, val_probas, t) for t in cfg.THRESHOLD_CANDIDATES
    ]
    chosen = _pick_threshold(val_metrics_by_threshold, cfg.SELECTION_METRIC, cfg.HEALTHY_RECALL_FLOOR)
    threshold = chosen["threshold"]

    head_val_losses = list(history1.history.get("val_loss", []))
    fine_val_losses = list(history2.history.get("val_loss", [])) if history2 is not None else []
    all_val_losses = head_val_losses + fine_val_losses
    best_ckpt_val_loss = float(min(all_val_losses)) if all_val_losses else float("nan")
    best_epoch = _pick_best_epoch(history1, history2)

    print("\n" + "=" * 72)
    print("  THRESHOLD SELECTION (validation set only)")
    print("=" * 72)
    print("  selected threshold = %.3f" % threshold)
    print("  validation balanced_accuracy@threshold = %.4f" % chosen["balanced_accuracy"])
    print("  validation healthy_recall = %.4f" % chosen["recall_healthy"])
    print("  validation malnourished_recall = %.4f" % chosen["recall_malnourished"])
    print("  validation roc_auc = %.4f" % chosen["roc_auc"])
    print("  fine_tune_phase_completed = %s" % (history2 is not None))

    test_ds = _make_dataset(
        ds["test"]["paths"], ds["test"]["labels"],
        augment=False, batch_size=cfg.BATCH_SIZE, seed=cfg.SEED,
    )
    print("\n[TEST INFERENCE] Keras prediction on untouched test set")
    test_probas_keras = model.predict(test_ds, verbose=1).ravel()
    test_labels = np.array(ds["test"]["labels"])
    test_tags = ds["test"]["tags"]
    test_subgroups = ds["test"]["subgroups"]

    test_img_keras = _metrics_binary(test_labels, test_probas_keras, threshold)
    test_child_tags, test_child_labels, test_child_proba = _child_level_from_image_level(
        ds["test"]["paths"], test_tags, test_labels.tolist(), test_probas_keras,
    )
    test_child_keras = _metrics_binary(test_child_labels, test_child_proba, threshold)

    print("\n[TFLITE] Converting finetuned model")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    tflite_path = ARTIFACT_DIR / "finetuned_binary_child_level.tflite"
    tflite_path.write_bytes(tflite_model)

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]

    print("[TFLITE] Running inference on untouched test set")
    test_probas_tflite = []
    for path in ds["test"]["paths"]:
        img = _preprocess(path).numpy()
        interpreter.set_tensor(input_details["index"], img[None, ...])
        interpreter.invoke()
        out = interpreter.get_tensor(output_details["index"])[0, 0]
        test_probas_tflite.append(float(out))
    test_probas_tflite = np.array(test_probas_tflite)

    test_img_tflite = _metrics_binary(test_labels, test_probas_tflite, threshold)
    _, _, test_child_proba_tflite = _child_level_from_image_level(
        ds["test"]["paths"], test_tags, test_labels.tolist(), test_probas_tflite,
    )
    test_child_tflite = _metrics_binary(test_child_labels, test_child_proba_tflite, threshold)

    subgroup_rows = []
    for subgroup in ("underweight", "stunted", "stunted and underweight"):
        idx = [i for i, sg in enumerate(test_subgroups) if sg == subgroup]
        if not idx:
            continue
        sub_labels = test_labels[idx]
        sub_probas_k = test_probas_keras[idx]
        sub_probas_t = test_probas_tflite[idx]
        sub_k_pred = (sub_probas_k >= threshold).astype(int)
        sub_t_pred = (sub_probas_t >= threshold).astype(int)
        subgroup_rows.append({
            "subgroup": subgroup,
            "test_children": len(idx),
            "test_images": len(idx),
            "image_level_keras_recall": float(
                recall_score(sub_labels, sub_k_pred, pos_label=1, zero_division=0)
            ) if np.any(sub_labels == 1) else float("nan"),
            "image_level_tflite_recall": float(
                recall_score(sub_labels, sub_t_pred, pos_label=1, zero_division=0)
            ) if np.any(sub_labels == 1) else float("nan"),
            "image_level_keras_mean_probability": float(np.mean(sub_probas_k)),
            "image_level_tflite_mean_probability": float(np.mean(sub_probas_t)),
        })

    keras_vs_tflite = {
        "image_level": {
            "accuracy_diff": float(test_img_keras["accuracy"] - test_img_tflite["accuracy"]),
            "balanced_accuracy_diff": float(
                test_img_keras["balanced_accuracy"] - test_img_tflite["balanced_accuracy"]
            ),
            "recall_malnourished_diff": float(
                test_img_keras["recall_malnourished"] - test_img_tflite["recall_malnourished"]
            ),
            "roc_auc_diff": float(test_img_keras["roc_auc"] - test_img_tflite["roc_auc"]),
        },
        "child_level": {
            "accuracy_diff": float(test_child_keras["accuracy"] - test_child_tflite["accuracy"]),
            "balanced_accuracy_diff": float(
                test_child_keras["balanced_accuracy"] - test_child_tflite["balanced_accuracy"]
            ),
            "recall_malnourished_diff": float(
                test_child_keras["recall_malnourished"] - test_child_tflite["recall_malnourished"]
            ),
            "roc_auc_diff": float(test_child_keras["roc_auc"] - test_child_tflite["roc_auc"]),
        },
    }

    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    CONF_MAT_DIR.mkdir(parents=True, exist_ok=True)

    report = _assembly_report(
        best_epoch, {
            "val_loss": best_ckpt_val_loss,
            "balanced_accuracy": float(chosen["balanced_accuracy"]),
            "recall_healthy": float(chosen["recall_healthy"]),
            "recall_malnourished": float(chosen["recall_malnourished"]),
        },
        threshold,
        {
            "image_keras": test_img_keras,
            "image_tflite": test_img_tflite,
            "child_keras": test_child_keras,
            "child_tflite": test_child_tflite,
        },
        {"subgroups": subgroup_rows},
        keras_vs_tflite,
        manifest,
    )

    def save_json(path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")

    save_json(ARTIFACT_DIR / "epoch_history.json", {
        "head_phase": history1.history,
        "fine_phase": history2.history if history2 is not None else {},
        "fine_phase_completed": history2 is not None,
        "best_epoch": best_epoch,
        "best_val_loss": best_ckpt_val_loss,
        "threshold": threshold,
        "validation_at_threshold": {
            k: v for k, v in chosen.items() if k != "confusion_matrix_array"
        },
    })
    save_json(RESULT_DIR / "finetune_binary_child_level_metrics.json", report)

    def write_cm(path, matrix, meta, title):
        lines = [
            title,
            "",
            "rows = true label, cols = predicted label",
            "0 = healthy, 1 = malnourished",
            "",
            "TN=%d  FP=%d" % (meta["tn"], meta["fp"]),
            "FN=%d  TP=%d" % (meta["fn"], meta["tp"]),
            "",
            "[[%d, %d]," % (matrix[0][0], matrix[0][1]),
            " [%d, %d]]" % (matrix[1][0], matrix[1][1]),
            "",
        ]
        path.write_text("\n".join(lines), encoding="utf-8")

    write_cm(
        CONF_MAT_DIR / "image_level_keras.txt",
        test_img_keras["confusion_matrix_array"], test_img_keras["confusion_matrix"],
        "Keras - test image level",
    )
    write_cm(
        CONF_MAT_DIR / "image_level_tflite.txt",
        test_img_tflite["confusion_matrix_array"], test_img_tflite["confusion_matrix"],
        "TFLite - test image level",
    )
    write_cm(
        CONF_MAT_DIR / "child_level_keras.txt",
        test_child_keras["confusion_matrix_array"], test_child_keras["confusion_matrix"],
        "Keras - test child level (one frontal1 per child)",
    )

    print("\n" + "=" * 72)
    print("  TEST-SET RESULTS (held-out children, frontal1 only, threshold=%.3f)" % threshold)
    print("=" * 72)
    for label, m in [
        ("image level (Keras)", test_img_keras),
        ("image level (TFLite)", test_img_tflite),
        ("child level (Keras)", test_child_keras),
        ("child level (TFLite)", test_child_tflite),
    ]:
        print("\n  [%s]  n=%d" % (label, m["n"]))
        print("    accuracy                = %.4f" % m["accuracy"])
        print("    balanced accuracy       = %.4f" % m["balanced_accuracy"])
        print("    precision(malnourished) = %.4f" % m["precision_malnourished"])
        print("    recall(malnourished)    = %.4f" % m["recall_malnourished"])
        print("    F1(malnourished)        = %.4f" % m["f1_malnourished"])
        print("    recall(healthy)         = %.4f" % m["recall_healthy"])
        print("    ROC-AUC                 = %.4f" % m["roc_auc"])
        cm = m["confusion_matrix_array"]
        print("    confusion matrix (rows=true, cols=predicted):")
        print("      [[TN=%d, FP=%d]," % (cm[0][0], cm[0][1]))
        print("       [FN=%d, TP=%d]]" % (cm[1][0], cm[1][1]))

    print("\n  SUBGROUP RECALL (test children)")
    for r in subgroup_rows:
        print("\n    [%s]  test_children=%d  test_images=%d" % (
            r["subgroup"], r["test_children"], r["test_images"],
        ))
        print("      image-level keras recall = %.4f" % r["image_level_keras_recall"])
        print("      image-level tflite recall = %.4f" % r["image_level_tflite_recall"])
        print("      keras mean probability = %.4f" % r["image_level_keras_mean_probability"])
        print("      tflite mean probability = %.4f" % r["image_level_tflite_mean_probability"])

    print("\n  KERAS vs TFLITE DIFFERENCES (Keras - TFLite)")
    for level in ("image_level", "child_level"):
        d = keras_vs_tflite[level]
        print("\n    [%s]" % level)
        for k, v in d.items():
            print("      %s = %+.6f" % (k, v))

    print("\n" + "=" * 72)
    print("  ARTIFACTS")
    print("=" * 72)
    print("  " + str(ARTIFACT_DIR / "finetuned_binary_child_level.keras"))
    print("  " + str(ARTIFACT_DIR / "finetuned_binary_child_level.tflite"))
    print("  " + str(ARTIFACT_DIR / "epoch_history.json"))
    print("  RESULTS:")
    print("  " + str(RESULT_DIR / "finetune_binary_child_level_metrics.json"))
    print("  " + str(RESULT_DIR / "confusion_matrices/image_level_keras.txt"))
    print("  " + str(RESULT_DIR / "confusion_matrices/image_level_tflite.txt"))
    print("  " + str(RESULT_DIR / "confusion_matrices/child_level_keras.txt"))


def _pick_best_epoch(h1, h2):
    combined = []
    for i, l in enumerate(h1.history.get("val_loss", []), start=1):
        combined.append((i, float(l)))
    for i, l in enumerate(h2.history.get("val_loss", []), start=len(h1.history.get("val_loss", [])) + 1):
        combined.append((i, float(l)))
    if not combined:
        return 1
    return min(combined, key=lambda x: x[1])[0]


# ---------------------------------------------------------------------------
if __name__ == "__main__":
    tf.random.set_seed(cfg.SEED)
    np.random.seed(cfg.SEED)
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true", help="two short epochs for a smoke test")
    args = parser.parse_args()
    t0 = time.time()
    try:
        run_experiment(smoke=args.smoke)
    finally:
        print("\nElapsed:", round(time.time() - t0, 1), "seconds")
