from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from config import CV_FEATURE_COLUMNS, MEASUREMENT_COLUMNS
from utils import save_joblib, load_joblib


class MeasurementFeaturePipeline:
    """Preprocess measurement features with imputation and scaling."""

    def __init__(self, feature_columns: list[str] | None = None):
        self.feature_columns = feature_columns or MEASUREMENT_COLUMNS
        self.pipeline = Pipeline(
            [
                ("imputer", SimpleImputer(strategy="median")),
                ("scaler", StandardScaler()),
            ]
        )

    def fit(self, df: pd.DataFrame) -> "MeasurementFeaturePipeline":
        self.pipeline.fit(df[self.feature_columns])
        return self

    def transform(self, df: pd.DataFrame) -> np.ndarray:
        return self.pipeline.transform(df[self.feature_columns])

    def fit_transform(self, df: pd.DataFrame) -> np.ndarray:
        return self.pipeline.fit_transform(df[self.feature_columns])

    def save(self, path: Path) -> None:
        save_joblib(path, {"feature_columns": self.feature_columns, "pipeline": self.pipeline})

    def load(self, path: Path) -> "MeasurementFeaturePipeline":
        payload = load_joblib(path)
        if isinstance(payload, dict) and "pipeline" in payload:
            self.pipeline = payload["pipeline"]
            self.feature_columns = payload.get("feature_columns", self.feature_columns)
        else:
            self.pipeline = payload
            if self.feature_columns is None and hasattr(self.pipeline, "feature_names_in_"):
                self.feature_columns = list(self.pipeline.feature_names_in_)
        return self


class CVFeaturePipeline:
    """Preprocess computer vision engineered features."""

    def __init__(self, feature_columns: list[str] | None = None):
        self.feature_columns = feature_columns or CV_FEATURE_COLUMNS
        self.pipeline = Pipeline(
            [
                ("imputer", SimpleImputer(strategy="median")),
                ("scaler", StandardScaler()),
            ]
        )

    def fit(self, df: pd.DataFrame) -> "CVFeaturePipeline":
        if self.feature_columns is None:
            self.feature_columns = CV_FEATURE_COLUMNS
        self.pipeline.fit(df[self.feature_columns])
        return self

    def transform(self, df: pd.DataFrame | np.ndarray) -> np.ndarray:
        if isinstance(df, pd.DataFrame):
            return self.pipeline.transform(df[self.feature_columns])
        return self.pipeline.transform(df)

    def fit_transform(self, df: pd.DataFrame | np.ndarray) -> np.ndarray:
        if isinstance(df, pd.DataFrame):
            return self.pipeline.fit_transform(df[self.feature_columns])
        return self.pipeline.fit_transform(df)

    def save(self, path: Path) -> None:
        save_joblib(path, {"feature_columns": self.feature_columns, "pipeline": self.pipeline})

    def load(self, path: Path) -> "CVFeaturePipeline":
        payload = load_joblib(path)
        if isinstance(payload, dict) and "pipeline" in payload:
            self.pipeline = payload["pipeline"]
            self.feature_columns = payload.get("feature_columns", self.feature_columns)
        else:
            self.pipeline = payload
            if self.feature_columns is None and hasattr(self.pipeline, "feature_names_in_"):
                self.feature_columns = list(self.pipeline.feature_names_in_)
        if self.feature_columns is None:
            self.feature_columns = CV_FEATURE_COLUMNS
        return self

    def get_feature_columns(self) -> list[str]:
        return self.feature_columns or CV_FEATURE_COLUMNS


class ImageFeaturePipeline:
    """Bundle image file paths and labels for TF training."""

    @staticmethod
    def extract_image_paths(df: pd.DataFrame, path_column: str = "image_path") -> np.ndarray:
        return df[path_column].astype(str).values

    @staticmethod
    def extract_labels(df: pd.DataFrame) -> np.ndarray:
        return df["label"].astype(int).values
