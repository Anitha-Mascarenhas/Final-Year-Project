"""Clean CV anthropometric feature dataset for AnthroVision.

Landmark-derived features only. No arm width, no segmentation-derived widths,
no image-derived MUAC. Production files untouched.

Features:
  face:      face_width, face_height, eye_distance, mouth_width, jaw_width,
             face_ratio, eye_ratio, mouth_ratio            (frontal views only)
  arm:       shoulder_width,
             left/right_upper_arm_length  (shoulder->elbow),
             left/right_forearm_length    (elbow->wrist),
             left/right_total_arm_length  (sum),
             left/right_upper_arm_to_shoulder_ratio,
             left/right_forearm_to_shoulder_ratio,
             left/right_total_arm_to_shoulder_ratio
             (frontal + lateral views; pose landmarks)

Outputs (experiments/cv_features_clean/):
  results/cv_features_clean.csv   one row per image
  results/missing_counts.csv      per-feature missing counts
  results/summary_statistics.csv  descriptive stats
  results/report.md               summary report
"""

from __future__ import annotations

# protobuf 6.x compatibility for mediapipe 0.10.14 (must precede mediapipe import)
from google.protobuf import symbol_database, descriptor_pool, message_factory

if not hasattr(symbol_database.SymbolDatabase, "GetPrototype"):
    def _GetPrototype(self, descriptor):
        return message_factory.GetMessageClass(
            descriptor_pool.Default().FindMessageTypeByName(descriptor.full_name)
        )
    symbol_database.SymbolDatabase.GetPrototype = _GetPrototype

import math
import re
import time
from collections import Counter
from pathlib import Path

import cv2
import numpy as np
import pandas as pd
import mediapipe as mp

HERE = Path(__file__).resolve().parent
RESULT_DIR = HERE / "results"
RESULT_DIR.mkdir(parents=True, exist_ok=True)

DATASET_ROOT = HERE.parent.parent / "dataset" / "ANTHROVISION"

FACE_LANDMARKS = {  # same indices as scripts/generate_cv_features.py
    "left_face": 234, "right_face": 454, "forehead": 10, "chin": 152,
    "left_eye": 33, "right_eye": 263, "mouth_left": 61, "mouth_right": 291,
    "left_jaw": 127, "right_jaw": 356,
}
POSE = {
    "l_shoulder": 11, "r_shoulder": 12,
    "l_elbow": 13, "r_elbow": 14, "l_wrist": 15, "r_wrist": 16,
}
MIN_POSE_VISIBILITY = 0.3

FACE_FEATURES = [
    "face_width", "face_height", "eye_distance", "mouth_width", "jaw_width",
    "face_ratio", "eye_ratio", "mouth_ratio",
]
ARM_FEATURES = [
    "shoulder_width",
    "left_upper_arm_length", "right_upper_arm_length",
    "left_forearm_length", "right_forearm_length",
    "left_total_arm_length", "right_total_arm_length",
    "left_upper_arm_to_shoulder_ratio", "right_upper_arm_to_shoulder_ratio",
    "left_forearm_to_shoulder_ratio", "right_forearm_to_shoulder_ratio",
    "left_total_arm_to_shoulder_ratio", "right_total_arm_to_shoulder_ratio",
]
ALL_FEATURES = FACE_FEATURES + ARM_FEATURES

VIEW_RE = re.compile(r"_(frontal\d*|lateralleft|lateralright|back|selfie|handswide)$")


def view_of(path: Path) -> str | None:
    m = VIEW_RE.search(path.stem.lower())
    return m.group(1) if m else None


def tag_of(path: Path) -> str | None:
    m = VIEW_RE.search(path.stem)
    return path.stem[: m.start()] if m else None


def extract(image_path: Path, holistic) -> dict | None:
    img = cv2.imread(str(image_path))
    if img is None:
        return None
    H, W = img.shape[:2]
    res = holistic.process(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    out: dict = {
        "image_name": image_path.name,
        "tag": tag_of(image_path),
        "view": view_of(image_path),
    }

    # ---------- face features (frontal views only) ----------
    if out["view"] and out["view"].startswith("frontal") and res.face_landmarks is not None:
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

    # ---------- arm features (frontal + lateral views) ----------
    if out["view"] and not out["view"].startswith("back") and res.pose_landmarks is not None:
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
            sw = out.get("shoulder_width")
            if sw:
                out[f"{side}_upper_arm_to_shoulder_ratio"] = upper / sw
                if out.get(f"{side}_forearm_length") is not None:
                    out[f"{side}_forearm_to_shoulder_ratio"] = out[f"{side}_forearm_length"] / sw
                if out.get(f"{side}_total_arm_length") is not None:
                    out[f"{side}_total_arm_to_shoulder_ratio"] = out[f"{side}_total_arm_length"] / sw

        arm(ls, le, lw, "left")
        arm(rs, re_, rw, "right")

    return out


def main() -> None:
    t0 = time.time()
    images = sorted(p for p in DATASET_ROOT.rglob("*")
                    if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png"}
                    and view_of(p))
    print(f"images to process: {len(images)}  "
          f"({dict(Counter(view_of(p) for p in images))})")

    # reuse one Holistic instance for speed; segmentation NOT needed
    holistic = mp.solutions.holistic.Holistic(
        static_image_mode=True, model_complexity=1, refine_face_landmarks=False,
    )
    rows = []
    for i, p in enumerate(images, 1):
        try:
            feats = extract(p, holistic)
        except Exception as exc:
            print(f"[ERROR] {p.name}: {exc}")
            feats = None
        if feats:
            rows.append(feats)
        if i % 250 == 0:
            el = time.time() - t0
            print(f"  {i}/{len(images)}  rows={len(rows)}  {el:.0f}s  "
                  f"ETA {el / i * (len(images) - i) / 60:.1f} min")
    holistic.close()

    df = pd.DataFrame(rows)
    out_csv = RESULT_DIR / "cv_features_clean.csv"
    df.to_csv(out_csv, index=False)
    print(f"wrote {out_csv}  rows={len(df)}")

    n_children = df["tag"].nunique()
    print(f"unique children (tags): {n_children}")

    # missing counts
    miss = {c: int(df[c].isna().sum()) for c in ALL_FEATURES}
    miss["n_images"] = len(df)
    miss["n_children"] = n_children
    pd.Series(miss).to_csv(RESULT_DIR / "missing_counts.csv", header=["missing"])

    # descriptive statistics + extreme-value flagging
    stats_df = df[ALL_FEATURES].describe().T.round(3)
    stats_df["n_extreme_outliers"] = [
        int(((df[c] < df[c].quantile(0.001)) | (df[c] > df[c].quantile(0.999))).sum())
        for c in ALL_FEATURES
    ]
    stats_df.to_csv(RESULT_DIR / "summary_statistics.csv")

    # sanity-check ratios physically (should be ~0.1-0.8 of shoulder width)
    ratio_cols = [c for c in ALL_FEATURES if c.endswith("_ratio") and "face" not in c
                  and "eye" not in c and "mouth" not in c]
    invalid = {}
    for c in ratio_cols:
        n_bad = int(((df[c] < 0.05) | (df[c] > 1.2)).sum())
        invalid[c] = n_bad
    print("ratio features outside plausible [0.05, 1.2] band:", invalid)

    # report
    lines = ["# Clean CV anthropometric features", ""]
    lines.append(f"- images processed: {len(df)}")
    lines.append(f"- unique children: {n_children}")
    lines.append(f"- views: {dict(Counter(df['view']))}")
    lines.append("")
    lines.append("## Missing counts per feature")
    lines.append("")
    lines.append("| feature | missing | available |")
    lines.append("|---|---|---|")
    for c in ALL_FEATURES:
        lines.append(f"| {c} | {miss[c]} | {len(df) - miss[c]} |")
    lines.append("")
    lines.append("## Extreme-value checks")
    lines.append("")
    lines.append(f"- pose-ratio features outside plausible [0.05, 1.2]: {invalid}")
    lines.append("")
    lines.append("## Summary statistics (see summary_statistics.csv for full table)")
    lines.append("")
    lines.append(stats_df.to_markdown())
    (RESULT_DIR / "report.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {RESULT_DIR / 'report.md'}")
    print(f"total time: {time.time() - t0:.0f}s")


if __name__ == "__main__":
    main()
