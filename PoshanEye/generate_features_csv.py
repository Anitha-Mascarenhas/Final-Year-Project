import os
import csv

from face_landmarks import FaceLandmarkExtractor
from pose_landmarks import PoseLandmarkExtractor
from feature_engineering import FeatureEngineer

# --------------------------------------------------
# Configuration
# --------------------------------------------------

IMAGE_FOLDER = "data/sample_images/ANTHROVISION/frontal1"
OUTPUT_CSV = "outputs/engineered_features.csv"

# --------------------------------------------------
# Initialize Modules
# --------------------------------------------------

face_extractor = FaceLandmarkExtractor()
pose_extractor = PoseLandmarkExtractor()
engineer = FeatureEngineer()

# --------------------------------------------------
# CSV Columns
# --------------------------------------------------

fieldnames = [
    "image_name",
    "folder",
    "face_width",
    "face_height",
    "eye_distance",
    "mouth_width",
    "jaw_width",
    "shoulder_width",
    "left_arm_length",
    "right_arm_length",
    "face_ratio",
    "eye_ratio",
    "mouth_ratio"
]

os.makedirs("outputs", exist_ok=True)

processed = 0
skipped = 0
errors = 0

with open(OUTPUT_CSV, "w", newline="") as csvfile:

    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    # Walk through every folder and subfolder
    for root, dirs, files in os.walk(IMAGE_FOLDER):

        for filename in files:

            if not filename.lower().endswith((".jpg", ".jpeg", ".png")):
                continue

            image_path = os.path.join(root, filename)

            folder_name = os.path.basename(root)

            print(f"Processing: {image_path}")

            try:

                face = face_extractor.extract_from_image(image_path)
                pose = pose_extractor.extract_from_image(image_path)

                if face is None:
                    print("   -> Face not detected.")
                    skipped += 1
                    continue

                if pose is None:
                    print("   -> Pose not detected.")
                    skipped += 1
                    continue

                features = engineer.generate_feature_vector(face, pose)

                row = {
                    "image_name": filename,
                    "folder": folder_name,
                    **features
                }

                writer.writerow(row)

                processed += 1

            except Exception as e:

                print(f"   -> Error: {e}")
                errors += 1

print("\n========================================")
print("Feature Extraction Complete")
print("========================================")
print(f"Processed Images : {processed}")
print(f"Skipped Images   : {skipped}")
print(f"Errors           : {errors}")
print(f"CSV Saved At     : {OUTPUT_CSV}")
print("========================================")