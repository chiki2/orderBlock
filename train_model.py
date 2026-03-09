#!/usr/bin/env python3
"""
train_model.py — train an ICT order-block classifier

Pipeline
    1.  Load ob_dataset.csv (all detected OBs)
    2.  Encode categoricals, impute missing values
    3.  Train a Random Forest with class_weight='balanced' (handles imbalance)
    4.  Report: CV accuracy, precision/recall, feature importances
    5.  Save model → ob_model.pkl
    6.  Print minimum-samples warning if positives < 50

Usage:
    python3 train_model.py                # full dataset
    python3 train_model.py --traded-only  # only OBs where an order was placed
    python3 train_model.py --dataset ob_dataset.csv --mode 3class
"""

import csv, argparse, math, os, pickle, sys
from pathlib import Path
from collections import Counter

BASE = Path("/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock")

# ── features used for training ──────────────────────────────────────────────

# Features available at OB birth / after full filter pipeline (no leakage)
DETECT_FEATS = [
    "is_bear",
    "htf_trend",           # -1/0/1 (BEARISH/RANGE/BULLISH)
    "htf_bull", "htf_bear", "align_with_trend",
    "stars",
    "ob_body_pct", "ob_range_pts", "ob_body", "ob_wick",
    # filter flags — reflect final state from CLOSED row
    "is_mss", "is_bos", "has_choch",
    "is_imbalanced",
    "lssc_valid", "has_sweep_before",
    "top_imp_valid", "is_lower_mss", "all_checks", "final_check",
    # market snapshot from DETECTED row
    "atr",
    "c1_open", "c1_high", "c1_low", "c1_close",
    "c2_open", "c2_high", "c2_low", "c2_close",
    # time features
    "hour_utc", "day_of_week", "month",
]

# Features only available after order is placed (use in --traded-only mode)
TRADE_FEATS = [
    "sl_dist_pts", "tp_dist_pts", "rr_ratio",
    "lot_size",
]

NUMERIC_FEATS = DETECT_FEATS  # default: no leakage

def safe_float(v, default=0.0):
    try:
        f = float(v)
        if math.isnan(f) or math.isinf(f) or abs(f) > 1e12:
            return default
        return f
    except (ValueError, TypeError):
        return default

def load_dataset(path, traded_only=False):
    X, y, names = [], [], []
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            if traded_only and int(safe_float(row.get("traded", 0))) == 0:
                continue
            feats = [safe_float(row.get(f, 0)) for f in NUMERIC_FEATS]
            label = int(safe_float(row.get("label", 0)))
            X.append(feats)
            y.append(label)
            names.append(row.get("ob_name", ""))
    return X, y, names

def run_cv(X, y, n_splits=5):
    """Stratified K-fold cross-validation."""
    try:
        from sklearn.ensemble import RandomForestClassifier
        from sklearn.model_selection import StratifiedKFold, cross_validate
        from sklearn.metrics import make_scorer, precision_score, recall_score, f1_score
    except ImportError:
        print("  [SKIP] sklearn not installed — pip install scikit-learn")
        return None

    clf = RandomForestClassifier(
        n_estimators=300,
        max_depth=None,
        min_samples_leaf=2,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )
    cv = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=42)
    scoring = {
        "accuracy":  "accuracy",
        "precision": make_scorer(precision_score, zero_division=0),
        "recall":    make_scorer(recall_score,    zero_division=0),
        "f1":        make_scorer(f1_score,        zero_division=0),
        "roc_auc":   "roc_auc",
    }
    results = cross_validate(clf, X, y, cv=cv, scoring=scoring)
    return results

def print_cv(results):
    if results is None:
        return
    for metric, key in [("Accuracy", "test_accuracy"), ("Precision", "test_precision"),
                        ("Recall",   "test_recall"),   ("F1",        "test_f1"),
                        ("ROC-AUC",  "test_roc_auc")]:
        vals = results[key]
        print(f"  {metric:12s}: {sum(vals)/len(vals):.4f}  (std {(sum((v-sum(vals)/len(vals))**2 for v in vals)/len(vals))**0.5:.4f})")

def train_final(X, y):
    """Train on all data and return fitted model + importances."""
    try:
        from sklearn.ensemble import RandomForestClassifier
        from sklearn.preprocessing import StandardScaler
        from sklearn.pipeline import Pipeline
    except ImportError:
        return None, None

    clf = RandomForestClassifier(
        n_estimators=500,
        max_depth=None,
        min_samples_leaf=1,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )
    clf.fit(X, y)

    importances = sorted(
        zip(NUMERIC_FEATS, clf.feature_importances_),
        key=lambda x: -x[1]
    )
    return clf, importances

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dataset",      default=str(BASE / "ob_dataset.csv"))
    ap.add_argument("--traded-only",  action="store_true",
                    help="train only on OBs where an order was placed")
    ap.add_argument("--mode",         default="binary",
                    choices=["binary", "3class"],
                    help="binary=WIN vs all,  3class=WIN/LOSS/NO_TRADE")
    ap.add_argument("--no-cv",        action="store_true")
    ap.add_argument("--out",          default=str(BASE / "ob_model.pkl"))
    args = ap.parse_args()

    if not os.path.exists(args.dataset):
        print(f"ERROR: dataset not found: {args.dataset}")
        print("Run  python3 build_dataset.py  first.")
        sys.exit(1)

    # In traded-only mode add trade-level features (no leakage since all rows have them)
    global NUMERIC_FEATS
    if args.traded_only:
        NUMERIC_FEATS = DETECT_FEATS + TRADE_FEATS

    print(f"Loading: {args.dataset}")
    X, y, names = load_dataset(args.dataset, traded_only=args.traded_only)
    counts = Counter(y)
    print(f"Samples: {len(X):,}  |  class distribution: {dict(counts)}")

    positives = counts.get(1, 0)
    if positives == 0:
        print("\nERROR: no positive (WIN) samples found — cannot train.")
        sys.exit(1)

    if positives < 50:
        print(f"\n⚠  WARNING: only {positives} WIN samples — model will be unreliable.")
        print("   To improve: run backtests on more symbols / date ranges and merge CSVs:")
        print("   python3 build_dataset.py --glob '/path/to/tester/*/MQL5/Files/ob_data_*.csv'")
        print("   A minimum of 50–200 positive examples is recommended.\n")

    # ── cross-validation ──────────────────────────────────────────────────
    n_splits = min(5, positives)   # can't have more folds than positive samples
    if not args.no_cv and n_splits >= 2:
        print(f"\n--- {n_splits}-fold stratified cross-validation ---")
        results = run_cv(X, y, n_splits=n_splits)
        print_cv(results)
    else:
        print("\n[CV skipped — too few positive samples]")

    # ── final model ───────────────────────────────────────────────────────
    print("\n--- Training final model on full dataset ---")
    clf, importances = train_final(X, y)
    if clf is None:
        print("sklearn not available — skipping model save.")
        return

    # ── feature importances ───────────────────────────────────────────────
    print("\n--- Top-15 feature importances ---")
    for name, imp in importances[:15]:
        bar = "█" * int(imp * 50)
        print(f"  {name:25s} {imp:.4f}  {bar}")

    # ── save ──────────────────────────────────────────────────────────────
    model_bundle = {
        "model":    clf,
        "features": NUMERIC_FEATS,
        "classes":  [0, 1],
        "n_train":  len(X),
        "n_wins":   positives,
    }
    with open(args.out, "wb") as fh:
        pickle.dump(model_bundle, fh)
    print(f"\nModel saved → {args.out}")

    # ── prediction helper hint ────────────────────────────────────────────
    print("""
--- How to predict on new OBs ---
import pickle, csv
bundle = pickle.load(open('ob_model.pkl','rb'))
clf    = bundle['model']
feats  = bundle['features']

# feats_row = dict with all feature values
row_vec = [[float(feats_row.get(f, 0)) for f in feats]]
proba   = clf.predict_proba(row_vec)[0][1]  # P(WIN)
print(f"P(WIN) = {proba:.3f}")
""")

if __name__ == "__main__":
    main()
