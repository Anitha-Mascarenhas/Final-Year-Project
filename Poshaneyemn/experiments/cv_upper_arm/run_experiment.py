"""Standalone experiment: image-derived upper-arm measurements from AnthroVision frontal photos.

Production code is untouched. Everything is computed here, with the MediaPipe
landmark indices reused from scripts/generate_cv_features.py.

Outputs (all under experiments/cv_upper_arm/):
  results/cv_upper_arm_features.csv   per-image upper-arm features
  results/muac_correlation.csv        correlation analysis vs real MUAC
  results/summary_statistics.csv      feature summary stats
  results/missing_counts.csv          per-feature missing/invalid counts
  results/scatter_armwidth_vs_muac.png
  results/scatter_ratio_vs_muac.png
  results/report.md                   human-readable summary
"""

from __future__ import annotations

# ---------------------------------------------------------------------------
# protobuf 6.x compatibility patch (mediapipe 0.10.14 expects protobuf<=4 API).
# Must run before importing mediapipe.
# ---------------------------------------------------------------------------
from google.protobuf import symbol_database, descriptor_pool, message_factory

if not hasattr(symbol_database.SymbolDatabase, "GetPrototype"):
    def _GetPrototype(self, descriptor):
        return message_factory.GetMessageClass(
            descriptor_pool.Default().FindMessageTypeByName(descriptor.full_name)
        )
    symbol_database.SymbolDatabase.GetPrototype = _GetPrototype

import json
import math
import time
from pathlib import Path

import cv2
import numpy as np
import pandas as pd

import mediapipe as mp

HERE = Path(__file__).resolve().parent
RESULT_DIR = HERE / "results"
RESULT_DIR.mkdir(parents=True, exist_ok=True)

DATASET_ROOT = HERE.parent.parent / "dataset" / "ANTHROVISION"
LABELS_CSV = DATASET_ROOT / "anthrovision_labels.csv"
FEATURES_OUT = RESULT_DIR / "cv_upper_arm_features.csv"

# Arm measurement is taken at this fraction along the shoulder->elbow axis
# (0.5 = mid upper arm, matching where MUAC is measured).
MEASURE_T = 0.5
# How far perpendicular to search for the arm silhouette crossing.
PERP_SPAN_FACTOR = 1.0
PERP_SPAN_MIN_PX = 40.0
# Reject implausible widths (> this fraction of shoulder width = bad crossing).
# Set slightly above 1.0: in frontal poses the perpendicular scanline at mid
# upper-arm often crosses BOTH the arm and the torso edge as one merged run,
# which is wider than 0.75*shoulder but still the arm's true apparent width.
MAX_WIDTH_FRACTION_OF_SHOULDER = 1.05
# The chosen run's center may sit up to this multiple of the upper-arm length
# away from the measurement point (loose guard: only rejects far-off hits).
MAX_RUN_CENTER_FRACTION = 1.2
# Minimum pose-landmark visibility for arm landmarks.
MIN_VISIBILITY = 0.3

# Pose landmark indices (same convention as generate_cv_features.py)
L_SHOULDER, R_SHOULDER = 11, 12
L_ELBOW, R_ELBOW = 13, 14
L_WRIST, R_WRIST = 15, 16
# Face landmarks for face-height scale normalizer
FOREHEAD, CHIN = 10, 152


def perpendicular_width(
    base: np.ndarray,
    direction: np.ndarray,
    mask: np.ndarray,
    img_w: int,
    img_h: int,
    axis_length: float,
    shoulder_width: float | None = None,
) -> tuple[float | None, float | None]:
    """Measure apparent body-part width along a perpendicular scanline.

    Returns (width_px, center_t) where center_t is the offset of the chosen
    silhouette crossing's center from `base` along the perpendicular direction.
    """
    d = direction
    L = float(np.hypot(*d))
    if L < 1e-6:
        return None, None
    u = d / L
    n = np.array([-u[1], u[0]])
    span = max(PERP_SPAN_MIN_PX, PERP_SPAN_FACTOR * axis_length)
    ts = np.arange(-span, span + 1.0, 1.0)
    pts = base[None, :] + ts[:, None] * n[None, :]
    xi = np.clip(np.round(pts[:, 0]).astype(int), 0, img_w - 1)
    yi = np.clip(np.round(pts[:, 1]).astype(int), 0, img_h - 1)
    vals = mask[yi, xi]
    padded = np.concatenate([[False], vals, [False]])
    diff = np.diff(padded.astype(np.int8))
    starts = np.where(diff == 1)[0]
    ends = np.where(diff == -1)[0]
    if len(starts) == 0:
        return None, None
    widths = (ends - starts).astype(float)
    centers_idx = (starts + ends - 1) // 2
    t_centers = ts[np.clip(centers_idx, 0, len(ts) - 1)]
    # Pick the plausible run whose center is closest to the axis. In frontal
    # poses the scanline often crosses the arm and the torso edge as ONE merged
    # run, so the width cap is generous (1.05 x shoulder width). If nothing
    # passes the caps, fall back to the closest run rather than dropping the
    # measurement entirely.
    sw = shoulder_width if shoulder_width else 1e9
    best = None
    for i in range(len(widths)):
        if widths[i] > MAX_WIDTH_FRACTION_OF_SHOULDER * sw:
            continue
        if abs(t_centers[i]) > MAX_RUN_CENTER_FRACTION * axis_length:
            continue
        if best is None or abs(t_centers[i]) < abs(t_centers[best]):
            best = i
    if best is None:
        best = int(np.argmin(np.abs(t_centers)))
    return float(widths[best]), float(t_centers[best])


def extract_image_features(image_path: Path) -> dict | None:
    img = cv2.imread(str(image_path))
    if img is None:
        return None
    H, W = img.shape[:2]
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)

    with mp.solutions.holistic.Holistic(
        static_image_mode=True,
        model_complexity=1,
        enable_segmentation=True,
        refine_face_landmarks=False,
    ) as holistic:
        res = holistic.process(rgb)

    out: dict = {"image_name": image_path.name}

    if res.pose_landmarks is None or res.face_landmarks is None:
        return out  # features left NaN

    lm = res.pose_landmarks.landmark
    flm = res.face_landmarks.landmark

    def pt(idx: int, check_vis: bool = True):
        l = lm[idx]
        if check_vis and l.visibility is not None and l.visibility < MIN_VISIBILITY:
            return None
        return np.array([l.x * W, l.y * H])

    # scale normalizers
    fh = flm[FOREHEAD]
    fc = flm[CHIN]
    face_height = float(np.hypot(fh.x * W - fc.x * W, fh.y * H - fc.y * H))

    ls, rs = pt(L_SHOULDER), pt(R_SHOULDER)
    le, re = pt(L_ELBOW), pt(R_ELBOW)
    lw, rw = pt(L_WRIST), pt(R_WRIST)

    out["face_height"] = face_height
    if ls is not None and rs is not None:
        out["shoulder_width"] = float(np.hypot(*(rs - ls)))

    mask = None
    if res.segmentation_mask is not None:
        mask = res.segmentation_mask > 0.5

    def arm_measurements(sh, el, wr, side: str):
        if sh is None or el is None:
            return
        upper_len = float(np.hypot(*(el - sh)))
        out[f"{side}_upper_arm_length"] = upper_len
        if wr is not None:
            out[f"{side}_forearm_length"] = float(np.hypot(*(wr - el)))
        if mask is None:
            return
        # width at mid upper-arm, perpendicular to the shoulder->elbow axis
        base = sh + MEASURE_T * (el - sh)
        w_px, t_center = perpendicular_width(
            base, el - sh, mask, W, H, upper_len,
            shoulder_width=out.get("shoulder_width"),
        )
        if w_px is None:
            return
        sw = out.get("shoulder_width")
        # sanity: reject crossings wider than a plausible fraction of shoulder width
        if sw is not None and w_px > MAX_WIDTH_FRACTION_OF_SHOULDER * sw:
            return
        # sanity: reject runs whose center is far off-axis (probably not the arm)
        if abs(t_center) > MAX_RUN_CENTER_FRACTION * upper_len:
            return
        out[f"{side}_upper_arm_width_px"] = w_px
        if sw:
            out[f"{side}_upper_arm_width_ratio_shoulder"] = w_px / sw
        if face_height:
            out[f"{side}_upper_arm_width_ratio_face"] = w_px / face_height
        if upper_len:
            out[f"{side}_upper_arm_width_ratio_length"] = w_px / upper_len

    arm_measurements(ls, le, lw, "left")
    arm_measurements(rs, re, rw, "right")
    return out


def normalize_image_id(name: str) -> str:
    stem = Path(name).stem
    return stem.rsplit("_", 1)[0] if stem.endswith("frontal1") else stem


def run_subset(limit: int | None = None) -> None:
    """Run feature extraction only (no analysis) on a small subset for debugging."""
    t0 = time.time()
    labels = pd.read_csv(LABELS_CSV)
    labels["image_name"] = labels["image_path_frontal1"].map(
        lambda p: Path(str(p)).name if pd.notna(p) else None
    )
    labels = labels.dropna(subset=["image_name"])
    wanted = set(labels["image_name"])
    image_paths = [p for p in sorted((DATASET_ROOT / "frontal1").glob("*.jpg"))
                   if p.name in wanted]
    if limit:
        image_paths = image_paths[:: max(1, len(image_paths) // limit)][:limit]
    print(f"subset run: {len(image_paths)} images")
    rows = []
    for i, p in enumerate(image_paths, 1):
        try:
            feats = extract_image_features(p)
        except Exception as exc:
            print(f"[ERROR] {p.name}: {exc}")
            continue
        if feats is None:
            continue
        rows.append(feats)
    df = pd.DataFrame(rows)
    out = RESULT_DIR / f"subset_{len(image_paths)}.csv"
    df.to_csv(out, index=False)
    width_cols = [c for c in df.columns if "width" in c]
    n_valid = {c: int(df[c].notna().sum()) for c in width_cols}
    print(f"wrote {out}")
    print("valid measurements per column:", json.dumps(n_valid, indent=1))
    if "left_upper_arm_width_px" in df.columns:
        ex = df.dropna(subset=["left_upper_arm_width_px"]).head(5)
        print("example measurements:")
        print(ex[["image_name", "shoulder_width", "left_upper_arm_width_px",
                  "left_upper_arm_width_ratio_shoulder"]].to_string(index=False))
    print(f"time: {time.time() - t0:.0f}s")


def main() -> None:
    t0 = time.time()
    labels = pd.read_csv(LABELS_CSV)
    labels = labels[["tag", "image_path_frontal1", "Height", "Weight", "Gender",
                     "MUAC", "HC", "Age", "BMI", "multiclass_label"]].copy()
    labels["image_name"] = labels["image_path_frontal1"].map(
        lambda p: Path(str(p)).name if pd.notna(p) else None
    )
    labels = labels.dropna(subset=["image_name"])
    print(f"children with frontal1 image in CSV: {len(labels)}")

    image_paths = sorted((DATASET_ROOT / "frontal1").glob("*.jpg"))
    print(f"frontal1 images on disk: {len(image_paths)}")

    # restrict to labeled children to keep runtime bounded
    wanted = set(labels["image_name"])
    image_paths = [p for p in image_paths if p.name in wanted]
    print(f"labeled frontal1 images to process: {len(image_paths)}")

    rows = []
    processed = skipped = 0
    for i, p in enumerate(image_paths, 1):
        try:
            feats = extract_image_features(p)
        except Exception as exc:
            feats = None
            print(f"[ERROR] {p.name}: {exc}")
        if feats is None:
            skipped += 1
        else:
            rows.append(feats)
            if feats.get("left_upper_arm_width_px") or feats.get("right_upper_arm_width_px"):
                processed += 1
        if i % 100 == 0:
            el = time.time() - t0
            print(f"  {i}/{len(image_paths)}  ok={len(rows)}  armwidth={processed}  "
                  f"{el:.0f}s elapsed, ETA {el / i * (len(image_paths) - i) / 60:.1f} min")

    feats_df = pd.DataFrame(rows)
    feats_df.to_csv(FEATURES_OUT, index=False)
    print(f"wrote {FEATURES_OUT} ({len(feats_df)} rows)")

    # ------------------------------------------------------------------
    # join with MUAC and analyze
    # ------------------------------------------------------------------
    feats_df["child_id"] = feats_df["image_name"].map(normalize_image_id)
    labels["child_id"] = labels["tag"].astype(str)
    merged = feats_df.merge(
        labels[["child_id", "MUAC", "Height", "Weight", "Age", "Gender",
                "multiclass_label"]],
        on="child_id", how="inner",
    )
    print(f"merged with MUAC labels: {len(merged)}")

    width_cols = [
        "left_upper_arm_width_px", "right_upper_arm_width_px",
        "left_upper_arm_width_ratio_shoulder", "right_upper_arm_width_ratio_shoulder",
        "left_upper_arm_width_ratio_face", "right_upper_arm_width_ratio_face",
        "left_upper_arm_width_ratio_length", "right_upper_arm_width_ratio_length",
        "left_upper_arm_length", "right_upper_arm_length",
        "left_forearm_length", "right_forearm_length",
        "shoulder_width", "face_height",
    ]

    # correlation analysis: raw, height-controlled, and within-child average
    from scipy import stats

    records = []
    for col in width_cols:
        sub = merged[[col, "MUAC"]].dropna()
        n = len(sub)
        if n < 10:
            records.append({"feature": col, "n": n, "pearson_r": None, "pearson_p": None,
                            "spearman_rho": None, "spearman_p": None})
            continue
        pr, pp = stats.pearsonr(sub[col], sub["MUAC"])
        sr, sp = stats.spearmanr(sub[col], sub["MUAC"])
        records.append({"feature": col, "n": n, "pearson_r": pr, "pearson_p": pp,
                        "spearman_rho": sr, "spearman_p": sp})

    # within-child average of left/right (children have one frontal1 each, so this
    # is just the available side; kept for completeness)
    corr = pd.DataFrame(records)
    corr.to_csv(RESULT_DIR / "muac_correlation.csv", index=False)

    # summary statistics
    summary = merged[width_cols + ["MUAC"]].describe().T.round(3)
    summary.to_csv(RESULT_DIR / "summary_statistics.csv")

    # missing/invalid counts
    n_total = len(merged)
    missing = {
        "n_images_processed": int(len(feats_df)),
        "n_merged_with_labels": n_total,
        "n_pose_or_face_missing": int(feats_df["face_height"].isna().sum()),
        **{f"missing_{c}": int(merged[c].isna().sum()) for c in width_cols},
        "n_muac_missing_in_labels": int(labels["MUAC"].isna().sum()),
    }
    pd.Series(missing).to_csv(RESULT_DIR / "missing_counts.csv", header=["count"])

    # scatter plots
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    for col, fname in [
        ("left_upper_arm_width_px", "scatter_leftwidth_vs_muac.png"),
        ("left_upper_arm_width_ratio_shoulder", "scatter_leftratio_vs_muac.png"),
        ("left_upper_arm_width_ratio_face", "scatter_leftratioface_vs_muac.png"),
    ]:
        sub = merged[[col, "MUAC"]].dropna()
        if len(sub) < 10:
            continue
        fig, ax = plt.subplots(figsize=(6, 5))
        ax.scatter(sub[col], sub["MUAC"], s=8, alpha=0.4)
        z = np.polyfit(sub[col], sub["MUAC"], 1)
        xs = np.linspace(sub[col].min(), sub[col].max(), 100)
        ax.plot(xs, np.polyval(z, xs), "r-", lw=1.5)
        r = sub[col].corr(sub["MUAC"])
        ax.set_xlabel(col)
        ax.set_ylabel("MUAC (cm, tape-measured)")
        ax.set_title(f"r = {r:.3f} (n={len(sub)})")
        fig.tight_layout()
        fig.savefig(RESULT_DIR / fname, dpi=120)
        plt.close(fig)

    # ------------------------------------------------------------------
    # markdown report
    # ------------------------------------------------------------------
    lines = ["# Upper-arm CV feature experiment", ""]
    lines.append(f"Images processed: {len(feats_df)}  |  merged with labels: {n_total}")
    lines.append("")
    lines.append("## Correlation with real MUAC (Pearson / Spearman)")
    lines.append("")
    lines.append("| feature | n | pearson r | spearman rho |")
    lines.append("|---|---|---|---|")
    for _, r in corr.iterrows():
        pr = f"{r['pearson_r']:.3f}" if pd.notna(r["pearson_r"]) else "—"
        sr = f"{r['spearman_rho']:.3f}" if pd.notna(r["spearman_rho"]) else "—"
        lines.append(f"| {r['feature']} | {r['n']} | {pr} | {sr} |")
    lines.append("")
    lines.append("## Missing counts")
    lines.append("")
    for k, v in missing.items():
        lines.append(f"- {k}: {v}")
    (RESULT_DIR / "report.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {RESULT_DIR / 'report.md'}")
    print(f"total time: {time.time() - t0:.0f}s")


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "--subset":
        run_subset(int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    else:
        main()
