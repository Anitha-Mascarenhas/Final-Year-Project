#!/usr/bin/env python
"""PoshanEye measurement-model experiment (isolated, reproducible).

Arms
  A  no resampling          RandomForest / RBF-SVM / XGBoost on raw train
  B  class weights          class_weight="balanced" (XGBoost: per-class sample_weight)
  C  train-only SMOTE       kNN-interpolation SMOTE, train ONLY, k chosen from minority count

Diagnostics
  majority baseline  - predict the most frequent training class for everything
  label ceiling      - deterministic WHO z-score rule (hfa/wfa < -2) reconstructing the
                       dataset's label definition. NOT a trained model.
  leakage ablation   - Height+Age / Weight+Age / Height+Weight+Age / all six

Design guarantees
  * one fixed stratified split (70/15/15, seed 42), cached to artifacts/split_indices.json
  * test set NEVER resampled; SMOTE touches train only
  * SVM scaler lives inside a sklearn Pipeline -> fitted on train folds only
  * tuning with GridSearchCV(scoring="f1_macro") inside TRAIN ONLY
  * class names always come from the fitted LabelEncoder (authoritative mapping)

Run (from Poshaneyemn/):
    ../.venv/Scripts/python.exe experiments/measurement_model/run_experiment.py
"""

from __future__ import annotations

import importlib.util
import json
import sys
from contextlib import contextmanager
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_recall_fscore_support,
    precision_score,
    recall_score,
)
from sklearn.model_selection import GridSearchCV, StratifiedKFold, train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC
from xgboost import XGBClassifier

# --------------------------------------------------------------- path bootstrap
EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parent.parent
SRC_DIR = PROJECT_ROOT / "src"
sys.path.insert(0, str(SRC_DIR))          # for src/config.py (dataset path only)


def _load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


exp_config = _load_module("exp_config", EXPERIMENT_DIR / "config.py")

# Reuse production loaders/preprocessor/encoder (read-only).
from config import ANTHROVISION_CSV as PROD_CSV  # noqa: E402  (src/config.py)
from data_loader import DatasetLoader  # noqa: E402
from features import MeasurementFeaturePipeline  # noqa: E402
from preprocessing import DataPreprocessor  # noqa: E402

RESULTS_DIR = exp_config.RESULTS_DIR
CONFUSION_DIR = exp_config.CONFUSION_DIR
ARTIFACTS_DIR = exp_config.ARTIFACTS_DIR
RANDOM_STATE = exp_config.SPLIT_RANDOM_STATE
FEATURES = exp_config.FEATURES
TARGET = exp_config.TARGET_COLUMN

# --------------------------------------------------------------- console safety
@contextmanager
def quiet_production_logs():
    """Silence stdout during Pipeline/DatasetLoader calls (they print progress)."""
    import io

    buf = io.StringIO()
    with _redirect_stdout(buf):
        yield


def _redirect_stdout(buf):
    import contextlib

    return contextlib.redirect_stdout(buf)


# --------------------------------------------------------------- data & split
def load_dataset() -> tuple[pd.DataFrame, list[str]]:
    """Load raw AnthroVision and fit the production LabelEncoder -> authoritative names."""
    loader = DatasetLoader()
    with quiet_production_logs():
        df = loader.load_anthrovision()

    pre = DataPreprocessor(target_column=TARGET)
    df = pre.clean_anthrovision(df)
    df = pre.encode_labels(df)                      # fits encoder on multiclass_label

    class_names = pre.get_class_names()             # authoritative, encoder order
    assert class_names == exp_config.EXPECTED_CLASS_NAMES, (
        f"Fitted encoder order {class_names} does not match expected mapping "
        f"{exp_config.EXPECTED_CLASS_NAMES}"
    )

    # Load production encoder as a cross-check of fitted ordering (read-only).
    prod_encoder = None
    if exp_config.PRODUCTION_ENCODER_PATH.exists():
        import joblib

        prod_encoder = joblib.load(exp_config.PRODUCTION_ENCODER_PATH)
        prod_names = [str(c) for c in prod_encoder.classes_]
        assert prod_names == class_names, (
            f"Production encoder order {prod_names} != freshly fitted {class_names}"
        )

    return df, class_names


def make_fixed_split(df: pd.DataFrame, class_names: list[str]) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
    """One stratified 70/15/15 split (seed 42) BEFORE any resampling; cached indices."""
    n = len(df)
    rng = np.random.RandomState(RANDOM_STATE)       # placeholder, unused directly

    # 70/30 then 15/15 -> stratified twice
    train_val, test = train_test_split(
        df,
        test_size=exp_config.TEST_FRACTION,
        random_state=RANDOM_STATE,
        stratify=df["label"],
    )
    val_fraction_of_tv = exp_config.VAL_FRACTION / (exp_config.TRAIN_FRACTION + exp_config.VAL_FRACTION)
    train, val = train_test_split(
        train_val,
        test_size=val_fraction_of_tv,
        random_state=RANDOM_STATE,
        stratify=train_val["label"],
    )

    # ---- cache the split as absolute row indices into the encoded dataframe
    all_index = df.index.to_numpy()
    idx = {name: set(all_index) for name in []}  # noqa: F841 (placeholder)
    def _positions(part: pd.DataFrame) -> list[int]:
        pos = pd.Series(np.arange(len(df)), index=df.index)
        return [int(p) for p in pos.loc[part.index]]

    split_payload = {
        "random_state": RANDOM_STATE,
        "stratified": True,
        "fractions": {
            "train": exp_config.TRAIN_FRACTION,
            "validation": exp_config.VAL_FRACTION,
            "test": exp_config.TEST_FRACTION,
        },
        "sizes": {"train": len(train), "validation": len(val), "test": len(test)},
        "indices": {
            "train": _positions(train),
            "validation": _positions(val),
            "test": _positions(test),
        },
        "class_names": class_names,
    }
    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    (ARTIFACTS_DIR / "split_indices.json").write_text(json.dumps(split_payload, indent=2))

    print(f"[split] sizes: train={len(train)} val={len(val)} test={len(test)} (seed {RANDOM_STATE}, stratified)")
    for name, part in (("train", train), ("val", val), ("test", test)):
        counts = part["label"].value_counts().sort_index()
        dist = ", ".join(f"{class_names[i]}={counts.get(i, 0)}" for i in range(len(class_names)))
        print(f"[split] {name:<5}: {dist}")

    assert set(train.index) & set(val.index) == set()
    assert set(train.index) & set(test.index) == set()
    assert set(val.index) & set(test.index) == set()
    assert len(train) + len(val) + len(test) == n
    return train, val, test


# --------------------------------------------------------------- metrics helpers
def evaluate_classifier(name: str, arm: str, y_true, y_pred, class_names: list[str], phase: str) -> dict[str, Any]:
    """Full metric block (Step 5) for one model on one data phase."""
    acc = accuracy_score(y_true, y_pred)
    macro_p = precision_score(y_true, y_pred, average="macro", zero_division=0)
    macro_r = recall_score(y_true, y_pred, average="macro", zero_division=0)
    macro_f1 = f1_score(y_true, y_pred, average="macro", zero_division=0)
    w_p = precision_score(y_true, y_pred, average="weighted", zero_division=0)
    w_r = recall_score(y_true, y_pred, average="weighted", zero_division=0)
    w_f1 = f1_score(y_true, y_pred, average="weighted", zero_division=0)
    bal_acc = balanced_accuracy_score(y_true, y_pred)

    per_class = precision_recall_fscore_support(y_true, y_pred, labels=range(len(class_names)), zero_division=0)
    cm = confusion_matrix(y_true, y_pred, labels=range(len(class_names)))

    return {
        "model": name,
        "arm": arm,
        "phase": phase,
        "accuracy": acc,
        "macro_precision": macro_p,
        "macro_recall": macro_r,
        "macro_f1": macro_f1,
        "weighted_precision": w_p,
        "weighted_recall": w_r,
        "weighted_f1": w_f1,
        "balanced_accuracy": bal_acc,
        "per_class_precision": dict(zip(class_names, per_class[0])),
        "per_class_recall": dict(zip(class_names, per_class[1])),
        "per_class_f1": dict(zip(class_names, per_class[2])),
        "confusion_matrix": cm.tolist(),
        "support": dict(zip(class_names, per_class[3].tolist())),
    }


def save_confusion_matrices(records: list[dict], phase: str) -> None:
    CONFUSION_DIR.mkdir(parents=True, exist_ok=True)
    for rec in records:
        cm = np.array(rec["confusion_matrix"])
        names = exp_config.EXPECTED_CLASS_NAMES
        lines = []
        w = max(len(n) for n in names) + 2
        header = " " * w + "".join(f"{n[:12]:>14}" for n in names)
        lines.append(header)
        for i, row_name in enumerate(names):
            row = " " * (w - len(row_name)) + row_name + "".join(f"{cm[i, j]:>14d}" for j in range(cm.shape[1]))
            lines.append(row)
        slug = f"{phase}_{rec['arm']}_{rec['model']}.txt"
        (CONFUSION_DIR / slug).write_text("\n".join(lines))


# --------------------------------------------------------------- SMOTE (self-contained)
def smote_resample(X: np.ndarray, y: np.ndarray, desired_k: int, random_state: int) -> tuple[np.ndarray, np.ndarray]:
    """Minority-oversampling SMOTE (Chawla et al. 2002) for numeric features.

    k_neighbors = min(desired_k, min_class_count - 1).
    NOTE: applied to TRAINING data only, by construction (callers guarantee it).
    """
    rng = np.random.RandomState(random_state)
    classes, counts = np.unique(y, return_counts=True)
    majority_count = counts.max()
    k_neighbors = min(desired_k, int(counts.min()) - 1)
    k_neighbors = max(k_neighbors, 1)
    print(f"[smote] class counts before: {dict(zip(classes.tolist(), counts.tolist()))}")
    print(f"[smote] k_neighbors={k_neighbors} (min class count {counts.min()})")

    synthetic_X, synthetic_y = [], []
    for cls in classes:
        cls_idx = np.where(y == cls)[0]
        deficit = majority_count - len(cls_idx)
        if deficit <= 0:
            continue
        X_cls = X[cls_idx]
        # kNN within class (numeric features, euclidean)
        from sklearn.neighbors import NearestNeighbors

        nn = NearestNeighbors(n_neighbors=k_neighbors + 1).fit(X_cls)  # +1 excludes self
        _, ind = nn.kneighbors(X_cls)
        neighbors = ind[:, 1:]                       # drop self
        for _ in range(deficit):
            i = rng.randint(len(X_cls))
            j = neighbors[i, rng.randint(k_neighbors)]
            lam = rng.rand()
            synthetic_X.append(X_cls[i] + lam * (X_cls[j] - X_cls[i]))
            synthetic_y.append(cls)

    if synthetic_X:
        X_out = np.vstack([X, np.array(synthetic_X, dtype=X.dtype)])
        y_out = np.concatenate([y, np.array(synthetic_y, dtype=y.dtype)])
    else:
        X_out, y_out = X, y

    classes_out, counts_out = np.unique(y_out, return_counts=True)
    print(f"[smote] class counts after : {dict(zip(classes_out.tolist(), counts_out.tolist()))}")
    return X_out, y_out


# --------------------------------------------------------------- model factories
def make_models(arm: str) -> dict[str, Any]:
    """Return {model_name: (estimator, param_grid)} for one arm."""
    grids = exp_config.PARAM_GRIDS

    def rf():
        est = RandomForestClassifier(random_state=RANDOM_STATE)
        if arm == "class_weights":
            est.set_params(class_weight="balanced")
        return est, grids["random_forest"]

    def svm():
        # Scaler INSIDE the pipeline -> fitted only on training folds (never on val/test).
        pipe = Pipeline([
            ("scaler", StandardScaler()),
            ("svc", SVC(kernel="rbf", random_state=RANDOM_STATE)),
        ])
        if arm == "class_weights":
            pipe.set_params(svc__class_weight="balanced")
        return pipe, grids["svm_rbf"]

    def xgb():
        est = XGBClassifier(
            objective="multi:softprob",
            eval_metric="mlogloss",
            tree_method="hist",
            random_state=RANDOM_STATE,
        )
        return est, grids["xgboost"]

    return {"random_forest": rf, "svm_rbf": svm, "xgboost": xgb}


def xgb_sample_weights(y: np.ndarray) -> np.ndarray:
    """Per-sample weights inversely proportional to class frequency (Arm B)."""
    classes, counts = np.unique(y, return_counts=True)
    weight_map = {c: len(y) / (len(classes) * cnt) for c, cnt in zip(classes, counts)}
    return np.array([weight_map[v] for v in y])


# --------------------------------------------------------------- main experiment
def main() -> None:
    print("=" * 78)
    print("POSHANEYE MEASUREMENT-MODEL EXPERIMENT (isolated under experiments/measurement_model)")
    print("=" * 78)

    df, class_names = load_dataset()
    n = len(df)
    counts = df["label"].value_counts().sort_index()
    print(f"[data] total samples: {n}")
    print("[data] class distribution: " + ", ".join(f"{class_names[i]}={counts.get(i, 0)}" for i in range(len(class_names))))

    # Safety checks (Step 10): exclusions before split
    forbidden = [c for c in ("label", TARGET, "image_name", "image_path", "image_id", "index") if c in FEATURES]
    assert not forbidden, f"Target/ID columns leaked into FEATURES: {zforbidden}"
    assert not df[FEATURES].isna().all().any(), "A feature column is entirely NaN"

    train, val, test = make_fixed_split(df, class_names)

    X_train_raw = train[FEATURES].to_numpy(dtype=np.float64)
    y_train = train["label"].to_numpy(dtype=int)
    X_val = val[FEATURES].to_numpy(dtype=np.float64)
    y_val = val["label"].to_numpy(dtype=int)
    X_test = test[FEATURES].to_numpy(dtype=np.float64)
    y_test = test["label"].to_numpy(dtype=int)

    # ---------------------------------------------------------------- Arm C data
    X_train_smote, y_train_smote = smote_resample(
        X_train_raw, y_train, desired_k=exp_config.SMOTE_DESIRED_K, random_state=RANDOM_STATE
    )

    # ---------------------------------------------------------------- tuning + fit
    all_records: list[dict] = []

    arms = [
        ("no_resampling", X_train_raw, y_train),
        ("class_weights", X_train_raw, y_train),
        ("train_only_smote", X_train_smote, y_train_smote),
    ]

    best_per_arm: dict[str, dict] = {}

    for arm_name, X_tr, y_tr in arms:
        print(f"\n{'-' * 78}\nARM {arm_name}\n{'-' * 78}")
        factories = make_models(arm_name)
        arm_records: list[dict] = []
        best_for_arm = None

        for model_name, factory in factories.items():
            est, grid = factory()

            use_sample_weight = (arm_name == "class_weights" and model_name == "xgboost")
            if use_sample_weight:
                sw = xgb_sample_weights(y_tr)
                fit_kwargs = {"sample_weight": sw}
            else:
                fit_kwargs = None

            cv = StratifiedKFold(n_splits=exp_config.CV_FOLDS, shuffle=True, random_state=RANDOM_STATE)
            gs = GridSearchCV(
                est, grid, scoring=exp_config.TUNING_SCORING, cv=cv, n_jobs=-1, refit=True
            )

            if fit_kwargs:
                # XGBoost sample weights flow through the sklearn API via fit params.
                gs.fit(X_tr, y_tr, **fit_kwargs)
                gs.best_estimator_.fit(X_tr, y_tr, **fit_kwargs)  # refit with weights
            else:
                gs.fit(X_tr, y_tr)

            best_params = {k.replace("svc__", ""): v for k, v in gs.best_params_.items()}
            print(f"[tune] {model_name:<14} best params: {best_params}  cv_{exp_config.TUNING_SCORING}={gs.best_score_:.4f}")

            model = gs.best_estimator_

            for phase, X_ev, y_ev in (("validation", X_val, y_val), ("test", X_test, y_test)):
                y_pred = model.predict(X_ev)
                rec = evaluate_classifier(model_name, arm_name, y_ev, y_pred, class_names, phase)
                arm_records.append(rec)
                if phase == "test":
                    print(
                        f"[{phase}] {model_name:<14} acc={rec['accuracy']:.4f} "
                        f"macroF1={rec['macro_f1']:.4f} macroRecall={rec['macro_recall']:.4f} "
                        f"balAcc={rec['balanced_accuracy']:.4f}"
                    )

            # validation-selected candidate for this arm
            val_rec = next(r for r in arm_records if r["model"] == model_name and r["phase"] == "validation")
            if best_for_arm is None or val_rec["macro_f1"] > best_for_arm["val_macro_f1"]:
                best_for_arm = {
                    "arm": arm_name,
                    "model": model_name,
                    "val_macro_f1": val_rec["macro_f1"],
                    "params": best_params,
                }

        all_records.extend(arm_records)
        best_per_arm[arm_name] = best_for_arm

    # ---------------------------------------------------------------- baselines & diagnostics
    # Majority baseline: predict the most frequent training class for everything.
    majority_label = int(pd.Series(y_train).value_counts().idxmax())
    print(f"\n[baseline] majority class: {class_names[majority_label]} (label {majority_label})")
    for phase, y_ev in (("validation", y_val), ("test", y_test)):
        rec = evaluate_classifier(
            "majority_baseline", "baseline", y_ev, np.full_like(y_ev, majority_label), class_names, phase
        )
        all_records.append(rec)
        print(f"[{phase}] majority acc={rec['accuracy']:.4f} macroF1={rec['macro_f1']:.4f}")

    # ---------------------------------------------------------------- save records
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)
    flat = []
    for rec in all_records:
        flat.append({k: v for k, v in rec.items() if k not in ("per_class_precision", "per_class_recall", "per_class_f1", "support", "confusion_matrix")})
    comparison_df = pd.DataFrame(flat)
    comparison_df.to_csv(RESULTS_DIR / "model_comparison.csv", index=False)

    # per-class metrics CSV
    rows = []
    for rec in all_records:
        for cls in class_names:
            rows.append({
                "phase": rec["phase"], "arm": rec["arm"], "model": rec["model"], "class": cls,
                "precision": rec["per_class_precision"][cls],
                "recall": rec["per_class_recall"][cls],
                "f1": rec["per_class_f1"][cls],
                "support": rec["support"][cls],
            })
    pd.DataFrame(rows).to_csv(RESULTS_DIR / "per_class_metrics.csv", index=False)

    save_confusion_matrices(all_records, "final")

    # ---------------------------------------------------------------- label ceiling + ablation
    print("\n" + "=" * 78)
    print("DIAGNOSTICS")
    print("=" * 78)

    # ---- Step 7: label-definition ceiling (NOT a trained model)
    def zscore_rule(z_hfa, z_wfa) -> int:
        stunted = int(z_hfa < -2.0)
        under = int(z_wfa < -2.0)
        return {0: 0, 1: 1, 3: 3, 2: 2}[stunted * 2 + under] if False else {0: 0, 1: 1, 2: 3, 3: 2}[stunted * 2 + under]

    rule_map = {(0, 0): 0, (1, 0): 1, (0, 1): 3, (1, 1): 2}
    def zscore_rule(z_hfa, z_wfa) -> int:
        return rule_map[(int(z_hfa < -2.0), int(z_wfa < -2.0))]

    rule_preds = np.array([zscore_rule(a, b) for a, b in zip(df["hfa_zscore"], df["wfa_zscore"])])
    y_all = df["label"].to_numpy(dtype=int)
    rec = evaluate_classifier("zscore_rule_ceiling", "diagnostic", y_all, rule_preds, class_names, "all_data")
    all_records.append(rec)
    print(f"[ceiling] WHO z-score rule reproduces multiclass_label with accuracy {rec['accuracy']:.4f}")
    print("          (label-definition consistency, NOT malnutrition-detection accuracy)")

    # ---- Step 8: leakage ablation (throwaway RFs, validation phase)
    ablation_sets = {
        "A_height_age": ["Height", "Age"],
        "B_weight_age": ["Weight", "Age"],
        "C_height_weight_age": ["Height", "Weight", "Age"],
        "D_all_six": FEATURES,
    }
    ablation_rows = []
    for name, cols in ablation_sets.items():
        pre = MeasurementFeaturePipeline(feature_columns=list(cols))
        Xa_tr = pre.fit_transform(train)
        Xa_va = pre.transform(val)
        rf = RandomForestClassifier(n_estimators=300, class_weight="balanced", random_state=RANDOM_STATE)
        rf.fit(Xa_tr, y_train)
        pred_val = rf.predict(Xa_va)
        rec_a = evaluate_classifier(name, "leakage_ablation", y_val, pred_val, class_names, "validation")
        ablation_rows.append((name, cols, rec_a["accuracy"], rec_a["macro_f1"]))
        print(f"[ablation] {name:<22} {str(cols):<38} val acc={rec_a['accuracy']:.4f} macroF1={rec_a['macro_f1']:.4f}")

    # ---------------------------------------------------------------- final report
    report = build_final_report(comparison_df, all_records, class_names, best_per_arm, ablation_rows, rec, n)
    (RESULTS_DIR / "final_report.md").write_text(report)
    print("\n[done] artifacts written under experiments/measurement_model/results/")

    # ---- Step 11: target-leakage documentation is embedded in final_report.md
    print("\nNOTE (target-leakage): the AnthroVision multiclass label is substantially determined")
    print("by anthropometric measurements; strong measurement-model performance does NOT")
    print("demonstrate independent malnutrition detection. See final_report.md.")


def build_final_report(comparison_df, all_records, class_names, best_per_arm, ablation_rows, ceiling_rec, n_total) -> str:
    lines = []
    ap = lines.append
    ap("# Measurement-Model Experiment — Final Report")
    ap("")
    ap(f"Dataset: AnthroVision ({n_total} samples) · target: `multiclass_label` · seed 42 · stratified 70/15/15")
    ap("")
    ap("> **Target-leakage caveat (Step 11):** the AnthroVision multiclass label is substantially")
    ap("> determined by anthropometric measurements (WHO z-score rule on Height/Weight/Age). Strong")
    ap("> measurement-model performance therefore does **not** demonstrate independent malnutrition")
    ap("> detection; it reproduces/approximates the dataset's label definition unless an independent")
    ap("> clinical/outcome-based target is introduced.")
    ap("")
    ap("## Authoritative class mapping (fitted LabelEncoder)")
    ap("")
    for i, n in enumerate(class_names):
        ap(f"- {i} = {n}")
    ap("")

    # headline comparison (test phase)
    ap("## Final comparison (test phase)")
    ap("")
    ap("| Model | Resampling | Accuracy | Macro F1 | Macro Recall | Balanced Accuracy |")
    ap("|---|---|---|---|---|---|")
    test_df = comparison_df[comparison_df["phase"] == "test"]
    arm_labels = {
        "no_resampling": "none (raw)",
        "class_weights": "class weights",
        "train_only_smote": "train-only SMOTE",
        "baseline": "—",
        "diagnostic": "—",
    }
    for _, r in test_df.iterrows():
        ap(
            f"| {r['model']} | {arm_labels.get(r['arm'], r['arm'])} | {r['accuracy']:.4f} | "
            f"{r['macro_f1']:.4f} | {r['macro_recall']:.4f} | {r['balanced_accuracy']:.4f} |"
        )
    ap("")

    best = max(
        (r for r in test_df.to_dict("records") if r["arm"] in ("no_resampling", "class_weights", "train_only_smote")),
        key=lambda r: r["macro_f1"],
    )
    ap(f"**Best candidate by the predefined metric (macro F1): {best['model']} ({best['arm']}) "
       f"= {best['macro_f1']:.4f}.** Not promoted to production.")
    ap("")

    ap("## Majority baseline")
    ap("")
    mb = test_df[test_df["model"] == "majority_baseline"].iloc[0]
    ap(f"Predicting only `{class_names[0] if False else ''}`..." .rstrip())
    ap("")
    ap("## Label-definition ceiling (diagnostic, NOT a trained model)")
    ap("")
    ap(f"- rule accuracy: {ceiling_rec['accuracy']:.4f}")
    ap("- rule: stunted = hfa_zscore < -2; underweight = wfa_zscore < -2; both -> stunted and underweight")
    ap("")
    ap("## Leakage ablation (validation phase, throwaway RFs)")
    ap("")
    ap("| Feature set | Validation accuracy | Validation macro F1 |")
    ap("|---|---|---|")
    for name, cols, acc, f1 in ablation_rows:
        ap(f"| {name} ({', '.join(cols)}) | {acc:.4f} | {f1:.4f} |")
    ap("")
    ap("## Limitations")
    ap("")
    ap("- The label is an anthropometric function; models approximate its definition.")
    ap("- SMOTE interpolates in raw measurement space; synthetic children are not real children.")
    ap("- Hyperparameter grids are deliberately small; results are directional, not SOTA claims.")
    ap("- No independent clinical outcome target exists yet, so 'detection' claims are out of scope.")
    ap("")
    ap("## Recommendation for the next experiment")
    ap("")
    ap("- Compare winning arm vs the z-score rule ceiling; if the ceiling is far higher, prefer the")
    ap("  deterministic rule in production and keep ML only where it beats it on held-out macro F1.")
    ap("- Introduce an independent outcome target (e.g. recovery, clinician flag) before claiming")
    ap("  predictive value beyond label reconstruction.")
    ap("")
    return "\n".join(lines)


if __name__ == "__main__":
    main()
