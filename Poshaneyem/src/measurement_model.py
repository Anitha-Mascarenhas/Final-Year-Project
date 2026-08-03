import os
import joblib

from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix
)

from data_preprocessing import DataPreprocessor


class MeasurementModel:

    def __init__(self):

        self.processor = DataPreprocessor()

        self.processor.clean_dataset()

        self.processor.encode_labels()

        self.train_df, self.test_df = self.processor.train_test_split()

        self.features = [
            "Height",
            "Weight",
            "MUAC",
            "HC",
            "Age",
            "BMI"
        ]

    def train(self):

        X_train = self.train_df[self.features]
        y_train = self.train_df["label"]

        X_test = self.test_df[self.features]
        y_test = self.test_df["label"]

        self.model = RandomForestClassifier(
            n_estimators=300,
            class_weight="balanced",
            random_state=42
        )

        print("\nTraining Measurement Model...\n")

        self.model.fit(X_train, y_train)

        predictions = self.model.predict(X_test)

        print("Accuracy :", accuracy_score(y_test, predictions))

        print("\nClassification Report\n")

        print(
            classification_report(
                y_test,
                predictions,
                target_names=self.processor.encoder.classes_
            )
        )

        print("Confusion Matrix\n")

        print(confusion_matrix(y_test, predictions))

    def save(self):

        models_path = os.path.join(
            self.processor.project_root,
            "models"
        )

        os.makedirs(models_path, exist_ok=True)

        joblib.dump(
            self.model,
            os.path.join(
                models_path,
                "measurement_model.pkl"
            )
        )

        joblib.dump(
            self.processor.encoder,
            os.path.join(
                models_path,
                "label_encoder.pkl"
            )
        )

        print("\nModel Saved Successfully")


if __name__ == "__main__":

    model = MeasurementModel()

    model.train()

    model.save()