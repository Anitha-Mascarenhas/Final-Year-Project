"""
Quality Control (QC) script for upper-arm segmentation masks.

Verifies:
1. Every current annotated JPG has a corresponding mask.
2. The number of generated masks is exactly equal to the number of currently annotated JPG images (246).
3. Every corresponding mask has the exact same dimensions as its JPG image.
4. Masks are single-channel grayscale (2D array, mode 'L').
5. Pixel values are strictly a subset of {0, 1} (0=background, 1=upper_arm).
6. No completed annotation has an empty mask (must contain at least one foreground pixel).
7. Flags suspiciously large foreground areas (> 25% of image pixels).
8. Flags suspiciously tiny foreground areas (< 0.2% of image pixels or < 100 pixels).
9. Does not use old {0, 1, 2} encoding.
10. Does not require all 300 metadata candidate records to have masks (only the 246 current batch).
"""

import sys
from pathlib import Path
from typing import List, Dict, Tuple
import numpy as np
from PIL import Image
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent.parent
EXP_DIR = ROOT / "experiments" / "upper_arm_segmentation"
IMAGES_DIR = EXP_DIR / "images"
MASKS_DIR = EXP_DIR / "masks"
META_CSV = EXP_DIR / "annotation_metadata.csv"

EXPECTED_COUNT = 246


def run_qc():
    print("=" * 60)
    print("UPPER-ARM SEGMENTATION QUALITY CONTROL (QC)")
    print("=" * 60)

    if not IMAGES_DIR.exists():
        print(f"Error: Images directory missing: {IMAGES_DIR}")
        return 1

    if not MASKS_DIR.exists():
        print(f"Error: Masks directory missing: {MASKS_DIR}")
        return 1

    jpg_files = sorted(list(IMAGES_DIR.glob("*.jpg")))
    mask_files = sorted(list(MASKS_DIR.glob("*.png")))
    json_files = sorted(list(IMAGES_DIR.glob("*.json")))

    num_jpg = len(jpg_files)
    num_mask = len(mask_files)
    num_json = len(json_files)

    print(f"Found JPG images in images/ : {num_jpg}")
    print(f"Found JSON files in images/ : {num_json}")
    print(f"Found PNG masks in masks/   : {num_mask}")

    errors: List[str] = []
    warnings: List[str] = []
    suspicious_files: List[Tuple[str, str]] = []

    # Check 1: Total mask count check against expected currently annotated batch
    if num_mask != EXPECTED_COUNT:
        errors.append(
            f"Mask count mismatch: Expected exactly {EXPECTED_COUNT} masks for current annotated batch, but found {num_mask}."
        )

    # Check 2: Mask count matches JPG count
    if num_mask != num_jpg:
        errors.append(
            f"Count mismatch between images and masks: {num_jpg} JPGs vs {num_mask} PNG masks."
        )

    # Check 3: Check each JPG image has a corresponding mask and inspect dimensions, channels, pixels
    valid_masks_count = 0

    for idx, jpg_path in enumerate(jpg_files, 1):
        stem = jpg_path.stem
        mask_path = MASKS_DIR / f"{stem}.png"

        # Check corresponding mask exists
        if not mask_path.exists():
            errors.append(f"{jpg_path.name}: Corresponding mask {mask_path.name} is MISSING.")
            continue

        # Open image to get true dimensions and mode
        try:
            with Image.open(jpg_path) as im_jpg:
                w_jpg, h_jpg = im_jpg.size
        except Exception as e:
            errors.append(f"{jpg_path.name}: Failed to open JPG: {e}")
            continue

        # Open mask
        try:
            with Image.open(mask_path) as im_mask:
                w_mask, h_mask = im_mask.size
                mask_mode = im_mask.mode
                mask_arr = np.array(im_mask)
        except Exception as e:
            errors.append(f"{mask_path.name}: Failed to open PNG mask: {e}")
            continue

        # Dimension Check
        if (w_mask != w_jpg) or (h_mask != h_jpg):
            errors.append(
                f"{mask_path.name}: Dimension mismatch! JPG is ({w_jpg}x{h_jpg}), mask is ({w_mask}x{h_mask})."
            )

        # Single-channel check
        if mask_mode not in ("L", "1") or mask_arr.ndim != 2:
            errors.append(
                f"{mask_path.name}: Mask is not single-channel grayscale! Mode: {mask_mode}, ndim: {mask_arr.ndim}"
            )

        # Pixel value check (strictly {0, 1})
        unique_vals = set(np.unique(mask_arr))
        valid_vals = {0, 1}
        invalid_vals = unique_vals - valid_vals
        if invalid_vals:
            errors.append(
                f"{mask_path.name}: Invalid pixel values found: {invalid_vals}. Must be strictly a subset of {valid_vals}."
            )

        # Empty mask check
        total_px = w_mask * h_mask
        fg_px = int(np.count_nonzero(mask_arr == 1))
        fg_ratio = fg_px / total_px if total_px > 0 else 0.0

        if fg_px == 0:
            errors.append(f"{mask_path.name}: Mask is completely empty (0 foreground pixels).")

        # Warning: Suspiciously large mask (> 25% of image)
        elif fg_ratio > 0.25:
            msg = f"Suspiciously large mask ({fg_ratio*100:.2f}% of image, {fg_px} px)."
            warnings.append(f"{mask_path.name}: {msg}")
            suspicious_files.append((mask_path.name, msg))

        # Warning: Suspiciously tiny mask (< 0.2% of image or < 100 px)
        elif fg_ratio < 0.002 or fg_px < 100:
            msg = f"Suspiciously small mask ({fg_ratio*100:.3f}% of image, {fg_px} px)."
            warnings.append(f"{mask_path.name}: {msg}")
            suspicious_files.append((mask_path.name, msg))

        valid_masks_count += 1

    # Check 4: Check if any stray masks exist that have no corresponding JPG
    for mask_path in mask_files:
        stem = mask_path.stem
        corresponding_jpg = IMAGES_DIR / f"{stem}.jpg"
        if not corresponding_jpg.exists():
            errors.append(f"{mask_path.name}: Stray mask exists with no matching {stem}.jpg in images/.")

    print("\n" + "=" * 60)
    print("QC VERIFICATION SUMMARY")
    print("=" * 60)
    print(f"Total Annotated Images Checked : {num_jpg}")
    print(f"Total Masks Verified           : {valid_masks_count} / {EXPECTED_COUNT}")
    print(f"QC Errors                      : {len(errors)}")
    print(f"QC Warnings                    : {len(warnings)}")
    print("=" * 60)

    if errors:
        print("\n[QC ERRORS]:")
        for err in errors:
            print(f"  - ERROR: {err}")

    if warnings:
        print(f"\n[QC WARNINGS] ({len(warnings)} files require manual visual review):")
        for w in warnings:
            print(f"  - WARN: {w}")

    if not errors and not warnings:
        print("\nAll 246 masks passed QC with 0 errors and 0 warnings!")
    elif not errors:
        print(f"\nAll 246 masks passed strict format/dimension validation (0 errors, {len(warnings)} warnings).")

    return 0 if len(errors) == 0 else 1


if __name__ == "__main__":
    sys.exit(run_qc())
