"""
parse_ob_data.py
================
Load the OB lifecycle CSV exported by exportOB.mqh, join each OB's
DETECTED-event features with its final outcome (CLOSED_WIN / CLOSED_LOSS /
EXPIRED / MITIGATED), and emit a tidy one-row-per-OB DataFrame.

Usage
-----
    python parse_ob_data.py --input ob_data_XAUUSD_PERIOD_H1_20250101.csv \
                            --output parsed_obs.csv

The output CSV is consumed by model.py.
"""

import argparse
import sys
from pathlib import Path

import pandas as pd
import numpy as np


# ── Column dtype map ──────────────────────────────────────────────────────────
BOOL_COLS = [
    "is_bear", "is_mss", "is_bos", "has_choch",
    "is_imbalanced", "fvg_filled", "lssc_valid", "has_sweep_before",
    "top_imp_valid", "is_lower_mss", "all_checks",
]
FLOAT_COLS = [
    "high_price", "low_price", "ob_body", "ob_wick",
    "mss_level", "imbalanced_dist", "imbalance_price",
    "fib50", "fib80", "fib100", "fib127", "fib1618",
    "top_imp_level",
    "entry_price", "stop_loss", "take_profit", "lot_size",
    "c1_open", "c1_high", "c1_low", "c1_close",
    "c2_open", "c2_high", "c2_low", "c2_close",
    "atr", "bid", "ask", "r_multiple",
]
INT_COLS = ["stars", "reason", "final_check", "spread"]


def load_raw(path: Path) -> pd.DataFrame:
    df = pd.read_csv(path, parse_dates=["export_time", "ob_start_time"])
    # Normalise column names
    df.columns = df.columns.str.strip().str.lower()
    for c in BOOL_COLS:
        if c in df.columns:
            df[c] = df[c].astype(bool)
    for c in FLOAT_COLS:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce")
    for c in INT_COLS:
        if c in df.columns:
            df[c] = pd.to_numeric(df[c], errors="coerce").astype("Int64")
    return df


# Structural flags set in the tick loop — always 0 in the DETECTED snapshot.
# We overlay these from the CLOSED event which captures the OB's final state.
STRUCTURAL_OVERLAY_COLS = [
    "is_mss", "is_imbalanced", "imbalanced_dist", "imbalance_price", "fvg_filled",
    "lssc_valid", "has_sweep_before", "top_imp_valid", "top_imp_level",
    "is_lower_mss", "all_checks", "final_check", "stars", "reason", "mss_level",
]


def join_lifecycle(df: pd.DataFrame) -> pd.DataFrame:
    """
    Group by (ob_name, symbol, timeframe).

    Feature strategy:
      - Geometry / candle / time features  →  from the DETECTED snapshot
        (captures the OB shape at the moment of creation, before filters run)
      - Structural confirmation flags       →  from the CLOSED snapshot
        (is_mss, is_imbalanced, stars, etc. are set in the tick loop and are
        always 0 in the DETECTED row; the CLOSED row holds the final state)
    """
    outcome_events = {"CLOSED_WIN", "CLOSED_LOSS", "CLOSED", "EXPIRED", "MITIGATED"}
    detected_events = {"DETECTED"}

    records = []
    groups = df.groupby(["ob_name", "symbol", "timeframe"], dropna=False)

    for (ob_name, symbol, tf), group in groups:
        detected = group[group["event_type"].isin(detected_events)]
        if detected.empty:
            continue  # no baseline row — skip
        base = detected.iloc[0].to_dict()

        # Final outcome: prefer last event that is a terminal state
        terminal = group[group["event_type"].isin(outcome_events)]
        if terminal.empty:
            # OB still open at export time — skip (no label yet)
            continue

        final = terminal.iloc[-1]
        event = final["event_type"]

        # Overlay structural flags onto the DETECTED baseline.
        # Priority: TRADED row (state at trade time) > CLOSED row (state at cleanup).
        # TRADED fires inside setOBOrder() when an order is actually placed;
        # for EXPIRED/MISS OBs there is no TRADED row so CLOSED is used.
        traded_row = group[group["event_type"] == "TRADED"]
        structural_source = traded_row.iloc[-1] if not traded_row.empty else final
        for col in STRUCTURAL_OVERLAY_COLS:
            if col in structural_source.index:
                base[col] = structural_source[col]

        # Determine label
        ev_outcome = str(final.get("outcome", "")).upper()
        if event == "CLOSED_WIN" or (event == "CLOSED" and ev_outcome == "WIN"):
            label = 1
            outcome_str = "WIN"
        elif event == "CLOSED_LOSS" or (event == "CLOSED" and ev_outcome == "LOSS"):
            label = 0
            outcome_str = "LOSS"
        elif event == "EXPIRED" or (event == "CLOSED" and ev_outcome == "EXPIRED"):
            label = 0
            outcome_str = "EXPIRED"
        elif event == "MITIGATED" or (event == "CLOSED" and ev_outcome == "MISS"):
            # Mitigated without trade = missed opportunity; kept separate (label=None)
            label = None
            outcome_str = "MISS"
        else:
            label = None
            outcome_str = "UNKNOWN"

        # Highest filter stage reached (number of FILTERED_TICK rows)
        n_filtered = len(group[group["event_type"] == "FILTERED_TICK"])

        base["label"] = label
        base["outcome_str"] = outcome_str
        base["n_filtered_ticks"] = n_filtered
        base["r_multiple_final"] = final.get("r_multiple", np.nan)
        records.append(base)

    result = pd.DataFrame(records)
    return result


def main():
    parser = argparse.ArgumentParser(description="Parse OB lifecycle CSV into tidy DataFrame")
    parser.add_argument("--input",  required=True,  help="Path to raw CSV from the EA")
    parser.add_argument("--output", default="parsed_obs.csv", help="Output CSV path")
    args = parser.parse_args()

    in_path = Path(args.input)
    if not in_path.exists():
        print(f"ERROR: input file not found: {in_path}", file=sys.stderr)
        sys.exit(1)

    print(f"Loading {in_path} ...")
    raw = load_raw(in_path)
    print(f"  {len(raw):,} rows loaded, {raw['event_type'].value_counts().to_dict()}")

    print("Joining lifecycle events ...")
    tidy = join_lifecycle(raw)
    print(f"  {len(tidy):,} OBs resolved")

    # Split summary
    traded = tidy[tidy["label"].notna()]
    missed = tidy[tidy["label"].isna()]
    wins   = traded[traded["label"] == 1]
    losses = traded[traded["label"] == 0]
    print(f"  Traded OBs: {len(traded)} ({len(wins)} WIN / {len(losses)} LOSS)")
    print(f"  Missed OBs (no trade): {len(missed)}")

    out_path = Path(args.output)
    tidy.to_csv(out_path, index=False)
    print(f"Saved to {out_path}")


if __name__ == "__main__":
    main()
