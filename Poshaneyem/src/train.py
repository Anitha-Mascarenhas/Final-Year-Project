from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import tensorflow as tf

from config import CLASS_NAMES, MODEL_DIR, OUTPUT_DIR
from data_loader import DatasetLoader
from evaluation import Evaluation
from features import CVFeaturePipeline, ImageFeaturePipeline, MeasurementFeaturePipeline
from preprocessing import DataPreprocessor
from pipeline import Pipeline
from serving import ModelExporter
from tf_data import build_hybrid_dataset, build_image_dataset
from utils import ensure_dir, save_json, save_joblib


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Train the PoshanEye AIML pipeline.")
    parser.add_argument("--cv-features-csv", type=Path, help="Path to computer vision feature CSV file.")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR, help="Output directory for models and reports.")
    parser.add_argument("--model-dir", type=Path, default=MODEL_DIR, help="Directory to save trained models.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output_dir = ensure_dir(args.output_dir)
    model_dir = ensure_dir(args.model_dir)

    pipeline = Pipeline()
    train_df, validation_df, test_df = pipeline.build_datasets()

    cv_features, cv_source = pipeline.loader.discover_and_load_cv_features(
        args.cv_features_csv,
        search_root=Path("dataset"),
    )

    image_available = (
        "image_path" in train_df.columns
        and train_df["image_path"].astype(str).str.strip().ne("").any()
    )
    cv_available = not cv_features.empty

    if cv_available:
        print(f"CV features loaded from: {cv_source}")
    else:
        if args.cv_features_csv is not None:
            print(f"CV feature CSV path not available or empty: {args.cv_features_csv}")
        print("No CV features available. Continuing without CV branch.")

    if image_available and cv_available:
        training_mode = "Full Hybrid (Images + Measurements + CV Features)"
    elif image_available:
        training_mode = "Images + Measurements"
    else:
        training_mode = "Measurements only"

    print(f"Training mode: {training_mode}")

    pipeline.train_measurement_baselines(train_df, validation_df, test_df)

    def _metrics_to_dict(model: tf.keras.Model, metrics_result):
        metrics_names = list(model.metrics_names)
        print("[Evaluation] model metrics names:", metrics_names)
        if not isinstance(metrics_result, (list, tuple)):
            values = [metrics_result]
        else:
            values = list(metrics_result)
        if len(values) != len(metrics_names):
            print(
                "[Evaluation] Warning: metrics result length does not match model.metrics_names; "
                f"using first {min(len(values), len(metrics_names))} values."
            )
        return {name: float(value) for name, value in zip(metrics_names, values)}

    if image_available:
        train_image_dataset = build_image_dataset(train_df["image_path"].values, train_df["label"].values)
        validation_image_dataset = build_image_dataset(
            validation_df["image_path"].values,
            validation_df["label"].values,
            shuffle=False,
        )
        image_model = pipeline.train_image_model(train_image_dataset, validation_image_dataset, len(CLASS_NAMES))
        image_test_dataset = build_image_dataset(test_df["image_path"].values, test_df["label"].values, shuffle=False)
        image_metrics = image_model.evaluate(image_test_dataset, verbose=0)
        image_metrics_dict = _metrics_to_dict(image_model, image_metrics)
        save_json(output_dir / "image_evaluation_metrics.json", image_metrics_dict)
    else:
        print("Image data not available. Skipping image model training.")

    pipeline.build_feature_pipelines(train_df, cv_features if cv_available else None)

    if image_available and cv_available:
        merged_train = pipeline.loader.merge_modalities(train_df, cv_features)
        merged_validation = pipeline.loader.merge_modalities(validation_df, cv_features)

        measurement_pipeline = MeasurementFeaturePipeline()
        measurement_pipeline.fit(merged_train)
        measurement_features = measurement_pipeline.transform(merged_train)
        cv_pipeline = CVFeaturePipeline()
        cv_pipeline.fit(cv_features)
        cv_features_train = cv_pipeline.transform(merged_train)

        hybrid_train = build_hybrid_dataset(
            merged_train["image_path"].values,
            measurement_features,
            cv_features_train,
            merged_train["label"].values,
        )
        hybrid_val = build_hybrid_dataset(
            merged_validation["image_path"].values,
            measurement_pipeline.transform(merged_validation),
            cv_pipeline.transform(merged_validation),
            merged_validation["label"].values,
            shuffle=False,
        )
        hybrid_model = pipeline.train_hybrid_model(
            hybrid_train,
            hybrid_val,
            measurement_dim=measurement_features.shape[1],
            cv_dim=cv_features_train.shape[1],
            num_classes=len(CLASS_NAMES),
        )
        hybrid_metrics = hybrid_model.evaluate(hybrid_val, verbose=0)
        hybrid_metrics_dict = _metrics_to_dict(hybrid_model, hybrid_metrics)
        save_json(output_dir / "hybrid_evaluation_metrics.json", hybrid_metrics_dict)
    else:
        print("Skipping hybrid training because CV features or image inputs are unavailable.")

    pipeline.save_label_map()
    exporter = ModelExporter(model_dir=model_dir)
    exporter.save_label_map(CLASS_NAMES, output_dir / "label_map.json")
    print("Training complete. Models and reports are available in:", output_dir)


if __name__ == "__main__":
    main()
