#!/usr/bin/env python3
"""
EURUSD Option C (No-DailyBias) cross-year validation (Item 3).

eurusd.set already has: DailyBias=false, MacroTrend=true, D1Trend=false, KZ=true
This tests whether EURUSD with the same filter stack as the deployed XAUUSD
config (Option C) passes cross-year validation.

Pass criteria: 3+/4 annual windows PF≥1.0 trades≥3 AND Full PF≥1.5
"""
import subprocess, json, time, os, sys, csv
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800
SYMBOL   = "EURUSD"
SET_FILE = "eurusd.set"

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]


def run_backtest(from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"]    = SYMBOL
    env["SET_FILE"]  = SET_FILE
    env["FROM_DATE"] = from_date
    env["TO_DATE"]   = to_date
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
    print(f"  EURUSD OPTION C (No-DailyBias) CROSS-YEAR VALIDATION (Item 3)", flush=True)
    print(f"  Set file: {SET_FILE}", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*70}\n", flush=True)

    results = []
    total = len(WINDOWS)

    for n, (year, from_d, to_d) in enumerate(WINDOWS, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{n}/{total}] {ts} — {year}", flush=True)

        t0 = time.time()
        result = run_backtest(from_d, to_d)
        elapsed = time.time() - t0
        diag = scan_last_backtest()

        if result:
            pf     = parse_float(result.get("profit_factor", 0))
            trades = int(result.get("traded", 0) or 0)
            dd     = parse_float(result.get("max_dd_pct", 0))
            profitable = pf >= 1.0 and trades >= 3
            mark = "✓" if profitable else "✗"
            print(f"  PF={pf:.2f}  T={trades}  DD={dd:.2f}%  ({elapsed:.0f}s)  {mark}", flush=True)
        else:
            pf, trades, dd, profitable = 0, 0, 0, False
            mark = "✗"
            print(f"  FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)
        results.append({"window": year, "pf": pf, "trades": trades, "dd": dd, "ok": profitable, "mark": mark})

    csv_file = "eurusd_nobias_xv_results.csv"
    with open(csv_file, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)

    annual   = [r for r in results if r["window"] != "Full"]
    full_r   = next((r for r in results if r["window"] == "Full"), None)
    ok_years = sum(1 for r in annual if r["ok"])

    print(f"\n\n{'='*70}", flush=True)
    print(f"  FINAL SUMMARY — EURUSD No-DailyBias Cross-Year", flush=True)
    print(f"{'='*70}", flush=True)
    print(f"\n  {'Year':<8} {'PF':>6} {'T':>4} {'DD':>6}  {'OK'}", flush=True)
    print(f"  {'-'*32}", flush=True)
    for r in results:
        print(f"  {r['window']:<8} {r['pf']:>6.2f} {r['trades']:>4} {r['dd']:>5.2f}%  {r['mark']}", flush=True)
    print(f"\n  {ok_years}/4 annual windows profitable", flush=True)
    if full_r:
        print(f"  Full: PF={full_r['pf']:.2f}  T={full_r['trades']}  DD={full_r['dd']:.2f}%", flush=True)
    verdict = ok_years >= 3 and full_r and full_r["pf"] >= 1.5
    print(f"  VERDICT: {'PASS ✓' if verdict else 'FAIL ✗'}", flush=True)
    print(f"\n  Saved: {csv_file}", flush=True)


if __name__ == "__main__":
    main()
