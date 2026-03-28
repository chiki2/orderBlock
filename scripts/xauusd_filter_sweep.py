#!/usr/bin/env python3
"""
XAUUSD filter redundancy sweep.

Tests Option B (DailyBias yesterday candle) and Option C (no DailyBias)
alongside systematic removal of D1Trend / MacroTrend / Skip09UTC to find
which filters add real value vs redundant stacking.

Full period 2022.01.01 – 2026.03.28
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800
SET_FILE = "claude.set"
FROM_DATE = "2022.01.01"
TO_DATE   = "2026.03.28"

# ── filter combinations to test ───────────────────────────────────────────────
# Each test: (label, overrides_dict)
# Only keys listed will be overridden; others remain as in claude.set
TESTS = [
    ("Baseline",        {}),   # current config (all filters on)

    # Option C — disable DailyBias, rely on D1Trend + MacroTrend
    ("No-DailyBias",    {"inpDailyBiasEnabled":  "false||false||0||true||N"}),

    # Option B — use yesterday's D1 candle direction
    ("D1-Candle",       {"inpDailyBiasEnabled":  "true||false||0||true||N",
                         "inpDailyBiasYesterday":"true||false||0||true||N"}),

    # Remove individual filters one at a time
    ("No-D1Trend",      {"inpRequireD1Trend":    "false||false||0||true||N"}),
    ("No-MacroTrend",   {"inpMacroTrendEnabled": "false||false||0||true||N"}),
    ("No-Skip09",       {"inpSkip09UTC":         "false||false||0||true||N"}),

    # Remove two direction filters — keep only D1Trend
    ("OnlyD1Trend",     {"inpDailyBiasEnabled":  "false||false||0||true||N",
                         "inpMacroTrendEnabled": "false||false||0||true||N"}),

    # Remove two direction filters — keep only MacroTrend
    ("OnlyMacroTrend",  {"inpDailyBiasEnabled":  "false||false||0||true||N",
                         "inpRequireD1Trend":    "false||false||0||true||N"}),

    # Remove all direction filters — just KZ + Skip09
    ("KZ+Skip09-Only",  {"inpDailyBiasEnabled":  "false||false||0||true||N",
                         "inpRequireD1Trend":    "false||false||0||true||N",
                         "inpMacroTrendEnabled": "false||false||0||true||N"}),

    # Option B + no MacroTrend (test if B makes MacroTrend redundant)
    ("D1-Candle+NoMacro", {"inpDailyBiasEnabled":  "true||false||0||true||N",
                           "inpDailyBiasYesterday":"true||false||0||true||N",
                           "inpMacroTrendEnabled": "false||false||0||true||N"}),
]


def apply_overrides(overrides, tag):
    path = os.path.join(BASE, "OBInclude", "SetFiles", SET_FILE)
    with codecs.open(path, "r", "utf-16") as f:
        lines = f.readlines()
    new_lines = []
    applied = set()
    for line in lines:
        key = line.split("=")[0].strip() if "=" in line else ""
        if key in overrides:
            new_lines.append(f"{key}={overrides[key]}\n")
            applied.add(key)
        else:
            new_lines.append(line)
    for key, val in overrides.items():
        if key not in applied:
            new_lines.append(f"{key}={val}\n")
    tmp_name = f"_tmp_xf_{tag}.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def run_backtest(set_file):
    env = os.environ.copy()
    env["SYMBOL"]    = "XAUUSD"
    env["SET_FILE"]  = set_file
    env["FROM_DATE"] = FROM_DATE
    env["TO_DATE"]   = TO_DATE
    env["DISPLAY"]   = ":0"
    json_path = os.path.join(BASE, "backtest_last.json")
    if os.path.exists(json_path):
        os.remove(json_path)
    clear_log()
    subprocess.run(["bash", "backtest.sh"], capture_output=True, text=True,
                   timeout=TIMEOUT, env=env)
    if not os.path.exists(json_path):
        return None
    try:
        with open(json_path) as f:
            return json.load(f)
    except Exception:
        return None


def parse_float(val, fallback=0.0):
    if not val:
        return fallback
    try:
        return float(val)
    except (TypeError, ValueError):
        pass
    if isinstance(val, str):
        for p in val.replace('%', '').replace(',', '.').split():
            try:
                return float(p)
            except ValueError:
                continue
    return fallback


def main():
    print(f"\n{'='*70}", flush=True)
    print(f"  XAUUSD FILTER REDUNDANCY SWEEP", flush=True)
    print(f"  Period: {FROM_DATE} – {TO_DATE}", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*70}\n", flush=True)

    results = []
    total = len(TESTS)

    for n, (label, overrides) in enumerate(TESTS, 1):
        print(f"\n[{n}/{total}] {datetime.now().strftime('%H:%M')} — {label}", flush=True)
        if overrides:
            for k, v in overrides.items():
                print(f"  override: {k} = {v.split('||')[0]}", flush=True)

        tag = label.lower().replace("+", "_").replace("-", "_")
        tmp_set = apply_overrides(overrides, tag)

        t0 = time.time()
        result = run_backtest(tmp_set)
        elapsed = time.time() - t0
        diag = scan_last_backtest()

        # cleanup
        tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_set)
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

        if result:
            pf     = parse_float(result.get("profit_factor", 0))
            trades = int(result.get("traded", 0) or 0)
            wins   = int(result.get("wins",   0) or 0)
            dd     = parse_float(result.get("max_dd_pct", 0))
            bal    = parse_float(result.get("balance", 10000))
            wr     = wins / trades * 100 if trades > 0 else 0
            mark   = "✓" if (pf >= 1.5 and trades >= 15) else ("~" if pf >= 1.1 else "✗")
            print(f"  PF={pf:.2f}  T={trades}  WR={wr:.0f}%  DD={dd:.2f}%  Bal={bal:.0f}  ({elapsed:.0f}s)  {mark}", flush=True)
        else:
            pf, trades, wins, dd, bal, wr = 0, 0, 0, 0, 10000, 0
            mark = "✗"
            print(f"  FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)
        results.append({
            "test": label, "pf": pf, "trades": trades, "wins": wins,
            "wr": round(wr, 1), "dd": dd, "balance": bal, "mark": mark,
        })

    # Save CSV
    csv_file = "xauusd_filter_sweep_results.csv"
    with open(csv_file, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)

    # Summary table
    baseline = next((r for r in results if r["test"] == "Baseline"), None)
    b_pf = baseline["pf"] if baseline else 0
    b_t  = baseline["trades"] if baseline else 0

    print(f"\n\n{'='*70}", flush=True)
    print(f"  FINAL SUMMARY — XAUUSD FILTER SWEEP", flush=True)
    print(f"{'='*70}", flush=True)
    print(f"\n  {'Test':<22} {'PF':>6} {'T':>4} {'WR':>5} {'DD':>6}  {'ΔT':>5}  {'Mark'}", flush=True)
    print(f"  {'-'*60}", flush=True)
    for r in results:
        dt = r["trades"] - b_t if baseline else 0
        print(f"  {r['test']:<22} {r['pf']:>6.2f} {r['trades']:>4} {r['wr']:>4.0f}% {r['dd']:>5.2f}%  {dt:>+5d}  {r['mark']}", flush=True)

    print(f"\n  Saved: {csv_file}", flush=True)


if __name__ == "__main__":
    main()
