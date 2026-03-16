#!/usr/bin/env python3
"""
parse_optimization.py — Parse MT5 optimization XML report

MT5 saves optimization results as Excel-compatible XML.
Extracts the row with the highest Sharpe ratio and prints
best parameter values along with the full sorted table.

Usage:
    python3 parse_optimization.py claudeReport.xml
    python3 parse_optimization.py claudeReport.xml --top 5
    python3 parse_optimization.py claudeReport.xml --criterion sharpe
"""

import sys, re, argparse, codecs, os
from pathlib import Path

CRITERIA = {
    "profit":   lambda r: float(r.get("Profit", 0)),
    "pf":       lambda r: float(r.get("Profit Factor", 0)),
    "sharpe":   lambda r: float(r.get("Sharpe Ratio", 0)),
    "recovery": lambda r: float(r.get("Recovery Factor", 0)),
    "payoff":   lambda r: float(r.get("Expected Payoff", 0)),
    "trades":   lambda r: int(float(r.get("Trades", 0))),
}

def read_file(path):
    """Try UTF-16 first, then UTF-8."""
    for enc in ("utf-16", "utf-8", "utf-8-sig"):
        try:
            with codecs.open(path, "r", enc) as f:
                return f.read()
        except Exception:
            continue
    with open(path, errors="replace") as f:
        return f.read()

def parse_xml(content):
    """
    Parse Excel-compatible XML from MT5 optimization report.
    Returns list of dicts (one per optimization pass).
    """
    # Extract all Row elements
    rows = re.findall(r'<Row[^>]*>(.*?)</Row>', content, re.DOTALL)
    if not rows:
        return []

    def cells(row_text):
        return re.findall(r'<Data[^>]*>(.*?)</Data>', row_text, re.DOTALL)

    # First row = headers
    headers = [c.strip() for c in cells(rows[0])]
    if not headers:
        return []

    records = []
    for row in rows[1:]:
        vals = [c.strip() for c in cells(row)]
        if not vals:
            continue
        rec = {}
        for i, h in enumerate(headers):
            rec[h] = vals[i] if i < len(vals) else ""
        records.append(rec)

    return records

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xml", help="Path to MT5 optimization XML report")
    ap.add_argument("--top",       type=int, default=5,       help="Show top N results")
    ap.add_argument("--criterion", default="sharpe",
                    choices=list(CRITERIA), help="Sort metric")
    ap.add_argument("--min-trades", type=int, default=3,
                    help="Minimum trades to include result")
    ap.add_argument("--set",       default=None,
                    help="Base .set file to patch with best params")
    ap.add_argument("--out-set",   default=None,
                    help="Output .set file (default: overwrite --set)")
    args = ap.parse_args()

    if not os.path.exists(args.xml):
        print(f"ERROR: file not found: {args.xml}")
        sys.exit(1)

    content = read_file(args.xml)
    records = parse_xml(content)

    if not records:
        print("ERROR: could not parse any records from XML")
        print("       (file may still be loading or format differs)")
        sys.exit(1)

    print(f"Total passes parsed: {len(records):,}")

    sort_fn = CRITERIA[args.criterion]

    # Filter by min trades
    filtered = [r for r in records
                if int(float(r.get("Trades", 0))) >= args.min_trades]
    print(f"Passes with >= {args.min_trades} trades: {len(filtered):,}")

    if not filtered:
        print("WARNING: no passes meet the minimum trade filter — showing all")
        filtered = records

    filtered.sort(key=sort_fn, reverse=True)
    best = filtered[0]

    # Print top-N
    print(f"\n{'='*72}")
    print(f" TOP {min(args.top, len(filtered))} by {args.criterion.upper()}")
    print(f"{'='*72}")

    # Determine which columns are parameter columns (not metrics)
    metric_cols = {"Pass", "Result", "Profit", "Expected Payoff",
                   "Profit Factor", "Recovery Factor", "Sharpe Ratio",
                   "Custom", "Trades", "Win %", "Balance DD %",
                   "Equity DD %", "Deals"}
    param_cols = [h for h in (filtered[0].keys() if filtered else [])
                  if h not in metric_cols]

    for i, r in enumerate(filtered[:args.top], 1):
        print(f"\n  #{i}  Sharpe={float(r.get('Sharpe Ratio',0)):.4f}"
              f"  PF={float(r.get('Profit Factor',0)):.2f}"
              f"  Trades={r.get('Trades','?')}"
              f"  Win={r.get('Win %','?')}%"
              f"  DD={r.get('Balance DD %','?')}%"
              f"  Profit={r.get('Profit','?')}")
        for p in param_cols:
            if r.get(p):
                print(f"       {p} = {r[p]}")

    # Patch set file if requested
    if args.set and best:
        in_path  = args.set
        out_path = args.out_set or args.set

        try:
            with codecs.open(in_path, "r", "utf-16") as f:
                set_content = f.read()
        except Exception:
            with open(in_path, errors="replace") as f:
                set_content = f.read()

        patched = 0
        for param, new_val in best.items():
            if param in metric_cols or not new_val:
                continue
            # Replace current value in set file:
            # line format: param=curval||...
            pattern = re.compile(r'^(' + re.escape(param) + r'=)([^|]+)(\\|\\|.*)?$',
                                  re.MULTILINE)
            if pattern.search(set_content):
                set_content = pattern.sub(lambda m: m.group(1) + new_val +
                                          (m.group(3) or ""), set_content)
                patched += 1

        with codecs.open(out_path, "w", "utf-16") as f:
            f.write(set_content)
        print(f"\n  Patched {patched} params → {out_path}")

    print(f"\n{'='*72}")
    print(f" BEST RESULT SUMMARY")
    print(f"{'='*72}")
    for k, v in best.items():
        print(f"  {k:35s} = {v}")

if __name__ == "__main__":
    main()
