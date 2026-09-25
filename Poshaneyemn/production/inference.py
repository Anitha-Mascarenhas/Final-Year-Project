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
from pathlib import Path
from typing import Any

import numpy as np

from .config import ARTIFACT_DIR, CLASS_NAMES, LABEL_MAP_JSON, PREPROCESSOR_JSON, SVM_FILENAME
from .fusion import PortableSVM
from .preprocessing import HybridPreprocessor
from .runtime_features import SegmentationFeatureExtractor, extract_cv_features, make_holistic


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
        shoulder_width = cv_features.get("shoulder_width", float("nan"))

        # 3. segmentation features (DeepLabV3+), scale-normalized by shoulder width
        seg_features = self._get_seg().extract_features(image_rgb, shoulder_width)

        # 4. anthropometrics incl. derived BMI
        anthro = dict(anthropometrics)
        anthro.update(derived_anthro_values(
            anthro.get("height_cm", float("nan")), anthro.get("weight_kg", float("nan")),
        ))

        # 5. identical preprocessing
        x = self.preprocessor.transform_single(image_features, cv_features, seg_features, anthro)[0]

        # 6. portable RBF-SVM
        pred = self.svm.predict_one(x)
        return {
            "prediction": self.label_map.get(pred, CLASS_NAMES[pred]),
            "label_index": pred,
            "feature_vector_dim": int(x.shape[0]),
        }

    def predict_from_bgr_bytes(self, image_bytes: bytes, anthropometrics: dict[str, float]) -> dict[str, Any]:
        import cv2

        arr = np.frombuffer(image_bytes, dtype=np.uint8)
        img = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Could not decode image bytes")
        return self.predict(img[:, :, ::-1], anthropometrics)

