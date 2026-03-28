#!/usr/bin/env python3
"""
EURUSD cross-year validation for DailyBias config.
Tests 5 windows: 2022, 2023, 2024, 2025, Full
Success criteria: >= 3/5 years profitable, PF >= 1.1 overall
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800
SYMBOL = "EURUSD"
SET_FILE = "eurusd.set"

# DailyBias override only
OVERRIDES = {
    "inpDailyBiasEnabled": "true||false||0||true||N",
}

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]


def apply_overrides(set_file, overrides, tag):
    path = os.path.join(BASE, "OBInclude", "SetFiles", set_file)
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
    tmp_name = f"_tmp_{tag}.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def run_backtest(symbol, set_file, from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"] = symbol
    env["SET_FILE"] = set_file
    env["FROM_DATE"] = from_date
    env["TO_DATE"] = to_date
    env["DISPLAY"] = ":0"
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


def main():
    print(f"\n{'='*60}", flush=True)
    print(f"  EURUSD CROSS-YEAR VALIDATION — DailyBias config", flush=True)
    print(f"{'='*60}\n", flush=True)

    tmp_set = apply_overrides(SET_FILE, OVERRIDES, "eurusd_dailybias_xv")
    results = []

    for i, (year, from_d, to_d) in enumerate(WINDOWS):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{i+1}/{len(WINDOWS)}] {ts} — {SYMBOL} {year}", flush=True)

        t0 = time.time()
        result = run_backtest(SYMBOL, tmp_set, from_d, to_d)
        elapsed = time.time() - t0

        diag = scan_last_backtest()

        if result:
            pf = float(result.get("profit_factor", 0) or 0)
            trades = int(result.get("traded", 0) or result.get("total_trades", 0) or 0)
            dd = float(result.get("max_dd_pct", 0) or 0)
            net = float(result.get("net_profit", 0) or 0)
            profitable = pf >= 1.0 and trades >= 3
            print(f"  PF={pf:.2f}  T={trades}  DD={dd:.2f}%  Net={net:+.2f}  ({elapsed:.0f}s)  {'✓' if profitable else '✗'}", flush=True)
        else:
            pf, trades, dd, net, profitable = 0, 0, 0, 0, False
            print(f"  FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)

        results.append({
            "window": year, "pf": pf, "trades": trades,
            "dd": dd, "net": net, "profitable": profitable,
        })

    # Cleanup temp set
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", "_tmp_eurusd_dailybias_xv.set")
    if os.path.exists(tmp_path):
        os.remove(tmp_path)

    # Summary
    annual = [r for r in results if r["window"] != "Full"]
    profitable_years = sum(1 for r in annual if r["profitable"])
    full = next((r for r in results if r["window"] == "Full"), None)

    print(f"\n{'='*60}", flush=True)
    print(f"  CROSS-YEAR VALIDATION RESULT", flush=True)
    print(f"{'='*60}", flush=True)
    print(f"  Config: EURUSD + DailyBias", flush=True)
    print(f"  Profitable years: {profitable_years}/4", flush=True)
    if full:
        print(f"  Full period: PF={full['pf']:.2f}  T={full['trades']}  DD={full['dd']:.2f}%  Net={full['net']:+.2f}", flush=True)
    print(f"\n  Year-by-year:", flush=True)
    for r in annual:
        mark = "✓" if r["profitable"] else "✗"
        print(f"    {r['window']}: PF={r['pf']:.2f}  T={r['trades']}  DD={r['dd']:.2f}%  {mark}", flush=True)

    passed = profitable_years >= 3 and full and full["pf"] >= 1.1
    print(f"\n  VERDICT: {'PASS — DEPLOYABLE' if passed else 'FAIL — do not deploy'}", flush=True)

    # Save
    with open("eurusd_dailybias_crossyear.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)
    print(f"  Saved: eurusd_dailybias_crossyear.csv", flush=True)


if __name__ == "__main__":
    main()
