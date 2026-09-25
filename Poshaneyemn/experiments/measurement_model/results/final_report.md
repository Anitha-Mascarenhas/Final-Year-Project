# Measurement-Model Experiment — Final Report

Dataset: AnthroVision (2389 samples) · target: `multiclass_label` · seed 42 · stratified 70/15/15

> **Target-leakage caveat (Step 11):** the AnthroVision multiclass label is substantially
> determined by anthropometric measurements (WHO z-score rule on Height/Weight/Age). Strong
> measurement-model performance therefore does **not** demonstrate independent malnutrition
> detection; it reproduces/approximates the dataset's label definition unless an independent
> clinical/outcome-based target is introduced.

## Authoritative class mapping (fitted LabelEncoder)

- 0 = healthy
- 1 = stunted
- 2 = stunted and underweight
- 3 = underweight

## Final comparison (test phase)

| Model | Resampling | Accuracy | Macro F1 | Macro Recall | Balanced Accuracy |
|---|---|---|---|---|---|
| random_forest | none (raw) | 0.8468 | 0.5914 | 0.5621 | 0.5621 |
| svm_rbf | none (raw) | 0.8886 | 0.6486 | 0.6319 | 0.6319 |
| xgboost | none (raw) | 0.8635 | 0.6365 | 0.6107 | 0.6107 |
| random_forest | class weights | 0.8273 | 0.5974 | 0.5949 | 0.5949 |
| svm_rbf | class weights | 0.8329 | 0.6983 | 0.7635 | 0.7635 |
| xgboost | class weights | 0.8273 | 0.6276 | 0.6374 | 0.6374 |
| random_forest | train-only SMOTE | 0.8329 | 0.6227 | 0.6212 | 0.6212 |
| svm_rbf | train-only SMOTE | 0.8329 | 0.6872 | 0.7298 | 0.7298 |
| xgboost | train-only SMOTE | 0.8357 | 0.6333 | 0.6417 | 0.6417 |
| majority_baseline | — | 0.6936 | 0.2048 | 0.2500 | 0.2500 |

**Best candidate by the predefined metric (macro F1): svm_rbf (class_weights) = 0.6983.** Not promoted to production.

## Majority baseline

Predicting only ``...

## Label-definition ceiling (diagnostic, NOT a trained model)

- rule accuracy: 0.9678
- rule: stunted = hfa_zscore < -2; underweight = wfa_zscore < -2; both -> stunted and underweight

## Leakage ablation (validation phase, throwaway RFs)

| Feature set | Validation accuracy | Validation macro F1 |
|---|---|---|
| A_height_age (Height, Age) | 0.6574 | 0.4532 |
| B_weight_age (Weight, Age) | 0.8050 | 0.5128 |
| C_height_weight_age (Height, Weight, Age) | 0.8329 | 0.5771 |
| D_all_six (Height, Weight, MUAC, HC, Age, BMI) | 0.8050 | 0.5343 |

## Limitations

- The label is an anthropometric function; models approximate its definition.
- SMOTE interpolates in raw measurement space; synthetic children are not real children.
- Hyperparameter grids are deliberately small; results are directional, not SOTA claims.
- No independent clinical outcome target exists yet, so 'detection' claims are out of scope.

## Recommendation for the next experiment

- Compare winning arm vs the z-score rule ceiling; if the ceiling is far higher, prefer the
  deterministic rule in production and keep ML only where it beats it on held-out macro F1.
- Introduce an independent outcome target (e.g. recovery, clinician flag) before claiming
  predictive value beyond label reconstruction.
