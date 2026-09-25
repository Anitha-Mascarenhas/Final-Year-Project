# PoshanEye Production Hybrid Pipeline - Training & Comparison Report

All arms evaluated on the SAME frozen child-level test split (321 children, zero overlap with train/val).

## Arms (SVM_RBF_Balanced, the existing repo classifier family)

| arm | accuracy | macro_precision | macro_recall | macro_f1 | weighted_f1 | balanced_accuracy |
|---|---|---|---|---|---|---|
| 1_anthropometric_only | 0.7352 | 0.5981 | 0.736 | 0.6128 | 0.7755 | 0.736 |
| 2_cv_only | 0.4143 | 0.2923 | 0.3261 | 0.2746 | 0.4594 | 0.3261 |
| 3_segmentation_only | 0.3863 | 0.3391 | 0.3484 | 0.2836 | 0.4619 | 0.3484 |
| 4_image_only_features | 0.5358 | 0.3935 | 0.4085 | 0.37 | 0.5719 | 0.4085 |
| 5_anthro_plus_cv | 0.6916 | 0.4889 | 0.5573 | 0.5005 | 0.7198 | 0.5573 |
| 6_anthro_plus_cv_plus_seg | 0.6947 | 0.5027 | 0.5966 | 0.5274 | 0.7193 | 0.5966 |
| 7_full_image_plus_cv_plus_seg_plus_anthro | 0.676 | 0.5211 | 0.466 | 0.4571 | 0.6874 | 0.466 |

## RandomForest reference

| arm | accuracy | macro_f1 | balanced_accuracy |
|---|---|---|---|
| 1_anthropometric_only [RF reference] | 0.8224 | 0.5949 | 0.5872 |
| 2_cv_only [RF reference] | 0.6075 | 0.2867 | 0.2892 |
| 3_segmentation_only [RF reference] | 0.5545 | 0.259 | 0.2631 |
| 4_image_only_features [RF reference] | 0.6511 | 0.2671 | 0.2736 |
| 5_anthro_plus_cv [RF reference] | 0.7695 | 0.4974 | 0.4897 |
| 6_anthro_plus_cv_plus_seg [RF reference] | 0.7539 | 0.4508 | 0.4457 |
| 7_full_image_plus_cv_plus_seg_plus_anthro [RF reference] | 0.7134 | 0.3762 | 0.3758 |

## Confusion matrices (SVM, rows=true, cols=pred; classes: healthy / underweight / stunted / stunted and underweight)

### 1_anthropometric_only

```
[[162  25  37   1]
 [  0  42   1  10]
 [  3   0   6   0]
 [  1   5   2  26]]
```

### 2_cv_only

```
[[100  75  28  22]
 [ 17  26   4   6]
 [  4   1   2   2]
 [ 13  13   3   5]]
```

### 3_segmentation_only

```
[[95 21 60 49]
 [14 12 14 13]
 [ 1  2  3  3]
 [ 7  1 12 14]]
```

### 4_image_only_features

```
[[132  46   2  45]
 [ 18  20   1  14]
 [  3   3   1   2]
 [  6   9   0  19]]
```

### 5_anthro_plus_cv

```
[[166  33  20   6]
 [  4  38   0  11]
 [  5   0   3   1]
 [  5  11   3  15]]
```

### 6_anthro_plus_cv_plus_seg

```
[[165  33  17  10]
 [  6  36   0  11]
 [  5   0   4   0]
 [  5  10   1  18]]
```

### 7_full_image_plus_cv_plus_seg_plus_anthro

```
[[172  32   1  20]
 [ 16  29   0   8]
 [  4   1   1   3]
 [  9  10   0  15]]
```
