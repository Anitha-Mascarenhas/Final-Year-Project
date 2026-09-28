"""End-to-end production inference (offline, mirrors the planned Flutter flow).

image + anthropometrics
  -> MobileNetV2 feature extractor (TFLite in Flutter; Keras here)
  -> MediaPipe CV features
  -> DeepLabV3+ segmentation features
  -> exact JSON preprocessing (medians/means/stds)
  -> portable RBF-SVM
  -> 4-class prediction
"""

from __future__ import annotations

import json
import hashlib
import os
from pathlib import Path
from typing import Any

import numpy as np

from .config import (
    ANTHROPOMETRIC_COLUMNS,
    ARTIFACT_DIR,
    CLASS_NAMES,
    CV_FEATURE_COLUMNS,
    LABEL_MAP_JSON,
    PREPROCESSOR_JSON,
    SEGMENTATION_FEATURE_COLUMNS,
    SVM_FILENAME,
)
from .fusion import PortableSVM
from .preprocessing import HybridPreprocessor
from .runtime_features import SegmentationFeatureExtractor, extract_cv_features, make_holistic


def _trace_block(name: str, values: np.ndarray) -> None:
    """Print a stable fingerprint and basic stats for a diagnostic feature block."""
    arr = np.ascontiguousarray(np.asarray(values, dtype=np.float64).reshape(-1))
    finite = arr[np.isfinite(arr)]
    if finite.size:
        minimum, maximum, mean = float(finite.min()), float(finite.max()), float(finite.mean())
    else:
        minimum = maximum = mean = float("nan")
    print(
        f"[TRACE] {name} dim={arr.size} sha256={hashlib.sha256(arr.tobytes()).hexdigest()} "
        f"min={minimum!r} max={maximum!r} mean={mean!r}",
        flush=True,
    )


def _ovr_from_pairwise(pairwise: np.ndarray, classes: list[int]) -> np.ndarray:
    votes = np.zeros(len(classes), dtype=np.float64)
    confidence = np.zeros(len(classes), dtype=np.float64)
    p = 0
    for i in range(len(classes)):
        for j in range(i + 1, len(classes)):
            d = float(pairwise[p])
            confidence[i] += d
            confidence[j] -= d
            votes[i if d > 0 else j] += 1
            p += 1
    return votes + confidence / (3 * (np.abs(confidence) + 1))


def _trace_svm_input(name: str, x: np.ndarray, svm: PortableSVM,
                     sklearn_svm=None, neutralize: bool = False) -> None:
    x = np.asarray(x, dtype=np.float64).reshape(-1)
    _trace_block(f"{name}_svm_input", x)
    blocks = {
        "image": slice(0, 128),
        "cv": slice(128, 149),
        "segmentation": slice(149, 160),
        "anthropometric": slice(160, 168),
    }

    def kernel_report(label: str, vector: np.ndarray) -> np.ndarray:
        diffs = svm.support_vectors - vector
        sq = np.einsum("ij,ij->i", diffs, diffs)
        kernels = np.exp(-svm.gamma * sq)
        nearest = int(np.argmin(sq))
        finite = kernels[np.isfinite(kernels)]
        print(
            f"[TRACE] {label}_rbf gamma={svm.gamma!r} support_vectors={len(kernels)} "
            f"sqdist_min={float(sq[nearest])!r} sqdist_max={float(np.max(sq))!r} "
            f"kernel_min={float(np.min(finite))!r} kernel_max={float(np.max(finite))!r} "
            f"kernel_mean={float(np.mean(finite))!r} "
            f">1e-12={int(np.count_nonzero(kernels > 1e-12))} "
            f">1e-20={int(np.count_nonzero(kernels > 1e-20))} "
            f">1e-50={int(np.count_nonzero(kernels > 1e-50))} "
            f"<1e-50={int(np.count_nonzero(kernels < 1e-50))}",
            flush=True,
        )
        total = float(sq[nearest])
        contributions = {
            key: float(np.sum(diffs[nearest, sl] ** 2)) for key, sl in blocks.items()
        }
        shares = {key: (value / total * 100 if total else 0.0)
                  for key, value in contributions.items()}
        print(
            f"[TRACE] {label}_nearest_sv index={nearest} sqdist_by_block={contributions!r} "
            f"percent_by_block={shares!r}",
            flush=True,
        )
        manual = svm.decision_function_one(vector)
        portable = svm.ovr_decision_function_one(vector)
        intercept_only = _ovr_from_pairwise(svm.intercepts, svm.classes)
        print(
            f"[TRACE] {label}_decision pairwise={manual.tolist()!r} "
            f"portable_ovr={portable.tolist()!r} intercept_only_ovr={intercept_only.tolist()!r}",
            flush=True,
        )
        if sklearn_svm is not None:
            sklearn_decision = np.asarray(
                sklearn_svm.decision_function(vector.reshape(1, -1))[0], dtype=np.float64
            )
            print(
                f"[TRACE] {label}_sklearn_decision={sklearn_decision.tolist()!r} "
                f"portable_max_abs_diff={float(np.max(np.abs(sklearn_decision - portable)))!r}",
                flush=True,
            )
        return kernels

    kernel_report(name, x)
    if neutralize:
        for key, sl in blocks.items():
            variant = x.copy()
            variant[sl] = 0.0  # zero is the training-centered value after standard scaling
            kernel_report(f"{name}_neutralize_{key}", variant)


class HybridProductionPredictor:
    """Loads the validated production artifacts and predicts from one image."""

    def __init__(self, artifact_dir: Path | None = None, seg_extractor=None, holistic=None):
        artifact_dir = Path(artifact_dir) if artifact_dir else Path(ARTIFACT_DIR)
        self.preprocessor = HybridPreprocessor.load(artifact_dir / PREPROCESSOR_JSON)
        self.svm = PortableSVM.load(artifact_dir / SVM_FILENAME.replace(".joblib", "_portable.json"))
        with open(artifact_dir / LABEL_MAP_JSON, "r", encoding="utf-8") as fh:
            self.label_map = {int(k): v for k, v in json.load(fh).items()}
        self._seg = seg_extractor
        self._holistic = holistic
        self._image_extractor = None  # lazily built (heavy)
        self._trace_sklearn_svm = None
        if os.environ.get("POSHANEYE_TRACE") == "1":
            print(f"[TRACE] feature_order={self.preprocessor.feature_order()!r}", flush=True)
            try:
                import pandas as pd

                training_seg = pd.read_csv(
                    artifact_dir.parent / "results" / "segmentation_features_train.csv"
                )
                for column in SEGMENTATION_FEATURE_COLUMNS:
                    if column not in training_seg.columns:
                        print(f"[TRACE] seg_train_stats_missing={column!r}", flush=True)
                        continue
                    values = pd.to_numeric(training_seg[column], errors="coerce").to_numpy(dtype=float)
                    values = values[np.isfinite(values)]
                    if values.size:
                        print(
                            f"[TRACE] seg_train_stats name={column!r} n={values.size} "
                            f"min={float(np.min(values))!r} max={float(np.max(values))!r} "
                            f"mean={float(np.mean(values))!r} std={float(np.std(values))!r} "
                            f"median={float(np.median(values))!r}", flush=True,
                        )
            except Exception as exc:
                print(f"[TRACE] seg_train_stats_error={type(exc).__name__}: {exc}", flush=True)
            try:
                import joblib

                self._trace_sklearn_svm = joblib.load(artifact_dir / SVM_FILENAME)
                model = self._trace_sklearn_svm
                print(
                    f"[TRACE] sklearn_artifact kernel={model.kernel!r} gamma={model._gamma!r} "
                    f"C={model.C!r} support_vectors={model.support_vectors_.shape!r} "
                    f"dual_coef={model.dual_coef_.shape!r} classes={model.classes_.tolist()!r} "
                    f"n_support={model.n_support_.tolist()!r} "
                    f"intercepts={model.intercept_.tolist()!r}", flush=True,
                )
            except Exception as exc:
                print(f"[TRACE] sklearn_artifact_load_error={type(exc).__name__}: {exc}", flush=True)

    # ------------------------------------------------------------------ lazy pieces
    def _get_holistic(self):
        if self._holistic is None:
            self._holistic = make_holistic()
        return self._holistic

    def _get_seg(self):
        if self._seg is None:
            self._seg = SegmentationFeatureExtractor()
        return self._seg

    def _get_image_extractor(self):
        if self._image_extractor is None:
            from .image_branch import load_image_feature_extractor

            self._image_extractor = load_image_feature_extractor()
        return self._image_extractor

    # ------------------------------------------------------------------ main API
    def predict(self, image_rgb: np.ndarray, anthropometrics: dict[str, float]) -> dict[str, Any]:
        """anthropometrics keys: age_months, gender_male, height_cm, weight_kg,
        head_circumference_cm, waist_cm (optional), muac_cm (optional)."""
        from .image_branch import extract_image_features
        from .preprocessing import derived_anthro_values

        # 1. image features (128-d MobileNetV2 embedding)
        image_features = extract_image_features(self._get_image_extractor(), image_rgb)

        # 2. CV features (MediaPipe)
        cv_features = extract_cv_features(image_rgb[:, :, ::-1], self._get_holistic())
        shoulder_width_512 = cv_features.get("_shoulder_width_512", float("nan"))

        # 3. segmentation features (DeepLabV3+), scale-normalized by shoulder width
        seg_features = self._get_seg().extract_features(image_rgb, shoulder_width_512)

        # 4. anthropometrics incl. derived BMI
        anthro = dict(anthropometrics)
        anthro.update(derived_anthro_values(
            anthro.get("height_cm", float("nan")), anthro.get("weight_kg", float("nan")),
        ))

        trace = os.environ.get("POSHANEYE_TRACE") == "1"
        if trace:
            _trace_block("image_features_raw", image_features)
            _trace_block("cv_features_raw", np.array([cv_features.get(k, np.nan) for k in CV_FEATURE_COLUMNS]))
            _trace_block("seg_features_raw", np.array([seg_features.get(k, np.nan) for k in SEGMENTATION_FEATURE_COLUMNS]))
            _trace_block("anthro_features_raw", np.array([anthro.get(k, np.nan) for k in ANTHROPOMETRIC_COLUMNS]))
            print(f"[TRACE] seg_raw_values={[(k, seg_features.get(k, float('nan'))) for k in SEGMENTATION_FEATURE_COLUMNS]!r}", flush=True)
            print(f"[TRACE] anthro_raw_values={[(k, anthro.get(k, float('nan'))) for k in ANTHROPOMETRIC_COLUMNS]!r}", flush=True)

        # 5. identical preprocessing
        x = self.preprocessor.transform_single(image_features, cv_features, seg_features, anthro)[0]

        if trace:
            image_end = self.preprocessor.image_dim
            cv_end = image_end + len(CV_FEATURE_COLUMNS)
            seg_end = cv_end + len(SEGMENTATION_FEATURE_COLUMNS)
            _trace_block("image_features_preprocessed", x[:image_end])
            _trace_block("cv_features_preprocessed", x[image_end:cv_end])
            _trace_block("seg_features_preprocessed", x[cv_end:seg_end])
            _trace_block("anthro_features_preprocessed", x[seg_end:])
            _trace_block("svm_input_168", x)
            print(f"[TRACE] svm_input_l2={float(np.linalg.norm(x))!r}", flush=True)
            # Report segmentation values after the exact production imputation/scaling.
            for offset, column in enumerate(SEGMENTATION_FEATURE_COLUMNS):
                idx = self.preprocessor.image_dim + len(CV_FEATURE_COLUMNS) + offset
                value = float(x[idx])
                print(f"[TRACE] seg_feature_scaled name={column!r} z={value!r}", flush=True)
            _trace_svm_input("runtime", x, self.svm, self._trace_sklearn_svm, neutralize=True)

        # 6. portable RBF-SVM
        pred = self.svm.predict_one(x)
        # Raw one-vs-one class scores from the classifier itself (votes + confidence
        # tie-breaker). NOT probabilities - can contain negatives. The backend adapter
        # may normalize them for UI display; the prediction is argmax of these.
        class_scores_raw = self.svm.ovr_decision_function_one(x)
        return {
            "prediction": self.label_map.get(pred, CLASS_NAMES[pred]),
            "label_index": pred,
            "class_scores_raw": {
                CLASS_NAMES[c]: float(class_scores_raw[c])
                for c in self.svm.classes
            },
            "feature_vector_dim": int(x.shape[0]),
        }

    def predict_from_bgr_bytes(self, image_bytes: bytes, anthropometrics: dict[str, float]) -> dict[str, Any]:
        import cv2

        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Could not decode image bytes")
        if os.environ.get("POSHANEYE_TRACE") == "1":
            pixel_bytes = np.ascontiguousarray(img).tobytes()
            print(f"[TRACE] decoded_image width={img.shape[1]} height={img.shape[0]} "
                  f"channels={1 if img.ndim == 2 else img.shape[2]} "
                  f"pixel_sha256={hashlib.sha256(pixel_bytes).hexdigest()}", flush=True)
        return self.predict(img[:, :, ::-1], anthropometrics)

