"""
Strictly isolated preprocessor for multimodal modalities with segmentation features.

All imputation and scaling parameters are fit STRICTLY on the training split,
preventing any data leakage into validation or test splits.
"""

from typing import List
import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler


class SegmentationBaselinePreprocessor:
    """Encapsulates strictly-isolated preprocessing for all modality arms."""

    def __init__(
        self,
        measurement_cols: List[str],
        cv_landmark_cols: List[str],
        seg_cols: List[str],
    ):
        self.measurement_cols = measurement_cols
        self.cv_landmark_cols = cv_landmark_cols
        self.seg_cols = seg_cols

        # Imputers: fit strictly on train split
        self.meas_imputer = SimpleImputer(strategy="median")
        self.landmark_imputer = SimpleImputer(strategy="median")
        self.seg_imputer = SimpleImputer(strategy="median")

        # Scalers: fit strictly on train split
        self.meas_scaler = StandardScaler()
        self.landmark_scaler = StandardScaler()
        self.seg_scaler = StandardScaler()

        self.is_fitted = False

    def fit(self, train_df: pd.DataFrame) -> "SegmentationBaselinePreprocessor":
        """Fit imputers and scalers using ONLY the training split."""
        # 1. Measurements
        meas_train = train_df[self.measurement_cols].values
        self.meas_imputer.fit(meas_train)
        meas_imp = self.meas_imputer.transform(meas_train)
        self.meas_scaler.fit(meas_imp)

        # 2. CV Landmark features
        lm_train = train_df[self.cv_landmark_cols].values
        self.landmark_imputer.fit(lm_train)
        lm_imp = self.landmark_imputer.transform(lm_train)
        self.landmark_scaler.fit(lm_imp)

        # 3. Segmentation features
        seg_train = train_df[self.seg_cols].values
        self.seg_imputer.fit(seg_train)
        seg_imp = self.seg_imputer.transform(seg_train)
        self.seg_scaler.fit(seg_imp)

        self.is_fitted = True
        return self

    def transform_measurements(self, df: pd.DataFrame) -> np.ndarray:
        """Transform measurement features using train-fitted parameters."""
        if not self.is_fitted:
            raise RuntimeError("Preprocessor must be fitted on train set first.")
        raw = df[self.measurement_cols].values
        imputed = self.meas_imputer.transform(raw)
        return self.meas_scaler.transform(imputed)

    def transform_landmarks(self, df: pd.DataFrame) -> np.ndarray:
        """Transform CV landmark features using train-fitted parameters."""
        if not self.is_fitted:
            raise RuntimeError("Preprocessor must be fitted on train set first.")
        raw = df[self.cv_landmark_cols].values
        imputed = self.landmark_imputer.transform(raw)
        return self.landmark_scaler.transform(imputed)

    def transform_segmentation(self, df: pd.DataFrame) -> np.ndarray:
        """Transform segmentation features using train-fitted parameters."""
        if not self.is_fitted:
            raise RuntimeError("Preprocessor must be fitted on train set first.")
        raw = df[self.seg_cols].values
        imputed = self.seg_imputer.transform(raw)
        return self.seg_scaler.transform(imputed)

    def transform_arm_a(self, df: pd.DataFrame) -> np.ndarray:
        """Arm A: Measurement-Only."""
        return self.transform_measurements(df)

    def transform_arm_b(self, df: pd.DataFrame) -> np.ndarray:
        """Arm B: Measurement + Landmark CV."""
        meas = self.transform_measurements(df)
        lm = self.transform_landmarks(df)
        return np.hstack([meas, lm])

    def transform_arm_c(self, df: pd.DataFrame) -> np.ndarray:
        """Arm C: Measurement + Segmentation."""
        meas = self.transform_measurements(df)
        seg = self.transform_segmentation(df)
        return np.hstack([meas, seg])

    def transform_arm_d(self, df: pd.DataFrame) -> np.ndarray:
        """Arm D: Measurement + Landmark CV + Segmentation."""
        meas = self.transform_measurements(df)
        lm = self.transform_landmarks(df)
        seg = self.transform_segmentation(df)
        return np.hstack([meas, lm, seg])
