# PoshanEye Production Hybrid Pipeline - Training & Comparison Report

All arms evaluated on the SAME frozen child-level test split (321 children, zero overlap with train/val).

## Arms (SVM_RBF_Balanced, the existing repo classifier family)

| arm | accuracy | macro_precision | macro_recall | macro_f1 | weighted_f1 | balanced_accuracy |
|---|---|---|---|---|---|---|
| 1_anthropometric_only | 0.7352 | 0.5981 | 0.736 | 0.6128 | 0.7755 | 0.736 |
| 2_cv_only | 0.4143 | 0.2923 | 0.3261 | 0.2746 | 0.4594 | 0.3261 |
| 3_segmentation_only | 0.3583 | 0.3025 | 0.3108 | 0.2558 | 0.4291 | 0.3108 |
| 4_image_only_features | 0.5358 | 0.3935 | 0.4085 | 0.37 | 0.5719 | 0.4085 |
| 5_anthro_plus_cv | 0.6916 | 0.4889 | 0.5573 | 0.5005 | 0.7198 | 0.5573 |
| 6_anthro_plus_cv_plus_seg | 0.704 | 0.5114 | 0.5858 | 0.5303 | 0.7292 | 0.5858 |
| 7_full_image_plus_cv_plus_seg_plus_anthro | 0.6791 | 0.6463 | 0.4671 | 0.4623 | 0.6899 | 0.4671 |

## RandomForest reference

| arm | accuracy | macro_f1 | balanced_accuracy |
|---|---|---|---|
| 1_anthropometric_only [RF reference] | 0.8224 | 0.5949 | 0.5872 |
| 2_cv_only [RF reference] | 0.6075 | 0.2867 | 0.2892 |
| 3_segmentation_only [RF reference] | 0.5888 | 0.2799 | 0.2835 |
| 4_image_only_features [RF reference] | 0.6511 | 0.2671 | 0.2736 |
| 5_anthro_plus_cv [RF reference] | 0.7695 | 0.4974 | 0.4897 |
| 6_anthro_plus_cv_plus_seg [RF reference] | 0.7695 | 0.5051 | 0.4852 |
| 7_full_image_plus_cv_plus_seg_plus_anthro [RF reference] | 0.7227 | 0.372 | 0.3729 |

## Confusion matrices (SVM, rows=true, cols=pred; classes: healthy / underweight / stunted / stunted and underweight)

## Full-model test metrics by class

| Class | Precision | Recall | F1 | Support |
|---|---:|---:|---:|---:|
| healthy | 0.8564 | 0.7689 | 0.8103 | 225 |
| underweight | 0.4028 | 0.5472 | 0.4640 | 53 |
| stunted | 1.0000 | 0.1111 | 0.2000 | 9 |
| stunted and underweight | 0.3261 | 0.4412 | 0.3750 | 34 |

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
[[88 29 60 48]
 [15 10 10 18]
 [ 1  4  2  2]
 [ 6  6  7 15]]
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
[[167  36  17   5]
 [  7  36   0  10]
 [  4   0   3   2]
 [  4   9   1  20]]
```

### 7_full_image_plus_cv_plus_seg_plus_anthro

```
[[173  32   0  20]
 [ 16  29   0   8]
 [  4   1   1   3]
 [  9  10   0  15]]
```
