# Child-Level Upper-Arm Segmentation Dataset Split Summary

**Date:** 2026-09-23  
**Random State:** `42`  
**Protocol:** 70% Train / 15% Validation / 15% Test  
**Split Level:** Child-Level Stratified  

---

## 1. Overview & Isolation Audit

| Metric | Total Annotated | Train | Validation | Test |
|---|---|---|---|---|
| **Total Images** | **246** | **172** (69.9%) | **37** (15.0%) | **37** (15.0%) |
| **Unique Children** | **246** | **172** | **37** | **37** |
| **Child Overlap** | — | **0** | **0** | **0** |
| **Physical JPG Verified** | 100% (246/246) | 100% (172/172) | 100% (37/37) | 100% (37/37) |
| **Physical PNG Mask Verified** | 100% (246/246) | 100% (172/172) | 100% (37/37) | 100% (37/37) |

> **Child-Level Leakage Check:** PASSED. There is **zero overlap** of children across train, validation, and test splits.

---

## 2. Class Distribution per Split

| Malnutrition Class | Total Count (%) | Train Count (%) | Validation Count (%) | Test Count (%) |
|---|---|---|---|---|
| **healthy** | 72 (29.3%) | 50 (29.1%) | 11 (29.7%) | 11 (29.7%) |
| **stunted** | 40 (16.3%) | 28 (16.3%) | 6 (16.2%) | 6 (16.2%) |
| **stunted and underweight** | 67 (27.2%) | 47 (27.3%) | 10 (27.0%) | 10 (27.0%) |
| **underweight** | 67 (27.2%) | 47 (27.3%) | 10 (27.0%) | 10 (27.0%) |

---

## 3. Dataset Integrity & Exclusions

- **Authoritative Candidate Metadata:** 300 records in `experiments/upper_arm_segmentation/annotation_metadata.csv`.
- **Annotated & Masked Subset:** Exactly 246 images currently have completed manual LabelMe annotations and validated binary PNG masks.
- **Unannotated Candidates Excluded:** Exactly 54 candidate records remain unannotated and are strictly excluded from these splits.

---

## 4. Split File Locations

- `experiments/upper_arm_segmentation/splits/train.csv` (172 rows)
- `experiments/upper_arm_segmentation/splits/val.csv` (37 rows)
- `experiments/upper_arm_segmentation/splits/test.csv` (37 rows)

> **Status:** Dataset split generation complete. Ready for model dataset loader construction.