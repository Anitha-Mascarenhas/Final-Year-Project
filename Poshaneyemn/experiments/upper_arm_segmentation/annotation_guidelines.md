# Upper-Arm Segmentation Annotation Guidelines & Protocol

**Target Dataset:** 300 frontal1 images selected from AnthroVision  
**Directory:** `experiments/upper_arm_segmentation/`  
**Task:** Manual polygon annotation of the visible upper arm regions  
**Authoritative List:** `experiments/upper_arm_segmentation/annotation_candidates.csv`  
**Tracking File:** `experiments/upper_arm_segmentation/annotation_metadata.csv`

---

## 1. Objective & Scope

The goal of this annotation stage is to produce precise ground-truth masks for the **visible upper-arm regions** of 300 children across distinct malnutrition diagnostic classes.

These annotations will be used solely for evaluating and training upper-arm segmentation models (such as U-Net or DeepLabV3+).

> **CRITICAL RULE:** Do NOT use MediaPipe masks, heuristics, color thresholding, or automated pseudo-masks to fabricate annotations. All 300 masks must be manually annotated.

---

## 2. Anatomical Region Definition

The upper arm extends from the **shoulder joint (acromion / axillary fold)** to the **elbow joint (olecranon / cubital fossa)**.

- **Foreground Class 1 (`left_upper_arm`):** The child''s anatomical left upper arm (viewer''s right).
- **Foreground Class 2 (`right_upper_arm`):** The child''s anatomical right upper arm (viewer''s left).
- **Background (Class 0):** Everything else.

### Regions Explicitly EXCLUDED from Foreground:
- **Forearm:** Cut off cleanly at the elbow bend / cubital crease.
- **Hand & Fingers:** Excluded entirely.
- **Torso / Chest / Axilla:** Follow the arm contour cleanly. Do NOT cross into the torso.
- **Neck & Head:** Excluded.
- **Background / Floor / Markers:** Excluded.

---

## 3. Boundary & Edge Rules

### 3.1 Shoulder Boundary
- Top boundary begins at the lateral acromial prominence down along the deltoid contour.
- Medial boundary terminates at the anterior axillary crease (armpit fold). Trace along the inner upper arm contour.

### 3.2 Elbow Boundary
- The distal cutoff line should be drawn straight across the narrowest anatomical constriction of the elbow joint (line connecting lateral and medial epicondyles).
- When the arm is slightly flexed, terminate along the interior cubital crease.

### 3.3 Arms Touching the Torso
- If the arm hangs flush against the torso, carefully trace the visible seam/shadow separating arm flesh from lateral thorax.
- Do not bleed the polygon into the chest, ribs, or waist.

---

## 4. Clothing Rules

> **DO NOT hallucinate or guess anatomical boundaries underneath clothing.**

1. **Short Sleeves / Visible Arm:**
   - If the upper arm is partially uncovered, trace the visible outer flesh contour.
   - If a sleeve covers the upper shoulder, trace the visible arm section and the immediate outer contour of the sleeve ONLY if the arm is clearly filling the fabric without billowing.
2. **Loose / Puffy / Bulky Sleeves:**
   - If the upper arm is covered by a loose dress, sweater, or puffy sleeve where the underlying arm profile is obscured, **do NOT invent an arm shape**.
   - If >50% of the upper arm segment is unidentifiable due to loose fabric, mark that specific arm as `unavailable` in `annotation_metadata.csv`.
3. **Full Long Sleeves:**
   - If the subject wears a tight long-sleeve garment where the arm contour is unambiguous, trace the visible clothed limb between shoulder and elbow.
   - If the garment is baggy or folds hide the limb geometry, mark as `unavailable`.

---

## 5. Occlusion and Unavailability Rules

In `annotation_metadata.csv`, each arm is tracked with `left_arm_status` and `right_arm_status`:

| Status Value | Meaning | Action |
|---|---|---|
| `annotated` | Arm is clearly visible and bounded by a polygon mask. | Generate polygon mask for this arm. |
| `occluded` | >40% of the arm is blocked by an object, board, posture turn, or hand. | Do not annotate partial stump; set status to `occluded`. |
| `unavailable` | Obscured by loose clothing, camera border clipping, or excessive shadow. | Do not guess; set status to `unavailable`. |

If one arm is visible and the other is occluded, annotate the single visible arm. The metadata will explicitly reflect `left_arm_status = annotated` and `right_arm_status = occluded`.

---

## 6. Recommended Annotation Tool & Workflow

### Tool Selection: LabelMe or CVAT
- **Recommended Local Tool:** **LabelMe** (open-source desktop app, zero external cloud dependencies, lightweight, exports standard JSON polygons).
  - Install locally when ready to annotate: `pip install labelme`
  - Launch command: `labelme experiments/upper_arm_segmentation/images --labels labels.txt`
- **Alternative:** **CVAT** (online / containerized, supports team multi-annotator workflows).

### Label Definition:
Create a label text file containing:
```
__ignore__
_background_
left_upper_arm
right_upper_arm
```

### File Hierarchy & Saving:
1. When annotating in LabelMe, save JSON annotation files alongside the images in `experiments/upper_arm_segmentation/images/<image_name>.json`.
2. A conversion utility (`convert_annotations_to_masks.py`) will automatically compile the polygon JSON files into lossless PNG masks.

---

## 7. Mask Encoding Specification

Final exported masks must be stored in:
`experiments/upper_arm_segmentation/masks/`

### Encoding Standards:
- **Format:** 8-bit single-channel lossless PNG (`.png`).
- **Dimensions:** Exactly match the input image height and width (`height_px`, `width` in metadata).

### Pixel Value Encoding (Semantic Split Preservation):
To ensure left and right upper arms can be analyzed separately for bilateral symmetry:

| Pixel Value | Semantic Label |
|:---:|---|
| **`0`** | Background |
| **`1`** | Left Upper Arm (anatomical left) |
| **`2`** | Right Upper Arm (anatomical right) |

*(Note: For binary arm vs. background segmentation experiments, `1` and `2` can be trivially mapped to `1` during data loading without information loss.)*

---

## 8. Quality Control (QC) Procedure

Before any segmentation dataset is used for model experiments, run the automated verification script:
`python experiments/upper_arm_segmentation/qc_masks.py`

### QC Criteria:
1. **Dimension Parity:** Mask `(H, W)` must strictly match original image `(H, W)`.
2. **Label Value Validity:** Unique pixel values in mask must be a subset of `{0, 1, 2}`.
3. **Empty Mask Verification:** If mask has zero foreground pixels, metadata must explicitly record both arms as `unavailable` or `occluded`.
4. **Boundary Sanity (Non-Trivial Foreground):**
   - Mask area ratio must fall between `0.5%` and `25%` of total image pixels (flags accidental whole-image selection).
   - Flag disconnected debris / isolated pixel noise < 50 pixels.
5. **Metadata Consistency:** Count of annotated masks in `masks/` must match `annotation_status = completed` in `annotation_metadata.csv`.
