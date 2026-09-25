# Upper-Arm Segmentation â€” Annotation Candidate Selection

**Date:** 2026-09-22
**Script:** `experiments/upper_arm_segmentation/select_candidates.py`
**Random seed:** `42`
**Output CSV:** `experiments/upper_arm_segmentation/annotation_candidates.csv`

---

## 1. Overview

| Item | Value |
|---|---|
| **Total images selected** | **300** |
| Unique children | **300** |
| Overlap with baseline TEST split | **0** (PASS) |
| Images physically on disk | **300 / 300** |
| All images frontal1 | **300 / 300** |
| From baseline train split | 244 |
| From baseline validation split | 56 |
| Random seed | `42` |

---

## 2. Overlap Constraint

> The `cv_multimodal_baseline/split_indices.json` covers all 2,138 matched children
> (train=1,496 Â· val=321 Â· test=321). The 1,986-image candidate pool (after landmark
> filters) is a strict subset of those 2,138 children. There are zero candidates
> outside the baseline splits.

**Applied constraint:** Only the **multimodal baseline TEST split (321 children)**
is excluded. Annotation candidates may come from baseline train or validation children.
The segmentation experiment will have its own child-level train/validation/test split,
completely separate from the multimodal baseline splits.

| Split | Total children | Passed landmark filters | Action |
|---|---|---|---|
| Train      | 1496 | 1392 | Included |
| Validation | 321 | 305 | Included |
| Test       | 321 | 289 | **Excluded** |

---

## 3. Class Counts

| Class | Target | Selected | Note |
|---|---|---|---|
| healthy | 80 | **90** | Includes 10 cross-class top-up images (stunted pool exhausted) |
| underweight | 80 | **80** | OK |
| stunted | 60 | **50** | Pool exhausted (50 available after test exclusion). Shortfall of 10 redistributed to healthy. |
| stunted and underweight | 80 | **80** | OK |

---

## 4. Age-Group Distribution

### Combined (all classes)

| Age group | Definition | Count |
|---|---|---|
| <24m | infant/toddler | 1 |
| 24-60m | young child | 32 |
| 60-120m | older child | 118 |
| >120m | adolescent | 149 |

### Per-Class Ã— Age-Group Breakdown

| Class | <24m | 24-60m | 60-120m | >120m | Total |
|---|---|---|---|---|---|
| healthy | 1 | 21 | 33 | 35 | 90 |
| underweight | 0 | 5 | 32 | 43 | 80 |
| stunted | 0 | 2 | 20 | 28 | 50 |
| stunted and underweight | 0 | 4 | 33 | 43 | 80 |

---

## 5. Baseline Split Source

| Source | Count |
|---|---|
| Baseline train split | 244 |
| Baseline validation split | 56 |
| Outside baseline splits | 0 |
| **Total** | **300** |

---

## 6. Selection Procedure

### 6.1 Candidate Pool Construction

| Step | Filter | Remaining |
|---|---|---|
| 1 | All matched frontal1 children (anthro labels Ã— physical files on disk) | 2,138 |
| 2 | `left_upper_arm_length` and `right_upper_arm_length` not NaN | 2,128 |
| 3 | `left_forearm_length` and `right_forearm_length` not NaN | 1,986 |
| 4 | `face_width` and `face_height` not NaN | 1,986 |
| 5 | Exclude multimodal baseline TEST split (321 children) | **1,697** |

### 6.2 Stratified Sampling Algorithm

For each class (healthy, underweight, stunted, stunted and underweight):

1. Divide the class pool into four age bins: `<24m`, `24-60m`, `60-120m`, `>120m`.
2. Per-bin target = `floor(class_target / 4)` + 1 for the youngest bins (to
   distribute any remainder).
3. Within each bin, sort by **image-scale proxy** (descending) as a *secondary
   tiebreaker only* â€” see note below. Take the top `2 Ã— need` candidates from the
   sorted list, then `sample(n=need, random_state=42)` to add controlled randomness.
4. If a bin has fewer images than needed, take all available in that bin.
5. After all bins, top-up remaining shortfall from the class-level remainder pool
   (again sorted by image-scale proxy, then sampled with seed 42).
6. Hard-cap at class target; enforce child-level uniqueness via `drop_duplicates`.

### 6.3 Cross-Class Top-Up (stunted pool exhaustion)

The `stunted` class has only **50 children** remaining after excluding the test split,
but the requested target is **60**. All 50 stunted children are selected.
The 10-image shortfall is filled with 10 additional **healthy** images
(from the healthy remainder pool, sorted by image-scale proxy, sampled with seed 42).
These 10 rows are marked `selection_reason = cross_class_topup_stunted_pool_exhausted`
in the CSV.

### 6.4 Image-Scale Proxy â€” Clarification

```
image_scale_proxy = shoulder_width + left_upper_arm_length + right_upper_arm_length
```

This is a **rough image-scale indicator** derived from pixel-distance measurements.
Larger values suggest the child was photographed at closer range, which tends to
result in larger, better-resolved landmark positions. It is used **only as a
secondary tiebreaker** when sampling within an age bin â€” it is NOT a MediaPipe
landmark visibility score, and it does NOT indicate that a selected image has
better segmentation quality. Actual segmentation suitability can only be confirmed
by visual inspection during the annotation phase.

### 6.5 Reproducibility

- Fixed seed: `numpy.random.default_rng(42)`
- All `DataFrame.sample()` calls: `random_state=42`
- Fully deterministic given the same input files
- Full selection script: `experiments/upper_arm_segmentation/select_candidates.py`

---

## 7. Validation Results

| # | Check | Result | Detail |
|---|---|---|---|
| 1 | Total == 300 | **PASS** | 300 |
| 2 | Class counts: stunted=50/60 pool-limited; healthy+10 cross-topup | **PASS** | {'healthy': 90, 'underweight': 80, 'stunted': 50, 'stunted and underweight': 80} |
| 3 | 300 unique children | **PASS** | 300 unique / 300 total |
| 4 | Zero overlap with test split | **PASS** | 0 overlaps |
| 5 | Age-group distribution reported | **PASS** | {'>120m': 149, '60-120m': 118, '24-60m': 32, '<24m': 1} |
| 6 | Train vs validation split breakdown | **PASS** | train=244, val=56 |
| 7 | All images physically on disk | **PASS** | 0 missing |
| 8 | All images are frontal1 | **PASS** | 0 non-frontal1 |
| 9 | Filenames and child IDs saved | **PASS** | annotation_candidates.csv |

---

## 8. Constraints Confirmed

- [x] Exactly 300 images selected
- [x] Child-level uniqueness â€” one image per child, no duplicates
- [x] Zero overlap with the multimodal baseline TEST split
- [x] Annotation candidates sourced from baseline train + validation only
- [x] All 300 images physically verified on disk
- [x] All 300 images are frontal1 view
- [x] Both upper arms detectable (left + right `upper_arm_length` not NaN)
- [x] Both forearms detectable (left + right `forearm_length` not NaN)
- [x] Face detectable (`face_width` + `face_height` not NaN)
- [x] Age stratification applied: four bins per class
- [x] Fixed random seed `42` used throughout
- [x] Image-scale proxy used only as secondary tiebreaker, not as a visibility score
- [x] All filenames, child IDs, classes, ages, heights, weights saved to CSV

---

## 9. What Was NOT Done

- No annotation of any image
- No segmentation mask creation
- No DeepLabV3+, U-Net, or segmentation model training
- No modification of production code or models
- No modification of the CV extraction pipeline or CV multimodal baseline

---

## 10. Next Steps (Pending User Decision)

1. Review and approve this 300-image candidate list
2. Choose annotation tooling: **LabelMe**, **CVAT**, or **Roboflow**
3. Decide which body parts to label: upper arm only, or full arm (forearm + hand)
4. Begin manual annotation using the images listed in `annotation_candidates.csv`
5. After annotation: define the segmentation model's own child-level train/val/test split

> **Stop here. Do NOT proceed to DeepLabV3+, U-Net, or any segmentation model
> until annotation is complete and the user has explicitly approved next steps.**