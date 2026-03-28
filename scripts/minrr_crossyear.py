#!/usr/bin/env python3
"""
Cross-year validation for inpMinRR filter on all 3 deploy symbols.
Tests MinRR=0.5 (best balance: keeps volume, improves PF) on 5 windows.

USDJPY: baseline PF 1.86 → MinRR target PF ~2.50
EURJPY: baseline PF 1.81 → MinRR target PF ~1.88
GBPUSD: baseline PF 1.67 → MinRR target PF ~2.36

Success: 4+/5 windows profitable (or at least as good as current deployment).
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

SYMBOLS = [
    ("USDJPY", "usdjpy.set", {"inpMinRR": "0.5||0||0.1||2||N"}),
    ("EURJPY", "eurjpy.set", {"inpMinRR": "0.5||0||0.1||2||N"}),
    ("GBPUSD", "gbpusd.set", {"inpMinRR": "1.0||0||0.1||2||N"}),
]

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


def parse_float(val, fallback=0.0):
    if not val:
        return fallback
    try:
        return float(val)
    except (TypeError, ValueError):
        pass
    if isinstance(val, str):
        parts = val.replace('%', '').replace(',', '.').split()
        for p in parts:
            try:
                return float(p)
            except ValueError:
                continue
    return fallback


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
    total = len(SYMBOLS) * len(WINDOWS)
    print(f"\n{'='*70}", flush=True)
    print(f"  MinRR CROSS-YEAR VALIDATION — {total} tests", flush=True)
    print(f"  USDJPY: MinRR=0.5  EURJPY: MinRR=0.5  GBPUSD: MinRR=1.0", flush=True)
    print(f"{'='*70}\n", flush=True)

    all_results = []
    run_num = 0

    for symbol, set_file, overrides in SYMBOLS:
        print(f"\n{'='*50}", flush=True)
        print(f"  {symbol}", flush=True)
        print(f"{'='*50}", flush=True)

        tag = f"{symbol.lower()}_minrr"
        tmp_set = apply_overrides(set_file, overrides, tag)

        sym_results = []
        for year, from_d, to_d in WINDOWS:
            run_num += 1
            ts = datetime.now().strftime("%H:%M")
            print(f"\n[{run_num}/{total}] {ts} — {symbol} {year}", flush=True)

            t0 = time.time()
            result = run_backtest(symbol, tmp_set, from_d, to_d)
            elapsed = time.time() - t0

            diag = scan_last_backtest()

            if result:
                pf = parse_float(result.get("profit_factor", 0))
                trades = int(result.get("traded", 0) or 0)
                dd = parse_float(result.get("max_dd_pct", 0))
                profitable = pf >= 1.0 and trades >= 3
                print(f"  PF={pf:.2f}  T={trades}  DD={dd:.2f}%  ({elapsed:.0f}s)  {'✓' if profitable else '✗'}", flush=True)
            else:
                pf, trades, dd, profitable = 0, 0, 0, False
                print(f"  FAIL ({elapsed:.0f}s)", flush=True)

            print(format_oneliner(diag), flush=True)
            sym_results.append({"year": year, "pf": pf, "trades": trades, "dd": dd, "ok": profitable})
            all_results.append({"symbol": symbol, "window": year, "pf": pf, "trades": trades, "dd": dd, "ok": profitable})

        # Cleanup
        tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_{tag}.set")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

        # Verdict for this symbol
        annual = [r for r in sym_results if r["year"] != "Full"]
        full = next((r for r in sym_results if r["year"] == "Full"), None)
        ok_years = sum(1 for r in annual if r["ok"])
        print(f"\n  {symbol}: {ok_years}/4 years profitable", flush=True)
        if full:
            print(f"  Full: PF={full['pf']:.2f}  T={full['trades']}  DD={full['dd']:.2f}%", flush=True)
        verdict = ok_years >= 3 and full and full["pf"] >= 1.1
        print(f"  VERDICT: {'PASS ✓' if verdict else 'FAIL ✗'}", flush=True)

    # Save CSV
    csv_file = "minrr_crossyear_results.csv"
    with open(csv_file, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=all_results[0].keys())
        w.writeheader()
        w.writerows(all_results)

    # Overall summary
    print(f"\n\n{'='*70}", flush=True)
    print(f"  FINAL SUMMARY — MinRR CROSS-YEAR VALIDATION", flush=True)
    print(f"{'='*70}", flush=True)
    print(f"\n  {'Symbol':<10} {'2022':>6} {'2023':>6} {'2024':>6} {'2025':>6} {'Full PF':>8} {'Full T':>7}", flush=True)
    print(f"  {'-'*50}", flush=True)
    for symbol, _, _ in SYMBOLS:
        sym = [r for r in all_results if r["symbol"] == symbol]
        row = f"  {symbol:<10}"
        for yr in ["2022", "2023", "2024", "2025"]:
            r = next((x for x in sym if x["window"] == yr), None)
            if r:
                mark = "✓" if r["ok"] else "✗"
                row += f"  {r['pf']:.2f}{mark}"
            else:
                row += f"  {'?':>5}"
        full = next((x for x in sym if x["window"] == "Full"), None)
        if full:
            row += f"  {full['pf']:>8.2f}  {full['trades']:>5}"
        print(row, flush=True)

    print(f"\n  Saved: {csv_file}", flush=True)


if __name__ == "__main__":
    main()
