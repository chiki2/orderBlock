#!/usr/bin/env python3
"""
Unexplored parameters sweep — test never-varied settings across deploy symbols.
Targets: H4 inside bar, D1 wick, forbidMondayFriday, outdatedOB, trailing stop,
         maxWickRatio, minBodySize, volume filter.
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

# Test on the 3 FX deploy symbols (XAUUSD too sparse for meaningful comparison)
SYMBOLS = [
    ("USDJPY", "usdjpy.set"),
    ("EURJPY", "eurjpy.set"),
    ("GBPUSD", "gbpusd.set"),
]

TESTS = [
    ("Baseline", {}),

    # Forensics filters — never enabled on FX symbols
    ("H4 InsideBar", {"inpSkipH4InsideBar": "true||false||0||true||N"}),
    ("D1 Wick", {"inpD1WickFilter": "true||false||0||true||N"}),
    ("H4IB + D1Wick", {
        "inpSkipH4InsideBar": "true||false||0||true||N",
        "inpD1WickFilter": "true||false||0||true||N",
    }),

    # Day filters
    ("No Mon/Fri", {"forbidMondayFriday": "true||false||0||true||N"}),

    # OB age — default=80, never tested
    ("outdatedOB=40", {"outdatedOB": "40||80||1||200||N"}),
    ("outdatedOB=120", {"outdatedOB": "120||80||1||200||N"}),
    ("outdatedOB=200", {"outdatedOB": "200||80||1||200||N"}),

    # OB quality — candle geometry thresholds
    ("maxWick=1.2", {"maxWickRatio": "1.2||1.6||0.100000||3.000000||N"}),
    ("maxWick=2.0", {"maxWickRatio": "2.0||1.6||0.100000||3.000000||N"}),
    ("minBody=5", {"minBodySize": "5||10||1||50||N"}),
    ("minBody=20", {"minBodySize": "20||10||1||50||N"}),

    # Trailing stop — disabled everywhere, never tested
    ("TrailStop=400", {
        "enableTrailingStop": "true||false||0||true||N",
        "trailingStopPoints": "400||600||50||1500||N",
    }),
    ("TrailStop=800", {
        "enableTrailingStop": "true||false||0||true||N",
        "trailingStopPoints": "800||600||50||1500||N",
    }),

    # Volume filter
    ("VolFilter", {"inpVolumeFilter": "true||false||0||true||N"}),
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
    total = len(SYMBOLS) * len(TESTS)
    print(f"\n{'='*70}", flush=True)
    print(f"  UNEXPLORED PARAMETERS SWEEP -- {total} tests ({len(SYMBOLS)} symbols x {len(TESTS)} configs)", flush=True)
    print(f"{'='*70}\n", flush=True)

    csv_rows = []
    test_num = 0
    baselines = {}

    for symbol, set_file in SYMBOLS:
        print(f"\n{'='*50}", flush=True)
        print(f"  {symbol}", flush=True)
        print(f"{'='*50}", flush=True)

        for label, overrides in TESTS:
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
                wr = result.get("win_rate_str", "n/a")
                print(f"  -> PF={pf:<8.2f} Trades={trades:<4} WR={wr}  DD={dd:.2f}%  ({elapsed:.0f}s)", flush=True)
            else:
                pf, trades, dd, bal, wr = 0, 0, 0, 0, "FAIL"
                print(f"  -> FAIL ({elapsed:.0f}s)", flush=True)

            print(format_oneliner(diag), flush=True)

            if label == "Baseline":
                baselines[symbol] = pf

            csv_rows.append({
                "symbol": symbol, "label": label, "pf": pf,
                "trades": trades, "dd_pct": dd, "balance": bal,
            })

            tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_{symbol.lower()}.set")
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    csv_file = "unexplored_results.csv"
    if csv_rows:
        with open(csv_file, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\nCSV saved: {csv_file}", flush=True)

    # Summary
    print(f"\n{'='*70}", flush=True)
    print(f"  UNEXPLORED PARAMETERS — RESULTS", flush=True)
    print(f"{'='*70}", flush=True)
    for symbol, _ in SYMBOLS:
        rows = [r for r in csv_rows if r["symbol"] == symbol]
        base_pf = baselines.get(symbol, 0)
        print(f"\n  {symbol} (baseline PF={base_pf:.2f}):", flush=True)
        print(f"  {'Config':<20} {'PF':<8} {'Trades':<8} {'DD%':<8} {'vs Base':<10}", flush=True)
        for r in rows:
            delta = r["pf"] - base_pf if base_pf > 0 else 0
            marker = "+" if delta > 0 else " " if delta == 0 else ""
            print(f"  {r['label']:<20} {r['pf']:<8.2f} {r['trades']:<8} {r['dd_pct']:<8.2f} {marker}{delta:<+8.2f}", flush=True)

    # Winners
    print(f"\n{'='*70}", flush=True)
    print(f"  WINNERS (PF improved vs baseline)", flush=True)
    print(f"{'='*70}", flush=True)
    for symbol, _ in SYMBOLS:
        rows = [r for r in csv_rows if r["symbol"] == symbol and r["label"] != "Baseline"]
        base_pf = baselines.get(symbol, 0)
        winners = [(r["label"], r["pf"], r["pf"] - base_pf) for r in rows if r["pf"] > base_pf and r["trades"] >= 10]
        winners.sort(key=lambda x: -x[2])
        if winners:
            print(f"\n  {symbol}:", flush=True)
            for label, pf, delta in winners:
                print(f"    {label:<20} PF={pf:.2f}  (+{delta:.2f})", flush=True)
        else:
            print(f"\n  {symbol}: No improvements found", flush=True)


if __name__ == "__main__":
    main()
