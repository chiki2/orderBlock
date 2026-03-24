#!/usr/bin/env python3
"""
Cross-year validate the unexplored sweep winners:
- EURJPY: forbidMondayFriday=true
- GBPUSD: forbidMondayFriday=true
- GBPUSD: forbidMondayFriday + H4InsideBar + outdatedOB=40
- USDJPY: outdatedOB=40
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.24"),
]

CONFIGS = [
    ("EURJPY", "eurjpy.set", "NoMonFri", {"forbidMondayFriday": "true||false||0||true||N"}),
    ("GBPUSD", "gbpusd.set", "NoMonFri", {"forbidMondayFriday": "true||false||0||true||N"}),
    ("GBPUSD", "gbpusd.set", "NoMonFri+H4IB+OB40", {
        "forbidMondayFriday": "true||false||0||true||N",
        "inpSkipH4InsideBar": "true||false||0||true||N",
        "outdatedOB": "40||80||1||200||N",
    }),
    ("USDJPY", "usdjpy.set", "OB40", {"outdatedOB": "40||80||1||200||N"}),
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


def run_backtest(symbol, set_file, from_date, to_date):
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
        report_mtime_after = os.path.getmtime(report_path) if os.path.exists(report_path) else 0
        if report_mtime_after <= report_mtime_before:
            print(f"  WARNING: HTML report not refreshed — stale data", flush=True)
        return data
    except Exception:
        return None


def main():
    total = len(CONFIGS) * len(WINDOWS)
    print(f"\n{'='*70}", flush=True)
    print(f"  CROSS-YEAR VALIDATION — {len(CONFIGS)} configs × {len(WINDOWS)} windows = {total} tests", flush=True)
    print(f"{'='*70}\n", flush=True)

    all_results = {}
    csv_rows = []
    run_num = 0

    for symbol, set_file, label, overrides in CONFIGS:
        print(f"\n{'='*50}", flush=True)
        print(f"  {symbol} — {label}", flush=True)
        print(f"{'='*50}", flush=True)

        results_for_config = []
        for win_label, from_d, to_d in WINDOWS:
            run_num += 1
            ts = datetime.now().strftime("%H:%M")
            print(f"\n[{run_num}/{total}] {ts} -- {symbol} {label} {win_label}", flush=True)

            actual_set = apply_overrides(set_file, overrides, symbol)

            t0 = time.time()
            result = run_backtest(symbol, actual_set, from_d, to_d)
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

            profitable = pf > 1.0 and trades >= 3
            results_for_config.append((win_label, pf, trades, dd, profitable))
            csv_rows.append({
                "symbol": symbol, "config": label, "window": win_label,
                "pf": pf, "trades": trades, "dd_pct": dd, "balance": bal,
                "profitable": "Y" if profitable else "N",
            })

            tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_{symbol.lower()}.set")
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

        wins = sum(1 for _, _, _, _, p in results_for_config if p)
        all_results[(symbol, label)] = (results_for_config, wins)

    # Save CSV
    csv_file = "crossyear_winners.csv"
    if csv_rows:
        with open(csv_file, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\nCSV saved: {csv_file}", flush=True)

    # Summary
    print(f"\n{'='*70}", flush=True)
    print(f"  CROSS-YEAR VALIDATION SUMMARY", flush=True)
    print(f"{'='*70}", flush=True)
    for (symbol, label), (results, wins) in all_results.items():
        status = "PASS" if wins >= 4 else "MARGINAL" if wins >= 3 else "FAIL"
        print(f"\n  {symbol} {label} — {wins}/{len(results)} profitable [{status}]", flush=True)
        print(f"  {'Window':<8} {'PF':<8} {'Trades':<8} {'DD%':<8} {'OK?':<5}", flush=True)
        for win_label, pf, trades, dd, profitable in results:
            mark = "Y" if profitable else "N"
            print(f"  {win_label:<8} {pf:<8.2f} {trades:<8} {dd:<8.2f} {mark}", flush=True)

    # Deploy recommendation
    print(f"\n{'='*70}", flush=True)
    print(f"  DEPLOY RECOMMENDATIONS", flush=True)
    print(f"{'='*70}", flush=True)
    for (symbol, label), (results, wins) in all_results.items():
        if wins >= 4:
            print(f"  DEPLOY: {symbol} {label} ({wins}/5 profitable)", flush=True)
        elif wins >= 3:
            print(f"  MAYBE:  {symbol} {label} ({wins}/5 profitable)", flush=True)
        else:
            print(f"  SKIP:   {symbol} {label} ({wins}/5 profitable)", flush=True)


if __name__ == "__main__":
    main()
