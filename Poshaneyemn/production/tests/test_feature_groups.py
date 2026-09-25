"""H1-H5: every required feature group reaches the classifier and matters."""

from __future__ import annotations

import numpy as np

from production.config import (
    ANTHROPOMETRIC_COLUMNS,
    CV_FEATURE_COLUMNS,
    IMAGE_FEATURE_DIM,
    SEGMENTATION_FEATURE_COLUMNS,
)
from production.fusion import fuse_vectors, group_slice


def test_h1_anthropometric_features_reach_classifier(group_slices):
    s = group_slices["anthropometric"]
    assert s.stop - s.start == len(ANTHROPOMETRIC_COLUMNS) == 8
    expected = [
        "age_months", "gender_male", "height_cm", "weight_kg",
        "head_circumference_cm", "waist_cm", "muac_cm", "bmi",
    ]
    assert ANTHROPOMETRIC_COLUMNS == expected


def test_h2_cv_features_reach_classifier(group_slices):
    s = group_slices["cv"]
    assert s.stop - s.start == len(CV_FEATURE_COLUMNS) == 21
    assert "face_width" in CV_FEATURE_COLUMNS and "eye_distance" in CV_FEATURE_COLUMNS
    assert "shoulder_width" in CV_FEATURE_COLUMNS


def test_h3_segmentation_features_reach_classifier(group_slices):
    s = group_slices["segmentation"]
    assert s.stop - s.start == len(SEGMENTATION_FEATURE_COLUMNS) == 11
    assert all("arm" in c or c == "num_arms_detected" for c in SEGMENTATION_FEATURE_COLUMNS)


def test_h4_image_features_reach_classifier(group_slices):
    s = group_slices["image"]
    assert s.stop - s.start == IMAGE_FEATURE_DIM == 128
    assert s.start == 0  # image block is the head of the fused vector


def test_h5_removing_any_group_changes_the_vector(preprocessor, embeddings, dataset):
    df = dataset.split("test")
    emb = embeddings["test"]
    full = preprocessor.transform(emb, df, df, df)
    slices = group_slice(preprocessor.image_dim)

    def drop(group: str) -> np.ndarray:
        keep = np.concatenate([
            np.arange(sl.start, sl.stop)
            for name, sl in slices.items() if name != group
        ])
        return full[:, keep]

    for group in ("image", "cv", "segmentation", "anthropometric"):
        reduced = drop(group)
        assert reduced.shape[1] == full.shape[1] - {
            "image": 128, "cv": 21, "segmentation": 11, "anthropometric": 8,
        }[group]
        # The removed block must have carried signal (not all zeros).
        block = full[:, slices[group]]
        assert not np.allclose(block, 0.0), f"{group} block is degenerate"


def test_fusion_order_is_image_cv_seg_anthro(preprocessor, embeddings, dataset):
    df = dataset.split("test")
    X = preprocessor.transform(embeddings["test"], df, df, df)
    assert X.shape == (len(df), 168)
    slices = group_slice(preprocessor.image_dim)
    assert [slices[k].start for k in ("image", "cv", "segmentation", "anthropometric")] == [0, 128, 149, 160]
    fuse_vectors(np.zeros((1, 128)), np.zeros((1, 21)), np.zeros((1, 11)), np.zeros((1, 8)))
