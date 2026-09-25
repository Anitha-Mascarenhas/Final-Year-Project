import os
from pathlib import Path

# Paths
PROJECT_ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT_DIR = Path(__file__).resolve().parent
RESULTS_DIR = EXPERIMENT_DIR / "results"

ANTHROVISION_CSV = PROJECT_ROOT / "dataset" / "ANTHROVISION" / "anthrovision_labels.csv"
CV_FEATURES_CSV = PROJECT_ROOT / "experiments" / "cv_features_clean" / "results" / "cv_features_clean.csv"
SPLITS_FILE = EXPERIMENT_DIR / "split_indices.json"

# Features
# Selected 15 clean, direct landmark geometric features
# Excluded: multi-view ratios with extreme geometric distortions/outliers
CV_FEATURE_COLUMNS = [
    "face_width", "face_height", "eye_distance", "mouth_width", "jaw_width",
    "face_ratio", "eye_ratio", "mouth_ratio", "shoulder_width",
    "left_upper_arm_length", "left_forearm_length", "left_total_arm_length",
    "right_upper_arm_length", "right_forearm_length", "right_total_arm_length"
]

MEASUREMENT_COLUMNS = ["Height", "Weight", "MUAC", "HC", "Age", "BMI"]
TARGET_COLUMN = "multiclass_label"

CLASS_NAMES = ["healthy", "underweight", "stunted", "stunted and underweight"]
CLASS_MAPPING = {name: i for i, name in enumerate(CLASS_NAMES)}

RANDOM_STATE = 42
TRAIN_RATIO = 0.70
VAL_RATIO = 0.15
TEST_RATIO = 0.15
