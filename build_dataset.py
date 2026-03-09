#!/usr/bin/env python3
"""
build_dataset.py — OB CSV → labeled ML dataset

Merges DETECTED / TRADED / CLOSED events per order-block, cleans features,
and writes ob_dataset.csv + ob_dataset_traded.csv.

Usage:
    python3 build_dataset.py               # uses default XAUUSD paths
    python3 build_dataset.py --glob "*.csv" --out /tmp/out.csv

Labels
    outcome  : WIN=1  LOSS=0  MISS=0 (no trade taken)  EXPIRED=0
    label_3  : WIN=2  LOSS=1  NO_TRADE=0   (3-class)

Classes in ob_dataset.csv      : all 6520+ detected OBs
Classes in ob_dataset_traded.csv: only OBs where an order was placed
"""

import csv, glob, os, math, argparse
from pathlib import Path
from collections import defaultdict

# ── paths ──────────────────────────────────────────────────────────────────
MT5_FILES   = Path("/home/charles/.mt5/drive_c/Program Files/MetaTrader 5")
TESTER_ROOT = MT5_FILES / "Tester"
LIVE_ROOT   = MT5_FILES / "MQL5/Files"
OUT_DIR     = Path("/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock")

# ── feature spec ───────────────────────────────────────────────────────────
# Features taken from the DETECTED row (market context at OB birth)
DETECT_FEATS = [
    "is_bear",
    "htf_trend",          # W1/H1 trend at detection (BULLISH/BEARISH/RANGE)
    "stars",
    "high_price", "low_price", "ob_body", "ob_wick",
    "is_mss", "is_bos", "has_choch", "mss_level",
    "is_imbalanced", "imbalanced_dist",
    "lssc_valid", "has_sweep_before",
    "top_imp_valid", "is_lower_mss", "all_checks", "final_check",
    "c1_open", "c1_high", "c1_low", "c1_close",
    "c2_open", "c2_high", "c2_low", "c2_close",
    "atr", "spread",
]

# Features taken from the TRADED row (available once order is placed)
TRADED_FEATS = [
    "fib50", "fib80", "fib100", "fib127", "fib1618",
    "entry_price", "stop_loss", "take_profit", "lot_size",
]

# Derived features (computed from raw values)
DERIVED_FEATS = [
    "ob_body_pct",       # body / (high-low), candle body ratio
    "ob_range_pts",      # high - low in points
    "sl_dist_pts",       # |entry - SL| in points
    "tp_dist_pts",       # |TP - entry| in points
    "rr_ratio",          # tp_dist / sl_dist
    "hour_utc",          # 0-23
    "day_of_week",       # 0=Mon..4=Fri
    "month",             # 1-12
    "htf_bull",          # 1 if htf_trend==BULLISH
    "htf_bear",          # 1 if htf_trend==BEARISH
    "align_with_trend",  # 1 if OB direction matches HTF trend
]

ALL_FEATS = DETECT_FEATS + TRADED_FEATS + DERIVED_FEATS

# ── helpers ─────────────────────────────────────────────────────────────────
SENTINEL = {-1.0, 0.0}   # values that mean "not yet set"

def safe_float(v, default=0.0):
    try:
        f = float(v)
        if math.isnan(f) or math.isinf(f) or abs(f) > 1e15:
            return default
        return f
    except (ValueError, TypeError):
        return default

def parse_datetime(s):
    """Return (hour, dow, month) from 'YYYY.MM.DD HH:MM:SS' or empty."""
    try:
        date_part, time_part = s.split(" ")
        y, mo, d = date_part.split(".")
        h, mi, _ = time_part.split(":")
        import datetime
        dt = datetime.date(int(y), int(mo), int(d))
        return int(h), dt.weekday(), int(mo)
    except Exception:
        return 0, 0, 0

def htf_num(s):
    if s == "BULLISH": return 1
    if s == "BEARISH": return -1
    return 0   # RANGE / UNKNOWN

def collect_csvs(pattern=None):
    """Return list of CSV paths to process."""
    paths = []
    if pattern:
        paths = sorted(glob.glob(pattern))
    else:
        # Primary: tester agent 3000 (main backtest runs there)
        agent_glob = str(TESTER_ROOT / "Agent-127.0.0.1-3000/MQL5/Files/ob_data_XAUUSD*.csv")
        paths = sorted(glob.glob(agent_glob))
        if not paths:
            # Fallback: all agents
            paths = sorted(glob.glob(str(TESTER_ROOT / "*/MQL5/Files/ob_data_XAUUSD*.csv")))
        if not paths:
            paths = sorted(glob.glob(str(LIVE_ROOT / "ob_data_XAUUSD*.csv")))
    return paths

# ── main pipeline ────────────────────────────────────────────────────────────
def load_events(csv_path):
    """Load all events; return dict ob_name → list[row]."""
    events = defaultdict(list)
    with open(csv_path, newline="", encoding="utf-8", errors="replace") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            events[row["ob_name"]].append(row)
    return events

def build_record(ob_name, rows):
    """
    Merge event rows for one OB into a single feature dict.
    Returns None if the OB is invalid / missing required data.
    """
    detect_row = None
    traded_row = None
    closed_row = None
    # Outcome priority: WIN > LOSS > EXPIRED > MISS
    OUTCOME_PRIORITY = {"WIN": 4, "LOSS": 3, "EXPIRED": 2, "MISS": 1, "": 0}

    for row in rows:
        et = row.get("event_type", "")
        if et == "DETECTED" and detect_row is None:
            detect_row = row
        elif et == "TRADED":
            traded_row = row   # last TRADED wins (re-entries)
        elif et == "CLOSED":
            # Keep the highest-priority outcome
            cur_p  = OUTCOME_PRIORITY.get(closed_row.get("outcome","") if closed_row else "", 0)
            new_p  = OUTCOME_PRIORITY.get(row.get("outcome",""), 0)
            if new_p >= cur_p:
                closed_row = row

    if detect_row is None:
        return None

    rec = {"ob_name": ob_name}

    # --- outcome / label ---
    outcome = closed_row.get("outcome", "MISS") if closed_row else "MISS"
    rec["outcome"]  = outcome
    rec["label"]    = 1 if outcome == "WIN" else 0
    rec["label_3"]  = 2 if outcome == "WIN" else (1 if outcome == "LOSS" else 0)
    rec["traded"]   = 1 if traded_row is not None else 0
    rec["r_multiple"] = safe_float(closed_row.get("r_multiple", 0)) if closed_row else 0.0

    # --- CLOSED row has final filter state; DETECT row has market snapshot ---
    # Use CLOSED for filter flags (they're all 0 at DETECTED time)
    # Use DETECTED for candle/market context (snapshot at OB birth)
    feat_src  = closed_row if closed_row else detect_row
    for f in DETECT_FEATS:
        if f not in ("htf_trend",):
            rec[f] = safe_float(feat_src.get(f, detect_row.get(f, 0)))
        else:
            rec[f] = feat_src.get(f, detect_row.get(f, "UNKNOWN"))
    # Candle data always from DETECTED (market state at birth)
    for cf in ["c1_open","c1_high","c1_low","c1_close","c2_open","c2_high","c2_low","c2_close","atr","spread"]:
        rec[cf] = safe_float(detect_row.get(cf, 0))

    # --- fib / entry levels from TRADED row (only meaningful if traded) ---
    trade_src = traded_row if traded_row else detect_row
    for f in TRADED_FEATS:
        rec[f] = safe_float(trade_src.get(f, 0))

    # --- derived features ---
    hi   = safe_float(feat_src.get("high_price",  0))
    lo   = safe_float(feat_src.get("low_price",   0))
    body = safe_float(feat_src.get("ob_body",     0))
    rng  = hi - lo if hi > lo else 1.0
    rec["ob_body_pct"]  = body / rng if rng > 0 else 0.0
    rec["ob_range_pts"] = rng

    entry = rec["entry_price"]
    sl    = rec["stop_loss"]
    tp    = rec["take_profit"]
    sl_d  = abs(entry - sl)   if (entry and sl)  else 0.0
    tp_d  = abs(tp    - entry) if (tp    and entry) else 0.0
    rec["sl_dist_pts"] = sl_d
    rec["tp_dist_pts"] = tp_d
    rec["rr_ratio"]    = tp_d / sl_d if sl_d > 0 else 0.0

    h, dow, mo = parse_datetime(detect_row.get("ob_start_time", ""))
    rec["hour_utc"]    = h
    rec["day_of_week"] = dow
    rec["month"]       = mo

    htf = feat_src.get("htf_trend", detect_row.get("htf_trend", "UNKNOWN"))
    rec["htf_bull"]         = 1 if htf == "BULLISH" else 0
    rec["htf_bear"]         = 1 if htf == "BEARISH" else 0
    is_bear = int(safe_float(feat_src.get("is_bear", 0)))
    rec["align_with_trend"] = 1 if (
        (htf == "BULLISH" and is_bear == 0) or
        (htf == "BEARISH" and is_bear == 1)
    ) else 0

    # encode htf_trend as numeric for model input
    rec["htf_trend"] = htf_num(feat_src.get("htf_trend", detect_row.get("htf_trend","UNKNOWN")))

    return rec

def write_csv(records, path, extra_cols=None):
    if not records:
        print(f"  [WARN] no records to write to {path}")
        return
    meta    = ["ob_name", "outcome", "label", "label_3", "traded", "r_multiple"]
    columns = meta + ALL_FEATS + (extra_cols or [])
    # deduplicate while preserving order
    seen = set(); columns = [c for c in columns if not (c in seen or seen.add(c))]
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=columns, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(records)
    print(f"  Wrote {len(records):,} rows → {path}")

# ─────────────────────────────────────────────────────────────────────────────
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--glob",  default=None, help="CSV file glob pattern")
    ap.add_argument("--out",   default=None, help="Output CSV path")
    args = ap.parse_args()

    csv_paths = collect_csvs(args.glob)
    if not csv_paths:
        print("ERROR: no OB CSV files found. Run a backtest first.")
        return

    print(f"Input files ({len(csv_paths)}):")
    for p in csv_paths:
        print(f"  {p}")

    # merge all files into one event dict
    all_events = defaultdict(list)
    for path in csv_paths:
        for ob_name, rows in load_events(path).items():
            all_events[ob_name].extend(rows)

    print(f"\nUnique OBs: {len(all_events):,}")

    # build records
    records = []
    for ob_name, rows in all_events.items():
        rec = build_record(ob_name, rows)
        if rec:
            records.append(rec)

    # sort by OB start time (derived from ob_name which embeds the time)
    records.sort(key=lambda r: r.get("ob_name", ""))

    # stats
    wins  = sum(1 for r in records if r["label"] == 1)
    losses = sum(1 for r in records if r["outcome"] == "LOSS")
    traded = sum(1 for r in records if r["traded"] == 1)
    print(f"\nDataset summary:")
    print(f"  Total OBs  : {len(records):,}")
    print(f"  WIN        : {wins}")
    print(f"  LOSS       : {losses}")
    print(f"  NO_TRADE   : {len(records) - wins - losses}")
    print(f"  Traded (order placed): {traded}")
    print(f"  Positive rate: {wins/len(records)*100:.2f}%")

    out_all    = args.out or str(OUT_DIR / "ob_dataset.csv")
    out_traded = out_all.replace(".csv", "_traded.csv")

    write_csv(records, out_all)
    write_csv([r for r in records if r["traded"] == 1], out_traded)

    print("\nDone. Next step: run train_model.py to train the classifier.")

if __name__ == "__main__":
    main()
