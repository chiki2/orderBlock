#!/usr/bin/env python3
"""
XAUUSD ATR min filter sweep + London-only kill zone test (Items 4 & 5).

Item 4: Tests inpATR_MinPct = 0.05%, 0.10%, 0.15%, 0.20% full period
        Forensics: low-ATR trades = 44.8% WR, high-ATR = 64.3%.
        Goal: find ATR floor that cuts losers without killing trade count.

Item 5: Tests London-only kill zone (disable KZ2 16-19 UTC)
        Forensics: NY session = 38.5% WR. London (08-11) is much better.
        KZ1=8-11, KZ2 disabled (set to 0-0).

Full period 2022.01.01 – 2026.03.28 first, then best config cross-year.
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800
SET_FILE = "claude.set"
FROM_DATE = "2022.01.01"
TO_DATE   = "2026.03.28"

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]

# ── Phase 1: ATR min sweep (full period only) ─────────────────────────────
ATR_SWEEP = [
    ("Baseline",      {}),
    ("ATR-min=0.05%", {"inpATR_MinPct": "0.05||0.0||0.050000||1.000000||N"}),
    ("ATR-min=0.10%", {"inpATR_MinPct": "0.10||0.0||0.050000||1.000000||N"}),
    ("ATR-min=0.15%", {"inpATR_MinPct": "0.15||0.0||0.050000||1.000000||N"}),
    ("ATR-min=0.20%", {"inpATR_MinPct": "0.20||0.0||0.050000||1.000000||N"}),
    # Item 5: London-only kill zone (shift KZ2 to 22-23 UTC to effectively disable it)
    # Cannot use 0-0 — MT5 treats that as invalid and blocks all trades
    ("London-KZ-only", {"inpKZ2Start": "22||16||0||23||N",
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
    tmp_name = f"_tmp_xak_{tag}.set"
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


def run_phase1():
    """Full-period sweep for all ATR values + London-only KZ."""
    print(f"\n{'='*70}", flush=True)
    print(f"  PHASE 1: XAUUSD ATR MIN + LONDON KZ SWEEP (full period)", flush=True)
    print(f"  Period: {FROM_DATE} – {TO_DATE}", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*70}\n", flush=True)

    results = []
    total = len(ATR_SWEEP)
    baseline_pf = 0
    baseline_t  = 0

    for n, (label, overrides) in enumerate(ATR_SWEEP, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{n}/{total}] {ts} — {label}", flush=True)

        tag = label.lower().replace("=", "").replace("%", "pct").replace("-", "_").replace(" ", "_")
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

    return results


def run_phase2(winners):
    """Cross-year validation for winning configs from phase 1."""
    if not winners:
        print("\n  No winners to validate cross-year.", flush=True)
        return []

    print(f"\n{'='*70}", flush=True)
    print(f"  PHASE 2: CROSS-YEAR VALIDATION for winners", flush=True)
    print(f"  Configs: {[w[0] for w in winners]}", flush=True)
    print(f"{'='*70}\n", flush=True)

    all_results = []
    total = len(winners) * len(WINDOWS)
    run_num = 0

    for cfg_label, overrides in winners:
        print(f"\n{'='*50}", flush=True)
        print(f"  CONFIG: {cfg_label}", flush=True)
        print(f"{'='*50}", flush=True)

        tag = cfg_label.lower().replace("=", "").replace("%", "pct").replace("-", "_").replace(" ", "_")
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
    # Phase 1: full-period sweep
    phase1 = run_phase1()

    # Save phase 1 CSV
    csv1 = "xauusd_atr_kz_sweep_results.csv"
    with open(csv1, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=phase1[0].keys())
        w.writeheader()
        w.writerows(phase1)

    print(f"\n\n{'='*70}", flush=True)
    print(f"  PHASE 1 SUMMARY", flush=True)
    print(f"{'='*70}", flush=True)
    print(f"  {'Config':<20} {'PF':>6} {'T':>4} {'WR':>5} {'DD':>6}  {'Mark'}", flush=True)
    print(f"  {'-'*50}", flush=True)
    baseline_r = next((r for r in phase1 if r["label"] == "Baseline"), None)
    for r in phase1:
        dt = r["trades"] - (baseline_r["trades"] if baseline_r else 0)
        print(f"  {r['label']:<20} {r['pf']:>6.2f} {r['trades']:>4}        {r['dd']:>5.2f}%  {r['mark']}", flush=True)

    # Pick winners: PF >= baseline AND trades >= 8 (don't lose too many)
    baseline_pf = baseline_r["pf"] if baseline_r else 0
    baseline_t  = baseline_r["trades"] if baseline_r else 0
    winners = [
        (r["label"], dict(ATR_SWEEP)[r["label"]])
        for r in phase1
        if r["label"] != "Baseline"
        and r["pf"] >= baseline_pf
        and r["trades"] >= max(8, baseline_t * 0.5)
        and r["mark"] in ("✓", "~")
    ]
    # Always include London-KZ-only if it shows improvement
    london_r = next((r for r in phase1 if r["label"] == "London-KZ-only"), None)
    london_in_winners = any(w[0] == "London-KZ-only" for w in winners)
    if london_r and not london_in_winners and london_r["pf"] >= baseline_pf * 0.9:
        winners.append(("London-KZ-only", dict(ATR_SWEEP)["London-KZ-only"]))

    print(f"\n  Winners for cross-year: {[w[0] for w in winners] or 'none'}", flush=True)

    # Phase 2: cross-year for winners
    phase2 = run_phase2(winners)

    if phase2:
        csv2 = "xauusd_atr_kz_xv_results.csv"
        with open(csv2, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=phase2[0].keys())
            w.writeheader()
            w.writerows(phase2)

        print(f"\n\n{'='*70}", flush=True)
        print(f"  PHASE 2 SUMMARY — CROSS-YEAR", flush=True)
        print(f"{'='*70}", flush=True)
        print(f"  {'Config':<22} {'2022':>7} {'2023':>7} {'2024':>7} {'2025':>7} {'Full PF':>8} {'T':>4}", flush=True)
        print(f"  {'-'*68}", flush=True)
        for cfg_label, _ in winners:
            rows = [r for r in phase2 if r["config"] == cfg_label]
            row_str = f"  {cfg_label:<22}"
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
        print(f"\n  Saved: {csv2}", flush=True)

    print(f"\n  Phase 1 saved: {csv1}", flush=True)


if __name__ == "__main__":
    main()
