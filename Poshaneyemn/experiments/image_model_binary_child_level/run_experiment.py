"""Isolated CHILD-LEVEL balanced BINARY MobileNetV2 experiment (AnthroVision only).

Question
--------
Can the MobileNetV2 image branch separate healthy vs malnourished children when
the experiment removes the two things that made the previous 4-class results
uninformative:

1. **Child leakage.** The child (`tag`), not the photo, is the unit of splitting,
   and every view of a child (frontal1..4, back, lateralleft, lateralright,
   selfie) lands in the same split. Zero child overlap by construction.
2. **Class imbalance.** The four AnthroVision classes are collapsed to
   ``healthy`` vs ``malnourished`` (underweight OR stunted OR stunted and
   underweight) and the two classes are matched on *children* -- no synthetic
   children, no duplicated children, no oversampling.

Design
------
* Child key = the CSV ``tag``. Two tags (1044, 1045) appear twice with different
  anthropometry *and* different photos, i.e. two different children sharing an
  id; each row is therefore kept as its own child ("1044#1", "1044#2", ...).
* Split: 70/15/15 at child level, stratified by the binary label, seed 42.
* Preprocessing: ``keras.applications.mobilenet_v2.preprocess_input`` ([-1, 1])
  for training and for TFLite inference (identical convention).
* Augmentation: TRAINING images only -- horizontal flip, contrast 0.1,
  translation 0.05, zoom 0.05. Validation/test images are never augmented.
* Class weights are still computed and passed (they come out ~1.0 on a balanced
  set); the balancing is done by the dataset, not by the loss.
* Early stopping (val_loss, patience 5), LR reduction (patience 3) and per-epoch
  checkpointing. Selection = validation balanced accuracy among epochs that keep
  healthy recall >= 0.5.
* The run is resumable: each epoch appends to ``artifacts/epoch_history.json``
  and saves ``last.keras``, so an interrupted run can continue with ``--resume``.

Read-only with respect to production: nothing under ``models/`` is written.
All outputs go under ``experiments/image_model_binary_child_level/``.

Usage (from ``D:\\Final-Year-Project\\Poshaneyemn``)::

    ..\\.venv\\Scripts\\python.exe experiments\\image_model_binary_child_level\\run_experiment.py
    ... --smoke          # tiny end-to-end check of the pipeline
    ... --resume         # continue an interrupted run
"""

from __future__ import annotations

import argparse
import contextlib
import csv
import io
import json
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parent.parent
sys.path.insert(0, str(EXPERIMENT_DIR))
sys.path.insert(0, str(PROJECT_ROOT / "src"))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import tensorflow as tf  # noqa: E402
from sklearn.metrics import (  # noqa: E402
    accuracy_score,
    balanced_accuracy_score,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split  # noqa: E402
from sklearn.utils.class_weight import compute_class_weight  # noqa: E402
from tensorflow.keras import layers  # noqa: E402
from tensorflow.keras.applications import MobileNetV2  # noqa: E402
from tensorflow.keras.applications.mobilenet_v2 import preprocess_input  # noqa: E402
from tensorflow.keras.layers import (  # noqa: E402
    RandomContrast,
    RandomFlip,
    RandomTranslation,
    RandomZoom,
)

import exp_config as cfg  # noqa: E402
from config import IMAGE_COLUMNS  # noqa: E402  (src/config.py)
from data_loader import DatasetLoader  # noqa: E402
from utils import ensure_dir, save_json  # noqa: E402


# --------------------------------------------------------------------------- #
# augmentation (module-level singletons: tf.function needs singleton variables)
# --------------------------------------------------------------------------- #
_AUGMENT_LAYERS = [
    RandomFlip(cfg.AUGMENTATION["random_flip"], seed=cfg.RANDOM_STATE),
    RandomContrast(cfg.AUGMENTATION["random_contrast"], seed=cfg.RANDOM_STATE),
    RandomTranslation(
        cfg.AUGMENTATION["random_translation_height"],
        cfg.AUGMENTATION["random_translation_width"],
        seed=cfg.RANDOM_STATE,
    ),
    RandomZoom(
        cfg.AUGMENTATION["random_zoom_height"],
        cfg.AUGMENTATION["random_zoom_width"],
        seed=cfg.RANDOM_STATE,
    ),
]


def augment_image(image: tf.Tensor) -> tf.Tensor:
    """Light, body-preserving augmentation (training images only)."""
    for layer in _AUGMENT_LAYERS:
        image = layer(image)
    return image


# --------------------------------------------------------------------------- #
# 1. child-level dataset assembly
# --------------------------------------------------------------------------- #
def build_children() -> pd.DataFrame:
    """One row per child: key, binary label, subgroup, and all of its images."""
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        df = DatasetLoader().load_anthrovision()
    views = [c for c in IMAGE_COLUMNS if c in df.columns]

    # tags that appear more than once describe different children (different
    # anthropometry AND different photos), so each row becomes its own child.
    duplicated = df["tag"].duplicated(keep=False)
    seen: dict[object, int] = {}
    keys: list[str] = []
    for tag, is_duplicate in zip(df["tag"], duplicated):
        if is_duplicate:
            seen[tag] = seen.get(tag, 0) + 1
            keys.append(f"{tag}#{seen[tag]}")
        else:
            keys.append(str(tag))
    df["child_key"] = keys

    rows: list[dict] = []
    for _, record in df.iterrows():
        images = [
            str(record[view])
            for view in views
            if str(record[view]).strip() and Path(str(record[view])).exists()
        ]
        if not images:
            continue  # child has no usable photo
        subgroup = str(record["multiclass_label"])
        rows.append(
            {
                "child_key": record["child_key"],
                "tag": record["tag"],
                "subgroup": subgroup,
                "binary_label": int(subgroup != cfg.NEGATIVE_CLASS),  # 1 = malnourished
                "images": images,
            }
        )
    return pd.DataFrame(rows)


def balance_children(children: pd.DataFrame) -> pd.DataFrame:
    """Match the two classes on the number of CHILDREN (no duplication, no synthesis)."""
    malnourished = children[children["binary_label"] == 1]
    healthy = children[children["binary_label"] == 0]
    n = min(len(malnourished), len(healthy))
    if len(healthy) > n:
        healthy = healthy.sample(n=n, random_state=cfg.RANDOM_STATE)
    balanced = pd.concat([malnourished, healthy]).sort_values("child_key").reset_index(drop=True)
    return balanced


def split_children(children: pd.DataFrame) -> dict[str, pd.DataFrame]:
    """70/15/15 split at child level, stratified by the binary label, seed 42."""
    train_df, holdout = train_test_split(
        children,
        test_size=(1.0 - cfg.TRAIN_FRACTION),
        stratify=children["binary_label"],
        random_state=cfg.RANDOM_STATE,
    )
    val_df, test_df = train_test_split(
        holdout,
        test_size=0.5,
        stratify=holdout["binary_label"],
        random_state=cfg.RANDOM_STATE,
    )
    return {
        "train": train_df.reset_index(drop=True),
        "validation": val_df.reset_index(drop=True),
        "test": test_df.reset_index(drop=True),
    }


def split_summary(frame: pd.DataFrame) -> dict:
    images = sum(len(imgs) for imgs in frame["images"])
    return {
        "children": int(len(frame)),
        "children_by_class": {
            cfg.NEGATIVE_CLASS: int((frame["binary_label"] == 0).sum()),
            cfg.POSITIVE_CLASS: int((frame["binary_label"] == 1).sum()),
        },
        "children_by_subgroup": {
            str(k): int(v) for k, v in frame["subgroup"].value_counts().to_dict().items()
        },
        "images": int(images),
        "images_per_child_mean": round(images / max(len(frame), 1), 2),
        "images_per_child_min": int(min((len(i) for i in frame["images"]), default=0)),
        "images_per_child_max": int(max((len(i) for i in frame["images"]), default=0)),
    }


# --------------------------------------------------------------------------- #
# 2. uint8 image cache (makes epochs ~4x faster; regenerable, delete any time)
# --------------------------------------------------------------------------- #
def build_cache(split_name: str, frame: pd.DataFrame, cache_dir: Path, reuse: bool) -> dict:
    paths = [p for images in frame["images"] for p in images]
    labels = np.repeat(frame["binary_label"].to_numpy(dtype=np.int32), [len(i) for i in frame["images"]])
    child_index = np.repeat(np.arange(len(frame), dtype=np.int32), [len(i) for i in frame["images"]])

    height, width = cfg.IMAGE_SIZE
    image_path = cache_dir / f"{split_name}_images.npy"
    label_path = cache_dir / f"{split_name}_labels.npy"
    child_path = cache_dir / f"{split_name}_child_index.npy"

    if reuse and image_path.exists() and label_path.exists() and child_path.exists():
        cached = np.load(image_path, mmap_mode="r")
        if cached.shape[0] == len(paths):
            return {"images": image_path, "labels": label_path, "child_index": child_path}

    def decode(path: tf.Tensor) -> tf.Tensor:
        raw = tf.io.read_file(path)
        image = tf.io.decode_image(raw, channels=3, expand_animations=False)
        image.set_shape([None, None, 3])
        return tf.image.resize(image, (height, width), method="bilinear")

    dataset = (
        tf.data.Dataset.from_tensor_slices(tf.constant(paths, dtype=tf.string))
        .map(decode, num_parallel_calls=tf.data.AUTOTUNE)
        .batch(64)
        .prefetch(tf.data.AUTOTUNE)
    )

    store = np.lib.format.open_memmap(
        image_path, mode="w+", dtype=np.uint8, shape=(len(paths), height, width, 3)
    )
    written = 0
    started = time.time()
    for batch in dataset:
        chunk = tf.cast(tf.clip_by_value(batch, 0.0, 255.0), tf.uint8).numpy()
        store[written : written + len(chunk)] = chunk
        written += len(chunk)
    store.flush()
    del store
    np.save(label_path, labels)
    np.save(child_path, child_index)
    print(
        f"  [cache] {split_name}: wrote {written} images in {time.time() - started:.1f}s "
        f"-> {image_path.name}"
    )
    return {"images": image_path, "labels": label_path, "child_index": child_path}


def make_dataset(cache: dict, augment: bool, shuffle: bool) -> tf.data.Dataset:
    images = np.load(cache["images"], mmap_mode="r")
    labels = np.load(cache["labels"])
    dataset = tf.data.Dataset.from_tensor_slices((images, labels))
    if shuffle:
        dataset = dataset.shuffle(len(labels), seed=cfg.RANDOM_STATE, reshuffle_each_iteration=True)
    dataset = dataset.map(
        lambda image, label: (preprocess_input(tf.cast(image, tf.float32)), label),
        num_parallel_calls=tf.data.AUTOTUNE,
    )
    if augment:
        dataset = dataset.map(
            lambda image, label: (augment_image(image), label),
            num_parallel_calls=tf.data.AUTOTUNE,
        )
    return dataset.batch(cfg.BATCH_SIZE).prefetch(tf.data.AUTOTUNE)


# --------------------------------------------------------------------------- #
# 3. metrics
# --------------------------------------------------------------------------- #
def binary_metrics(y_true: np.ndarray, probabilities: np.ndarray, threshold: float = 0.5) -> dict:
    y_true = np.asarray(y_true).astype(int)
    probabilities = np.asarray(probabilities, dtype=float)
    y_pred = (probabilities >= threshold).astype(int)
    tn, fp, fn, tp = (
        int(((y_true == 0) & (y_pred == 0)).sum()),
        int(((y_true == 0) & (y_pred == 1)).sum()),
        int(((y_true == 1) & (y_pred == 0)).sum()),
        int(((y_true == 1) & (y_pred == 1)).sum()),
    )
    metrics = {
        "n": int(len(y_true)),
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "precision_malnourished": float(precision_score(y_true, y_pred, zero_division=0)),
        "recall_malnourished": float(recall_score(y_true, y_pred, zero_division=0)),
        "f1_malnourished": float(f1_score(y_true, y_pred, zero_division=0)),
        "precision_macro": float(precision_score(y_true, y_pred, average="macro", zero_division=0)),
        "recall_macro": float(recall_score(y_true, y_pred, average="macro", zero_division=0)),
        "f1_macro": float(f1_score(y_true, y_pred, average="macro", zero_division=0)),
        "recall_healthy": float(recall_score(1 - y_true, 1 - y_pred, zero_division=0)),
        "mean_probability": float(probabilities.mean()),
        "mean_probability_malnourished": float(probabilities[y_true == 1].mean()) if (y_true == 1).any() else None,
        "mean_probability_healthy": float(probabilities[y_true == 0].mean()) if (y_true == 0).any() else None,
        "predicted_malnourished": int(y_pred.sum()),
        "confusion_matrix": {"tn": tn, "fp": fp, "fn": fn, "tp": tp,
                             "_rows": "true", "_cols": "predicted",
                             "labels": [[cfg.NEGATIVE_CLASS, cfg.POSITIVE_CLASS]]},
        "confusion_matrix_array": [[tn, fp], [fn, tp]],
    }
    if len(set(y_true.tolist())) > 1:
        metrics["roc_auc"] = float(roc_auc_score(y_true, probabilities))
    else:
        metrics["roc_auc"] = None
    return metrics


def child_level_metrics(frame: pd.DataFrame, probabilities: np.ndarray) -> dict:
    """Average the per-view probabilities of each child, then score the child."""
    labels, scores = [], []
    for position, (_, record) in enumerate(frame.iterrows()):
        view_count = len(record["images"])
        start = int(np.sum([len(i) for i in frame["images"].iloc[:position]]))
        scores.append(float(probabilities[start : start + view_count].mean()))
        labels.append(int(record["binary_label"]))
    metrics = binary_metrics(np.array(labels), np.array(scores))
    metrics["aggregation"] = "mean per-child probability over that child's views"
    return metrics


def subgroup_metrics(
    frame: pd.DataFrame, probabilities: np.ndarray, subgroup: str
) -> dict:
    """Recall for one original malnutrition subgroup, at image and at child level."""
    offsets, image_labels, image_scores, child_labels, child_scores = [], [], [], [], []
    cursor = 0
    for _, record in frame.iterrows():
        count = len(record["images"])
        scores = probabilities[cursor : cursor + count]
        cursor += count
        if record["subgroup"] == subgroup:
            image_scores.extend(scores.tolist())
            image_labels.extend([1] * count)
            child_scores.append(float(scores.mean()))
            child_labels.append(1)
    result = {
        "subgroup": subgroup,
        "test_children": len(child_labels),
        "test_images": len(image_labels),
    }
    if child_labels:
        pred = (np.array(child_scores) >= 0.5).astype(int)
        result["child_level_recall"] = float(pred.mean())
        result["child_level_mean_probability"] = float(np.mean(child_scores))
        pred_images = (np.array(image_scores) >= 0.5).astype(int)
        result["image_level_recall"] = float(pred_images.mean())
    else:
        result["child_level_recall"] = None
        result["image_level_recall"] = None
        result["child_level_mean_probability"] = None
    return result


# --------------------------------------------------------------------------- #
# 4. model
# --------------------------------------------------------------------------- #
def build_model() -> tf.keras.Model:
    base = MobileNetV2(
        input_shape=(*cfg.IMAGE_SIZE, 3), include_top=False, weights="imagenet", pooling="avg"
    )
    base.trainable = False
    inputs = layers.Input(shape=(*cfg.IMAGE_SIZE, 3), name="image_input")
    features = base(inputs, training=False)
    x = layers.Dropout(cfg.DROPOUT)(features)
    x = layers.Dense(cfg.DENSE_UNITS, activation="relu", name="binary_dense")(x)
    outputs = layers.Dense(1, activation="sigmoid", name="binary_output")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="mobilenet_binary_child_level")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=cfg.LEARNING_RATE),
        loss=tf.keras.losses.BinaryCrossentropy(),
        metrics=[tf.keras.metrics.BinaryAccuracy(name="binary_accuracy")],
    )
    return model


def export_tflite(model: tf.keras.Model, path: Path) -> None:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    path.write_bytes(converter.convert())


def tflite_predict(tflite_path: Path, images: np.ndarray, batch: int = 64) -> np.ndarray:
    """Run the exported TFLite model over the cached uint8 images.

    The export keeps the production convention (fixed batch 1), so images are fed
    one at a time unless the converter happened to emit a dynamic batch.
    """
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()[0]
    output_details = interpreter.get_output_details()[0]
    fixed_batch = int(input_details["shape"][0])
    step = 1 if fixed_batch == 1 else batch
    probabilities = np.zeros(len(images), dtype=np.float32)
    started = time.time()
    for start in range(0, len(images), step):
        chunk = preprocess_input(images[start : start + step].astype(np.float32))
        if fixed_batch == 1 and chunk.shape[0] != 1:
            chunk = chunk[:1]
        interpreter.set_tensor(input_details["index"], chunk)
        interpreter.invoke()
        probabilities[start : start + step] = interpreter.get_tensor(
            output_details["index"]
        ).reshape(-1)[: len(chunk)]
        if start and start % 512 == 0:
            print(f"    [tflite] {start}/{len(images)} images ({time.time() - started:.0f}s)")
    print(f"  [tflite] scored {len(images)} images in {time.time() - started:.1f}s")
    return probabilities


# --------------------------------------------------------------------------- #
# 5. main
# --------------------------------------------------------------------------- #
def main() -> None:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("--epochs", type=int, default=cfg.EPOCHS)
    parser.add_argument("--smoke", action="store_true", help="tiny end-to-end pipeline check")
    parser.add_argument("--resume", action="store_true", help="continue an interrupted run")
    parser.add_argument("--refresh-cache", action="store_true", help="rebuild the uint8 cache")
    parser.add_argument(
        "--max-views",
        type=int,
        default=0,
        help="cap views used per child (0 = use every available view)",
    )
    args = parser.parse_args()

    suffix = "_smoke" if args.smoke else ""
    artifact_dir = ensure_dir(cfg.ARTIFACT_DIR.parent / f"artifacts{suffix}")
    result_dir = ensure_dir(cfg.RESULT_DIR.parent / f"results{suffix}")
    cache_dir = ensure_dir(cfg.CACHE_DIR.parent / f"cache{suffix}")
    epochs = cfg.SMOKE_EPOCHS if args.smoke else args.epochs

    tf.keras.utils.set_random_seed(cfg.RANDOM_STATE)
    print(f"TensorFlow {tf.__version__} | seed {cfg.RANDOM_STATE} | epochs {epochs}")
    print(f"Artifacts -> {artifact_dir}\nResults   -> {result_dir}\n")

    # ---- children --------------------------------------------------------- #
    children = build_children()
    print("=" * 96)
    print("CHILD-LEVEL DATASET (AnthroVision only, one row per child)")
    print("=" * 96)
    print(f"  children with at least one usable image : {len(children)}")
    print(f"  children by subgroup                    : "
          f"{ {str(k): int(v) for k, v in children['subgroup'].value_counts().to_dict().items()} }")
    print(f"  total images (all views, all children)  : {int(sum(len(i) for i in children['images']))}")

    if args.max_views:
        children = children.copy()
        children["images"] = children["images"].map(lambda paths: paths[: args.max_views])
        print(f"  (views capped at {args.max_views} per child)")

    balanced = balance_children(children)
    if args.smoke:
        parts = []
        for label in (0, 1):
            subset = balanced[balanced["binary_label"] == label]
            parts.append(subset.head(cfg.SMOKE_CHILDREN_PER_CLASS))
        balanced = pd.concat(parts).reset_index(drop=True)

    print("\nAFTER CHILD-LEVEL BALANCING (no duplication, no synthetic children)")
    print(f"  healthy children      : {int((balanced['binary_label'] == 0).sum())}")
    print(f"  malnourished children : {int((balanced['binary_label'] == 1).sum())}")
    print(f"  total children        : {len(balanced)}")
    print(f"  malnourished subgroups: "
          f"{ {str(k): int(v) for k, v in balanced[balanced['binary_label'] == 1]['subgroup'].value_counts().to_dict().items()} }")

    splits = split_children(balanced)
    summary = {name: split_summary(frame) for name, frame in splits.items()}

    print("\n" + "=" * 96)
    print("SPLIT (child level, stratified by binary class, seed 42, ZERO child overlap)")
    print("=" * 96)
    header = f"{'split':<12}{'children':>9}{'healthy':>9}{'malnourished':>13}{'images':>9}{'img/child':>11}"
    print(header)
    print("-" * len(header))
    for name in ("train", "validation", "test"):
        s = summary[name]
        print(
            f"{name:<12}{s['children']:>9}{s['children_by_class'][cfg.NEGATIVE_CLASS]:>9}"
            f"{s['children_by_class'][cfg.POSITIVE_CLASS]:>13}{s['images']:>9}"
            f"{s['images_per_child_mean']:>11.2f}"
        )
    for name in ("train", "validation", "test"):
        print(f"  {name} subgroups: {summary[name]['children_by_subgroup']}")

    # prove the disjointness requirement
    key_sets = {name: set(frame["child_key"]) for name, frame in splits.items()}
    overlap = {
        "train_inter_validation": len(key_sets["train"] & key_sets["validation"]),
        "train_inter_test": len(key_sets["train"] & key_sets["test"]),
        "validation_inter_test": len(key_sets["validation"] & key_sets["test"]),
    }
    print(f"\n  child overlap between splits: {overlap}")
    if any(overlap.values()):
        raise SystemExit("Child overlap detected between splits -- aborting.")
    image_sets = {
        name: {p for images in frame["images"] for p in images} for name, frame in splits.items()
    }
    image_overlap = {
        "train_inter_validation": len(image_sets["train"] & image_sets["validation"]),
        "train_inter_test": len(image_sets["train"] & image_sets["test"]),
        "validation_inter_test": len(image_sets["validation"] & image_sets["test"]),
    }
    print(f"  image overlap between splits: {image_overlap}")
    if any(image_overlap.values()):
        raise SystemExit("Image overlap detected between splits -- aborting.")

    save_json(
        artifact_dir / "split_children.json",
        {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "class_definition": {
                cfg.NEGATIVE_CLASS: "AnthroVision multiclass_label == healthy",
                cfg.POSITIVE_CLASS: "multiclass_label in "
                + str(list(cfg.MALNOURISHED_LABELS)),
            },
            "balance_rule": "all malnourished children + an equal random sample of healthy children",
            "summary": summary,
            "overlap_check": {**overlap, **image_overlap},
            "children": {
                name: {
                    "child_keys": frame["child_key"].tolist(),
                    "binary_labels": frame["binary_label"].astype(int).tolist(),
                    "subgroups": frame["subgroup"].tolist(),
                    "images": frame["images"].tolist(),
                }
                for name, frame in splits.items()
            },
        },
    )

    # ---- caches ----------------------------------------------------------- #
    caches = {
        name: build_cache(name, frame, cache_dir, reuse=(args.resume or not args.refresh_cache))
        for name, frame in splits.items()
    }

    train_ds = make_dataset(caches["train"], augment=True, shuffle=True)
    val_ds = make_dataset(caches["validation"], augment=False, shuffle=False)
    test_ds = make_dataset(caches["test"], augment=False, shuffle=False)

    y_val = np.load(caches["validation"]["labels"])
    y_test = np.load(caches["test"]["labels"])

    class_weights_array = compute_class_weight(
        "balanced", classes=np.array([0, 1]), y=np.load(caches["train"]["labels"])
    )
    class_weights = {0: float(class_weights_array[0]), 1: float(class_weights_array[1])}
    print(f"\n  train class weights (balanced dataset -> ~1.0): {class_weights}")

    # ---- training --------------------------------------------------------- #
    history_path = artifact_dir / "epoch_history.json"
    state = {"epochs": [], "best": {"score": -1.0, "epoch": -1, "healthy_recall": None}}
    if args.resume and history_path.exists():
        state = json.loads(history_path.read_text(encoding="utf-8"))
        print(f"\n[resume] continuing from epoch {len(state['epochs'])}")

    last_path = artifact_dir / "last.keras"
    best_path = artifact_dir / "best_binary_child_level.keras"
    start_epoch = len(state["epochs"]) if args.resume else 0
    if args.resume and last_path.exists():
        model = tf.keras.models.load_model(last_path)
    else:
        model = build_model()

    best_val_loss = min([e["val_loss"] for e in state["epochs"]], default=float("inf"))
    epochs_without_improvement = 0
    for epoch in range(start_epoch, epochs):
        started = time.time()
        history = model.fit(
            train_ds,
            validation_data=val_ds,
            initial_epoch=epoch,
            epochs=epoch + 1,
            class_weight=class_weights,
            verbose=0,
        )
        train_loss = float(history.history["loss"][-1])
        val_probabilities = model.predict(val_ds, verbose=0).reshape(-1)
        val_metrics = binary_metrics(y_val, val_probabilities)
        val_child_metrics = child_level_metrics(splits["validation"], val_probabilities)
        record = {
            "epoch": epoch + 1,
            "train_loss": train_loss,
            "val_loss": float(history.history["val_loss"][-1]),
            "val_accuracy": val_metrics["accuracy"],
            "val_balanced_accuracy": val_metrics["balanced_accuracy"],
            "val_f1_malnourished": val_metrics["f1_malnourished"],
            "val_f1_macro": val_metrics["f1_macro"],
            "val_recall_malnourished": val_metrics["recall_malnourished"],
            "val_recall_healthy": val_metrics["recall_healthy"],
            "val_child_balanced_accuracy": val_child_metrics["balanced_accuracy"],
            "val_child_accuracy": val_child_metrics["accuracy"],
            "learning_rate": float(model.optimizer.learning_rate.numpy()),
            "seconds": round(time.time() - started, 1),
        }
        state["epochs"].append(record)

        model.save(last_path)

        if (
            val_metrics["recall_healthy"] >= cfg.HEALTHY_RECALL_FLOOR
            and val_metrics[cfg.PRIMARY_METRIC] > state["best"]["score"]
        ):
            state["best"] = {
                "score": val_metrics[cfg.PRIMARY_METRIC],
                "epoch": epoch + 1,
                "healthy_recall": val_metrics["recall_healthy"],
                "val_loss": record["val_loss"],
            }
            model.save(best_path)

        save_json(history_path, state)

        improved = record["val_loss"] < best_val_loss - 1e-4
        best_val_loss = min(best_val_loss, record["val_loss"])
        epochs_without_improvement = 0 if improved else epochs_without_improvement + 1
        if epochs_without_improvement >= cfg.LR_REDUCTION_PATIENCE:
            new_lr = max(float(model.optimizer.learning_rate.numpy()) * cfg.LR_REDUCTION_FACTOR, 1e-6)
            model.optimizer.learning_rate.assign(new_lr)
            epochs_without_improvement = 0
            print(f"    [lr] reduced to {new_lr:.2e}")

        print(
            f"  epoch {epoch + 1:>2}/{epochs}: train_loss={record['train_loss']:.4f} "
            f"val_loss={record['val_loss']:.4f} acc={record['val_accuracy']:.4f} "
            f"bal_acc={record['val_balanced_accuracy']:.4f} "
            f"F1={record['val_f1_malnourished']:.4f} "
            f"recall[mal]={record['val_recall_malnourished']:.4f} "
            f"recall[healthy]={record['val_recall_healthy']:.4f} "
            f"child_bal_acc={record['val_child_balanced_accuracy']:.4f} "
            f"({record['seconds']}s)"
            + ("  <- best" if state["best"]["epoch"] == epoch + 1 else "")
        )

        patience_hit = record["epoch"] - max(
            (e["epoch"] for e in state["epochs"] if e["val_loss"] <= best_val_loss + 1e-4), default=0
        )
        if patience_hit >= cfg.EARLY_STOPPING_PATIENCE:
            print(f"\n  early stopping: val_loss has not improved for {patience_hit} epochs")
            break

    # ---- evaluation ------------------------------------------------------- #
    if state["best"]["epoch"] > 0 and best_path.exists():
        model = tf.keras.models.load_model(best_path)
        note = f"best guarded validation {cfg.PRIMARY_METRIC} at epoch {state['best']['epoch']}"
    else:
        note = "no epoch met the healthy-recall floor; using final-epoch weights"
    model.save(artifact_dir / "final_binary_child_level.keras")
    tflite_path = artifact_dir / "binary_child_level.tflite"
    export_tflite(model, tflite_path)
    print(f"\n{note}\nTFLite exported -> {tflite_path} ({tflite_path.stat().st_size / 1e6:.2f} MB)")

    test_probabilities = model.predict(test_ds, verbose=0).reshape(-1)
    test_images = np.load(caches["test"]["images"], mmap_mode="r")
    tflite_probabilities = tflite_predict(tflite_path, test_images)

    image_metrics = binary_metrics(y_test, test_probabilities)
    image_metrics_tflite = binary_metrics(y_test, tflite_probabilities)
    child_metrics = child_level_metrics(splits["test"], test_probabilities)

    subgroups = {
        subgroup: subgroup_metrics(splits["test"], test_probabilities, subgroup)
        for subgroup in cfg.SUBGROUPS
    }
    healthy_frame = splits["test"][splits["test"]["binary_label"] == 0]
    healthy_child_scores = None
    cursor = 0
    for _, record in splits["test"].iterrows():
        count = len(record["images"])
        if record["binary_label"] == 0:
            healthy_child_scores = (healthy_child_scores or []) + [
                float(test_probabilities[cursor : cursor + count].mean())
            ]
        cursor += count
    healthy_mean_probability = (
        float(np.mean(healthy_child_scores)) if healthy_child_scores else None
    )

    validation_metrics = binary_metrics(y_val, model.predict(val_ds, verbose=0).reshape(-1))
    child_validation_metrics = child_level_metrics(
        splits["validation"], model.predict(val_ds, verbose=0).reshape(-1)
    )

    results = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "experiment": "child-level balanced binary healthy vs malnourished (AnthroVision only)",
        "dataset_source": "dataset/ANTHROVISION (AnthroVision only; ARAN not used)",
        "unit_of_splitting": "child (CSV tag; the two duplicated tags are treated as two children each)",
        "class_definition": {
            cfg.NEGATIVE_CLASS: "multiclass_label == 'healthy'",
            cfg.POSITIVE_CLASS: "multiclass_label in " + str(list(cfg.MALNOURISHED_LABELS)),
        },
        "augmentation": cfg.AUGMENTATION,
        "augmentation_note": "training images only; validation/test never augmented",
        "preprocessing": "keras.applications.mobilenet_v2.preprocess_input ([-1, 1]) for training and TFLite",
        "class_weights": class_weights,
        "class_weighting_note": (
            "the dataset is balanced on children, so weights are ~1.0; balancing comes from the "
            "dataset, not the loss"
        ),
        "selection": {
            "metric": cfg.PRIMARY_METRIC,
            "healthy_recall_floor": cfg.HEALTHY_RECALL_FLOOR,
            "chosen": state["best"],
            "note": note,
        },
        "children_overall": {
            "children_with_images": int(len(children)),
            "unique_tags": int(children["tag"].nunique()),
            "images": int(sum(len(i) for i in children["images"])),
            "subgroups": {str(k): int(v) for k, v in children["subgroup"].value_counts().to_dict().items()},
        },
        "children_after_balancing": {
            cfg.NEGATIVE_CLASS: int((balanced["binary_label"] == 0).sum()),
            cfg.POSITIVE_CLASS: int((balanced["binary_label"] == 1).sum()),
            "total": int(len(balanced)),
        },
        "splits": summary,
        "split_overlap_check": {**overlap, **image_overlap},
        "epoch_history": state["epochs"],
        "validation": {
            "image_level": validation_metrics,
            "child_level": child_validation_metrics,
        },
        "test": {
            "image_level_keras": image_metrics,
            "image_level_tflite": image_metrics_tflite,
            "child_level_keras": child_metrics,
            "metrics_note": "image_level counts every view as a sample; child_level averages a child's views first",
        },
        "test_subgroups": subgroups,
        "test_healthy_child_mean_probability": healthy_mean_probability,
    }
    save_json(result_dir / "binary_child_level_metrics.json", results)

    # ---- reports ---------------------------------------------------------- #
    confusion_dir = ensure_dir(result_dir / "confusion_matrices")
    for label, metrics in (("image_level_keras", image_metrics), ("child_level_keras", child_metrics),
                           ("image_level_tflite", image_metrics_tflite)):
        (confusion_dir / f"{label}.txt").write_text(
            f"{label}\n"
            f"n={metrics['n']}  accuracy={metrics['accuracy']:.4f}  "
            f"balanced_accuracy={metrics['balanced_accuracy']:.4f}\n"
            f"precision[{cfg.POSITIVE_CLASS}]={metrics['precision_malnourished']:.4f}  "
            f"recall[{cfg.POSITIVE_CLASS}]={metrics['recall_malnourished']:.4f}  "
            f"F1[{cfg.POSITIVE_CLASS}]={metrics['f1_malnourished']:.4f}\n"
            f"recall[{cfg.NEGATIVE_CLASS}]={metrics['recall_healthy']:.4f}\n\n"
            f"confusion matrix (rows=true, cols=predicted)\n"
            f"            pred healthy  pred malnourished\n"
            f"true healthy       {metrics['confusion_matrix']['tn']:>6}             {metrics['confusion_matrix']['fp']:>6}\n"
            f"true malnourish    {metrics['confusion_matrix']['fn']:>6}             {metrics['confusion_matrix']['tp']:>6}\n",
            encoding="utf-8",
        )

    with (result_dir / "per_subgroup_test_metrics.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["subgroup", "test_children", "test_images", "child_level_recall",
                        "image_level_recall", "child_level_mean_probability"],
        )
        writer.writeheader()
        for subgroup, metrics in subgroups.items():
            writer.writerow({k: metrics.get(k) for k in writer.fieldnames})
        writer.writerow(
            {
                "subgroup": cfg.NEGATIVE_CLASS,
                "test_children": int(len(healthy_frame)),
                "test_images": int(sum(len(i) for i in healthy_frame["images"])),
                "child_level_recall": None,
                "image_level_recall": None,
                "child_level_mean_probability": healthy_mean_probability,
            }
        )

    report = [
        "# Child-level balanced BINARY image experiment (AnthroVision only)",
        "",
        "Isolated experiment. No production file, TFLite model, Keras model, backend file or",
        "Flutter file was modified; everything is written under",
        "`experiments/image_model_binary_child_level/`.",
        "",
        "## Task",
        "",
        f"`{cfg.NEGATIVE_CLASS}` (AnthroVision healthy) vs `{cfg.POSITIVE_CLASS}` (underweight,",
        "stunted, stunted and underweight), balanced on the number of CHILDREN, with every view of",
        "a child kept in the same split and zero child overlap between splits.",
        "",
        "## Children",
        "",
        f"- children with at least one usable image: {len(children)} "
        f"(unique tags {children['tag'].nunique()}; 2 duplicated tags are kept as 2 children each)",
        f"- images (all views): {int(sum(len(i) for i in children['images']))}",
        f"- balanced dataset: {int((balanced['binary_label'] == 0).sum())} healthy + "
        f"{int((balanced['binary_label'] == 1).sum())} malnourished = {len(balanced)} children",
        f"- images per child: min {min(len(i) for i in children['images'])}, "
        f"max {max(len(i) for i in children['images'])}, "
        f"mean {np.mean([len(i) for i in children['images']]):.2f}",
        "",
        "## Split (child level, stratified, seed 42)",
        "",
        "| split | children | healthy | malnourished | images | images/child |",
        "|---|---|---|---|---|---|",
    ]
    for name in ("train", "validation", "test"):
        s = summary[name]
        report.append(
            f"| {name} | {s['children']} | {s['children_by_class'][cfg.NEGATIVE_CLASS]} | "
            f"{s['children_by_class'][cfg.POSITIVE_CLASS]} | {s['images']} | "
            f"{s['images_per_child_mean']:.2f} |"
        )
    report += [
        "",
        f"Child overlap between splits: {overlap} (all zero). Image overlap: {image_overlap} (all zero).",
        "",
        "## Test-set results (held-out children)",
        "",
        "| level | n | accuracy | balanced accuracy | precision[malnourished] | recall[malnourished] | F1[malnourished] | recall[healthy] | ROC-AUC |",
        "|---|---|---|---|---|---|---|---|---|",
    ]
    for label, metrics in (
        ("image level (Keras)", image_metrics),
        ("child level (Keras)", child_metrics),
        ("image level (TFLite)", image_metrics_tflite),
    ):
        report.append(
            f"| {label} | {metrics['n']} | {metrics['accuracy']:.4f} | "
            f"{metrics['balanced_accuracy']:.4f} | {metrics['precision_malnourished']:.4f} | "
            f"{metrics['recall_malnourished']:.4f} | {metrics['f1_malnourished']:.4f} | "
            f"{metrics['recall_healthy']:.4f} | "
            f"{metrics['roc_auc'] if metrics['roc_auc'] is None else round(metrics['roc_auc'], 4)} |"
        )
    report += [
        "",
        "Confusion matrix, image level (rows = truth, columns = predicted; order healthy, malnourished):",
        "",
        "```",
        str(np.array(image_metrics["confusion_matrix_array"])),
        "```",
        "",
        "Confusion matrix, child level:",
        "",
        "```",
        str(np.array(child_metrics["confusion_matrix_array"])),
        "```",
        "",
        "## Recall by original malnutrition subgroup (held-out test children)",
        "",
        "| subgroup | test children | test images | child-level recall | image-level recall | mean probability |",
        "|---|---|---|---|---|---|",
    ]
    for subgroup, metrics in subgroups.items():
        report.append(
            f"| {subgroup} | {metrics['test_children']} | {metrics['test_images']} | "
            f"{metrics['child_level_recall']} | {metrics['image_level_recall']} | "
            f"{metrics['child_level_mean_probability']} |"
        )
    report.append(
        f"| {cfg.NEGATIVE_CLASS} (control) | {len(healthy_frame)} | "
        f"{int(sum(len(i) for i in healthy_frame['images']))} | - | - | {healthy_mean_probability} |"
    )
    report += [
        "",
        "## Selection and training",
        "",
        f"- selection metric: validation {cfg.PRIMARY_METRIC} with healthy-recall floor "
        f"{cfg.HEALTHY_RECALL_FLOOR} -> {note}",
        f"- class weights (train, balanced): {class_weights}",
        f"- augmentation (train only): {cfg.AUGMENTATION}",
        f"- epochs run: {len(state['epochs'])} of {epochs}, early stopping patience "
        f"{cfg.EARLY_STOPPING_PATIENCE}",
        "",
        "## Limitations",
        "",
        "- The `malnourished` target is the AnthroVision anthropometric label definition",
        "  (hfa/wfa z-score rule), not an independent clinical assessment. High accuracy here",
        "  means the images correlate with that label, not that the model diagnoses malnutrition.",
        "- `stunted` has far fewer children than the other subgroups, so its per-subgroup recall",
        "  is the noisiest number in this report.",
        "- One experiment, one seed; treat the numbers as a single measurement.",
        "",
        "## Files",
        "",
        "- `results/binary_child_level_metrics.json`, `results/per_subgroup_test_metrics.csv`",
        "- `results/confusion_matrices/*.txt`, `artifacts/split_children.json`",
        "- `artifacts/epoch_history.json`, `artifacts/binary_child_level.tflite`",
        "",
    ]
    (result_dir / "final_report.md").write_text("\n".join(report), encoding="utf-8")

    # ---- console summary -------------------------------------------------- #
    print("\n" + "=" * 96)
    print("HELD-OUT TEST (untouched children)")
    print("=" * 96)
    print(f"{'level':<24}{'n':>6}{'acc':>9}{'balAcc':>9}{'prec[mal]':>11}{'rec[mal]':>10}{'F1[mal]':>9}{'rec[healthy]':>14}{'AUC':>8}")
    for label, metrics in (
        ("image (Keras)", image_metrics),
        ("child (Keras)", child_metrics),
        ("image (TFLite)", image_metrics_tflite),
    ):
        auc = metrics["roc_auc"]
        print(
            f"{label:<24}{metrics['n']:>6}{metrics['accuracy']:>9.4f}"
            f"{metrics['balanced_accuracy']:>9.4f}{metrics['precision_malnourished']:>11.4f}"
            f"{metrics['recall_malnourished']:>10.4f}{metrics['f1_malnourished']:>9.4f}"
            f"{metrics['recall_healthy']:>14.4f}{(f'{auc:.4f}' if auc else 'n/a'):>8}"
        )
    print(f"\nconfusion (image level, rows=true, cols=pred): {np.array(image_metrics['confusion_matrix_array']).tolist()}")
    print(f"confusion (child level)                     : {np.array(child_metrics['confusion_matrix_array']).tolist()}")
    print("\nper-subgroup recall on held-out children:")
    for subgroup, metrics in subgroups.items():
        print(
            f"  {subgroup:<26} children={metrics['test_children']:>4} "
            f"child_recall={metrics['child_level_recall']} "
            f"image_recall={metrics['image_level_recall']} "
            f"mean_prob={None if metrics['child_level_mean_probability'] is None else round(metrics['child_level_mean_probability'], 4)}"
        )
    print(f"  {cfg.NEGATIVE_CLASS + ' (control)':<26} children={len(healthy_frame):>4} "
          f"mean_prob={None if healthy_mean_probability is None else round(healthy_mean_probability, 4)}")
    print(f"\nArtifacts: {artifact_dir}\nReports:   {result_dir}")


if __name__ == "__main__":
    main()
