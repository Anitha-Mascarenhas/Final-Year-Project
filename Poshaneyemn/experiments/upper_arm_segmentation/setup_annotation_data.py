import shutil
import pandas as pd
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent.parent
CANDIDATES_CSV = ROOT / "experiments" / "upper_arm_segmentation" / "annotation_candidates.csv"
FRONTAL1_DIR = ROOT / "dataset" / "ANTHROVISION" / "frontal1"
EXP_DIR = ROOT / "experiments" / "upper_arm_segmentation"
IMAGES_DIR = EXP_DIR / "images"
METADATA_DIR = EXP_DIR / "metadata"
ANNOTATION_METADATA_CSV = EXP_DIR / "annotation_metadata.csv"
METADATA_METADATA_CSV = METADATA_DIR / "annotation_metadata.csv"

# 1. Read authoritative list of 300 candidates
df_candidates = pd.read_csv(CANDIDATES_CSV)
print(f"Loaded {len(df_candidates)} candidates from {CANDIDATES_CSV}")

# 2. Copy/link the 300 images into experiments/upper_arm_segmentation/images/
copied_count = 0
image_records = []

for idx, row in df_candidates.iterrows():
    img_name = row["image_name"]
    src_img = FRONTAL1_DIR / img_name
    dst_img = IMAGES_DIR / img_name
    
    if not src_img.exists():
        raise FileNotFoundError(f"Source image not found: {src_img}")
    
    if not dst_img.exists():
        shutil.copy2(src_img, dst_img)
        copied_count += 1
        
    with Image.open(src_img) as im:
        w, h = im.size

    image_records.append({
        "image_name": img_name,
        "child_id": row["child_id"],
        "class": row["class"],
        "age": row["age"],
        "height": row["height"],
        "weight": row["weight"],
        "width": w,
        "height_px": h,
        "annotation_status": "unannotated",  # unannotated | in_progress | completed | flagged
        "left_arm_status": "pending",        # pending | annotated | occluded | unavailable
        "right_arm_status": "pending",       # pending | annotated | occluded | unavailable
        "annotator_id": "",
        "notes": ""
    })

print(f"Copied {copied_count} new images to {IMAGES_DIR} (Total present: {len(list(IMAGES_DIR.glob('*.jpg')))})")

# 3. Create annotation_metadata.csv
df_meta = pd.DataFrame(image_records)
df_meta.to_csv(ANNOTATION_METADATA_CSV, index=False)
df_meta.to_csv(METADATA_METADATA_CSV, index=False)
print(f"Saved annotation metadata ({len(df_meta)} rows) to:\n  - {ANNOTATION_METADATA_CSV}\n  - {METADATA_METADATA_CSV}")
