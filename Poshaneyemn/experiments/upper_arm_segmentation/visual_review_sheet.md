# Visual Inspection & Review of Upper-Arm Annotation Candidates

**Sample Count for Review Sheet:** 20 images
**Visual Contact Sheet File:** `experiments/upper_arm_segmentation/contact_sheet_20.png`

---

## 1. Contact Sheet Sample (20 Images)

The 20 sampled images represent 5 children from each of the 4 diagnostic classes, covering infants, children, and adolescents.

| # | Image Filename | Child ID | Class | Age (months) | Height (cm) | Weight (kg) | Group |
|---|---|---|---|---|---|---|---|
| 1 | `IMG_20230316_101818_385_frontal1.jpg` | 385 | **healthy** | 90 | 123.0 | 19.6 | 60-120m |
| 2 | `IMG_20230316_111336_396_frontal1.jpg` | 396 | **healthy** | 98 | 130.0 | 22.0 | 60-120m |
| 3 | `IMG_20221203_123756_177_frontal1.jpg` | 177 | **healthy** | 183 | 167.0 | 44.3 | >120m |
| 4 | `IMG_20240109_090509_1847_frontal1.jpg` | 1847 | **healthy** | 79 | 120.0 | 21.0 | 60-120m |
| 5 | `IMG_20231030_085321_595_frontal1.jpg` | 595 | **healthy** | 14 | 147.0 | 35.4 | <24m |
| 6 | `IMG_20230609_022716_464_frontal1.jpg` | 463 | **underweight** | 189 | 164.8 | 37.0 | >120m |
| 7 | `IMG_20230316_091626_366_frontal1.jpg` | 366 | **underweight** | 50 | 109.0 | 14.0 | 24-60m |
| 8 | `IMG_20231031_113050_646_frontal1.jpg` | 646 | **underweight** | 97 | 120.0 | 17.8 | 60-120m |
| 9 | `IMG_20240105_134131_1823_frontal1.jpg` | 1823 | **underweight** | 191 | 165.0 | 39.7 | >120m |
| 10 | `IMG_20221203_134429_218_frontal1.jpg` | 218 | **underweight** | 96 | 111.0 | 17.3 | 60-120m |
| 11 | `IMG_20221124_122144_31_frontal1.jpg` | 31 | **stunted** | 71 | 117.0 | 23.4 | 60-120m |
| 12 | `IMG_20240123_112830_2017_frontal1.jpg` | 2017 | **stunted** | 79 | 106.0 | 17.2 | 60-120m |
| 13 | `IMG_20221203_115939_141_frontal1.jpg` | 141 | **stunted** | 130 | 147.0 | 29.9 | >120m |
| 14 | `IMG_20221210_133609_321_frontal1.jpg` | 321 | **stunted** | 155 | 147.8 | 33.5 | >120m |
| 15 | `IMG_20231128_151237_1125_frontal1.jpg` | 1125 | **stunted** | 183 | 148.0 | 45.1 | >120m |
| 16 | `IMG_20240124_124754_2155_frontal1.jpg` | 2155 | **stunted and underweight** | 175 | 151.0 | 34.3 | >120m |
| 17 | `IMG_20230315_110418_353_frontal1.jpg` | 353 | **stunted and underweight** | 39 | 83.0 | 10.0 | 24-60m |
| 18 | `IMG_20221124_110307_20_frontal1.jpg` | 20 | **stunted and underweight** | 100 | 116.2 | 19.7 | 60-120m |
| 19 | `IMG_20221203_124313_183_frontal1.jpg` | 183 | **stunted and underweight** | 166 | 145.0 | 32.1 | >120m |
| 20 | `IMG_20231025_143629_560_frontal1.jpg` | 560 | **stunted and underweight** | 97 | 114.0 | 15.0 | 60-120m |

---

## 2. Qualitative Categories Identified Across the 300 Candidates

### A. Clear Bilateral Upper Arms (Ideal Candidates for Benchmark / Test Splits)
These subjects exhibit highly balanced arm visibility, symmetric arm length measurements (<5% bilateral variance), and clear delineation from torso:

- **`IMG_20221124_120851_29_frontal1.jpg`** (Child ID: 29, Class: stunted and underweight, Age: 156m) — High bilateral symmetry (L: 672.7px, R: 695.6px, Diff: 3.4%)
- **`IMG_20230315_122705_363_frontal1.jpg`** (Child ID: 363, Class: healthy, Age: 66m) — High bilateral symmetry (L: 616.0px, R: 632.3px, Diff: 2.6%)
- **`IMG_20230316_092043_368_frontal1.jpg`** (Child ID: 368, Class: underweight, Age: 144m) — High bilateral symmetry (L: 616.9px, R: 643.1px, Diff: 4.2%)
- **`IMG_20221125_123822_62_frontal1.jpg`** (Child ID: 62, Class: healthy, Age: 149m) — High bilateral symmetry (L: 592.2px, R: 609.6px, Diff: 2.9%)
- **`IMG_20230606_051102_457_frontal1.jpg`** (Child ID: 456, Class: healthy, Age: 207m) — High bilateral symmetry (L: 589.1px, R: 606.2px, Diff: 2.9%)

### B. Partial Occlusion / Arm Discrepancy
Subjects where one arm is partially occluded by hand position, rotation, or frame border (>18% bilateral length delta):

- **`IMG_20221210_133609_321_frontal1.jpg`** (Child ID: 321, Class: stunted, Age: 155m) — Bilateral variance: 19.7% (L: 373.3px vs R: 306.5px)
- **`IMG_20230609_024815_473_frontal1.jpg`** (Child ID: 472, Class: healthy, Age: 42m) — Bilateral variance: 19.3% (L: 391.1px vs R: 322.2px)

### C. Difficult Poses (Abnormal Angles / Non-Standard Stance)
Subjects displaying non-neutral stances, bent elbows, or unusual arm-to-shoulder extension ratios:

- **`IMG_20231030_085321_595_frontal1.jpg`** (Child ID: 595, Class: healthy, Age: 14m) — Upper arm-to-shoulder ratio: 0.86
- **`IMG_20231206_113053_1350_frontal1.jpg`** (Child ID: 1350, Class: healthy, Age: 54m) — Upper arm-to-shoulder ratio: 0.93
- **`IMG_20230316_111336_396_frontal1.jpg`** (Child ID: 396, Class: healthy, Age: 98m) — Upper arm-to-shoulder ratio: 0.87
- **`IMG_20230609_030754_479_frontal1.jpg`** (Child ID: 478, Class: healthy, Age: 111m) — Upper arm-to-shoulder ratio: 0.92
- **`IMG_20221128_124853_85_frontal1.jpg`** (Child ID: 85, Class: healthy, Age: 119m) — Upper arm-to-shoulder ratio: 0.93

### D. Loose Clothing / Distance Challenges
Subjects photographed at greater distance or wearing loose sleeves/shirts obscuring the arm boundaries:

- **`IMG_20231222_125533_1595_frontal1.jpg`** (Child ID: 1595, Class: stunted and underweight, Age: 84m) — Lower image scale proxy (852.4)
- **`IMG_20240120_112947_1931_frontal1.jpg`** (Child ID: 1931, Class: underweight, Age: 54m) — Lower image scale proxy (861.8)
- **`IMG_20221210_120348_272_frontal1.jpg`** (Child ID: 272, Class: underweight, Age: 118m) — Lower image scale proxy (876.8)
- **`IMG_20240120_115030_1938_frontal1.jpg`** (Child ID: 1938, Class: stunted, Age: 49m) — Lower image scale proxy (877.1)
- **`IMG_20231106_123501_781_frontal1.jpg`** (Child ID: 781, Class: stunted and underweight, Age: 68m) — Lower image scale proxy (880.2)

---

## 3. Practical Implications for Annotation Protocol

1. **Clear Bilateral Arms:** Recommended for test / benchmark partition in the segmentation task to establish an unconfounded baseline of segmentation capability.
2. **Occlusions & Poses:** Should be deliberately retained in the training split so that the future U-Net / DeepLabV3+ model learns robust spatial representations rather than memorizing canonical frontal poses.
3. **Clothing Protocol:** Clear annotation guidelines are necessary to specify whether annotators should trace the outer clothing contour or infer anatomical arm boundaries.

> **Status:** Visual inspection complete. No models trained, no masks generated, no production or baseline code modified.