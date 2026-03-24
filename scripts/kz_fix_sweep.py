#!/usr/bin/env python3
"""
Test GBPJPY and AUDJPY with kill zones enabled (matching USDJPY config).
USDJPY (5/5 profitable) uses KZ 08-12 + 13-16. These symbols have KZ disabled.
"""
import subprocess, json, time, codecs, os, csv, copy, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

TESTS = [
    # (label, symbol, set_file, overrides_dict)
    ("GBPJPY baseline (KZ off)", "GBPJPY", "gbpjpy.set", {}),
    ("GBPJPY KZ=USDJPY (08-12+13-16)", "GBPJPY", "gbpjpy.set", {
        "inpKillZoneEnabled": "true||false||0||true||N",
        "inpKZ1Start": "8||8||1||70||N",
        "inpKZ1End": "12||12||1||100||N",
        "inpKZ2Start": "13||13||1||120||N",
        "inpKZ2End": "16||16||1||160||N",
    }),
    ("GBPJPY KZ=London+NY (08-12+13-17)", "GBPJPY", "gbpjpy.set", {
        "inpKillZoneEnabled": "true||false||0||true||N",
        "inpKZ1Start": "8||8||1||70||N",
        "inpKZ1End": "12||12||1||100||N",
        "inpKZ2Start": "13||13||1||120||N",
        "inpKZ2End": "17||16||1||160||N",
    }),
    ("GBPJPY KZ=Wide (07-17)", "GBPJPY", "gbpjpy.set", {
        "inpKillZoneEnabled": "true||false||0||true||N",
        "inpKZ1Start": "7||8||1||70||N",
        "inpKZ1End": "12||12||1||100||N",
        "inpKZ2Start": "12||13||1||120||N",
        "inpKZ2End": "17||16||1||160||N",
    }),
    ("AUDJPY baseline (KZ off)", "AUDJPY", "audjpy.set", {}),
    ("AUDJPY KZ=USDJPY (08-12+13-16)", "AUDJPY", "audjpy.set", {
        "inpKillZoneEnabled": "true||false||0||true||N",
        "inpKZ1Start": "8||8||1||70||N",
        "inpKZ1End": "12||12||1||100||N",
        "inpKZ2Start": "13||13||1||120||N",
        "inpKZ2End": "16||16||1||160||N",
    }),
    ("AUDJPY KZ=London+NY (08-12+13-17)", "AUDJPY", "audjpy.set", {
        "inpKillZoneEnabled": "true||false||0||true||N",
        "inpKZ1Start": "8||8||1||70||N",
        "inpKZ1End": "12||12||1||100||N",
        "inpKZ2Start": "13||13||1||120||N",
        "inpKZ2End": "17||16||1||160||N",
    }),
    ("AUDJPY KZ=Asian+London (00-06+08-14)", "AUDJPY", "audjpy.set", {
        "inpKillZoneEnabled": "true||false||0||true||N",
        "inpKZ1Start": "0||8||1||70||N",
        "inpKZ1End": "6||12||1||100||N",
        "inpKZ2Start": "8||13||1||120||N",
        "inpKZ2End": "14||16||1||160||N",
    }),
]

CSV_FILE = "kz_fix_results.csv"


def apply_overrides(set_file, overrides):
    """Apply parameter overrides to a set file, return temp filename."""
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

    # Add any overrides not found in original
    for key, val in overrides.items():
        if key not in applied:
            new_lines.append(f"{key}={val}\n")

    tmp_name = f"_tmp_kz_{set_file}"
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


def run_backtest(symbol, set_file, from_date="2022.01.01", to_date="2026.03.23"):
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
    print(f"  Kill Zone Fix Sweep — {total} tests", flush=True)
    print(f"{'='*65}\n", flush=True)

    csv_rows = []

    for idx, (label, symbol, set_file, overrides) in enumerate(TESTS, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{idx}/{total}] {ts} -- {label}", flush=True)

        actual_set = apply_overrides(set_file, overrides)

        t0 = time.time()
        result = run_backtest(symbol, actual_set)
        elapsed = time.time() - t0

        diag = scan_last_backtest()

        if result:
            pf = parse_pf(result.get("profit_factor", 0))
            trades = result.get("traded", 0) or 0
            wr = result.get("win_rate_str", "n/a")
            dd = parse_dd(result.get("max_dd_pct", 0))
            bal = result.get("balance", 0) or 0
            print(f"  -> PF={pf:<6.2f}  Trades={trades:<4}  WR={wr}  DD={dd:.2f}%  ({elapsed:.0f}s)", flush=True)
        else:
            pf, trades, wr, dd, bal = 0, 0, "FAIL", 0, 0
            print(f"  -> FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)

        csv_rows.append({
            "label": label, "symbol": symbol,
            "pf": pf, "trades": trades, "dd_pct": dd, "balance": bal,
            "log": diag["summary"],
        })

        # Cleanup temp set file
        if overrides:
            tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_kz_{set_file}")
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
    print(f"  KZ FIX SWEEP RESULTS", flush=True)
    print(f"{'='*65}", flush=True)
    print(f"  {'Label':<45} {'PF':<8} {'Trades':<8} {'DD%':<8}", flush=True)
    for r in csv_rows:
        print(f"  {r['label']:<45} {r['pf']:<8.2f} {r['trades']:<8} {r['dd_pct']:<8.2f}", flush=True)


if __name__ == "__main__":
    main()
