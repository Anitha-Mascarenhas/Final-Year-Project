"""Isolated MobileNetV2 v2 experiment for the PoshanEye 4-class image classifier.

Goal
----
Test whether damped class weights (plus slightly richer, still-conservative
augmentation and a consistent MobileNetV2 preprocessing convention between Keras
training and TFLite inference) improve MINORITY-class recognition over the current
production TFLite model, without repeating the v1 collapse of the majority class.

Reference points on the identical held-out test split (429 images):
  * production  models/best_model.tflite                     (accuracy ~0.699, macro F1 ~0.225)
  * v1          models/class_balanced_experiment/...         (accuracy ~0.501, macro F1 ~0.258)

Design
------
* Split: the project's existing stratified split (DataPreprocessor.split_dataset,
  RANDOM_STATE=42) is reused verbatim via Pipeline.build_datasets() -- no reseeding,
  no re-splitting, no new split logic.
* Preprocessing: keras.applications.mobilenet_v2.preprocess_input ([-1, 1]) for
  train/validation/test AND for TFLite inference on the new models.
* Augmentation, training split only: RandomFlip(horizontal), RandomContrast(0.1),
  RandomTranslation(0.05, 0.05), RandomZoom(0.05). No rotation/shear/colour jitter.
* Class weights: n_train / (n_classes * n_train_c), raised to a damping exponent
  alpha in {0.25, 0.50, 0.75} (computed from the TRAIN split only). v1's alpha = 1.0
  is evaluated as an existing artifact instead of being retrained.
* Architecture/optimizer/loss/epochs/dropout: unchanged from src/image_model.py.
  The MobileNetV2 base stays frozen, weights="imagenet".
* Selection: validation macro F1 (primary) with a healthy-recall guard
  (>= HEALTHY_RECALL_FLOOR); the test split is used only for final reporting of
  arms selected on validation.

Read-only with respect to production: nothing under models/ is written or replaced.
All outputs go under experiments/image_model_v2/{artifacts,results,logs}.

Usage (from D:\\Final-Year-Project\\Poshaneyemn):

    ..\\.venv\\Scripts\\python.exe experiments\\image_model_v2\\run_experiment.py

Optional:
    --epochs 25            (override epoch budget)
    --arms alpha_0.25,alpha_0.50,alpha_0.75
    --tag smoke            (write into results_smoke/artifacts_smoke instead)
"""

from __future__ import annotations

import argparse
import contextlib
import csv
import io
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parent.parent
sys.path.insert(0, str(EXPERIMENT_DIR))
sys.path.insert(0, str(PROJECT_ROOT / "src"))
sys.path.insert(0, str(PROJECT_ROOT / "scripts"))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
import tensorflow as tf  # noqa: E402
from sklearn.metrics import (  # noqa: E402
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
)
from tensorflow.keras import layers  # noqa: E402
from tensorflow.keras.applications import MobileNetV2  # noqa: E402
from tensorflow.keras.callbacks import EarlyStopping, ReduceLROnPlateau  # noqa: E402
from tensorflow.keras.layers import (  # noqa: E402
    RandomContrast,
    RandomFlip,
    RandomTranslation,
    RandomZoom,
)

import exp_config as cfg  # noqa: E402
from config import MODEL_DIR  # noqa: E402  (src/config.py)
from image_model import ImageModelTrainer  # noqa: E402
from pipeline import Pipeline  # noqa: E402
from tf_data import preprocess_image  # noqa: E402
from utils import ensure_dir, save_json  # noqa: E402

import compare_tflite_models as ctm  # noqa: E402  (reuse decode/inference helpers)


# --------------------------------------------------------------------------- #
# augmentation (module-level singletons: tf.function requires singleton variables)
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
    """Light augmentation for child health photographs (train split only)."""
    for layer in _AUGMENT_LAYERS:
        image = layer(image)
    return image


def build_dataset(
    df: pd.DataFrame,
    augment: bool,
    shuffle: bool,
    batch_size: int = cfg.BATCH_SIZE,
) -> tf.data.Dataset:
    """Build a tf.data pipeline using the project's own preprocess_image."""
    paths = df["image_path"].astype(str).tolist()
    labels = df["label"].astype(int).tolist()
    dataset = tf.data.Dataset.from_tensor_slices(
        (tf.constant(paths, dtype=tf.string), tf.constant(labels, dtype=tf.int32))
    )
    if shuffle:
        dataset = dataset.shuffle(len(paths), seed=cfg.RANDOM_STATE, reshuffle_each_iteration=True)
    dataset = dataset.map(
        lambda path, label: (preprocess_image(path), label),
        num_parallel_calls=tf.data.AUTOTUNE,
    )
    if augment:
        dataset = dataset.map(
            lambda image, label: (augment_image(image), label),
            num_parallel_calls=tf.data.AUTOTUNE,
        )
    return dataset.batch(batch_size).prefetch(tf.data.AUTOTUNE)


# --------------------------------------------------------------------------- #
# metrics
# --------------------------------------------------------------------------- #
def compute_metrics(
    y_true: np.ndarray,
    probabilities: np.ndarray,
    class_names: list[str],
    healthy_index: int,
) -> dict:
    labels = list(range(len(class_names)))
    y_pred = np.argmax(probabilities, axis=1)
    report = classification_report(
        y_true, y_pred, labels=labels, target_names=class_names, output_dict=True, zero_division=0
    )
    per_class = {
        name: {
            "index": index,
            "precision": float(report[name]["precision"]),
            "recall": float(report[name]["recall"]),
            "f1": float(report[name]["f1-score"]),
            "support": int(report[name]["support"]),
        }
        for index, name in zip(labels, class_names)
    }
    return {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "balanced_accuracy": float(balanced_accuracy_score(y_true, y_pred)),
        "healthy_recall": float(per_class[class_names[healthy_index]]["recall"]),
        "mean_top_probability": float(probabilities.max(axis=1).mean()),
        "predicted_distribution": np.bincount(y_pred, minlength=len(class_names)).tolist(),
        "per_class": per_class,
        "macro": {
            "precision": float(report["macro avg"]["precision"]),
            "recall": float(report["macro avg"]["recall"]),
            "f1": float(report["macro avg"]["f1-score"]),
        },
        "weighted": {
            "precision": float(report["weighted avg"]["precision"]),
            "recall": float(report["weighted avg"]["recall"]),
            "f1": float(report["weighted avg"]["f1-score"]),
        },
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=labels).tolist(),
        "classification_report_text": classification_report(
            y_true, y_pred, labels=labels, target_names=class_names, zero_division=0
        ),
        "total": int(len(y_true)),
    }


# --------------------------------------------------------------------------- #
# validation-driven checkpointing
# --------------------------------------------------------------------------- #
class MacroF1Checkpoint(tf.keras.callbacks.Callback):
    """Track validation macro F1 per epoch and keep the best guarded checkpoint."""

    def __init__(
        self,
        val_dataset: tf.data.Dataset,
        y_val: np.ndarray,
        class_names: list[str],
        healthy_index: int,
        checkpoint_path: Path,
        healthy_recall_floor: float,
    ) -> None:
        super().__init__()
        self.val_dataset = val_dataset
        self.y_val = y_val
        self.class_names = class_names
        self.healthy_index = healthy_index
        self.checkpoint_path = checkpoint_path
        self.healthy_recall_floor = healthy_recall_floor
        self.history: list[dict] = []
        self.best_score = -1.0
        self.best_epoch = -1
        self.best_healthy_recall = None
        self.unguarded_best_score = -1.0
        self.unguarded_best_epoch = -1
        self.saved = False

    def on_epoch_end(self, epoch: int, logs: dict | None = None) -> None:
        logs = logs or {}
        probabilities = self.model.predict(self.val_dataset, verbose=0)
        metrics = compute_metrics(
            self.y_val, probabilities, self.class_names, self.healthy_index
        )
        record = {
            "epoch": epoch + 1,
            "train_loss": float(logs.get("loss", float("nan"))),
            "val_loss": float(logs.get("val_loss", float("nan"))),
            "val_accuracy": metrics["accuracy"],
            "val_balanced_accuracy": metrics["balanced_accuracy"],
            "val_macro_f1": metrics["macro"]["f1"],
            "val_macro_recall": metrics["macro"]["recall"],
            "val_healthy_recall": metrics["healthy_recall"],
        }
        self.history.append(record)

        score = metrics["macro"]["f1"]
        if score > self.unguarded_best_score:
            self.unguarded_best_score = score
            self.unguarded_best_epoch = epoch + 1

        if metrics["healthy_recall"] >= self.healthy_recall_floor and score > self.best_score:
            self.best_score = score
            self.best_epoch = epoch + 1
            self.best_healthy_recall = metrics["healthy_recall"]
            self.model.save(self.checkpoint_path)
            self.saved = True

        print(
            f"    epoch {epoch + 1:>2}: val_loss={record['val_loss']:.4f} "
            f"val_acc={record['val_accuracy']:.4f} val_macroF1={record['val_macro_f1']:.4f} "
            f"healthy_recall={record['val_healthy_recall']:.4f}"
            + ("  <- saved" if self.best_epoch == epoch + 1 else "")
        )


def build_model(num_classes: int) -> tf.keras.Model:
    """Same architecture as src/image_model.ImageModelTrainer.build_model."""
    base_model = MobileNetV2(
        input_shape=(*cfg.IMAGE_SIZE, 3), include_top=False, weights="imagenet", pooling="avg"
    )
    base_model.trainable = False
    inputs = layers.Input(shape=(*cfg.IMAGE_SIZE, 3), name="image_input")
    x = base_model(inputs, training=False)
    x = layers.Dropout(cfg.DROPOUT)(x)
    x = layers.Dense(cfg.DENSE_UNITS, activation="relu", name="image_dense")(x)
    outputs = layers.Dense(num_classes, activation="softmax", name="image_output")(x)
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="mobilenet_image_model")
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=cfg.LEARNING_RATE),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(from_logits=False),
        metrics=[tf.keras.metrics.SparseCategoricalAccuracy(name="sparse_categorical_accuracy")],
    )
    return model


def damped_class_weights(train_df: pd.DataFrame, alpha: float, num_classes: int) -> dict[int, float]:
    counts = train_df["label"].value_counts().sort_index()
    total = int(counts.sum())
    weights: dict[int, float] = {}
    for class_index in range(num_classes):
        count = int(counts.get(class_index, 0))
        if count == 0:
            weights[class_index] = 0.0
            continue
        weights[class_index] = float((total / (num_classes * count)) ** alpha)
    return weights


# --------------------------------------------------------------------------- #
# split
# --------------------------------------------------------------------------- #
def build_split(verbose: bool = False):
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        pipeline = Pipeline(model_dir=MODEL_DIR)
        train_df, val_df, test_df = pipeline.build_datasets()
    if verbose:
        print(buffer.getvalue())
    class_names = [str(name) for name in pipeline.preprocessor.encoder.classes_]
    return train_df, val_df, test_df, class_names


def split_summary(df: pd.DataFrame, class_names: list[str]) -> dict:
    counts = df["label"].value_counts().sort_index().to_dict()
    return {
        "total": int(len(df)),
        "per_class": {class_names[i]: int(counts.get(i, 0)) for i in range(len(class_names))},
    }


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--epochs", type=int, default=cfg.EPOCHS)
    parser.add_argument("--arms", type=str, default=",".join(name for name, _ in cfg.ARMS))
    parser.add_argument("--tag", type=str, default="", help="Suffix for output directories (e.g. smoke).")
    parser.add_argument(
        "--test-frac",
        type=float,
        default=1.0,
        help="Fraction of the held-out test split to evaluate (smoke testing only).",
    )
    parser.add_argument("--verbose-split", action="store_true")
    parser.add_argument(
        "--eval-only",
        action="store_true",
        help=(
            "Skip training: reuse the TFLite/Keras artifacts and the saved "
            "<arm>_validation.json already in artifacts/, re-run the held-out test "
            "evaluation and rewrite the reports so they describe the models on disk."
        ),
    )
    args = parser.parse_args()

    suffix = f"_{args.tag}" if args.tag else ""
    artifact_dir = ensure_dir(cfg.EXPERIMENT_DIR / f"artifacts{suffix}")
    result_dir = ensure_dir(cfg.EXPERIMENT_DIR / f"results{suffix}")
    log_dir = ensure_dir(cfg.EXPERIMENT_DIR / f"logs{suffix}")
    arm_specs = [(name, alpha) for name, alpha in cfg.ARMS if name in {a.strip() for a in args.arms.split(",")}]
    if not arm_specs:
        raise SystemExit(f"No known arms selected. Available: {[name for name, _ in cfg.ARMS]}")

    tf.keras.utils.set_random_seed(cfg.RANDOM_STATE)
    print(f"TensorFlow {tf.__version__} | seed {cfg.RANDOM_STATE} | epochs {args.epochs}")
    print(f"Outputs -> {result_dir}")

    # ---- data ------------------------------------------------------------- #
    train_df, val_df, test_df, class_names = build_split(verbose=args.verbose_split)
    num_classes = len(class_names)
    healthy_index = class_names.index("healthy")

    print("\n=== AUTHORITATIVE CLASS ORDER (fitted LabelEncoder) ===")
    for index, name in enumerate(class_names):
        print(f"  {index} -> {name}")

    summary = {
        "train": split_summary(train_df, class_names),
        "validation": split_summary(val_df, class_names),
        "test": split_summary(test_df, class_names),
        "class_names": class_names,
        "split_source": "Pipeline.build_datasets -> DataPreprocessor.split_dataset (stratified, RANDOM_STATE=42)",
    }
    print("\n=== SPLIT ===")
    for split_name in ("train", "validation", "test"):
        print(f"  {split_name:<11} n={summary[split_name]['total']:<5} {summary[split_name]['per_class']}")

    save_json(
        artifact_dir / "split_indices.json",
        {
            "class_names": class_names,
            "splits": {
                "train": train_df["image_path"].astype(str).tolist(),
                "validation": val_df["image_path"].astype(str).tolist(),
                "test": test_df["image_path"].astype(str).tolist(),
            },
            "labels": {
                "train": train_df["label"].astype(int).tolist(),
                "validation": val_df["label"].astype(int).tolist(),
                "test": test_df["label"].astype(int).tolist(),
            },
            "summary": summary,
        },
    )

    if args.test_frac < 1.0:
        test_df = test_df.sample(frac=args.test_frac, random_state=cfg.RANDOM_STATE).reset_index(drop=True)
        print(f"[smoke] evaluating on {len(test_df)} of the held-out test images")

    y_val = val_df["label"].to_numpy(dtype=np.int64)
    y_test = test_df["label"].to_numpy(dtype=np.int64)

    train_dataset = build_dataset(train_df, augment=True, shuffle=True)
    val_dataset = build_dataset(val_df, augment=False, shuffle=False)
    test_dataset = build_dataset(test_df, augment=False, shuffle=False)

    # ---- arms ------------------------------------------------------------- #
    arm_results: dict[str, dict] = {}
    for arm_name, alpha in arm_specs:
        arm_dir = ensure_dir(artifact_dir / arm_name)

        if args.eval_only:
            validation_json = artifact_dir / f"{arm_name}_validation.json"
            tflite_path = arm_dir / "best_model.tflite"
            if not validation_json.exists() or not tflite_path.exists():
                raise SystemExit(
                    f"--eval-only: missing artifacts for arm '{arm_name}' "
                    f"({validation_json.name} / best_model.tflite)."
                )
            result = json.loads(validation_json.read_text(encoding="utf-8"))
            result["tflite_path"] = str(tflite_path)
            arm_results[arm_name] = result
            val_metrics = result["validation_metrics"]
            print(
                f"\n=== ARM {arm_name} (alpha={result['alpha']}) "
                f"[eval-only: reusing saved artifacts] ==="
            )
            print(
                f"  saved validation: acc={val_metrics['accuracy']:.4f} "
                f"balanced_acc={val_metrics['balanced_accuracy']:.4f} "
                f"macroF1={val_metrics['macro']['f1']:.4f} "
                f"healthy_recall={val_metrics['healthy_recall']:.4f} "
                f"({result.get('selection_note', 'n/a')})"
            )
            continue

        weights = damped_class_weights(train_df, alpha, num_classes)
        print(f"\n=== ARM {arm_name} (alpha={alpha}) ===")
        print(f"  preprocess: train/val/test = mobilenet preprocess_input ([-1, 1])")
        print(f"  augmentation: train only, {cfg.AUGMENTATION}")
        print("  class weights (train split only):")
        counts = train_df["label"].value_counts().sort_index().to_dict()
        for index, name in enumerate(class_names):
            print(
                f"    {index} {name:<26} n_train={int(counts.get(index, 0)):<5} weight={weights[index]:.4f}"
            )

        model = build_model(num_classes)
        checkpoint_path = arm_dir / "image_best_keras.keras"
        selector = MacroF1Checkpoint(
            val_dataset=val_dataset,
            y_val=y_val,
            class_names=class_names,
            healthy_index=healthy_index,
            checkpoint_path=checkpoint_path,
            healthy_recall_floor=cfg.HEALTHY_RECALL_FLOOR,
        )
        history = model.fit(
            train_dataset,
            validation_data=val_dataset,
            epochs=args.epochs,
            class_weight=weights,
            callbacks=[
                selector,
                EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=False),
                ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=3, verbose=1),
            ],
            verbose=0,
        )

        if selector.saved:
            selected_model = tf.keras.models.load_model(checkpoint_path)
            selection_note = f"best guarded validation macro F1 at epoch {selector.best_epoch}"
        else:
            selected_model = model
            selection_note = (
                "no epoch respected the healthy-recall floor; fell back to final-epoch weights"
            )

        selected_model.save(arm_dir / "image_best.keras")
        trainer = ImageModelTrainer(model_dir=arm_dir, log_dir=log_dir / arm_name)
        trainer.model = selected_model
        trainer.save(arm_dir / "image_model.keras")
        trainer.save_tflite(arm_dir / "best_model.tflite")

        val_probabilities = selected_model.predict(val_dataset, verbose=0)
        val_metrics = compute_metrics(y_val, val_probabilities, class_names, healthy_index)

        arm_results[arm_name] = {
            "alpha": alpha,
            "class_weights": weights,
            "class_counts": {class_names[i]: int(counts.get(i, 0)) for i in range(num_classes)},
            "selection_note": selection_note,
            "selected_epoch": selector.best_epoch,
            "epochs_run": len(selector.history),
            "history": selector.history,
            "unguarded_best": {
                "epoch": selector.unguarded_best_epoch,
                "val_macro_f1": selector.unguarded_best_score,
            },
            "keras_history": {
                key: [float(v) for v in values] for key, values in history.history.items()
            },
            "validation_metrics": val_metrics,
            "tflite_path": str(arm_dir / "best_model.tflite"),
        }
        print(
            f"  selected: {selection_note}\n"
            f"  validation: acc={val_metrics['accuracy']:.4f} "
            f"balanced_acc={val_metrics['balanced_accuracy']:.4f} "
            f"macroF1={val_metrics['macro']['f1']:.4f} "
            f"healthy_recall={val_metrics['healthy_recall']:.4f}"
        )
        save_json(artifact_dir / f"{arm_name}_validation.json", arm_results[arm_name])

    # ---- arm selection on validation -------------------------------------- #
    guarded = {
        name: result
        for name, result in arm_results.items()
        if result["validation_metrics"]["healthy_recall"] >= cfg.HEALTHY_RECALL_FLOOR
    }
    pool = guarded or arm_results
    selected_arm = max(pool, key=lambda name: pool[name]["validation_metrics"]["macro"]["f1"])
    print(
        f"\n=== SELECTED ARM (validation {cfg.PRIMARY_METRIC}="
        f"{pool[selected_arm]['validation_metrics']['macro']['f1']:.4f}, healthy-recall floor "
        f"{cfg.HEALTHY_RECALL_FLOOR}): {selected_arm} ==="
    )

    # ---- TFLite evaluation on the held-out test split --------------------- #
    print("\nDecoding/resizing test images once for TFLite evaluation ...")
    test_paths = test_df["image_path"].astype(str).tolist()
    test_uint8 = ctm.decode_images(test_paths)

    model_paths: dict[str, Path] = {}
    modes: dict[str, str] = {}
    if cfg.PRODUCTION_MODEL.exists():
        model_paths["production"] = cfg.PRODUCTION_MODEL
        modes["production"] = cfg.PREPROCESSING_MODE["production"]
    if cfg.V1_EXPERIMENT_MODEL.exists():
        model_paths["v1_balanced_alpha_1.00"] = cfg.V1_EXPERIMENT_MODEL
        modes["v1_balanced_alpha_1.00"] = cfg.PREPROCESSING_MODE["v1_balanced_alpha_1.00"]
    for arm_name in arm_results:
        model_paths[arm_name] = Path(arm_results[arm_name]["tflite_path"])
        modes[arm_name] = "mobilenet"

    interpreters = ctm.load_interpreters(model_paths)
    tflite_metrics: dict[str, dict[str, dict]] = {}
    for model_name, interpreter in interpreters.items():
        tflite_metrics[model_name] = {}
        for mode in ctm.PREPROCESSING_MODES:
            print(f"  predicting: {model_name} / {mode} ...")
            probabilities = ctm.predict(interpreter, test_uint8, mode)
            tflite_metrics[model_name][mode] = compute_metrics(
                y_test, probabilities, class_names, healthy_index
            )

    # ---- reports ---------------------------------------------------------- #
    ordered = [name for name in ("production", "v1_balanced_alpha_1.00") if name in tflite_metrics]
    ordered += list(arm_results)
    primary = {name: modes[name] for name in ordered}

    comparison_rows = []
    for name in ordered:
        metrics = tflite_metrics[name][primary[name]]
        validation = (
            arm_results[name]["validation_metrics"] if name in arm_results else None
        )
        comparison_rows.append(
            {
                "model": name,
                "preprocessing": primary[name],
                "class_weighting": "none" if name == "production" else f"damped alpha={arm_results[name]['alpha']}" if name in arm_results else "full balanced alpha=1.0",
                "test_accuracy": metrics["accuracy"],
                "test_balanced_accuracy": metrics["balanced_accuracy"],
                "test_macro_precision": metrics["macro"]["precision"],
                "test_macro_recall": metrics["macro"]["recall"],
                "test_macro_f1": metrics["macro"]["f1"],
                "test_weighted_precision": metrics["weighted"]["precision"],
                "test_weighted_recall": metrics["weighted"]["recall"],
                "test_weighted_f1": metrics["weighted"]["f1"],
                "test_healthy_recall": metrics["healthy_recall"],
                "val_macro_f1": validation["macro"]["f1"] if validation else "",
                "val_balanced_accuracy": validation["balanced_accuracy"] if validation else "",
                "selected": "yes" if name == selected_arm else "",
            }
        )

    comparison_csv = result_dir / "model_comparison.csv"
    with comparison_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(comparison_rows[0].keys()))
        writer.writeheader()
        writer.writerows(comparison_rows)

    per_class_rows = []
    for name in ordered:
        metrics = tflite_metrics[name][primary[name]]
        for class_name in class_names:
            entry = metrics["per_class"][class_name]
            per_class_rows.append(
                {
                    "model": name,
                    "class": class_name,
                    "index": entry["index"],
                    "precision": entry["precision"],
                    "recall": entry["recall"],
                    "f1": entry["f1"],
                    "support": entry["support"],
                }
            )
    per_class_csv = result_dir / "per_class_metrics.csv"
    with per_class_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(per_class_rows[0].keys()))
        writer.writeheader()
        writer.writerows(per_class_rows)

    confusion_dir = ensure_dir(result_dir / "confusion_matrices")
    for name in ordered:
        metrics = tflite_metrics[name][primary[name]]
        (confusion_dir / f"{name}.txt").write_text(
            f"{name} (preprocessing: {primary[name]})\n"
            f"accuracy: {metrics['accuracy']:.4f}  balanced_accuracy: {metrics['balanced_accuracy']:.4f}  "
            f"macro_f1: {metrics['macro']['f1']:.4f}\n\n"
            f"{metrics['classification_report_text']}\n"
            f"confusion matrix (rows=true, cols=pred):\n{np.array(metrics['confusion_matrix'])}\n"
            f"class index order: {class_names}\n",
            encoding="utf-8",
        )

    save_json(
        result_dir / "tflite_evaluation.json",
        {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "split": summary,
            "selected_arm": selected_arm,
            "selection_rule": (
                f"highest validation {cfg.PRIMARY_METRIC} among arms with validation "
                f"healthy recall >= {cfg.HEALTHY_RECALL_FLOOR}"
            ),
            "test_set_note": (
                "Test split is the project's existing held-out split (429 images) and was not "
                "used for training, augmentation or arm selection."
            ),
            "label_mapping_check": {
                "encoder_classes": class_names,
                "note": "Model output indices follow the fitted LabelEncoder order.",
            },
            "models": {
                name: {
                    "path": str(model_paths[name]),
                    "primary_preprocessing": primary[name],
                    "arm_config": arm_results.get(name),
                    "metrics_by_preprocessing": tflite_metrics[name],
                    "primary_metrics": tflite_metrics[name][primary[name]],
                }
                for name in ordered
            },
        },
    )

    # ---- console summary -------------------------------------------------- #
    print("\n" + "=" * 118)
    print(f"{'Model':<26}{'Preproc':>10}{'Acc':>9}{'BalAcc':>9}{'MacroP':>9}{'MacroR':>9}{'MacroF1':>9}{'WtdF1':>9}{'HealthyR':>10}")
    print("-" * 118)
    for row in comparison_rows:
        print(
            f"{row['model']:<26}{row['preprocessing']:>10}{row['test_accuracy']:>9.4f}"
            f"{row['test_balanced_accuracy']:>9.4f}{row['test_macro_precision']:>9.4f}"
            f"{row['test_macro_recall']:>9.4f}{row['test_macro_f1']:>9.4f}"
            f"{row['test_weighted_f1']:>9.4f}{row['test_healthy_recall']:>10.4f}"
        )
    print("=" * 118)

    print("\nPer-class recall (test):")
    header = "".join(f"{name[:14]:>16}" for name in class_names)
    print(f"{'Model':<26}{header}")
    for name in ordered:
        metrics = tflite_metrics[name][primary[name]]
        row = "".join(
            f"{metrics['per_class'][class_name]['recall']:>16.4f}" for class_name in class_names
        )
        print(f"{name:<26}{row}")

    print("\nCross-preprocessing sanity check (accuracy):")
    for name in ordered:
        parts = [
            f"{mode}={tflite_metrics[name][mode]['accuracy']:.4f}" for mode in ctm.PREPROCESSING_MODES
        ]
        print(f"  {name:<26}" + "  ".join(parts))

    write_final_report(
        result_dir, comparison_rows, arm_results, tflite_metrics, primary, class_names,
        summary, selected_arm,
    )
    print(f"\nArtifacts: {artifact_dir}")
    print(f"Reports:   {result_dir}")


def write_final_report(
    result_dir: Path,
    comparison_rows: list[dict],
    arm_results: dict[str, dict],
    tflite_metrics: dict,
    primary: dict,
    class_names: list[str],
    split: dict,
    selected_arm: str,
) -> None:
    lines = [
        "# MobileNetV2 v2 image-classifier experiment",
        "",
        "Isolated experiment. No production file, model artifact, backend file or Flutter",
        "file was modified; everything is written under `experiments/image_model_v2/`.",
        "",
        "## Split (project's existing stratified split, RANDOM_STATE=42)",
        "",
        f"- train: {split['train']['total']} -- {split['train']['per_class']}",
        f"- validation: {split['validation']['total']} -- {split['validation']['per_class']}",
        f"- test (held out): {split['test']['total']} -- {split['test']['per_class']}",
        "",
        f"Class index order (fitted `LabelEncoder`): {class_names}",
        "",
        "## Test-set comparison (TFLite interpreters, identical 429-image split)",
        "",
        "| Model | Preprocessing | Class weighting | Accuracy | Balanced acc | Macro P | Macro R | Macro F1 | Weighted F1 | Healthy recall |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for row in comparison_rows:
        lines.append(
            f"| {row['model']} | {row['preprocessing']} | {row['class_weighting']} | "
            f"{row['test_accuracy']:.4f} | {row['test_balanced_accuracy']:.4f} | "
            f"{row['test_macro_precision']:.4f} | {row['test_macro_recall']:.4f} | "
            f"{row['test_macro_f1']:.4f} | {row['test_weighted_f1']:.4f} | "
            f"{row['test_healthy_recall']:.4f} |"
        )

    lines += ["", "## Per-class recall (test)", "", "| Model | " + " | ".join(class_names) + " |", "|---|" + "---|" * len(class_names)]
    for name in primary:
        metrics = tflite_metrics[name][primary[name]]
        cells = " | ".join(f"{metrics['per_class'][c]['recall']:.4f}" for c in class_names)
        lines.append(f"| {name} | {cells} |")

    lines += ["", "## Confusion matrices (test)", "", "Order: " + ", ".join(class_names), ""]
    for name in primary:
        metrics = tflite_metrics[name][primary[name]]
        lines.append(f"**{name}** (acc {metrics['accuracy']:.4f}, macro F1 {metrics['macro']['f1']:.4f})")
        lines.append("")
        lines.append("```")
        lines.append(str(np.array(metrics["confusion_matrix"])))
        lines.append("```")
        lines.append("")

    lines += ["## Arm selection (validation only)", ""]
    for arm_name, result in arm_results.items():
        lines.append(
            f"- `{arm_name}` (alpha={result['alpha']}): val macro F1 "
            f"{result['validation_metrics']['macro']['f1']:.4f}, val balanced acc "
            f"{result['validation_metrics']['balanced_accuracy']:.4f}, val healthy recall "
            f"{result['validation_metrics']['healthy_recall']:.4f} -- {result['selection_note']}"
        )
    lines += [
        "",
        f"Selected arm by the predefined rule (validation macro F1, healthy-recall floor): **{selected_arm}**.",
        "",
        "## Limitations",
        "",
        "- The 4-class target (`multiclass_label`) is an anthropometric label definition, not an",
        "  independent clinical diagnosis, and the class `stunted` has only 12 held-out images. Its",
        "  recall is dominated by small-sample noise and cannot be reliably improved with this data.",
        "- The test split has been inspected in earlier turns; treat these numbers as a fixed",
        "  benchmark rather than a fresh unbiased estimate.",
        "- Class weighting changes the decision threshold behaviour, not the separability of the",
        "  features, so accuracy and macro F1 trade off directly.",
        "",
        "## Files",
        "",
        "- `results/model_comparison.csv`, `results/per_class_metrics.csv`",
        "- `results/confusion_matrices/*.txt`, `results/tflite_evaluation.json`",
        "- `artifacts/split_indices.json` (cached split), `artifacts/<arm>/` (keras + TFLite models)",
        "",
    ]
    (result_dir / "final_report.md").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    main()
