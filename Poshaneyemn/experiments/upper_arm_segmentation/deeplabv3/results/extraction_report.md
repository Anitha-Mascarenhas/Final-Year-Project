# DeepLabV3+ Upper-Arm Segmentation Feature Extraction Report

## 1. Overview

- **Total target images processed**: 2138
- **Successful mask predictions**: 2138 (100.00%)
- **Missing/corrupted images**: 0 (0.00%)
- **Total inference runtime**: 1786.0 s (29.77 min)
- **Throughput**: 1.20 images/second

## 2. Detection Distribution

| Detected Upper Arms | Count | Percentage |
|---|---|---|
| 2 arms detected (both sides) | 2053 | 96.02% |
| 1 arm detected (single side) | 76 | 3.55% |
| 0 arms detected (empty mask) | 9 | 0.42% |

## 3. Feature Missingness Profile

| Feature | Available Count | Missing Count | Missingness % |
|---|---|---|---|
| `total_arm_area` | 2138 | 0 | 0.00% |
| `left_arm_area` | 2080 | 58 | 2.71% |
| `right_arm_area` | 2102 | 36 | 1.68% |
| `left_arm_width` | 2080 | 58 | 2.71% |
| `right_arm_width` | 2102 | 36 | 1.68% |
| `left_arm_height` | 2080 | 58 | 2.71% |
| `right_arm_height` | 2102 | 36 | 1.68% |
| `left_arm_aspect_ratio` | 2080 | 58 | 2.71% |
| `right_arm_aspect_ratio` | 2102 | 36 | 1.68% |
| `total_arm_area_norm` | 2129 | 9 | 0.42% |
| `left_arm_area_norm` | 2080 | 58 | 2.71% |
| `right_arm_area_norm` | 2102 | 36 | 1.68% |
| `left_arm_width_norm` | 2080 | 58 | 2.71% |
| `right_arm_width_norm` | 2102 | 36 | 1.68% |
| `left_arm_height_norm` | 2080 | 58 | 2.71% |
| `right_arm_height_norm` | 2102 | 36 | 1.68% |


## 4. Summary Statistics (Available Values)

| Feature | Mean | Std | Min | Median | Max |
|---|---|---|---|---|---|
| `total_arm_area` | 2140.0332 | 1425.3724 | 0.0 | 1741.0 | 9251.0 |
| `left_arm_area` | 1081.6745 | 743.2888 | 151.0 | 878.5 | 6092.0 |
| `right_arm_area` | 1106.3311 | 703.4178 | 153.0 | 909.0 | 4956.0 |
| `left_arm_width` | 23.2707 | 10.6549 | 7.0 | 20.0 | 88.0 |
| `right_arm_width` | 23.852 | 10.1792 | 7.0 | 21.0 | 72.0 |
| `left_arm_height` | 60.45 | 15.7179 | 24.0 | 60.0 | 116.0 |
| `right_arm_height` | 62.4981 | 15.8392 | 22.0 | 62.0 | 112.0 |
| `left_arm_aspect_ratio` | 2.839 | 0.7113 | 1.1023 | 2.8182 | 5.5 |
| `right_arm_aspect_ratio` | 2.8198 | 0.6602 | 0.8596 | 2.8333 | 5.4444 |
| `total_arm_area_norm` | 0.2124 | 0.0814 | 0.0235 | 0.2065 | 2.2247 |
| `left_arm_area_norm` | 0.1054 | 0.0405 | 0.0215 | 0.1007 | 0.6999 |
| `right_arm_area_norm` | 0.1108 | 0.0473 | 0.0235 | 0.1072 | 1.5247 |
| `left_arm_width_norm` | 0.2313 | 0.0536 | 0.0909 | 0.23 | 0.7747 |
| `right_arm_width_norm` | 0.2394 | 0.05 | 0.084 | 0.237 | 0.9296 |
| `left_arm_height_norm` | 0.6344 | 0.1391 | 0.287 | 0.6441 | 1.3324 |
| `right_arm_height_norm` | 0.6578 | 0.1417 | 0.2592 | 0.6725 | 2.2 |


## 5. Critical Methodological & Clinical Notes

1. **Projected 2D Geometry Only**: These features represent projected 2D silhouettes in pixel coordinates from a single frontal camera view. They do NOT represent 3D anatomical circumference or volume.
2. **NOT Mid-Upper Arm Circumference (MUAC)**: Pixel silhouette width and area must never be conflated with physical tape-measured MUAC.
3. **Non-Fabrication Policy**: Missing or occluded arms are encoded strictly as NaN and were not imputed during feature extraction.
4. **Left/Right Coordinate Convention**: Due to binary mask training, left vs right designation strictly reflects image-space horizontal orientation (viewer perspective: $X < 256$ for left, $X \ge 256$ for right), not verified anatomical chirality.
5. **Scale Normalization**: Normalized features use `shoulder_width_512 = hypot(right_shoulder_x - left_shoulder_x, right_shoulder_y - left_shoulder_y) * 512`, where MediaPipe coordinates are normalized to [0,1]. Lengths divide by this reference and areas divide by its square.

6. **Production Feature Statistics**: The table below covers the exact 11 segmentation features consumed by the hybrid model.

| Feature | Min | Max | Mean | Std | Median |
|---|---:|---:|---:|---:|---:|
| `total_arm_area_norm` | 0.023467 | 2.224651 | 0.212414 | 0.08139 | 0.206501 |
| `left_arm_area_norm` | 0.021509 | 0.699944 | 0.105398 | 0.040495 | 0.100736 |
| `right_arm_area_norm` | 0.023467 | 1.524707 | 0.110848 | 0.047343 | 0.107245 |
| `left_arm_width_norm` | 0.090856 | 0.774654 | 0.231267 | 0.053609 | 0.230036 |
| `right_arm_width_norm` | 0.083991 | 0.929585 | 0.239366 | 0.049984 | 0.236968 |
| `left_arm_height_norm` | 0.287001 | 1.332405 | 0.634443 | 0.13909 | 0.64415 |
| `right_arm_height_norm` | 0.259156 | 2.200018 | 0.657766 | 0.141737 | 0.672472 |
| `left_arm_aspect_ratio` | 1.102273 | 5.5 | 2.839028 | 0.711287 | 2.818182 |
| `right_arm_aspect_ratio` | 0.859649 | 5.444444 | 2.819795 | 0.660179 | 2.833333 |
| `total_arm_area` | 0.0 | 9251.0 | 2140.033209 | 1425.3724 | 1741.0 |
| `num_arms_detected` | 0.0 | 2.0 | 1.956034 | 0.224669 | 2.0 |
