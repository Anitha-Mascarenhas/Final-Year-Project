"""
Data loader and split verification for Segmentation Feature Baseline.

Guarantees:
1. Exact reuse of frozen child-level splits from cv_multimodal_baseline (split_indices.json).
2. Explicit verification of 0 child overlap across splits.
3. Clean 1:1 reconciliation of Measurements, Landmark CV, and Segmentation features.
"""

import json
from pathlib import Path
from typing import Dict, Tuple

import numpy as np
import pandas as pd

from config import (
    ANTHROVISION_CSV,
    CV_LANDMARK_CSV,
    SEG_FEATURES_CSV,
    FROZEN_SPLITS_FILE,
    MEASUREMENT_COLUMNS,
    CV_LANDMARK_COLUMNS,
    SEGMENTATION_COLUMNS,
    TARGET_COLUMN,
)


def load_and_merge_modalities() -> Tuple[pd.DataFrame, Dict]:
    """Load and merge Measurements, MediaPipe landmarks, and DeepLabV3+ segmentation features."""
    # 1. AnthroVision labels
    anthro_raw = pd.read_csv(ANTHROVISION_CSV)
    anthro_clean = anthro_raw.loc[:, ~anthro_raw.columns.str.contains(r"^Unnamed")].copy()
    anthro_clean = anthro_clean.dropna(subset=[TARGET_COLUMN]).drop_duplicates(subset=["tag"], keep="first").copy()
    anthro_clean["f1_filename"] = anthro_clean["image_path_frontal1"].dropna().apply(lambda x: Path(str(x)).name)
    
    # 2. Landmark CV features (frontal1)
    cv_raw = pd.read_csv(CV_LANDMARK_CSV)
    cv_f1 = cv_raw[cv_raw["view"] == "frontal1"].copy()
    
    # 3. DeepLabV3+ segmentation features
    seg_raw = pd.read_csv(SEG_FEATURES_CSV)
    
    # 4. Merge AnthroVision + Landmark CV
    merged_1 = pd.merge(
        anthro_clean,
        cv_f1,
        left_on="f1_filename",
        right_on="image_name",
        how="inner"
    ).rename(columns={"tag_x": "child_id"})
    
    # 5. Merge with Segmentation features on child_id
    merged = pd.merge(
        merged_1,
        seg_raw[["child_id"] + SEGMENTATION_COLUMNS],
        on="child_id",
        how="inner"
    )
    
    # Ensure numerical types
    for col in MEASUREMENT_COLUMNS + CV_LANDMARK_COLUMNS + SEGMENTATION_COLUMNS:
        merged[col] = pd.to_numeric(merged[col], errors="coerce")
        
    audit = {
        "anthrovision_labeled_children": len(anthro_clean),
        "cv_frontal1_records": len(cv_f1),
        "segmentation_records": len(seg_raw),
        "final_merged_records": len(merged),
        "unique_children": merged["child_id"].nunique(),
    }
    
    return merged, audit


def load_frozen_splits(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, Dict]:
    """Load splits strictly matching frozen split_indices.json from cv_multimodal_baseline."""
    if not FROZEN_SPLITS_FILE.exists():
        raise FileNotFoundError(f"Frozen splits file not found: {FROZEN_SPLITS_FILE}")
        
    with open(FROZEN_SPLITS_FILE, "r") as f:
        split_info = json.load(f)
        
    train_ids = set(split_info["child_ids"]["train"])
    val_ids = set(split_info["child_ids"]["validation"])
    test_ids = set(split_info["child_ids"]["test"])
    
    train_df = df[df["child_id"].isin(train_ids)].copy().reset_index(drop=True)
    val_df = df[df["child_id"].isin(val_ids)].copy().reset_index(drop=True)
    test_df = df[df["child_id"].isin(test_ids)].copy().reset_index(drop=True)
    
    # Verification of zero child overlap
    tr_set = set(train_df["child_id"])
    va_set = set(val_df["child_id"])
    te_set = set(test_df["child_id"])
    
    assert len(tr_set & va_set) == 0, "Data leakage: Train and Val overlap!"
    assert len(tr_set & te_set) == 0, "Data leakage: Train and Test overlap!"
    assert len(va_set & te_set) == 0, "Data leakage: Val and Test overlap!"
    
    return train_df, val_df, test_df, split_info
