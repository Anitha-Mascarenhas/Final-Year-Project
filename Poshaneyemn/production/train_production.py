"""Production training entry point.

Trains the fused-features RBF-SVM (the existing repo classifier family) on the frozen
child-level splits and evaluates 7 modality arms on the SAME held-out test children:
  1. anthropometric-only
  2. cv-only
  3. segmentation-only
  4. image-only (MobileNetV2 128-d embedding, NOT the legacy 4-class head)
  5. anthropometric + cv
  6. anthropometric + cv + segmentation
  7. FULL: image + cv + segmentation + anthropometric  <- production model

Outputs (all new files, legacy best_model.* untouched):
  production/artifacts/hybrid_production_svm.joblib
  production/artifacts/hybrid_production_svm_portable.json
  production/artifacts/hybrid_production_preprocessor.json
  production/artifacts/hybrid_production_label_map.json
  production/artifacts/hybrid_production_image_feature_extractor.tflite
  production/artifacts/hybrid_production_manifest.json
  production/results/  (metrics, comparison table, report)
"""

from __future__ import annotations

import json
import time
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
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
    ANTHROPOMETRIC_COLUMNS,
    ARTIFACT_DIR,
    CLASS_NAMES,
    CV_FEATURE_COLUMNS,
    IMAGE_FEATURE_DIM,
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
from .fusion import PortableSVM, fit_production_svm, group_slice
from .image_branch import export_image_extractor_tflite, load_image_feature_extractor
from .preprocessing import GROUPS, HybridPreprocessor
from .runtime_features import SegmentationFeatureExtractor

ARM_NAMES = {
    "anthro": "1_anthropometric_only",
    "cv": "2_cv_only",
    "seg": "3_segmentation_only",
    "image": "4_image_only_features",
    "anthro+cv": "5_anthro_plus_cv",
    "anthro+cv+seg": "6_anthro_plus_cv_plus_seg",
    "full": "7_full_image_plus_cv_plus_seg_plus_anthro",
}


# ---------------------------------------------------------------------------
# Image embedding cache (MobileNetV2 feature extractor over frontal1 images)
# ---------------------------------------------------------------------------
def compute_image_embeddings(df: pd.DataFrame, extractor, log_every: int = 200) -> np.ndarray:
    import tensorflow as tf

    from .config import ANTHROVISION_FRONTAL1_DIR

    embeddings = np.zeros((len(df), IMAGE_FEATURE_DIM), dtype=np.float32)
    batch_paths, batch_idx = [], []

    def flush(paths, idxs):
        if not paths:
            return
        from .image_branch import preprocess_for_extractor

        arrs = []
        for p in paths:
            img = tf.io.read_file(p)
            img = tf.image.decode_image(img, channels=3, expand_animations=False)
            arrs.append(preprocess_for_extractor(img.numpy()))
        emb = extractor.predict(np.stack(arrs), verbose=0)
        embeddings[idxs] = np.asarray(emb, dtype=np.float32)

    t0 = time.time()
    for i, (_, row) in enumerate(df.iterrows()):
        fname = Path(str(row["f1_filename"])).name
        path = ANTHROVISION_FRONTAL1_DIR / fname
        if not path.exists():
            continue  # stays zeros -> median-imputed by the preprocessor
        batch_paths.append(str(path))
        batch_idx.append(i)
        if len(batch_paths) >= 32:
            flush(batch_paths, batch_idx)
            batch_paths, batch_idx = [], []
        if (i + 1) % log_every == 0:
            print(f"  [image-embed] {i + 1}/{len(df)} ({time.time() - t0:.0f}s)")
    flush(batch_paths, batch_idx)
    print(f"  [image-embed] done in {time.time() - t0:.0f}s")
    return embeddings


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------
def evaluate(y_true, y_pred) -> dict:
    return {
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
        "balanced_accuracy": round(float(balanced_accuracy_score(y_true, y_pred)), 4),
        "macro_precision": round(float(precision_score(y_true, y_pred, average="macro", zero_division=0)), 4),
        "macro_recall": round(float(recall_score(y_true, y_pred, average="macro", zero_division=0)), 4),
        "macro_f1": round(float(f1_score(y_true, y_pred, average="macro", zero_division=0)), 4),
        "weighted_f1": round(float(f1_score(y_true, y_pred, average="weighted", zero_division=0)), 4),
        "confusion_matrix": confusion_matrix(y_true, y_pred, labels=list(range(len(CLASS_NAMES)))).tolist(),
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> None:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print("POSHANEYE PRODUCTION HYBRID PIPELINE TRAINING")
    print("=" * 70)

    # 1. dataset (frozen child-level splits)
    print("\n[1/6] Building child-level dataset (frozen splits)...")
    ds = build_dataset()
    ds.assert_disjoint_splits()
    train_df, val_df, test_df = ds.split("train"), ds.split("validation"), ds.split("test")
    print(f"  children: train={len(train_df)} val={len(val_df)} test={len(test_df)} (0 overlap verified)")
    all_child_ids = set(ds.df["child_id"].astype(int))
    assert all_child_ids.isdisjoint(set(map(int, ds.test_child_ids)) - all_child_ids)

    # 2. image embeddings for ALL rows (train stats later use train rows only)
    print("\n[2/6] Extracting MobileNetV2 image embeddings (128-d, frozen backbone)...")
    extractor = load_image_feature_extractor()
    image_train = compute_image_embeddings(train_df, extractor)
    image_val = compute_image_embeddings(val_df, extractor)
    image_test = compute_image_embeddings(test_df, extractor)

    # 3. segmentation features for train rows missing them (CSV coverage < full set)
    print("\n[3/6] Ensuring segmentation features for every training row (DeepLabV3+)...")
    have_seg = train_df[SEGMENTATION_FEATURE_COLUMNS].notna().all(axis=1)
    missing = train_df[~have_seg]
    if len(missing) > 0:
        print(f"  extracting DeepLabV3+ features for {len(missing)} train rows without CSV coverage...")
        seg_extractor = SegmentationFeatureExtractor()
        from .runtime_features import make_holistic

        holistic = make_holistic()
        import cv2

        from .config import ANTHROVISION_FRONTAL1_DIR

        for idx, row in missing.iterrows():
            path = ANTHROVISION_FRONTAL1_DIR / Path(str(row["f1_filename"])).name
            img = cv2.imread(str(path))
            if img is None:
                continue
            sw = row["shoulder_width"]
            sw = float(sw) if pd.notna(sw) else None
            feats = seg_extractor.extract_features(img[:, :, ::-1], sw)
            for col in SEGMENTATION_FEATURE_COLUMNS:
                train_df.loc[idx, col] = feats[col]
        del seg_extractor
    train_df.to_csv(RESULTS_DIR / SEG_FEAT_TRAIN_CSV, index=False)

    # 4. fit preprocessing strictly on train split
    print("\n[4/6] Fitting preprocessing on the TRAIN split only...")
    pre = HybridPreprocessor()
    pre.fit(image_train, train_df, train_df, train_df)
    pre.save(ARTIFACT_DIR / PREPROCESSOR_JSON)

    X_train_full = pre.transform(image_train, train_df, train_df, train_df)
    X_val_full = pre.transform(image_val, val_df, val_df, val_df)
    X_test_full = pre.transform(image_test, test_df, test_df, test_df)
    slices = group_slice(pre.image_dim)
    print(f"  fused vector dim: {X_train_full.shape[1]} (slices: { {k: (s.start, s.stop) for k, s in slices.items()} })")

    y_train = train_df["label"].to_numpy()
    y_val = val_df["label"].to_numpy()
    y_test = test_df["label"].to_numpy()

    # 5. train + evaluate the 7 modality arms (same test children for every arm)
    print("\n[5/6] Training and evaluating 7 modality arms (SVM_RBF_Balanced)...")
    arms = {
        "anthro": ("anthropometric",),
        "cv": ("cv",),
        "seg": ("segmentation",),
        "image": ("image",),
        "anthro+cv": ("anthropometric", "cv"),
        "anthro+cv+seg": ("anthropometric", "cv", "segmentation"),
        "full": ("image", "cv", "segmentation", "anthropometric"),
    }
    results, cms, per_arm_artifacts = {}, {}, {}
    for arm_key, groups in arms.items():
        cols = np.hstack([np.arange(slices[g].start, slices[g].stop) for g in groups])
        X_tr, X_te = X_train_full[:, cols], X_test_full[:, cols]
        svc, portable = fit_production_svm(X_tr, y_train)
        y_pred = svc.predict(X_te)
        results[arm_key] = evaluate(y_test, y_pred)
        results[arm_key]["arm"] = ARM_NAMES[arm_key]
        cms[ARM_NAMES[arm_key]] = results[arm_key]["confusion_matrix"]
        print(f"  {ARM_NAMES[arm_key]:45s} acc={results[arm_key]['accuracy']:.4f} "
              f"bacc={results[arm_key]['balanced_accuracy']:.4f} macroF1={results[arm_key]['macro_f1']:.4f}")
        # RandomForest reference (existing repo comparison family), same split
        rf = RandomForestClassifier(n_estimators=150, class_weight="balanced", random_state=42)
        rf.fit(X_tr, y_train)
        rf_pred = rf.predict(X_te)
        results[f"{arm_key}__rf"] = evaluate(y_test, rf_pred)
        results[f"{arm_key}__rf"]["arm"] = ARM_NAMES[arm_key] + " [RF reference]"
        if arm_key == "full":
            per_arm_artifacts["svm"] = svc
            per_arm_artifacts["portable"] = portable

    # 6. persist production artifacts (FULL model only)
    print("\n[6/6] Saving production artifacts...")
    svc = per_arm_artifacts["svm"]
    portable = per_arm_artifacts["portable"]
    joblib.dump(svc, ARTIFACT_DIR / SVM_FILENAME)
    portable.save(ARTIFACT_DIR / (SVM_FILENAME.replace(".joblib", "_portable.json")))
    with open(ARTIFACT_DIR / LABEL_MAP_JSON, "w", encoding="utf-8") as fh:
        json.dump({i: name for i, name in enumerate(CLASS_NAMES)}, fh, indent=2)
    tflite_path = export_image_extractor_tflite(ARTIFACT_DIR / IMAGE_TFLITE_FILENAME)
    print(f"  saved {ARTIFACT_DIR / SVM_FILENAME}")
    print(f"  saved portable SVM JSON")
    print(f"  saved {tflite_path}")

    # manifest
    manifest = {
        "model_family": "SVC(kernel='rbf', C=1.0, class_weight='balanced') [existing repo classifier]",
        "fusion_order": ["image (MobileNetV2 128-d embedding)", "cv (MediaPipe 21 features)",
                         "segmentation (DeepLabV3+ 11 features)", "anthropometric (8 features)"],
        "total_feature_dim": int(X_train_full.shape[1]),
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
        "splits": {"train_children": len(train_df), "validation_children": len(val_df),
                   "test_children": len(test_df), "child_level": True,
                   "frozen_from": "experiments/cv_multimodal_baseline/split_indices.json"},
        "label_map": {i: name for i, name in enumerate(CLASS_NAMES)},
    }
    with open(ARTIFACT_DIR / MANIFEST_JSON, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    # results table + report
    rows = []
    for arm_key, metrics in results.items():
        row = {"arm": metrics["arm"], "model": "SVM_RBF_Balanced" if not arm_key.endswith("__rf") else "RandomForest_Balanced"}
        row.update({k: v for k, v in metrics.items() if k not in {"confusion_matrix", "arm"}})
        rows.append(row)
    metrics_df = pd.DataFrame(rows)
    metrics_df.to_csv(RESULTS_DIR / "modality_comparison.csv", index=False)
    with open(RESULTS_DIR / "confusion_matrices.json", "w", encoding="utf-8") as fh:
        json.dump(cms, fh, indent=2)

    svm_rows = metrics_df[~metrics_df["arm"].str.contains("RF reference")]
    lines = [
        "# PoshanEye Production Hybrid Pipeline - Training & Comparison Report",
        "",
        "All arms evaluated on the SAME frozen child-level test split (321 children, zero overlap with train/val).",
        "",
        "## Arms (SVM_RBF_Balanced, the existing repo classifier family)",
        "",
        svm_rows[["arm", "accuracy", "macro_precision", "macro_recall", "macro_f1", "weighted_f1", "balanced_accuracy"]].to_markdown(index=False),
        "",
        "## RandomForest reference",
        "",
        metrics_df[metrics_df["arm"].str.contains("RF reference")][["arm", "accuracy", "macro_f1", "balanced_accuracy"]].to_markdown(index=False),
        "",
        "## Confusion matrices (SVM, row=true, col=pred, classes: healthy / stunted / stunted and underweight / underweight)",
        "",
    ]
    for arm_key, cm in cms.items():
        lines += [f"### {arm_key}", "", "```", str(np.array(cm)), "```", ""]
    (RESULTS_DIR / "report.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"\nSaved comparison to {RESULTS_DIR / 'modality_comparison.csv'} and report.md")
    print("Done.")


if __name__ == "__main__":
    main()
