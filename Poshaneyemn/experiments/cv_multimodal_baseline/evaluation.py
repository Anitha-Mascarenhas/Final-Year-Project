"""Comprehensive evaluation metrics calculation for multimodal baseline experiments."""

from typing import Dict, List, Tuple
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    balanced_accuracy_score,
    confusion_matrix,
    precision_recall_fscore_support,
)

from config import CLASS_NAMES


def compute_all_metrics(
    y_true: np.ndarray,
    y_pred: np.ndarray,
    model_name: str,
    modality_arm: str,
    split_name: str = "test",
) -> Tuple[Dict, pd.DataFrame, np.ndarray]:
    """Calculate accuracy, balanced accuracy, macro/weighted metrics, and per-class metrics.
    
    Returns:
        summary_dict: Dict with aggregate metrics
        per_class_df: DataFrame with per-class precision, recall, F1, and support
        cm: Confusion matrix array
    """
    acc = accuracy_score(y_true, y_pred)
    bal_acc = balanced_accuracy_score(y_true, y_pred)
    
    prec_macro, rec_macro, f1_macro, _ = precision_recall_fscore_support(
        y_true, y_pred, average="macro", zero_division=0
    )
    prec_weighted, rec_weighted, f1_weighted, _ = precision_recall_fscore_support(
        y_true, y_pred, average="weighted", zero_division=0
    )
    
    cm = confusion_matrix(y_true, y_pred, labels=list(range(len(CLASS_NAMES))))
    
    prec_per_class, rec_per_class, f1_per_class, support = precision_recall_fscore_support(
        y_true, y_pred, average=None, labels=list(range(len(CLASS_NAMES))), zero_division=0
    )
    
    summary_dict = {
        "model_name": model_name,
        "modality_arm": modality_arm,
        "split": split_name,
        "accuracy": round(float(acc), 4),
        "balanced_accuracy": round(float(bal_acc), 4),
        "macro_precision": round(float(prec_macro), 4),
        "macro_recall": round(float(rec_macro), 4),
        "macro_f1": round(float(f1_macro), 4),
        "weighted_precision": round(float(prec_weighted), 4),
        "weighted_recall": round(float(rec_weighted), 4),
        "weighted_f1": round(float(f1_weighted), 4),
    }
    
    per_class_records = []
    for idx, name in enumerate(CLASS_NAMES):
        per_class_records.append({
            "model_name": model_name,
            "modality_arm": modality_arm,
            "split": split_name,
            "class_index": idx,
            "class_name": name,
            "precision": round(float(prec_per_class[idx]), 4),
            "recall": round(float(rec_per_class[idx]), 4),
            "f1_score": round(float(f1_per_class[idx]), 4),
            "support": int(support[idx]),
        })
        
    per_class_df = pd.DataFrame(per_class_records)
    
    return summary_dict, per_class_df, cm
