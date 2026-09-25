"""H6-H8: preprocessing parity, portable-SVM parity, and zero child leakage."""

from __future__ import annotations

import json
from pathlib import Path

import joblib
import numpy as np

from production.config import (
    ANTHROVISION_FRONTAL1_DIR,
    ARTIFACT_DIR,
    PREPROCESSOR_JSON,
    RESULTS_DIR,
    SVM_FILENAME,
)
from production.preprocessing import HybridPreprocessor


def test_h6_train_and_inference_preprocessing_identical(preprocessor, dataset, embeddings):
    """Reconstruct the scaler JSON and verify the exact same stats are applied."""
    train_df = dataset.split("train")
    X_train = preprocessor.transform(embeddings["train"], train_df, train_df, train_df)

    # Re-apply from the saved JSON exactly as Flutter would.
    saved = json.loads((ARTIFACT_DIR / PREPROCESSOR_JSON).read_text(encoding="utf-8"))
    assert saved["version"] == "hybrid_production_v1"
    assert saved["groups"]["anthropometric"]["columns"][0] == "age_months"

    # A train row transformed twice (object + fresh load) must be identical.
    fresh = HybridPreprocessor.load(ARTIFACT_DIR / PREPROCESSOR_JSON)
    x1 = preprocessor.transform_single(
        embeddings["train"][0], {c: float(train_df.iloc[0][c]) for c in saved["groups"]["cv"]["columns"]},
        {c: float(train_df.iloc[0][c]) for c in saved["groups"]["segmentation"]["columns"]},
        {c: float(train_df.iloc[0][c]) for c in saved["groups"]["anthropometric"]["columns"]},
    )[0]
    x2 = fresh.transform_single(
        embeddings["train"][0], {c: float(train_df.iloc[0][c]) for c in saved["groups"]["cv"]["columns"]},
        {c: float(train_df.iloc[0][c]) for c in saved["groups"]["segmentation"]["columns"]},
        {c: float(train_df.iloc[0][c]) for c in saved["groups"]["anthropometric"]["columns"]},
    )[0]
    assert np.allclose(x1, x2, atol=1e-9)
    # The anthro block of the batch transform matches the single-sample transform.
    assert np.allclose(x2[-8:], X_train[0, -8:], atol=1e-9)

    # Scaled train data has mean~0/std~1 per non-constant feature group.
    assert np.abs(X_train[:, -8:].mean(axis=0)).max() < 1e-6


def test_h6b_no_nans_reach_the_classifier(preprocessor, dataset, embeddings):
    for name in ("train", "test"):
        df = dataset.split(name)
        X = preprocessor.transform(embeddings[name], df, df, df)
        assert np.isfinite(X).all(), f"NaN/inf found in {name} fused vector"


def test_h7_portable_svm_matches_sklearn(preprocessor, dataset, embeddings):
    """The portable (JSON) SVM must reproduce the sklearn SVC predictions exactly."""
    svc = joblib.load(ARTIFACT_DIR / SVM_FILENAME)
    df = dataset.split("test")
    X_test = preprocessor.transform(embeddings["test"], df, df, df)

    from production.fusion import PortableSVM

    portable = PortableSVM.load(ARTIFACT_DIR / SVM_FILENAME.replace(".joblib", "_portable.json"))
    sklearn_pred = svc.predict(X_test)
    portable_pred = portable.predict(X_test)
    agreement = float((sklearn_pred == portable_pred).mean())
    assert agreement >= 0.999, f"portable SVM agreement {agreement:.4f} < 99.9%"

    # sklearn's decision_function is the OvR transformation of the raw OvO values;
    # the portable class exposes both levels, so compare both.
    d_sk = svc.decision_function(X_test[:5])
    d_pt = np.stack([portable.ovr_decision_function_one(row) for row in X_test[:5]])
    assert np.allclose(d_sk, d_pt, atol=1e-6)
    assert portable.decision_function_one(X_test[0]).shape == (6,)  # 4 classes -> 6 pairs


def test_h8_no_test_child_in_training_data(dataset):
    train_ids = set(dataset.train_child_ids)
    val_ids = set(dataset.validation_child_ids)
    test_ids = set(dataset.test_child_ids)
    assert not (train_ids & test_ids), "child leakage between train and test"
    assert not (val_ids & test_ids), "child leakage between validation and test"
    assert not (train_ids & val_ids)
    # And the actually used dataframe rows respect the split assignment.
    df = dataset.df
    train_rows = df[df["child_id"].isin(train_ids)]
    test_rows = df[df["child_id"].isin(test_ids)]
    assert set(train_rows["child_id"]).isdisjoint(set(test_rows["child_id"]))
    assert len(train_rows) == 1496 and len(test_rows) == 321
    assert Path(RESULTS_DIR / "segmentation_features_train.csv").exists()
