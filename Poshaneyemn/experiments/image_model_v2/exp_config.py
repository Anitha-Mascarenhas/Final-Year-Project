"""Configuration for the isolated MobileNetV2 v2 image-classifier experiment.

Everything in this experiment writes ONLY under
``Poshaneyemn/experiments/image_model_v2/``. No production source file, production
model artifact, backend file or Flutter file is touched.

This module is deliberately named ``exp_config.py`` (not ``config.py``) so that it can
never shadow ``src/config.py``, which this experiment imports.
"""

from __future__ import annotations

from pathlib import Path

EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parent.parent
SRC_DIR = PROJECT_ROOT / "src"

# --------------------------------------------------------------------------- #
# output locations (isolated)
# --------------------------------------------------------------------------- #
ARTIFACT_DIR = EXPERIMENT_DIR / "artifacts"
RESULT_DIR = EXPERIMENT_DIR / "results"
LOG_DIR = EXPERIMENT_DIR / "logs"

# --------------------------------------------------------------------------- #
# training configuration (kept identical to the project defaults so the new
# arms are comparable with the production baseline and the v1 experiment)
# --------------------------------------------------------------------------- #
RANDOM_STATE = 42
BATCH_SIZE = 32
IMAGE_SIZE = (224, 224)
EPOCHS = 25
LEARNING_RATE = 1e-4
DROPOUT = 0.3
DENSE_UNITS = 128

# The v1 experiment used FULL balanced weights (alpha = 1.0). That is already
# available as models/class_balanced_experiment/best_model.tflite and is evaluated
# here as a reference arm, so this run trains only the damped variants.
#   weight_c = (n_train / (n_classes * n_train_c)) ** alpha
ARMS: tuple[tuple[str, float], ...] = (
    ("alpha_0.25", 0.25),
    ("alpha_0.50", 0.50),
    ("alpha_0.75", 0.75),
)

# --------------------------------------------------------------------------- #
# augmentation (training split ONLY; validation/test are never augmented)
# --------------------------------------------------------------------------- #
AUGMENTATION = {
    "random_flip": "horizontal",
    "random_contrast": 0.1,
    "random_translation_height": 0.05,
    "random_translation_width": 0.05,
    "random_zoom_height": 0.05,
    "random_zoom_width": 0.05,
}

# --------------------------------------------------------------------------- #
# model selection rule (validation macro F1 primary, with a guard so we do not
# repeat the v1 collapse of the majority class)
# --------------------------------------------------------------------------- #
PRIMARY_METRIC = "macro_f1"
HEALTHY_RECALL_FLOOR = 0.80

# --------------------------------------------------------------------------- #
# reference models already on disk (read-only: never modified, never replaced)
# --------------------------------------------------------------------------- #
PRODUCTION_MODEL = PROJECT_ROOT / "models" / "best_model.tflite"
V1_EXPERIMENT_MODEL = PROJECT_ROOT / "models" / "class_balanced_experiment" / "best_model.tflite"

# The production model predates the MobileNetV2 preprocessing fix, so its native
# input convention is raw/255; v1 and v2 were trained with MobileNetV2
# preprocess_input ([-1, 1]). Both conventions are evaluated and recorded.
PREPROCESSING_MODE = {
    "production": "div255",
    "v1_balanced_alpha_1.00": "mobilenet",
}

SUPPORTED_VIEWS_NOTE = (
    "Uses the project's existing image_path column and the existing stratified "
    "train/validation/test split from DataPreprocessor.split_dataset (RANDOM_STATE=42)."
)
