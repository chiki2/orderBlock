#!/usr/bin/env python3
"""
XAUUSD London-only kill zone cross-year validation (Item 5 retest).

Disables NY kill zone (16-19 UTC) by shifting KZ2 to 22-23 UTC (dead of night).
Only London KZ1 (08-11 UTC) is active.

Forensics: NY session = 38.5% WR vs London ~60%+. Test if removing NY entries
improves cross-year stability even at the cost of fewer trades.

Pass criteria: 3+/4 annual windows PF>=1.0 trades>=3 AND Full PF>=1.5
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800
SET_FILE = "claude.set"

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]

CONFIGS = [
    ("Baseline (KZ1+KZ2)",  {}),
    ("London-only (KZ1)",   {"inpKZ2Start": "22||16||0||23||N",
                              "inpKZ2End":   "23||19||0||24||N"}),
]


def apply_overrides(overrides, tag):
    path = os.path.join(BASE, "OBInclude", "SetFiles", SET_FILE)
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
    tmp_name = f"_tmp_lkz_{tag}.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def run_backtest(set_file, from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"]    = "XAUUSD"
    env["SET_FILE"]  = set_file
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
    print(f"  XAUUSD LONDON-ONLY KZ CROSS-YEAR (Item 5 retest)", flush=True)
    print(f"  KZ1=08-11 UTC (London) vs KZ1+KZ2=08-11+16-19 UTC (baseline)", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*70}\n", flush=True)

    total = len(CONFIGS) * len(WINDOWS)
    run_num = 0
    all_results = []

    for cfg_label, overrides in CONFIGS:
        print(f"\n{'='*50}", flush=True)
        print(f"  CONFIG: {cfg_label}", flush=True)
        print(f"{'='*50}", flush=True)

        tag = "baseline" if not overrides else "london_only"
        tmp_set = apply_overrides(overrides, tag)
        sym_results = []

        for year, from_d, to_d in WINDOWS:
            run_num += 1
            ts = datetime.now().strftime("%H:%M")
            print(f"\n[{run_num}/{total}] {ts} — {cfg_label} {year}", flush=True)

            t0 = time.time()
            result = run_backtest(tmp_set, from_d, to_d)
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
            sym_results.append({"year": year, "pf": pf, "trades": trades, "dd": dd, "ok": profitable})
            all_results.append({"config": cfg_label, "window": year, "pf": pf,
                                  "trades": trades, "dd": dd, "ok": profitable})

        tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_set)
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

        annual   = [r for r in sym_results if r["year"] != "Full"]
        full_r   = next((r for r in sym_results if r["year"] == "Full"), None)
        ok_years = sum(1 for r in annual if r["ok"])
        print(f"\n  {cfg_label}: {ok_years}/4 annual windows profitable", flush=True)
        if full_r:
            print(f"  Full: PF={full_r['pf']:.2f}  T={full_r['trades']}  DD={full_r['dd']:.2f}%", flush=True)
        verdict = ok_years >= 3 and full_r and full_r["pf"] >= 1.5
        print(f"  VERDICT: {'PASS ✓' if verdict else 'FAIL ✗'}", flush=True)

    csv_file = "xauusd_london_kz_xv_results.csv"
    with open(csv_file, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=all_results[0].keys())
        w.writeheader()
        w.writerows(all_results)

    print(f"\n\n{'='*70}", flush=True)
    print(f"  FINAL SUMMARY — London KZ vs Baseline", flush=True)
    print(f"{'='*70}", flush=True)
    print(f"\n  {'Config':<24} {'2022':>7} {'2023':>7} {'2024':>7} {'2025':>7} {'Full PF':>8} {'T':>4}", flush=True)
    print(f"  {'-'*68}", flush=True)
    for cfg_label, _ in CONFIGS:
        rows = [r for r in all_results if r["config"] == cfg_label]
        row_str = f"  {cfg_label:<24}"
        for yr in ["2022", "2023", "2024", "2025"]:
            r = next((x for x in rows if x["window"] == yr), None)
            if r:
                mark = "✓" if r["ok"] else "✗"
                row_str += f"  {r['pf']:.2f}{mark}"
            else:
                row_str += f"  {'?':>5}"
        full_r = next((x for x in rows if x["window"] == "Full"), None)
        if full_r:
            row_str += f"  {full_r['pf']:>8.2f}  {full_r['trades']:>3}"
        print(row_str, flush=True)

    baseline_full = next((r for r in all_results if r["config"] == "Baseline (KZ1+KZ2)" and r["window"] == "Full"), None)
    london_full   = next((r for r in all_results if r["config"] == "London-only (KZ1)" and r["window"] == "Full"), None)
    if baseline_full and london_full:
        dpf = london_full["pf"] - baseline_full["pf"]
        dt  = london_full["trades"] - baseline_full["trades"]
        print(f"\n  London-only vs Baseline: ΔPF={dpf:+.2f}  ΔT={dt:+d}", flush=True)

    print(f"\n  Saved: {csv_file}", flush=True)


if __name__ == "__main__":
    main()
