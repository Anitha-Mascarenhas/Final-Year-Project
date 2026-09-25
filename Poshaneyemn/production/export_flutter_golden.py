"""Generate the Flutter golden parity vector (Python is the source of truth).

Produces poshaneye_flutter/test/services/golden_vector.json:
  raw_fused (168) -> preprocessed (168) -> expected label
so the Dart HybridInferenceService can be asserted to produce identical numbers.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np

from .config import ARTIFACT_DIR
from .dataset import build_dataset
from .preprocessing import HybridPreprocessor


def main() -> None:
    out_path = Path(__file__).resolve().parents[2] / "poshaneye_flutter" / "test" / "services" / "golden_vector.json"
    pre = HybridPreprocessor.load(ARTIFACT_DIR / "hybrid_production_preprocessor.json")
    ds = build_dataset()
    test_df = ds.split("test")

    import cv2
    from .image_branch import extract_image_features, load_image_feature_extractor
    from .runtime_features import SegmentationFeatureExtractor, extract_cv_features, make_holistic

    extractor = load_image_feature_extractor()
    holistic = make_holistic()
    seg = SegmentationFeatureExtractor()

    row = test_df.iloc[0]
    path = ARTIFACT_DIR.parents[1] / "dataset" / "ANTHROVISION" / "frontal1" / Path(str(row["f1_filename"])).name
    img = cv2.imread(str(path))
    image_features = extract_image_features(extractor, img[:, :, ::-1])
    cv_feats = extract_cv_features(img, holistic)
    sw = cv_feats.get("shoulder_width")
    seg_feats = seg.extract_features(img[:, :, ::-1], float(sw) if sw is not None and np.isfinite(sw) else None)
    anthro = {
        "age_months": float(row["age_months"]),
        "gender_male": float(row["gender_male"]),
        "height_cm": float(row["height_cm"]),
        "weight_kg": float(row["weight_kg"]),
        "head_circumference_cm": float(row["head_circumference_cm"]),
        "waist_cm": float("nan"),
        "muac_cm": float(row["muac_cm"]),
        "bmi": float(row["bmi"]),
    }

    x = pre.transform_single(image_features, cv_feats, seg_feats, anthro)[0]

    from .fusion import PortableSVM

    svm = PortableSVM.load(ARTIFACT_DIR / "hybrid_production_svm_portable.json")
    label = svm.predict_one(x)

    payload = {
        "description": "Golden parity vector: child_id "
        f"{int(row['child_id'])}, true label {int(row['label'])}",
        "image_features": [float(v) for v in image_features],
        "cv_features": {k: None if not np.isfinite(v) else float(v) for k, v in cv_feats.items()},
        "segmentation_features": {k: None if not np.isfinite(v) else float(v) for k, v in seg_feats.items()},
        "anthropometric_features": {k: None if not np.isfinite(v) else float(v) for k, v in anthro.items()},
        "expected_preprocessed_vector": [float(v) for v in x],
        "expected_label_index": int(label),
        "expected_label": {0: "healthy", 1: "underweight", 2: "stunted",
                           3: "stunted and underweight"}[int(label)],
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    print(f"saved golden vector to {out_path} (label={payload['expected_label']})")


if __name__ == "__main__":
    main()
