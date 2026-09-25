"""Compare the production TFLite image model against the class-balanced experiment.

This script is READ-ONLY with respect to model artifacts: it loads
``best_model.tflite`` files and never writes, moves, or overwrites them. The only
files it creates are reports under the requested ``--output-dir``.

It also traces and reports the numeric -> class-name mapping actually used by the
models, because ``outputs/*/label_map.json`` (built from ``config.CLASS_NAMES``
order) and the sklearn ``LabelEncoder`` order disagree.

Usage (from the Poshaneyemn directory):

    ../.venv/Scripts/python.exe scripts/compare_tflite_models.py

Optional flags:

    --output-dir outputs/class_balanced_experiment
    --old-model models/best_model.tflite
    --new-model models/class_balanced_experiment/best_model.tflite
    --test-frac 1.0          # fraction of the test split to evaluate (debugging)

Exit code is 0 even when the new model is worse than the old one; this script
reports, it does not gate.
"""

from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.append(str(PROJECT_ROOT / "src"))

import numpy as np  # noqa: E402
import tensorflow as tf  # noqa: E402
from sklearn.metrics import (  # noqa: E402
    accuracy_score,
    classification_report,
    confusion_matrix,
)

from config import (  # noqa: E402
    CLASS_NAMES,
    IMAGE_SIZE,
    MODEL_DIR,
    OUTPUT_DIR,
    TFLITE_FILENAME,
)
from pipeline import Pipeline  # noqa: E402
from utils import ensure_dir, save_json  # noqa: E402

# Two preprocessing conventions exist in this project's history:
#   "mobilenet" : keras.applications.mobilenet_v2.preprocess_input  -> [-1, 1]
#                 (used by the class-balanced experiment, tf_data.preprocess_image)
#   "div255"    : raw / 255.0                                       -> [0, 1]
#                 (used by the original production training run)
PREPROCESSING_MODES = ("mobilenet", "div255")


# --------------------------------------------------------------------------- #
# data
# --------------------------------------------------------------------------- #
def build_test_split(verbose: bool = False):
    """Rebuild the exact stratified train/val/test split used by training."""
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        pipeline = Pipeline(model_dir=MODEL_DIR)
        train_df, val_df, test_df = pipeline.build_datasets()
    if verbose:
        print(buffer.getvalue())

    encoder = pipeline.preprocessor.encoder
    encoder_classes = [str(name) for name in encoder.classes_]
    return train_df, val_df, test_df, encoder_classes


def decode_images(paths) -> np.ndarray:
    """Decode + resize every image once, exactly like tf_data.preprocess_image."""
    decoded = []
    for image_path in paths:
        raw = tf.io.read_file(image_path)
        image = tf.image.decode_image(raw, channels=3, expand_animations=False)
        image = tf.image.resize(image, IMAGE_SIZE)
        decoded.append(image.numpy().astype(np.uint8))
    return np.stack(decoded)


def normalize(batch_uint8: np.ndarray, mode: str) -> np.ndarray:
    """Apply one of the two project preprocessing conventions to uint8 pixels."""
    pixels = batch_uint8.astype(np.float32)
    if mode == "mobilenet":
        # Equivalent to keras.applications.mobilenet_v2.preprocess_input.
        return pixels / 127.5 - 1.0
    if mode == "div255":
        return pixels / 255.0
    raise ValueError(f"Unknown preprocessing mode: {mode!r}")


# --------------------------------------------------------------------------- #
# inference
# --------------------------------------------------------------------------- #
def load_interpreters(model_paths: dict[str, Path]) -> dict[str, tf.lite.Interpreter]:
    interpreters: dict[str, tf.lite.Interpreter] = {}
    for name, path in model_paths.items():
        if not path.exists():
            raise FileNotFoundError(f"{name} model not found: {path}")
        interpreter = tf.lite.Interpreter(model_path=str(path))
        interpreter.allocate_tensors()
        input_detail = interpreter.get_input_details()[0]
        output_detail = interpreter.get_output_details()[0]
        print(
            f"[TFLite] {name}: {path.name} "
            f"input {input_detail['shape'].tolist()} {np.dtype(input_detail['dtype']).name} | "
            f"output {output_detail['shape'].tolist()} {np.dtype(output_detail['dtype']).name}"
        )
        interpreters[name] = interpreter
    return interpreters


def predict(interpreter: tf.lite.Interpreter, batch_uint8: np.ndarray, mode: str) -> np.ndarray:
    """Run the interpreter per-image and return an (N, num_classes) probability matrix."""
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    input_dtype = input_detail["dtype"]
    input_index = input_detail["index"]
    output_index = output_detail["index"]

    expected_h, expected_w = int(input_detail["shape"][1]), int(input_detail["shape"][2])
    if (expected_h, expected_w) != tuple(IMAGE_SIZE):
        raise ValueError(
            f"Model expects {(expected_h, expected_w)} but IMAGE_SIZE is {IMAGE_SIZE}."
        )

    probabilities = np.zeros((len(batch_uint8), output_detail["shape"][-1]), dtype=np.float32)
    for index in range(len(batch_uint8)):
        sample = normalize(batch_uint8[index : index + 1], mode)
        if input_dtype != np.float32:
            scale, zero_point = input_detail["quantization"]
            sample = (sample / scale + zero_point).round()
        interpreter.set_tensor(input_index, sample.astype(input_dtype))
        interpreter.invoke()
        output = interpreter.get_tensor(output_index)
        probabilities[index] = np.asarray(output, dtype=np.float32).reshape(-1)
    return probabilities


# --------------------------------------------------------------------------- #
# metrics
# --------------------------------------------------------------------------- #
def compute_metrics(y_true: np.ndarray, probabilities: np.ndarray, class_names: list[str]) -> dict:
    labels = list(range(len(class_names)))
    y_pred = np.argmax(probabilities, axis=1)

    report = classification_report(
        y_true,
        y_pred,
        labels=labels,
        target_names=class_names,
        output_dict=True,
        zero_division=0,
    )

    per_class: dict[str, dict[str, float]] = {}
    for label_index, class_name in zip(labels, class_names):
        entry = report[class_name]
        per_class[class_name] = {
            "index": label_index,
            "precision": float(entry["precision"]),
            "recall": float(entry["recall"]),
            "f1": float(entry["f1-score"]),
            "support": int(entry["support"]),
        }

    macro = report["macro avg"]
    weighted = report["weighted avg"]
    clipped = np.clip(probabilities, 1e-9, 1.0)
    prediction_distribution = np.bincount(y_pred, minlength=len(class_names)).tolist()
    return {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "mean_top_probability": float(probabilities.max(axis=1).mean()),
        "mean_entropy_nats": float(-(clipped * np.log(clipped)).sum(axis=1).mean()),
        "predicted_distribution": prediction_distribution,
        "per_class": per_class,
        "macro": {
            "precision": float(macro["precision"]),
            "recall": float(macro["recall"]),
            "f1": float(macro["f1-score"]),
        },
        "weighted": {
            "precision": float(weighted["precision"]),
            "recall": float(weighted["recall"]),
            "f1": float(weighted["f1-score"]),
        },
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=labels).tolist(),
        "classification_report_text": classification_report(
            y_true,
            y_pred,
            labels=labels,
            target_names=class_names,
            zero_division=0,
        ),
        "correct": int((y_pred == y_true).sum()),
        "total": int(len(y_true)),
    }


# --------------------------------------------------------------------------- #
# reporting
# --------------------------------------------------------------------------- #
def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def print_comparison_table(old: dict, new: dict) -> None:
    rows = [
        ("Accuracy", old["accuracy"], new["accuracy"]),
        ("Mean top probability", old["mean_top_probability"], new["mean_top_probability"]),
        ("Macro Precision", old["macro"]["precision"], new["macro"]["precision"]),
        ("Macro Recall", old["macro"]["recall"], new["macro"]["recall"]),
        ("Macro F1", old["macro"]["f1"], new["macro"]["f1"]),
        ("Weighted Precision", old["weighted"]["precision"], new["weighted"]["precision"]),
        ("Weighted Recall", old["weighted"]["recall"], new["weighted"]["recall"]),
        ("Weighted F1", old["weighted"]["f1"], new["weighted"]["f1"]),
    ]
    print("\n" + "=" * 62)
    print(f"{'Metric':<24}{'Old':>12}{'New':>12}{'Delta':>12}")
    print("-" * 62)
    for name, old_value, new_value in rows:
        marker = "  " if name == "Accuracy" else ""
        print(f"{name:<24}{old_value:>12.4f}{new_value:>12.4f}{new_value - old_value:>+12.4f}{marker}")
    print("=" * 62)


def print_per_class(old: dict, new: dict) -> None:
    print(f"\n{'Class':<26}{'Metric':>10}{'Old':>10}{'New':>10}")
    print("-" * 56)
    for class_name in old["per_class"]:
        old_class = old["per_class"][class_name]
        new_class = new["per_class"][class_name]
        print(f"{class_name + ' (idx ' + str(old_class['index']) + ')':<26}{'support':>10}{old_class['support']:>10d}{new_class['support']:>10d}")
        for metric in ("precision", "recall", "f1"):
            print(f"{'':<26}{metric:>10}{old_class[metric]:>10.4f}{new_class[metric]:>10.4f}")
        print()


def print_confusion(label: str, metrics: dict, class_names: list[str]) -> None:
    print(f"\n{label} confusion matrix (rows = true, cols = predicted)")
    header = "".join(f"{name[:10]:>12}" for name in class_names)
    print(f"{'':<26}{header}")
    for name, row in zip(class_names, metrics["confusion_matrix"]):
        print(f"{name:<26}" + "".join(f"{value:>12d}" for value in row))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--old-model", type=Path, default=MODEL_DIR / TFLITE_FILENAME)
    parser.add_argument(
        "--new-model",
        type=Path,
        default=MODEL_DIR / "class_balanced_experiment" / TFLITE_FILENAME,
    )
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR / "class_balanced_experiment")
    parser.add_argument("--test-frac", type=float, default=1.0, help="Fraction of the test split to evaluate.")
    parser.add_argument("--verbose", action="store_true", help="Show full pipeline debug output.")
    args = parser.parse_args()

    output_dir = ensure_dir(args.output_dir)

    # ---- split + true label mapping -------------------------------------- #
    _, _, test_df, encoder_classes = build_test_split(verbose=args.verbose)
    class_names = encoder_classes  # ground truth: sklearn LabelEncoder order

    if args.test_frac < 1.0:
        test_df = test_df.sample(frac=args.test_frac, random_state=42).reset_index(drop=True)

    counts = test_df["label"].value_counts().sort_index().to_dict()
    print("\n=== TRUE NUMERIC -> CLASS MAPPING (sklearn LabelEncoder) ===")
    for index, name in enumerate(class_names):
        print(f"  {index} -> {name}")
    print("\n=== config.CLASS_NAMES (positional interpretation used by label_map.json) ===")
    for index, name in enumerate(CLASS_NAMES):
        flag = "" if name == class_names[index] else "   <-- MISMATCH"
        print(f"  {index} -> {name}{flag}")
    print("\n=== Held-out test split ===")
    print(f"  total: {len(test_df)}")
    for index, name in enumerate(class_names):
        print(f"  {index} {name}: {counts.get(index, 0)}")

    paths = test_df["image_path"].astype(str).tolist()
    y_true = test_df["label"].to_numpy(dtype=np.int64)

    print("\nDecoding and resizing test images once ...")
    batch_uint8 = decode_images(paths)
    print(f"  decoded tensor: {batch_uint8.shape} {batch_uint8.dtype}")

    # ---- inference -------------------------------------------------------- #
    model_paths = {"old": args.old_model, "new": args.new_model}
    interpreters = load_interpreters(model_paths)

    results: dict[str, dict[str, dict]] = {"old": {}, "new": {}}
    for model_name, interpreter in interpreters.items():
        for mode in PREPROCESSING_MODES:
            print(f"  predicting: {model_name} / {mode} ...")
            probabilities = predict(interpreter, batch_uint8, mode)
            results[model_name][mode] = compute_metrics(y_true, probabilities, class_names)

    # ---- choose each model's own training convention ---------------------- #
    # The production model predates the preprocessing fix, so its native
    # convention is div255; the experiment was trained with mobilenet.
    primary_mode = {"old": "div255", "new": "mobilenet"}
    old_primary = results["old"][primary_mode["old"]]
    new_primary = results["new"][primary_mode["new"]]

    print_comparison_table(old_primary, new_primary)
    print(
        f"\n(primary convention: old = {primary_mode['old']}, new = {primary_mode['new']}; "
        "cross-convention results are included in the JSON and below)"
    )

    print_per_class(old_primary, new_primary)
    print_confusion("OLD", old_primary, class_names)
    print_confusion("NEW", new_primary, class_names)

    print("\nCross-convention accuracy (sanity check of preprocessing assumption):")
    for model_name in ("old", "new"):
        for mode in PREPROCESSING_MODES:
            metrics = results[model_name][mode]
            print(f"  {model_name:<4} {mode:<10} accuracy={metrics['accuracy']:.4f} macro_f1={metrics['macro']['f1']:.4f}")

    # ---- persist reports -------------------------------------------------- #
    report_path = output_dir / "tflite_comparison.json"
    save_json(
        report_path,
        {
            "generated_at": datetime.now(timezone.utc).isoformat(),
            "primary_preprocessing": primary_mode,
            "test_set": {
                "total": int(len(test_df)),
                "class_counts": {class_names[i]: int(counts.get(i, 0)) for i in range(len(class_names))},
                "source": "DataPreprocessor.split_dataset (stratified, RANDOM_STATE=42)",
            },
            "label_mapping": {
                "encoder_classes": class_names,
                "config_class_names": list(CLASS_NAMES),
                "label_map_json_artifact": {str(i): name for i, name in enumerate(CLASS_NAMES)},
                "consistent": list(CLASS_NAMES) == class_names,
                "note": (
                    "Model output indices follow the sklearn LabelEncoder order. "
                    "outputs/*/label_map.json is written from config.CLASS_NAMES order, "
                    "so index 1/2/3 names in that artifact do not match the model. "
                    "The FastAPI backend builds class names from label_encoder.pkl "
                    "(encoder order), so served predictions are unaffected."
                ),
            },
            "models": {
                name: {
                    "path": str(path),
                    "sha256": sha256(path),
                    "bytes": path.stat().st_size,
                    "primary_preprocessing": primary_mode[name],
                    "metrics": results[name],
                }
                for name, path in model_paths.items()
            },
            "comparison": {
                "old": old_primary,
                "new": new_primary,
                "delta": {
                    "accuracy": new_primary["accuracy"] - old_primary["accuracy"],
                    "macro_f1": new_primary["macro"]["f1"] - old_primary["macro"]["f1"],
                    "weighted_f1": new_primary["weighted"]["f1"] - old_primary["weighted"]["f1"],
                    "per_class_f1": {
                        class_name: new_primary["per_class"][class_name]["f1"]
                        - old_primary["per_class"][class_name]["f1"]
                        for class_name in class_names
                    },
                },
            },
        },
    )
    print(f"\nWrote comparison JSON: {report_path}")

    for model_name, metrics in (("old", old_primary), ("new", new_primary)):
        report_file = output_dir / f"tflite_classification_report_{model_name}.txt"
        report_file.write_text(
            f"{model_name.upper()} model ({model_paths[model_name]})\n"
            f"preprocessing: {primary_mode[model_name]}\n"
            f"accuracy: {metrics['accuracy']:.4f}  macro_f1: {metrics['macro']['f1']:.4f}\n\n"
            f"{metrics['classification_report_text']}\n"
            f"confusion matrix (rows=true, cols=pred):\n{np.array(metrics['confusion_matrix'])}\n"
            f"class index order: {class_names}\n",
            encoding="utf-8",
        )
        print(f"Wrote classification report: {report_file}")

    _save_confusion_figures(output_dir, class_names, old_primary, new_primary)


def _save_confusion_figures(output_dir: Path, class_names: list[str], old: dict, new: dict) -> None:
    try:
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except Exception as exc:  # pragma: no cover - optional dependency
        print(f"Confusion matrix figures skipped: {exc}")
        return

    fig, axes = plt.subplots(1, 2, figsize=(12, 5))
    for ax, (label, metrics) in zip(axes, (("Old (production)", old), ("New (class-balanced)", new))):
        matrix = np.array(metrics["confusion_matrix"])
        image = ax.imshow(matrix, interpolation="nearest", cmap="Blues")
        ax.figure.colorbar(image, ax=ax)
        ax.set(
            xticks=np.arange(len(class_names)),
            yticks=np.arange(len(class_names)),
            xticklabels=class_names,
            yticklabels=class_names,
            ylabel="True label",
            xlabel="Predicted label",
            title=f"{label}\nacc={metrics['accuracy']:.4f} macroF1={metrics['macro']['f1']:.4f}",
        )
        plt.setp(ax.get_xticklabels(), rotation=45, ha="right")
        threshold = matrix.max() / 2.0 if matrix.max() else 0.0
        for i in range(matrix.shape[0]):
            for j in range(matrix.shape[1]):
                ax.text(
                    j,
                    i,
                    int(matrix[i, j]),
                    ha="center",
                    va="center",
                    color="white" if matrix[i, j] > threshold else "black",
                )
    figure_path = output_dir / "tflite_confusion_matrices.png"
    fig.tight_layout()
    fig.savefig(figure_path, dpi=300)
    plt.close(fig)
    print(f"Wrote confusion matrix figure: {figure_path}")


if __name__ == "__main__":
    main()
