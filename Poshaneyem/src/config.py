from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATA_DIR = PROJECT_ROOT / "dataset"
OUTPUT_DIR = PROJECT_ROOT / "outputs"
MODEL_DIR = PROJECT_ROOT / "models"
LOG_DIR = OUTPUT_DIR / "logs"
FIGURE_DIR = OUTPUT_DIR / "figures"
REPORT_DIR = OUTPUT_DIR / "reports"

ANTHROVISION_DIR = DATA_DIR / "ANTHROVISION"
ANTHROVISION_CSV = ANTHROVISION_DIR / "anthrovision_labels.csv"
ARAN_DIR = DATA_DIR / "aran"
ARAN_CSV = ARAN_DIR / "labels.csv"

# Default dataset columns and inputs
IMAGE_COLUMNS = [
    "image_path_frontal1",
    "image_path_frontal2",
    "image_path_frontal3",
    "image_path_frontal4",
    "image_path_back",
    "image_path_lateralleft",
    "image_path_lateralright",
    "image_path_selfie",
]
PRIMARY_IMAGE_VIEW = "image_path_frontal1"
MEASUREMENT_COLUMNS = ["Height", "Weight", "MUAC", "HC", "Age", "BMI"]
TARGET_COLUMN = "multiclass_label"
CLASS_NAMES = ["healthy", "underweight", "stunted", "stunted and underweight"]

# Training configuration
RANDOM_STATE = 42
TEST_SIZE = 0.20
VALIDATION_SIZE = 0.15
IMAGE_SIZE = (224, 224)
BATCH_SIZE = 32
EPOCHS = 25

# Image model and hybrid training
MOBILENET_TRAINABLE = False
LEARNING_RATE = 1e-4
WEIGHT_DECAY = 1e-5

# Flutter integration
TFLITE_FILENAME = "best_model.tflite"
LABELS_FILENAME = "label_map.json"
METADATA_FILENAME = "model_metadata.json"
