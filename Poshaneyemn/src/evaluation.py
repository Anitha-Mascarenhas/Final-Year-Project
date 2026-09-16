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

    def save_confusion_matrix(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        filename: str,
        class_names: list[str],
    ) -> Path:
        """Save a confusion matrix labelled in encoded-label order.

        ``class_names`` must come from the fitted ``LabelEncoder`` (see
        ``DataPreprocessor.get_class_names``): ``config.CLASS_NAMES`` is a display list
        and is NOT ordered the same way as model output indices.
        """
        labels = list(range(len(class_names)))
        matrix = confusion_matrix(y_true, y_pred, labels=labels)
        fig, ax = plt.subplots(figsize=(6, 5))
        heatmap = ax.imshow(matrix, interpolation="nearest", cmap="Blues")
        ax.figure.colorbar(heatmap, ax=ax)
        ax.set(
            xticks=np.arange(len(class_names)),
            yticks=np.arange(len(class_names)),
            xticklabels=class_names,
            yticklabels=class_names,
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

    def save_classification_report(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        filename: str,
        class_names: list[str],
    ) -> Path:
        """Save a per-class report labelled in encoded-label order.

        ``class_names`` must come from the fitted ``LabelEncoder`` for the same reason
        as in :meth:`save_confusion_matrix`.
        """
        report = classification_report(
            y_true,
            y_pred,
            labels=list(range(len(class_names))),
            target_names=class_names,
            zero_division=0,
        )
        path = self.output_dir / filename
        path.write_text(report, encoding="utf-8")
        return path

    def save_full_classification_report(
        self,
        y_true: np.ndarray,
        y_pred: np.ndarray,
        class_names: list[str],
        filename_prefix: str,
    ) -> dict[str, Path]:
        """Save per-class precision/recall/F1, macro/weighted averages and a confusion matrix.

        ``class_names`` is passed explicitly because the model output indices follow
        ``sklearn.preprocessing.LabelEncoder`` order, which is not the same as the
        positional order of ``config.CLASS_NAMES``.
        """
        labels = list(range(len(class_names)))
        report_dict = classification_report(
            y_true,
            y_pred,
            labels=labels,
            target_names=class_names,
            output_dict=True,
            zero_division=0,
        )
        per_class = {
            name: {
                "precision": float(report_dict[name]["precision"]),
                "recall": float(report_dict[name]["recall"]),
                "f1_score": float(report_dict[name]["f1-score"]),
                "support": int(report_dict[name]["support"]),
            }
            for name in class_names
        }
        macro = report_dict["macro avg"]
        weighted = report_dict["weighted avg"]
        metrics = {
            "accuracy": float(accuracy_score(y_true, y_pred)),
            "per_class": per_class,
            "macro": {
                "precision": float(macro["precision"]),
                "recall": float(macro["recall"]),
                "f1_score": float(macro["f1-score"]),
            },
            "weighted": {
                "precision": float(weighted["precision"]),
                "recall": float(weighted["recall"]),
                "f1_score": float(weighted["f1-score"]),
            },
            "confusion_matrix": confusion_matrix(y_true, y_pred, labels=labels).tolist(),
            "class_index_order": list(class_names),
        }

        metrics_path = self.save_metrics(metrics, f"{filename_prefix}_metrics.json")
        report_path = self.output_dir / f"{filename_prefix}_classification_report.txt"
        report_path.write_text(
            classification_report(
                y_true,
                y_pred,
                labels=labels,
                target_names=class_names,
                zero_division=0,
            ),
            encoding="utf-8",
        )
        figure_path = self._save_confusion_figure(
            np.asarray(metrics["confusion_matrix"]),
            class_names,
            f"{filename_prefix}_confusion_matrix.png",
        )
        return {"metrics": metrics_path, "report": report_path, "confusion_matrix": figure_path}

    def _save_confusion_figure(
        self,
        matrix: np.ndarray,
        class_names: list[str],
        filename: str,
    ) -> Path:
        fig, ax = plt.subplots(figsize=(7, 6))
        heatmap = ax.imshow(matrix, interpolation="nearest", cmap="Blues")
        ax.figure.colorbar(heatmap, ax=ax)
        ax.set(
            xticks=np.arange(len(class_names)),
            yticks=np.arange(len(class_names)),
            xticklabels=class_names,
            yticklabels=class_names,
            ylabel="True label",
            xlabel="Predicted label",
            title="Confusion Matrix",
        )
        plt.setp(ax.get_xticklabels(), rotation=45, ha="right")
        threshold = matrix.max() / 2.0 if matrix.size and matrix.max() else 0.0
        for i in range(matrix.shape[0]):
            for j in range(matrix.shape[1]):
                ax.text(
                    j,
                    i,
                    int(matrix[i, j]),
                    ha="center",
                    va="center",
                    color="white" if matrix[i, j] > threshold else "black",
                )
        path = self.output_dir / filename
        fig.tight_layout()
        fig.savefig(path, dpi=300)
        plt.close(fig)
        return path

    def save_metrics(self, metrics: dict[str, float], filename: str) -> Path:
        path = self.output_dir / filename
        save_json(path, metrics)
        return path

    def save_model_comparison_table(self, results: dict[str, dict[str, float]], filename: str) -> Path:
        path = self.output_dir / filename
        save_json(path, results)
        return path
