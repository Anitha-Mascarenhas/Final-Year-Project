# DeepLabV3+ Upper-Arm Segmentation Feature Extraction Report

## 1. Overview

- **Total target images processed**: 2138
- **Successful mask predictions**: 2138 (100.00%)
- **Missing/corrupted images**: 0 (0.00%)
- **Total inference runtime**: 1388.4 s (23.14 min)
- **Throughput**: 1.54 images/second

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
| `total_arm_area` | 2140.0327 | 1425.3716 | 0.0 | 1741.0 | 9251.0 |
| `left_arm_area` | 1081.6745 | 743.2888 | 151.0 | 878.5 | 6092.0 |
| `right_arm_area` | 1106.3306 | 703.417 | 153.0 | 909.0 | 4956.0 |
| `left_arm_width` | 23.2707 | 10.6549 | 7.0 | 20.0 | 88.0 |
| `right_arm_width` | 23.852 | 10.1792 | 7.0 | 21.0 | 72.0 |
| `left_arm_height` | 60.45 | 15.7179 | 24.0 | 60.0 | 116.0 |
| `right_arm_height` | 62.4981 | 15.8392 | 22.0 | 62.0 | 112.0 |
| `left_arm_aspect_ratio` | 2.839 | 0.7113 | 1.1023 | 2.8182 | 5.5 |
| `right_arm_aspect_ratio` | 2.8198 | 0.6602 | 0.8596 | 2.8333 | 5.4444 |
| `total_arm_area_norm` | 0.0082 | 0.0053 | 0.0007 | 0.0073 | 0.1752 |
| `left_arm_area_norm` | 0.0041 | 0.0023 | 0.0006 | 0.0037 | 0.0551 |
| `right_arm_area_norm` | 0.0043 | 0.0032 | 0.0007 | 0.0038 | 0.1201 |
| `left_arm_width_norm` | 0.0461 | 0.0171 | 0.0155 | 0.0418 | 0.2174 |
| `right_arm_width_norm` | 0.0475 | 0.0167 | 0.0143 | 0.0428 | 0.2609 |
| `left_arm_height_norm` | 0.1212 | 0.0231 | 0.0495 | 0.122 | 0.3739 |
| `right_arm_height_norm` | 0.1255 | 0.0242 | 0.056 | 0.1266 | 0.6174 |


## 5. Critical Methodological & Clinical Notes

1. **Projected 2D Geometry Only**: These features represent projected 2D silhouettes in pixel coordinates from a single frontal camera view. They do NOT represent 3D anatomical circumference or volume.
2. **NOT Mid-Upper Arm Circumference (MUAC)**: Pixel silhouette width and area must never be conflated with physical tape-measured MUAC.
3. **Non-Fabrication Policy**: Missing or occluded arms are encoded strictly as NaN and were not imputed during feature extraction.
4. **Left/Right Coordinate Convention**: Due to binary mask training, left vs right designation strictly reflects image-space horizontal orientation (viewer perspective: $X < 256$ for left, $X \ge 256$ for right), not verified anatomical chirality.
5. **Scale Normalization**: Normalized features use MediaPipe `shoulder_width` as reference ($x / \text{shoulder\_width}$ for lengths, $x / \text{shoulder\_width}^2$ for areas) to mitigate camera distance variations.
