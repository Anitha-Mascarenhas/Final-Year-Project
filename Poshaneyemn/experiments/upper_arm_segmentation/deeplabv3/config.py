"""
Configuration for DeepLabV3+ (MobileNetV2 backbone) Upper-Arm Segmentation Experiment.
Completely isolated under experiments/upper_arm_segmentation/deeplabv3/
"""

from pathlib import Path

# Paths
EXPERIMENT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = EXPERIMENT_DIR.parents[2]
BASE_SEG_DIR = EXPERIMENT_DIR.parent

IMAGES_DIR = BASE_SEG_DIR / "images"
MASKS_DIR = BASE_SEG_DIR / "masks"
SPLITS_DIR = BASE_SEG_DIR / "splits"

TRAIN_CSV = SPLITS_DIR / "train.csv"
VAL_CSV = SPLITS_DIR / "val.csv"
TEST_CSV = SPLITS_DIR / "test.csv"

# Model Checkpoints & Output Paths
BEST_MODEL_PATH = EXPERIMENT_DIR / "best_model.weights.h5"
LAST_MODEL_PATH = EXPERIMENT_DIR / "last_model.weights.h5"
TRAINING_HISTORY_CSV = EXPERIMENT_DIR / "training_history.csv"
TEST_METRICS_JSON = EXPERIMENT_DIR / "test_metrics.json"
VISUALIZATIONS_DIR = EXPERIMENT_DIR / "visualizations"
TEST_PREDICTIONS_DIR = EXPERIMENT_DIR / "test_predictions"

# Architecture & Image
MODEL_NAME = "DeepLabV3Plus_MobileNetV2"
IMAGE_SIZE = (512, 512)
NUM_CLASSES = 2  # 0 = background, 1 = upper_arm

# Hyperparameters
RANDOM_SEED = 42
BATCH_SIZE = 4
LEARNING_RATE = 1e-4
WEIGHT_DECAY = 1e-4
MAX_EPOCHS = 50
EARLY_STOPPING_PATIENCE = 10

# Loss weights: 0.5 * CrossEntropy + 0.5 * DiceLoss
CE_WEIGHT = 0.5
DICE_WEIGHT = 0.5
SMOOTH = 1e-6
