# Measurement-Model Experiment (isolated)

**Status:** experiment only — nothing here is wired into production. All outputs land
under `experiments/measurement_model/`. Production `models/`, `src/` inference code,
the FastAPI backend, and the Flutter app are untouched.

## Purpose

Quantify, under a controlled and reproducible protocol, how well tabular
measurement models (RandomForest / RBF-SVM / XGBoost) can classify the AnthroVision
`multiclass_label` under three imbalance-handling arms — and how much of that
performance is simply **reconstructing the label definition**.

## Target-leakage documentation (important)

The AnthroVision `multiclass_label` is **substantially determined by anthropometric
measurements**: it is derived from WHO z-score flags (`hfa_zscore`, `wfa_zscore`,
`BMIz_who`) which are themselves computed from Height / Weight / Age / sex.
Because the headline features (Height, Weight, MUAC, HC, Age, BMI) overlap with the
variables that define the labels, **strong measurement-model performance does not
demonstrate independent malnutrition detection** — the models approximate the
dataset's labeling rule. This experiment should be described as
*reproducing/approximating the label definition* unless an independent
clinical/outcome-based target is introduced.

## Design

| Step | Guarantee |
|---|---|
| Split | One stratified 70/15/15 split, seed 42, created BEFORE any resampling; row indices cached to `artifacts/split_indices.json` so every rerun uses the identical population |
| Arm A | RandomForest / RBF-SVM / XGBoost on raw train |
| Arm B | `class_weight="balanced"` (RF, SVM); XGBoost uses per-class inverse-frequency `sample_weight` |
| Arm C | SMOTE **train only**, `k_neighbors = min(5, min_class_count − 1)`; validation/test never resampled |
| Scaler | SVM: `StandardScaler` inside a sklearn `Pipeline` → fitted on train folds only |
| Tuning | `GridSearchCV(scoring="f1_macro")`, 3-fold StratifiedKFold, train only — never against test |
| Labels | Numeric→name mapping taken exclusively from the **fitted LabelEncoder** (`0=healthy, 1=stunted, 2=stunted and underweight, 3=underweight`); asserted against production `models/label_encoder.pkl` |
| Test usage | Untouched until the final per-arm candidate is selected on **validation macro F1** |

## Arms & diagnostics

- **Majority baseline** — always predict the most frequent training class.
- **Label-definition ceiling** — deterministic rule: `stunted ⇔ hfa_zscore < −2`,
  `underweight ⇔ wfa_zscore < −2`, both → `stunted and underweight`. Not a trained
  model; measures how exactly the supplied labels can be reconstructed.
- **Leakage ablation** — throwaway RFs on Height+Age / Weight+Age / Height+Weight+Age /
  all six features to quantify recoverability of the target.

## SMOTE note

`imbalanced-learn` is **not installed** in this environment, so Arm C uses a
self-contained SMOTE (Chawla et al., 2002) implemented in `run_experiment.py`:
kNN interpolation within each minority class in the (already numeric) measurement
feature space. It matches the canonical algorithm for this feature type and keeps the
experiment dependency-isolated.

## Run

```bash
cd Poshaneyemn
../.venv/Scripts/python.exe experiments/measurement_model/run_experiment.py
```

## Outputs

```
experiments/measurement_model/
├── README.md
├── config.py
├── run_experiment.py
├── artifacts/split_indices.json
└── results/
    ├── model_comparison.csv
    ├── per_class_metrics.csv
    ├── confusion_matrices/  (one txt per model/arm/phase)
    └── final_report.md
```
