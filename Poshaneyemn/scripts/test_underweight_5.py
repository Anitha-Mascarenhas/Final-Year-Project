import os
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_PATH = os.path.join(PROJECT_ROOT, "src")

sys.path.insert(0, PROJECT_ROOT)
sys.path.insert(0, SRC_PATH)

import numpy as np
from PIL import Image
from src.predictor import TFLitePredictor

MODEL_PATH = "models/best_model.tflite"
TEST_FOLDER = sys.argv[1] if len(sys.argv) > 1 else "dataset/test_underweight"

predictor = TFLitePredictor(MODEL_PATH)

print("\n=== UNDERWEIGHT TEST ===\n")

for filename in sorted(os.listdir(TEST_FOLDER)):
    if not filename.lower().endswith((".jpg", ".jpeg", ".png")):
        continue

    path = os.path.join(TEST_FOLDER, filename)

    image = Image.open(path).convert("RGB")
    image = image.resize((224, 224))

    image_array = np.array(image, dtype=np.float32)
    image_array = image_array / 255.0
    image_array = np.expand_dims(image_array, axis=0)

    result = predictor.infer(image_array)

    print(f"Image: {filename}")
    print(f"Prediction: {result['prediction']}")
    print(f"Confidence: {result['confidence']:.4f}")
    print("Probabilities:")

    for label, probability in result["probabilities"].items():
        print(f"  {label}: {probability:.4f}")

    print("-" * 60)