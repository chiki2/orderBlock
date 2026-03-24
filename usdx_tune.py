"""
USDX Parameter Tuning Sweep.
Symbol confirmed: 'USDX' on Fusion Markets. Baseline: 6T, 0% WR.
Dollar Index trades ~100-105, daily range ~0.3-0.8 pts, M15 ATR ~0.05-0.15.
Default claude.set settings (ATR_max=8.2, fibo1rstTP=1.27) are mismatched.
Goal: find settings that produce positive PF trades.
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime, timedelta

BASE_DIR    = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC     = f"{BASE_DIR}/OBInclude/SetFiles/usdx.set"
LAST_JSON   = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD  = f"{BASE_DIR}/docs/usdx_tune_results.md"
RESULTS_CSV = f"{BASE_DIR}/usdx_tune_results.csv"
BEST_SET    = f"{BASE_DIR}/OBInclude/SetFiles/usdx_best.set"

STOP_HOUR = 23
FROM_DATE = "2022.01.01"
TO_DATE   = "2026.01.01"

def read_set():
    with codecs.open(SET_SRC, "r", "utf-16") as f:
        return f.read()

def write_set(content):
    with codecs.open(SET_SRC, "w", "utf-16") as f:
        f.write(content)

def apply_params(base_content, params):
    content = base_content
    for key, value in params.items():
        pattern = rf"^({re.escape(key)}=).*$"
        replacement = rf"\g<1>{value}"
        new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        if new_content == content:
            print(f"  WARNING: param '{key}' not found in set file", flush=True)
        content = new_content
    return content

def run_backtest():
    env = os.environ.copy()
    env["SYMBOL"]    = "USDX"
    env["SET_FILE"]  = "usdx.set"
    env["FROM_DATE"] = FROM_DATE
    env["TO_DATE"]   = TO_DATE
    result = subprocess.run(
        ["bash", "backtest.sh"],
        cwd=BASE_DIR, env=env,
        capture_output=True, text=True, timeout=1800
    )
    return result.returncode

def read_results():
    try:
        with open(LAST_JSON) as f:
            return json.load(f)
    except Exception as e:
        return {"error": str(e)}

def should_stop():
    now  = datetime.now()
    stop = now.replace(hour=STOP_HOUR, minute=0, second=0, microsecond=0)
    if stop <= now:
        stop += timedelta(days=1)
    return now >= stop

def log_result(run_id, label, data, elapsed):
    pf   = data.get("profit_factor", "n/a")
    bal  = data.get("balance", 0)
    dd   = data.get("max_dd_pct", "n/a")
    trd  = data.get("traded", 0)
    tot  = data.get("total_trades", "n/a")
    wr   = data.get("win_rate_str", "n/a")
    pf_v = float(str(pf).split()[0]) if pf != "n/a" else 0

    line_csv = f'{run_id},"{label}",{pf},{bal},{dd},{trd},{tot},"{wr}",{elapsed:.0f}'
    with open(RESULTS_CSV, "a") as f:
        f.write(line_csv + "\n")

    emoji = "✅" if pf_v >= 1.5 else ("⚠️" if pf_v >= 1.0 else "❌")
    line_md = f"| {run_id} | {label} | {pf} | {bal:.2f} | {dd} | {trd} | {tot} | {wr} | {elapsed:.0f}s | {emoji} |"
    with open(RESULTS_MD, "a") as f:
        f.write(line_md + "\n")

    print(f"  → PF={pf}  Balance={bal:.2f}  Trades={tot}  WR={wr}  DD={dd}", flush=True)
    return pf_v

def init_logs():
    header_md = f"""# USDX Parameter Tuning
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')} — Stop at {STOP_HOUR:02d}:00*
*Base: USDX, KZ=08-12+13-17 UTC, claude.set adapted, 2022-2026*
*Probe result: 6T, 0% WR — default params mismatched for DXY price/ATR range*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
"""
    header_csv = "run_id,label,profit_factor,balance,max_dd_pct,traded,total_trades,win_rate,elapsed_s\n"
    with open(RESULTS_MD, "w") as f:
        f.write(header_md)
    with open(RESULTS_CSV, "w") as f:
        f.write(header_csv)

# USDX M15 ATR is ~0.05-0.15 pts (vs XAUUSD ~3-8 USD)
# ATR_max=8.2 effectively disabled — needs to be ~0.3 to filter high-vol
# minBodySize / minImBalanced / tolerance are in points — need scaling down
# fibo1rstTP=1.27 may be fine (ratio-based)

def atr_max(v): return f"{v}||8.2||0.820000||82.000000||N"
def tp(v): return f"{v}||1.27||0.127000||12.700000||N"

TEST_CASES = [
    # Baseline — same as probe
    ("baseline",       "Baseline (default claude.set params)",         {}),

    # Fix ATR_max for USDX range — most critical
    ("atr_max_03",     "ATR_max=0.3 (USDX M15 high vol filter)",       {"ATR_max": atr_max("0.3")}),
    ("atr_max_05",     "ATR_max=0.5",                                   {"ATR_max": atr_max("0.5")}),
    ("atr_max_10",     "ATR_max=1.0 (effectively off for USDX)",       {"ATR_max": atr_max("1.0")}),

    # STOP orders — DXY is trend-following, STOP might work better
    ("stop_orders",    "STOP orders (typeofOrder=2)",                   {"typeofOrder": "2||1||0||2||N"}),
    ("stop_tp200",     "STOP + tp=2.0",                                 {"typeofOrder": "2||1||0||2||N",
                                                                          "fibo1rstTP": tp("2.0")}),

    # Relax trend filters — DXY may not respect D1 the same way
    ("d1_off",         "D1Trend=false",                                 {"inpRequireD1Trend": "false||false||0||true||N"}),
    ("macro_off",      "MacroTrend=false",                              {"inpMacroTrendEnabled": "false||false||0||true||N"}),

    # TP variants on LIMIT
    ("tp_200",         "LIMIT + tp=2.0",                               {"fibo1rstTP": tp("2.0")}),
    ("tp_300",         "LIMIT + tp=3.0",                               {"fibo1rstTP": tp("3.0")}),

    # Combo: ATR fix + best TP
    ("atr03_tp200",    "ATR_max=0.3 + tp=2.0",                        {"ATR_max": atr_max("0.3"),
                                                                          "fibo1rstTP": tp("2.0")}),
    ("atr03_stop",     "ATR_max=0.3 + STOP",                           {"ATR_max": atr_max("0.3"),
                                                                          "typeofOrder": "2||1||0||2||N"}),
    ("atr03_d1off",    "ATR_max=0.3 + D1=false",                       {"ATR_max": atr_max("0.3"),
                                                                          "inpRequireD1Trend": "false||false||0||true||N"}),
]

def main():
    print(f"\n{'='*55}", flush=True)
    print(f"  USDX Parameter Tuning", flush=True)
    print(f"  Stop time: {STOP_HOUR:02d}:00  |  Tests: {len(TEST_CASES)}", flush=True)
    print(f"  Note: symbol USDX confirmed on Fusion Markets", flush=True)
    print(f"{'='*55}\n", flush=True)

    init_logs()
    base_content = read_set()
    best_pf    = 0.0
    best_label = "none"

    for i, (run_id, label, params) in enumerate(TEST_CASES):
        if should_stop():
            print(f"\n⏰ Stop time {STOP_HOUR:02d}:00 reached — exiting.", flush=True)
            break

        now_str = datetime.now().strftime("%H:%M")
        print(f"\n[{i+1}/{len(TEST_CASES)}] {now_str} — {label}", flush=True)

        content = apply_params(base_content, params)
        write_set(content)

        t0      = time.time()
        rc      = run_backtest()
        elapsed = time.time() - t0

        if rc != 0:
            print(f"  ⚠️  backtest.sh rc={rc}", flush=True)

        data  = read_results()
        pf_v  = log_result(i+1, label, data, elapsed)

        if pf_v > best_pf:
            best_pf    = pf_v
            best_label = label
            with codecs.open(SET_SRC, "r", "utf-16") as f:
                best_content = f.read()
            with codecs.open(BEST_SET, "w", "utf-16") as f:
                f.write(best_content)
            print(f"  🏆 New best: PF={pf_v:.2f} → usdx_best.set", flush=True)

    write_set(base_content)

    summary = f"""
---
## Summary
- **Best PF**: {best_pf:.2f} — {best_label}
- **Best set**: `OBInclude/SetFiles/usdx_best.set`
- **Completed**: {datetime.now().strftime('%Y-%m-%d %H:%M')}
"""
    with open(RESULTS_MD, "a") as f:
        f.write(summary)

    print(f"\n{'='*55}", flush=True)
    print(f"  DONE — Best: PF={best_pf:.2f} ({best_label})", flush=True)
    print(f"  Results: docs/usdx_tune_results.md", flush=True)
    print(f"{'='*55}\n", flush=True)

if __name__ == "__main__":
    main()
