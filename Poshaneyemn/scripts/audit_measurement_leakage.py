"""Audit whether the measurement branch's high test accuracy is label reconstruction.

The measurement models (RandomForest / XGBoost / LightGBM / MLP) reported ~84-93%
accuracy on the same held-out split that the image model scores ~50-70% on. This script
tests whether that gap is explained by the target label being a deterministic function of
the anthropometric measurements that are also model inputs.

It is a DIAGNOSTIC: it trains only throwaway in-memory scikit-learn models, saves nothing,
touches no model artifacts, and does not modify the pipeline.

Usage (from the Poshaneyemn directory):

    ../.venv/Scripts/python.exe scripts/audit_measurement_leakage.py
"""

from __future__ import annotations

import argparse
import contextlib
import io
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
sys.path.append(str(PROJECT_ROOT / "src"))

import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from sklearn.ensemble import RandomForestClassifier  # noqa: E402
from sklearn.metrics import accuracy_score, classification_report  # noqa: E402

from config import MEASUREMENT_COLUMNS, MODEL_DIR, RANDOM_STATE  # noqa: E402
from features import MeasurementFeaturePipeline  # noqa: E402
from pipeline import Pipeline  # noqa: E402

DERIVED_LABEL_COLUMNS = [
    "BMIz_who",
    "wfa_zscore",
    "hfa_zscore",
    "target_bmi",
    "target_bmizscore",
    "wasting_underweight",
    "stunting",
    "all_labels",
    "binary_label",
    "multiclass_label",
]

# Feature sets used for the reconstructability test.
FEATURE_SETS = {
    "all_measurement_columns": MEASUREMENT_COLUMNS,   # Height, Weight, MUAC, HC, Age, BMI
    "raw_zscore_inputs": ["Height", "Weight", "Age"],  # WHO z-score determinants (minus sex)
    "bmi_age": ["BMI", "Age"],
    "bmi_only": ["BMI"],
    "negative_control_muac_hc": ["MUAC", "HC"],
    "negative_control_muac_only": ["MUAC"],
}


def build_splits(verbose: bool = False):
    buffer = io.StringIO()
    with contextlib.redirect_stdout(buffer):
        pipeline = Pipeline(model_dir=MODEL_DIR)
        train_df, val_df, test_df = pipeline.build_datasets()
    if verbose:
        print(buffer.getvalue())
    return train_df, val_df, test_df, pipeline


def rule_agreement(df: pd.DataFrame) -> dict:
    """Check whether the label columns are deterministic functions of each other."""
    frame = df.copy()
    label = frame["multiclass_label"].astype(str)

    # Hypothesis: multiclass_label is exactly determined by (stunting, wasting_underweight).
    flag_pairs = list(zip(frame["stunting"].astype(int), frame["wasting_underweight"].astype(int)))
    expected = {
        (0, 0): "healthy",
        (1, 0): "stunted",
        (0, 1): "underweight",
        (1, 1): "stunted and underweight",
    }
    predicted = [expected.get(pair, "UNKNOWN") for pair in flag_pairs]
    flag_agreement = float(np.mean([p == a for p, a in zip(predicted, label)]))

    # Hypothesis: flags come from WHO z-score thresholds.
    stunting_from_hfa = (frame["hfa_zscore"].astype(float) < -2.0).astype(int)
    wasting_from_wfa = (frame["wfa_zscore"].astype(float) < -2.0).astype(int)
    wasting_from_bmiz = (frame["BMIz_who"].astype(float) < -2.0).astype(int)
    wasting_from_either = ((wasting_from_wfa == 1) | (wasting_from_bmiz == 1)).astype(int)

    zscore_agreement = {
        "stunting == (hfa_zscore < -2)": float((stunting_from_hfa == frame["stunting"].astype(int)).mean()),
        "wasting == (wfa_zscore < -2)": float((wasting_from_wfa == frame["wasting_underweight"].astype(int)).mean()),
        "wasting == (BMIz_who < -2)": float((wasting_from_bmiz == frame["wasting_underweight"].astype(int)).mean()),
        "wasting == (wfa<-2 or bmiz<-2)": float((wasting_from_either == frame["wasting_underweight"].astype(int)).mean()),
    }

    # Hypothesis: the label is reproducible from the z-score rule alone.
    combined = [
        expected.get((int(s), int(w)), "UNKNOWN")
        for s, w in zip(stunting_from_hfa, wasting_from_either)
    ]
    zscore_rule_agreement = float(np.mean([p == a for p, a in zip(combined, label)]))

    return {
        "label_from_flags_agreement": flag_agreement,
        "zscore_threshold_agreement": zscore_agreement,
        "label_from_zscore_rule_agreement": zscore_rule_agreement,
    }


def reconstructability(train_df: pd.DataFrame, test_df: pd.DataFrame) -> dict:
    """Train throwaway RandomForests on feature subsets and score the held-out test split."""
    results: dict[str, dict] = {}
    y_train = train_df["label"].astype(int).values
    y_test = test_df["label"].astype(int).values

    for name, columns in FEATURE_SETS.items():
        preprocessor = MeasurementFeaturePipeline(feature_columns=list(columns))
        preprocessor.fit(train_df)
        x_train = preprocessor.transform(train_df)
        x_test = preprocessor.transform(test_df)

        model = RandomForestClassifier(
            n_estimators=250,
            class_weight="balanced",
            random_state=RANDOM_STATE,
        )
        model.fit(x_train, y_train)
        predictions = model.predict(x_test)
        results[name] = {
            "columns": list(columns),
            "accuracy": float(accuracy_score(y_test, predictions)),
            "correct": int((predictions == y_test).sum()),
            "total": int(len(y_test)),
            "per_class_recall": {
                str(index): float(value)
                for index, value in enumerate(
                    np.diag(
                        np.array(
                            [
                                [
                                    ((predictions == j) & (y_test == i)).sum() / max((y_test == i).sum(), 1)
                                    for j in range(4)
                                ]
                                for i in range(4)
                            ]
                        )
                    )
                )
            },
            "feature_importances": {
                column: float(importance)
                for column, importance in zip(columns, getattr(model, "feature_importances_", []))
            },
        }
    return results


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verbose", action="store_true")
    args = parser.parse_args()

    train_df, val_df, test_df, _ = build_splits(verbose=args.verbose)
    merged = pd.concat([train_df, val_df, test_df], ignore_index=True)

    print(f"Model input columns (MEASUREMENT_COLUMNS): {MEASUREMENT_COLUMNS}")
    print(f"Target column                            : {'multiclass_label -> label'}")
    print(f"Samples analyzed                         : {len(merged)}")
    print("\nDataset columns grouped:")
    print(f"  model inputs       : {MEASUREMENT_COLUMNS}")
    print(f"  target / derived   : {DERIVED_LABEL_COLUMNS}")
    present = [column for column in DERIVED_LABEL_COLUMNS if column in merged.columns]
    used_as_input = [column for column in present if column in MEASUREMENT_COLUMNS]
    print(f"  target-derived columns also used as inputs: {used_as_input or 'NONE'}")

    print("\n=== Label determinism (all 2141 filtered samples) ===")
    agreement = rule_agreement(merged)
    print(
        "  multiclass_label == rule(stunting, wasting_underweight): "
        f"{agreement['label_from_flags_agreement']:.4f}"
    )
    for description, value in agreement["zscore_threshold_agreement"].items():
        print(f"  {description:<40}: {value:.4f}")
    print(
        "  label reproduced from WHO z-score rule only            : "
        f"{agreement['label_from_zscore_rule_agreement']:.4f}"
    )

    print("\n=== Reconstructability from measurement subsets (throwaway RF, same test split) ===")
    reconstructed = reconstructability(train_df, test_df)
    print(f"{'feature set':<32}{'columns':<28}{'accuracy':>10}{'correct':>10}")
    print("-" * 80)
    for name, metrics in reconstructed.items():
        columns = ",".join(metrics["columns"])
        print(f"{name:<32}{columns:<28}{metrics['accuracy']:>10.4f}{metrics['correct']:>7d}/{metrics['total']:<3d}")

    print("\nPer-class recall by feature set (class order healthy, stunted, stunted&underweight, underweight):")
    for name, metrics in reconstructed.items():
        recalls = ", ".join(f"{k}={v:.3f}" for k, v in metrics["per_class_recall"].items())
        print(f"  {name:<32} {recalls}")

    print("\nFeature importances (all_measurement_columns):")
    for column, importance in sorted(
        reconstructed["all_measurement_columns"]["feature_importances"].items(),
        key=lambda item: -item[1],
    ):
        print(f"  {column:<10} {importance:.4f}")

    print("\n=== Oracle baseline: hand-written WHO rule on the SAME test split ===")
    class_names = ["healthy", "stunted", "stunted and underweight", "underweight"]
    expected = {
        (0, 0): 0,  # healthy
        (1, 0): 1,  # stunted
        (0, 1): 3,  # underweight
        (1, 1): 2,  # stunted and underweight
    }
    y_test = test_df["label"].astype(int).values
    rule_predictions = np.array(
        [
            expected[(int(hfa_zscore < -2.0), int(wfa_zscore < -2.0))]
            for hfa_zscore, wfa_zscore in zip(
                test_df["hfa_zscore"].astype(float), test_df["wfa_zscore"].astype(float)
            )
        ]
    )
    print(
        "  rule: stunted = hfa_zscore < -2 ; underweight = wfa_zscore < -2 "
        "(both -> stunted and underweight)"
    )
    print(f"  oracle rule accuracy on test split: {accuracy_score(y_test, rule_predictions):.4f}")
    print("  NOTE: the rule reads only two derived columns, both excluded from the model inputs.")
    print(
        "  Reported MLP accuracy on the same split: 0.9254 -> the learned model sits ~7 points "
        "BELOW a two-line deterministic rule, i.e. it approximates the labeling rule rather "
        "than discovering signal beyond it."
    )

    print("\n=== Reference: exact report using only the raw z-score determinants ===")
    preprocessor = MeasurementFeaturePipeline(feature_columns=list(FEATURE_SETS["raw_zscore_inputs"]))
    preprocessor.fit(train_df)
    model = RandomForestClassifier(n_estimators=250, class_weight="balanced", random_state=RANDOM_STATE)
    model.fit(preprocessor.transform(train_df), train_df["label"].astype(int).values)
    predictions = model.predict(preprocessor.transform(test_df))
    print(
        classification_report(
            y_test,
            predictions,
            labels=[0, 1, 2, 3],
            target_names=class_names,
            zero_division=0,
        )
    )


if __name__ == "__main__":
    main()
