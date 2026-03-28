#!/usr/bin/env python3
"""
Live OB performance monitor.

Reads ob_data_*.csv files from the live MT5 MQL5/Files/ directory,
shows all TRADED/CLOSED events grouped by symbol, computes running PF/WR/R.

Usage:
    python3 scripts/live_monitor.py          # all symbols
    python3 scripts/live_monitor.py XAUUSD   # specific symbol
"""
import os, sys, csv, glob
from datetime import datetime
from collections import defaultdict

MT5_FILES = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Files"


def parse_float(v, fallback=0.0):
    try:
        return float(str(v).split()[0].replace('%', '').replace(',', '.'))
    except Exception:
        return fallback


def load_ob_data(symbols_filter=None):
    """Load all ob_data CSVs, return list of rows."""
    pattern = os.path.join(MT5_FILES, "ob_data_*.csv")
    files = sorted(glob.glob(pattern))
    rows = []
    for f in files:
        sym = os.path.basename(f).split("_")[2]  # ob_data_SYMBOL_...
        if symbols_filter and sym not in symbols_filter:
            continue
        try:
            with open(f, encoding="utf-8") as fh:
                reader = csv.DictReader(fh)
                for row in reader:
                    row["_source_file"] = os.path.basename(f)
                    row["_symbol"] = sym
                    rows.append(row)
        except Exception as e:
            print(f"  [warn] Could not read {f}: {e}")
    return rows


def summarize(rows, symbol):
    traded   = [r for r in rows if r.get("event_type", "").strip() == "TRADED"]
    closed   = [r for r in rows if r.get("event_type", "").strip() in ("CLOSED", "CLOSED_WIN", "CLOSED_LOSS")]
    active   = [r for r in rows if r.get("event_type", "").strip() == "TRADED"
                and not any(c.get("ob_name") == r.get("ob_name") for c in closed)]

    wins  = [r for r in closed if r.get("outcome", "").strip() in ("WIN",  "CLOSED_WIN")]
    losses= [r for r in closed if r.get("outcome", "").strip() in ("LOSS", "CLOSED_LOSS")]

    total_r_wins  = sum(parse_float(r.get("r_multiple", 0)) for r in wins)
    total_r_losses= sum(parse_float(r.get("r_multiple", 0)) for r in losses)

    gross_profit = total_r_wins
    gross_loss   = abs(total_r_losses)
    pf = gross_profit / gross_loss if gross_loss > 0 else float("inf") if gross_profit > 0 else 0

    print(f"\n{'='*60}")
    print(f"  {symbol}  —  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"{'='*60}")
    print(f"  Traded : {len(traded):>4}   Closed: {len(closed):>4}   Active: {len(active):>4}")
    if closed:
        wr = len(wins) / len(closed) * 100
        print(f"  Wins   : {len(wins):>4}   Losses: {len(losses):>4}   WR: {wr:.1f}%")
        print(f"  Total R: {gross_profit - gross_loss:>+.2f}R   PF: {pf:.2f}")
    else:
        print(f"  No closed trades yet.")

    # Active positions
    if active:
        print(f"\n  Active positions ({len(active)}):")
        for r in active[-5:]:
            direction = "SELL" if r.get("is_bear", "0").strip() == "1" else "BUY "
            entry = parse_float(r.get("entry_price", 0))
            sl    = parse_float(r.get("stop_loss",   0))
            tp    = parse_float(r.get("take_profit", 0))
            t     = r.get("export_time", "")[:16]
            print(f"    {t}  {direction}  entry={entry:.5f}  sl={sl:.5f}  tp={tp:.5f}")

    # Recent closed trades
    if closed:
        recent = sorted(closed, key=lambda x: x.get("export_time",""))[-10:]
        print(f"\n  Last {len(recent)} closed trades:")
        for r in recent:
            outcome = r.get("outcome", "?").strip()
            rm = parse_float(r.get("r_multiple", 0))
            direction = "SELL" if r.get("is_bear", "0").strip() == "1" else "BUY "
            t  = r.get("export_time", "")[:16]
            mark = "✓" if outcome in ("WIN","CLOSED_WIN") else "✗"
            print(f"    {t}  {direction}  {mark} {outcome:<10}  {rm:>+.2f}R")


def main():
    filter_syms = set(sys.argv[1:]) if len(sys.argv) > 1 else None

    print(f"\nLIVE OB MONITOR — {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"Reading from: {MT5_FILES}")

    rows = load_ob_data(filter_syms)
    if not rows:
        print("\n  No ob_data files found. Files are written when MT5 is running with OB EA.")
        return

    by_sym = defaultdict(list)
    for r in rows:
        by_sym[r["_symbol"]].append(r)

    for sym in sorted(by_sym.keys()):
        summarize(by_sym[sym], sym)

    # Portfolio summary
    all_closed = [r for r in rows if r.get("event_type","").strip() in ("CLOSED","CLOSED_WIN","CLOSED_LOSS")]
    all_wins   = [r for r in all_closed if r.get("outcome","").strip() in ("WIN","CLOSED_WIN")]
    all_losses = [r for r in all_closed if r.get("outcome","").strip() in ("LOSS","CLOSED_LOSS")]
    if all_closed:
        total_r_w = sum(parse_float(r.get("r_multiple",0)) for r in all_wins)
        total_r_l = abs(sum(parse_float(r.get("r_multiple",0)) for r in all_losses))
        pf = total_r_w / total_r_l if total_r_l > 0 else float("inf") if total_r_w > 0 else 0
        wr = len(all_wins) / len(all_closed) * 100
        print(f"\n{'='*60}")
        print(f"  PORTFOLIO TOTAL")
        print(f"{'='*60}")
        print(f"  Closed: {len(all_closed)}   Wins: {len(all_wins)}   Losses: {len(all_losses)}")
        print(f"  WR: {wr:.1f}%   PF: {pf:.2f}   Net R: {total_r_w - total_r_l:>+.2f}R")
        print()


if __name__ == "__main__":
    main()
