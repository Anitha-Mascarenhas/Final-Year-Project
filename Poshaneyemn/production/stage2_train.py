"""Stage 2: production training from cached image embeddings (fast, rerunnable)."""

from __future__ import annotations

import json
import os
from pathlib import Path

import joblib
import numpy as np
import pandas as pd

# Avoid the GPU plugin init hang observed on this machine.
os.environ.setdefault("CUDA_VISIBLE_DEVICES", "-1")
os.environ.setdefault("TF_CPP_MIN_LOG_LEVEL", "3")

from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)

from .config import (
    ANTHROVISION_FRONTAL1_DIR,
    ARTIFACT_DIR,
    CLASS_NAMES,
    IMAGE_TFLITE_FILENAME,
    LABEL_MAP_JSON,
    MANIFEST_JSON,
    PREPROCESSOR_JSON,
    RESULTS_DIR,
    SEGMENTATION_FEATURE_COLUMNS,
    SEG_FEAT_TRAIN_CSV,
    SVM_FILENAME,
)
from .dataset import build_dataset
from .fusion import fit_production_svm, group_slice
from .image_branch import export_image_extractor_tflite
from .preprocessing import HybridPreprocessor
from .train_production import ARM_NAMES, evaluate


def main() -> None:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print("POSHANEYE PRODUCTION HYBRID TRAINING (stage 2, cached embeddings)")
    print("=" * 70)

    ds = build_dataset()
    ds.assert_disjoint_splits()
    train_df, val_df, test_df = ds.split("train"), ds.split("validation"), ds.split("test")
    print(f"children: train={len(train_df)} val={len(val_df)} test={len(test_df)} (0 overlap verified)")

    image_train = np.load(ARTIFACT_DIR / "image_embeddings_train.npy")
    image_val = np.load(ARTIFACT_DIR / "image_embeddings_validation.npy")
    image_test = np.load(ARTIFACT_DIR / "image_embeddings_test.npy")

    # Fill any segmentation gaps in the train split from the runtime extractor.
    need = train_df[SEGMENTATION_FEATURE_COLUMNS].isna().any(axis=1)
    if int(need.sum()) > 0:
        print(f"[seg] running DeepLabV3+ runtime extractor for {int(need.sum())} train rows...")
        import cv2

        from .runtime_features import SegmentationFeatureExtractor, make_holistic

        seg_extractor = SegmentationFeatureExtractor()
        holistic = make_holistic()
        for idx, row in train_df[need].iterrows():
            path = ANTHROVISION_FRONTAL1_DIR / Path(str(row["f1_filename"])).name
            img = cv2.imread(str(path))
            if img is None:
                continue
            sw_raw = row["shoulder_width"]
            sw = float(sw_raw) if pd.notna(sw_raw) else None
            if sw is None:
                cv_feats = _quick_cv(img, holistic)
                sw = cv_feats.get("shoulder_width")
                sw = float(sw) if sw is not None and np.isfinite(sw) else None
            feats = seg_extractor.extract_features(img[:, :, ::-1], sw)
            for col in SEGMENTATION_FEATURE_COLUMNS:
                train_df.loc[idx, col] = feats[col]
        train_df.to_csv(RESULTS_DIR / SEG_FEAT_TRAIN_CSV, index=False)

    print("[pre] fitting preprocessing strictly on the train split...")
    pre = HybridPreprocessor()
    pre.fit(image_train, train_df, train_df, train_df)
    pre.save(ARTIFACT_DIR / PREPROCESSOR_JSON)

    X_train = pre.transform(image_train, train_df, train_df, train_df)
    X_test = pre.transform(image_test, test_df, test_df, test_df)
    slices = group_slice(pre.image_dim)
    print(f"fused dim={X_train.shape[1]} slices={ {k: [s.start, s.stop] for k, s in slices.items()} }")

    y_train = train_df["label"].to_numpy()
    y_test = test_df["label"].to_numpy()

    arms = {
        "anthro": ("anthropometric",),
        "cv": ("cv",),
        "seg": ("segmentation",),
        "image": ("image",),
        "anthro+cv": ("anthropometric", "cv"),
        "anthro+cv+seg": ("anthropometric", "cv", "segmentation"),
        "full": ("image", "cv", "segmentation", "anthropometric"),
    }
    results, cms = {}, {}
    full_artifacts = {}
    for arm_key, groups in arms.items():
        cols = np.concatenate([np.arange(slices[g].start, slices[g].stop) for g in groups])
        X_tr, X_te = X_train[:, cols], X_test[:, cols]
        svc, portable = fit_production_svm(X_tr, y_train)
        pred = svc.predict(X_te)
        results[arm_key] = evaluate(y_test, pred)
        results[arm_key]["arm"] = ARM_NAMES[arm_key]
        cms[ARM_NAMES[arm_key]] = results[arm_key]["confusion_matrix"]
        print(f"SVM  {ARM_NAMES[arm_key]:45s} acc={results[arm_key]['accuracy']:.4f} "
              f"bacc={results[arm_key]['balanced_accuracy']:.4f} macroF1={results[arm_key]['macro_f1']:.4f}")
        rf = RandomForestClassifier(n_estimators=150, class_weight="balanced", random_state=42)
        rf.fit(X_tr, y_train)
        rf_results = evaluate(y_test, rf.predict(X_te))
        results[f"{arm_key}__rf"] = rf_results | {"arm": ARM_NAMES[arm_key] + " [RF reference]"}
        print(f"RF   {ARM_NAMES[arm_key]:45s} acc={rf_results['accuracy']:.4f} "
              f"bacc={rf_results['balanced_accuracy']:.4f} macroF1={rf_results['macro_f1']:.4f}")
        if arm_key == "full":
            full_artifacts = {"svc": svc, "portable": portable}

    svc = full_artifacts["svc"]
    portable = full_artifacts["portable"]
    joblib.dump(svc, ARTIFACT_DIR / SVM_FILENAME)
    portable.save(ARTIFACT_DIR / SVM_FILENAME.replace(".joblib", "_portable.json"))
    with open(ARTIFACT_DIR / LABEL_MAP_JSON, "w", encoding="utf-8") as fh:
        json.dump({i: name for i, name in enumerate(CLASS_NAMES)}, fh, indent=2)
    export_image_extractor_tflite(ARTIFACT_DIR / IMAGE_TFLITE_FILENAME)

    manifest = {
        "model_family": "SVC(kernel='rbf', C=1.0, class_weight='balanced') [existing repo classifier]",
        "fusion_order": ["image (MobileNetV2 128-d embedding)", "cv (MediaPipe 21 features)",
                         "segmentation (DeepLabV3+ 11 features)", "anthropometric (8 features)"],
        "total_feature_dim": int(X_train.shape[1]),
        "group_slices": {k: [s.start, s.stop] for k, s in slices.items()},
        "classifier_artifacts": [SVM_FILENAME, SVM_FILENAME.replace(".joblib", "_portable.json")],
        "preprocessor": PREPROCESSOR_JSON,
        "image_feature_extractor": {
            "source_model": "models/image_best.h5 (legacy, read-only)",
            "layer_used": "image_dense (penultimate Dense(128, relu))",
            "legacy_head_discarded": "Dense(4, softmax) NOT used",
            "tflite": IMAGE_TFLITE_FILENAME,
            "input_shape": [1, 224, 224, 3],
            "output_shape": [1, 128],
        },
        "splits": {"train_children": int(len(train_df)), "validation_children": int(len(val_df)),
                   "test_children": int(len(test_df)), "child_level": True,
                   "frozen_from": "experiments/cv_multimodal_baseline/split_indices.json"},
        "label_map": {i: name for i, name in enumerate(CLASS_NAMES)},
    }
    with open(ARTIFACT_DIR / MANIFEST_JSON, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    rows = []
    for arm_key, metrics in results.items():
        row = {"arm": metrics["arm"],
               "model": "RandomForest_Balanced" if arm_key.endswith("__rf") else "SVM_RBF_Balanced"}
        row.update({k: v for k, v in metrics.items() if k not in {"confusion_matrix", "arm"}})
        rows.append(row)
    metrics_df = pd.DataFrame(rows)
    metrics_df.to_csv(RESULTS_DIR / "modality_comparison.csv", index=False)
    with open(RESULTS_DIR / "confusion_matrices.json", "w", encoding="utf-8") as fh:
        json.dump(cms, fh, indent=2)

    svm_rows = metrics_df[metrics_df["model"] == "SVM_RBF_Balanced"]

    def _md(df: pd.DataFrame, cols: list[str]) -> str:
        """Markdown table without the optional tabulate dependency."""
        sub = df[cols]
        header = "| " + " | ".join(cols) + " |"
        sep = "|" + "|".join(["---"] * len(cols)) + "|"
        rows = ["| " + " | ".join(str(v) for v in r) + " |" for r in sub.itertuples(index=False)]
        return "\n".join([header, sep] + rows)

    lines = [
        "# PoshanEye Production Hybrid Pipeline - Training & Comparison Report",
        "",
        "All arms evaluated on the SAME frozen child-level test split (321 children, zero overlap with train/val).",
        "",
        "## Arms (SVM_RBF_Balanced, the existing repo classifier family)",
        "",
        _md(svm_rows, ["arm", "accuracy", "macro_precision", "macro_recall", "macro_f1", "weighted_f1", "balanced_accuracy"]),
        "",
        "## RandomForest reference",
        "",
        _md(metrics_df[metrics_df["model"] == "RandomForest_Balanced"], ["arm", "accuracy", "macro_f1", "balanced_accuracy"]),
        "",
        "## Confusion matrices (SVM, rows=true, cols=pred; classes: healthy / underweight / stunted / stunted and underweight)",
        "",
    ]
    for arm_name, cm in cms.items():
        lines += [f"### {arm_name}", "", "```", str(np.array(cm)), "```", ""]
    (RESULTS_DIR / "report.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"\nsaved: {RESULTS_DIR / 'modality_comparison.csv'}")
    print("stage 2 complete.")


def _quick_cv(image_bgr, holistic):
    from .runtime_features import extract_cv_features

    return extract_cv_features(image_bgr, holistic)


if __name__ == "__main__":
    main()
