# PoshanEye — Production Hybrid Pipeline

## 1. Architecture

```
                        CHILD IMAGE                          CHILD PROFILE
                             |                          (age, gender, height, weight,
        +--------------------+----------------+          head circ., waist slot, MUAC)
        |                    |                |                        |
        v                    v                v                        v
+----------------+  +------------------+  +----------------+  +---------------------+
| MobileNetV2    |  | MediaPipe        |  | DeepLabV3+     |  | Anthropometric      |
| FEATURE        |  | FaceMesh + Pose  |  | (MobileNetV2   |  | features (+ derived |
| EXTRACTOR      |  | landmarks        |  |  backbone)     |  | BMI; waist slot)    |
| 128-d emb.     |  | 21 features      |  | mask -> 11     |  | 8 features          |
|                |  |                  |  | features       |  |                     |
+----------------+  +------------------+  +----------------+  +---------------------+
|     image block    |     cv block      |     seg block     |     anthro block    |
+--------------------+-------------------+-------------------+---------------------+
                     |
                     v
              FEATURE FUSION  (fixed order: image|cv|segmentation|anthropometric, 168-d)
                     |
                     v
     train-only median imputation + standardization
                     |
                     v
        EXISTING CLASSIFIER FAMILY: SVC(kernel='rbf', C=1.0,
        class_weight='balanced')  ->  portable JSON form for Flutter
                     |
                     v
        4 nutritional classes: healthy / underweight / stunted /
        stunted and underweight
```

**The legacy `Image → MobileNetV2 → 4 classes` model is retired from prediction duty.**
`models/image_best.h5` is used ONLY as the source of the frozen 128-d feature extractor
(its penultimate `image_dense` layer). The softmax head is discarded. The original
`models/best_model.tflite` remains untouched on disk and is NOT deployed.

## 2. Why the SVM was retrained (verification result)

Inspection of the existing SVM training code
(`experiments/cv_multimodal_baseline/run_baseline.py`, `experiments/segmentation_feature_baseline/run_experiment.py`)
showed the previously-evaluated RBF-SVMs used:

| # | Question | Finding |
|---|---|---|
| 1 | Exact input features | Arm A: 6 measurements; Arm B: 15 CV landmarks; Arm C/D: +16 segmentation features |
| 2 | Number of features | 6 / 15 / 21 / 22 / 37 per arm |
| 3 | Feature ordering | concatenated blocks `[measurements | CV landmarks | segmentation]` |
| 4 | Preprocessing | per-group `SimpleImputer(median)` → `StandardScaler`, fit on train only |
| 5 | Training dataset | AnthroVision children + `cv_features_clean.csv` + `segmentation_features.csv`, frozen child-level split 1496/321/321 |
| 6 | Classes | `healthy=0, underweight=1, stunted=2, stunted and underweight=3` |
| 7 | MobileNet features included | **NO** (MobileNet was only a separate diagnostic arm) |
| 8 | MediaPipe CV included | **YES** (15 features) |
| 9 | Segmentation included | **YES** (16 features) |
| 10 | Anthropometrics included | **PARTIAL** — 6 features, **no gender, no waist** |

**Missing required modalities: MobileNet image features, gender, waist slot → the SVM
was retrained with the complete 168-d vector** (same classifier family, same split,
same label mapping). MobileNetV2 was NOT retrained and no new image classifier was
created — the existing trained model is reused frozen as a feature extractor.

## 3. Exact feature list entering the classifier (168-d)

Fixed order (slice offsets in brackets):

- **image [0–127]**: `image_feat_0 … image_feat_127` — penultimate `image_dense`
  Dense(128, relu) output of the legacy MobileNetV2 model (`models/image_best.h5`),
  softmax head discarded.
- **cv [128–148]** (MediaPipe, 21):
  `face_width, face_height, eye_distance, mouth_width, jaw_width, face_ratio, eye_ratio,
  mouth_ratio, shoulder_width, left_upper_arm_length, right_upper_arm_length,
  left_forearm_length, right_forearm_length, left_total_arm_length, right_total_arm_length,
  left_upper_arm_to_shoulder_ratio, right_upper_arm_to_shoulder_ratio,
  left_forearm_to_shoulder_ratio, right_forearm_to_shoulder_ratio,
  left_total_arm_to_shoulder_ratio, right_total_arm_to_shoulder_ratio`
- **segmentation [149–159]** (DeepLabV3+ upper-arm mask, 11):
  `total_arm_area_norm, left_arm_area_norm, right_arm_area_norm, left_arm_width_norm,
  right_arm_width_norm, left_arm_height_norm, right_arm_height_norm,
  left_arm_aspect_ratio, right_arm_aspect_ratio, total_arm_area, num_arms_detected`
- **anthropometric [160–167]** (8):
  `age_months, gender_male, height_cm, weight_kg, head_circumference_cm, waist_cm,
  muac_cm, bmi`

`waist_cm` is a reserved slot: the labeled AnthroVision table has no waist column (only
the unlabeled ARAN dataset carries waistline), so during training it is imputed to 0.0
(pre-standardized) and contributes a constant; it becomes informative the moment a waist
measurement is supplied at inference. BMI is recomputed at inference from height/weight
when missing. These are model features, not medical claims.

## 4. Input/output shape of every model

| Model | Input | Output | Role |
|---|---|---|---|
| `hybrid_production_image_feature_extractor.tflite` | `[1,224,224,3]` float32 (MobileNetV2 preprocess, `[-1,1]`) | `[1,128]` | image features (frozen, from legacy `image_best.h5` minus softmax head) |
| `hybrid_production_segmentation.tflite` | `[1,512,512,3]` float32 (ImageNet mean/std) | `[1,512,512,2]` logits → argmax mask | segmentation features |
| MediaPipe FaceMesh + Pose | RGB image | 10 face + 6 pose landmarks | CV features |
| `hybrid_production_svm_portable.json` | `[168]` preprocessed fused vector | class index (OvO votes + tie-break) | final classifier (pure Dart, offline) |
| `hybrid_production_preprocessor.json` | — | per-feature median/mean/std | exact train-only preprocessing params |

## 5. Training results (child-level frozen split, preprocessing fit on train only)

Same 321 held-out test children for every arm. SVM = `SVC(C=1.0, kernel='rbf',
class_weight='balanced', random_state=42)`; RF reference = `RandomForest(150,
class_weight='balanced')`.

| Arm | SVM acc | SVM bal-acc | SVM macro-F1 | RF acc | RF macro-F1 |
|---|---|---|---|---|---|
| 1 anthropometric-only | 0.7352 | **0.7360** | 0.6128 | 0.8224 | 0.5949 |
| 2 cv-only | 0.4143 | 0.3261 | 0.2746 | 0.6075 | 0.2867 |
| 3 segmentation-only | 0.3863 | 0.3484 | 0.2836 | 0.5545 | 0.2590 |
| 4 image-only features | 0.5358 | 0.4085 | 0.3700 | 0.6511 | 0.2671 |
| 5 anthro + cv | 0.6916 | 0.5573 | 0.5005 | 0.7695 | 0.4974 |
| 6 anthro + cv + seg | 0.6947 | 0.5966 | 0.5274 | 0.7539 | 0.4508 |
| 7 FULL (image+cv+seg+anthro) | 0.6760 | 0.4660 | 0.4571 | 0.7134 | 0.3762 |

Confusion matrix, FULL SVM (rows=true, cols=pred; classes: healthy / underweight /
stunted / stunted and underweight):

```
[[172  32   1  20]
 [ 16  29   0   8]
 [  4   1   1   3]
 [  9  10   0  15]]
```

## 6. Test results — honest reading

- **Anthropometrics dominate**: labels derive from WHO z-scores of height/weight/age, so
  the tabular arm is strongest (SVM balanced accuracy 0.736).
- **Adding CV and/or segmentation features does NOT beat the anthropometric-only arm**
  on this dataset (full model: 0.466 balanced accuracy). No claim is made that the
  hybrid is more accurate than anthropometrics alone — the measured results show the
  opposite on this split.
- The production pipeline is deployed as required because the project mandates all four
  modalities; the per-modality metrics above document what each contributes. Segmentation
  features are genuine DeepLabV3+ mask geometry, CV features are genuine MediaPipe
  landmarks — both reproducible offline — but they add uncalibrated camera noise relative
  to direct clinical measurements. This matches the repo's own earlier finding
  (`experiments/segmentation_feature_baseline/results/report.md`).

## 7. Deployment / inference flow (fully offline)

```
Flutter image (camera / upload)
  → MediaPipe landmarks via platform channel (10 face + 6 pose landmarks)
  → DeepLabV3+ TFLite  [1,512,512,3] → mask → 11 segmentation features
  → MobileNetV2 TFLite [1,224,224,3] → 128-d image embedding
  → anthropometrics + derived BMI
  → HybridInferenceService.fuse (168-d, fixed order)
  → preprocess (median-impute + standardize from hybrid_production_preprocessor.json)
  → portable RBF-SVM in Dart (hybrid_production_svm_portable.json)
  → 4 nutritional classes
```

No network calls. No silent image-only fallback: if any stage fails, the app surfaces an
error. The legacy `best_model.tflite` is not referenced by the new pipeline.

## 8. Confirmation that all four modalities are used

Proven by `Poshaneyemn/production/tests/` (13 tests, all passing):

- `test_feature_groups.py` — H1–H5: each group present with correct size and non-zero
  signal; removing any group changes the vector by exactly its size.
- `test_training_inference_parity.py` — H6–H8: train/inference preprocessing identical
  (parity < 1e-9, no NaNs reach the classifier), portable SVM reproduces sklearn exactly
  (decision values atol 1e-6), zero train/test child overlap (1496/321).
- `test_deployment_pipeline.py` — H9 + end-to-end: deployed image model outputs
  `[1,128]` features (not `[1,4]` probabilities), legacy `best_model.tflite` untouched,
  and a full single-image run through all four modalities produces a valid prediction.
- Flutter `test/services/hybrid_inference_service_test.dart` — golden-vector parity:
  Dart preprocessing matches Python to < 1e-9 and predicts the identical class.

## 9. Files created/changed

Python production package (`Poshaneyemn/production/`):
`__init__.py, config.py, dataset.py, preprocessing.py, image_branch.py,
runtime_features.py, fusion.py, inference.py, train_production.py,
stage1_embeddings.py, stage2_train.py, export_flutter_golden.py,
export_segmentation_tflite.py, tests/{conftest.py, test_feature_groups.py,
test_training_inference_parity.py, test_deployment_pipeline.py}`

Artifacts (`Poshaneyemn/production/artifacts/`):
`hybrid_production_svm.joblib, hybrid_production_svm_portable.json,
hybrid_production_preprocessor.json, hybrid_production_label_map.json,
hybrid_production_image_feature_extractor.tflite,
hybrid_production_segmentation.tflite, hybrid_production_manifest.json,
image_embeddings_{train,validation,test}.npy`

Results (`Poshaneyemn/production/results/`):
`modality_comparison.csv, confusion_matrices.json, report.md,
segmentation_features_train.csv`

Flutter (`poshaneye_flutter/`):
`lib/services/hybrid_inference_service.dart, hybrid_feature_extractor.dart,
hybrid_prediction_orchestrator.dart, hybrid_landmark_bridge.dart`,
`lib/screens/scan_screen.dart` (offline hybrid inference wired in),
`lib/models/vital_record.dart` (waist slot), `lib/screens/main_scaffold.dart`,
`pubspec.yaml` (tflite_flutter, image, model assets),
`assets/models/hybrid_production_*.{tflite,json}`,
`test/services/hybrid_inference_service_test.dart, golden_vector.json`

Untouched: all legacy models (`models/best_model.tflite`, `image_best.h5`, …) and all
`experiments/` code and results.

## 10. Reproduction commands

```bash
# from repository root, using the project venv
cd Poshaneyemn
../.venv/Scripts/python.exe -m production.stage1_embeddings     # ~8 min, once
../.venv/Scripts/python.exe -m production.stage2_train          # trains + saves artifacts
../.venv/Scripts/python.exe -m production.export_flutter_golden # golden parity vector
../.venv/Scripts/python.exe -m production.export_segmentation_tflite
../.venv/Scripts/python.exe -m pytest production/tests -q       # 13 tests
cd ../poshaneye_flutter && flutter test test/services/          # 5 tests
```
