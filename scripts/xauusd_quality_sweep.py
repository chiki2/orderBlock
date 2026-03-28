#!/usr/bin/env python3
"""
XAUUSD trade quality sweep (proxy for stars filter).

No inpMinStars input exists. Tests quality-related toggles:
  - inpLowQualityTrades: true = also trade sub-quality OBs (MSS+FVG, no sweep)
  - inpSkipH4InsideBar: true = skip H4 consolidation entries (forensics: 46% of losses)
  - inpD1WickFilter: true = skip when D1 lower wick > 35% (forensics: loss signal)
  - Combined: SkipH4 + D1Wick together

Full period 2022-2026, then cross-year for any winner.
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800
SET_FILE  = "claude.set"
FROM_DATE = "2022.01.01"
TO_DATE   = "2026.03.28"

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]

TESTS = [
    ("Baseline",              {}),
    ("LowQual=ON",            {"inpLowQualityTrades": "true||false||0||true||N"}),
    ("SkipH4Inside",          {"inpSkipH4InsideBar":  "true||false||0||true||N"}),
    ("D1WickFilter",          {"inpD1WickFilter":     "true||false||0||true||N"}),
    ("SkipH4+D1Wick",         {"inpSkipH4InsideBar":  "true||false||0||true||N",
                                "inpD1WickFilter":     "true||false||0||true||N"}),
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
    tmp_name = f"_tmp_xqual_{tag}.set"
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
        for p in val.replace('%','').replace(',','.').split():
            try:
                return float(p)
            except ValueError:
                continue
    return fallback


def run_phase1():
    print(f"\n{'='*70}", flush=True)
    print(f"  PHASE 1: XAUUSD QUALITY SWEEP (full period)", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*70}\n", flush=True)

    results = []
    baseline_pf = 0
    baseline_t  = 0

    for n, (label, overrides) in enumerate(TESTS, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{n}/{len(TESTS)}] {ts} — {label}", flush=True)
        tag = label.lower().replace("+","_").replace("=","").replace(" ","_")
        tmp_set = apply_overrides(overrides, tag)

        t0 = time.time()
        result = run_backtest(tmp_set, FROM_DATE, TO_DATE)
        elapsed = time.time() - t0
        diag = scan_last_backtest()

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
            print(f"  PF={pf:.2f}  T={trades}  WR={wr:.0f}%  DD={dd:.2f}%  ΔT={dt:+d}  ({elapsed:.0f}s)  {mark}", flush=True)
        else:
            pf, trades, dd, wr, dt = 0, 0, 0, 0, 0
            mark = "✗"
            print(f"  FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)
        results.append({"label": label, "pf": pf, "trades": trades, "dd": dd,
                         "wr": round(wr, 1), "mark": mark})

    return results, baseline_pf, baseline_t


def run_phase2(winners):
    if not winners:
        print("\n  No winners to validate cross-year.", flush=True)
        return []

    print(f"\n{'='*70}", flush=True)
    print(f"  PHASE 2: CROSS-YEAR VALIDATION", flush=True)
    print(f"{'='*70}\n", flush=True)

    all_results = []
    total = len(winners) * len(WINDOWS)
    run_num = 0

    for cfg_label, overrides in winners:
        print(f"\n{'='*50}", flush=True)
        print(f"  CONFIG: {cfg_label}", flush=True)
        print(f"{'='*50}", flush=True)

        tag = cfg_label.lower().replace("+","_").replace("=","").replace(" ","_") + "_xv"
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

    return all_results


def main():
    phase1, baseline_pf, baseline_t = run_phase1()

    csv1 = "xauusd_quality_sweep_results.csv"
    with open(csv1, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=phase1[0].keys())
        w.writeheader()
        w.writerows(phase1)

    print(f"\n\n{'='*70}", flush=True)
    print(f"  PHASE 1 SUMMARY", flush=True)
    print(f"{'='*70}", flush=True)
    print(f"  {'Config':<20} {'PF':>6} {'T':>4} {'WR':>5} {'DD':>6}  {'ΔT':>5}  Mark", flush=True)
    print(f"  {'-'*55}", flush=True)
    for r in phase1:
        dt = r["trades"] - baseline_t
        print(f"  {r['label']:<20} {r['pf']:>6.2f} {r['trades']:>4} {r['wr']:>4.0f}% {r['dd']:>5.2f}%  {dt:>+5d}  {r['mark']}", flush=True)

    # Winners: PF >= baseline AND trades >= 8 AND mark better than ✗
    winners = [
        (r["label"], dict(TESTS)[r["label"]])
        for r in phase1
        if r["label"] != "Baseline"
        and r["pf"] > baseline_pf * 1.05
        and r["trades"] >= max(8, baseline_t * 0.5)
        and r["mark"] in ("✓", "~")
    ]
    print(f"\n  Winners: {[w[0] for w in winners] or 'none (no improvement over baseline)'}", flush=True)

    phase2 = run_phase2(winners)

    if phase2:
        csv2 = "xauusd_quality_xv_results.csv"
        with open(csv2, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=phase2[0].keys())
            w.writeheader()
            w.writerows(phase2)
        print(f"\n  Phase 2 saved: {csv2}", flush=True)

    print(f"  Phase 1 saved: {csv1}", flush=True)


if __name__ == "__main__":
    main()
