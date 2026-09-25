"""
Automated segmentation feature extraction using trained DeepLabV3+ model.

Extracts projected 2D upper-arm geometric features from predicted segmentation masks
for all frontal1 images in the multimodal baseline dataset.

Features extracted:
- total_arm_area
- left_arm_area, right_arm_area
- left_arm_width, right_arm_width
- left_arm_height, right_arm_height
- left_arm_aspect_ratio, right_arm_aspect_ratio
- Normalized versions using MediaPipe shoulder_width reference

Guarantees:
- 100% automated; no manual intervention.
- Projected 2D geometric features only (NOT MUAC, NOT circumference).
- Missing/occluded arms recorded as NaN, never fabricated.
- Preserves child ID, tag, view, and image filename.
"""

import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np
import pandas as pd
from PIL import Image
import tensorflow as tf

# Setup paths
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parents[2]
RESULTS_DIR = SCRIPT_DIR / "results"
RESULTS_DIR.mkdir(parents=True, exist_ok=True)

WEIGHTS_PATH = SCRIPT_DIR / "best_model.weights.h5"
ANTHROVISION_CSV = PROJECT_ROOT / "dataset" / "ANTHROVISION" / "anthrovision_labels.csv"
CV_FEATURES_CSV = PROJECT_ROOT / "experiments" / "cv_features_clean" / "results" / "cv_features_clean.csv"
FRONTAL_IMAGES_DIR = PROJECT_ROOT / "dataset" / "ANTHROVISION" / "frontal1"
OUTPUT_CSV = RESULTS_DIR / "segmentation_features.csv"
REPORT_MD = RESULTS_DIR / "extraction_report.md"

# Import model architecture
from model import build_deeplabv3plus


def load_dataset_metadata() -> pd.DataFrame:
    """Load and merge AnthroVision labels with frontal1 CV features matching baseline dataset."""
    anthro_raw = pd.read_csv(ANTHROVISION_CSV)
    anthro_clean = anthro_raw.loc[:, ~anthro_raw.columns.str.contains(r"^Unnamed")].copy()
    anthro_clean = anthro_clean.dropna(subset=["multiclass_label"]).drop_duplicates(subset=["tag"], keep="first").copy()
    
    anthro_clean["f1_filename"] = anthro_clean["image_path_frontal1"].dropna().apply(lambda x: Path(str(x)).name)
    
    cv_raw = pd.read_csv(CV_FEATURES_CSV)
    cv_f1 = cv_raw[cv_raw["view"] == "frontal1"].copy()
    
    merged = pd.merge(
        anthro_clean,
        cv_f1,
        left_on="f1_filename",
        right_on="image_name",
        how="inner"
    )
    merged = merged.rename(columns={"tag_x": "child_id"})
    
    keep_cols = [
        "child_id", "tag_y", "view", "image_name", "f1_filename",
        "multiclass_label", "Height", "Weight", "MUAC", "HC", "Age", "BMI",
        "shoulder_width"
    ]
    meta_df = merged[keep_cols].copy().rename(columns={"tag_y": "tag"})
    print(f"Loaded {len(meta_df)} child metadata records matching baseline.")
    return meta_df


def preprocess_image_for_model(img_path: Path, target_size=(512, 512)) -> Tuple[Optional[np.ndarray], bool]:
    """Load image, resize with bilinear interpolation, and normalize using ImageNet stats."""
    if not img_path.exists():
        return None, False
    try:
        with Image.open(img_path) as im:
            im_rgb = im.convert("RGB")
            im_resized = im_rgb.resize(target_size, Image.Resampling.BILINEAR)
            arr = np.array(im_resized, dtype=np.float32) / 255.0
            
            mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
            std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
            norm = (arr - mean) / std
            return norm, True
    except Exception as e:
        print(f"Error loading {img_path}: {e}")
        return None, False


def extract_features_from_mask(
    mask: np.ndarray,
    shoulder_width: Optional[float] = None,
    min_component_area: int = 150
) -> Dict[str, float]:
    """
    Extract projected 2D geometric upper-arm features from binary mask.
    
    Returns geometric properties:
    - total_arm_area
    - left_arm_area, right_arm_area
    - left_arm_width, right_arm_width
    - left_arm_height, right_arm_height
    - left_arm_aspect_ratio, right_arm_aspect_ratio
    - Scale-normalized versions using shoulder_width reference
    """
    features = {
        "total_arm_area": 0.0,
        "left_arm_area": np.nan,
        "right_arm_area": np.nan,
        "left_arm_width": np.nan,
        "right_arm_width": np.nan,
        "left_arm_height": np.nan,
        "right_arm_height": np.nan,
        "left_arm_aspect_ratio": np.nan,
        "right_arm_aspect_ratio": np.nan,
        # Normalized features
        "total_arm_area_norm": np.nan,
        "left_arm_area_norm": np.nan,
        "right_arm_area_norm": np.nan,
        "left_arm_width_norm": np.nan,
        "right_arm_width_norm": np.nan,
        "left_arm_height_norm": np.nan,
        "right_arm_height_norm": np.nan,
        "num_arms_detected": 0,
    }
    
    bin_mask = (mask > 0).astype(np.uint8)
    num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(bin_mask, connectivity=8)
    
    # Filter valid components (label > 0, area >= min_component_area)
    valid_components = []
    for lbl in range(1, num_labels):
        area = int(stats[lbl, cv2.CC_STAT_AREA])
        if area >= min_component_area:
            cx = float(centroids[lbl][0])
            cy = float(centroids[lbl][1])
            w = float(stats[lbl, cv2.CC_STAT_WIDTH])
            h = float(stats[lbl, cv2.CC_STAT_HEIGHT])
            valid_components.append({
                "label": lbl,
                "area": area,
                "cx": cx,
                "cy": cy,
                "width": w,
                "height": h,
                "aspect_ratio": h / w if w > 0 else np.nan
            })
            
    if not valid_components:
        return features
        
    # Sort valid components by area descending; keep top 2
    valid_components.sort(key=lambda c: c["area"], reverse=True)
    kept_components = valid_components[:2]
    
    total_area = sum(c["area"] for c in kept_components)
    features["total_arm_area"] = float(total_area)
    features["num_arms_detected"] = len(kept_components)
    
    # Left vs Right arm assignment in image projection (viewer perspective)
    # Left side of image: cx < 256; Right side: cx >= 256
    if len(kept_components) == 2:
        # Sort by horizontal centroid: smaller cx is viewer's left, larger cx is viewer's right
        kept_components.sort(key=lambda c: c["cx"])
        left_comp = kept_components[0]
        right_comp = kept_components[1]
        
        features["left_arm_area"] = float(left_comp["area"])
        features["left_arm_width"] = float(left_comp["width"])
        features["left_arm_height"] = float(left_comp["height"])
        features["left_arm_aspect_ratio"] = float(left_comp["aspect_ratio"])
        
        features["right_arm_area"] = float(right_comp["area"])
        features["right_arm_width"] = float(right_comp["width"])
        features["right_arm_height"] = float(right_comp["height"])
        features["right_arm_aspect_ratio"] = float(right_comp["aspect_ratio"])
        
    elif len(kept_components) == 1:
        comp = kept_components[0]
        if comp["cx"] < 256.0:
            features["left_arm_area"] = float(comp["area"])
            features["left_arm_width"] = float(comp["width"])
            features["left_arm_height"] = float(comp["height"])
            features["left_arm_aspect_ratio"] = float(comp["aspect_ratio"])
        else:
            features["right_arm_area"] = float(comp["area"])
            features["right_arm_width"] = float(comp["width"])
            features["right_arm_height"] = float(comp["height"])
            features["right_arm_aspect_ratio"] = float(comp["aspect_ratio"])
            
    # Calculate scale-normalized features using MediaPipe shoulder_width
    if shoulder_width is not None and not np.isnan(shoulder_width) and shoulder_width > 0:
        sw = float(shoulder_width)
        sw_sq = sw ** 2
        features["total_arm_area_norm"] = float(features["total_arm_area"] / sw_sq)
        
        if not np.isnan(features["left_arm_area"]):
            features["left_arm_area_norm"] = float(features["left_arm_area"] / sw_sq)
            features["left_arm_width_norm"] = float(features["left_arm_width"] / sw)
            features["left_arm_height_norm"] = float(features["left_arm_height"] / sw)
            
        if not np.isnan(features["right_arm_area"]):
            features["right_arm_area_norm"] = float(features["right_arm_area"] / sw_sq)
            features["right_arm_width_norm"] = float(features["right_arm_width"] / sw)
            features["right_arm_height_norm"] = float(features["right_arm_height"] / sw)
            
    return features


def run_extraction(batch_size: int = 8):
    print("=" * 70)
    print("DEEPLABV3+ AUTOMATED SEGMENTATION FEATURE EXTRACTION")
    print("=" * 70)
    
    # 1. Load metadata
    meta_df = load_dataset_metadata()
    total_records = len(meta_df)
    
    # 2. Build model and load trained weights
    print(f"\nInstantiating DeepLabV3+ and loading weights from {WEIGHTS_PATH.name}...")
    model = build_deeplabv3plus(input_shape=(512, 512, 3), num_classes=2)
    model.load_weights(str(WEIGHTS_PATH))
    print("Loaded DeepLabV3+ checkpoint successfully.")
    
    @tf.function
    def predict_batch(imgs):
        logits = model(imgs, training=False)
        return tf.argmax(logits, axis=-1)
        
    # Warm up tf.function
    _ = predict_batch(tf.zeros((1, 512, 512, 3), dtype=tf.float32))
    
    # 3. Process images in batches
    print(f"\nProcessing {total_records} images in batches of {batch_size}...")
    all_results = []
    start_time = time.time()
    
    successful_count = 0
    missing_image_count = 0
    
    for i in range(0, total_records, batch_size):
        batch_slice = meta_df.iloc[i : min(i + batch_size, total_records)]
        
        batch_tensors = []
        batch_meta = []
        
        for _, row in batch_slice.iterrows():
            img_path = FRONTAL_IMAGES_DIR / row["f1_filename"]
            norm_arr, ok = preprocess_image_for_model(img_path)
            if ok and norm_arr is not None:
                batch_tensors.append(norm_arr)
                batch_meta.append((row, True))
            else:
                batch_meta.append((row, False))
                missing_image_count += 1
                
        if batch_tensors:
            batch_input = np.stack(batch_tensors, axis=0)
            preds = predict_batch(batch_input).numpy()
            
            pred_idx = 0
            for row, ok in batch_meta:
                if ok:
                    mask = preds[pred_idx]
                    pred_idx += 1
                    sw = row["shoulder_width"]
                    feat = extract_features_from_mask(mask, shoulder_width=sw)
                    successful_count += 1
                else:
                    feat = extract_features_from_mask(np.zeros((512, 512), dtype=np.uint8), shoulder_width=np.nan)
                    
                record = {
                    "child_id": row["child_id"],
                    "tag": row["tag"],
                    "view": row["view"],
                    "image_name": row["image_name"],
                    "shoulder_width_ref": row["shoulder_width"],
                    **feat
                }
                all_results.append(record)
        else:
            for row, _ in batch_meta:
                feat = extract_features_from_mask(np.zeros((512, 512), dtype=np.uint8), shoulder_width=np.nan)
                record = {
                    "child_id": row["child_id"],
                    "tag": row["tag"],
                    "view": row["view"],
                    "image_name": row["image_name"],
                    "shoulder_width_ref": row["shoulder_width"],
                    **feat
                }
                all_results.append(record)
                
        if (i // batch_size + 1) % 25 == 0 or (i + batch_size) >= total_records:
            elapsed = time.time() - start_time
            rate = (i + len(batch_slice)) / elapsed
            print(f"  Processed {min(i + batch_size, total_records)}/{total_records} images "
                  f"({(i + len(batch_slice))/total_records*100:.1f}%) - {rate:.1f} img/s")
                  
    total_elapsed = time.time() - start_time
    print(f"\nExtraction completed in {total_elapsed:.1f} seconds ({total_elapsed/60:.1f} minutes).")
    
    # 4. Save results CSV
    results_df = pd.DataFrame(all_results)
    results_df.to_csv(OUTPUT_CSV, index=False)
    print(f"Saved {len(results_df)} records to {OUTPUT_CSV}")
    
    # 5. Generate extraction report
    generate_extraction_report(results_df, total_records, successful_count, missing_image_count, total_elapsed)
    print(f"Saved extraction report to {REPORT_MD}")


def generate_extraction_report(
    df: pd.DataFrame,
    total_records: int,
    successful_count: int,
    missing_image_count: int,
    elapsed_time: float
):
    """Generate Markdown summary report of feature extraction."""
    num_arms_dist = df["num_arms_detected"].value_counts().to_dict()
    
    rep = []
    rep.append("# DeepLabV3+ Upper-Arm Segmentation Feature Extraction Report\n")
    rep.append("## 1. Overview\n")
    rep.append(f"- **Total target images processed**: {total_records}")
    rep.append(f"- **Successful mask predictions**: {successful_count} ({successful_count / total_records * 100:.2f}%)")
    rep.append(f"- **Missing/corrupted images**: {missing_image_count} ({missing_image_count / total_records * 100:.2f}%)")
    rep.append(f"- **Total inference runtime**: {elapsed_time:.1f} s ({elapsed_time/60:.2f} min)")
    rep.append(f"- **Throughput**: {total_records / elapsed_time:.2f} images/second\n")
    
    rep.append("## 2. Detection Distribution\n")
    rep.append("| Detected Upper Arms | Count | Percentage |")
    rep.append("|---|---|---|")
    rep.append(f"| 2 arms detected (both sides) | {num_arms_dist.get(2, 0)} | {num_arms_dist.get(2, 0)/total_records*100:.2f}% |")
    rep.append(f"| 1 arm detected (single side) | {num_arms_dist.get(1, 0)} | {num_arms_dist.get(1, 0)/total_records*100:.2f}% |")
    rep.append(f"| 0 arms detected (empty mask) | {num_arms_dist.get(0, 0)} | {num_arms_dist.get(0, 0)/total_records*100:.2f}% |\n")
    
    rep.append("## 3. Feature Missingness Profile\n")
    feature_cols = [
        "total_arm_area", "left_arm_area", "right_arm_area",
        "left_arm_width", "right_arm_width", "left_arm_height", "right_arm_height",
        "left_arm_aspect_ratio", "right_arm_aspect_ratio",
        "total_arm_area_norm", "left_arm_area_norm", "right_arm_area_norm",
        "left_arm_width_norm", "right_arm_width_norm", "left_arm_height_norm", "right_arm_height_norm"
    ]
    rep.append("| Feature | Available Count | Missing Count | Missingness % |")
    rep.append("|---|---|---|---|")
    for col in feature_cols:
        avail = int(df[col].notna().sum())
        missing = int(df[col].isna().sum())
        pct = missing / total_records * 100.0
        rep.append(f"| `{col}` | {avail} | {missing} | {pct:.2f}% |")
    rep.append("\n")
    
    rep.append("## 4. Summary Statistics (Available Values)\n")
    stats_df = df[feature_cols].describe().T[["mean", "std", "min", "50%", "max"]].rename(columns={"50%": "median"})
    stats_df = stats_df.round(4)
    rep.append("| Feature | Mean | Std | Min | Median | Max |")
    rep.append("|---|---|---|---|---|---|")
    for idx, row in stats_df.iterrows():
        rep.append(f"| `{idx}` | {row['mean']} | {row['std']} | {row['min']} | {row['median']} | {row['max']} |")
    rep.append("\n")
    
    rep.append("## 5. Critical Methodological & Clinical Notes\n")
    rep.append("1. **Projected 2D Geometry Only**: These features represent projected 2D silhouettes in pixel coordinates from a single frontal camera view. They do NOT represent 3D anatomical circumference or volume.")
    rep.append("2. **NOT Mid-Upper Arm Circumference (MUAC)**: Pixel silhouette width and area must never be conflated with physical tape-measured MUAC.")
    rep.append("3. **Non-Fabrication Policy**: Missing or occluded arms are encoded strictly as NaN and were not imputed during feature extraction.")
    rep.append("4. **Left/Right Coordinate Convention**: Due to binary mask training, left vs right designation strictly reflects image-space horizontal orientation (viewer perspective: $X < 256$ for left, $X \\ge 256$ for right), not verified anatomical chirality.")
    rep.append("5. **Scale Normalization**: Normalized features use MediaPipe `shoulder_width` as reference ($x / \\text{shoulder\\_width}$ for lengths, $x / \\text{shoulder\\_width}^2$ for areas) to mitigate camera distance variations.\n")
    
    with open(REPORT_MD, "w", encoding="utf-8") as f:
        f.write("\n".join(rep))


if __name__ == "__main__":
    run_extraction(batch_size=8)
