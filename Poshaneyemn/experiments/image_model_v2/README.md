# MobileNetV2 v2 image-classifier experiment (isolated)

Purpose: test whether **damped class weights** improve minority-class recognition on the
PoshanEye 4-class image task without repeating the v1 collapse of the majority class, and
whether keeping **Keras training preprocessing and TFLite inference preprocessing identical**
helps the exported model.

## Isolation guarantees

- Nothing outside `experiments/image_model_v2/` is written.
- `models/best_model.tflite` (production) and `models/class_balanced_experiment/*` (v1) are
  opened **read-only** for comparison and are never modified or replaced.
- No production source file, backend file, Dockerfile or Flutter file is touched.
- `src/` is imported, not edited: `Pipeline.build_datasets` (split), `preprocess_image`
  (image decode/resize/normalize), `ImageModelTrainer.save_tflite` (conversion),
  `utils.ensure_dir`/`save_json`, and `scripts/compare_tflite_models.py` (TFLite inference
  helpers, imported as a module — its `main()` is guarded).

## Design

| Item | Value | Note |
|---|---|---|
| Split | project's existing stratified split via `DataPreprocessor.split_dataset` | `RANDOM_STATE=42`, `TEST_SIZE=0.20`, `VALIDATION_SIZE=0.15` — reused, not re-created |
| Split cache | `artifacts/split_indices.json` | exact image paths + labels per split, for audit |
| Image size | 224×224 | unchanged |
| Batch size | 32 | unchanged |
| Epochs | 25 max, `EarlyStopping(monitor="val_loss", patience=5)` | unchanged budget, same callback family as `src/image_model.py` |
| Backbone | MobileNetV2, `include_top=False`, `weights="imagenet"`, `pooling="avg"`, **frozen** | unchanged |
| Head | Dropout 0.3 → Dense 128 ReLU → Dense 4 softmax | unchanged |
| Optimizer / loss | Adam(1e-4) / SparseCategoricalCrossentropy | unchanged |
| Preprocessing | `mobilenet_v2.preprocess_input` → [-1, 1] | **updated** (production predates this; v1 already used it) |
| Augmentation (train only) | `RandomFlip("horizontal")`, `RandomContrast(0.1)`, `RandomTranslation(0.05, 0.05)`, `RandomZoom(0.05)` | no rotation/shear/colour jitter; layers are module-level singletons because `tf.function` requires singleton variables |
| Validation / test | never augmented, never resampled, never used for fitting | verified by construction |

### Class weighting

Weights are computed from the **train split only**:

```
weight_c = (n_train / (n_classes * n_train_c)) ** alpha
```

- `alpha = 1.0` is the fully balanced weighting used by v1 — already on disk, so it is
  evaluated here as a reference arm instead of being retrained.
- This run trains `alpha ∈ {0.25, 0.50, 0.75}` (damped), so the majority class is
  down-weighted less aggressively.

### Selection rule

1. Per arm, a custom callback tracks validation macro F1 every epoch and checkpoints the
   best epoch **only while validation healthy recall stays ≥ 0.80**.
2. The arm is chosen by the predefined primary metric **validation macro F1** among arms
   that respect that floor (falling back to unguarded macro F1 if none do).
3. The held-out test split is used only to report the already-selected arms.

## Run

```powershell
cd D:\Final-Year-Project\Poshaneyemn
..\.venv\Scripts\python.exe experiments\image_model_v2\run_experiment.py
```

Useful flags: `--epochs`, `--arms alpha_0.25,alpha_0.50`, `--tag smoke`, `--test-frac 0.15`.

## Outputs

```
experiments/image_model_v2/
├── exp_config.py            # configuration (named exp_config so it cannot shadow src/config.py)
├── run_experiment.py
├── artifacts/               # split cache + per-arm .keras/.tflite models (never in models/)
├── logs/                    # per-arm TensorBoard logs
└── results/
    ├── model_comparison.csv
    ├── per_class_metrics.csv
    ├── confusion_matrices/*.txt
    ├── tflite_evaluation.json
    └── final_report.md
```

## Caveat

The 4-class target is an **anthropometric label definition** (`hfa_zscore` / `wfa_zscore`
derived, see the earlier label audit), not an independent clinical diagnosis, and the
`stunted` class has only 12 held-out test images. Metrics on that class are small-sample
noise; no image-model result on this dataset should be described as clinical detection.
