"""Configuration for the PoshanEye production hybrid pipeline."""

from __future__ import annotations

from pathlib import Path

PRODUCTION_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = PRODUCTION_DIR.parent

# ---------------------------------------------------------------------------
# Inputs (existing repo artifacts; nothing here is modified or deleted)
# ---------------------------------------------------------------------------
ANTHROVISION_CSV = PROJECT_ROOT / "dataset" / "ANTHROVISION" / "anthrovision_labels.csv"
ANTHROVISION_FRONTAL1_DIR = PROJECT_ROOT / "dataset" / "ANTHROVISION" / "frontal1"
CV_FEATURES_CSV = (
    PROJECT_ROOT / "experiments" / "cv_features_clean" / "results" / "cv_features_clean.csv"
)
SEG_FEATURES_CSV = (
    PROJECT_ROOT
    / "experiments"
    / "upper_arm_segmentation"
    / "deeplabv3"
    / "results"
    / "segmentation_features.csv"
)
DEEPLAB_WEIGHTS = (
    PROJECT_ROOT / "experiments" / "upper_arm_segmentation" / "deeplabv3" / "best_model.weights.h5"
)
DEEPLAB_ARCH = PROJECT_ROOT / "experiments" / "upper_arm_segmentation" / "deeplabv3" / "model.py"
LEGACY_IMAGE_MODEL = PROJECT_ROOT / "models" / "image_best.h5"  # frozen; read-only
FROZEN_SPLITS_JSON = (
    PROJECT_ROOT / "experiments" / "cv_multimodal_baseline" / "split_indices.json"
)

# ---------------------------------------------------------------------------
# Outputs (new artifacts, clearly different names from legacy best_model.*)
# ---------------------------------------------------------------------------
ARTIFACT_DIR = PRODUCTION_DIR / "artifacts"
MODELS_OUT_DIR = PROJECT_ROOT / "models"
RESULTS_DIR = PRODUCTION_DIR / "results"
TESTS_DIR = PRODUCTION_DIR / "tests"

SVM_FILENAME = "hybrid_production_svm.joblib"          # fused-vector classifier
PREPROCESSOR_JSON = "hybrid_production_preprocessor.json"  # exact scaling params for Flutter
LABEL_MAP_JSON = "hybrid_production_label_map.json"
IMAGE_TFLITE_FILENAME = "hybrid_production_image_feature_extractor.tflite"
IMAGE_FEATURE_SPEC_JSON = "hybrid_production_image_feature_spec.json"
MANIFEST_JSON = "hybrid_production_manifest.json"
SEG_FEAT_TRAIN_CSV = "segmentation_features_train.csv"  # runtime extractor output for train rows

# ---------------------------------------------------------------------------
# Anthropometric features
# ---------------------------------------------------------------------------
# Raw anthropometric inputs. Gender is encoded as gender_male in [0, 1].
# Waistline does not exist in the labeled AnthroVision table (only the unlabeled ARAN
# dataset carries it), so the production feature vector reserves a waist_cm slot that
# is median-imputed when unavailable; it becomes informative the moment a waist
# measurement is supplied (Flutter input or a labeled waist dataset).
ANTHROPOMETRIC_COLUMNS = [
    "age_months",
    "gender_male",
    "height_cm",
    "weight_kg",
    "head_circumference_cm",
    "waist_cm",
    "muac_cm",
    "bmi",
]
DERIVED_ANTHROPOMETRIC_COLUMNS = ["bmi"]  # derived feature kept in the raw group
GENDER_COLUMN = "gender_male"
WAIST_COLUMN = "waist_cm"  # reserved slot; median-imputed during training

# ---------------------------------------------------------------------------
# CV features (MediaPipe FaceMesh + Pose, existing extraction code)
# ---------------------------------------------------------------------------
CV_FACE_FEATURES = [
    "face_width",
    "face_height",
    "eye_distance",
    "mouth_width",
    "jaw_width",
    "face_ratio",
    "eye_ratio",
    "mouth_ratio",
]
CV_POSE_FEATURES = [
    "shoulder_width",
    "left_upper_arm_length",
    "right_upper_arm_length",
    "left_forearm_length",
    "right_forearm_length",
    "left_total_arm_length",
    "right_total_arm_length",
    "left_upper_arm_to_shoulder_ratio",
    "right_upper_arm_to_shoulder_ratio",
    "left_forearm_to_shoulder_ratio",
    "right_forearm_to_shoulder_ratio",
    "left_total_arm_to_shoulder_ratio",
    "right_total_arm_to_shoulder_ratio",
]
CV_FEATURE_COLUMNS = CV_FACE_FEATURES + CV_POSE_FEATURES  # 21 features

# ---------------------------------------------------------------------------
# Segmentation features (DeepLabV3+ upper-arm masks, existing extraction code)
# ---------------------------------------------------------------------------
SEGMENTATION_FEATURE_COLUMNS = [
    "total_arm_area_norm",
    "left_arm_area_norm",
    "right_arm_area_norm",
    "left_arm_width_norm",
    "right_arm_width_norm",
    "left_arm_height_norm",
    "right_arm_height_norm",
    "left_arm_aspect_ratio",
    "right_arm_aspect_ratio",
    "total_arm_area",
    "num_arms_detected",
]  # 11 features (scale-normalized set prioritized; raw pixel areas kept last)

# ---------------------------------------------------------------------------
# Image features (MobileNetV2 feature extractor, NOT a classifier)
# ---------------------------------------------------------------------------
IMAGE_FEATURE_DIM = 128  # penultimate Dense(128, relu) of the legacy image model
IMAGE_INPUT_SIZE = (224, 224)

# ---------------------------------------------------------------------------
# Classifier / training
# ---------------------------------------------------------------------------
# Label mapping used by the frozen multimodal baseline splits and every existing
# confusion matrix in this repo (cv_multimodal_baseline/config.py CLASS_MAPPING).
# The frozen split JSON only stores child ids, so this mapping must stay identical.
CLASS_NAMES = ["healthy", "underweight", "stunted", "stunted and underweight"]
TARGET_COLUMN = "multiclass_label"
RANDOM_STATE = 42
SVM_C = 1.0
SVM_KERNEL = "rbf"

CLASS_TO_INDEX = {name: i for i, name in enumerate(CLASS_NAMES)}
