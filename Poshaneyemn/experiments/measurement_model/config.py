"""Configuration for the isolated measurement-model experiment.

This file is intentionally SELF-CONTAINED (it does not import src/config.py) so it
can be loaded via importlib without shadowing the production `src/config.py` module.
Everything written by the experiment goes under experiments/measurement_model/.
"""

from pathlib import Path

# ---------------------------------------------------------------- paths
EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parent.parent          # Poshaneyemn/
RESULTS_DIR = EXPERIMENT_DIR / "results"
CONFUSION_DIR = RESULTS_DIR / "confusion_matrices"
ARTIFACTS_DIR = EXPERIMENT_DIR / "artifacts"

# Production artifacts are READ-ONLY inputs (never written to).
PRODUCTION_ENCODER_PATH = PROJECT_ROOT / "models" / "label_encoder.pkl"

# ---------------------------------------------------------------- data
TARGET_COLUMN = "multiclass_label"

# Headline feature set (Step: "Features for the headline experiment").
FEATURES = ["Height", "Weight", "MUAC", "HC", "Age", "BMI"]

# The authoritative numeric -> class mapping is defined by the FITTED LabelEncoder
# (models/label_encoder.pkl). This list is an ASSERTION target, not a source of truth.
EXPECTED_CLASS_NAMES = ["healthy", "stunted", "stunted and underweight", "underweight"]

# ---------------------------------------------------------------- fixed split (Step 1)
TRAIN_FRACTION = 0.70
VAL_FRACTION = 0.15
TEST_FRACTION = 0.15
SPLIT_RANDOM_STATE = 42          # stratified, fixed BEFORE any resampling
SPLIT_CACHE_PATH = ARTIFACTS_DIR / "split_indices.json"

# ---------------------------------------------------------------- resampling (Arm C)
SMOTE_DESIRED_K = 5              # k_neighbors = min(SMOTE_DESIRED_K, min_class_count - 1)

# ---------------------------------------------------------------- tuning (Step 3)
CV_FOLDS = 3
TUNING_SCORING = "f1_macro"      # never accuracy

PARAM_GRIDS = {
    "random_forest": {
        "n_estimators": [200, 400],
        "max_depth": [None, 12],
        "min_samples_leaf": [1, 3],
        "random_state": [SPLIT_RANDOM_STATE],
    },
    "svm_rbf": {
        "svc__C": [1.0, 10.0],
        "svc__gamma": ["scale", 0.01],
    },
    "xgboost": {
        "n_estimators": [200, 400],
        "max_depth": [3, 5],
        "learning_rate": [0.1],
        "random_state": [SPLIT_RANDOM_STATE],
    },
}
