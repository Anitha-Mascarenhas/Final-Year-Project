import json
import re
from pathlib import Path
from typing import Dict, Iterable, Optional

import numpy as np
import pandas as pd

from config import (
    ANTHROVISION_CSV,
    ARAN_CSV,
    ANTHROVISION_DIR,
    ARAN_DIR,
    DATA_DIR,
    IMAGE_COLUMNS,
    PRIMARY_IMAGE_VIEW,
)
from utils import normalize_path


class DatasetLoader:
    """Load and normalize AnthroVision, ARAN, and computer vision datasets."""

    def __init__(self):
        self.anthrovision_csv = ANTHROVISION_CSV
        self.aran_csv = ARAN_CSV
        self.anthrovision_root = ANTHROVISION_DIR
        self.aran_root = ARAN_DIR
        self.data_root = DATA_DIR

    def load_anthrovision(self, image_views: list[str] | None = None) -> pd.DataFrame:
        """Load the AnthroVision metadata CSV and normalize all available image views."""
        df = pd.read_csv(self.anthrovision_csv)
        image_views = image_views or IMAGE_COLUMNS
        available_views = [col for col in image_views if col in df.columns]
        for view in available_views:
            df[view] = df[view].replace({pd.NA: "", "nan": "", None: ""}).astype(str)
            df[view] = df[view].apply(lambda value: self._resolve_anthrovision_path(value) if str(value).strip() else "")

        df["image_path"] = df[available_views].apply(self._first_available_image, axis=1)
        self._report_image_path_integrity(df["image_path"])
        df["data_source"] = "anthrovision"
        return df

    def load_aran(self, image_dir: Optional[Path] = None) -> pd.DataFrame:
        """Load the ARAN metadata CSV, clean columns, and attach optional image paths."""
        df = pd.read_csv(self.aran_csv)
        df = df.rename(columns={
            "height in cm": "Height",
            "weight in grams": "Weight",
            "head circumference in cm": "HC",
            "waistline in cm": "Waistline",
            "age in months": "Age",
            "gender": "Gender",
        })
        if "Weight" in df.columns:
            df["Weight"] = pd.to_numeric(df["Weight"], errors="coerce") / 1000
        if image_dir is None:
            image_dir = self.aran_root
        image_index = self._index_aran_images([image_dir])
        df["image_id"] = df["child_id"].astype(str)
        df["image_path"] = df["image_id"].map(image_index).astype(object)
        df["data_source"] = "aran"
        return df

    def load_cv_features(
        self,
        cv_csv_path: Path,
        image_root: Optional[Path] = None,
    ) -> pd.DataFrame:
        """Load computer vision features and pivot landmark coordinates or engineered numbers."""
        cv_csv_path = Path(cv_csv_path)
        if not cv_csv_path.exists():
            raise FileNotFoundError(f"CV feature file not found: {cv_csv_path}")
        df = self._load_cv_features_from_file(cv_csv_path)
        if image_root is not None:
            image_root = Path(image_root)
        return df

    def discover_cv_feature_sources(self, root: Optional[Path] = None) -> list[Path]:
        root = Path(root) if root is not None else self.data_root
        if not root.exists():
            return []
        return sorted(
            path
            for path in root.rglob("*")
            if path.is_file() and path.suffix.lower() in {".csv", ".json"}
        )

    def discover_and_load_cv_features(
        self,
        cv_csv_path: Optional[Path] = None,
        search_root: Optional[Path] = None,
    ) -> tuple[pd.DataFrame, Optional[Path]]:
        if cv_csv_path is not None and cv_csv_path.exists():
            return self.load_cv_features(cv_csv_path), cv_csv_path

        if cv_csv_path is not None and not cv_csv_path.exists():
            print(f"Warning: CV features CSV path was provided but not found: {cv_csv_path}")

        if cv_csv_path is None:
            default_path = self.data_root / "cv_features.csv"
            if default_path.exists():
                return self.load_cv_features(default_path), default_path

        search_root = Path(search_root) if search_root is not None else self.data_root
        candidates = self.discover_cv_feature_sources(search_root)
        for candidate in candidates:
            try:
                features = self._load_cv_features_from_file(candidate)
                if not features.empty:
                    return features, candidate
            except Exception:
                continue
        return pd.DataFrame(), None

    def _load_cv_features_from_file(self, path: Path) -> pd.DataFrame:
        path = Path(path)
        if path.suffix.lower() == ".json":
            df = self._load_json_as_dataframe(path)
        else:
            df = pd.read_csv(path)
        if not isinstance(df, pd.DataFrame):
            raise ValueError(f"Unable to parse CV feature file: {path}")

        df = df.copy()
        if "image_name" in df.columns:
            df["image_id"] = df["image_name"].astype(str).apply(self._normalize_image_id)
        elif "image_id" in df.columns:
            df["image_id"] = df["image_id"].astype(str).apply(self._normalize_image_id)
        else:
            raise ValueError("CV feature file must contain an 'image_name' or 'image_id' column.")

        if {"landmark", "x", "y"}.issubset(df.columns):
            pivoted = df.pivot_table(
                index="image_id",
                columns="landmark",
                values=["x", "y"],
                aggfunc="first",
            )
            pivoted.columns = [f"{col[0]}_{col[1]}" for col in pivoted.columns]
            pivoted = pivoted.reset_index()
        else:
            pivoted = df.drop_duplicates(subset=["image_id"]).reset_index(drop=True)

        numeric_columns = [col for col in pivoted.columns if col != "image_id"]
        pivoted[numeric_columns] = pivoted[numeric_columns].apply(pd.to_numeric, errors="coerce")
        return pivoted

    def _load_json_as_dataframe(self, path: Path) -> pd.DataFrame:
        with path.open("r", encoding="utf-8") as handler:
            payload = json.load(handler)

        if isinstance(payload, list):
            return pd.json_normalize(payload)
        if isinstance(payload, dict):
            if all(isinstance(value, dict) for value in payload.values()):
                records = [dict(image_id=key, **value) for key, value in payload.items()]
                return pd.json_normalize(records)
            return pd.json_normalize(payload)
        raise ValueError("Unsupported JSON format for CV feature data.")

    def merge_modalities(
        self,
        measurement_df: pd.DataFrame,
        cv_features_df: Optional[pd.DataFrame] = None,
        image_col: str = "image_path",
        image_id_col: str = "image_id",
    ) -> pd.DataFrame:
        """Merge measurement data with CV features and preserve image references."""
        df = measurement_df.copy()
        if image_col in df.columns:
            df[image_id_col] = df[image_col].astype(str).apply(self._normalize_image_id)
        if cv_features_df is not None:
            df = df.merge(cv_features_df, on=image_id_col, how="left")
        return df

    def _resolve_anthrovision_path(self, image_path: str) -> str:
        if pd.isna(image_path) or str(image_path).strip() == "":
            return ""
        candidate = Path(str(image_path))
        if not candidate.is_absolute():
            parts = list(candidate.parts)
            if parts and parts[0].lower() == "fulldataset":
                parts = parts[1:]
            candidate = self.anthrovision_root.joinpath(*parts)
        return normalize_path(str(candidate))

    def _first_available_image(self, row: pd.Series) -> str:
        for view in row.index:
            if isinstance(row[view], str) and row[view].strip():
                return row[view]
        return ""

    def _report_image_path_integrity(self, image_paths: pd.Series) -> None:
        valid_count = 0
        missing_count = 0
        for image_path in image_paths:
            if isinstance(image_path, str) and image_path.strip():
                if Path(image_path).exists():
                    valid_count += 1
                else:
                    missing_count += 1
            else:
                missing_count += 1
        print(
            f"[AnthroVision] image path integrity: {valid_count} valid files, {missing_count} missing or invalid paths."
        )

    def _index_aran_images(self, roots: Iterable[Path]) -> Dict[str, str]:
        image_index: Dict[str, str] = {}
        for root in roots:
            root = Path(root)
            if not root.exists():
                continue
            for path in root.rglob("*"):
                if path.is_file() and path.suffix.lower() in {".jpg", ".jpeg", ".png"}:
                    image_id = path.parent.name
                    if image_id:
                        image_index.setdefault(image_id, normalize_path(str(path)))
        return image_index

    @staticmethod
    def _normalize_image_id(image_name: str) -> str:
        image_path = Path(str(image_name))
        return image_path.stem
