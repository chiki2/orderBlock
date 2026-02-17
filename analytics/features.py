"""
features.py
===========
Feature engineering for the ICT Order Block model.
Input : tidy DataFrame from parse_ob_data.py  (one row per OB)
Output: (X, y) arrays ready for scikit-learn, plus a feature-name list.

All features are derived purely from the DETECTED-event snapshot so that
predictions can be made at detection time (before any filter runs).
"""

import numpy as np
import pandas as pd


# Point value for XAUUSD: 1 point = $0.01 (1 pip = 10 points for Gold)
# Passed as parameter so the pipeline works for other symbols too.
POINT_DEFAULT = 0.01


def engineer(df: pd.DataFrame, point: float = POINT_DEFAULT) -> pd.DataFrame:
    """
    Add engineered columns to *df* in-place and return it.
    Operates only on columns that are present; missing ones get NaN.
    """
    d = df.copy()

    # ── OB geometry ──────────────────────────────────────────────────────────
    d["ob_size_pips"] = (d["high_price"] - d["low_price"]).abs() / point
    d["ob_size_pips"] = d["ob_size_pips"].replace(0, np.nan)

    wick_body = (d["ob_body"] - d["ob_wick"]).abs()
    d["ob_body_pct"]   = wick_body / (d["ob_size_pips"] * point).replace(0, np.nan)
    d["ob_wick_ratio"] = 1.0 - d["ob_body_pct"]

    # ── ATR ratios ───────────────────────────────────────────────────────────
    atr_pips = d["atr"] / point
    d["atr_pips"]      = atr_pips
    d["atr_ratio"]     = d["ob_size_pips"] / atr_pips.replace(0, np.nan)
    d["spread_cost"]   = d["spread"] / d["ob_size_pips"].replace(0, np.nan)

    # ── SL / TP distance at detection time ──────────────────────────────────
    d["sl_dist_pips"]  = (d["entry_price"] - d["stop_loss"]).abs() / point
    d["tp_dist_pips"]  = (d["take_profit"] - d["entry_price"]).abs() / point
    d["rr_setup"]      = d["tp_dist_pips"] / d["sl_dist_pips"].replace(0, np.nan)

    # ── Candle structure (c2 = impulse candle that created the OB) ──────────
    c2_range = (d["c2_high"] - d["c2_low"]).abs().replace(0, np.nan)
    d["c2_body_size"]     = (d["c2_close"] - d["c2_open"]).abs()
    d["c2_body_pct"]      = d["c2_body_size"] / c2_range
    # Where did the candle close within its range?  0=at low, 1=at high
    d["c2_close_pos"]     = (d["c2_close"] - d["c2_low"]) / c2_range
    # How big is the impulse relative to ATR?
    d["c2_atr_ratio"]     = d["c2_body_size"] / d["atr"].replace(0, np.nan)

    # ── HTF trend alignment ──────────────────────────────────────────────────
    # is_bear=0 → bullish OB; htf_trend="BULLISH" → trend-aligned
    def trend_aligned(row):
        trend = str(row.get("htf_trend", "")).upper()
        is_bear = bool(row.get("is_bear", False))
        if trend == "BULLISH" and not is_bear:
            return 1
        if trend == "BEARISH" and is_bear:
            return 1
        if trend == "RANGE":
            return 0
        return -1   # counter-trend

    d["htf_aligned"] = d.apply(trend_aligned, axis=1)

    # ── Time-of-day features ─────────────────────────────────────────────────
    if "ob_start_time" in d.columns:
        ts = pd.to_datetime(d["ob_start_time"], errors="coerce")
        d["hour_of_day"] = ts.dt.hour
        d["day_of_week"] = ts.dt.dayofweek   # 0=Mon … 4=Fri

        # ICT sessions (UTC): London 07-16, NY 13-21, Asia 22-06
        d["is_london"]   = d["hour_of_day"].between(7, 15).astype(int)
        d["is_ny"]        = d["hour_of_day"].between(13, 20).astype(int)
        d["is_asia"]      = ((d["hour_of_day"] >= 22) | (d["hour_of_day"] < 7)).astype(int)

    # ── FVG / imbalance ──────────────────────────────────────────────────────
    d["fvg_dist_pips"] = d["imbalanced_dist"].abs() / point

    # ── Fibonacci level distances at detection ───────────────────────────────
    for fib_col in ["fib50", "fib80", "fib100", "fib127", "fib1618"]:
        if fib_col in d.columns:
            dist_col = f"{fib_col}_dist_pips"
            d[dist_col] = (d[fib_col] - d["entry_price"]).abs() / point

    # ── Boolean flags (ensure numeric) ──────────────────────────────────────
    for c in ["is_mss", "is_bos", "has_choch", "is_imbalanced",
              "fvg_filled", "lssc_valid", "has_sweep_before",
              "top_imp_valid", "is_lower_mss", "all_checks"]:
        if c in d.columns:
            d[c] = d[c].astype(float)

    return d


# Columns to use as model features (all must be numeric after engineer())
FEATURE_COLS = [
    # OB geometry
    "ob_size_pips", "ob_body_pct", "ob_wick_ratio",
    # ATR context
    "atr_ratio", "spread_cost",
    # Trade setup
    "sl_dist_pips", "rr_setup",
    # Impulse candle
    "c2_body_pct", "c2_close_pos", "c2_atr_ratio",
    # Trend
    "htf_aligned",
    # Time
    "hour_of_day", "day_of_week", "is_london", "is_ny", "is_asia",
    # ICT structure
    "is_mss", "is_bos", "has_choch",
    "fvg_dist_pips", "is_imbalanced",
    "lssc_valid", "has_sweep_before",
    "top_imp_valid",
    # Stars (confidence score assigned by EA)
    "stars",
    # Filter stage reached
    "n_filtered_ticks",
]


def build_matrices(df: pd.DataFrame, point: float = POINT_DEFAULT):
    """
    Return (X, y, feature_names) for the traded OBs (label not null).
    Drops rows with all-NaN features.
    """
    enriched = engineer(df, point=point)

    # Only keep OBs that were actually traded (have a definitive label)
    traded = enriched[enriched["label"].notna()].copy()

    available = [c for c in FEATURE_COLS if c in traded.columns]
    X = traded[available].astype(float)
    y = traded["label"].astype(int)

    # Drop rows where every feature is NaN
    valid = X.notna().any(axis=1)
    X, y = X[valid], y[valid]

    print(f"Feature matrix: {X.shape[0]} samples × {X.shape[1]} features")
    print(f"Class balance: {y.value_counts().to_dict()}")

    return X, y, available
