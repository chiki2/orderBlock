"""
Cross-year validation — runs each winner set file across 5 annual windows.
Symbols: EURUSD (FVG=true), GBPUSD (FVG=true), USDJPY (tp=3.0), XAUUSD (Skip09UTC)
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime

BASE_DIR  = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
LAST_JSON = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD  = f"{BASE_DIR}/docs/cross_year_results.md"
RESULTS_CSV = f"{BASE_DIR}/cross_year_results.csv"

YEARS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("OOS",  "2026.01.01", "2026.04.01"),
]

SYMBOLS = [
    ("EURUSD",  "eurusd.set"),
    ("GBPUSD",  "gbpusd.set"),
    ("USDJPY",  "usdjpy.set"),
    ("XAUUSD",  "claude.set"),
]

def run_backtest(symbol, set_file, from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"]    = symbol
    env["SET_FILE"]  = set_file
    env["FROM_DATE"] = from_date
    env["TO_DATE"]   = to_date
    result = subprocess.run(
        ["bash", "backtest.sh"], cwd=BASE_DIR, env=env,
        capture_output=True, text=True, timeout=900
    )
    return result.returncode

def read_results():
    try:
        with open(LAST_JSON) as f: return json.load(f)
    except Exception as e: return {"error": str(e)}

def init_logs():
    header_md = f"""# Cross-Year Validation
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')}*
*Winners: EURUSD FVG=true | GBPUSD FVG=true | USDJPY tp=3.0 | XAUUSD Skip09UTC*

| Symbol | Year | PF | Balance | DD% | Trades | WR | Time |
|---|---|---|---|---|---|---|---|
"""
    with open(RESULTS_MD, "w") as f: f.write(header_md)
    with open(RESULTS_CSV, "w") as f:
        f.write("symbol,year,profit_factor,balance,max_dd_pct,total_trades,win_rate,elapsed_s\n")

def log_result(symbol, year, data, elapsed):
    pf  = data.get("profit_factor", "n/a")
    bal = data.get("balance", 0)
    dd  = data.get("max_dd_pct", "n/a")
    tot = data.get("total_trades", "n/a")
    wr  = data.get("win_rate_str", "n/a")
    pf_v = float(str(pf).split()[0]) if pf != "n/a" else 0
    with open(RESULTS_CSV, "a") as f:
        f.write(f'{symbol},{year},{pf},{bal},{dd},{tot},"{wr}",{elapsed:.0f}\n')
    emoji = "✅" if pf_v >= 1.5 else ("⚠️" if pf_v >= 1.0 else "❌")
    with open(RESULTS_MD, "a") as f:
        f.write(f"| {symbol} | {year} | {pf} | {bal:.2f} | {dd} | {tot} | {wr} | {elapsed:.0f}s | {emoji} |\n")
    print(f"  → PF={pf}  Balance={bal:.2f}  Trades={tot}  WR={wr}  DD={dd}", flush=True)
    return pf_v

def main():
    total = len(SYMBOLS) * len(YEARS)
    print(f"\n{'='*55}", flush=True)
    print(f"  Cross-Year Validation — {total} backtests", flush=True)
    print(f"  4 symbols × 5 windows (2022-2025 + OOS 2026)", flush=True)
    print(f"{'='*55}\n", flush=True)

    init_logs()
    n = 0
    for symbol, set_file in SYMBOLS:
        print(f"\n── {symbol} ({set_file}) ──────────────────", flush=True)
        with open(RESULTS_MD, "a") as f:
            f.write(f"| **{symbol}** | | | | | | | |\n")
        for year_label, from_date, to_date in YEARS:
            n += 1
            print(f"\n[{n}/{total}] {datetime.now().strftime('%H:%M')} — {symbol} {year_label}", flush=True)
            t0 = time.time()
            rc = run_backtest(symbol, set_file, from_date, to_date)
            elapsed = time.time() - t0
            if rc != 0: print(f"  ⚠️  exit code {rc}", flush=True)
            data = read_results()
            log_result(symbol, year_label, data, elapsed)

    with open(RESULTS_MD, "a") as f:
        f.write(f"\n---\n*Completed: {datetime.now().strftime('%Y-%m-%d %H:%M')}*\n")
    print(f"\n{'='*55}", flush=True)
    print(f"  DONE — Results: docs/cross_year_results.md", flush=True)
    print(f"{'='*55}\n", flush=True)

if __name__ == "__main__":
    main()
