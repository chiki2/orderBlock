#!/usr/bin/env python3
"""
AUDUSD Option C (No-DailyBias) cross-year validation.

Builds a temporary audusd_optionc.set from AUDUSD.set with:
  - inpDailyBiasEnabled=false  (Option C: no intraday bias filter)
  - inpMacroTrendEnabled=true  (keep — load-bearing for other symbols)
  - inpRequireD1Trend=true     (keep — only redundant for XAUUSD)
  - inpKillZoneEnabled=true    (keep)

AUDUSD was previously tested at 2/5 pass rate with DailyBias=true.
Testing if removing DailyBias improves consistency.

Pass criteria: 3+/4 annual windows PF>=1.0 trades>=3 AND Full PF>=1.5
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800
SYMBOL    = "AUDUSD"
SRC_SET   = "AUDUSD.set"   # uppercase original

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]

OPTION_C_OVERRIDES = {
    "inpDailyBiasEnabled":   "false||false||0||true||N",
    "inpDailyBiasYesterday": "false||false||0||true||N",
    "inpMacroTrendEnabled":  "true||false||0||true||N",
    "inpRequireD1Trend":     "true||false||0||true||N",
}


def build_set_file():
    src = os.path.join(BASE, "OBInclude", "SetFiles", SRC_SET)
    with codecs.open(src, "r", "utf-16") as f:
        lines = f.readlines()
    new_lines = []
    applied = set()
    for line in lines:
        key = line.split("=")[0].strip() if "=" in line else ""
        if key in OPTION_C_OVERRIDES:
            new_lines.append(f"{key}={OPTION_C_OVERRIDES[key]}\n")
            applied.add(key)
        else:
            new_lines.append(line)
    for key, val in OPTION_C_OVERRIDES.items():
        if key not in applied:
            new_lines.append(f"{key}={val}\n")
    tmp_name = "_tmp_audusd_optc.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def run_backtest(set_file, from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"]    = SYMBOL
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
        for p in val.replace('%','').replace(',','.').split():
            try:
                return float(p)
            except ValueError:
                continue
    return fallback


def main():
    print(f"\n{'='*70}", flush=True)
    print(f"  AUDUSD OPTION C (No-DailyBias) CROSS-YEAR VALIDATION", flush=True)
    print(f"  Source: {SRC_SET} + DailyBias=false override", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*70}\n", flush=True)

    print("  Overrides applied:", flush=True)
    for k, v in OPTION_C_OVERRIDES.items():
        print(f"    {k} = {v.split('||')[0]}", flush=True)

    tmp_set = build_set_file()
    results = []

    for n, (year, from_d, to_d) in enumerate(WINDOWS, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{n}/{len(WINDOWS)}] {ts} — {year}", flush=True)

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
        results.append({"window": year, "pf": pf, "trades": trades, "dd": dd,
                         "ok": profitable, "mark": mark})

    # Cleanup temp set
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_set)
    if os.path.exists(tmp_path):
        os.remove(tmp_path)

    csv_file = "audusd_option_c_xv_results.csv"
    with open(csv_file, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=results[0].keys())
        w.writeheader()
        w.writerows(results)

    annual   = [r for r in results if r["window"] != "Full"]
    full_r   = next((r for r in results if r["window"] == "Full"), None)
    ok_years = sum(1 for r in annual if r["ok"])

    print(f"\n\n{'='*70}", flush=True)
    print(f"  FINAL SUMMARY — AUDUSD Option C Cross-Year", flush=True)
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
