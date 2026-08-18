from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf

from config import LABELS_FILENAME, MODEL_DIR, OUTPUT_DIR, CLASS_NAMES
from data_loader import DatasetLoader
from evaluation import Evaluation
from features import CVFeaturePipeline, MeasurementFeaturePipeline
from preprocessing import DataPreprocessor
from serving import ModelExporter
from tf_data import build_hybrid_dataset, preprocess_image
from utils import ensure_dir


def ensure_output_dirs() -> tuple[Path, Path]:
    output_dir = ensure_dir(OUTPUT_DIR)
    models_dir = ensure_dir(output_dir / "models")
    return output_dir, models_dir


def build_hybrid_dataset_from_df(
    df: pd.DataFrame,
    measurement_pipeline: MeasurementFeaturePipeline,
    cv_pipeline: CVFeaturePipeline,
) -> tf.data.Dataset:
    image_paths = df["image_path"].astype(str).values
    measurement_features = measurement_pipeline.transform(df)
    cv_features = cv_pipeline.transform(df)
    labels = df["label"].astype(int).values
    return build_hybrid_dataset(image_paths, measurement_features, cv_features, labels, shuffle=False)


def save_bar_chart(title: str, categories: list[str], values: list[float], filepath: Path) -> Path:
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.bar(categories, values, color=["#4c72b0", "#dd8452"])
    ax.set_title(title)
    ax.set_ylabel(title)
    for index, value in enumerate(values):
        ax.text(index, value + 0.01 * max(values), f"{value:.4f}", ha="center", va="bottom")
    fig.tight_layout()
    fig.savefig(filepath, dpi=300)
    plt.close(fig)
    return filepath


def collect_labels_from_dataset(dataset: tf.data.Dataset) -> np.ndarray:
    labels: list[np.ndarray] = []
    for _, batch_labels in dataset:
        labels.append(batch_labels.numpy())
    if not labels:
        return np.array([], dtype=np.int32)
    return np.concatenate(labels, axis=0)


def main() -> None:
    output_dir, models_dir = ensure_output_dirs()
    evaluator = Evaluation(models_dir)
    exporter = ModelExporter(model_dir=Path(MODEL_DIR))

    loader = DatasetLoader()
    preprocessor = DataPreprocessor()

    print("[Evaluation] Building datasets...")
    train_df, validation_df, test_df = PipelineDataBuilder().build_datasets()

    cv_features, cv_source = loader.discover_and_load_cv_features(search_root=Path("dataset"))
    if cv_features.empty:
        raise RuntimeError("No CV features were discovered for hybrid evaluation.")
    print(f"[Evaluation] CV features loaded from: {cv_source}")

    merged_train = loader.merge_modalities(train_df, cv_features)
    merged_validation = loader.merge_modalities(validation_df, cv_features)
    merged_test = loader.merge_modalities(test_df, cv_features)

    measurement_pipeline = MeasurementFeaturePipeline().load(Path(MODEL_DIR) / "measurement_pipeline.joblib")
    cv_pipeline = CVFeaturePipeline().load(Path(MODEL_DIR) / "cv_pipeline.joblib")

    print("[Evaluation] Building hybrid datasets...")
    train_dataset = build_hybrid_dataset_from_df(merged_train, measurement_pipeline, cv_pipeline)
    validation_dataset = build_hybrid_dataset_from_df(merged_validation, measurement_pipeline, cv_pipeline)
    test_dataset = build_hybrid_dataset_from_df(merged_test, measurement_pipeline, cv_pipeline)

    model_path = Path(MODEL_DIR) / "hybrid_best.h5"
    if not model_path.exists():
        raise FileNotFoundError(f"Saved hybrid model not found: {model_path}")

    print(f"[Evaluation] Loading hybrid model from {model_path}")
    try:
        model = tf.keras.models.load_model(model_path)
    except Exception as exc:
        print("[Evaluation] Failed to load saved H5 model directly, attempting compatibility workaround...")
        import keras

        class LegacyGlorotUniform(keras.initializers.GlorotUniform):
            def __init__(self, seed=None, input_axes=None, output_axes=None):
                super().__init__(seed=seed)

            def get_config(self):
                config = super().get_config()
                config.pop("input_axes", None)
                config.pop("output_axes", None)
                return config

        custom_objects = {"GlorotUniform": LegacyGlorotUniform}
        model = tf.keras.models.load_model(model_path, custom_objects=custom_objects)

    print("[Evaluation] Saving model artifacts to outputs/models...")
    model.save(models_dir / "hybrid_best.keras")
    model.save(models_dir / "hybrid_best.h5")

    print("[Evaluation] Evaluating model on test dataset...")
    test_eval = model.evaluate(test_dataset, verbose=1)
    test_loss, test_accuracy = test_eval[0], test_eval[1]

    y_true = collect_labels_from_dataset(test_dataset)
    predictions = model.predict(test_dataset, verbose=0)
    y_pred = np.argmax(predictions, axis=1)

    metrics = evaluator.classification_metrics(y_true, y_pred)
    metrics["loss"] = float(test_loss)
    metrics["accuracy"] = float(test_accuracy)
    evaluator.save_metrics(metrics, "hybrid_evaluation_metrics.json")

    evaluator.save_classification_report(y_true, y_pred, "hybrid_classification_report.txt")
    evaluator.save_confusion_matrix(y_true, y_pred, "hybrid_confusion_matrix.png")

    print("[Evaluation] Computing train and validation endpoint metrics...")
    train_eval = model.evaluate(train_dataset, verbose=0)
    validation_eval = model.evaluate(validation_dataset, verbose=0)
    save_bar_chart(
        "Training vs Validation Accuracy",
        ["Train", "Validation"],
        [float(train_eval[1]), float(validation_eval[1])],
        models_dir / "hybrid_accuracy_comparison.png",
    )
    save_bar_chart(
        "Training vs Validation Loss",
        ["Train", "Validation"],
        [float(train_eval[0]), float(validation_eval[0])],
        models_dir / "hybrid_loss_comparison.png",
    )

    exporter.save_label_map(CLASS_NAMES, models_dir / LABELS_FILENAME)

    sample_row = merged_test.iloc[[0]]
    image_path = sample_row["image_path"].iloc[0]
    image_tensor = preprocess_image(tf.constant(image_path))
    image_tensor = np.expand_dims(image_tensor, axis=0)
    sample_measurement = sample_row[measurement_pipeline.feature_columns]
    sample_cv = sample_row[cv_pipeline.get_feature_columns()]
    predictor = HybridPredictor(measurement_pipeline, cv_pipeline)
    sample_result = predictor.predict_hybrid(image_tensor, sample_measurement, sample_cv, model)
    import json

    Path(models_dir / "hybrid_single_image_inference.json").write_text(
        json.dumps(sample_result, indent=2), encoding="utf-8"
    )

    summary_text = (
        f"Hybrid model evaluation on held-out test set:\n"
        f"- Test loss: {test_loss:.4f}\n"
        f"- Test accuracy: {test_accuracy:.4f}\n"
        f"- Precision (weighted): {metrics['precision']:.4f}\n"
        f"- Recall (weighted): {metrics['recall']:.4f}\n"
        f"- F1 score (weighted): {metrics['f1_score']:.4f}\n"
        f"- Confusion matrix saved to outputs/models/hybrid_confusion_matrix.png\n"
        f"- Classification report saved to outputs/models/hybrid_classification_report.txt\n"
        f"- Model copies saved to outputs/models/hybrid_best.keras and outputs/models/hybrid_best.h5\n"
        f"- Label map saved to outputs/models/{LABELS_FILENAME}\n"
        f"- Single-image inference result saved to outputs/models/hybrid_single_image_inference.json\n"
    )
    Path(models_dir / "hybrid_evaluation_summary.txt").write_text(summary_text, encoding="utf-8")
    print(summary_text)


class PipelineDataBuilder:
    def __init__(self):
        self.loader = DatasetLoader()
        self.preprocessor = DataPreprocessor()

    def build_datasets(self) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
        anthro_df = self.loader.load_anthrovision()
        anthro_df = self.preprocessor.clean_anthrovision(anthro_df)
        anthro_df = self.preprocessor.encode_labels(anthro_df)

        aran_df = self.loader.load_aran()
        aran_df = self.preprocessor.clean_aran(aran_df)
        labeled_aran_df = None
        if self.preprocessor.target_column in aran_df.columns:
            labeled_aran_df = self.preprocessor.encode_labels(aran_df)

        labeled_dfs = [anthro_df]
        if labeled_aran_df is not None:
            labeled_dfs.append(labeled_aran_df)

        merged_df = pd.concat(labeled_dfs, ignore_index=True, sort=False)
        merged_df = merged_df.drop_duplicates(subset=["image_path"], keep="first").reset_index(drop=True)
        merged_df = self._filter_missing_image_paths(merged_df)
        merged_df = self._validate_training_dataframe(merged_df)
        return self.preprocessor.split_dataset(merged_df)

    def _validate_training_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        required_columns = ["image_path", "label"]
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise ValueError(f"Training dataframe missing required columns: {missing_columns}")
        if df["label"].isna().any():
            raise ValueError("Training dataframe contains NaN labels before split.")
        return df

    def _filter_missing_image_paths(self, df: pd.DataFrame) -> pd.DataFrame:
        if "image_path" not in df.columns:
            return df
        valid_rows = df["image_path"].astype(str).apply(lambda path: bool(path) and Path(path).exists())
        return df[valid_rows].reset_index(drop=True)


class HybridPredictor:
    def __init__(
        self,
        measurement_pipeline: MeasurementFeaturePipeline,
        cv_pipeline: CVFeaturePipeline,
    ):
        self.measurement_pipeline = measurement_pipeline
        self.cv_pipeline = cv_pipeline

    def predict_hybrid(
        self,
        image_tensor: np.ndarray,
        measurement_df: pd.DataFrame,
        cv_df: pd.DataFrame,
        model: tf.keras.Model,
    ) -> dict[str, float]:
        if image_tensor.ndim == 3:
            image_tensor = np.expand_dims(image_tensor, axis=0)
        measurement_features = self.measurement_pipeline.transform(measurement_df)
        cv_features = self.cv_pipeline.transform(cv_df)
        probabilities = model.predict(
            {
                "image_input": image_tensor.astype(np.float32),
                "measurement_input": measurement_features,
                "cv_input": cv_features,
            },
            verbose=0,
        )
        best_index = int(np.argmax(probabilities[0]))
        return {
            "prediction": CLASS_NAMES[best_index],
            "confidence": float(probabilities[0][best_index]),
            "probabilities": {CLASS_NAMES[i]: float(probabilities[0][i]) for i in range(len(CLASS_NAMES))},
        }


if __name__ == "__main__":
    main()
