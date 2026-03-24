#!/usr/bin/env python3
"""Quick cross-year revalidation for EURJPY with tolerance=80 applied."""
import subprocess, json, time, os, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

WINDOWS = [
    ("2022", "2022.01.01", "2022.12.31"),
    ("2023", "2023.01.01", "2023.12.31"),
    ("2024", "2024.01.01", "2024.12.31"),
    ("2025", "2025.01.01", "2025.12.31"),
    ("OOS 2026", "2026.01.01", "2026.03.24"),
]


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


def run_backtest(from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"] = "EURJPY"
    env["SET_FILE"] = "eurjpy.set"
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
    print(f"\n{'='*65}", flush=True)
    print(f"  EURJPY Cross-Year (tolerance=80) -- 5 windows", flush=True)
    print(f"{'='*65}\n", flush=True)

    results = []
    for idx, (label, from_d, to_d) in enumerate(WINDOWS, 1):
        ts = datetime.now().strftime("%H:%M")
        print(f"\n[{idx}/5] {ts} -- {label} ({from_d} -> {to_d})", flush=True)

        t0 = time.time()
        result = run_backtest(from_d, to_d)
        elapsed = time.time() - t0

        diag = scan_last_backtest()

        if result:
            pf = parse_pf(result.get("profit_factor", 0))
            trades = result.get("traded", 0) or 0
            wr = result.get("win_rate_str", "n/a")
            dd = parse_dd(result.get("max_dd_pct", 0))
            print(f"  -> PF={pf:<6.2f}  Trades={trades:<4}  WR={wr}  DD={dd:.2f}%  ({elapsed:.0f}s)", flush=True)
        else:
            pf, trades, wr, dd = 0, 0, "FAIL", 0
            print(f"  -> FAIL ({elapsed:.0f}s)", flush=True)

        print(format_oneliner(diag), flush=True)
        results.append((label, pf, trades, dd))

    # Summary
    print(f"\n{'='*65}", flush=True)
    print(f"  EURJPY Summary (tolerance=80)", flush=True)
    print(f"  {'Year':<12} {'PF':<8} {'Trades':<8} {'DD%':<8}", flush=True)
    profitable = 0
    for label, pf, trades, dd in results:
        marker = "+" if pf > 1.0 else "-"
        print(f"  {marker} {label:<10} {pf:<8.2f} {trades:<8} {dd:<8.2f}", flush=True)
        if pf > 1.0:
            profitable += 1
    print(f"\n  Result: {profitable}/5 profitable windows", flush=True)
    print(f"{'='*65}", flush=True)


if __name__ == "__main__":
    main()
