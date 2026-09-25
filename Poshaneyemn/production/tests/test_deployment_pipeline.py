"""H9 + end-to-end: the deployed pipeline is the hybrid, not the legacy image-only model."""

from __future__ import annotations

import json

import numpy as np
import tensorflow as tf

from production.config import ANTHROVISION_FRONTAL1_DIR, ARTIFACT_DIR


def test_h9_deployed_pipeline_is_not_the_legacy_image_only_classifier(tflite_path):
    """The old image-only path (in [1,224,224,3] -> out [1,4]) must not be deployed."""
    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()[0]
    out = interpreter.get_output_details()[0]
    assert list(inp["shape"]) == [1, 224, 224, 3]
    assert list(out["shape"]) == [1, 128], (
        "Deployed image model must output a 128-d FEATURE VECTOR, not 4 class probabilities"
    )

    manifest = json.loads(
        (tflite_path.parent / "hybrid_production_manifest.json").read_text(encoding="utf-8")
    )
    assert manifest["image_feature_extractor"]["legacy_head_discarded"].startswith("Dense(4")
    assert manifest["model_family"].startswith("SVC")
    assert manifest["total_feature_dim"] == 168


def test_legacy_best_model_tflite_untouched():
    """The original models/best_model.tflite still exists but is NOT the deployed model."""
    from production.config import PROJECT_ROOT

    legacy = PROJECT_ROOT / "models" / "best_model.tflite"
    assert legacy.exists(), "original best_model.tflite must not be deleted"
    manifest = json.loads(
        (ARTIFACT_DIR / "hybrid_production_manifest.json").read_text(encoding="utf-8")
    )
    assert manifest["classifier_artifacts"][0] == "hybrid_production_svm.joblib"


def test_end_to_end_single_image_prediction(dataset, label_map):
    """Full runtime path: image -> 3 extractors -> preprocessing -> portable SVM."""
    import cv2

    from production.inference import HybridProductionPredictor
    from production.preprocessing import derived_anthro_values

    df = dataset.split("test").head(3)
    predictor = HybridProductionPredictor(
        artifact_dir=ARTIFACT_DIR,
        seg_extractor=None,  # build lazily (DeepLabV3+ weights)
        holistic=None,       # build lazily (MediaPipe)
    )
    for _, row in df.iterrows():
        path = ANTHROVISION_FRONTAL1_DIR / str(row["f1_filename"]).replace("\\", "/").split("/")[-1]
        img = cv2.imread(str(path))
        assert img is not None
        anthro = {
            "age_months": float(row["age_months"]),
            "gender_male": float(row["gender_male"]),
            "height_cm": float(row["height_cm"]),
            "weight_kg": float(row["weight_kg"]),
            "head_circumference_cm": float(row["head_circumference_cm"]),
            "waist_cm": float("nan"),
            "muac_cm": float(row["muac_cm"]),
        }
        anthro.update(derived_anthro_values(anthro["height_cm"], anthro["weight_kg"]))
        result = predictor.predict(img[:, :, ::-1], anthro)
        assert result["prediction"] in label_map.values()
        assert result["feature_vector_dim"] == 168
        assert set(label_map.values()) == {
            "healthy", "underweight", "stunted", "stunted and underweight",
        }
