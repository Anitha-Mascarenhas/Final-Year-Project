import json
from pathlib import Path
import pandas as pd

img_dir = Path("experiments/upper_arm_segmentation/images")
jpg_files = sorted(list(img_dir.glob("*.jpg")))
json_files = sorted(list(img_dir.glob("*.json")))

print(f"JPG files in images/: {len(jpg_files)}")
print(f"JSON files in images/: {len(json_files)}")

# 1. Inspect sample JSON file structure
if json_files:
    sample_json = json_files[0]
    with open(sample_json, "r", encoding="utf-8") as f:
        data = json.load(f)
    print(f"\n--- Sample JSON: {sample_json.name} ---")
    print(f"Top-level Keys: {list(data.keys())}")
    shapes = data.get("shapes", [])
    print(f"Number of shapes in sample: {len(shapes)}")
    if shapes:
        first_shape = shapes[0]
        print(f"Shape Keys: {list(first_shape.keys())}")
        print(f"Shape Label: '{first_shape.get('label')}'")
        print(f"Shape Type: '{first_shape.get('shape_type')}'")
        print(f"Points count in first shape: {len(first_shape.get('points', []))}")
        print(f"Sample Points (first 2): {first_shape.get('points', [])[:2]}")
    print(f"imagePath field: '{data.get('imagePath')}'")
    print(f"imageHeight: {data.get('imageHeight')}, imageWidth: {data.get('imageWidth')}")

# 2. Check all JSON files for labels and shape counts
labels_found = set()
shape_types_found = set()
shapes_distribution = {}
zero_shapes = []
has_upper_arm = []
other_label_files = []

for jf in json_files:
    with open(jf, "r", encoding="utf-8") as f:
        data = json.load(f)
    shapes = data.get("shapes", [])
    n_shapes = len(shapes)
    shapes_distribution[n_shapes] = shapes_distribution.get(n_shapes, 0) + 1
    
    if n_shapes == 0:
        zero_shapes.append(jf.name)
    
    contains_ua = False
    for s in shapes:
        lbl = s.get("label")
        labels_found.add(lbl)
        stype = s.get("shape_type")
        shape_types_found.add(stype)
        if lbl == "upper_arm":
            contains_ua = True
        else:
            other_label_files.append((jf.name, lbl))
            
    if contains_ua:
        has_upper_arm.append(jf.name)

print("\n--- JSON Inspection Summary ---")
print(f"Total JSON files inspected: {len(json_files)}")
print(f"All Unique Labels found: {labels_found}")
print(f"All Unique Shape Types found: {shape_types_found}")
print(f"Shape count per image distribution: {dict(sorted(shapes_distribution.items()))}")
print(f"JSONs containing at least one 'upper_arm' shape: {len(has_upper_arm)}")
print(f"JSONs containing zero shapes: {len(zero_shapes)}")
if zero_shapes:
    print(f"  Zero-shape filenames: {zero_shapes}")
print(f"Labels other than 'upper_arm': {len(other_label_files)}")
if other_label_files:
    print(f"  Non-'upper_arm' entries: {other_label_files}")

# 3. Check Metadata CSVs
csv1_path = Path("experiments/upper_arm_segmentation/annotation_metadata.csv")
csv2_path = Path("experiments/upper_arm_segmentation/metadata/annotation_metadata.csv")

df1 = pd.read_csv(csv1_path)
df2 = pd.read_csv(csv2_path)

print("\n--- Metadata CSV Comparison ---")
print(f"CSV 1 ({csv1_path.as_posix()}): {len(df1)} rows, columns: {list(df1.columns)}")
print(f"CSV 2 ({csv2_path.as_posix()}): {len(df2)} rows, columns: {list(df2.columns)}")

identical = df1.equals(df2)
print(f"Are the two metadata CSVs exactly identical? {identical}")

# 4. Image Coverage & Duplicates
jpg_names = set(p.name for p in jpg_files)
json_stems = set(p.stem for p in json_files)
jpg_stems = set(p.stem for p in jpg_files)

csv1_images = set(df1["image_name"])

print("\n--- Image Coverage & Duplicates ---")
print(f"Total .jpg files in images/: {len(jpg_files)} (Unique: {len(jpg_names)})")
print(f"Duplicates in .jpg filenames: {len(jpg_files) - len(jpg_names)}")
print(f"Total images in metadata CSV: {len(df1)} (Unique: {len(csv1_images)})")
print(f"Duplicates in metadata CSV: {len(df1) - len(csv1_images)}")

missing_from_metadata = jpg_names - csv1_images
print(f"Images in folder but MISSING from metadata CSV: {len(missing_from_metadata)}")
if missing_from_metadata:
    print(f"  Missing names: {missing_from_metadata}")

paired_count = len(jpg_stems.intersection(json_stems))
unpaired_jpg = jpg_stems - json_stems
unpaired_json = json_stems - jpg_stems

print(f"Images with corresponding JSON: {paired_count} / {len(jpg_files)}")
print(f"JPGs without JSON: {len(unpaired_jpg)}")
print(f"JSONs without JPG: {len(unpaired_json)}")

# 5. Inspect existing qc_masks.py
qc_path = Path("experiments/upper_arm_segmentation/qc_masks.py")
print(f"\n--- qc_masks.py ---")
print(f"Path: {qc_path.as_posix()} | Exists: {qc_path.exists()} | Size: {qc_path.stat().st_size} bytes")
