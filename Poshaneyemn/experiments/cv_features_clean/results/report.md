# Clean CV anthropometric features

- images processed: 17324
- unique children: 17314
- views: {'back': 2127, 'frontal1': 2158, 'frontal2': 2142, 'frontal3': 2129, 'frontal4': 2067, 'handswide': 249, 'lateralleft': 2145, 'lateralright': 2148, 'selfie': 2159}

## Missing counts per feature

| feature | missing | available |
|---|---|---|
| face_width | 8830 | 8494 |
| face_height | 8830 | 8494 |
| eye_distance | 8830 | 8494 |
| mouth_width | 8830 | 8494 |
| jaw_width | 8830 | 8494 |
| face_ratio | 8830 | 8494 |
| eye_ratio | 8830 | 8494 |
| mouth_ratio | 8830 | 8494 |
| shoulder_width | 2133 | 15191 |
| left_upper_arm_length | 6004 | 11320 |
| right_upper_arm_length | 5535 | 11789 |
| left_forearm_length | 6611 | 10713 |
| right_forearm_length | 6583 | 10741 |
| left_total_arm_length | 6611 | 10713 |
| right_total_arm_length | 6583 | 10741 |
| left_upper_arm_to_shoulder_ratio | 6004 | 11320 |
| right_upper_arm_to_shoulder_ratio | 5535 | 11789 |
| left_forearm_to_shoulder_ratio | 6611 | 10713 |
| right_forearm_to_shoulder_ratio | 6583 | 10741 |
| left_total_arm_to_shoulder_ratio | 6611 | 10713 |
| right_total_arm_to_shoulder_ratio | 6583 | 10741 |

## Extreme-value checks

- pose-ratio features outside plausible [0.05, 1.2]: {'left_upper_arm_to_shoulder_ratio': 2176, 'right_upper_arm_to_shoulder_ratio': 2154, 'left_forearm_to_shoulder_ratio': 2173, 'right_forearm_to_shoulder_ratio': 2145, 'left_total_arm_to_shoulder_ratio': 10617, 'right_total_arm_to_shoulder_ratio': 10642}

## Summary statistics

| feature | count | mean | std | min | 25% | 50% | 75% | max | n_extreme_outliers |
|---|---|---|---|---|---|---|---|---|---|
| face_width | 8494.000 | 249.726 | 38.560 | 129.403 | 222.283 | 243.591 | 270.754 | 572.462 | 18.000 |
| face_height | 8494.000 | 300.742 | 52.155 | 166.572 | 262.655 | 291.646 | 330.430 | 615.345 | 18.000 |
| eye_distance | 8494.000 | 167.626 | 25.312 | 69.079 | 150.324 | 163.563 | 180.403 | 409.925 | 18.000 |
| mouth_width | 8494.000 | 93.485 | 16.498 | 40.036 | 81.264 | 91.431 | 103.707 | 192.181 | 18.000 |
| jaw_width | 8494.000 | 254.033 | 38.825 | 129.547 | 226.610 | 247.468 | 274.632 | 586.384 | 18.000 |
| face_ratio | 8494.000 | 0.834 | 0.033 | 0.532 | 0.812 | 0.834 | 0.855 | 0.992 | 18.000 |
| eye_ratio | 8494.000 | 0.672 | 0.018 | 0.534 | 0.660 | 0.672 | 0.684 | 0.746 | 18.000 |
| mouth_ratio | 8494.000 | 0.374 | 0.029 | 0.265 | 0.355 | 0.370 | 0.389 | 0.545 | 18.000 |
| shoulder_width | 15191.000 | 568.725 | 558.150 | 1.777 | 148.635 | 467.085 | 582.545 | 2933.108 | 32.000 |
| left_upper_arm_length | 11320.000 | 452.361 | 137.811 | 47.160 | 369.645 | 432.652 | 503.137 | 2034.519 | 24.000 |
| right_upper_arm_length | 11789.000 | 496.811 | 223.230 | 23.819 | 382.675 | 449.259 | 524.528 | 2196.500 | 24.000 |
| left_forearm_length | 10713.000 | 385.295 | 95.517 | 8.175 | 321.427 | 381.119 | 439.735 | 1772.454 | 22.000 |
| right_forearm_length | 10741.000 | 382.624 | 92.773 | 84.827 | 317.533 | 377.299 | 439.433 | 1368.428 | 22.000 |
| left_total_arm_length | 10713.000 | 825.734 | 194.173 | 322.689 | 694.336 | 814.367 | 938.195 | 3698.499 | 22.000 |
| right_total_arm_length | 10741.000 | 832.408 | 192.597 | 349.662 | 697.000 | 820.367 | 945.318 | 2583.120 | 22.000 |
| left_upper_arm_to_shoulder_ratio | 11320.000 | 2.660 | 7.746 | 0.265 | 0.807 | 0.856 | 0.918 | 367.544 | 24.000 |
| right_upper_arm_to_shoulder_ratio | 11789.000 | 2.864 | 8.183 | 0.134 | 0.821 | 0.875 | 0.937 | 273.446 | 24.000 |
| left_forearm_to_shoulder_ratio | 10713.000 | 2.443 | 7.012 | 0.020 | 0.701 | 0.758 | 0.841 | 313.171 | 22.000 |
| right_forearm_to_shoulder_ratio | 10741.000 | 2.663 | 7.453 | 0.155 | 0.695 | 0.751 | 0.830 | 217.658 | 22.000 |
| left_total_arm_to_shoulder_ratio | 10713.000 | 5.213 | 14.951 | 0.312 | 1.521 | 1.617 | 1.750 | 680.716 | 22.000 |
| right_total_arm_to_shoulder_ratio | 10741.000 | 5.734 | 15.986 | 0.714 | 1.534 | 1.630 | 1.764 | 491.104 | 22.000 |