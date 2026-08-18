from pathlib import Path

import numpy as np
from PIL import Image
import tensorflow as tf
import joblib


BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "models" / "best_model.tflite"
LABEL_ENCODER_PATH = BASE_DIR / "models" / "label_encoder.pkl"


class PoshanEyePredictor:
    def __init__(self):
        # Load TFLite model
        self.interpreter = tf.lite.Interpreter(
            model_path=str(MODEL_PATH)
        )
        self.interpreter.allocate_tensors()

        self.input_details = self.interpreter.get_input_details()
        self.output_details = self.interpreter.get_output_details()

        # Load the exact class mapping used during training
        self.label_encoder = joblib.load(LABEL_ENCODER_PATH)
        self.class_names = list(self.label_encoder.classes_)

        print("Model loaded successfully")
        print("Classes:", self.class_names)

    def preprocess_image(self, image_path: str):
        image = Image.open(image_path).convert("RGB")

        image = image.resize((224, 224))

        image = np.array(image, dtype=np.float32)

        # MobileNetV2 preprocessing
        image = image / 127.5 - 1.0

        image = np.expand_dims(image, axis=0)

        return image

    def predict(self, image_path: str):
        image = self.preprocess_image(image_path)

        input_index = self.input_details[0]["index"]
        output_index = self.output_details[0]["index"]

        self.interpreter.set_tensor(input_index, image)
        self.interpreter.invoke()

        probabilities = self.interpreter.get_tensor(output_index)[0]

        predicted_index = int(np.argmax(probabilities))
        predicted_class = self.class_names[predicted_index]
        confidence = float(probabilities[predicted_index])

        return {
            "prediction": predicted_class,
            "confidence": confidence,
            "probabilities": {
                self.class_names[i]: float(probabilities[i])
                for i in range(len(self.class_names))
            },
        }


predictor = PoshanEyePredictor()


def run_prediction(image_path: str):
    return predictor.predict(image_path)