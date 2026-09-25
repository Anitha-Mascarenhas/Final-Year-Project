"""
Child-level balanced BINARY image experiment (AnthroVision only, frontal1 only).

Reuses the existing balanced 641+641 child population and the same
train/validation/test child split from the previous child-level experiment.

Production files under models/ are untouched. All outputs go under
experiments/image_model_frontal1_only/.
"""
from __future__ import annotations

import argparse
import json
import os
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import tensorflow as tf
from keras import applications, optimizers
from keras.callbacks import EarlyStopping, ReduceLROnPlateau, ModelCheckpoint
from keras.layers import RandomContrast, RandomFlip, RandomTranslation, RandomZoom
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
ARTIFACT_DIR = HERE / "artifacts"
RESULT_DIR = HERE / "results"
SPLIT_CHILDREN_PATH = (
    ROOT / "experiments" / "image_model_binary_child_level" / "artifacts" / "split_children.json"
)
MANIFEST_PATH = HERE / "frontal1_manifest.json"


class Config:
    IMAGE_SIZE = (224, 224)
    BATCH_SIZE = 32
    EPOCHS = 25
    SMOKE_EPOCHS = 2
    LEARNING_RATE = 1e-4
    DROPOUT_RATE = 0.3
    EARLY_STOPPING_PATIENCE = 5
    LR_PATIENCE = 3
    MIN_DELTA = 1e-4
    RANDOM_STATE = 42
    CLASS_NAMES = ["healthy", "malnourished"]


cfg = Config()


def preprocess_image(path):
    img = tf.io.read_file(path)
    img = tf.image.decode_jpeg(img, channels=3)
    img = tf.image.resize(img, cfg.IMAGE_SIZE, method="bicubic")
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


def build_model():
    base = applications.MobileNetV2(
        input_shape=(*cfg.IMAGE_SIZE, 3),
        include_top=False,
        weights="imagenet",
        pooling="avg",
    )
    base.trainable = False
    inputs = tf.keras.layers.Input(shape=(*cfg.IMAGE_SIZE, 3), name="image_input")
    x = applications.mobilenet_v2.preprocess_input(inputs)
    x = base(x, training=False)
    x = tf.keras.layers.Dropout(cfg.DROPOUT_RATE)(x)
    x = tf.keras.layers.Dense(32, activation="relu")(x)
    outputs = tf.keras.layers.Dense(1, activation="sigmoid", name="malnourished_prob")(x)
    model = tf.keras.Model(inputs, outputs, name="mobilenetv2_binary_frontal1")
    model.compile(
        optimizer=optimizers.Adam(learning_rate=cfg.LEARNING_RATE),
        loss="binary_crossentropy",
        metrics=[
            "accuracy",
            tf.keras.metrics.BalancedAccuracy(name="balanced_accuracy"),
            tf.keras.metrics.Recall(name="recall_malnourished"),
            tf.keras.metrics.Precision(name="precision_malnourished"),
            tf.keras.metrics.AUC(name="roc_auc"),
        ],
    )
    return model


def binary_metrics(y_true, probabilities, threshold=0.5):
    y_true = np.asarray(y_true).astype(int)
    probabilities = np.asarray(probabilities, dtype=float)
    y_pred = (probabilities >= threshold).astype(int)
    tn = int(((y_true == 0) & (y_pred == 0)).sum())
    fp = int(((y_true == 0) & (y_pred == 1)).sum())
    fn = int(((y_true == 1) & (y_pred == 0)).sum())
    tp = int(((y_true == 1) & (y_pred == 1)).sum())
    metrics = {
        "n": int(len(y_true)),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "precision_malnourished": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall_malnourished": float(recall_score(y_true, y_pred, zero_division=0)),
        "f1_malnourished": float(f1_score(y_true, y_pred, zero_division=0)),
        "recall_healthy": float(recall_score(1 - y_true, 1 - y_pred, zero_division=0)),
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
        "confusion_matrix_array": [[tn, fp], [fn, tp]],
    }
    if len(set(y_true.tolist())) > 1:
        metrics["roc_auc"] = float(roc_auc_score(y_true, probabilities))
    else:
        metrics["roc_auc"] = None
    return metrics


def build_tf_dataset(paths, labels, augment=False, shuffle=True, cache_dir=None):
    ds = tf.data.Dataset.from_tensor_slices((list(paths), list(labels)))
    if shuffle:
        ds = ds.shuffle(len(paths), seed=cfg.RANDOM_STATE, reshuffle_each_iteration=True)
    if cache_dir:
        ds = ds.cache(cache_dir)
    map_fn = (lambda p, l: (build_augment()(preprocess_image(p)), l)) if augment else (
        lambda p, l: (preprocess_image(p), l)
    )
    ds = ds.map(map_fn, num_parallel_calls=tf.data.AUTOTUNE)
    return ds.batch(cfg.BATCH_SIZE).prefetch(tf.data.AUTOTUNE)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--smoke", action="store_true")
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    RESULT_DIR.mkdir(parents=True, exist_ok=True)

    with open(SPLIT_CHILDREN_PATH, "r", encoding="utf-8-sig") as f:
        split_data = json.load(f)
    with open(MANIFEST_PATH, "r", encoding="utf-8-sig") as f:
        manifest = json.load(f)

    manifest_by_tag = {entry["tag"]: entry for entry in manifest["entries"]}

    train_children = sorted(split_data["train_children"])
    val_children = sorted(split_data["validation_children"])
    test_children = sorted(split_data["test_children"])

    def children_to_items(children):
        paths = []
        labels = []
        tags = []
        for child in children:
            tag = child["tag"]
            entry = manifest_by_tag.get(tag)
            if entry is None:
                continue
            rel = entry["relative_path"]
            path = os.path.join(ROOT, "dataset", rel) if not os.path.isabs(rel) else rel
            if not os.path.exists(path):
                continue
            paths.append(path)
            labels.append(int(child["label"]))
            tags.append(tag)
        return paths, labels, tags

    train_paths, train_labels, train_tags = children_to_items(train_children)
    val_paths, val_labels, val_tags = children_to_items(val_children)
    test_paths, test_labels, test_tags = children_to_items(test_children)

    print(f"train children={len(train_children)} images={len(train_paths)}")
    print(f"validation children={len(val_children)} images={len(val_paths)}")
    print(f"test children={len(test_children)} images={len(test_paths)}")
    print(
        f"train class dist: healthy={sum(1 for l in train_labels if l==0)}, malnourished={sum(1 for l in train_labels if l==1)}"
    )
    print(
        f"validation class dist: healthy={sum(1 for l in val_labels if l==0)}, malnourished={sum(1 for l in val_labels if l==1)}"
    )
    print(
        f"test class dist: healthy={sum(1 for l in test_labels if l==0)}, malnourished={sum(1 for l in test_labels if l==1)}"
    )

    epochs = cfg.SMOKE_EPOCHS if args.smoke else cfg.EPOCHS
    cache_dir = os.path.join(str(HERE), "cache", "train_cache.tfdata") if not args.smoke else None

    train_ds = build_tf_dataset(train_paths, train_labels, augment=True, shuffle=True, cache_dir=cache_dir)
    val_ds = build_tf_dataset(val_paths, val_labels, augment=False, shuffle=False)
    test_ds = build_tf_dataset(test_paths, test_labels, augment=False, shuffle=False)

    model = build_model()
    callbacks = [
        EarlyStopping(
            monitor="val_balanced_accuracy",
            patience=cfg.EARLY_STOPPING_PATIENCE,
            min_delta=cfg.MIN_DELTA,
            mode="max",
            restore_best_weights=True,
        ),
        ReduceLROnPlateau(
            monitor="val_balanced_accuracy",
            patience=cfg.LR_PATIENCE,
            min_delta=cfg.MIN_DELTA,
            factor=0.5,
            mode="max",
        ),
        ModelCheckpoint(
            filepath=str(ARTIFACT_DIR / "best_frontal1.keras"),
            monitor="val_balanced_accuracy",
            save_best_only=True,
        ),
    ]

    t0 = time.time()
    history = model.fit(train_ds, validation_data=val_ds, epochs=epochs, callbacks=callbacks, verbose=1)
    train_time = time.time() - t0
    print(f"training finished in {train_time:.1f}s")

    best_path = ARTIFACT_DIR / "best_frontal1.keras"
    best_model = tf.keras.models.load_model(best_path)

    val_probs = best_model.predict(val_ds, verbose=0).ravel()
    val_metrics = binary_metrics(np.array(val_labels), val_probs)
    print("validation metrics:")
    for k, v in val_metrics.items():
        if k != "confusion_matrix":
            print(f"  {k}: {v}")

    test_probs = best_model.predict(test_ds, verbose=0).ravel()
    test_metrics = binary_metrics(np.array(test_labels), test_probs)
    print("test metrics (Keras):")
    for k, v in test_metrics.items():
        if k != "confusion_matrix":
            print(f"  {k}: {v}")

    converter = tf.lite.TFLiteConverter.from_keras_model(best_model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    tflite_path = ARTIFACT_DIR / "best_frontal1.tflite"
    tflite_path.write_bytes(tflite_model)
    print(f"wrote tflite: {tflite_path.stat().st_size} bytes")

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    input_idx = interpreter.get_input_details()[0]["index"]
    output_idx = interpreter.get_output_details()[0]["index"]

    tflite_probs = []
    for i in range(0, len(test_paths), cfg.BATCH_SIZE):
        batch_paths = test_paths[i : i + cfg.BATCH_SIZE]
        batch_imgs = np.array([preprocess_image(p).numpy() for p in batch_paths], dtype=np.float32)
        interpreter.set_tensor(input_idx, batch_imgs)
        interpreter.invoke()
        tflite_probs.append(interpreter.get_tensor(output_idx).ravel())
    tflite_probs = np.concatenate(tflite_probs)
    tflite_metrics = binary_metrics(np.array(test_labels), tflite_probs)
    print("test metrics (TFLite):")
    for k, v in tflite_metrics.items():
        if k != "confusion_matrix":
            print(f"  {k}: {v}")

    out = {
        "experiment": "image_model_frontal1_only",
        "trained_at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "config": {k: v for k, v in vars(cfg).items() if not k.startswith("_")},
        "split": {
            "train_children": len(train_children),
            "validation_children": len(val_children),
            "test_children": len(test_children),
            "train_images": len(train_paths),
            "validation_images": len(val_paths),
            "test_images": len(test_paths),
        },
        "val_metrics": val_metrics,
        "test_metrics_keras": test_metrics,
        "test_metrics_tflite": tflite_metrics,
    }
    (RESULT_DIR / "metrics.json").write_text(json.dumps(out, indent=2))
    print(f"wrote {RESULT_DIR / 'metrics.json'}")


if __name__ == "__main__":
    main()
