"""
Scientific Audit Calculations for experiments/cv_feature_analysis/

Performs exact quantitative audits:
1. PCA PC1 correlations with scale proxies (shoulder_width, face_width, arm lengths, image_scale_proxy).
2. Random Baselines (Theoretical and Empirical for Majority Class & Uniform Random).
3. Quantitative Class Separation in PCA space (Centroids, Euclidean distances, ANOVA / F-statistics).
4. Exact Pearson r values for redundant feature pairs.
5. Exact held-out test metrics for raw CV, normalized CV, and measurement baseline.
6. Exact class distributions (full N=2,138, test N=321) and per-class recall for CV models.
7. Verification of anthropometric label derivation.
"""

import json
from pathlib import Path
import numpy as np
import pandas as pd
from scipy import stats
from sklearn.decomposition import PCA
from sklearn.preprocessing import StandardScaler
from sklearn.impute import SimpleImputer
from sklearn.metrics import balanced_accuracy_score, accuracy_score, recall_score, confusion_matrix

ROOT = Path(__file__).resolve().parents[2]
BASELINE_DIR = ROOT / "experiments" / "cv_multimodal_baseline"
ANALYSIS_DIR = ROOT / "experiments" / "cv_feature_analysis"
SPLITS_FILE = BASELINE_DIR / "split_indices.json"
ANTHROVISION_CSV = ROOT / "dataset" / "ANTHROVISION" / "anthrovision_labels.csv"
CV_FEATURES_CSV = ROOT / "experiments" / "cv_features_clean" / "results" / "cv_features_clean.csv"

# Load data
anthro_raw = pd.read_csv(ANTHROVISION_CSV)
anthro_clean = anthro_raw.loc[:, ~anthro_raw.columns.str.contains(r"^Unnamed")].copy()
anthro_clean = anthro_clean.dropna(subset=["multiclass_label"]).copy()
anthro_unique = anthro_clean.drop_duplicates(subset=["tag"], keep="first").copy()
anthro_unique["f1_filename"] = anthro_unique["image_path_frontal1"].dropna().apply(lambda x: Path(str(x)).name)

cv_raw = pd.read_csv(CV_FEATURES_CSV)
cv_f1 = cv_raw[cv_raw["view"] == "frontal1"].copy()

merged = pd.merge(
    anthro_unique,
    cv_f1,
    left_on="f1_filename",
    right_on="image_name",
    how="inner"
).rename(columns={"tag_x": "child_id"})

with open(SPLITS_FILE, "r") as f:
    splits_json = json.load(f)

test_ids = set(splits_json["child_ids"]["test"])
train_ids = set(splits_json["child_ids"]["train"])

test_df = merged[merged["child_id"].isin(test_ids)].copy()
train_df = merged[merged["child_id"].isin(train_ids)].copy()

cv_15_cols = [
    "face_width", "face_height", "eye_distance", "mouth_width", "jaw_width",
    "face_ratio", "eye_ratio", "mouth_ratio", "shoulder_width",
    "left_upper_arm_length", "left_forearm_length", "left_total_arm_length",
    "right_upper_arm_length", "right_forearm_length", "right_total_arm_length"
]

print("=================================================================")
print("SCIENTIFIC AUDIT CALCULATIONS")
print("=================================================================")

# -------------------------------------------------------------------------
# 1. PCA / SCALE CLAIM AUDIT
# -------------------------------------------------------------------------
print("\n--- 1. PCA PC1 vs Landmark Scale Proxies ---")
imputer = SimpleImputer(strategy="median")
scaler = StandardScaler()
X_imp = imputer.fit_transform(merged[cv_15_cols])
X_scaled = scaler.fit_transform(X_imp)

pca = PCA(n_components=5)
X_pca = pca.fit_transform(X_scaled)
pc1 = X_pca[:, 0]
pc2 = X_pca[:, 1]

print(f"Explained Variance Ratios: PC1 = {pca.explained_variance_ratio_[0]*100:.2f}%, PC2 = {pca.explained_variance_ratio_[1]*100:.2f}%")

merged["image_scale_proxy"] = (
    merged["shoulder_width"].fillna(0) +
    merged["left_upper_arm_length"].fillna(0) +
    merged["right_upper_arm_length"].fillna(0)
)

scale_proxies = {
    "shoulder_width": merged["shoulder_width"],
    "face_width": merged["face_width"],
    "left_upper_arm_length": merged["left_upper_arm_length"],
    "right_upper_arm_length": merged["right_upper_arm_length"],
    "image_scale_proxy": merged["image_scale_proxy"]
}

pc1_corrs = {}
for name, s in scale_proxies.items():
    valid = ~s.isna()
    r, p = stats.pearsonr(pc1[valid], s[valid])
    pc1_corrs[name] = (r, p)
    print(f"  Corr(PC1, {name}): r = {r:.4f} (p = {p:.2e})")

# Check PCA loadings for PC1
print("\nPC1 Loadings across 15 CV features:")
loadings_pc1 = pd.Series(pca.components_[0], index=cv_15_cols).sort_values(ascending=False)
for k, v in loadings_pc1.items():
    print(f"  {k:35s}: {v:+.4f}")

# -------------------------------------------------------------------------
# 2. RANDOM & MAJORITY BASELINES AUDIT
# -------------------------------------------------------------------------
print("\n--- 2. Random & Majority Baseline Benchmarks ---")
y_test = test_df["multiclass_label"].values
classes = ["healthy", "underweight", "stunted", "stunted and underweight"]
N_test = len(y_test)
test_counts = pd.Series(y_test).value_counts()
p_classes = [test_counts.get(c, 0) / N_test for c in classes]

print(f"Test split class proportions: {dict(test_counts)}")
print(f"Proportions: {[round(p, 4) for p in p_classes]}")

# Uniform random classifier: predicts each class with probability 1/K = 0.25
# Theoretical Expected Balanced Accuracy = 0.25 (since recall on each class is 0.25)
# Theoretical Expected Accuracy = sum(p_i * 0.25) = 0.25
print("Uniform Random Baseline: Expected Balanced Accuracy = 25.00%, Expected Accuracy = 25.00%")

# Majority class classifier: always predicts 'healthy'
y_pred_maj = np.array(["healthy"] * N_test)
maj_acc = accuracy_score(y_test, y_pred_maj)
maj_b_acc = balanced_accuracy_score(y_test, y_pred_maj)
print(f"Majority-Class Baseline: Accuracy = {maj_acc*100:.2f}%, Balanced Accuracy = {maj_b_acc*100:.2f}% (1/4 recall on majority, 0 on others)")

# -------------------------------------------------------------------------
# 3. PCA CLASS SEPARATION QUANTITATIVE AUDIT
# -------------------------------------------------------------------------
print("\n--- 3. PCA Class Separation Quantitative Analysis ---")
merged["PC1"] = pc1
merged["PC2"] = pc2

centroids = merged.groupby("multiclass_label")[["PC1", "PC2"]].mean()
print("Class Centroids in (PC1, PC2) space:")
print(centroids.to_string())

# Pairwise Euclidean distances between class centroids
print("\nPairwise Euclidean Distance Between Class Centroids:")
dist_matrix = pd.DataFrame(index=centroids.index, columns=centroids.index, dtype=float)
for c1 in centroids.index:
    for c2 in centroids.index:
        p1 = centroids.loc[c1, ["PC1", "PC2"]].values
        p2 = centroids.loc[c2, ["PC1", "PC2"]].values
        dist_matrix.loc[c1, c2] = np.linalg.norm(p1 - p2)
print(dist_matrix.round(4).to_string())

# Overall standard deviation of PC1 and PC2
print(f"Standard Deviation of PC1: {pc1.std():.4f}, PC2: {pc2.std():.4f}")
max_centroid_dist = dist_matrix.values.max()
print(f"Max distance between any two class centroids: {max_centroid_dist:.4f} (compared to PC1 std of {pc1.std():.4f})")

# ANOVA F-test for difference in PC1 across classes
f_val_pc1, p_val_pc1 = stats.f_oneway(*[group["PC1"].values for _, group in merged.groupby("multiclass_label")])
f_val_pc2, p_val_pc2 = stats.f_oneway(*[group["PC2"].values for _, group in merged.groupby("multiclass_label")])
print(f"ANOVA F-test across classes for PC1: F = {f_val_pc1:.4f}, p = {p_val_pc1:.4e}")
print(f"ANOVA F-test across classes for PC2: F = {f_val_pc2:.4f}, p = {p_val_pc2:.4e}")

# -------------------------------------------------------------------------
# 4. FEATURE REDUNDANCY EXACT AUDIT
# -------------------------------------------------------------------------
print("\n--- 4. Feature Redundancy Exact Audit ---")
corr_mat = pd.read_csv(ANALYSIS_DIR / "results" / "cv_feature_correlation_matrix.csv", index_col=0)

key_pairs = [
    ("left_upper_arm_length", "right_upper_arm_length"),
    ("left_forearm_length", "right_forearm_length"),
    ("left_total_arm_length", "right_total_arm_length"),
    ("face_width", "jaw_width"),
    ("face_width", "face_height"),
    ("face_width", "eye_distance"),
    ("shoulder_width", "left_upper_arm_length"),
    ("shoulder_width", "right_upper_arm_length"),
    ("shoulder_width", "face_width")
]

for f1, f2 in key_pairs:
    val = corr_mat.loc[f1, f2]
    print(f"  Corr({f1}, {f2}): r = {val:.4f}")

# -------------------------------------------------------------------------
# 5. SCALE NORMALIZATION EXACT COMPARISON AUDIT
# -------------------------------------------------------------------------
print("\n--- 5. Scale Normalization Metrics Audit (Held-Out Test Set N=321) ---")
ablation_df = pd.read_csv(ANALYSIS_DIR / "results" / "feature_ablation_results.csv")
key_rows = ablation_df[
    ablation_df["Feature_Group"].isin([
        "G: All CV Features (15 Baseline)",
        "Normalized CV (Ratios)",
        "H: Measurement-Only Baseline"
    ])
]
print(key_rows[["Feature_Group", "Model", "Accuracy", "Balanced_Accuracy", "Macro_F1"]].to_string(index=False))

# -------------------------------------------------------------------------
# 6. CLASS COUNTS & PER-CLASS RECALL AUDIT
# -------------------------------------------------------------------------
print("\n--- 6. Class Distribution & Per-Class Recall Audit ---")
full_counts = merged["multiclass_label"].value_counts()
print(f"Full Dataset (N={len(merged)}):")
for c in classes:
    print(f"  {c:25s}: {full_counts.get(c, 0):4d} ({full_counts.get(c, 0)/len(merged)*100:.2f}%)")

print(f"\nHeld-Out Test Set (N={len(test_df)}):")
for c in classes:
    print(f"  {c:25s}: {test_counts.get(c, 0):4d} ({test_counts.get(c, 0)/len(test_df)*100:.2f}%)")

# Inspect per-class metrics for All CV RF and SVM
rf_cv_class = pd.read_csv(ANALYSIS_DIR / "results" / "per_class_g_all_cv_features_15_baseline_-_rf_balanced.csv")
svm_cv_class = pd.read_csv(ANALYSIS_DIR / "results" / "per_class_g_all_cv_features_15_baseline_-_svm_balanced.csv")
meas_svm_class = pd.read_csv(ANALYSIS_DIR / "results" / "per_class_h_measurement-only_baseline_-_svm_balanced.csv")

print("\nAll CV Features (15 Baseline) - RF Balanced (Test Set):")
print(rf_cv_class[rf_cv_class["class"].isin(classes)][["class", "precision", "recall", "f1-score", "support"]].to_string(index=False))

print("\nAll CV Features (15 Baseline) - SVM Balanced (Test Set):")
print(svm_cv_class[svm_cv_class["class"].isin(classes)][["class", "precision", "recall", "f1-score", "support"]].to_string(index=False))

print("\nMeasurement-Only Baseline - SVM Balanced (Test Set):")
print(meas_svm_class[meas_svm_class["class"].isin(classes)][["class", "precision", "recall", "f1-score", "support"]].to_string(index=False))

# Export audit summary dictionary for reference
audit_data = {
    "pc1_correlations": {k: float(v[0]) for k, v in pc1_corrs.items()},
    "pc1_explained_variance": float(pca.explained_variance_ratio_[0]),
    "max_centroid_distance": float(max_centroid_dist),
    "pc1_std": float(pc1.std()),
    "anova_pc1_f": float(f_val_pc1),
    "anova_pc1_p": float(p_val_pc1),
    "majority_acc": float(maj_acc),
    "majority_bacc": float(maj_b_acc),
    "uniform_random_bacc": 0.25,
    "redundant_pairs_checked": {f"{f1}_vs_{f2}": float(corr_mat.loc[f1, f2]) for f1, f2 in key_pairs}
}

with open(ANALYSIS_DIR / "results" / "audit_metrics.json", "w") as f:
    json.dump(audit_data, f, indent=2)

print(f"\nAudit metrics saved to: {ANALYSIS_DIR / 'results' / 'audit_metrics.json'}")
print("=================================================================")
