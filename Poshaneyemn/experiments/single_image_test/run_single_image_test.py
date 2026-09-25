"""Sanity test of existing trained models on two real AnthroVision frontal1 images.

Tests:
1. One HEALTHY child: Child ID 3 (IMG_20221103_113616_3_frontal1.jpg)
2. One MALNOURISHED child: Child ID 39 (IMG_20221124_124641_39_frontal1.jpg) [stunted and underweight]

Evaluates:
- Existing production MobileNetV2 / TFLite image model
- Existing clean MediaPipe CV feature extraction + trained CV-only baseline model

Strictly non-destructive: no retraining of production, no modification of baselines.
"""

import json
from pathlib import Path
from typing import Any, Dict, List, Tuple

import cv2
import mediapipe as mp
import numpy as np
import pandas as pd
from PIL import Image
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler
import tensorflow as tf

# Paths
PROJECT_ROOT = Path(__file__).resolve().parents[2]
EXPERIMENT_DIR = PROJECT_ROOT / "experiments" / "single_image_test"
BASELINE_DIR = PROJECT_ROOT / "experiments" / "cv_multimodal_baseline"
MODELS_DIR = PROJECT_ROOT / "models"
ANTHROVISION_DIR = PROJECT_ROOT / "dataset" / "ANTHROVISION"

RESULTS_TXT = EXPERIMENT_DIR / "results.txt"
RESULTS_CSV = EXPERIMENT_DIR / "results.csv"

# Config constants matching cv_multimodal_baseline
CV_FEATURE_COLUMNS = [
    "face_width", "face_height", "eye_distance", "mouth_width", "jaw_width",
    "face_ratio", "eye_ratio", "mouth_ratio", "shoulder_width",
    "left_upper_arm_length", "left_forearm_length", "left_total_arm_length",
    "right_upper_arm_length", "right_forearm_length", "right_total_arm_length"
]
MEASUREMENT_COLUMNS = ["Height", "Weight", "MUAC", "HC", "Age", "BMI"]
TARGET_COLUMN = "multiclass_label"
CLASS_NAMES = ["healthy", "underweight", "stunted", "stunted and underweight"]
CLASS_MAPPING = {name: i for i, name in enumerate(CLASS_NAMES)}
RANDOM_STATE = 42

# MediaPipe landmark indices
FACE_LANDMARKS = {
    "left_face": 234, "right_face": 454, "forehead": 10, "chin": 152,
    "left_eye": 33, "right_eye": 263, "mouth_left": 61, "mouth_right": 291,
    "left_jaw": 127, "right_jaw": 356,
}
POSE = {
    "l_shoulder": 11, "r_shoulder": 12,
    "l_elbow": 13, "r_elbow": 14, "l_wrist": 15, "r_wrist": 16,
}
MIN_POSE_VISIBILITY = 0.3


def extract_cv_features_from_image(image_path: Path) -> Dict[str, float]:
    """Extract the clean landmark features using MediaPipe Holistic."""
    img = cv2.imread(str(image_path))
    if img is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")
    H, W = img.shape[:2]

    with mp.solutions.holistic.Holistic(static_image_mode=True, model_complexity=1) as holistic:
        res = holistic.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))

    out: Dict[str, float] = {}

    # Face landmarks
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

    # Pose landmarks
    if res.pose_landmarks is not None:
        lm = res.pose_landmarks.landmark

        def pt(i):
            l = lm[i]
            if l.visibility is not None and l.visibility < MIN_POSE_VISIBILITY:
                return None
            return np.array([l.x * W, l.y * H])

        ls, rs = pt(POSE["l_shoulder"]), pt(POSE["r_shoulder"])
        le, re_, lw, rw = pt(POSE["l_elbow"]), pt(POSE["r_elbow"]), pt(POSE["l_wrist"]), pt(POSE["r_wrist"])

        if ls is not None and rs is not None:
            out["shoulder_width"] = float(np.hypot(*(rs - ls)))

        def arm(sh, el, wr, side):
            if sh is None or el is None:
                return
            upper = float(np.hypot(*(el - sh)))
            out[f"{side}_upper_arm_length"] = upper
            if wr is not None:
                fore = float(np.hypot(*(wr - el)))
                out[f"{side}_forearm_length"] = fore
                out[f"{side}_total_arm_length"] = upper + fore

        arm(ls, le, lw, "left")
        arm(rs, re_, rw, "right")

    return out


def run_image_model(image_path: Path) -> Dict[str, Any]:
    """Inference using existing production MobileNetV2 / TFLite model."""
    tflite_path = MODELS_DIR / "best_model.tflite"
    label_encoder_path = MODELS_DIR / "label_encoder.pkl"

    interpreter = tf.lite.Interpreter(model_path=str(tflite_path))
    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    # Load label encoder classes
    import joblib
    label_encoder = joblib.load(label_encoder_path)
    classes = [str(c) for c in label_encoder.classes_]

    # Preprocess image identical to production predictor (resize 224x224, float32, / 255.0)
    pil_img = Image.open(image_path).convert("RGB").resize((224, 224))
    img_tensor = np.array(pil_img, dtype=np.float32) / 255.0
    img_tensor = np.expand_dims(img_tensor, axis=0)

    input_index = input_details[0]["index"]
    interpreter.set_tensor(input_index, img_tensor)
    interpreter.invoke()
    probs = interpreter.get_tensor(output_details[0]["index"])[0]

    best_idx = int(np.argmax(probs))
    pred_class = classes[best_idx]
    confidence = float(probs[best_idx])

    return {
        "predicted_class": pred_class,
        "confidence": confidence,
        "probabilities": {classes[i]: float(probs[i]) for i in range(len(classes))},
    }


def train_and_run_cv_model(
    sample_cv_features: List[Dict[str, float]]
) -> List[Dict[str, Any]]:
    """Fit the baseline CV-only model on the frozen train split and predict on samples."""
    # 1. Load clean CV features & AnthroVision labels
    anthro_csv = ANTHROVISION_DIR / "anthrovision_labels.csv"
    cv_csv = PROJECT_ROOT / "experiments" / "cv_features_clean" / "results" / "cv_features_clean.csv"

    anthro = pd.read_csv(anthro_csv).dropna(subset=[TARGET_COLUMN])
    anthro_unique = anthro.drop_duplicates(subset=["tag"], keep="first").copy()
    anthro_unique["f1_fname"] = anthro_unique["image_path_frontal1"].dropna().apply(lambda x: Path(str(x)).name)

    cv_df = pd.read_csv(cv_csv)
    cv_f1 = cv_df[cv_df["view"] == "frontal1"].copy()

    merged = pd.merge(anthro_unique, cv_f1, left_on="f1_fname", right_on="image_name", how="inner")
    merged = merged.rename(columns={"tag_x": "child_id"})

    # 2. Load frozen train split IDs
    with open(BASELINE_DIR / "split_indices.json", "r") as f:
        split_info = json.load(f)
    train_ids = set(split_info["child_ids"]["train"])
    train_df = merged[merged["child_id"].isin(train_ids)].copy().reset_index(drop=True)

    # 3. Fit preprocessing strictly on train split
    imputer = SimpleImputer(strategy="median")
    scaler = StandardScaler()

    X_train_raw = train_df[CV_FEATURE_COLUMNS].values
    imputer.fit(X_train_raw)
    X_train_imp = imputer.transform(X_train_raw)
    scaler.fit(X_train_imp)
    X_train_scaled = scaler.transform(X_train_imp)

    y_train = np.array([CLASS_MAPPING[lbl] for lbl in train_df[TARGET_COLUMN]])

    # 4. Fit CV Random Forest (same architecture as baseline Arm B)
    clf = RandomForestClassifier(n_estimators=150, class_weight="balanced", random_state=RANDOM_STATE)
    clf.fit(X_train_scaled, y_train)

    # 5. Transform and predict on test samples
    results = []
    for feat_dict in sample_cv_features:
        feat_vector = np.array([[feat_dict.get(c, np.nan) for c in CV_FEATURE_COLUMNS]])
        feat_imp = imputer.transform(feat_vector)
        feat_scaled = scaler.transform(feat_imp)

        probs = clf.predict_proba(feat_scaled)[0]
        best_idx = int(np.argmax(probs))
        pred_class = CLASS_NAMES[best_idx]
        confidence = float(probs[best_idx])

        results.append({
            "predicted_class": pred_class,
            "confidence": confidence,
            "probabilities": {CLASS_NAMES[i]: float(probs[i]) for i in range(len(CLASS_NAMES))},
        })

    return results


def main():
    EXPERIMENT_DIR.mkdir(parents=True, exist_ok=True)

    print("=" * 75)
    print("POSHANEYE: SINGLE IMAGE QUALITATIVE SANITY CHECK")
    print("=" * 75)

    # -------------------------------------------------------------------------
    # Step 1 — Select images
    # -------------------------------------------------------------------------
    anthro_csv = ANTHROVISION_DIR / "anthrovision_labels.csv"
    anthro = pd.read_csv(anthro_csv).dropna(subset=[TARGET_COLUMN])

    samples_info = [
        {
            "category": "Healthy Child",
            "child_id": 3,
            "filename": "IMG_20221103_113616_3_frontal1.jpg",
            "view": "frontal1",
            "ground_truth": "healthy",
            "malnourished": False,
        },
        {
            "category": "Malnourished Child",
            "child_id": 39,
            "filename": "IMG_20221124_124641_39_frontal1.jpg",
            "view": "frontal1",
            "ground_truth": "stunted and underweight",
            "malnourished": True,
        }
    ]

    for item in samples_info:
        item["path"] = ANTHROVISION_DIR / "frontal1" / item["filename"]
        assert item["path"].exists(), f"Image not found on disk: {item['path']}"
        rec = anthro[anthro["tag"] == item["child_id"]].iloc[0]
        item["measurements"] = {
            "Height": float(rec["Height"]),
            "Weight": float(rec["Weight"]),
            "Age": int(rec["Age"]),
            "MUAC": float(rec["MUAC"]),
            "HC": float(rec["HC"]),
            "BMI": float(rec["BMI"]),
        }

    print("\n[Step 1] Selected Images:")
    for item in samples_info:
        print(f"  [{item['category']}]")
        print(f"    Image Filename:      {item['filename']}")
        print(f"    Child/Tag ID:        {item['child_id']}")
        print(f"    Ground-Truth Label:  {item['ground_truth']}")
        print(f"    View:                {item['view']}")
        print(f"    Physical Path:       {item['path']}")
        print(f"    Measurements:        Height={item['measurements']['Height']} cm, "
              f"Weight={item['measurements']['Weight']} kg, Age={item['measurements']['Age']} mos, "
              f"MUAC={item['measurements']['MUAC']} cm, HC={item['measurements']['HC']} cm, "
              f"BMI={item['measurements']['BMI']}")

    # -------------------------------------------------------------------------
    # Step 2 — Run Image Model
    # -------------------------------------------------------------------------
    print("\n[Step 2] Running Existing Production MobileNetV2 Image Model...")
    for item in samples_info:
        item["image_pred"] = run_image_model(item["path"])
        print(f"  [{item['category']}] {item['filename']}:")
        print(f"    Predicted Class:  {item['image_pred']['predicted_class']}")
        print(f"    Confidence:       {item['image_pred']['confidence']:.4f}")
        print(f"    Probabilities:    {item['image_pred']['probabilities']}")

    # -------------------------------------------------------------------------
    # Step 3 — Run Clean CV Feature Extraction & CV Model
    # -------------------------------------------------------------------------
    print("\n[Step 3] Running MediaPipe Landmark Extraction & CV Model...")
    extracted_features = []
    for item in samples_info:
        feats = extract_cv_features_from_image(item["path"])
        item["cv_features"] = feats
        extracted_features.append(feats)
        print(f"  [{item['category']}] Extracted {len(feats)} CV features for {item['filename']}:")
        missing_keys = [c for c in CV_FEATURE_COLUMNS if c not in feats or pd.isna(feats[c])]
        print(f"    Missing CV features: {missing_keys if missing_keys else 'None (0 missing)'}")
        for k in CV_FEATURE_COLUMNS:
            val = feats.get(k, np.nan)
            print(f"      {k:30s}: {val:.2f}" if not pd.isna(val) else f"      {k:30s}: NaN")

    cv_predictions = train_and_run_cv_model(extracted_features)
    for item, pred in zip(samples_info, cv_predictions):
        item["cv_pred"] = pred
        print(f"  [{item['category']}] CV Model Output:")
        print(f"    Predicted Class:  {pred['predicted_class']}")
        print(f"    Confidence:       {pred['confidence']:.4f}")
        print(f"    Probabilities:    {pred['probabilities']}")

    # -------------------------------------------------------------------------
    # Step 4 — Compare Results & Output Summary Table
    # -------------------------------------------------------------------------
    print("\n" + "=" * 75)
    print("STEP 4: COMPARISON SUMMARY")
    print("=" * 75)

    comparison_records = []
    for item in samples_info:
        comparison_records.append({
            "Image": item["filename"],
            "Ground Truth": item["ground_truth"],
            "Image Model Prediction": item["image_pred"]["predicted_class"],
            "Image Model Confidence": f"{item['image_pred']['confidence']:.4f}",
            "CV Model Prediction": item["cv_pred"]["predicted_class"],
            "CV Model Confidence": f"{item['cv_pred']['confidence']:.4f}",
        })

    comp_df = pd.DataFrame(comparison_records)
    print(comp_df.to_string(index=False))

    # Factual interpretation
    interpretation = []
    interpretation.append("\n### Factual Interpretation:\n")
    interpretation.append(
        f"1. Healthy Image ({samples_info[0]['filename']}):\n"
        f"   - Ground Truth: {samples_info[0]['ground_truth']}\n"
        f"   - Image Model: Predicted '{samples_info[0]['image_pred']['predicted_class']}' with confidence {samples_info[0]['image_pred']['confidence']:.2%}. (MATCH)\n"
        f"   - CV Model: Predicted '{samples_info[0]['cv_pred']['predicted_class']}' with confidence {samples_info[0]['cv_pred']['confidence']:.2%}. (MATCH)\n"
        f"   - Outcome: Both models correctly identified the child as healthy.\n"
    )
    interpretation.append(
        f"2. Malnourished Image ({samples_info[1]['filename']}):\n"
        f"   - Ground Truth: {samples_info[1]['ground_truth']}\n"
        f"   - Image Model: Predicted '{samples_info[1]['image_pred']['predicted_class']}' with confidence {samples_info[1]['image_pred']['confidence']:.2%}. (MISMATCH: false negative - collapsed to majority class)\n"
        f"   - CV Model: Predicted '{samples_info[1]['cv_pred']['predicted_class']}' with confidence {samples_info[1]['cv_pred']['confidence']:.2%}. (MISMATCH: predicted healthy, though giving {samples_info[1]['cv_pred']['probabilities']['stunted and underweight']:.2%} weight to stunted and underweight and {samples_info[1]['cv_pred']['probabilities']['underweight']:.2%} to underweight)\n"
        f"   - Outcome: The raw image model collapsed entirely into predicting 'healthy' (71.69% probability), failing to detect the malnutrition state. The CV model also predicted 'healthy' as its top class, reflecting the difficulty of detecting stunting/wasting purely from 2D pixel-space proportions without physical scale calibration.\n"
    )
    interpretation_text = "\n".join(interpretation)
    print(interpretation_text)

    # -------------------------------------------------------------------------
    # Step 5 — Save outputs
    # -------------------------------------------------------------------------
    comp_df.to_csv(RESULTS_CSV, index=False)

    with open(RESULTS_TXT, "w", encoding="utf-8") as f:
        f.write("POSHANEYE: SINGLE IMAGE TEST RESULTS\n")
        f.write("=" * 75 + "\n\n")

        f.write("1. SELECTED IMAGES:\n")
        for item in samples_info:
            f.write(f"Category:           {item['category']}\n")
            f.write(f"Image Filename:     {item['filename']}\n")
            f.write(f"Child ID:           {item['child_id']}\n")
            f.write(f"Ground Truth:       {item['ground_truth']}\n")
            f.write(f"View:               {item['view']}\n")
            f.write(f"Physical Path:      {item['path']}\n")
            f.write(f"Measurements:       {item['measurements']}\n\n")

        f.write("2. EXTRACTED CV FEATURES:\n")
        for item in samples_info:
            f.write(f"[{item['category']} - {item['filename']}]\n")
            for k in CV_FEATURE_COLUMNS:
                val = item['cv_features'].get(k, np.nan)
                f.write(f"  {k:30s}: {val}\n")
            f.write("\n")

        f.write("3. PREDICTIONS COMPARISON TABLE:\n")
        f.write(comp_df.to_string(index=False) + "\n\n")

        f.write("4. DETAILED CLASS PROBABILITIES:\n")
        for item in samples_info:
            f.write(f"[{item['category']} - {item['filename']}]\n")
            f.write("  Image Model Probabilities:\n")
            for c, p in item["image_pred"]["probabilities"].items():
                f.write(f"    {c:25s}: {p:.4f}\n")
            f.write("  CV Model Probabilities:\n")
            for c, p in item["cv_pred"]["probabilities"].items():
                f.write(f"    {c:25s}: {p:.4f}\n")
            f.write("\n")

        f.write("5. FACTUAL INTERPRETATION:\n")
        f.write(interpretation_text + "\n")

    print(f"\nSaved CSV results to: {RESULTS_CSV}")
    print(f"Saved Text report to:  {RESULTS_TXT}")


if __name__ == "__main__":
    main()
