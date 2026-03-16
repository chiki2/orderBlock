#!/usr/bin/env python3
"""
parse_agent_log.py — Extract optimization results from MT5 tester agent log

The agent log (Agent-127.0.0.1-3000/logs/YYYYMMDD.log) contains lines like:
  CS  0  HH:MM:SS.mmm  Tester  N OnTester result X.XXXX : passed in HH:MM:SS.mmm

This extracts (pass_number, score) pairs and, given the optimization parameter
ranges, maps each pass number to its parameter values.

Usage:
    python3 parse_agent_log.py --log /path/to/log.log \
        --params "inpKZ1Start=6:1:8" "inpKZ1End=9:1:12" \
        --top 5 --patch-set XAUUSD_best.set

Parameter range format: name=min:step:max
  Integers: inpKZ1Start=6:1:8 -> values [6,7,8]
  Booleans: inpRequireD1Trend=false:0:true -> values [false,true]
  Floats:   fiboEntry=0.55:0.05:0.75 -> values [0.55,0.60,...,0.75]
"""

import sys, re, argparse, codecs, os, math
from pathlib import Path


def read_log(path):
    """Read MT5 agent log (UTF-16)."""
    try:
        with codecs.open(path, 'r', 'utf-16') as f:
            return f.read()
    except Exception:
        with open(path, errors='replace') as f:
            return f.read()


def parse_scores(log_content):
    """Extract {pass_number: score} from agent log."""
    scores = {}
    pattern = re.compile(r'\bTester\s+(\d+)\s+OnTester result\s+([+-]?\d+\.?\d*)\s*:')
    for m in pattern.finditer(log_content):
        pass_num = int(m.group(1))
        score = float(m.group(2))
        # Keep the most recent score for each pass (in case of restarts)
        scores[pass_num] = score
    return scores


def parse_param_range(spec):
    """Parse 'name=min:step:max' into (name, [values])."""
    name, rest = spec.split('=', 1)
    parts = rest.split(':')
    if len(parts) != 3:
        raise ValueError(f"Invalid range spec: {spec}. Use name=min:step:max")
    
    lo, step_s, hi = parts
    
    # Boolean special case
    if lo.lower() in ('false', 'true') or hi.lower() in ('false', 'true'):
        values = ['false', 'true']
        return name, values
    
    # Numeric
    lo_f, step_f, hi_f = float(lo), float(step_s), float(hi)
    if step_f <= 0:
        return name, [lo_f]
    
    values = []
    v = lo_f
    while v <= hi_f + 1e-9:
        # Use round to avoid floating-point drift
        rounded = round(v, 8)
        values.append(rounded)
        v = lo_f + (len(values)) * step_f
    
    # Format nicely
    formatted = []
    for val in values:
        if abs(val - round(val)) < 1e-9:
            formatted.append(str(int(round(val))))
        else:
            formatted.append(str(round(val, 6)))
    
    return name, formatted


def enumerate_combos(params):
    """
    Enumerate all parameter combinations in MT5 complete optimization order.
    MT5 iterates: first param slowest, last param fastest.
    Returns list of dicts {name: value}.
    """
    if not params:
        return [{}]
    
    # params = [(name, [values]), ...]
    # Build cartesian product with first param slowest
    combos = [{}]
    for name, values in params:
        new_combos = []
        for partial in combos:
            for v in values:
                new = dict(partial)
                new[name] = v
                new_combos.append(new)
        combos = new_combos
    return combos


def find_latest_log():
    """Find the most recent agent log file."""
    base = Path("/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/Tester")
    logs = sorted(base.glob("Agent-127.0.0.1-*/logs/*.log"),
                  key=lambda p: p.stat().st_mtime)
    return str(logs[-1]) if logs else None


def patch_set_file(set_path, best_combo):
    """Patch parameter values into a UTF-16 .set file."""
    try:
        with codecs.open(set_path, 'r', 'utf-16') as f:
            content = f.read()
    except Exception:
        with open(set_path, errors='replace') as f:
            content = f.read()
    
    patched = 0
    for param, val in best_combo.items():
        pattern = re.compile(
            r'^(' + re.escape(param) + r'=)([^|]+)((\|\|[^\r\n]*)?)\r?$',
            re.MULTILINE
        )
        if pattern.search(content):
            content = pattern.sub(lambda m: m.group(1) + str(val) + m.group(3), content)
            patched += 1
    
    with codecs.open(set_path, 'w', 'utf-16') as f:
        f.write(content)
    return patched


def main():
    ap = argparse.ArgumentParser(description='Parse MT5 agent log for optimization results')
    ap.add_argument('--log', default=None, help='Path to agent log (auto-detected if omitted)')
    ap.add_argument('--params', nargs='+', default=[],
                    help='Parameter ranges: name=min:step:max ...')
    ap.add_argument('--top', type=int, default=5)
    ap.add_argument('--min-score', type=float, default=0.0,
                    help='Minimum OnTester score to consider')
    ap.add_argument('--patch-set', default=None,
                    help='Path to .set file to patch with best params')
    ap.add_argument('--round', default='opt')
    args = ap.parse_args()

    # Find log
    log_path = args.log or find_latest_log()
    if not log_path or not os.path.exists(log_path):
        print(f"ERROR: agent log not found (tried: {log_path})")
        sys.exit(1)
    
    print(f"Log: {log_path}")
    log_content = read_log(log_path)
    scores = parse_scores(log_content)
    
    if not scores:
        print("WARNING: no OnTester results found in log")
        sys.exit(0)
    
    print(f"Found {len(scores)} pass results")
    
    # Parse parameter ranges
    param_ranges = []
    for spec in args.params:
        name, values = parse_param_range(spec)
        param_ranges.append((name, values))
        print(f"  {name}: {values}")
    
    # Enumerate combinations
    combos = enumerate_combos(param_ranges)
    print(f"Total combinations: {len(combos)}")
    
    # Match pass numbers to combos
    results = []
    for pass_num, score in scores.items():
        if score <= args.min_score:
            continue
        combo = combos[pass_num] if pass_num < len(combos) else {}
        results.append({
            'pass': pass_num,
            'score': score,
            'params': combo
        })
    
    results.sort(key=lambda r: r['score'], reverse=True)
    
    print(f"\n{'='*60}")
    print(f" TOP {min(args.top, len(results))} by OnTester Score — Round: {args.round}")
    print(f"{'='*60}")
    
    for i, r in enumerate(results[:args.top], 1):
        print(f"\n  #{i}  Pass={r['pass']}  Score={r['score']:.4f}")
        for k, v in r['params'].items():
            print(f"       {k} = {v}")
    
    if not results:
        print("  No valid passes found.")
        return
    
    best = results[0]
    print(f"\n{'='*60}")
    print(f" BEST: Pass {best['pass']}, Score={best['score']:.4f}")
    print(f"{'='*60}")
    for k, v in best['params'].items():
        print(f"  {k} = {v}")
    
    if args.patch_set and best['params']:
        n = patch_set_file(args.patch_set, best['params'])
        print(f"\n  Patched {n} params → {args.patch_set}")


if __name__ == '__main__':
    main()
