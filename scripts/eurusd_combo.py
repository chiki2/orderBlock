#!/usr/bin/env python3
"""
EURUSD combo sweep — test combinations of the top 5 winners.
Winners: DailyBias(+0.35), OB40(+0.27), Skip09(+0.21), NoMonFri(+0.20), STOP(+0.17)
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

TESTS = [
    ("DailyBias+OB40", {
        "inpDailyBiasEnabled": "true||false||0||true||N",
        "outdatedOB": "40||80||1||200||N",
    }),
    ("DailyBias+Skip09", {
        "inpDailyBiasEnabled": "true||false||0||true||N",
        "inpSkip09UTC": "true||false||0||true||N",
    }),
    ("DailyBias+NoMonFri", {
        "inpDailyBiasEnabled": "true||false||0||true||N",
        "forbidMondayFriday": "true||false||0||true||N",
    }),
    ("DailyBias+OB40+Skip09", {
        "inpDailyBiasEnabled": "true||false||0||true||N",
        "outdatedOB": "40||80||1||200||N",
        "inpSkip09UTC": "true||false||0||true||N",
    }),
    ("DailyBias+OB40+NoMonFri", {
        "inpDailyBiasEnabled": "true||false||0||true||N",
        "outdatedOB": "40||80||1||200||N",
        "forbidMondayFriday": "true||false||0||true||N",
    }),
    ("DailyBias+NoMonFri+Skip09", {
        "inpDailyBiasEnabled": "true||false||0||true||N",
        "forbidMondayFriday": "true||false||0||true||N",
        "inpSkip09UTC": "true||false||0||true||N",
    }),
    ("DailyBias+OB40+NoMonFri+Skip09", {
        "inpDailyBiasEnabled": "true||false||0||true||N",
        "outdatedOB": "40||80||1||200||N",
        "forbidMondayFriday": "true||false||0||true||N",
        "inpSkip09UTC": "true||false||0||true||N",
    }),
    ("OB40+Skip09", {
        "outdatedOB": "40||80||1||200||N",
        "inpSkip09UTC": "true||false||0||true||N",
    }),
    ("OB40+NoMonFri", {
        "outdatedOB": "40||80||1||200||N",
        "forbidMondayFriday": "true||false||0||true||N",
    }),
    ("OB40+NoMonFri+Skip09", {
        "outdatedOB": "40||80||1||200||N",
        "forbidMondayFriday": "true||false||0||true||N",
        "inpSkip09UTC": "true||false||0||true||N",
    }),
]


def apply_overrides(set_file, overrides, symbol):
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
    tmp_name = f"_tmp_{symbol.lower()}.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def parse_pf(val):
    try: return float(val)
    except: return 0.0

def parse_dd(val):
    if not val: return 0.0
    try: return float(val)
    except: pass
    if isinstance(val, str):
        parts = val.replace('%', '').split()
        if parts:
            try: return float(parts[0])
            except: pass
    return 0.0


def run_backtest(symbol, set_file, from_date="2022.01.01", to_date="2026.03.25"):
    env = os.environ.copy()
    env["SYMBOL"] = symbol
    env["SET_FILE"] = set_file
    env["FROM_DATE"] = from_date
    env["TO_DATE"] = to_date
    env["DISPLAY"] = ":0"
    json_path = os.path.join(BASE, "backtest_last.json")
    report_path = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/claudeReport.htm"
    if os.path.exists(json_path):
        os.remove(json_path)
    report_mtime_before = os.path.getmtime(report_path) if os.path.exists(report_path) else 0
    clear_log()
    subprocess.run(["bash", "backtest.sh"], capture_output=True, text=True,
                   timeout=TIMEOUT, env=env)
    if not os.path.exists(json_path):
        return None
    try:
        with open(json_path) as f:
            data = json.load(f)
        return data
    except:
        return None


def main():
    total = len(TESTS)
    print(f"\n{'='*65}", flush=True)
    print(f"  EURUSD COMBO SWEEP -- {total} tests", flush=True)
    print(f"{'='*65}\n", flush=True)

    csv_rows = []

    for idx, (label, overrides) in enumerate(TESTS, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{idx}/{total}] {ts} -- {SYMBOL} {label}", flush=True)

        actual_set = apply_overrides(SET_FILE, overrides, SYMBOL)
        t0 = time.time()
        result = run_backtest(SYMBOL, actual_set)
        elapsed = time.time() - t0
        diag = scan_last_backtest()

        if result:
            pf = parse_pf(result.get("profit_factor", 0))
            trades = result.get("traded", 0) or 0
            if not trades:
                tt = result.get("total_trades", 0)
                try: trades = int(tt) if tt else 0
                except: trades = 0
            dd = parse_dd(result.get("max_dd_pct", 0))
            bal = result.get("balance", 0) or 0
            print(f"  -> PF={pf:<8.2f} Trades={trades:<4} DD={dd:.2f}%  ({elapsed:.0f}s)", flush=True)
        else:
            pf, trades, dd, bal = 0, 0, 0, 0
            print(f"  -> FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)
        csv_rows.append({
            "symbol": SYMBOL, "label": label, "pf": pf,
            "trades": trades, "dd_pct": dd, "balance": bal,
        })

        tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_{SYMBOL.lower()}.set")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    csv_file = "eurusd_combo.csv"
    if csv_rows:
        with open(csv_file, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\nCSV saved: {csv_file}", flush=True)

    print(f"\n{'='*65}", flush=True)
    print(f"  EURUSD COMBO RESULTS", flush=True)
    print(f"{'='*65}", flush=True)
    print(f"  {'Config':<35} {'PF':<8} {'Trades':<8} {'DD%':<8}", flush=True)
    for r in sorted(csv_rows, key=lambda x: -x['pf']):
        print(f"  {r['label']:<35} {r['pf']:<8.2f} {r['trades']:<8} {r['dd_pct']:<8.2f}", flush=True)


if __name__ == "__main__":
    main()
