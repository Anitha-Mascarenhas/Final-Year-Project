# PoshanEye: Segmentation-Derived Feature Baseline & Multimodal Comparison Report

## 1. Executive Summary & Experimental Goal

Following the successful training of DeepLabV3+ (MobileNetV2 backbone) on upper-arm segmentation, this experiment systematically evaluated whether automated segmentation-derived geometric features add predictive value when combined with measurement and landmark CV features for child nutritional status classification.

### Strict Experimental Controls & Integrity

- **Frozen Split Reuse**: The exact child-level train/validation/test split from `cv_multimodal_baseline` was preserved.
- **Zero Leakage**: Exactly 0 child overlap across train (1,496), validation (321), and test (321) splits.
- **Leakage-Free Preprocessing**: Median imputation and `StandardScaler` were fit strictly on the training set.
- **Direct Model Comparability**: Identical classifier families (`RandomForestClassifier(n_estimators=150, class_weight='balanced')` and `SVC(kernel='rbf', class_weight='balanced')`) with `random_state=42` were evaluated on the exact same 321 test children.

## 2. Modality Arm Definitions

- **Arm A (Measurement-Only)**: 6 tabular anthropometric measurements (`Height`, `Weight`, `MUAC`, `HC`, `Age`, `BMI`).
- **Arm B (Measurement + CV Landmarks)**: 6 measurements + 15 MediaPipe facial and arm landmark metrics.
- **Arm C (Measurement + Segmentation)**: 6 measurements + 16 DeepLabV3+ upper-arm silhouette geometric features (areas, widths, heights, aspect ratios, and shoulder-width normalized variants).
- **Arm D (Measurement + CV + Segmentation)**: 6 measurements + 15 landmark metrics + 16 segmentation features (37 total features).

## 3. Held-Out Test Evaluation Results (N = 321 Children)

| modality_arm                           | model_name            | accuracy | balanced_accuracy | macro_precision | macro_recall | macro_f1 | weighted_f1 |
|----------------------------------------|-----------------------|----------|-------------------|-----------------|--------------|----------|-------------|
| Arm A: Measurement-Only                | RandomForest_Balanced | 0.8193   | 0.6154            | 0.6153          | 0.6154       | 0.6123   | 0.821       |
| Arm A: Measurement-Only                | SVM_RBF_Balanced      | 0.7695   | 0.7626            | 0.6412          | 0.7626       | 0.6499   | 0.8066      |
| Arm B: Measurement + CV Landmarks      | RandomForest_Balanced | 0.8037   | 0.495             | 0.5144          | 0.495        | 0.4971   | 0.7894      |
| Arm B: Measurement + CV Landmarks      | SVM_RBF_Balanced      | 0.7227   | 0.6148            | 0.5217          | 0.6148       | 0.538    | 0.755       |
| Arm C: Measurement + Segmentation      | RandomForest_Balanced | 0.7726   | 0.4776            | 0.488           | 0.4776       | 0.4725   | 0.76        |
| Arm C: Measurement + Segmentation      | SVM_RBF_Balanced      | 0.7321   | 0.6582            | 0.5635          | 0.6582       | 0.5782   | 0.7676      |
| Arm D: Measurement + CV + Segmentation | RandomForest_Balanced | 0.7601   | 0.4614            | 0.4711          | 0.4614       | 0.4624   | 0.7468      |
| Arm D: Measurement + CV + Segmentation | SVM_RBF_Balanced      | 0.6885   | 0.5881            | 0.4921          | 0.5881       | 0.5101   | 0.7221      |

### Comparative Analysis by Classifier Family

#### Balanced Random Forest (150 trees)

| modality_arm                           | model_name            | accuracy | balanced_accuracy | macro_precision | macro_recall | macro_f1 | weighted_f1 |
|----------------------------------------|-----------------------|----------|-------------------|-----------------|--------------|----------|-------------|
| Arm A: Measurement-Only                | RandomForest_Balanced | 0.8193   | 0.6154            | 0.6153          | 0.6154       | 0.6123   | 0.821       |
| Arm B: Measurement + CV Landmarks      | RandomForest_Balanced | 0.8037   | 0.495             | 0.5144          | 0.495        | 0.4971   | 0.7894      |
| Arm C: Measurement + Segmentation      | RandomForest_Balanced | 0.7726   | 0.4776            | 0.488           | 0.4776       | 0.4725   | 0.76        |
| Arm D: Measurement + CV + Segmentation | RandomForest_Balanced | 0.7601   | 0.4614            | 0.4711          | 0.4614       | 0.4624   | 0.7468      |

#### Balanced RBF Support Vector Machine (SVM)

| modality_arm                           | model_name       | accuracy | balanced_accuracy | macro_precision | macro_recall | macro_f1 | weighted_f1 |
|----------------------------------------|------------------|----------|-------------------|-----------------|--------------|----------|-------------|
| Arm A: Measurement-Only                | SVM_RBF_Balanced | 0.7695   | 0.7626            | 0.6412          | 0.7626       | 0.6499   | 0.8066      |
| Arm B: Measurement + CV Landmarks      | SVM_RBF_Balanced | 0.7227   | 0.6148            | 0.5217          | 0.6148       | 0.538    | 0.755       |
| Arm C: Measurement + Segmentation      | SVM_RBF_Balanced | 0.7321   | 0.6582            | 0.5635          | 0.6582       | 0.5782   | 0.7676      |
| Arm D: Measurement + CV + Segmentation | SVM_RBF_Balanced | 0.6885   | 0.5881            | 0.4921          | 0.5881       | 0.5101   | 0.7221      |

## 4. Key Scientific Questions & Evidence-Based Answers

### Question 1: Does segmentation-derived geometry improve over the measurement-only baseline?
**Answer**: **No.** Adding upper-arm segmentation features to tabular measurements does not improve performance over measurements alone. For Balanced RBF SVM, balanced accuracy shifts from 76.26% (Arm A) to 65.82% (Arm C). For Balanced Random Forest, balanced accuracy shifts from 61.54% (Arm A) to 47.76% (Arm C).

*Methodological Context*: AnthroVision multiclass labels are derived deterministically from WHO z-score formulas which are direct mathematical functions of Height, Weight, and Age. Tabular measurements directly approximate the ground-truth labeling rule. Appending projected 2D image silhouette features adds uncalibrated camera noise that diffuses the high-certainty decision boundary.

### Question 2: Does it improve over measurement + landmark CV?
**Answer**: Comparing Arm C (Measurement + Segmentation) against Arm B (Measurement + Landmark CV), segmentation features perform similarly or slightly differently depending on the model, but neither CV modality outperforms the pure tabular baseline. Both encounter the same fundamental constraint: 2D image projections contain clothing occlusions, posture variations, and camera distance scale effects that cannot match the precision of physical clinical instruments.

### Question 3: Does combining both CV approaches help?
**Answer**: **No.** Combining all three modalities (Arm D: Measurement + Landmark CV + Segmentation) does not yield synergistic gains. In Random Forest, Arm D achieves 46.14% balanced accuracy; in SVM, Arm D achieves 58.81%. Expanding the feature space to 37 dimensions increases dimensionality without introducing novel independent physical information not already captured by the direct weight, height, and age records.

### Question 4: Which segmentation-derived features have usable coverage?
**Answer**: `total_arm_area` and `total_arm_area_norm` have **100% usable coverage** across all frontal images. Side-specific features (`left_arm_area`, `right_arm_area`, `left_arm_width`, etc.) have high coverage when both arms are unobstructed, but exhibit missingness (~5-15%) when children have one arm occluded by clothing, parents holding them, or cropped out of the frame. `aspect_ratio` has reliable coverage when arm silhouettes are well-formed.

### Question 5: What limitations remain?
1. **Projected 2D Silhouettes vs 3D Circumference**: Single-camera 2D segmentation measures cross-sectional silhouette width, NOT true cross-sectional perimeter (MUAC) or volumetric girth.
2. **Clothing & Pose Variability**: Natural field photographs in AnthroVision frequently feature loose clothing, diapers, or hands held by guardians that alter upper-arm boundaries.
3. **Camera Distance & Scale Ambiguity**: Without depth sensors or physical calibration targets, image-scale normalization relies entirely on landmark proxies (e.g. shoulder width), which themselves vary with child age and posture.
4. **Clinical Framing**: All models evaluate classification against WHO anthropometric thresholds, not clinical etiologies. No claim of medical diagnostic validity is made.

## 5. Confusion Matrices (Held-Out Test Set)

#### Arm A: Measurement-Only - RandomForest

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 205          | 14               | 5            | 1                            |
| True underweight             | 6            | 38               | 0            | 9                            |
| True stunted                 | 5            | 0                | 3            | 1                            |
| True stunted and underweight | 3            | 13               | 1            | 17                           |

#### Arm A: Measurement-Only - SVM_RBF

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 169          | 22               | 33           | 1                            |
| True underweight             | 0            | 46               | 2            | 5                            |
| True stunted                 | 3            | 0                | 6            | 0                            |
| True stunted and underweight | 1            | 4                | 3            | 26                           |

#### Arm B: Measurement + CV Landmarks - RandomForest

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 209          | 11               | 3            | 2                            |
| True underweight             | 10           | 37               | 0            | 6                            |
| True stunted                 | 8            | 0                | 0            | 1                            |
| True stunted and underweight | 8            | 14               | 0            | 12                           |

#### Arm B: Measurement + CV Landmarks - SVM_RBF

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 171          | 24               | 22           | 8                            |
| True underweight             | 2            | 40               | 1            | 10                           |
| True stunted                 | 3            | 1                | 4            | 1                            |
| True stunted and underweight | 1            | 12               | 4            | 17                           |

#### Arm C: Measurement + Segmentation - RandomForest

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 200          | 21               | 2            | 2                            |
| True underweight             | 9            | 37               | 0            | 7                            |
| True stunted                 | 9            | 0                | 0            | 0                            |
| True stunted and underweight | 11           | 12               | 0            | 11                           |

#### Arm C: Measurement + Segmentation - SVM_RBF

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 168          | 27               | 29           | 1                            |
| True underweight             | 2            | 39               | 1            | 11                           |
| True stunted                 | 4            | 0                | 4            | 1                            |
| True stunted and underweight | 1            | 7                | 2            | 24                           |

#### Arm D: Measurement + CV + Segmentation - RandomForest

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 200          | 19               | 2            | 4                            |
| True underweight             | 14           | 32               | 0            | 7                            |
| True stunted                 | 8            | 0                | 0            | 1                            |
| True stunted and underweight | 13           | 9                | 0            | 12                           |

#### Arm D: Measurement + CV + Segmentation - SVM_RBF

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 164          | 31               | 21           | 9                            |
| True underweight             | 3            | 36               | 0            | 14                           |
| True stunted                 | 5            | 0                | 4            | 0                            |
| True stunted and underweight | 2            | 10               | 5            | 17                           |
