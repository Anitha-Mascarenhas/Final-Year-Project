"""Configuration for the isolated CHILD-LEVEL balanced BINARY image experiment.

This experiment answers one question: can the MobileNetV2 image branch learn
healthy vs malnourished when (a) the child, not the photo, is the unit of
splitting, (b) no child appears in more than one split, and (c) the two classes
contain an equal number of *children* (no duplication, no synthetic children)?

Everything writes ONLY under ``Poshaneyemn/experiments/image_model_binary_child_level/``.
No production source file, model artifact, backend file or Flutter file is touched.

Named ``exp_config.py`` (not ``config.py``) so it can never shadow ``src/config.py``.
"""

from __future__ import annotations

from pathlib import Path

EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parent.parent
SRC_DIR = PROJECT_ROOT / "src"

ARTIFACT_DIR = EXPERIMENT_DIR / "artifacts"
RESULT_DIR = EXPERIMENT_DIR / "results"
LOG_DIR = EXPERIMENT_DIR / "logs"
CACHE_DIR = EXPERIMENT_DIR / "cache"  # uint8 image cache (regenerable, safe to delete)

# --------------------------------------------------------------------------- #
# label definition
# --------------------------------------------------------------------------- #
POSITIVE_CLASS = "malnourished"
NEGATIVE_CLASS = "healthy"

# AnthroVision multiclass label -> subgroup used for the held-out analysis
SUBGROUPS = ("underweight", "stunted", "stunted and underweight")
MALNOURISHED_LABELS = ("underweight", "stunted", "stunted and underweight")

# --------------------------------------------------------------------------- #
# split: child-level, stratified by the binary class, seed 42
# --------------------------------------------------------------------------- #
RANDOM_STATE = 42
TRAIN_FRACTION = 0.70
VAL_FRACTION = 0.15
TEST_FRACTION = 0.15

# --------------------------------------------------------------------------- #
# training (kept at the project defaults so results are comparable with the
# existing 4-class experiment and the production baseline)
# --------------------------------------------------------------------------- #
BATCH_SIZE = 32
IMAGE_SIZE = (224, 224)
EPOCHS = 25
LEARNING_RATE = 1e-4
DROPOUT = 0.3
DENSE_UNITS = 128

EARLY_STOPPING_PATIENCE = 5
LR_REDUCTION_PATIENCE = 3
LR_REDUCTION_FACTOR = 0.5

# Selection metric: validation balanced accuracy (the dataset is balanced, so
# plain accuracy is no longer pathological, but balanced accuracy is the metric
# that actually answers the question). An epoch only becomes a candidate if it
# keeps healthy recall at or above this floor, so the model cannot win by
# predicting "malnourished" everywhere.
PRIMARY_METRIC = "balanced_accuracy"
HEALTHY_RECALL_FLOOR = 0.50

# --------------------------------------------------------------------------- #
# augmentation: TRAINING images only. Conservative, appropriate for child
# photographs -- no rotation/shear/colour jitter that would distort bodies.
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
# smoke mode (verifies the pipeline without a full run)
# --------------------------------------------------------------------------- #
SMOKE_CHILDREN_PER_CLASS = 40
SMOKE_EPOCHS = 2
