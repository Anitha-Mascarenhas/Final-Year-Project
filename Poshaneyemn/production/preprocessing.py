"""Strictly train-fit preprocessing for the production hybrid pipeline.

Each feature group (image / CV / segmentation / anthropometric) is imputed with its
training-split median and standardized with training-split mean/std. The exact
parameters are exported to JSON so the Flutter offline inference can apply the
identical transformation without Python.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

from .config import (
    ANTHROPOMETRIC_COLUMNS,
    CV_FEATURE_COLUMNS,
    DERIVED_ANTHROPOMETRIC_COLUMNS,
    SEGMENTATION_FEATURE_COLUMNS,
)

GROUPS = {
    "image": None,  # image embedding produced by the MobileNetV2 feature extractor
    "cv": CV_FEATURE_COLUMNS,
    "segmentation": SEGMENTATION_FEATURE_COLUMNS,
    "anthropometric": ANTHROPOMETRIC_COLUMNS,
}


class HybridPreprocessor:
    """Median-impute + standard-scale each feature group, fit on the training split only."""

    def __init__(self) -> None:
        self.columns: dict[str, list[str] | None] = {}
        self.medians: dict[str, dict[str, float]] = {}
        self.means: dict[str, dict[str, float]] = {}
        self.stds: dict[str, dict[str, float]] = {}
        self.image_dim = 0
        self.fitted = False

    # ------------------------------------------------------------------ fit/transform
    def fit(self, image_features: np.ndarray, cv_df: pd.DataFrame, seg_df: pd.DataFrame,
            anthro_df: pd.DataFrame) -> "HybridPreprocessor":
        self.image_dim = int(image_features.shape[1])
        # Image embeddings from the frozen MobileNetV2 extractor are already bounded;
        # standardize them with training statistics as well so the fused vector is uniform.
        self._fit_group("image", image_features, columns=None)
        for name, df in (("cv", cv_df), ("segmentation", seg_df), ("anthropometric", anthro_df)):
            cols = GROUPS[name]
            self._fit_group(name, df[cols].to_numpy(dtype=np.float64), columns=cols)
        self.fitted = True
        return self

    def _fit_group(self, name: str, arr: np.ndarray, columns: list[str] | None) -> None:
        arr = np.asarray(arr, dtype=np.float64)
        # Median per column ignoring NaN/inf; all-NaN columns fall back to 0.0
        # (reserved slots such as waist_cm with no training coverage).
        with np.errstate(all="ignore"):
            med = np.nanmedian(np.where(np.isfinite(arr), arr, np.nan), axis=0)
        med = np.where(np.isfinite(med), med, 0.0)
        filled = np.where(np.isfinite(arr), arr, med)
        mean = filled.mean(axis=0)
        std = filled.std(axis=0)
        std = np.where(std < 1e-8, 1.0, std)
        keys = columns if columns is not None else [str(i) for i in range(arr.shape[1])]
        self.columns[name] = columns
        self.medians[name] = {k: float(v) for k, v in zip(keys, med)}
        self.means[name] = {k: float(v) for k, v in zip(keys, mean)}
        self.stds[name] = {k: float(v) for k, v in zip(keys, std)}

    def transform(self, image_features: np.ndarray, cv_df: pd.DataFrame, seg_df: pd.DataFrame,
                  anthro_df: pd.DataFrame) -> np.ndarray:
        blocks = [
            self._transform_group("image", image_features),
            self._transform_group("cv", cv_df[GROUPS["cv"]].to_numpy(dtype=np.float64)),
            self._transform_group("segmentation", seg_df[GROUPS["segmentation"]].to_numpy(dtype=np.float64)),
            self._transform_group("anthropometric", anthro_df[GROUPS["anthropometric"]].to_numpy(dtype=np.float64)),
        ]
        return np.hstack(blocks)

    def _transform_group(self, name: str, arr: np.ndarray) -> np.ndarray:
        arr = np.asarray(arr, dtype=np.float64)
        keys = self.columns[name] if self.columns.get(name) is not None else [str(i) for i in range(arr.shape[1])]
        med = np.array([self.medians[name][k] for k in keys])
        mean = np.array([self.means[name][k] for k in keys])
        std = np.array([self.stds[name][k] for k in keys])
        filled = np.where(np.isfinite(arr), arr, med)
        return (filled - mean) / std

    # ------------------------------------------------------------------ persistence
    def to_dict(self) -> dict[str, Any]:
        return {
            "version": "hybrid_production_v1",
            "feature_order": self.feature_order(),
            "groups": {
                "image": {"dim": self.image_dim},
                "cv": {"columns": GROUPS["cv"]},
                "segmentation": {"columns": GROUPS["segmentation"]},
                "anthropometric": {"columns": GROUPS["anthropometric"]},
            },
            "medians": self.medians,
            "means": self.means,
            "stds": self.stds,
        }

    def feature_order(self) -> list[str]:
        return (
            [f"image_feat_{i}" for i in range(self.image_dim)]
            + [f"cv__{c}" for c in GROUPS["cv"]]
            + [f"seg__{c}" for c in GROUPS["segmentation"]]
            + [f"anthro__{c}" for c in GROUPS["anthropometric"]]
        )

    def save(self, path: Path) -> None:
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(self.to_dict(), indent=2), encoding="utf-8")

    @classmethod
    def load(cls, path: Path) -> "HybridPreprocessor":
        data = json.loads(Path(path).read_text(encoding="utf-8"))
        prep = cls()
        prep.image_dim = data["groups"]["image"]["dim"]
        prep.columns = {
            "image": None,
            "cv": data["groups"]["cv"]["columns"],
            "segmentation": data["groups"]["segmentation"]["columns"],
            "anthropometric": data["groups"]["anthropometric"]["columns"],
        }
        prep.medians = data["medians"]
        prep.means = data["means"]
        prep.stds = data["stds"]
        prep.fitted = True
        return prep

    # ------------------------------------------------------------------ single-sample
    def transform_single(self, image_features: np.ndarray, cv_features: dict[str, float],
                         seg_features: dict[str, float], anthro_features: dict[str, float]) -> np.ndarray:
        """Transform one sample given raw feature dicts (mirrors Flutter inference)."""
        image_features = np.asarray(image_features, dtype=np.float64).reshape(1, -1)
        cv_arr = np.array([[cv_features.get(c, np.nan) for c in GROUPS["cv"]]], dtype=np.float64)
        seg_arr = np.array([[seg_features.get(c, np.nan) for c in GROUPS["segmentation"]]], dtype=np.float64)
        anthro_arr = np.array([[anthro_features.get(c, np.nan) for c in GROUPS["anthropometric"]]], dtype=np.float64)
        return self.transform(image_features, pd.DataFrame(cv_arr, columns=GROUPS["cv"]),
                              pd.DataFrame(seg_arr, columns=GROUPS["segmentation"]),
                              pd.DataFrame(anthro_arr, columns=GROUPS["anthropometric"]))


def derived_anthro_values(height_cm: float, weight_kg: float) -> dict[str, float]:
    """Derived anthropometric features computed at inference time."""
    bmi = weight_kg / (height_cm / 100.0) ** 2 if height_cm and height_cm > 0 else float("nan")
    return {c: bmi for c in DERIVED_ANTHROPOMETRIC_COLUMNS} | {"bmi": bmi}
