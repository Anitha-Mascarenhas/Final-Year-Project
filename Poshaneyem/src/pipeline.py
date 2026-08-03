from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf

from config import (
    ANTHROVISION_CSV,
    ARAN_CSV,
    CLASS_NAMES,
    LABELS_FILENAME,
    LOG_DIR,
    MEASUREMENT_COLUMNS,
    MODEL_DIR,
    OUTPUT_DIR,
    TFLITE_FILENAME,
)
from data_loader import DatasetLoader
from evaluation import Evaluation
from features import CVFeaturePipeline, ImageFeaturePipeline, MeasurementFeaturePipeline
from hybrid_model import HybridModelTrainer
from image_model import ImageModelTrainer
from preprocessing import DataPreprocessor
from utils import ensure_dir, save_json, save_joblib


class Pipeline:
    """Pipeline for building and evaluating the PoshanEye AIML models."""

    def __init__(self):
        self.loader = DatasetLoader()
        self.preprocessor = DataPreprocessor()
        self.measurement_pipeline = MeasurementFeaturePipeline()
        self.cv_pipeline = CVFeaturePipeline()
        self.image_trainer = ImageModelTrainer()
        self.hybrid_trainer = HybridModelTrainer()
        self.evaluator = Evaluation(OUTPUT_DIR)
        self.output_dir = ensure_dir(OUTPUT_DIR)
        self.model_dir = ensure_dir(MODEL_DIR)
        self.log_dir = ensure_dir(LOG_DIR)

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

        train_df, validation_df, test_df = self.preprocessor.split_dataset(merged_df)
        return train_df, validation_df, test_df

    def _validate_training_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        df = df.copy()
        required_columns = ["image_path", "label"] + MEASUREMENT_COLUMNS
        missing_columns = [col for col in required_columns if col not in df.columns]
        if missing_columns:
            raise ValueError(f"Training dataframe missing required columns: {missing_columns}")

        debug_info = {
            "shape": df.shape,
            "columns": df.columns.tolist(),
            "label_distribution": df["label"].value_counts(dropna=False).to_dict(),
            "missing_values": df.isna().sum().to_dict(),
            "nan_label_count": int(df["label"].isna().sum()),
            "duplicate_image_path_count": int(df.duplicated(subset=["image_path"], keep=False).sum()),
        }
        debug_text = [f"{key}: {value}" for key, value in debug_info.items()]
        print("\n[Pipeline Validation] Training dataframe debug info:\n" + "\n".join(debug_text))
        print("[Pipeline Validation] Dataframe head:\n", df.head(10).to_string(index=False))

        if df["label"].isna().any():
            nan_rows = df[df["label"].isna()].head(20)
            print("\n[Pipeline Validation] Rows with NaN labels:\n", nan_rows.to_string(index=False))
            raise ValueError("Training dataframe contains NaN labels before stratified split.")

        if df["image_path"].isna().any():
            nan_rows = df[df["image_path"].isna()].head(20)
            print("\n[Pipeline Validation] Rows with missing image_path:\n", nan_rows.to_string(index=False))
            raise ValueError("Training dataframe contains missing image_path values.")

        missing_measurements = df[MEASUREMENT_COLUMNS].isna().any(axis=1)
        if missing_measurements.any():
            nan_rows = df[missing_measurements].head(20)
            print("\n[Pipeline Validation] Rows with missing measurement values:\n", nan_rows.to_string(index=False))
            raise ValueError("Training dataframe contains missing measurement values.")

        if df.duplicated(subset=["image_path"], keep=False).any():
            duplicate_rows = df[df.duplicated(subset=["image_path"], keep=False)]
            print("\n[Pipeline Validation] Duplicate image_path rows:\n", duplicate_rows.head(20).to_string(index=False))
            raise ValueError("Training dataframe contains duplicate samples based on image_path.")

        return df

    def _filter_missing_image_paths(self, df: pd.DataFrame) -> pd.DataFrame:
        if "image_path" not in df.columns:
            return df

        image_paths = df["image_path"].astype(str).str.strip()
        if not image_paths.any():
            return df

        total_samples = len(df)
        valid_rows = image_paths.apply(lambda path: bool(path) and Path(path).exists())
        valid_samples = int(valid_rows.sum())
        removed_samples = total_samples - valid_samples
        print(
            f"[Pipeline] Total samples: {total_samples}, valid samples: {valid_samples}, removed samples: {removed_samples}"
        )

        filtered_df = df[valid_rows].reset_index(drop=True)
        return filtered_df

    def build_feature_pipelines(self, train_df: pd.DataFrame, cv_features_df: pd.DataFrame | None = None) -> None:
        self.measurement_pipeline.fit(train_df)
        save_joblib(self.model_dir / "measurement_pipeline.joblib", self.measurement_pipeline.pipeline)

        if cv_features_df is not None and not cv_features_df.empty:
            self.cv_pipeline.fit(cv_features_df)
            save_joblib(self.model_dir / "cv_pipeline.joblib", self.cv_pipeline.pipeline)

    def train_measurement_baselines(
        self,
        train_df: pd.DataFrame,
        validation_df: pd.DataFrame | None = None,
        test_df: pd.DataFrame | None = None,
    ) -> None:
        from measurement_models import MeasurementModelTrainer

        # Print sample counts
        print(f"[Measurement] Training samples: {len(train_df)}")
        if validation_df is not None:
            print(f"[Measurement] Validation samples: {len(validation_df)}")
        if test_df is not None:
            print(f"[Measurement] Test samples: {len(test_df)}")

        trainer = MeasurementModelTrainer(model_dir=self.model_dir)
        trainer.fit(train_df)

        # Evaluate trained models only on held-out test set
        if test_df is not None:
            trainer.evaluate_on_test(test_df)

        best = trainer.get_best_model()
        if best is not None:
            save_joblib(self.model_dir / "measurement_best_model.pkl", best.model)

        model_summary = {
            name: {
                "accuracy": result.accuracy,
                "precision": result.precision,
                "recall": result.recall,
                "f1_score": result.f1,
                "roc_auc": result.roc_auc,
            }
            for name, result in trainer.results.items()
        }
        self.evaluator.save_model_comparison_table(model_summary, "measurement_model_comparison.json")

    def train_image_model(
        self,
        train_dataset: tf.data.Dataset,
        val_dataset: tf.data.Dataset,
        num_classes: int,
    ) -> tf.keras.Model:
        history = self.image_trainer.train(train_dataset, val_dataset, num_classes)
        self.evaluator.save_training_history(history, "image_model")
        self.image_trainer.save(self.model_dir / "image_model.h5")
        self.image_trainer.save_tflite(self.model_dir / TFLITE_FILENAME)
        return self.image_trainer.model

    def train_hybrid_model(
        self,
        train_dataset: tf.data.Dataset,
        val_dataset: tf.data.Dataset,
        measurement_dim: int,
        cv_dim: int,
        num_classes: int,
    ) -> tf.keras.Model:
        model = self.hybrid_trainer.build_model(
            num_classes=num_classes,
            measurement_feature_dim=measurement_dim,
            cv_feature_dim=cv_dim,
        )
        checkpoint_path = self.model_dir / "hybrid_best.h5"
        callbacks = [
            tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True),
            tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", patience=3, factor=0.5, verbose=1),
        ]

        for inputs, labels in train_dataset.take(1):
            print("[HybridModel] sample batch image shape:", inputs["image_input"].shape)
            print("[HybridModel] sample batch measurement shape:", inputs["measurement_input"].shape)
            print("[HybridModel] sample batch cv shape:", inputs["cv_input"].shape)
            print("[HybridModel] sample batch label shape:", labels.shape)
            break

        model.fit(train_dataset, validation_data=val_dataset, epochs=25, callbacks=callbacks)
        model.save(checkpoint_path)
        return model

    def save_label_map(self) -> None:
        label_map = {i: label for i, label in enumerate(CLASS_NAMES)}
        save_json(self.output_dir / LABELS_FILENAME, label_map)

    def build(self) -> None:
        raise NotImplementedError("Pipeline.build should be implemented in project-specific orchestration.")
