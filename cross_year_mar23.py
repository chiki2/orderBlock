#!/usr/bin/env python3
"""
Cross-year validation for all symbols.
5 windows per symbol: 2022, 2023, 2024, 2025, OOS 2026.
"""
import subprocess, json, time, csv, os, sys
from datetime import datetime
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)

TIMEOUT = 1800
STOP_HOUR = 8  # stop at 8 AM to hand off to user

WINDOWS = [
    ("2022",     "2022.01.01", "2022.12.31"),
    ("2023",     "2023.01.01", "2023.12.31"),
    ("2024",     "2024.01.01", "2024.12.31"),
    ("2025",     "2025.01.01", "2025.12.31"),
    ("OOS 2026", "2026.01.01", "2026.03.23"),
]

SYMBOLS = [
    ("EURJPY", "eurjpy.set", "EURJPY"),
    ("USDX",   "usdx.set",   "USDX"),
    ("USDJPY", "usdjpy.set",  "USDJPY"),
    ("GBPUSD", "gbpusd.set",  "GBPUSD"),
    ("GBPJPY", "gbpjpy.set",  "GBPJPY"),
    ("AUDJPY", "audjpy.set",  "AUDJPY"),
    ("XAUUSD", "claude.set",  "XAUUSD"),
]

CSV_FILE = "cross_year_results.csv"


def parse_pf(val):
    """Parse profit_factor from JSON (can be string or number)."""
    try:
        return float(val)
    except (TypeError, ValueError):
        return 0.0


def parse_dd(val):
    """Parse max_dd_pct — format is '1.97% 198.89' or just a number."""
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


def run_backtest(symbol_name, set_file, from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"] = symbol_name
    env["SET_FILE"] = set_file
    env["FROM_DATE"] = from_date
    env["TO_DATE"] = to_date
    env["DISPLAY"] = ":0"  # ensure wine can run under nohup

    # Remove stale JSON so we know if this test produced output
    json_path = os.path.join(BASE, "backtest_last.json")
    if os.path.exists(json_path):
        os.remove(json_path)

    clear_log()

    r = subprocess.run(["bash", "backtest.sh"], capture_output=True, text=True,
                       timeout=TIMEOUT, env=env)

    if not os.path.exists(json_path):
        return None

    try:
        with open(json_path) as f:
            return json.load(f)
    except Exception:
        return None


def fmt(result):
    if not result:
        return "FAIL"
    pf = parse_pf(result.get("profit_factor", 0))
    trades = result.get("traded", 0) or 0
    wr_str = result.get("win_rate_str", "n/a")
    dd = parse_dd(result.get("max_dd_pct", 0))
    bal = result.get("balance", 0) or 0
    return f"PF={pf:<6.2f}  Trades={trades:<4}  WR={wr_str}  DD={dd:.2f}%  Bal={bal:.2f}"


def should_stop():
    h = datetime.now().hour
    # Stop between STOP_HOUR and 12 (don't stop if still evening/night)
    return STOP_HOUR <= h < 12


def main():
    total = len(SYMBOLS) * len(WINDOWS)
    print(f"\n{'='*65}", flush=True)
    print(f"  Cross-Year Validation — {len(SYMBOLS)} symbols x {len(WINDOWS)} windows = {total} tests", flush=True)
    print(f"  Stop: {STOP_HOUR:02d}:00", flush=True)
    print(f"{'='*65}\n", flush=True)

    all_results = {}
    csv_rows = []
    idx = 0

    for sym_short, set_file, sym_broker in SYMBOLS:
        print(f"\n{'_'*65}", flush=True)
        print(f"  {sym_short} -- set file: {set_file}", flush=True)
        print(f"{'_'*65}", flush=True)

        sym_results = []
        for label, from_d, to_d in WINDOWS:
            if should_stop():
                print(f"\n  Stopping at {STOP_HOUR}:00", flush=True)
                break

            idx += 1
            t0 = time.time()
            ts = datetime.now().strftime("%H:%M")
            print(f"\n[{idx}/{total}] {ts} -- {sym_short} {label} ({from_d} -> {to_d})", flush=True)

            result = run_backtest(sym_broker, set_file, from_d, to_d)
            elapsed = time.time() - t0
            print(f"  -> {fmt(result)}  ({elapsed:.0f}s)", flush=True)

            # Log scanner
            diag = scan_last_backtest()
            print(format_oneliner(diag), flush=True)

            sym_results.append((label, result))

            # CSV row
            pf = parse_pf(result.get("profit_factor", 0)) if result else 0
            trades = result.get("traded", 0) if result else 0
            dd = parse_dd(result.get("max_dd_pct", 0)) if result else 0
            bal = result.get("balance", 0) if result else 0
            csv_rows.append({
                "symbol": sym_short, "window": label,
                "from": from_d, "to": to_d,
                "pf": pf, "trades": trades, "dd_pct": dd, "balance": bal,
                "log_summary": diag["summary"],
            })

        all_results[sym_short] = sym_results

        if should_stop():
            break

        # Print summary table for this symbol
        print(f"\n  {'_'*55}", flush=True)
        print(f"  {sym_short} Summary:", flush=True)
        print(f"  {'Year':<10} {'PF':<8} {'Trades':<8} {'WR':<16} {'DD%':<8}", flush=True)
        for label, r in sym_results:
            if r:
                pf = parse_pf(r.get('profit_factor', 0))
                trades = r.get('traded', 0) or 0
                wr = r.get('win_rate_str', 'n/a')
                dd = parse_dd(r.get('max_dd_pct', 0))
                print(f"  {label:<10} {pf:<8.2f} {trades:<8} {wr:<16} {dd:<8.2f}", flush=True)
            else:
                print(f"  {label:<10} FAIL", flush=True)

    # Save CSV
    if csv_rows:
        with open(CSV_FILE, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\n  CSV saved: {CSV_FILE}", flush=True)

    # Final comparison
    print(f"\n\n{'='*65}", flush=True)
    print(f"  CROSS-YEAR VALIDATION COMPLETE", flush=True)
    print(f"{'='*65}", flush=True)
    for sym_short, results in all_results.items():
        profitable = sum(1 for _, r in results
                        if r and parse_pf(r.get("profit_factor", 0)) > 1.0)
        total_w = len(results)
        print(f"\n  {sym_short}: {profitable}/{total_w} profitable windows", flush=True)
        for label, r in results:
            pf = parse_pf(r.get("profit_factor", 0)) if r else 0
            marker = "+" if pf > 1.0 else "-"
            print(f"    {marker} {label}: PF={pf:.2f}", flush=True)

    print(f"\n{'='*65}", flush=True)


if __name__ == "__main__":
    main()
