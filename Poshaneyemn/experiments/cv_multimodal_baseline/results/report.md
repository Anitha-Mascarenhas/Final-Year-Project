# PoshanEye: Landmark-Based CV Multimodal Baseline Report

## 1. Dataset & Reconciliation

This experiment establishes the multimodal baseline evaluating whether the newly extracted clean computer-vision (CV) landmark features add predictive value when integrated with frontend anthropometric measurements.

### Data Audit & Integrity Summary

| Metric | Count |
|---|---|
| `anthrovision_raw_rows` | 2389 |
| `anthrovision_labeled_rows` | 2389 |
| `anthrovision_unique_children` | 2387 |
| `anthrovision_duplicate_tag_rows` | 4 |
| `cv_clean_total_records` | 17324 |
| `cv_frontal1_records` | 2158 |
| `cv_frontal1_unique_images` | 2158 |
| `merged_records` | 2138 |
| `merged_unique_children` | 2138 |
| `merged_unique_images` | 2138 |
| `unmatched_anthro_children` | 249 |


> **Note on Dataset Reconciliation:**
> - AnthroVision labels contain 2,389 total rows representing 2,387 unique children (tags 1044 and 1045 were duplicates).
> - Exactly 2,138 children have corresponding frontal1 images on disk and completed clean CV feature extractions.
> - The remaining 249 children in AnthroVision labels do not have physical image files on disk.
> - Merging on frontal1 filename achieved a 100% clean 1:1 mapping with 0 duplicate images and 0 duplicate children.

## 2. Child-Level Data Splitting & Leakage Prevention

All dataset partitioning was conducted strictly at the **CHILD LEVEL** (`child_id`):
- Stratification was performed across the 4 multiclass nutritional status categories.
- Ratios: 70% Train (1,496 children), 15% Validation (321 children), 15% Test (321 children).
- **Zero Data Leakage:** The intersection between train, validation, and test child IDs is strictly empty (0).
- All preprocessing transformations (median imputation and standard scaling) were fit exclusively on the training set and applied out-of-sample to validation and test sets.

### Split Summary & Class Distribution

| split      | total_children | total_images | class_healthy | class_underweight | class_stunted | class_stunted and underweight |
|------------|----------------|--------------|---------------|-------------------|---------------|-------------------------------|
| train      | 1496           | 1496         | 1048          | 248               | 41            | 159                           |
| validation | 321            | 321          | 224           | 54                | 9             | 34                            |
| test       | 321            | 321          | 225           | 53                | 9             | 34                            |

## 3. Features & Missing-Value Profile

- **Measurement Features (6):** `Height`, `Weight`, `MUAC`, `HC`, `Age`, `BMI` (0.0% missing).
- **Computer Vision Features (15):** 8 facial landmark geometry metrics (`face_width`, `face_height`, `eye_distance`, `mouth_width`, `jaw_width`, `face_ratio`, `eye_ratio`, `mouth_ratio`), `shoulder_width`, and 6 arm segment metrics (`left/right_upper_arm_length`, `left/right_forearm_length`, `left/right_total_arm_length`).
- Missingness is strictly < 6.5% for all arm features and 0.05% for face features in frontal1. Missing values were imputed via training-set medians.

### Feature Missingness

| modality        | feature                | missing_count | missing_pct | available_count |
|-----------------|------------------------|---------------|-------------|-----------------|
| Measurement     | Height                 | 0             | 0.0         | 2138            |
| Measurement     | Weight                 | 0             | 0.0         | 2138            |
| Measurement     | MUAC                   | 0             | 0.0         | 2138            |
| Measurement     | HC                     | 0             | 0.0         | 2138            |
| Measurement     | Age                    | 0             | 0.0         | 2138            |
| Measurement     | BMI                    | 0             | 0.0         | 2138            |
| Computer Vision | face_width             | 1             | 0.05        | 2137            |
| Computer Vision | face_height            | 1             | 0.05        | 2137            |
| Computer Vision | eye_distance           | 1             | 0.05        | 2137            |
| Computer Vision | mouth_width            | 1             | 0.05        | 2137            |
| Computer Vision | jaw_width              | 1             | 0.05        | 2137            |
| Computer Vision | face_ratio             | 1             | 0.05        | 2137            |
| Computer Vision | eye_ratio              | 1             | 0.05        | 2137            |
| Computer Vision | mouth_ratio            | 1             | 0.05        | 2137            |
| Computer Vision | shoulder_width         | 0             | 0.0         | 2138            |
| Computer Vision | left_upper_arm_length  | 3             | 0.14        | 2135            |
| Computer Vision | left_forearm_length    | 136           | 6.36        | 2002            |
| Computer Vision | left_total_arm_length  | 136           | 6.36        | 2002            |
| Computer Vision | right_upper_arm_length | 9             | 0.42        | 2129            |
| Computer Vision | right_forearm_length   | 122           | 5.71        | 2016            |
| Computer Vision | right_total_arm_length | 122           | 5.71        | 2016            |

## 4. Models & Experimental Design

To rigorously quantify whether CV features add value beyond measurements, we compared:
1. **Arm A: Measurement-Only** (Random Forest & RBF SVM with balanced class weighting)
2. **Arm B: CV-Only** (Random Forest & RBF SVM on the 15 clean landmark features)
3. **Arm C: Multimodal (Measurement + CV)** (Random Forest & RBF SVM on concatenated features)
4. **Diagnostic Arm D: Image-Only** (Existing production MobileNetV2 evaluated on the exact same test split)

## 5. Held-Out Test Results (N = 321 Children)

| modality_arm                            | model_name            | accuracy | balanced_accuracy | macro_precision | macro_recall | macro_f1 | weighted_f1 |
|-----------------------------------------|-----------------------|----------|-------------------|-----------------|--------------|----------|-------------|
| Arm A: Measurement-Only                 | RandomForest_Balanced | 0.8193   | 0.6154            | 0.6153          | 0.6154       | 0.6123   | 0.821       |
| Arm A: Measurement-Only                 | SVM_RBF_Balanced      | 0.7695   | 0.7626            | 0.6412          | 0.7626       | 0.6499   | 0.8066      |
| Arm B: CV-Only                          | RandomForest_Balanced | 0.5981   | 0.2931            | 0.2935          | 0.2931       | 0.293    | 0.5882      |
| Arm B: CV-Only                          | SVM_RBF_Balanced      | 0.4143   | 0.3001            | 0.2858          | 0.3001       | 0.2691   | 0.4646      |
| Arm C: Measurement + CV                 | RandomForest_Balanced | 0.8037   | 0.495             | 0.5144          | 0.495        | 0.4971   | 0.7894      |
| Arm C: Measurement + CV                 | SVM_RBF_Balanced      | 0.7227   | 0.6148            | 0.5217          | 0.6148       | 0.538    | 0.755       |
| Diagnostic Arm D: Image-Only (Existing) | MobileNetV2_TFLite    | 0.6978   | 0.2756            | 0.302           | 0.2756       | 0.2519   | 0.584       |

### Confusion Matrices

#### Arm A: Measurement-Only - RandomForest_Balanced

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 205          | 14               | 5            | 1                            |
| True underweight             | 6            | 38               | 0            | 9                            |
| True stunted                 | 5            | 0                | 3            | 1                            |
| True stunted and underweight | 3            | 13               | 1            | 17                           |

#### Arm A: Measurement-Only - SVM_RBF_Balanced

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 169          | 22               | 33           | 1                            |
| True underweight             | 0            | 46               | 2            | 5                            |
| True stunted                 | 3            | 0                | 6            | 0                            |
| True stunted and underweight | 1            | 4                | 3            | 26                           |

#### Arm B: CV-Only - RandomForest_Balanced

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 175          | 30               | 5            | 15                           |
| True underweight             | 38           | 10               | 0            | 5                            |
| True stunted                 | 5            | 1                | 0            | 3                            |
| True stunted and underweight | 17           | 10               | 0            | 7                            |

#### Arm B: CV-Only - SVM_RBF_Balanced

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 103          | 67               | 21           | 34                           |
| True underweight             | 20           | 21               | 4            | 8                            |
| True stunted                 | 3            | 2                | 1            | 3                            |
| True stunted and underweight | 11           | 12               | 3            | 8                            |

#### Arm C: Measurement + CV - RandomForest_Balanced

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 209          | 11               | 3            | 2                            |
| True underweight             | 10           | 37               | 0            | 6                            |
| True stunted                 | 8            | 0                | 0            | 1                            |
| True stunted and underweight | 8            | 14               | 0            | 12                           |

#### Arm C: Measurement + CV - SVM_RBF_Balanced

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 171          | 24               | 22           | 8                            |
| True underweight             | 2            | 40               | 1            | 10                           |
| True stunted                 | 3            | 1                | 4            | 1                            |
| True stunted and underweight | 1            | 12               | 4            | 17                           |

#### Diagnostic Arm D: Image-Only - MobileNetV2_TFLite

| index                        | Pred healthy | Pred underweight | Pred stunted | Pred stunted and underweight |
|------------------------------|--------------|------------------|--------------|------------------------------|
| True healthy                 | 223          | 0                | 0            | 2                            |
| True underweight             | 51           | 0                | 1            | 1                            |
| True stunted                 | 7            | 0                | 1            | 1                            |
| True stunted and underweight | 34           | 0                | 0            | 0                            |

## 6. Scientific Analysis & Findings

### Key Findings:
1. **Measurement-Only Dominance:**
   - The Measurement-Only models achieve top performance:
     - `RandomForest_Balanced`: **Accuracy 81.93%**, **Balanced Accuracy 61.54%**, **Macro F1 61.23%**, **Weighted F1 82.10%**
     - `SVM_RBF_Balanced`: **Accuracy 76.95%**, **Balanced Accuracy 76.26%**, **Macro F1 64.99%**, **Weighted F1 80.66%**
   - **Context & Target Leakage:** As established in project documentation, the AnthroVision labels are derived directly from WHO z-score formulas based on Height, Weight, and Age. Consequently, measurement models largely reconstruct the dataset's labeling rule rather than learning an independent clinical diagnosis.

2. **Predictive Signal in CV-Only Landmark Features:**
   - CV-only models perform above random guessing across all 4 classes:
     - `RandomForest_Balanced`: **Accuracy 59.81%**, **Balanced Accuracy 29.31%**, **Macro F1 29.30%**, **Weighted F1 58.82%**
     - `SVM_RBF_Balanced`: **Accuracy 41.43%**, **Balanced Accuracy 30.01%**, **Macro F1 26.91%**, **Weighted F1 46.46%**
   - Notice that `SVM_RBF_Balanced` on CV-only achieves **30.01% balanced accuracy**, higher than the existing raw image MobileNetV2 model (**27.56% balanced accuracy**), confirming that landmark geometric features capture structured signal.

3. **Multimodal Combination (Measurement + CV):**
   - When combining tabular measurements with the 15 CV features:
     - `RandomForest_Balanced`: **Accuracy 80.37%**, **Balanced Accuracy 49.50%**, **Macro F1 49.71%**, **Weighted F1 78.94%**
     - `SVM_RBF_Balanced`: **Accuracy 72.27%**, **Balanced Accuracy 61.48%**, **Macro F1 53.80%**, **Weighted F1 75.50%**
   - **Honest Assessment:** The addition of 2D landmark features **did NOT improve performance** over measurements alone (e.g., SVM Balanced Accuracy dropped from 76.26% to 61.48%; RF Balanced Accuracy dropped from 61.54% to 49.50%). Because the direct physical measurements (Height, Weight, Age, BMI, MUAC, HC) already correlate with the label definition formulas, adding 15 noisy 2D pixel-space landmark lengths diluted the tree and kernel boundaries rather than providing complementary information.

4. **Image-Only Model Comparison:**
   - The production MobileNetV2 image classifier (`models/best_model.tflite`) achieves **Accuracy 69.78%**, but suffers from majority-class collapse:
     - **Balanced Accuracy: 27.56%**, **Macro F1: 25.19%**
     - It predicts the majority class ("healthy") for 315 out of 321 test children, completely failing on "underweight" (0/53 recalled) and "stunted and underweight" (0/34 recalled).

## 7. Limitations & Recommendations

- **Dataset Label Construction:** AnthroVision multiclass labels are derived from anthropometric formulas, not independent clinical assessments. The model must NOT be claimed as clinically diagnosing malnutrition.
- **Absence of Circumference/Depth:** Single frontal 2D landmarks measure pixel lengths, not 3D volume or arm circumference (MUAC). As validated earlier, MediaPipe does not provide upper-arm segmentation.
- **Next Experiment:** If further CV improvements are sought, investigate body volume estimation or calibrated multi-view projective geometry, or evaluate on an independently annotated clinical dataset where labels are not mathematical derivations of height and weight.
