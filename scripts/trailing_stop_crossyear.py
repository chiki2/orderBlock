#!/usr/bin/env python3
"""
Cross-year validation for the winning trailing-stop config per symbol.

Reads trailing_stop_results.csv to find the best non-baseline config,
then runs 5 time windows per symbol to validate stability.

Thresholds (pass):
  - 3+/4 annual windows profitable (PF >= 1.0 and trades >= 3)
  - Full-period PF >= 1.1
  - No worse than baseline on Full period
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

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("Full", "2022.01.01", "2026.03.28"),
]

# Config overrides per trailing-stop label
# Used to re-apply the winning config from trailing_stop_results.csv
CONFIG_OVERRIDES = {
    "Baseline": {},
    "NoTrail": {
        "enableTrailingStop": "false||false||0||true||N",
    },
    "ATR-Trail": {
        "enableTrailingStop": "true||false||0||true||N",
        "trailingStrat": "1||0||0||1||N",
        "tslTrigger": "0||0||0||3||N",
    },
    "ATR+FIB127": {
        "enableTrailingStop": "true||false||0||true||N",
        "trailingStrat": "1||0||0||1||N",
        "tslTrigger": "1||0||0||3||N",
    },
    "ATR+FIB161": {
        "enableTrailingStop": "true||false||0||true||N",
        "trailingStrat": "1||0||0||1||N",
        "tslTrigger": "2||0||0||3||N",
    },
    "Classic+FIB127": {
        "enableTrailingStop": "true||false||0||true||N",
        "trailingStrat": "0||0||0||1||N",
        "tslTrigger": "1||0||0||3||N",
        "trailingStopPoints": "800||400||100||1200||N",
    },
    "BreakEven": {
        "enableTrailingStop": "false||false||0||true||N",
        "inpEarlyBreakEven": "true||false||0||true||N",
        "inpBreakEvenRatio": "0.7||0.3||0.1||0.9||N",
    },
    "BE+ATR-Trail": {
        "enableTrailingStop": "true||false||0||true||N",
        "trailingStrat": "1||0||0||1||N",
        "tslTrigger": "1||0||0||3||N",
        "inpEarlyBreakEven": "true||false||0||true||N",
    },
}


def load_winners():
    """Read trailing_stop_results.csv and pick the best config per symbol."""
    results_file = os.path.join(BASE, "trailing_stop_results.csv")
    if not os.path.exists(results_file):
        print(f"ERROR: {results_file} not found. Run trailing_stop_sweep.py first.")
        return None

    by_symbol = {}
    with open(results_file) as f:
        for row in csv.DictReader(f):
            sym = row["symbol"]
            if sym not in by_symbol:
                by_symbol[sym] = []
            by_symbol[sym].append(row)

    winners = {}
    for sym, rows in by_symbol.items():
        baseline = next((r for r in rows if r["test"] == "Baseline"), None)
        best = None
        best_pf = -1
        for r in rows:
            if r["test"] == "Baseline":
                continue
            pf = float(r["pf"] or 0)
            trades = int(r["trades"] or 0)
            if pf > best_pf and trades >= 10:
                best_pf = pf
                best = r
        if best:
            baseline_pf = float(baseline["pf"] or 0) if baseline else 0
            delta = best_pf - baseline_pf
            winners[sym] = {
                "label": best["test"],
                "pf": best_pf,
                "baseline_pf": baseline_pf,
                "delta": delta,
                "overrides": CONFIG_OVERRIDES.get(best["test"], {}),
            }
            print(f"  {sym}: winner = {best['test']}  PF={best_pf:.2f} (baseline={baseline_pf:.2f}, delta={delta:+.2f})")
        else:
            print(f"  {sym}: no winner found (all worse than baseline)")
    return winners


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
    print(f"  TRAILING STOP CROSS-YEAR VALIDATION", flush=True)
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}", flush=True)
    print(f"{'='*70}\n", flush=True)

    print("Loading winners from trailing_stop_results.csv...", flush=True)
    winners = load_winners()
    if not winners:
        return

    # Filter: only validate configs that improved by > 0.1 PF
    to_validate = {sym: w for sym, w in winners.items() if w["delta"] > 0.1}
    if not to_validate:
        print("\nNo configs improved PF by > 0.1. Skipping cross-year validation.")
        return

    print(f"\nValidating {len(to_validate)} symbol(s): {', '.join(to_validate.keys())}", flush=True)
    total = len(to_validate) * len(WINDOWS)
    run_num = 0
    all_results = []

    for symbol, set_file in SYMBOLS:
        if symbol not in to_validate:
            print(f"\n  {symbol}: no significant improvement — skipping", flush=True)
            continue

        winner = to_validate[symbol]
        print(f"\n{'='*50}", flush=True)
        print(f"  {symbol} — {winner['label']} (PF={winner['pf']:.2f}, {winner['delta']:+.2f} vs baseline)", flush=True)
        print(f"{'='*50}", flush=True)

        tag = f"{symbol.lower()}_trail_cy"
        tmp_set = apply_overrides(set_file, winner["overrides"], tag)
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
                mark = "✓" if profitable else "✗"
                print(f"  PF={pf:.2f}  T={trades}  DD={dd:.2f}%  ({elapsed:.0f}s)  {mark}", flush=True)
            else:
                pf, trades, dd, profitable = 0, 0, 0, False
                print(f"  FAIL ({elapsed:.0f}s)", flush=True)

            print(format_oneliner(diag), flush=True)
            sym_results.append({"year": year, "pf": pf, "trades": trades, "dd": dd, "ok": profitable})
            all_results.append({"symbol": symbol, "label": winner["label"], "window": year,
                                 "pf": pf, "trades": trades, "dd": dd, "ok": profitable})

        # Cleanup
        tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_{tag}.set")
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

        annual = [r for r in sym_results if r["year"] != "Full"]
        full = next((r for r in sym_results if r["year"] == "Full"), None)
        ok_years = sum(1 for r in annual if r["ok"])
        print(f"\n  {symbol}: {ok_years}/4 annual windows profitable", flush=True)
        if full:
            print(f"  Full: PF={full['pf']:.2f}  T={full['trades']}  DD={full['dd']:.2f}%", flush=True)
        verdict = ok_years >= 3 and full and full["pf"] >= 1.1 and full["pf"] >= winner["baseline_pf"]
        print(f"  VERDICT: {'PASS ✓' if verdict else 'FAIL ✗'}", flush=True)

    # Save CSV
    if all_results:
        csv_file = "trailing_stop_crossyear_results.csv"
        with open(csv_file, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=all_results[0].keys())
            w.writeheader()
            w.writerows(all_results)

        print(f"\n\n{'='*70}", flush=True)
        print(f"  FINAL SUMMARY — TRAILING STOP CROSS-YEAR", flush=True)
        print(f"{'='*70}", flush=True)
        print(f"\n  {'Symbol':<10} {'Config':<18} {'2022':>6} {'2023':>6} {'2024':>6} {'2025':>6} {'Full PF':>8}", flush=True)
        print(f"  {'-'*60}", flush=True)
        for sym, _ in [x for x in [(s, f) for s, f in SYMBOLS] if x[0] in to_validate]:
            sym_rows = [r for r in all_results if r["symbol"] == sym]
            label = to_validate[sym]["label"]
            row_str = f"  {sym:<10} {label:<18}"
            for yr in ["2022", "2023", "2024", "2025"]:
                r = next((x for x in sym_rows if x["window"] == yr), None)
                if r:
                    mark = "✓" if r["ok"] else "✗"
                    row_str += f"  {r['pf']:.2f}{mark}"
                else:
                    row_str += f"  {'?':>5}"
            full_r = next((x for x in sym_rows if x["window"] == "Full"), None)
            if full_r:
                row_str += f"  {full_r['pf']:>8.2f}"
            print(row_str, flush=True)

        print(f"\n  Saved: {csv_file}", flush=True)


if __name__ == "__main__":
    main()
