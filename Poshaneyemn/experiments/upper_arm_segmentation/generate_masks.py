"""
generate_masks.py

Converts manually annotated LabelMe JSON polygons into binary segmentation masks.

Specification:
- Reads every LabelMe JSON in: experiments/upper_arm_segmentation/images/
- Selects only shapes with label == "upper_arm"
- Rasterizes all polygons into one binary mask per image:
    0 = background
    1 = upper_arm
- Output directory: experiments/upper_arm_segmentation/masks/
- Output filename: <IMAGE_STEM>.png
- Preserves exact original image dimensions (from JSON imageWidth and imageHeight)
- Single-channel 8-bit grayscale PNG (dtype uint8, pixel values strictly in {0, 1})
- Validates each mask before writing
- Safely skips existing masks unless overwritten
- Never modifies source JPG or JSON files
"""

import sys
import json
from pathlib import Path
from typing import Dict, List, Tuple
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent.parent
EXP_DIR = ROOT / "experiments" / "upper_arm_segmentation"
IMAGES_DIR = EXP_DIR / "images"
MASKS_DIR = EXP_DIR / "masks"


def generate_masks():
    MASKS_DIR.mkdir(parents=True, exist_ok=True)
    
    json_files = sorted(list(IMAGES_DIR.glob("*.json")))
    total_json = len(json_files)
    print(f"Found {total_json} LabelMe JSON files in {IMAGES_DIR}")

    if total_json == 0:
        print("Error: No LabelMe JSON files found. Halting.")
        return 1

    generated_count = 0
    skipped_count = 0
    failed_count = 0
    total_polygons_rasterized = 0
    one_poly_count = 0
    two_poly_count = 0
    other_poly_count = 0
    failures: List[Tuple[str, str]] = []

    for idx, json_path in enumerate(json_files, 1):
        stem = json_path.stem
        out_mask_path = MASKS_DIR / f"{stem}.png"
        
        # Check if already exists
        if out_mask_path.exists():
            skipped_count += 1
            print(f"[{idx}/{total_json}] Mask already exists, skipping: {out_mask_path.name}")
            continue

        try:
            with open(json_path, "r", encoding="utf-8") as f:
                data = json.load(f)
        except Exception as e:
            failed_count += 1
            failures.append((json_path.name, f"Failed to read/parse JSON: {e}"))
            print(f"[FAIL] {json_path.name}: Failed to read/parse JSON: {e}")
            continue

        width = data.get("imageWidth")
        height = data.get("imageHeight")

        # Validation: positive image dimensions
        if not isinstance(width, int) or not isinstance(height, int) or width <= 0 or height <= 0:
            failed_count += 1
            failures.append((json_path.name, f"Invalid dimensions: width={width}, height={height}"))
            print(f"[FAIL] {json_path.name}: Invalid dimensions: width={width}, height={height}")
            continue

        # Extract shapes
        shapes = data.get("shapes", [])
        ua_shapes = [s for s in shapes if s.get("label") == "upper_arm"]

        # Validation: at least one upper_arm polygon exists
        if len(ua_shapes) == 0:
            failed_count += 1
            failures.append((json_path.name, "No shapes with label == 'upper_arm' found."))
            print(f"[FAIL] {json_path.name}: No shapes with label == 'upper_arm' found.")
            continue

        # Count distribution
        num_ua = len(ua_shapes)
        if num_ua == 1:
            one_poly_count += 1
        elif num_ua == 2:
            two_poly_count += 1
        else:
            other_poly_count += 1

        # Create blank 8-bit grayscale image (0 = background)
        mask_img = Image.new("L", (width, height), 0)
        draw = ImageDraw.Draw(mask_img)

        valid_poly_in_image = 0
        poly_error = None

        for s in ua_shapes:
            raw_pts = s.get("points", [])
            # Validation: polygon coordinate points
            if not isinstance(raw_pts, list) or len(raw_pts) < 3:
                poly_error = f"Polygon has fewer than 3 points: {len(raw_pts)}"
                break
            
            try:
                pts = [(float(p[0]), float(p[1])) for p in raw_pts]
            except Exception as e:
                poly_error = f"Malformed point coordinates: {e}"
                break

            # Rasterize polygon into class 1
            draw.polygon(pts, fill=1)
            valid_poly_in_image += 1

        if poly_error is not None or valid_poly_in_image != num_ua:
            failed_count += 1
            msg = poly_error if poly_error else "Failed to rasterize all polygons."
            failures.append((json_path.name, msg))
            print(f"[FAIL] {json_path.name}: {msg}")
            continue

        # Post-rasterization validation
        mask_arr = np.array(mask_img, dtype=np.uint8)

        # Validation: dimension matching
        if mask_arr.shape != (height, width):
            failed_count += 1
            msg = f"Mask shape mismatch: expected ({height}, {width}), got {mask_arr.shape}"
            failures.append((json_path.name, msg))
            print(f"[FAIL] {json_path.name}: {msg}")
            continue

        # Validation: unique pixel values subset of {0, 1}
        unique_vals = set(np.unique(mask_arr))
        if not unique_vals.issubset({0, 1}):
            failed_count += 1
            msg = f"Unexpected pixel values in mask: {unique_vals}"
            failures.append((json_path.name, msg))
            print(f"[FAIL] {json_path.name}: {msg}")
            continue

        # Validation: non-empty foreground
        if 1 not in unique_vals:
            failed_count += 1
            msg = "Mask has 0 foreground pixels despite valid polygons."
            failures.append((json_path.name, msg))
            print(f"[FAIL] {json_path.name}: {msg}")
            continue

        # Save lossless PNG
        try:
            mask_img.save(out_mask_path, format="PNG")
            generated_count += 1
            total_polygons_rasterized += valid_poly_in_image
        except Exception as e:
            failed_count += 1
            failures.append((json_path.name, f"Failed to save PNG: {e}"))
            print(f"[FAIL] {json_path.name}: Failed to save PNG: {e}")
            continue

    print("\n" + "=" * 50)
    print("MASK GENERATION SUMMARY")
    print("=" * 50)
    print(f"Total JSON files: {total_json}")
    print(f"Masks generated: {generated_count}")
    print(f"Already existed (skipped): {skipped_count}")
    print(f"Failed: {failed_count}")
    print(f"Total polygons rasterized: {total_polygons_rasterized}")
    print(f"Images with 1 polygon: {one_poly_count}")
    print(f"Images with 2 polygons: {two_poly_count}")
    if other_poly_count > 0:
        print(f"Images with >2 polygons: {other_poly_count}")
    print("=" * 50)

    if failures:
        print("\nFailures:")
        for fn, rsn in failures:
            print(f"  - {fn}: {rsn}")
        return 1
    else:
        print("All masks generated and validated successfully with 0 failures!")
        return 0


if __name__ == "__main__":
    sys.exit(generate_masks())
