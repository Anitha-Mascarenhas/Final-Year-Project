from pathlib import Path
from typing import Optional, Tuple

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

from config import (
    CLASS_NAMES,
    MEASUREMENT_COLUMNS,
    PRIMARY_IMAGE_VIEW,
    RANDOM_STATE,
    TARGET_COLUMN,
    TEST_SIZE,
    VALIDATION_SIZE,
)


class DataPreprocessor:
    """Encapsulates dataset cleaning, label encoding, and train/validation/test splitting."""

    def __init__(self, target_column: str = TARGET_COLUMN):
        self.target_column = target_column
        self.encoder = LabelEncoder()

    def clean_anthrovision(self, df: pd.DataFrame) -> pd.DataFrame:
        """Clean the AnthroVision metadata table."""
        df = df.copy()
        df = df.loc[:, ~df.columns.str.contains(r"^Unnamed")]  # drop unnamed columns
        df = df.drop_duplicates().reset_index(drop=True)
        if self.target_column in df.columns:
            df[self.target_column] = df[self.target_column].replace({"": None, "nan": None, pd.NA: None})
            df = df.dropna(subset=[self.target_column])
        df[MEASUREMENT_COLUMNS] = df[MEASUREMENT_COLUMNS].apply(pd.to_numeric, errors="coerce")
        df["Age"] = pd.to_numeric(df["Age"], errors="coerce")
        df = df.replace({"Gender": {"F": "female", "M": "male"}})
        return df

    def clean_aran(self, df: pd.DataFrame) -> pd.DataFrame:
        """Clean the ARAN measurements table and normalize column names."""
        df = df.copy()
        if "Height" in df.columns:
            df["Height"] = pd.to_numeric(df["Height"], errors="coerce")
        if "Weight" in df.columns:
            df["Weight"] = pd.to_numeric(df["Weight"], errors="coerce")
        if "Age" in df.columns:
            df["Age"] = pd.to_numeric(df["Age"], errors="coerce")
        if "HC" in df.columns:
            df["HC"] = pd.to_numeric(df["HC"], errors="coerce")
        if "Weight" in df.columns and df["Weight"].max() > 500:
            df["Weight"] = df["Weight"] / 1000
        if "BMI" not in df.columns and {"Weight", "Height"}.issubset(df.columns):
            df["BMI"] = df["Weight"] / ((df["Height"] / 100) ** 2)
        df = df.drop_duplicates().reset_index(drop=True)
        df = df.replace({"Gender": {"f": "female", "m": "male", "F": "female", "M": "male"}})
        return df

    def encode_labels(self, df: pd.DataFrame) -> pd.DataFrame:
        """Encode string labels into integer classes."""
        if self.target_column not in df.columns:
            raise ValueError(f"Target column '{self.target_column}' not found in DataFrame.")
        df = df.copy()
        df[self.target_column] = df[self.target_column].replace({"": None, "nan": None, pd.NA: None})
        df = df.dropna(subset=[self.target_column]).reset_index(drop=True)
        if df.empty:
            raise ValueError(f"No valid labels available in '{self.target_column}' after dropping missing values.")
        df[self.target_column] = df[self.target_column].astype(str)
        df["label"] = self.encoder.fit_transform(df[self.target_column])
        return df

    def split_dataset(
        self,
        df: pd.DataFrame,
        test_size: float = TEST_SIZE,
        validation_size: float = VALIDATION_SIZE,
        stratify_column: Optional[str] = "label",
    ) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame]:
        """Split the dataset into train, validation and test sets."""
        if stratify_column in df.columns:
            train_val, test = train_test_split(
                df,
                test_size=test_size,
                random_state=RANDOM_STATE,
                stratify=df[stratify_column],
            )
            val_size = validation_size / (1.0 - test_size)
            train, val = train_test_split(
                train_val,
                test_size=val_size,
                random_state=RANDOM_STATE,
                stratify=train_val[stratify_column],
            )
        else:
            train_val, test = train_test_split(
                df,
                test_size=test_size,
                random_state=RANDOM_STATE,
            )
            val_size = validation_size / (1.0 - test_size)
            train, val = train_test_split(
                train_val,
                test_size=val_size,
                random_state=RANDOM_STATE,
            )
        return train.reset_index(drop=True), val.reset_index(drop=True), test.reset_index(drop=True)

    def get_class_names(self) -> list[str]:
        return list(self.encoder.classes_)

    def validate_training_dataframe(self, df: pd.DataFrame) -> pd.DataFrame:
        """Validate the training dataframe before a stratified split."""
        if "label" not in df.columns:
            raise ValueError("Training dataframe must contain a 'label' column before splitting.")
        if df["label"].isna().any():
            nan_rows = df[df["label"].isna()].head(20)
            raise ValueError(
                f"Training dataframe contains NaN labels before split.\n"
                f"NaN label rows:\n{nan_rows.to_string(index=False)}"
            )
        if "image_path" in df.columns and df["image_path"].isna().any():
            raise ValueError("Training dataframe contains missing image_path values.")
        duplicates = df.duplicated(subset=["image_path"], keep=False).sum() if "image_path" in df.columns else 0
        if duplicates > 0:
            raise ValueError(f"Training dataframe contains {duplicates} duplicate image_path entries.")
        return df

    def save_label_encoder(self, path: Path) -> None:
        from utils import save_joblib

        save_joblib(path, self.encoder)

    def load_label_encoder(self, path: Path) -> None:
        from utils import load_joblib

        self.encoder = load_joblib(path)
