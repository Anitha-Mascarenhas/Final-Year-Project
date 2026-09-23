# Upper-Arm Segmentation — Annotation Inventory
**Date:** 2026-09-22
**Author:** PoshanEye experiment pipeline
**Experiment path:** `experiments/upper_arm_segmentation/`
**Status:** Investigation complete — NO usable masks found

---

## 1. Executive Summary

A comprehensive search of the entire PoshanEye repository and the AnthroVision dataset found **zero usable upper-arm segmentation masks or pixel-level body-part annotations**. Manual annotation would be required before any upper-arm segmentation model can be trained. This report documents the evidence for that conclusion and proposes a candidate pool and stratified sampling strategy for a future ~300-image manual annotation effort.

---

## 2. Scope of Search

### 2.1 Paths Searched

| Location | What was searched |
|---|---|
| `dataset/ANTHROVISION/` | All 9 view subdirectories, all file types |
| `dataset/ARAN/` | Full directory tree |
| `experiments/` | All experiment subdirectories |
| `src/` | All source files |
| `models/` | All model artifacts |
| Flutter app (`lib/`, `assets/`, `web/`) | All directories |
| Repository root | All files at top level |

### 2.2 Search Terms Used

`mask`, `segmentation`, `upper_arm`, `upperarm`, `arm`, `body_parts`, `polygon`, `annotation`, `coco`, `labelme`, `json` (non-config), `xml`, `.png` (non-icon), binary images

---

## 3. Findings — No Usable Masks

### 3.1 AnthroVision Dataset

The AnthroVision dataset (`dataset/ANTHROVISION/`) contains:

- **9 view subdirectories:** `frontal1/`, `frontal2/`, `frontal3/`, `frontal4/`, `back/`, `lateralleft/`, `lateralright/`, `selfie/`, `handswide/`
- **All image files are `.jpg` photographs** — raw captures, no overlay or annotation
- **1 CSV file:** `anthrovision_labels.csv` — contains anthropometric measurements and classification labels only (Height, Weight, MUAC, HC, BMI, class label). No pixel-level fields.
- **7 `.DS_Store` files:** macOS metadata, not annotations
- **1 stray `image.png`** in `frontal1/`: 258x387 RGBA image. Confirmed to be a regular photograph thumbnail, **not** a segmentation mask (non-binary pixel values, full RGBA colour)

**Conclusion:** AnthroVision contains NO segmentation masks, polygon annotations, COCO-style JSON files, LabelMe files, XML annotations, or any pixel-level body-part labels.

### 3.2 ARAN Dataset

The ARAN dataset (`dataset/ARAN/`) similarly contains:

- CSV label files with anthropometric measurements
- `.jpg` image files
- No annotation files of any kind

### 3.3 Experiments Directory

| Path | Relevant content found |
|---|---|
| `experiments/cv_upper_arm/run_experiment.py` | Uses **MediaPipe person-level segmentation mask** (`res.segmentation_mask > 0.5`) — NOT a ground-truth upper-arm mask. This approach was previously invalidated: the person-level mask produces apparent widths ~1.17-1.47x shoulder width, which are not valid arm measurements. |
| `experiments/cv_features_clean/` | MediaPipe landmark positions only, no masks |
| `experiments/cv_multimodal_baseline/` | Uses landmark-derived features, no masks |
| `experiments/single_image_test/` | Inference scripts only |

### 3.4 Flutter App

`web/icons/Icon-maskable-*.png` files are Progressive Web App (PWA) icons — standard icon assets, not segmentation masks.

### 3.5 Source Code

`src/` contains no mask loading, mask processing, or segmentation annotation handling of any kind.

---

## 4. Conclusion

> **No usable upper-arm segmentation masks exist anywhere in the PoshanEye project or in either dataset (AnthroVision, ARAN).**

The only body-part mask available in the current pipeline is the **MediaPipe Holistic person-level segmentation mask**, which:
- Is a coarse silhouette of the whole person, not the upper arm
- Has been empirically shown to produce invalid apparent arm-width measurements
- Has been formally invalidated by the project team

To train any upper-arm segmentation model (e.g., DeepLabV3+, U-Net), **manual annotation of a representative image subset is required**.

---

## 5. Candidate Pool for Manual Annotation

### 5.1 Source Images

All candidates are drawn from the matched set of **2,138 frontal1 children** for whom both an AnthroVision label and a physical image file exist on disk.

### 5.2 Filtering Criteria

| Filter | Criterion | Remaining |
|---|---|---|
| Start | All matched frontal1 children | 2,138 |
| Both upper-arm landmarks detected | Left & right elbow + shoulder visible (MediaPipe visibility >= 0.3) | 2,128 |
| Full arm + face visible | Both forearms, both wrists, and all face landmarks detected | **1,986** |

**Final candidate pool: 1,986 images** (one image per child — child-level isolation guaranteed).

### 5.3 Class Distribution of Candidate Pool

| Class | Count | % of pool |
|---|---|---|
| healthy | 1,379 | 69.4% |
| underweight | 333 | 16.8% |
| stunted | 59 | 3.0% |
| stunted and underweight | 215 | 10.8% |
| **Total** | **1,986** | **100%** |

**Note:** The class distribution is heavily skewed toward healthy. Any annotation sampling strategy must account for this to avoid wasting annotation budget on the majority class.

### 5.4 Additional Candidate Characteristics

- Age range: 14-224 months (mean ~127 months)
- Height range: 80-185 cm
- Weight range: 9.6-93.5 kg
- All images are frontal1 view (child facing camera, arms at sides)

---

## 6. Proposed Sampling Strategy for ~300 Annotations

### 6.1 Design Principles

1. **Child-level isolation:** Each selected image represents a unique child. No child may appear in both the annotation set and any future train/val/test splits derived from it.
2. **Class balance:** Over-sample minority classes to enable meaningful per-class segmentation evaluation.
3. **Age stratification:** Ensure coverage across age groups (infant, toddler, child, adolescent) since arm proportions vary significantly with age.
4. **Image quality pre-screen:** Prioritise images where MediaPipe detects all arm landmarks with visibility >= 0.5 (higher threshold than extraction minimum of 0.3).

### 6.2 Recommended Allocation (~330 images)

| Class | Pool size | Proposed sample | Sampling method |
|---|---|---|---|
| healthy | 1,379 | 90 | Random stratified by age quartile |
| underweight | 333 | 90 | Random stratified by age quartile |
| stunted | 59 | 60 | Near-exhaustive (~100% of pool) |
| stunted and underweight | 215 | 90 | Random stratified by age quartile |
| **Total** | **1,986** | **330** | — |

Healthy is capped at 90 (not proportional to its 69% pool share) to prevent annotation budget imbalance. Stunted is near-exhaustive because its pool (59 images) is the scarcest class.

### 6.3 Age Quartile Stratification

For each class (except stunted which is near-exhaustive), divide the pool into four age quartiles and sample equally from each:

| Age group | Approx. range | % of allocation |
|---|---|---|
| Infant/Toddler | < 24 months | 25% |
| Young child | 24-60 months | 25% |
| Older child | 60-120 months | 25% |
| Adolescent | > 120 months | 25% |

### 6.4 Annotation Format Recommendation

If manual annotation proceeds, use the following format for compatibility with standard segmentation frameworks:

- **Tool:** LabelMe or CVAT (polygon annotation)
- **Format:** COCO-style JSON with polygon segmentation fields
- **Body parts to annotate (minimum):** left upper arm, right upper arm
- **Optional extensions:** left forearm, right forearm, left hand, right hand
- **Per-image deliverable:** one JSON file with polygon coordinates per annotated body part, referenced to the source image filename

### 6.5 Annotation Isolation from Model Training

The ~330 annotated images must be treated as a **separate annotation pool**. When training a segmentation model:
- The annotation pool becomes the full available dataset for that model
- Apply a child-level 70/15/15 train/val/test split within the annotation pool
- The children used for segmentation model training must NOT overlap with children in the multimodal baseline splits (frozen in `experiments/cv_multimodal_baseline/split_indices.json`)

---

## 7. What Has NOT Been Done

The following actions are explicitly **not** part of this investigation and have NOT been started:

- No manual annotation of any images
- No DeepLabV3+ or U-Net model definition, training, or inference
- No selection of the 330 specific images (only the strategy is proposed here)
- No modification of any production code or models
- No modification of the CV extraction pipeline or CV multimodal baseline

---

## 8. Next Steps (Pending User Decision)

Before proceeding, the following decisions are needed:

1. **Approve or modify the sampling strategy** (class allocations, age stratification, annotation format)
2. **Decide on annotation tooling** (LabelMe, CVAT, Roboflow, custom script)
3. **Decide on annotation body parts** (upper arm only, or full arm)
4. **Decide whether to proceed with manual annotation** or defer to a later project phase
5. If annotation is approved: run a candidate-selection script to output the exact list of 330 image filenames

> **Do NOT proceed to DeepLabV3+, U-Net, or any segmentation model until annotation is complete and the user has given explicit approval.**
