"""Data loader and child-level splitting for CV multimodal baseline.

Guarantees:
1. 100% child-level isolation: no child can appear across multiple splits.
2. Complete data audit and reconciliation before and after merge.
3. Explicit missingness tracking.
4. Stratified splits based on multiclass nutritional status.
"""

import json
from pathlib import Path
from typing import Dict, Tuple

import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split

from config import (
    ANTHROVISION_CSV,
    CV_FEATURES_CSV,
    CV_FEATURE_COLUMNS,
    MEASUREMENT_COLUMNS,
    RANDOM_STATE,
    SPLITS_FILE,
    TARGET_COLUMN,
    TRAIN_RATIO,
    VAL_RATIO,
    TEST_RATIO,
)


def load_and_merge_data() -> Tuple[pd.DataFrame, Dict]:
    """Load AnthroVision labels and clean CV features, reconcile and merge at child level."""
    # 1. Load AnthroVision labels
    anthro_raw = pd.read_csv(ANTHROVISION_CSV)
    anthro_clean = anthro_raw.loc[:, ~anthro_raw.columns.str.contains(r"^Unnamed")].copy()
    anthro_clean = anthro_clean.dropna(subset=[TARGET_COLUMN]).copy()
    
    # Check duplicate tags in AnthroVision
    duplicate_anthro_tags = anthro_clean[anthro_clean.duplicated(subset=["tag"], keep=False)]
    # Keep first record of duplicate tag to ensure 1 child = 1 record
    anthro_unique = anthro_clean.drop_duplicates(subset=["tag"], keep="first").copy()
    
    # 2. Load clean CV features
    cv_raw = pd.read_csv(CV_FEATURES_CSV)
    
    # Filter CV features to frontal1 view (primary anthropometric view with complete face & body landmarks)
    cv_f1 = cv_raw[cv_raw["view"] == "frontal1"].copy()
    
    # 3. Match AnthroVision children to frontal1 images
    anthro_unique["f1_filename"] = (
        anthro_unique["image_path_frontal1"]
        .dropna()
        .apply(lambda x: Path(str(x)).name)
    )
    
    # 4. Perform inner merge
    merged = pd.merge(
        anthro_unique,
        cv_f1,
        left_on="f1_filename",
        right_on="image_name",
        how="inner"
    )
    
    # Rename tag_x to child_id
    merged = merged.rename(columns={"tag_x": "child_id"})
    
    # Verify measurement types
    for col in MEASUREMENT_COLUMNS:
        merged[col] = pd.to_numeric(merged[col], errors="coerce")
    for col in CV_FEATURE_COLUMNS:
        merged[col] = pd.to_numeric(merged[col], errors="coerce")
        
    audit_summary = {
        "anthrovision_raw_rows": len(anthro_raw),
        "anthrovision_labeled_rows": len(anthro_clean),
        "anthrovision_unique_children": anthro_clean["tag"].nunique(),
        "anthrovision_duplicate_tag_rows": len(duplicate_anthro_tags),
        "cv_clean_total_records": len(cv_raw),
        "cv_frontal1_records": len(cv_f1),
        "cv_frontal1_unique_images": cv_f1["image_name"].nunique(),
        "merged_records": len(merged),
        "merged_unique_children": merged["child_id"].nunique(),
        "merged_unique_images": merged["image_name"].nunique(),
        "unmatched_anthro_children": len(anthro_unique) - len(merged),
    }
    
    return merged, audit_summary


def compute_feature_missingness(df: pd.DataFrame) -> pd.DataFrame:
    """Compute detailed missingness counts and percentages across all modalities."""
    records = []
    total = len(df)
    
    # Measurement features
    for col in MEASUREMENT_COLUMNS:
        missing = int(df[col].isna().sum())
        records.append({
            "modality": "Measurement",
            "feature": col,
            "missing_count": missing,
            "missing_pct": round(missing / total * 100, 2),
            "available_count": total - missing
        })
        
    # CV features
    for col in CV_FEATURE_COLUMNS:
        missing = int(df[col].isna().sum())
        records.append({
            "modality": "Computer Vision",
            "feature": col,
            "missing_count": missing,
            "missing_pct": round(missing / total * 100, 2),
            "available_count": total - missing
        })
        
    return pd.DataFrame(records)


def create_or_load_splits(df: pd.DataFrame) -> Tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, Dict]:
    """Create or load deterministic child-level stratified train/val/test splits."""
    if SPLITS_FILE.exists():
        with open(SPLITS_FILE, "r") as f:
            split_info = json.load(f)
            
        train_ids = set(split_info["child_ids"]["train"])
        val_ids = set(split_info["child_ids"]["validation"])
        test_ids = set(split_info["child_ids"]["test"])
        
        train_df = df[df["child_id"].isin(train_ids)].copy().reset_index(drop=True)
        val_df = df[df["child_id"].isin(val_ids)].copy().reset_index(drop=True)
        test_df = df[df["child_id"].isin(test_ids)].copy().reset_index(drop=True)
    else:
        # Perform child-level stratified split
        unique_children = df[["child_id", TARGET_COLUMN]].drop_duplicates(subset=["child_id"]).copy()
        
        # 70% train, 30% temp (val + test)
        temp_ratio = VAL_RATIO + TEST_RATIO
        train_kids, temp_kids = train_test_split(
            unique_children,
            test_size=temp_ratio,
            random_state=RANDOM_STATE,
            stratify=unique_children[TARGET_COLUMN]
        )
        
        # Split temp equally into val (15%) and test (15%)
        val_share_of_temp = VAL_RATIO / temp_ratio
        val_kids, test_kids = train_test_split(
            temp_kids,
            test_size=(1.0 - val_share_of_temp),
            random_state=RANDOM_STATE,
            stratify=temp_kids[TARGET_COLUMN]
        )
        
        train_ids = train_kids["child_id"].tolist()
        val_ids = val_kids["child_id"].tolist()
        test_ids = test_kids["child_id"].tolist()
        
        split_info = {
            "random_state": RANDOM_STATE,
            "stratified": True,
            "ratios": {
                "train": TRAIN_RATIO,
                "validation": VAL_RATIO,
                "test": TEST_RATIO
            },
            "sizes": {
                "train": len(train_ids),
                "validation": len(val_ids),
                "test": len(test_ids)
            },
            "child_ids": {
                "train": train_ids,
                "validation": val_ids,
                "test": test_ids
            }
        }
        
        SPLITS_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(SPLITS_FILE, "w") as f:
            json.dump(split_info, f, indent=2)
            
        train_df = df[df["child_id"].isin(train_ids)].copy().reset_index(drop=True)
        val_df = df[df["child_id"].isin(val_ids)].copy().reset_index(drop=True)
        test_df = df[df["child_id"].isin(test_ids)].copy().reset_index(drop=True)

    # Verify 0 child overlap across splits
    train_set = set(train_df["child_id"])
    val_set = set(val_df["child_id"])
    test_set = set(test_df["child_id"])
    
    assert len(train_set & val_set) == 0, "Data leakage! Child ID overlap between train and val"
    assert len(train_set & test_set) == 0, "Data leakage! Child ID overlap between train and test"
    assert len(val_set & test_set) == 0, "Data leakage! Child ID overlap between val and test"
    
    return train_df, val_df, test_df, split_info
