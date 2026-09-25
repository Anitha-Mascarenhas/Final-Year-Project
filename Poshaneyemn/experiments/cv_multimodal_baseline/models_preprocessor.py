"""Feature pipelines and preprocessing transformers for CV multimodal baseline.

All scaling and imputation parameters are fit STRICTLY on the training split,
preventing any data leakage into validation or test splits.
"""

from typing import List, Optional, Tuple
import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler


class MultimodalPreprocessor:
    """Encapsulates strictly-isolated preprocessing for tabular modalities."""

    def __init__(
        self,
        measurement_cols: List[str],
        cv_cols: List[str],
    ):
        self.measurement_cols = measurement_cols
        self.cv_cols = cv_cols

        # Imputers: fit strictly on train split
        self.measurement_imputer = SimpleImputer(strategy="median")
        self.cv_imputer = SimpleImputer(strategy="median")

        # Scalers: fit strictly on train split
        self.measurement_scaler = StandardScaler()
        self.cv_scaler = StandardScaler()

        self.is_fitted = False

    def fit(self, train_df: pd.DataFrame) -> "MultimodalPreprocessor":
        """Fit imputers and scalers using ONLY the training split."""
        # Fit measurement pipeline
        meas_train = train_df[self.measurement_cols].values
        self.measurement_imputer.fit(meas_train)
        meas_imputed = self.measurement_imputer.transform(meas_train)
        self.measurement_scaler.fit(meas_imputed)

        # Fit CV pipeline
        cv_train = train_df[self.cv_cols].values
        self.cv_imputer.fit(cv_train)
        cv_imputed = self.cv_imputer.transform(cv_train)
        self.cv_scaler.fit(cv_imputed)

        self.is_fitted = True
        return self

    def transform_measurements(self, df: pd.DataFrame) -> np.ndarray:
        """Transform measurement features using train-fitted imputer and scaler."""
        if not self.is_fitted:
            raise RuntimeError("Preprocessor must be fitted on train set before transforming.")
        raw = df[self.measurement_cols].values
        imputed = self.measurement_imputer.transform(raw)
        scaled = self.measurement_scaler.transform(imputed)
        return scaled

    def transform_cv(self, df: pd.DataFrame) -> np.ndarray:
        """Transform CV features using train-fitted imputer and scaler."""
        if not self.is_fitted:
            raise RuntimeError("Preprocessor must be fitted on train set before transforming.")
        raw = df[self.cv_cols].values
        imputed = self.cv_imputer.transform(raw)
        scaled = self.cv_scaler.transform(imputed)
        return scaled

    def transform_multimodal(self, df: pd.DataFrame) -> np.ndarray:
        """Transform and concatenate measurement and CV features."""
        meas_scaled = self.transform_measurements(df)
        cv_scaled = self.transform_cv(df)
        return np.hstack([meas_scaled, cv_scaled])
