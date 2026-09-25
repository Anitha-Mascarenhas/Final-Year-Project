"""Runtime feature extraction from a single image using the existing repo code.

CV branch   : MediaPipe FaceMesh + Pose (same landmark indices and formulas as
              ``experiments/cv_features_clean/run_experiment.py``).
Segmentation: DeepLabV3+ (MobileNetV2 backbone) upper-arm mask, then the same
              connected-component geometry as
              ``experiments/upper_arm_segmentation/deeplabv3/extract_segmentation_features.py``.

These functions guarantee the features entering the classifier at inference time are
computed exactly the way they were computed for the training CSVs.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

import numpy as np
import tensorflow as tf

try:
    import cv2
except ImportError:  # OpenCV is optional at import time; required at runtime
    cv2 = None

from .config import (
    CV_FEATURE_COLUMNS,
    DEEPLAB_ARCH,
    DEEPLAB_WEIGHTS,
    SEGMENTATION_FEATURE_COLUMNS,
)

_MIN_POSE_VISIBILITY = 0.3  # matches experiments/cv_features_clean/run_experiment.py

FACE_LANDMARKS = {
    "left_face": 234, "right_face": 454, "forehead": 10, "chin": 152,
    "left_eye": 33, "right_eye": 263, "mouth_left": 61, "mouth_right": 291,
    "left_jaw": 127, "right_jaw": 356,
}
POSE_LANDMARKS = {
    "l_shoulder": 11, "r_shoulder": 12,
    "l_elbow": 13, "r_elbow": 14, "l_wrist": 15, "r_wrist": 16,
}


# ---------------------------------------------------------------------------
# CV (MediaPipe) features
# ---------------------------------------------------------------------------
def extract_cv_features(image_bgr: np.ndarray, holistic: Any) -> dict[str, float]:
    """Compute the 21 CV features from one BGR image using a MediaPipe Holistic."""
    import cv2

    H, W = image_bgr.shape[:2]
    res = holistic.process(cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB))
    out: dict[str, float] = {c: float("nan") for c in CV_FEATURE_COLUMNS}

    if res is None:
        return out

    # ---- face features (frontal face visible) ----
    if res.face_landmarks is not None:
        flm = res.face_landmarks.landmark
        P = {k: np.array([flm[i].x * W, flm[i].y * H]) for k, i in FACE_LANDMARKS.items()}
        fw = float(np.hypot(*(P["right_face"] - P["left_face"])))
        fh = float(np.hypot(*(P["chin"] - P["forehead"])))
        ed = float(np.hypot(*(P["right_eye"] - P["left_eye"])))
        mw = float(np.hypot(*(P["mouth_right"] - P["mouth_left"])))
        jw = float(np.hypot(*(P["right_jaw"] - P["left_jaw"])))
        if fw > 0 and fh > 0:
            out["face_width"] = fw
            out["face_height"] = fh
            out["eye_distance"] = ed
            out["mouth_width"] = mw
            out["jaw_width"] = jw
            out["face_ratio"] = fw / fh
            out["eye_ratio"] = ed / fw
            out["mouth_ratio"] = mw / fw

    # ---- pose/arm features ----
    if res.pose_landmarks is not None:
        lm = res.pose_landmarks.landmark

        def pt(i: int) -> np.ndarray | None:
            l = lm[i]
            if l.visibility is not None and l.visibility < _MIN_POSE_VISIBILITY:
                return None
            return np.array([l.x * W, l.y * H])

        ls, rs = pt(11), pt(12)
        le, re_, lw, rw = pt(13), pt(14), pt(15), pt(16)

        if ls is not None and rs is not None:
            out["shoulder_width"] = float(np.hypot(*(rs - ls)))

        def arm(sh, el, wr, side: str) -> None:
            if sh is None or el is None:
                return
            upper = float(np.hypot(*(el - sh)))
            out[f"{side}_upper_arm_length"] = upper
            if wr is not None:
                fore = float(np.hypot(*(wr - el)))
                out[f"{side}_forearm_length"] = fore
                out[f"{side}_total_arm_length"] = upper + fore
            sw = out.get("shoulder_width")
            if sw and np.isfinite(sw):
                out[f"{side}_upper_arm_to_shoulder_ratio"] = upper / sw
                if np.isfinite(out.get(f"{side}_forearm_length", float("nan"))):
                    out[f"{side}_forearm_to_shoulder_ratio"] = out[f"{side}_forearm_length"] / sw
                if np.isfinite(out.get(f"{side}_total_arm_length", float("nan"))):
                    out[f"{side}_total_arm_to_shoulder_ratio"] = out[f"{side}_total_arm_length"] / sw

        arm(ls, le, lw, "left")
        arm(rs, re_, rw, "right")

    return out


def make_holistic():
    """Create the MediaPipe Holistic configured exactly like the training extractor."""
    import mediapipe as mp

    return mp.solutions.holistic.Holistic(
        static_image_mode=True, model_complexity=1, refine_face_landmarks=False,
    )


# ---------------------------------------------------------------------------
# Segmentation (DeepLabV3+) features
# ---------------------------------------------------------------------------
def _load_deeplab():
    arch_path = str(Path(DEEPLAB_ARCH))
    if arch_path not in sys.path:
        sys.path.insert(0, str(Path(DEEPLAB_ARCH).parent))
    from model import build_deeplabv3plus  # type: ignore  # existing repo implementation

    model = build_deeplabv3plus(input_shape=(512, 512, 3), num_classes=2)
    model.load_weights(str(DEEPLAB_WEIGHTS))
    return model


class SegmentationFeatureExtractor:
    """Predict the upper-arm mask with the trained DeepLabV3+ and derive features."""

    def __init__(self, model=None):
        self.model = model if model is not None else _load_deeplab()

    @staticmethod
    def _preprocess(image_rgb: np.ndarray) -> np.ndarray:
        import tensorflow as tf

        img = tf.convert_to_tensor(image_rgb, dtype=tf.float32)
        img = tf.image.resize(img, (512, 512))
        img = img / 255.0
        mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
        std = np.array([0.229, 0.224, 0.225], dtype=np.float32)
        return ((img.numpy() - mean) / std).astype(np.float32)

    def predict_mask(self, image_rgb: np.ndarray) -> np.ndarray:
        """Run DeepLabV3+ and return the binary upper-arm mask (512x512 uint8)."""
        batch = self._preprocess(image_rgb)[None, ...]
        logits = self.model(batch, training=False)
        return np.asarray(tf.argmax(logits, axis=-1)[0]).astype(np.uint8)

    def extract_features(self, image_rgb: np.ndarray, shoulder_width: float | None) -> dict[str, float]:
        """Mask -> connected components -> the 11 production segmentation features.

        Geometry matches extract_features_from_mask() in the existing extraction code;
        the scale normalization uses the MediaPipe shoulder_width reference so the
        features are comparable across camera distances.
        """
        import cv2

        import cv2  # noqa: F811  (local import keeps module import lightweight)

        mask = self.predict_mask(image_rgb)
        return self.features_from_mask(mask, shoulder_width)

    @staticmethod
    def features_from_mask(mask: np.ndarray, shoulder_width: float | None) -> dict[str, float]:
        out: dict[str, float] = {c: float("nan") for c in SEGMENTATION_FEATURE_COLUMNS}
        out["total_arm_area"] = 0.0
        out["num_arms_detected"] = 0.0

        if cv2 is None:
            raise ImportError("OpenCV (cv2) is required to derive segmentation features.")
        bin_mask = (mask > 0).astype(np.uint8)
        num_labels, labels, stats, centroids = cv2.connectedComponentsWithStats(bin_mask, connectivity=8)
        comps = []
        for lbl in range(1, num_labels):
            area = int(stats[lbl, cv2.CC_STAT_AREA])
            if area >= 150:  # same min_component_area as the training extraction
                comps.append({
                    "area": area,
                    "cx": float(centroids[lbl][0]),
                    "width": float(stats[lbl, cv2.CC_STAT_WIDTH]),
                    "height": float(stats[lbl, cv2.CC_STAT_HEIGHT]),
                })
        if not comps:
            return out

        comps.sort(key=lambda c: c["area"], reverse=True)
        comps = comps[:2]
        out["total_arm_area"] = float(sum(c["area"] for c in comps))
        out["num_arms_detected"] = float(len(comps))

        if len(comps) == 2:
            comps.sort(key=lambda c: c["cx"])
            left, right = comps[0], comps[1]
        else:
            left = comps[0] if comps[0]["cx"] < 256.0 else None
            right = comps[0] if comps[0]["cx"] >= 256.0 else None

        if left is not None:
            out["left_arm_area"] = float(left["area"])
            out["left_arm_width"] = float(left["width"])
            out["left_arm_height"] = float(left["height"])
            out["left_arm_aspect_ratio"] = float(left["height"] / left["width"]) if left["width"] > 0 else float("nan")
        if right is not None:
            out["right_arm_area"] = float(right["area"])
            out["right_arm_width"] = float(right["width"])
            out["right_arm_height"] = float(right["height"])
            out["right_arm_aspect_ratio"] = float(right["height"] / right["width"]) if right["width"] > 0 else float("nan")

        if shoulder_width is not None and np.isfinite(shoulder_width) and shoulder_width > 0:
            sw, sw_sq = float(shoulder_width), float(shoulder_width) ** 2
            out["total_arm_area_norm"] = out["total_arm_area"] / sw_sq
            if np.isfinite(out.get("left_arm_area", float("nan"))):
                out["left_arm_area_norm"] = out["left_arm_area"] / sw_sq
                out["left_arm_width_norm"] = out["left_arm_width"] / sw
                out["left_arm_height_norm"] = out["left_arm_height"] / sw
            if np.isfinite(out.get("right_arm_area", float("nan"))):
                out["right_arm_area_norm"] = out["right_arm_area"] / sw_sq
                out["right_arm_width_norm"] = out["right_arm_width"] / sw
                out["right_arm_height_norm"] = out["right_arm_height"] / sw
        return out
