"""End-to-end test: FastAPI /predict -> production hybrid pipeline (Poshaneyemn).

Proves the NEW Flutter frontend's inference path uses the validated production
hybrid model (MobileNetV2 image features + MediaPipe CV features + DeepLabV3+
segmentation features + anthropometrics -> exact preprocessing -> portable RBF-SVM)
and NOT the legacy image-only best_model.tflite.

Run with the hybrid venv (the one that can load the production stack):
    backend/.venv_hybrid/Scripts/python -m pytest backend/test_hybrid_predict.py -v
"""

from pathlib import Path

import pytest

BACKEND_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = BACKEND_DIR.parent
DATASET_DIR = PROJECT_ROOT / "Poshaneyemn" / "dataset" / "ANTHROVISION" / "frontal1"

VALID_CLASSES = {"healthy", "underweight", "stunted", "stunted and underweight"}


def _sample_image_bytes() -> bytes:
    images = sorted(DATASET_DIR.glob("*.jpg"))
    if not images:
        pytest.skip("no dataset image available for the smoke test")
    return images[0].read_bytes()


@pytest.fixture(scope="module")
def client():
    from fastapi.testclient import TestClient

    from app import app

    with TestClient(app) as test_client:  # context manager runs startup warm-up
        yield test_client


def _post_predict(client, image_bytes: bytes, fields: dict | None = None):
    return client.post(
        "/predict",
        files={"file": ("child.jpg", image_bytes, "image/jpeg")},
        data=fields or {},
    )


def test_health_endpoint(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_predict_with_anthropometrics_uses_hybrid_pipeline(client):
    """Anthropometrics + image -> 168-feature hybrid SVM prediction."""
    response = _post_predict(
        client,
        _sample_image_bytes(),
        {
            "child_name": "Aarav",
            "gender": "Boy",
            "age_years": "2",
            "age_months": "3",  # extra months on top of age_years
            "height_cm": "88.00",
            "weight_kg": "11.50",
        },
    )
    assert response.status_code == 200
    body = response.json()

    # The response contract the Flutter client expects is unchanged...
    assert set(body) >= {"prediction", "confidence", "probabilities", "status", "risk", "recommendation"}
    assert body["prediction"] in VALID_CLASSES

    # ...but it comes from the production hybrid, not the legacy image-only model.
    assert body["feature_vector_dim"] == 168
    assert body["model"] == "hybrid_production_v1"


def test_predict_image_only_imputes_missing_values(client):
    """No anthropometrics at all -> median imputation, no crash."""
    response = _post_predict(client, _sample_image_bytes())
    assert response.status_code == 200
    body = response.json()
    assert body["prediction"] in VALID_CLASSES
    assert body["feature_vector_dim"] == 168


def test_age_years_plus_months_equals_total_months(client):
    """2y 3m and 27 total months must produce the identical prediction."""
    r_years = _post_predict(
        client, _sample_image_bytes(),
        {"age_years": "2", "age_months": "3", "gender": "male",
         "height_cm": "88", "weight_kg": "11.5"},
    )
    r_total = _post_predict(
        client, _sample_image_bytes(),
        {"age_months": "27", "gender": "male",
         "height_cm": "88", "weight_kg": "11.5"},
    )
    assert r_years.status_code == r_total.status_code == 200
    assert r_years.json()["prediction"] == r_total.json()["prediction"]


def test_invalid_anthropometrics_are_imputed_not_rejected(client):
    """Garbage field values must follow the NaN -> training-median convention."""
    response = _post_predict(
        client,
        _sample_image_bytes(),
        {"height_cm": "not-a-number", "weight_kg": "", "gender": "unknown"},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["prediction"] in VALID_CLASSES
    assert body["feature_vector_dim"] == 168
