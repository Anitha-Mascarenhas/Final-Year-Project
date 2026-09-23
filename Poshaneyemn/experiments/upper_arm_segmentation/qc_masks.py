"""
Quality Control (QC) script for upper-arm segmentation masks.

Verifies:
1. Mask existence and matching dimensions with source image.
2. Valid pixel encodings (0=bg, 1=left_upper_arm, 2=right_upper_arm).
3. Foreground area bounds (detects empty masks or accidental full-image fills).
4. Metadata alignment with annotation_metadata.csv.
"""

import sys
import numpy as np
import pandas as pd
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
EXP_DIR = ROOT / "experiments" / "upper_arm_segmentation"
IMAGES_DIR = EXP_DIR / "images"
MASKS_DIR = EXP_DIR / "masks"
META_CSV = EXP_DIR / "annotation_metadata.csv"

def run_qc():
    if not META_CSV.exists():
        print(f"Error: Metadata file missing: {META_CSV}")
        return 1
    
    df = pd.read_csv(META_CSV)
    print(f"Loaded {len(df)} metadata records.")
    
    mask_files = list(MASKS_DIR.glob("*.png"))
    print(f"Found {len(mask_files)} mask files in {MASKS_DIR}.")
    
    if len(mask_files) == 0:
        print("Notice: No masks generated yet. Annotation is currently pending.")
        return 0

    errors = []
    warnings = []
    
    for idx, row in df.iterrows():
        img_name = row["image_name"]
        mask_name = Path(img_name).stem + ".png"
        mask_path = MASKS_DIR / mask_name
        
        if not mask_path.exists():
            if row["annotation_status"] == "completed":
                errors.append(f"{img_name}: marked completed in metadata, but mask file {mask_name} missing.")
            continue
            
        with Image.open(mask_path) as mask_img:
            mask_arr = np.array(mask_img)
            h, w = mask_arr.shape[:2]
            
        # 1. Dimension Check
        if (w != row["width"]) or (h != row["height_px"]):
            errors.append(f"{mask_name}: Dimension mismatch! Expected ({row['width']}, {row['height_px']}), got ({w}, {h}).")
            
        # 2. Pixel Values Check
        unique_vals = set(np.unique(mask_arr))
        valid_vals = {0, 1, 2}
        invalid = unique_vals - valid_vals
        if invalid:
            errors.append(f"{mask_name}: Contains invalid pixel values: {invalid}. Must only contain {valid_vals}.")
            
        # 3. Area Fraction Check
        total_px = w * h
        fg_px = np.count_nonzero(mask_arr)
        fg_ratio = fg_px / total_px
        
        if fg_px == 0 and row["annotation_status"] == "completed":
            warnings.append(f"{mask_name}: Mask is completely empty (0 foreground pixels).")
        elif fg_ratio > 0.30:
            warnings.append(f"{mask_name}: Suspiciously large arm mask ({fg_ratio*100:.1f}% of total image). Check for accidental fill.")
        elif fg_ratio < 0.002 and fg_px > 0:
            warnings.append(f"{mask_name}: Suspiciously tiny mask ({fg_px} px, {fg_ratio*100:.3f}% of total image).")

    print("\n--- QC Summary ---")
    print(f"Total Masks Checked: {len(mask_files)}")
    print(f"Errors Found       : {len(errors)}")
    print(f"Warnings Found     : {len(warnings)}")
    
    if errors:
        print("\nErrors:")
        for e in errors[:10]:
            print("  [ERROR]", e)
    if warnings:
        print("\nWarnings:")
        for w in warnings[:10]:
            print("  [WARN]", w)
            
    if not errors and not warnings:
        print("All existing masks passed QC successfully!")
    return 0

if __name__ == "__main__":
    sys.exit(run_qc())
