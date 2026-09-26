"""Bridge between the FastAPI backend and the EXISTING Poshaneyemn production pipeline.

This module does NOT contain any ML logic of its own. It delegates to the validated
production implementation in ``Poshaneyemn/production`` (MobileNetV2 image features +
MediaPipe CV features + DeepLabV3+ segmentation features + anthropometrics -> exact
JSON preprocessing -> portable RBF-SVM -> 4 nutritional classes).

The production stack (tensorflow 2.19 + mediapipe 0.10.13 + numpy 2.1.3) is
incompatible with the backend's own venv (tensorflow 2.21 + mediapipe 1.0.1), so the
backend is expected to run under ``backend/.venv_hybrid`` — see
``backend/requirements_hybrid.txt``.

Class mapping is preserved exactly:
    0 -> healthy, 1 -> underweight, 2 -> stunted, 3 -> stunted and underweight
"""

from __future__ import annotations

import sys
import threading
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
POSHPROD_DIR = PROJECT_ROOT / "Poshaneyemn"
if str(POSHPROD_DIR) not in sys.path:
    sys.path.insert(0, str(POSHPROD_DIR))

# Fallback care guidance per class (generic public-health wording, no medical claims).
_STATUS_MAP = {
    "healthy": ("Healthy", "Low Risk",
                "Child growth is on track. Maintain balanced nutrition and routine check-ups."),
    "underweight": ("Underweight", "High Risk",
                    "Increase energy-dense foods (dal, ghee, eggs, banana) and refer to the "
                    "local Anganwadi for supplementary nutrition. Re-scan in 30 days."),
    "stunted": ("Stunted", "High Risk",
                "Focus on protein, calcium and micronutrient-rich foods. Track height monthly "
                "and consult a health worker for growth support."),
    "stunted and underweight": ("Stunted & Underweight", "Critical Risk",
                                "Immediate nutritional intervention is required. Refer to the "
                                "nearest health centre for full assessment and follow-up."),
}

# The production predictor loads heavy models; create it once, guard all use.
_predictor = None
_predictor_lock = threading.Lock()
_predict_use_lock = threading.Lock()


def _get_predictor():
    global _predictor
    if _predictor is None:
        with _predictor_lock:
            if _predictor is None:
                from production.inference import HybridProductionPredictor  # type: ignore

                _predictor = HybridProductionPredictor()
    return _predictor


def warm_up() -> None:
    """Load the production artifacts eagerly (called from app startup)."""
    _get_predictor()


def _to_float(value: Any) -> float:
    """Parse a numeric form field; NaN means 'unavailable' (median-imputed downstream)."""
    import math

    if value is None:
        return float("nan")
    try:
        out = float(value)
    except (TypeError, ValueError):
        return float("nan")
    return out if math.isfinite(out) else float("nan")


_MALE_TOKENS = {"male", "m", "boy", "b", "1", "true"}
_FEMALE_TOKENS = {"female", "f", "girl", "g", "0", "false"}


def _to_gender_male(value: Any) -> float:
    """Encode gender as gender_male in [0, 1]; NaN when unknown (imputed downstream)."""
    if value is None:
        return float("nan")
    if isinstance(value, bool):
        return 1.0 if value else 0.0
    if isinstance(value, (int, float)):
        return 1.0 if float(value) >= 0.5 else 0.0
    token = str(value).strip().lower()
    if token in _MALE_TOKENS:
        return 1.0
    if token in _FEMALE_TOKENS:
        return 0.0
    return float("nan")


def extract_anthropometrics(form: dict[str, Any]) -> dict[str, float]:
    """Build the production anthropometric dict from multipart form fields.

    Accepted fields (all optional; missing values follow the exact training
    convention of median imputation with training-split statistics):
      age_years (+age_months), age_months (total), gender, height_cm, weight_kg,
      head_circumference_cm, waist_cm, muac_cm

    Age semantics (matches the Flutter app's ageYears/ageMonths model):
      - if age_years is provided, total age = years*12 + extra months
      - else age_months is interpreted as the total age in months
    """
    years = _to_float(form.get("age_years"))
    months_field = _to_float(form.get("age_months"))

    if years == years:  # finite: years + extra months (extra months may be absent)
        age_months = years * 12.0 + (months_field if months_field == months_field else 0.0)
    else:
        age_months = months_field  # total age in months (NaN when absent)

    return {
        "age_months": age_months,
        "gender_male": _to_gender_male(form.get("gender")),
        "height_cm": _to_float(form.get("height_cm")),
        "weight_kg": _to_float(form.get("weight_kg")),
        "head_circumference_cm": _to_float(form.get("head_circumference_cm")),
        "waist_cm": _to_float(form.get("waist_cm")),
        "muac_cm": _to_float(form.get("muac_cm")),
    }


def _softmax_confidences(class_scores_raw: dict[str, float], temperature: float = 0.5) -> dict[str, float]:
    """Normalize the SVM's raw class scores into UI-displayable shares via softmax.

    These are model-derived relative confidences (sum to 1), NOT trained class
    probabilities — an RBF-SVM does not natively output probabilities. The raw
    scores themselves are also passed through so any client that wants the
    untransformed values can use them.
    """
    import math

    if not class_scores_raw:
        return {}
    mx = max(class_scores_raw.values())
    exp = {k: math.exp((v - mx) / temperature) for k, v in class_scores_raw.items()}
    total = sum(exp.values())
    return {k: v / total for k, v in exp.items()}


def run_hybrid_prediction(image_bytes: bytes, anthropometrics: dict[str, float]) -> dict[str, Any]:
    """Run the full hybrid pipeline and shape the response for the Flutter client."""
    # Temporary data-flow trace (remove after verification)
    print(f"[HYBRID] anthropometrics in: {anthropometrics}", flush=True)

    with _predict_use_lock:  # MediaPipe/TFLite runtime is not thread-safe
        predictor = _get_predictor()
        raw = predictor.predict_from_bgr_bytes(image_bytes, anthropometrics)

    # Temporary data-flow trace (remove after verification)
    print(f"[HYBRID] raw output: {raw}", flush=True)

    label = str(raw["prediction"])  # exact production label string
    status, risk, recommendation = _STATUS_MAP.get(
        label, (_STATUS_MAP["healthy"][0], "Unknown Risk", _STATUS_MAP["healthy"][2])
    )
    raw_scores = raw.get("class_scores_raw") or {}
    return {
        "prediction": label,
        "label_index": int(raw.get("label_index", 0)),
        "confidence": _softmax_confidences(raw_scores).get(label, 0.0),
        "probabilities": _softmax_confidences(raw_scores),
        "class_scores_raw": raw_scores,
        "status": status,
        "risk": risk,
        "recommendation": recommendation,
        "feature_vector_dim": int(raw.get("feature_vector_dim", 0)),
        "model": "hybrid_production_v1",
    }
