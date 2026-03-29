#!/usr/bin/env python3
"""
Dynamic Parameters Sweep — Weekday Scaling + ATR-TP Adaptation.

Tests two new dynamic features across all 4 deployed symbols:

FEATURE 1: Weekday Lot Scaling (inpWeekdayScaling=true)
  - Mon=1.0, Tue=0.5, Wed=0.75, Thu=1.0, Fri=0.75
  - Rationale: forensics showed Tue/Wed as worst WR days

FEATURE 2: ATR-Adaptive TP (inpATRTP=true)
  - High ATR regime → TP × 1.5 (trending, let winners run)
  - Low ATR regime  → TP × 0.85 (ranging, take profit earlier)
  - Rationale: static fibo1rstTP under-exploits trending weeks

For each symbol, tests: Baseline / WeekdayScaling / ATRTP / Both
Phase 1: full period. Phase 2: cross-year for winners (PF > baseline × 1.05).

Pass criteria: 3+/4 annual PF>=1.0 T>=3 AND Full PF>=1.5
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

SYMBOLS = [
    ("XAUUSD", "claude.set",  "2022.01.01", "2026.03.28"),
    ("USDJPY", "usdjpy.set",  "2022.01.01", "2026.03.28"),
    ("EURJPY", "eurjpy.set",  "2022.01.01", "2026.03.28"),
    ("GBPUSD", "gbpusd.set",  "2022.01.01", "2026.03.28"),
]

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]

WEEKDAY_OVERRIDES = {
    "inpWeekdayScaling": "true||false||0||true||N",
    "inpWdMon":          "1.0||1.0||0.1||2.0||N",
    "inpWdTue":          "0.5||1.0||0.1||2.0||N",
    "inpWdWed":          "0.75||1.0||0.1||2.0||N",
    "inpWdThu":          "1.0||1.0||0.1||2.0||N",
    "inpWdFri":          "0.75||1.0||0.1||2.0||N",
}

ATRTP_OVERRIDES = {
    "inpATRTP":          "true||false||0||true||N",
    "inpATRTPPeriod":    "50||50||10||200||N",
    "inpATRTPHighPct":   "0.70||0.70||0.1||0.9||N",
    "inpATRTPHighMult":  "1.5||1.5||1.0||3.0||N",
    "inpATRTPLowPct":    "0.30||0.30||0.1||0.5||N",
    "inpATRTPLowMult":   "0.85||0.85||0.5||1.0||N",
}

TESTS = [
    ("Baseline",     {}),
    ("WeekdayScale", WEEKDAY_OVERRIDES),
    ("ATRTP",        ATRTP_OVERRIDES),
    ("Both",         {**WEEKDAY_OVERRIDES, **ATRTP_OVERRIDES}),
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
    tmp_name = f"_tmp_dp_{tag}.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def run_backtest(symbol, set_file, from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"]    = symbol
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


def run_symbol_phase1(symbol, set_file, from_date, to_date):
    results = []
    baseline_pf = 0
    baseline_t  = 0
    for label, overrides in TESTS:
        tag = f"{symbol.lower()}_{label.lower()}"
        tmp_set = apply_overrides(set_file, overrides, tag)
        ts = datetime.now().strftime("%H:%M")
        print(f"  {ts}  {label:<16}", end=" ", flush=True)
        t0 = time.time()
        result = run_backtest(symbol, tmp_set, from_date, to_date)
        elapsed = time.time() - t0
        tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_set)
        if os.path.exists(tmp_path):
            os.remove(tmp_path)
        if result:
            pf     = parse_float(result.get("profit_factor", 0))
            trades = int(result.get("traded", 0) or 0)
            dd     = parse_float(result.get("max_dd_pct", 0))
            wins_raw = result.get("profit_trades", result.get("wins", "0"))
            wins   = int(str(wins_raw).split()[0]) if wins_raw else 0
            wr     = wins / trades * 100 if trades > 0 else 0
            mark   = "✓" if (pf >= 1.5 and trades >= 10) else ("~" if pf >= 1.1 else "✗")
            if label == "Baseline":
                baseline_pf, baseline_t = pf, trades
            dt = trades - baseline_t
            print(f"PF={pf:.2f}  T={trades}  WR={wr:.0f}%  DD={dd:.2f}%  ΔT={dt:+d}  ({elapsed:.0f}s)  {mark}", flush=True)
        else:
            pf, trades, dd, wr, dt = 0, 0, 0, 0, 0
            mark = "✗"
            print(f"FAIL ({elapsed:.0f}s)", flush=True)
        results.append({"symbol": symbol, "label": label, "pf": pf,
                         "trades": trades, "dd": dd, "wr": round(wr,1), "mark": mark})
    return results, baseline_pf, baseline_t


def run_xv(symbol, set_file, label, overrides):
    tag = f"{symbol.lower()}_{label.lower()}_xv"
    tmp_set = apply_overrides(set_file, overrides, tag)
    xv_results = []
    for year, from_d, to_d in WINDOWS:
        ts = datetime.now().strftime("%H:%M")
        print(f"    {ts}  {year}", end="  ", flush=True)
        t0 = time.time()
        result = run_backtest(symbol, tmp_set, from_d, to_d)
        elapsed = time.time() - t0
        if result:
            pf     = parse_float(result.get("profit_factor", 0))
            trades = int(result.get("traded", 0) or 0)
            dd     = parse_float(result.get("max_dd_pct", 0))
            ok     = pf >= 1.0 and trades >= 3
            mark   = "✓" if ok else "✗"
            print(f"PF={pf:.2f}  T={trades}  DD={dd:.2f}%  ({elapsed:.0f}s)  {mark}", flush=True)
        else:
            pf, trades, dd, ok = 0, 0, 0, False
            print(f"FAIL ({elapsed:.0f}s)", flush=True)
        xv_results.append({"symbol": symbol, "config": label, "window": year,
                            "pf": pf, "trades": trades, "dd": dd, "ok": ok})
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_set)
    if os.path.exists(tmp_path):
        os.remove(tmp_path)
    annual   = [r for r in xv_results if r["window"] != "Full"]
    full_r   = next((r for r in xv_results if r["window"] == "Full"), None)
    ok_years = sum(1 for r in annual if r["ok"])
    verdict  = ok_years >= 3 and full_r and full_r["pf"] >= 1.5
    full_pf_str = f"{full_r['pf']:.2f}" if full_r else "0.00"
    print(f"    → {label}: {ok_years}/4 annual  Full PF={full_pf_str}  {'PASS ✓' if verdict else 'FAIL ✗'}", flush=True)
    return xv_results, verdict


def main():
    all_phase1 = []
    all_phase2 = []
    deployed_changes = []

    print(f"\n{'='*75}", flush=True)
    print(f"  DYNAMIC PARAMETERS SWEEP — WeekdayScaling + ATR-TP", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*75}", flush=True)

    for symbol, set_file, from_date, to_date in SYMBOLS:
        print(f"\n{'='*60}", flush=True)
        print(f"  {symbol}  ({set_file})", flush=True)
        print(f"{'='*60}", flush=True)

        results, baseline_pf, baseline_t = run_symbol_phase1(symbol, set_file, from_date, to_date)
        all_phase1.extend(results)

        # Cross-year for winners
        winners = [
            (r["label"], dict(TESTS)[r["label"]])
            for r in results
            if r["label"] != "Baseline"
            and r["pf"] > baseline_pf * 1.05
            and r["trades"] >= max(8, baseline_t * 0.5)
            and r["mark"] in ("✓", "~")
        ]
        print(f"\n  Winners for XV: {[w[0] for w in winners] or 'none'}", flush=True)

        for label, overrides in winners:
            print(f"\n  Cross-year: {symbol} {label}", flush=True)
            xv, verdict = run_xv(symbol, set_file, label, overrides)
            all_phase2.extend(xv)
            if verdict:
                deployed_changes.append((symbol, label))

        bash_cleanup = ["bash", "scripts/cleanup_tester.sh",
                        "XAUUSD", "USDJPY", "EURJPY", "GBPUSD", "EURUSD"]
        subprocess.run(bash_cleanup, capture_output=True, cwd=BASE)

    # ── Save CSVs ──────────────────────────────────────────────────────
    if all_phase1:
        with open("dynamic_params_phase1.csv", "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=all_phase1[0].keys())
            w.writeheader(); w.writerows(all_phase1)

    if all_phase2:
        with open("dynamic_params_xv.csv", "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=all_phase2[0].keys())
            w.writeheader(); w.writerows(all_phase2)

    # ── Summary ────────────────────────────────────────────────────────
    print(f"\n\n{'='*75}", flush=True)
    print(f"  FINAL SUMMARY", flush=True)
    print(f"{'='*75}", flush=True)
    print(f"\n  {'Symbol':<8} {'Config':<16} {'PF':>6} {'T':>4} {'WR':>5} {'DD':>6}  Mark", flush=True)
    print(f"  {'-'*55}", flush=True)
    for r in all_phase1:
        print(f"  {r['symbol']:<8} {r['label']:<16} {r['pf']:>6.2f} {r['trades']:>4} {r['wr']:>4.0f}% {r['dd']:>5.2f}%  {r['mark']}", flush=True)

    print(f"\n  Deployable changes (PASS cross-year): {deployed_changes or 'none'}", flush=True)
    if all_phase1:
        print(f"  Phase 1 saved: dynamic_params_phase1.csv", flush=True)
    if all_phase2:
        print(f"  Phase 2 saved: dynamic_params_xv.csv", flush=True)


if __name__ == "__main__":
    main()
