#!/usr/bin/env python3
"""
Out-of-Sample Portfolio Test — 2026 Q1 (Jan 1 – Mar 28).

Runs all 4 deployed symbols on the period AFTER all our optimization.
This is the true OOS test: no parameter was tuned on this period.

Symbols/set files: XAUUSD/claude.set, USDJPY/usdjpy.set,
                   EURJPY/eurjpy.set, GBPUSD/gbpusd.set
"""
import subprocess, json, time, os, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT   = 1800
FROM_DATE = "2026.01.01"
TO_DATE   = "2026.03.28"

SYMBOLS = [
    ("XAUUSD", "claude.set"),
    ("USDJPY", "usdjpy.set"),
    ("EURJPY", "eurjpy.set"),
    ("GBPUSD", "gbpusd.set"),
]


def run_backtest(symbol, set_file):
    env = os.environ.copy()
    env["SYMBOL"]    = symbol
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
        for p in val.replace('%','').replace(',','.').split():
            try:
                return float(p)
            except ValueError:
                continue
    return fallback


def main():
    print(f"\n{'='*65}", flush=True)
    print(f"  OUT-OF-SAMPLE TEST — 2026 Q1  ({FROM_DATE} → {TO_DATE})", flush=True)
    print(f"  All parameters were finalized BEFORE this period.", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*65}\n", flush=True)

    results = []
    for symbol, set_file in SYMBOLS:
        ts = datetime.now().strftime("%H:%M")
        print(f"[{ts}] {symbol:<8} {set_file}", flush=True)
        t0 = time.time()
        result = run_backtest(symbol, set_file)
        elapsed = time.time() - t0
        diag = scan_last_backtest()
        if result:
            pf     = parse_float(result.get("profit_factor", 0))
            trades = int(result.get("traded", 0) or 0)
            dd     = parse_float(result.get("max_dd_pct", 0))
            wins_raw = result.get("profit_trades", result.get("wins", "0"))
            wins   = int(str(wins_raw).split()[0]) if wins_raw else 0
            wr     = wins / trades * 100 if trades > 0 else 0
            mark   = "✓" if pf >= 1.0 and trades >= 2 else "✗"
            print(f"  PF={pf:.2f}  T={trades}  WR={wr:.0f}%  DD={dd:.2f}%  ({elapsed:.0f}s)  {mark}", flush=True)
        else:
            pf, trades, dd, wr = 0, 0, 0, 0
            mark = "✗"
            print(f"  FAIL ({elapsed:.0f}s)", flush=True)
        print(format_oneliner(diag), flush=True)
        results.append({"symbol": symbol, "pf": pf, "trades": trades,
                         "dd": dd, "wr": round(wr,1), "mark": mark})

    print(f"\n{'='*65}", flush=True)
    print(f"  PORTFOLIO OOS SUMMARY — 2026 Q1", flush=True)
    print(f"{'='*65}", flush=True)
    print(f"\n  {'Symbol':<8} {'PF':>6} {'T':>4} {'WR':>5} {'DD':>6}  Mark", flush=True)
    print(f"  {'-'*40}", flush=True)
    for r in results:
        print(f"  {r['symbol']:<8} {r['pf']:>6.2f} {r['trades']:>4} {r['wr']:>4.0f}% {r['dd']:>5.2f}%  {r['mark']}", flush=True)

    pass_count = sum(1 for r in results if r["mark"] == "✓")
    total_trades = sum(r["trades"] for r in results)
    print(f"\n  {pass_count}/{len(results)} symbols profitable in OOS period", flush=True)
    print(f"  Total trades: {total_trades}", flush=True)
    print(f"\n  {'PASS ✓' if pass_count >= 3 else 'MIXED ~' if pass_count >= 2 else 'FAIL ✗'} — portfolio OOS verdict", flush=True)


if __name__ == "__main__":
    main()
