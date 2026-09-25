"""
Configuration for Segmentation Feature Baseline Experiment.

Completely isolated under experiments/segmentation_feature_baseline/
Reuses the exact frozen child-level splits from cv_multimodal_baseline.
"""

from pathlib import Path

# Paths
EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parents[1]
RESULTS_DIR = EXPERIMENT_DIR / "results"

ANTHROVISION_CSV = PROJECT_ROOT / "dataset" / "ANTHROVISION" / "anthrovision_labels.csv"
CV_LANDMARK_CSV = PROJECT_ROOT / "experiments" / "cv_features_clean" / "results" / "cv_features_clean.csv"
SEG_FEATURES_CSV = PROJECT_ROOT / "experiments" / "upper_arm_segmentation" / "deeplabv3" / "results" / "segmentation_features.csv"
FROZEN_SPLITS_FILE = PROJECT_ROOT / "experiments" / "cv_multimodal_baseline" / "split_indices.json"

# Features definitions
MEASUREMENT_COLUMNS = ["Height", "Weight", "MUAC", "HC", "Age", "BMI"]

CV_LANDMARK_COLUMNS = [
    "face_width", "face_height", "eye_distance", "mouth_width", "jaw_width",
    "face_ratio", "eye_ratio", "mouth_ratio", "shoulder_width",
    "left_upper_arm_length", "left_forearm_length", "left_total_arm_length",
    "right_upper_arm_length", "right_forearm_length", "right_total_arm_length"
]

SEGMENTATION_COLUMNS = [
    "total_arm_area", "left_arm_area", "right_arm_area",
    "left_arm_width", "right_arm_width", "left_arm_height", "right_arm_height",
    "left_arm_aspect_ratio", "right_arm_aspect_ratio",
    "total_arm_area_norm", "left_arm_area_norm", "right_arm_area_norm",
    "left_arm_width_norm", "right_arm_width_norm", "left_arm_height_norm", "right_arm_height_norm"
]

TARGET_COLUMN = "multiclass_label"
CLASS_NAMES = ["healthy", "underweight", "stunted", "stunted and underweight"]
CLASS_MAPPING = {name: i for i, name in enumerate(CLASS_NAMES)}

RANDOM_STATE = 42
