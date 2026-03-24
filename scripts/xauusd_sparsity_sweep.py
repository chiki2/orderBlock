#!/usr/bin/env python3
"""
XAUUSD sparsity fix — test wider kill zones and relaxed filters.
Current: only 2-6 trades/year, filters too aggressive.
Goal: increase trade count while maintaining quality.
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

TESTS = [
    # (label, overrides_dict)
    ("Baseline (current claude.set)", {}),
    ("Wider KZ (08-16 + 18-23)", {
        "inpKZ1Start": "8||8||1||70||N",
        "inpKZ1End": "16||12||1||100||N",
        "inpKZ2Start": "18||13||1||120||N",
        "inpKZ2End": "23||16||1||160||N",
    }),
    ("No KZ", {
        "inpKillZoneEnabled": "false||false||0||true||N",
    }),
    ("No Skip09UTC", {
        "inpSkip09UTC": "false||false||0||true||N",
    }),
    ("No D1Trend", {
        "inpRequireD1Trend": "false||false||0||true||N",
    }),
    ("No MacroTrend", {
        "inpMacroTrendEnabled": "false||false||0||true||N",
    }),
    ("Wider KZ + No Skip09", {
        "inpKZ1Start": "8||8||1||70||N",
        "inpKZ1End": "16||12||1||100||N",
        "inpKZ2Start": "18||13||1||120||N",
        "inpKZ2End": "23||16||1||160||N",
        "inpSkip09UTC": "false||false||0||true||N",
    }),
    ("No KZ + No Skip09 + No D1", {
        "inpKillZoneEnabled": "false||false||0||true||N",
        "inpSkip09UTC": "false||false||0||true||N",
        "inpRequireD1Trend": "false||false||0||true||N",
    }),
    ("No KZ + No D1 (keep Macro+Skip09)", {
        "inpKillZoneEnabled": "false||false||0||true||N",
        "inpRequireD1Trend": "false||false||0||true||N",
    }),
    ("Wider KZ + No D1", {
        "inpKZ1Start": "8||8||1||70||N",
        "inpKZ1End": "16||12||1||100||N",
        "inpKZ2Start": "18||13||1||120||N",
        "inpKZ2End": "23||16||1||160||N",
        "inpRequireD1Trend": "false||false||0||true||N",
    }),
]

CSV_FILE = "xauusd_sparsity_results.csv"


def apply_overrides(set_file, overrides):
    if not overrides:
        return set_file
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
    tmp_name = "_tmp_xau_claude.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def parse_pf(val):
    try:
        return float(val)
    except (TypeError, ValueError):
        return 0.0


def parse_dd(val):
    if not val:
        return 0.0
    try:
        return float(val)
    except (TypeError, ValueError):
        pass
    if isinstance(val, str):
        parts = val.replace('%', '').split()
        if parts:
            try:
                return float(parts[0])
            except ValueError:
                pass
    return 0.0


def run_backtest(set_file, from_date="2022.01.01", to_date="2026.03.24"):
    env = os.environ.copy()
    env["SYMBOL"] = "XAUUSD"
    env["SET_FILE"] = set_file
    env["FROM_DATE"] = from_date
    env["TO_DATE"] = to_date
    env["DISPLAY"] = ":0"
    json_path = os.path.join(BASE, "backtest_last.json")
    if os.path.exists(json_path):
        os.remove(json_path)
    clear_log()
    r = subprocess.run(["bash", "backtest.sh"], capture_output=True, text=True,
                       timeout=TIMEOUT, env=env)
    if not os.path.exists(json_path):
        return None
    try:
        with open(json_path) as f:
            return json.load(f)
    except Exception:
        return None


def main():
    total = len(TESTS)
    print(f"\n{'='*65}", flush=True)
    print(f"  XAUUSD Sparsity Fix Sweep -- {total} tests", flush=True)
    print(f"{'='*65}\n", flush=True)

    csv_rows = []

    for idx, (label, overrides) in enumerate(TESTS, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{idx}/{total}] {ts} -- {label}", flush=True)

        actual_set = apply_overrides("claude.set", overrides)

        t0 = time.time()
        result = run_backtest(actual_set)
        elapsed = time.time() - t0

        diag = scan_last_backtest()

        if result:
            pf = parse_pf(result.get("profit_factor", 0))
            trades = result.get("traded", 0) or 0
            wr = result.get("win_rate_str", "n/a")
            dd = parse_dd(result.get("max_dd_pct", 0))
            bal = result.get("balance", 0) or 0
            print(f"  -> PF={pf:<8.2f} Trades={trades:<4} WR={wr}  DD={dd:.2f}%  ({elapsed:.0f}s)", flush=True)
        else:
            pf, trades, wr, dd, bal = 0, 0, "FAIL", 0, 0
            print(f"  -> FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)

        csv_rows.append({
            "label": label, "pf": pf, "trades": trades, "dd_pct": dd, "balance": bal,
            "log": diag["summary"],
        })

        # Cleanup
        tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", "_tmp_xau_claude.set")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    # Save CSV
    if csv_rows:
        with open(CSV_FILE, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\nCSV saved: {CSV_FILE}", flush=True)

    # Summary
    print(f"\n{'='*65}", flush=True)
    print(f"  XAUUSD SPARSITY SWEEP RESULTS", flush=True)
    print(f"{'='*65}", flush=True)
    print(f"  {'Label':<45} {'PF':<8} {'Trades':<8} {'DD%':<8}", flush=True)
    for r in csv_rows:
        print(f"  {r['label']:<45} {r['pf']:<8.2f} {r['trades']:<8} {r['dd_pct']:<8.2f}", flush=True)


if __name__ == "__main__":
    main()
