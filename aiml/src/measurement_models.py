from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
    roc_auc_score,
    roc_curve,
)
from sklearn.model_selection import GridSearchCV, train_test_split

from config import CLASS_NAMES, MODEL_DIR, RANDOM_STATE
from features import MeasurementFeaturePipeline
from utils import ensure_dir, save_joblib


@dataclass
class ModelResult:
    name: str
    accuracy: float
    precision: float
    recall: float
    f1: float
    roc_auc: float | None
    confusion_matrix: np.ndarray
    classification_report: str
    model: Any


class MeasurementModelTrainer:
    """Train and compare measurement-only baseline models."""

    def __init__(self, model_dir: Path = MODEL_DIR):
        self.model_dir = ensure_dir(model_dir)
        self.feature_pipeline = MeasurementFeaturePipeline()
        self.results: dict[str, ModelResult] = {}

    def fit(self, df: pd.DataFrame, label_column: str = "label") -> None:
        # Fit feature pipeline on training data and train models (no evaluation here)
        self.feature_pipeline.fit(df)
        X = self.feature_pipeline.transform(df)
        y = df[label_column].astype(int).values

        # store trained models for later test evaluation
        self.trained_models: dict[str, Any] = {}

        self._fit_random_forest(X, y)
        self._fit_xgboost(X, y)
        self._fit_lightgbm(X, y)
        self._fit_mlp(X, y)

    def evaluate(self, X: np.ndarray, y: np.ndarray, model: Any, name: str) -> ModelResult:
        predictions = model.predict(X)
        probabilities = self._predict_proba(model, X)
        roc_auc = None
        if probabilities is not None and probabilities.shape[1] == len(CLASS_NAMES):
            try:
                roc_auc = roc_auc_score(y, probabilities, multi_class="ovo")
            except ValueError:
                roc_auc = None

        report = classification_report(y, predictions, target_names=CLASS_NAMES, zero_division=0)
        # Print evaluation artifacts for visibility
        print(f"\n[Measurement Evaluation] Model: {name}")
        print("Classification Report:\n", report)
        print("Confusion Matrix:\n", confusion_matrix(y, predictions))

        result = ModelResult(
            name=name,
            accuracy=accuracy_score(y, predictions),
            precision=precision_score(y, predictions, average="weighted", zero_division=0),
            recall=recall_score(y, predictions, average="weighted", zero_division=0),
            f1=f1_score(y, predictions, average="weighted", zero_division=0),
            roc_auc=roc_auc,
            confusion_matrix=confusion_matrix(y, predictions),
            classification_report=report,
            model=model,
        )
        self.results[name] = result
        return result

    def _predict_proba(self, model: Any, X: np.ndarray) -> np.ndarray | None:
        if hasattr(model, "predict_proba"):
            return model.predict_proba(X)
        if hasattr(model, "decision_function"):
            scores = model.decision_function(X)
            if scores.ndim == 1:
                return np.vstack([1 - scores, scores]).T
            return self._softmax(scores)
        return None

    def _softmax(self, logits: np.ndarray) -> np.ndarray:
        exp = np.exp(logits - np.max(logits, axis=1, keepdims=True))
        return exp / np.sum(exp, axis=1, keepdims=True)

    def _fit_random_forest(self, X: np.ndarray, y: np.ndarray) -> None:
        from sklearn.ensemble import RandomForestClassifier

        model = RandomForestClassifier(
            n_estimators=250,
            class_weight="balanced",
            random_state=RANDOM_STATE,
        )
        model.fit(X, y)
        self.trained_models["RandomForest"] = model
        save_joblib(self.model_dir / "measurement_random_forest.pkl", model)

    def _fit_xgboost(self, X: np.ndarray, y: np.ndarray) -> None:
        try:
            from xgboost import XGBClassifier
        except ImportError as err:
            raise ImportError("Install xgboost to use the XGBoost measurement model.") from err

        model = XGBClassifier(
            use_label_encoder=False,
            eval_metric="mlogloss",
            random_state=RANDOM_STATE,
            n_estimators=150,
        )
        model.fit(X, y)
        self.trained_models["XGBoost"] = model
        save_joblib(self.model_dir / "measurement_xgboost.pkl", model)

    def _fit_lightgbm(self, X: np.ndarray, y: np.ndarray) -> None:
        try:
            from lightgbm import LGBMClassifier
        except ImportError as err:
            raise ImportError("Install lightgbm to use the LightGBM measurement model.") from err

        model = LGBMClassifier(
            objective="multiclass",
            random_state=RANDOM_STATE,
            n_estimators=150,
        )
        model.fit(X, y)
        self.trained_models["LightGBM"] = model
        save_joblib(self.model_dir / "measurement_lightgbm.pkl", model)

    def _fit_mlp(self, X: np.ndarray, y: np.ndarray) -> None:
        from sklearn.neural_network import MLPClassifier

        model = MLPClassifier(
            hidden_layer_sizes=(128, 64),
            activation="relu",
            solver="adam",
            max_iter=300,
            random_state=RANDOM_STATE,
        )
        model.fit(X, y)
        self.trained_models["MLP"] = model
        save_joblib(self.model_dir / "measurement_mlp.pkl", model)

    def evaluate_on_test(self, df_test: pd.DataFrame, label_column: str = "label") -> None:
        """Evaluate all trained models on the held-out test set and populate self.results."""
        X_test = self.feature_pipeline.transform(df_test)
        y_test = df_test[label_column].astype(int).values
        # Clear any previous results and evaluate
        self.results = {}
        for name, model in self.trained_models.items():
            try:
                self.evaluate(X_test, y_test, model, name)
            except Exception as e:
                print(f"Error evaluating model {name} on test set: {e}")

    def get_best_model(self) -> ModelResult | None:
        if not self.results:
            return None
        # Select best model by test-set accuracy
        return max(self.results.values(), key=lambda result: result.accuracy)
