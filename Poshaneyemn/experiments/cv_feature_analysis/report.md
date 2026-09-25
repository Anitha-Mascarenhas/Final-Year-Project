# CV Feature Analysis & Diagnostic Investigation Report

**Author:** PoshanEye Diagnostic Pipeline  
**Date:** 2026-09-23  
**Directory:** `experiments/cv_feature_analysis/`  
**Protocol:** Child-Level Stratified Split (70/15/15), Random State = 42 (Identical to `cv_multimodal_baseline`)  

---

## 1. Executive Summary

In this diagnostic investigation, we systematically analyzed the 2D computer vision (CV) landmark features extracted from AnthroVision to explain **why computer vision features do not improve upon the measurement-only baseline (Balanced Accuracy ~76.26%, Macro F1 ~0.6499)**.

All labels in this study are derived from measurement-based anthropometric criteria (WHO z-scores on Height, Weight, MUAC, HC, Age, and BMI), rather than independent clinical diagnoses.

### Key Audited Findings:
1. **Dominant Global Scale-Related Variation:** Principal Component 1 (PC1) accounts for **71.35%** of the variance across the 15 primary CV landmark features. PC1 demonstrates near-uniform high positive correlations ($r \ge 0.90$) with all raw pixel distance measurements, including `shoulder_width` ($r = 0.9532$), `face_width` ($r = 0.9081$), `left_upper_arm_length` ($r = 0.9537$), and `image_scale_proxy` ($r = 0.9623$). In the absence of ground-truth camera distance recordings, PC1 captures a dominant global scale-related variation in the landmark measurements (combining framing distance, zoom, and physical body size).
2. **Ablation Performance vs. Random Baselines:** On the 4-class task, a **uniform random classifier** achieves an expected balanced accuracy of **25.00%**, while a **majority-class classifier** achieves **25.00% balanced accuracy** (accuracy 70.09%). The CV-only models achieve balanced accuracies between **23.10% and 32.65%** (Macro F1 between **0.2073 and 0.2930**). The 15-feature baseline Random Forest model achieves **29.31% balanced accuracy**, which is only **4.31% above the random baseline**.
3. **Severe Collinearity & Feature Redundancy:** Landmark features demonstrate extreme collinearity. 36 feature pairs exhibit $|r| \ge 0.85$. In particular, bilateral limb measurements are near-perfect linear duplicates: `left_upper_arm_length` vs `right_upper_arm_length` has $r = 0.9764$, `left_forearm_length` vs `right_forearm_length` has $r = 0.9532$, and `left_total_arm_length` vs `right_total_arm_length` has $r = 0.9811$. Including bilateral measurements duplicates model parameters without supplying independent diagnostic information.
4. **Scale-Normalization (Ratios):** Normalizing landmark lengths by shoulder width or face width creates scale-invariant ratios, but reduces balanced accuracy to **27.46% (RF)** and **26.05% (SVM)** with Macro F1 dropping to **0.2733 (RF)** and **0.2336 (SVM)**. Computing ratios of 2D landmark coordinates compounds landmark localization jitter and posture rotation angle variations.
5. **Class Separation & Stunted Dynamics:** In PCA space, the maximum Euclidean distance between any two class centroids is **0.9855**, compared to a PC1 standard deviation of **3.2716**. The PCA projection shows substantial overlap among nutritional classes. Stunted children (N=59, 2.76% of dataset; N=9 in test set) suffer from severe recall collapse in CV models (recall = 0.0000 in RF, 0.1111 in SVM with only 1 true positive out of 9), because in 2D photographs without metric calibration, a shorter child positioned closer to the camera produces pixel lengths comparable to an older child positioned further away.

---

## 2. Experimental Setup & Audit

- **Total Matched Children:** 2,138 unique children (zero child leakage across splits).
- **Child Splits:** Train = 1,496 children (70%), Validation = 321 children (15%), Held-Out Test = 321 children (15%).
- **Random Seed:** 42 (strictly frozen in `split_indices.json`).
- **Leakage Prevention:** Median imputation and StandardScaler fitted strictly on the train split and applied out-of-sample to validation and test splits.
- **Label Foundation:** Anthropometric measurement-based labels defined by WHO z-score thresholds on anthropometric measurements (`Height`, `Weight`, `MUAC`, `HC`, `Age`, `BMI`).

---

## 3. Feature Group Ablation Results

Performance evaluated on the held-out test split (N=321 children):

| Feature_Group | Model | Num_Features | Accuracy | Balanced_Accuracy | Macro_Precision | Macro_Recall | Macro_F1 | Weighted_F1 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A: Face Geometry | RF_Balanced | 8 | 0.5545 | 0.2811 | 0.2762 | 0.2811 | 0.2784 | 0.5568 |
| A: Face Geometry | SVM_Balanced | 8 | 0.3738 | 0.2650 | 0.2690 | 0.2650 | 0.2416 | 0.4344 |
| B: Shoulder Geometry | RF_Balanced | 1 | 0.3988 | 0.2388 | 0.2405 | 0.2388 | 0.2275 | 0.4467 |
| B: Shoulder Geometry | SVM_Balanced | 1 | 0.4891 | 0.2638 | 0.2486 | 0.2638 | 0.2380 | 0.5009 |
| C: Upper-Arm Lengths | RF_Balanced | 2 | 0.4517 | 0.2310 | 0.2336 | 0.2310 | 0.2290 | 0.4791 |
| C: Upper-Arm Lengths | SVM_Balanced | 2 | 0.2773 | 0.3265 | 0.3005 | 0.3265 | 0.2166 | 0.2995 |
| D: Forearm Lengths | RF_Balanced | 2 | 0.4860 | 0.2521 | 0.2500 | 0.2521 | 0.2471 | 0.5108 |
| D: Forearm Lengths | SVM_Balanced | 2 | 0.2648 | 0.3004 | 0.2883 | 0.3004 | 0.2073 | 0.2995 |
| E: Arm-to-Shoulder Ratios | RF_Balanced | 6 | 0.5358 | 0.2584 | 0.2576 | 0.2584 | 0.2578 | 0.5410 |
| E: Arm-to-Shoulder Ratios | SVM_Balanced | 6 | 0.3769 | 0.3230 | 0.2933 | 0.3230 | 0.2666 | 0.4322 |
| F: Face + Arm Features | RF_Balanced | 11 | 0.5763 | 0.2863 | 0.2826 | 0.2863 | 0.2844 | 0.5733 |
| F: Face + Arm Features | SVM_Balanced | 11 | 0.4393 | 0.3068 | 0.2731 | 0.3068 | 0.2572 | 0.4882 |
| G: All CV Features (15 Baseline) | RF_Balanced | 15 | 0.5981 | 0.2931 | 0.2935 | 0.2931 | 0.2930 | 0.5882 |
| G: All CV Features (15 Baseline) | SVM_Balanced | 15 | 0.4143 | 0.3001 | 0.2858 | 0.3001 | 0.2691 | 0.4646 |
| Normalized CV (Ratios) | RF_Balanced | 10 | 0.5888 | 0.2746 | 0.2722 | 0.2746 | 0.2733 | 0.5816 |
| Normalized CV (Ratios) | SVM_Balanced | 10 | 0.3458 | 0.2605 | 0.2730 | 0.2605 | 0.2336 | 0.4079 |
| **H: Measurement-Only Baseline** | **RF_Balanced** | 6 | **0.8193** | **0.6154** | **0.6153** | **0.6154** | **0.6123** | **0.8210** |
| **H: Measurement-Only Baseline** | **SVM_Balanced** | 6 | **0.7695** | **0.7626** | **0.6412** | **0.7626** | **0.6499** | **0.8066** |

### Benchmark Against Standard Baselines:
- **Uniform Random Guessing Baseline:** Expected Balanced Accuracy = **25.00%**, Expected Accuracy = **25.00%**.
- **Majority-Class Baseline ("always predict healthy"):** Balanced Accuracy = **25.00%**, Accuracy = **70.09%**.
- **CV Models vs. Baselines:**
  - Random Forest on All 15 CV features achieves **29.31% Balanced Accuracy**, which is an absolute gain of only **+4.31%** over random assignment.
  - RBF SVM on All 15 CV features achieves **30.01% Balanced Accuracy** (+5.01% over random), with overall accuracy dropping to **41.43%**.
  - Meanwhile, the Measurement-Only RBF SVM baseline achieves **76.26% Balanced Accuracy** (+51.26% over random) and Macro F1 of **0.6499**.

---

## 4. PCA & Global Scale Analysis

Principal Component Analysis (PCA) was fitted on the standardized 15 CV features across the 2,138 children.

### Variance Explained:
- **PC1:** **71.35%**
- **PC2:** **9.08%**
- **Cumulative (PC1 + PC2):** **80.43%**

### Quantitative Correlation with Scale Proxies:
To evaluate what PC1 represents, we computed Pearson correlation coefficients between PC1 and major distance/scale proxies:

| Scale Proxy | Pearson $r$ with PC1 | $p$-value |
|---|---|---|
| `image_scale_proxy` (`shoulder_width` + arm lengths) | **+0.9623** | $< 10^{-15}$ |
| `left_upper_arm_length` | **+0.9537** | $< 10^{-15}$ |
| `shoulder_width` | **+0.9532** | $< 10^{-15}$ |
| `right_upper_arm_length` | **+0.9468** | $< 10^{-15}$ |
| `face_width` | **+0.9081** | $< 10^{-15}$ |

### Feature Loadings on PC1:
All 12 primary pixel-distance features load positively and nearly uniformly onto PC1 (loadings between **+0.2689 and +0.2915**):
- `left_upper_arm_length`: +0.2915
- `shoulder_width`: +0.2914
- `right_upper_arm_length`: +0.2893
- `right_total_arm_length`: +0.2879
- `left_total_arm_length`: +0.2876
- `face_height`: +0.2868
- `right_forearm_length`: +0.2789
- `face_width`: +0.2776
- `mouth_width`: +0.2775
- `left_forearm_length`: +0.2756
- `jaw_width`: +0.2750
- `eye_distance`: +0.2689

Only the ratio features have small loadings (`mouth_ratio`: +0.0850, `eye_ratio`: -0.0814, `face_ratio`: -0.1704).

**Conclusion:** PC1 captures a **dominant global scale-related variation in the landmark measurements**. Because camera-to-subject distance was not independently recorded with metric fiducials, PC1 combines framing distance, digital zoom, and anatomical body scale into an unseparated scalar.

---

## 5. Quantitative Class Separation in Representation Space

To assess whether nutritional classes cluster distinctly in CV feature space, we analyzed class centroids and dispersions in the (PC1, PC2) projection:

### Class Centroids:
| Class | Mean PC1 | Mean PC2 |
|---|---|---|
| `healthy` | +0.1921 | -0.0001 |
| `underweight` | -0.2402 | +0.1833 |
| `stunted` | -0.4311 | -0.4570 |
| `stunted and underweight` | -0.7791 | -0.1674 |

### Pairwise Euclidean Distances Between Centroids:
| Class | `healthy` | `underweight` | `stunted` | `stunted and underweight` |
|---|---|---|---|---|
| `healthy` | 0.0000 | 0.4696 | 0.7727 | **0.9855** |
| `underweight` | 0.4696 | 0.0000 | 0.6682 | 0.6430 |
| `stunted` | 0.7727 | 0.6682 | 0.0000 | 0.4528 |
| `stunted and underweight` | 0.9855 | 0.6430 | 0.4528 | 0.0000 |

### Separation vs. Dispersion:
- **Standard Deviation of PC1 across population:** **3.2716** (variance = 10.70).
- **Maximum distance between any two class centroids:** **0.9855** (between `healthy` and `stunted and underweight`).
- **Centroid distance to spread ratio:** The separation between the two furthest class centers is less than **0.30 standard deviations** of PC1.
- While an ANOVA test across classes confirms a statistically detectable shift ($F = 7.05, p = 1.03 \times 10^{-4}$ for PC1; $F = 7.55, p = 5.01 \times 10^{-5}$ for PC2), the between-class variance is dwarfed by the within-class spread.

**Conclusion:** The PCA projection shows **substantial overlap among nutritional classes**, rather than discrete, separable clusters.

---

## 6. Feature Redundancy & Collinearity

Features with Pearson correlation coefficient $|r| \ge 0.85$ are severely redundant:

### Bilateral Symmetry & Segment Collinearity:
| Feature 1 | Feature 2 | Pearson $r$ | Diagnostic Meaning |
|---|---|---|---|
| `left_upper_arm_length` | `right_upper_arm_length` | **0.9764** | Near-perfect bilateral symmetry |
| `left_forearm_length` | `right_forearm_length` | **0.9532** | Near-perfect bilateral symmetry |
| `left_total_arm_length` | `right_total_arm_length` | **0.9811** | Near-perfect bilateral symmetry |
| `left_upper_arm_length` | `left_total_arm_length` | **0.9848** | Part-to-whole collinearity |
| `right_upper_arm_length` | `right_total_arm_length` | **0.9870** | Part-to-whole collinearity |
| `face_width` | `jaw_width` | **0.9993** | Duplicate facial width measurement |
| `face_width` | `eye_distance` | **0.9843** | Facial structural collinearity |
| `face_width` | `face_height` | **0.9760** | Global facial box collinearity |
| `shoulder_width` | `left_upper_arm_length` | **0.9259** | Shared camera scale confound |
| `shoulder_width` | `right_upper_arm_length` | **0.9208** | Shared camera scale confound |
| `shoulder_width` | `face_width` | **0.8903** | Shared camera scale confound |

**Conclusion:** 36 feature pairs exhibit $|r| \ge 0.85$. Bilateral inclusion of both left and right limbs inflates dimensionality without introducing orthogonal variance.

---

## 7. Scale-Normalized CV Features (Ratios)

We constructed 10 scale-invariant ratio features:
- `norm_face_width_to_shoulder` = `face_width / shoulder_width`
- `norm_face_height_to_shoulder` = `face_height / shoulder_width`
- `norm_eye_distance_to_face_w` = `eye_distance / face_width`
- `norm_mouth_width_to_face_w` = `mouth_width / face_width`
- `norm_left_upper_arm_to_shoulder` = `left_upper_arm_length / shoulder_width`
- `norm_right_upper_arm_to_shoulder` = `right_upper_arm_length / shoulder_width`
- `norm_left_forearm_to_shoulder` = `left_forearm_length / shoulder_width`
- `norm_right_forearm_to_shoulder` = `right_forearm_length / shoulder_width`
- `norm_left_total_arm_to_shoulder` = `left_total_arm_length / shoulder_width`
- `norm_right_total_arm_to_shoulder` = `right_total_arm_length / shoulder_width`

### Held-Out Test Evaluation Comparison:
| Metric | All 15 Raw CV Features | 10 Scale-Normalized CV Ratios | Clinical Measurements Baseline |
|---|---|---|---|
| **RF Balanced Accuracy** | 29.31% | **27.46%** (-1.85%) | **61.54%** |
| **RF Macro F1** | 0.2930 | **0.2733** (-0.0197) | **0.6123** |
| **SVM Balanced Accuracy** | 30.01% | **26.05%** (-3.96%) | **76.26%** |
| **SVM Macro F1** | 0.2691 | **0.2336** (-0.0355) | **0.6499** |

**Conclusion:** Constructing scale ratios did **not** improve classification performance; in fact, balanced accuracy dropped by 1.85% to 3.96%. Ratios of landmark lengths are sensitive to posture variance (e.g., slight torso rotation distorts `shoulder_width` significantly while leaving arm length unchanged), magnifying measurement noise.

---

## 8. Class Imbalance & Per-Class Recall Analysis

### Exact Class Distribution:
| Class | Matched Dataset (N=2,138) | % | Held-Out Test Set (N=321) | % |
|---|---|---|---|---|
| `healthy` | 1,497 | 70.02% | 225 | 70.09% |
| `underweight` | 355 | 16.60% | 53 | 16.51% |
| `stunted and underweight` | 227 | 10.62% | 34 | 10.59% |
| `stunted` | 59 | 2.76% | 9 | 2.80% |

### Per-Class Test Performance (All 15 CV Features vs Measurement Baseline):

#### 1. All CV Features — Random Forest (Balanced):
| Class | Precision | Recall | F1-Score | Support |
|---|---|---|---|---|
| `healthy` | 0.7447 | 0.7778 | 0.7609 | 225 |
| `underweight` | 0.1961 | 0.1887 | 0.1923 | 53 |
| `stunted and underweight` | 0.2333 | 0.2059 | 0.2188 | 34 |
| `stunted` | **0.0000** | **0.0000** | **0.0000** | 9 |

*Observation:* The Random Forest model completely collapsed on the `stunted` class (0 out of 9 detected).

#### 2. All CV Features — RBF SVM (Balanced):
| Class | Precision | Recall | F1-Score | Support |
|---|---|---|---|---|
| `healthy` | 0.7518 | 0.4578 | 0.5691 | 225 |
| `underweight` | 0.2059 | 0.3962 | 0.2710 | 53 |
| `stunted and underweight` | 0.1509 | 0.2353 | 0.1839 | 34 |
| `stunted` | **0.0345** | **0.1111** | **0.0526** | 9 |

*Observation:* The SVM model detected only 1 true positive for `stunted` out of 9 (Recall = 11.11%) with 28 false positives (Precision = 3.45%).

#### 3. Measurement-Only Baseline — RBF SVM (Balanced):
| Class | Precision | Recall | F1-Score | Support |
|---|---|---|---|---|
| `healthy` | 0.9769 | 0.7511 | 0.8492 | 225 |
| `underweight` | 0.6389 | 0.8679 | 0.7360 | 53 |
| `stunted and underweight` | 0.8125 | 0.7647 | 0.7879 | 34 |
| `stunted` | **0.1364** | **0.6667** | **0.2264** | 9 |

*Observation:* The measurement-only model correctly identifies 6 out of 9 `stunted` children (Recall = 66.67%) and achieves high recall across all malnourished categories (>76%).

---

## 9. View Availability Analysis

| View | Total Images | Face Avail (%) | Shoulder Avail (%) | Left Arm Avail (%) | Right Arm Avail (%) |
|---|---|---|---|---|---|
| `frontal1` | 2,158 | **100.0%** | **100.0%** | **99.9%** | **99.6%** |
| `frontal2` | 2,142 | **100.0%** | **100.0%** | **99.8%** | **99.7%** |
| `frontal3` | 2,129 | **100.0%** | **100.0%** | **99.8%** | **99.8%** |
| `frontal4` | 2,067 | **100.0%** | **100.0%** | **100.0%** | **99.9%** |
| `lateralright` | 2,148 | 0.0% | 100.0% | 100.0% | 1.0% |
| `lateralleft` | 2,145 | 0.0% | 99.8% | 1.6% | 99.7% |
| `selfie` | 2,159 | 0.0% | 100.0% | 18.9% | 41.9% |
| `back` | 2,127 | 0.0% | 0.0% | 0.0% | 0.0% |
| `handswide` | 249 | 0.0% | 100.0% | 100.0% | 100.0% |

- Non-frontal views suffer from severe view-dependent feature dropout (e.g., lateral views capture only one arm and 0% face landmarks; back view has 0% detection).
- Combining multi-view landmark vectors is hindered by structural missingness unless models are explicitly designed for asymmetric sparse inputs.

---

## 10. Limitations & Scientific Assessment

1. **Absence of Calibrated Metric Reference:** 2D bounding lengths in pixels cannot differentiate a tall subject standing further back from a short subject standing closer.
2. **Skeletal Landmark Limitation:** MediaPipe landmarks measure inter-joint bone distances. Anthropometric malnutrition is defined by soft-tissue depletion (wasting / low MUAC) or age-standardized height deficit (stunting). Inter-joint lengths do not reflect limb girth or cross-sectional tissue volume.
3. **No Claim of Clinical Utility:** The current 2D CV landmark features cannot be described as providing clinically useful diagnostic predictions for child malnutrition.
