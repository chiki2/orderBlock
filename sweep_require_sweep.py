"""
XAUUSD inpRequireSweep=false test — single backtest to see raw trade count impact.
inpRequireSweep gates checkLiquiditySweepBeforeOB(); disabling it removes the strictest filter.
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime

BASE_DIR  = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC   = f"{BASE_DIR}/OBInclude/SetFiles/claude.set"
LAST_JSON = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD = f"{BASE_DIR}/docs/require_sweep_results.md"

FROM_DATE = "2022.01.01"
TO_DATE   = "2026.01.01"

def read_set():
    with codecs.open(SET_SRC, "r", "utf-16") as f:
        return f.read()

def write_set(content):
    with codecs.open(SET_SRC, "w", "utf-16") as f:
        f.write(content)

def apply_param(content, key, value):
    pattern = rf"^({re.escape(key)}=).*$"
    new = re.sub(pattern, rf"\g<1>{value}", content, flags=re.MULTILINE)
    if new == content:
        print(f"  WARNING: '{key}' not found in set file", flush=True)
    return new

def run_backtest(symbol="XAUUSD", set_file="claude.set"):
    env = os.environ.copy()
    env["SYMBOL"]    = symbol
    env["SET_FILE"]  = set_file
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
    print(f"  XAUUSD inpRequireSweep Test", flush=True)
    print(f"  Base: PF=357, 9T (Skip09UTC ON)", flush=True)
    print(f"  Goal: see trade count without sweep requirement", flush=True)
    print(f"{'='*55}\n", flush=True)

    base_content = read_set()

    with open(RESULTS_MD, "w") as f:
        f.write(f"# XAUUSD inpRequireSweep=false Test\n")
        f.write(f"*{datetime.now().strftime('%Y-%m-%d %H:%M')}*\n")
        f.write(f"*Base: XAUUSD M15 2022-2026, inpSkip09UTC=true*\n\n")
        f.write(f"| Test | PF | Trades | WR | DD% | Notes |\n")
        f.write(f"|---|---|---|---|---|---|\n")

    tests = [
        ("baseline",     "Baseline (inpRequireSweep=true)",  {}),
        ("sweep_false",  "inpRequireSweep=false",            {"inpRequireSweep": "false||false||0||true||N"}),
    ]

    for run_id, label, params in tests:
        print(f"\n[{run_id}] {label}", flush=True)
        content = base_content
        for k, v in params.items():
            content = apply_param(content, k, v)
        write_set(content)

        t0 = time.time()
        rc = run_backtest()
        elapsed = time.time() - t0

        if rc != 0:
            print(f"  WARNING: backtest.sh rc={rc}", flush=True)

        data = read_results()
        pf   = data.get("profit_factor", "n/a")
        tot  = data.get("total_trades", "n/a")
        wr   = data.get("win_rate_str", "n/a")
        dd   = data.get("max_dd_pct", "n/a")
        bal  = data.get("balance", 0)
        print(f"  → PF={pf}  Trades={tot}  WR={wr}  DD={dd}  ({elapsed:.0f}s)", flush=True)

        with open(RESULTS_MD, "a") as f:
            f.write(f"| {label} | {pf} | {tot} | {wr} | {dd} | {elapsed:.0f}s |\n")

    write_set(base_content)
    print(f"\n  Restored claude.set.", flush=True)
    print(f"  Results: {RESULTS_MD}", flush=True)
    print(f"{'='*55}\n", flush=True)

if __name__ == "__main__":
    main()
