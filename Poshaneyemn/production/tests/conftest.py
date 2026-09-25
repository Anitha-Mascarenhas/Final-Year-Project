"""Shared fixtures for the production pipeline tests."""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pytest

PRODUCTION_DIR = Path(__file__).resolve().parents[1]
PROJECT_ROOT = PRODUCTION_DIR.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from production.config import (  # noqa: E402
    ANTHROPOMETRIC_COLUMNS,
    ARTIFACT_DIR,
    CV_FEATURE_COLUMNS,
    IMAGE_TFLITE_FILENAME,
    LABEL_MAP_JSON,
    PREPROCESSOR_JSON,
    RESULTS_DIR,
    SEGMENTATION_FEATURE_COLUMNS,
    SVM_FILENAME,
)
from production.dataset import build_dataset  # noqa: E402
from production.fusion import PortableSVM, group_slice  # noqa: E402
from production.preprocessing import HybridPreprocessor  # noqa: E402


@pytest.fixture(scope="session")
def dataset():
    return build_dataset()


@pytest.fixture(scope="session")
def preprocessor():
    return HybridPreprocessor.load(ARTIFACT_DIR / PREPROCESSOR_JSON)


@pytest.fixture(scope="session")
def portable_svm():
    return PortableSVM.load(ARTIFACT_DIR / SVM_FILENAME.replace(".joblib", "_portable.json"))


@pytest.fixture(scope="session")
def group_slices(preprocessor):
    return group_slice(preprocessor.image_dim)


@pytest.fixture(scope="session")
def embeddings(dataset):
    cache = {}
    for name in ("train", "validation", "test"):
        cache[name] = np.load(ARTIFACT_DIR / f"image_embeddings_{name}.npy")
    return cache


@pytest.fixture(scope="session")
def transformed(dataset, preprocessor, embeddings):
    """Train and test feature matrices produced by the training-time transform."""
    out = {}
    for name in ("train", "test"):
        df = dataset.split(name)
        out[name] = {
            "X": preprocessor.transform(embeddings[name], df, df, df),
            "y": df["label"].to_numpy(),
            "df": df,
        }
    return out


@pytest.fixture(scope="session")
def confusion_matrices():
    with open(RESULTS_DIR / "confusion_matrices.json", "r", encoding="utf-8") as fh:
        return json.load(fh)


@pytest.fixture(scope="session")
def label_map():
    with open(ARTIFACT_DIR / LABEL_MAP_JSON, "r", encoding="utf-8") as fh:
        return {int(k): v for k, v in json.load(fh).items()}


@pytest.fixture(scope="session")
def tflite_path():
    path = ARTIFACT_DIR / IMAGE_TFLITE_FILENAME
    assert path.exists(), "image feature extractor TFLite missing"
    return path
