"""
model.py
========
Train a Random Forest classifier on traded OB data and produce:
  - SHAP feature importance plot  (feature_importance.png)
  - Classification report          (classification_report.txt)
  - Missed-OB analysis             (missed_obs_analysis.csv)
  - Saved model                    (ob_model.pkl)

Usage
-----
    python model.py --input parsed_obs.csv [--point 0.01] [--output-dir .]
"""

import argparse
import pickle
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")   # headless
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import shap
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import (
    classification_report,
    roc_auc_score,
)
from sklearn.model_selection import cross_val_predict, StratifiedKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

from features import build_matrices, engineer, FEATURE_COLS, POINT_DEFAULT


# ── Helpers ───────────────────────────────────────────────────────────────────

def build_pipeline() -> Pipeline:
    return Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("scaler",  StandardScaler()),
        ("rf", RandomForestClassifier(
            n_estimators=300,
            max_depth=None,
            min_samples_leaf=3,
            class_weight="balanced",
            random_state=42,
            n_jobs=-1,
        )),
    ])


def cross_validate_report(pipe: Pipeline, X: pd.DataFrame, y: pd.Series,
                           n_splits: int = 5) -> str:
    cv = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=42)
    y_pred = cross_val_predict(pipe, X, y, cv=cv)
    y_prob = cross_val_predict(pipe, X, y, cv=cv, method="predict_proba")[:, 1]

    report = classification_report(y, y_pred, target_names=["LOSS/EXPIRED", "WIN"])
    try:
        auc = roc_auc_score(y, y_prob)
        report += f"\nROC-AUC (cross-val): {auc:.4f}\n"
    except Exception:
        pass
    report += f"\nSamples: {len(y)} | Folds: {n_splits}\n"
    return report


def shap_importance_plot(pipe: Pipeline, X: pd.DataFrame, y: pd.Series,
                          feature_names: list, out_path: Path):
    """Train on full data, compute SHAP, save bar chart."""
    pipe.fit(X, y)
    rf = pipe.named_steps["rf"]

    # SHAP on transformed data
    X_transformed = pipe[:-1].transform(X)   # imputer + scaler only
    explainer = shap.TreeExplainer(rf)
    shap_values = explainer.shap_values(X_transformed)

    # shap_values may be:
    #   list  → one array per class (old SHAP ≤0.44)
    #   3-D ndarray (n_samples, n_features, n_classes) → new SHAP ≥0.45
    #   2-D ndarray (n_samples, n_features) → regression / single-output
    # Always use class-1 (WIN) slice.
    sv = np.array(shap_values)
    if sv.ndim == 3:          # (samples, features, classes)
        sv = sv[:, :, 1]
    elif sv.ndim == 1 and isinstance(shap_values, list):
        sv = np.array(shap_values[1])  # old-style list

    mean_abs = np.abs(sv).mean(axis=0)
    order    = np.argsort(mean_abs)[::-1].astype(int)
    feat_arr = np.array(feature_names)

    fig, ax = plt.subplots(figsize=(10, max(6, len(feature_names) * 0.35)))
    bars = ax.barh(  # noqa: F841
        feat_arr[order][::-1],
        mean_abs[order][::-1],
        color="steelblue",
    )
    ax.set_xlabel("Mean |SHAP value|")
    ax.set_title("ICT Order Block — Feature Importance (SHAP)\nHigher = more influence on WIN prediction")
    plt.tight_layout()
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    print(f"Feature importance plot saved: {out_path}")

    # Return top-10 as text summary
    summary_lines = ["Top features by SHAP importance:"]
    for rank, idx in enumerate(order[:10], 1):
        summary_lines.append(f"  {rank:2d}. {feat_arr[idx]:<30s}  {mean_abs[idx]:.4f}")
    return "\n".join(summary_lines)


def missed_obs_analysis(df: pd.DataFrame, pipe: Pipeline,
                         feature_names: list, point: float,
                         out_path: Path):
    """
    Apply the trained model to the MISSED (MISS) OBs to estimate
    which ones the model would have classified as WIN.
    Saves a ranked CSV.
    """
    missed = df[df["outcome_str"] == "MISS"].copy()
    if missed.empty:
        print("No missed OBs found in dataset — skipping missed analysis.")
        return

    enriched = engineer(missed, point=point)
    available = [c for c in feature_names if c in enriched.columns]
    X_miss = enriched[available].astype(float).replace([np.inf, -np.inf], np.nan)
    # Also replace values that overflow float32 (e.g. fvg_dist_pips = 8e164)
    _f32max = np.finfo(np.float32).max
    X_miss = X_miss.where(X_miss.abs() <= _f32max, np.nan)

    prob_win = pipe.predict_proba(X_miss)[:, 1]
    missed = missed.copy()
    missed["prob_win"] = prob_win
    missed_sorted = missed.sort_values("prob_win", ascending=False)
    missed_sorted.to_csv(out_path, index=False)
    print(f"Missed-OB analysis saved: {out_path}  ({len(missed_sorted)} rows)")
    print(f"  Top missed OBs (p_win > 0.7): {(prob_win > 0.7).sum()}")


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Train RF model on OB lifecycle data")
    parser.add_argument("--input",      required=True,           help="parsed_obs.csv from parse_ob_data.py")
    parser.add_argument("--point",      type=float, default=POINT_DEFAULT, help="Tick point value (default 0.01 for Gold)")
    parser.add_argument("--output-dir", default=".",             help="Directory for output files")
    args = parser.parse_args()

    in_path  = Path(args.input)
    out_dir  = Path(args.output_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    if not in_path.exists():
        print(f"ERROR: {in_path} not found", file=sys.stderr)
        sys.exit(1)

    print(f"Loading {in_path} ...")
    df = pd.read_csv(in_path, parse_dates=["export_time", "ob_start_time"])

    X, y, feature_names = build_matrices(df, point=args.point)

    if len(y) < 10:
        print(f"ERROR: Only {len(y)} labeled samples — need at least 10 to train.")
        print("Run more backtests to accumulate data and try again.")
        sys.exit(1)

    if y.nunique() < 2:
        print("ERROR: Only one class in labels (all WIN or all LOSS). "
              "Cannot train a binary classifier.")
        sys.exit(1)

    # ── Cross-validated evaluation ────────────────────────────────────────────
    print("\nCross-validating (StratifiedKFold k=5) ...")
    pipe = build_pipeline()
    report_text = cross_validate_report(pipe, X, y)
    print(report_text)

    report_path = out_dir / "classification_report.txt"
    report_path.write_text(report_text)
    print(f"Classification report saved: {report_path}")

    # ── Full-data fit + SHAP ──────────────────────────────────────────────────
    print("\nFitting full model and computing SHAP values ...")
    pipe2 = build_pipeline()
    shap_summary = shap_importance_plot(
        pipe2, X, y, feature_names,
        out_path=out_dir / "feature_importance.png",
    )
    print(shap_summary)

    # Append SHAP summary to report
    with open(report_path, "a") as f:
        f.write("\n" + shap_summary + "\n")

    # ── Save model ────────────────────────────────────────────────────────────
    model_path = out_dir / "ob_model.pkl"
    with open(model_path, "wb") as f:
        pickle.dump(pipe2, f)
    print(f"\nModel saved: {model_path}")

    # ── Missed-OB analysis ────────────────────────────────────────────────────
    print("\nAnalysing missed OBs ...")
    missed_obs_analysis(
        df, pipe2, feature_names, args.point,
        out_path=out_dir / "missed_obs_analysis.csv",
    )

    print("\nDone. Outputs:")
    for p in sorted(out_dir.glob("*")):
        print(f"  {p.name}")


if __name__ == "__main__":
    main()
