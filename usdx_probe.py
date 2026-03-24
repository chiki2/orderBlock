"""
Dollar Index (USDX) Probe — baseline backtest to check if symbol is available
and see initial trading behavior.

NOTE: Symbol name varies by broker:
  Fusion Markets: likely "USDX" or "DXY" — script tries USDX first.
  If 0 trades and no error, try DXY by setting SYMBOL_NAME below.

Usage: python3 usdx_probe.py
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime

BASE_DIR  = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC   = f"{BASE_DIR}/OBInclude/SetFiles/usdx.set"
LAST_JSON = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD = f"{BASE_DIR}/docs/usdx_probe_results.md"

# Try these symbol names in order — stop on first that produces trades
SYMBOL_NAMES = ["USDX", "DXY", "DX", "DOLLAR"]

FROM_DATE = "2022.01.01"
TO_DATE   = "2026.01.01"

def read_set():
    with codecs.open(SET_SRC, "r", "utf-16") as f:
        return f.read()

def write_set(content):
    with codecs.open(SET_SRC, "w", "utf-16") as f:
        f.write(content)

def run_backtest(symbol):
    env = os.environ.copy()
    env["SYMBOL"]    = symbol
    env["SET_FILE"]  = "usdx.set"
    env["FROM_DATE"] = FROM_DATE
    env["TO_DATE"]   = TO_DATE
    result = subprocess.run(
        ["bash", "backtest.sh"],
        cwd=BASE_DIR, env=env,
        capture_output=True, text=True, timeout=900
    )
    return result.returncode

def read_results():
    try:
        with open(LAST_JSON) as f:
            return json.load(f)
    except Exception as e:
        return {"error": str(e)}

def main():
    print(f"\n{'='*55}", flush=True)
    print(f"  Dollar Index (USDX) Probe", flush=True)
    print(f"  Trying symbols: {SYMBOL_NAMES}", flush=True)
    print(f"  Period: {FROM_DATE} → {TO_DATE}", flush=True)
    print(f"{'='*55}\n", flush=True)

    with open(RESULTS_MD, "w") as f:
        f.write(f"# Dollar Index (USDX) Probe Results\n")
        f.write(f"*{datetime.now().strftime('%Y-%m-%d %H:%M')}*\n\n")
        f.write(f"| Symbol | PF | Trades | WR | DD% | Balance | Notes |\n")
        f.write(f"|---|---|---|---|---|---|---|\n")

    for symbol in SYMBOL_NAMES:
        print(f"\n[Testing symbol: {symbol}]", flush=True)

        t0 = time.time()
        rc = run_backtest(symbol)
        elapsed = time.time() - t0

        data = read_results()
        pf   = data.get("profit_factor", "n/a")
        tot  = data.get("total_trades", "n/a")
        wr   = data.get("win_rate_str", "n/a")
        dd   = data.get("max_dd_pct", "n/a")
        bal  = data.get("balance", 0)
        err  = data.get("error", "")

        print(f"  rc={rc}  PF={pf}  Trades={tot}  WR={wr}  DD={dd}  ({elapsed:.0f}s)", flush=True)
        if err:
            print(f"  ERROR: {err}", flush=True)

        note = f"rc={rc}" if rc != 0 else ("no data" if err else "ok")
        with open(RESULTS_MD, "a") as f:
            f.write(f"| {symbol} | {pf} | {tot} | {wr} | {dd} | {bal:.2f} | {note} |\n")

        # If we got trades, this is the right symbol name — stop
        tot_int = 0
        try:
            tot_int = int(str(tot).split()[0])
        except:
            pass

        if tot_int > 0:
            print(f"\n  ✅ Symbol '{symbol}' produced {tot_int} trades — this is the correct name!", flush=True)
            with open(RESULTS_MD, "a") as f:
                f.write(f"\n**✅ Working symbol: `{symbol}`** — {tot_int} trades\n")
            break
        else:
            print(f"  No trades for '{symbol}' — trying next...", flush=True)

    else:
        print(f"\n  ❌ No symbol name produced trades.", flush=True)
        print(f"  Dollar Index may not be available on this broker account.", flush=True)
        with open(RESULTS_MD, "a") as f:
            f.write(f"\n**❌ Dollar Index not available** — no symbol name produced trades.\n")
            f.write(f"Check MT5 Market Watch for available index symbols.\n")

    print(f"\n  Results: {RESULTS_MD}", flush=True)
    print(f"{'='*55}\n", flush=True)

if __name__ == "__main__":
    main()
