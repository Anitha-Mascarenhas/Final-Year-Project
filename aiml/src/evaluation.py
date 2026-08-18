from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)

from config import CLASS_NAMES
from utils import ensure_dir, save_json


class Evaluation:
    """Generate evaluation reports and visualizations for classification models."""

    def __init__(self, output_dir: Path):
        self.output_dir = ensure_dir(output_dir)

    def classification_metrics(self, y_true: np.ndarray, y_pred: np.ndarray) -> dict[str, float]:
        return {
            "accuracy": float(accuracy_score(y_true, y_pred)),
            "precision": float(precision_score(y_true, y_pred, average="weighted", zero_division=0)),
            "recall": float(recall_score(y_true, y_pred, average="weighted", zero_division=0)),
            "f1_score": float(f1_score(y_true, y_pred, average="weighted", zero_division=0)),
        }

    def save_confusion_matrix(self, y_true: np.ndarray, y_pred: np.ndarray, filename: str) -> Path:
        matrix = confusion_matrix(y_true, y_pred)
        fig, ax = plt.subplots(figsize=(6, 5))
        heatmap = ax.imshow(matrix, interpolation="nearest", cmap="Blues")
        ax.figure.colorbar(heatmap, ax=ax)
        ax.set(
            xticks=np.arange(len(CLASS_NAMES)),
            yticks=np.arange(len(CLASS_NAMES)),
            xticklabels=CLASS_NAMES,
            yticklabels=CLASS_NAMES,
            ylabel="True label",
            xlabel="Predicted label",
            title="Confusion Matrix",
        )
        plt.setp(ax.get_xticklabels(), rotation=45, ha="right")
        for i in range(matrix.shape[0]):
            for j in range(matrix.shape[1]):
                ax.text(j, i, int(matrix[i, j]), ha="center", va="center", color="black")
        filename = self.output_dir / filename
        fig.tight_layout()
        fig.savefig(filename, dpi=300)
        plt.close(fig)
        return filename

    def save_training_history(self, history, filename_prefix: str) -> list[Path]:
        paths: list[Path] = []
        history_dict = history.history
        for metric in ["loss", "accuracy", "precision", "recall", "val_loss", "val_accuracy", "val_precision", "val_recall"]:
            if metric not in history_dict:
                continue
            fig, ax = plt.subplots(figsize=(8, 5))
            ax.plot(history_dict[metric], label=metric)
            ax.set_xlabel("Epoch")
            ax.set_ylabel(metric.replace("_", " ").title())
            ax.set_title(f"{filename_prefix} - {metric}")
            ax.legend()
            filename = self.output_dir / f"{filename_prefix}_{metric}.png"
            fig.tight_layout()
            fig.savefig(filename, dpi=300)
            plt.close(fig)
            paths.append(filename)
        return paths

    def save_classification_report(self, y_true: np.ndarray, y_pred: np.ndarray, filename: str) -> Path:
        report = classification_report(y_true, y_pred, target_names=CLASS_NAMES, zero_division=0)
        path = self.output_dir / filename
        path.write_text(report, encoding="utf-8")
        return path

    def save_metrics(self, metrics: dict[str, float], filename: str) -> Path:
        path = self.output_dir / filename
        save_json(path, metrics)
        return path

    def save_model_comparison_table(self, results: dict[str, dict[str, float]], filename: str) -> Path:
        path = self.output_dir / filename
        save_json(path, results)
        return path
