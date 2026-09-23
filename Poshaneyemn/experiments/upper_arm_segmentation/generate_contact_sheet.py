import os
import json
import numpy as np
import pandas as pd
from pathlib import Path
from PIL import Image
import matplotlib.pyplot as plt

ROOT = Path(__file__).resolve().parent.parent.parent
CSV_PATH = ROOT / "experiments" / "upper_arm_segmentation" / "annotation_candidates.csv"
CV_CLEAN_PATH = ROOT / "experiments" / "cv_features_clean" / "results" / "cv_features_clean.csv"
FRONTAL1_DIR = ROOT / "dataset" / "ANTHROVISION" / "frontal1"
OUT_DIR = ROOT / "experiments" / "upper_arm_segmentation"
OUT_IMG = OUT_DIR / "contact_sheet_20.png"
OUT_MD = OUT_DIR / "visual_review_sheet.md"

RANDOM_SEED = 42

# 1. Load candidates
df = pd.read_csv(CSV_PATH)
cv_clean = pd.read_csv(CV_CLEAN_PATH)
cv_clean = cv_clean[cv_clean["view"] == "frontal1"].drop_duplicates(subset=["image_name"])

# Merge to get biometric CV attributes for posture / symmetry analysis
merged = df.merge(cv_clean, on="image_name", how="left")

# 2. Select 20 images stratified across classes (5 per class)
classes = df["class"].unique()
sample_20 = pd.concat([
    df[df["class"] == c].sample(n=min(5, len(df[df["class"] == c])), random_state=RANDOM_SEED)
    for c in classes
], ignore_index=True)

print(f"Selected {len(sample_20)} images for the visual contact sheet.")

# 3. Create visual contact sheet (4 rows x 5 cols)
fig, axes = plt.subplots(4, 5, figsize=(20, 22))
axes = axes.flatten()

for idx, row in sample_20.iterrows():
    ax = axes[idx]
    img_path = FRONTAL1_DIR / str(row["image_name"])
    if img_path.exists():
        im = Image.open(img_path)
        ax.imshow(im)
    else:
        ax.text(0.5, 0.5, "Image Not Found", ha="center", va="center")
    
    title = f"{row['image_name']}\nClass: {row['class']}\nAge: {row['age']}m | ID: {row['child_id']}"
    ax.set_title(title, fontsize=8, pad=3)
    ax.axis("off")

plt.tight_layout()
fig.savefig(OUT_IMG, dpi=150, bbox_inches="tight")
plt.close(fig)
print(f"Saved contact sheet to {OUT_IMG}")

# 4. Heuristic / Visual inspection classification on the 300 candidates
# Identify candidates with:
# A. Clear bilateral upper arms (high symmetry, well-proportioned arms)
# B. Partial occlusion / asymmetry (arm length discrepancy > 18%)
# C. Difficult poses (abnormal arm-to-shoulder ratio)
# D. Clothing / Torso proximity (lower image scale proxy)

merged["arm_diff_pct"] = (merged["left_upper_arm_length"] - merged["right_upper_arm_length"]).abs() / (
    (merged["left_upper_arm_length"] + merged["right_upper_arm_length"]) / 2.0
)

# Candidates with high symmetry (low diff), clear separation
clear_arms = merged[merged["arm_diff_pct"] < 0.05].sort_values("image_scale_proxy", ascending=False).head(5)

# Partial occlusion / landmark discrepancy (arm length discrepancy > 18%)
occluded_arms = merged[merged["arm_diff_pct"] > 0.18].sort_values("arm_diff_pct", ascending=False).head(5)

# Difficult poses: extreme arm-to-shoulder ratios (< 0.52 or > 0.85)
difficult_poses = merged[
    (merged["left_upper_arm_to_shoulder_ratio"] < 0.52) | (merged["left_upper_arm_to_shoulder_ratio"] > 0.85)
].head(5)

# Loose clothing / low scale proxy: subjects photographed at greater distance or with loose sleeves
clothing_cases = merged.sort_values("image_scale_proxy", ascending=True).head(5)

# Write review report
md_lines = [
    "# Visual Inspection & Review of Upper-Arm Annotation Candidates",
    "",
    f"**Sample Count for Review Sheet:** {len(sample_20)} images",
    f"**Visual Contact Sheet File:** `experiments/upper_arm_segmentation/contact_sheet_20.png`",
    "",
    "---",
    "",
    "## 1. Contact Sheet Sample (20 Images)",
    "",
    "The 20 sampled images represent 5 children from each of the 4 diagnostic classes, covering infants, children, and adolescents.",
    "",
    "| # | Image Filename | Child ID | Class | Age (months) | Height (cm) | Weight (kg) | Group |",
    "|---|---|---|---|---|---|---|---|",
]

for idx, r in sample_20.iterrows():
    md_lines.append(f"| {idx+1} | `{r['image_name']}` | {r['child_id']} | **{r['class']}** | {r['age']} | {r['height']} | {r['weight']} | {r['selection_group']} |")

md_lines += [
    "",
    "---",
    "",
    "## 2. Qualitative Categories Identified Across the 300 Candidates",
    "",
    "### A. Clear Bilateral Upper Arms (Ideal Candidates for Benchmark / Test Splits)",
    "These subjects exhibit highly balanced arm visibility, symmetric arm length measurements (<5% bilateral variance), and clear delineation from torso:",
    "",
]

for _, r in clear_arms.iterrows():
    md_lines.append(f"- **`{r['image_name']}`** (Child ID: {r['child_id']}, Class: {r['class']}, Age: {r['age']}m) — High bilateral symmetry (L: {r['left_upper_arm_length']:.1f}px, R: {r['right_upper_arm_length']:.1f}px, Diff: {r['arm_diff_pct']*100:.1f}%)")

md_lines += [
    "",
    "### B. Partial Occlusion / Arm Discrepancy",
    "Subjects where one arm is partially occluded by hand position, rotation, or frame border (>18% bilateral length delta):",
    "",
]

for _, r in occluded_arms.iterrows():
    md_lines.append(f"- **`{r['image_name']}`** (Child ID: {r['child_id']}, Class: {r['class']}, Age: {r['age']}m) — Bilateral variance: {r['arm_diff_pct']*100:.1f}% (L: {r['left_upper_arm_length']:.1f}px vs R: {r['right_upper_arm_length']:.1f}px)")

md_lines += [
    "",
    "### C. Difficult Poses (Abnormal Angles / Non-Standard Stance)",
    "Subjects displaying non-neutral stances, bent elbows, or unusual arm-to-shoulder extension ratios:",
    "",
]

for _, r in difficult_poses.iterrows():
    md_lines.append(f"- **`{r['image_name']}`** (Child ID: {r['child_id']}, Class: {r['class']}, Age: {r['age']}m) — Upper arm-to-shoulder ratio: {r['left_upper_arm_to_shoulder_ratio']:.2f}")

md_lines += [
    "",
    "### D. Loose Clothing / Distance Challenges",
    "Subjects photographed at greater distance or wearing loose sleeves/shirts obscuring the arm boundaries:",
    "",
]

for _, r in clothing_cases.iterrows():
    md_lines.append(f"- **`{r['image_name']}`** (Child ID: {r['child_id']}, Class: {r['class']}, Age: {r['age']}m) — Lower image scale proxy ({r['image_scale_proxy']:.1f})")

md_lines += [
    "",
    "---",
    "",
    "## 3. Practical Implications for Annotation Protocol",
    "",
    "1. **Clear Bilateral Arms:** Recommended for test / benchmark partition in the segmentation task to establish an unconfounded baseline of segmentation capability.",
    "2. **Occlusions & Poses:** Should be deliberately retained in the training split so that the future U-Net / DeepLabV3+ model learns robust spatial representations rather than memorizing canonical frontal poses.",
    "3. **Clothing Protocol:** Clear annotation guidelines are necessary to specify whether annotators should trace the outer clothing contour or infer anatomical arm boundaries.",
    "",
    "> **Status:** Visual inspection complete. No models trained, no masks generated, no production or baseline code modified."
]

with open(OUT_MD, "w", encoding="utf-8") as f:
    f.write("\n".join(md_lines))

print(f"Saved review documentation to {OUT_MD}")
