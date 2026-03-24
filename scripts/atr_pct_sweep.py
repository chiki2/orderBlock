#!/usr/bin/env python3
"""
ATR percentage sweep — calibrate inpATR_MaxPct / inpATR_MinPct for deploy symbols.
Tests percentage-based ATR thresholds to find optimal volatility windows.
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

SYMBOLS = [
    ("USDJPY", "usdjpy.set"),
    ("EURJPY", "eurjpy.set"),
    ("GBPUSD", "gbpusd.set"),
]

ATR_TESTS = [
    ("Baseline", {}),
    ("MaxPct=0.5", {"inpATR_MaxPct": "0.5||0.0||0.100000||2.000000||N"}),
    ("MaxPct=0.8", {"inpATR_MaxPct": "0.8||0.0||0.100000||2.000000||N"}),
    ("MaxPct=1.0", {"inpATR_MaxPct": "1.0||0.0||0.100000||2.000000||N"}),
    ("MaxPct=1.5", {"inpATR_MaxPct": "1.5||0.0||0.100000||2.000000||N"}),
    ("MinPct=0.1", {"inpATR_MinPct": "0.1||0.0||0.050000||1.000000||N"}),
    ("MinPct=0.2", {"inpATR_MinPct": "0.2||0.0||0.050000||1.000000||N"}),
    ("MinPct=0.3", {"inpATR_MinPct": "0.3||0.0||0.050000||1.000000||N"}),
    ("Min=0.1+Max=1.0", {
        "inpATR_MinPct": "0.1||0.0||0.050000||1.000000||N",
        "inpATR_MaxPct": "1.0||0.0||0.100000||2.000000||N",
    }),
    ("Min=0.2+Max=1.5", {
        "inpATR_MinPct": "0.2||0.0||0.050000||1.000000||N",
        "inpATR_MaxPct": "1.5||0.0||0.100000||2.000000||N",
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


def run_backtest(symbol, set_file, from_date="2022.01.01", to_date="2026.03.24"):
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
    total = len(SYMBOLS) * len(ATR_TESTS)
    print(f"\n{'='*65}", flush=True)
    print(f"  ATR Percentage Sweep -- {total} tests ({len(SYMBOLS)} symbols x {len(ATR_TESTS)} configs)", flush=True)
    print(f"{'='*65}\n", flush=True)

    csv_rows = []
    test_num = 0

    for symbol, set_file in SYMBOLS:
        print(f"\n--- {symbol} ---", flush=True)

        for label, overrides in ATR_TESTS:
            test_num += 1
            ts = datetime.now().strftime("%H:%M")
            print(f"\n[{test_num}/{total}] {ts} -- {symbol} {label}", flush=True)

            actual_set = apply_overrides(set_file, overrides, symbol)

            t0 = time.time()
            result = run_backtest(symbol, actual_set)
            elapsed = time.time() - t0

            diag = scan_last_backtest()

            if result:
                pf = parse_pf(result.get("profit_factor", 0))
                trades = result.get("traded", 0) or 0
                dd = parse_dd(result.get("max_dd_pct", 0))
                bal = result.get("balance", 0) or 0
                print(f"  -> PF={pf:<8.2f} Trades={trades:<4} DD={dd:.2f}%  ({elapsed:.0f}s)", flush=True)
            else:
                pf, trades, dd, bal = 0, 0, 0, 0
                print(f"  -> FAIL ({elapsed:.0f}s)", flush=True)

            print(format_oneliner(diag), flush=True)

            csv_rows.append({
                "symbol": symbol, "label": label, "pf": pf,
                "trades": trades, "dd_pct": dd, "balance": bal,
            })

            tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_{symbol.lower()}.set")
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    csv_file = "atr_pct_results.csv"
    if csv_rows:
        with open(csv_file, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\nCSV saved: {csv_file}", flush=True)

    print(f"\n{'='*65}", flush=True)
    print(f"  ATR PERCENTAGE SWEEP RESULTS", flush=True)
    print(f"{'='*65}", flush=True)
    for symbol, _ in SYMBOLS:
        rows = [r for r in csv_rows if r["symbol"] == symbol]
        print(f"\n  {symbol}:", flush=True)
        print(f"  {'Config':<25} {'PF':<8} {'Trades':<8} {'DD%':<8}", flush=True)
        for r in rows:
            print(f"  {r['label']:<25} {r['pf']:<8.2f} {r['trades']:<8} {r['dd_pct']:<8.2f}", flush=True)


if __name__ == "__main__":
    main()
