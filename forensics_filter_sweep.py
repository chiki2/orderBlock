"""
Forensics Filter Sweep — XAUUSD
Tests the 6 new forensics-derived filters individually and in combos.
All filters were derived from 126-trade XAUUSD analysis (2022-2026).

Usage: python3 forensics_filter_sweep.py
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime, timedelta

BASE_DIR    = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC     = f"{BASE_DIR}/OBInclude/SetFiles/claude.set"
LAST_JSON   = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD  = f"{BASE_DIR}/docs/forensics_filter_results.md"
RESULTS_CSV = f"{BASE_DIR}/forensics_filter_results.csv"
BEST_SET    = f"{BASE_DIR}/OBInclude/SetFiles/forensics_best.set"

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
            print(f"  WARNING: param '{key}' not found in set file")
        content = new_content
    return content

def run_backtest():
    env = os.environ.copy()
    env["SYMBOL"]    = "XAUUSD"
    env["SET_FILE"]  = "claude.set"
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

def should_stop():
    now  = datetime.now()
    stop = now.replace(hour=STOP_HOUR, minute=0, second=0, microsecond=0)
    if stop <= now:
        stop += timedelta(days=1)
    return now >= stop

def log_result(run_id, label, params, data, elapsed):
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

    print(f"  → PF={pf}  Balance={bal:.2f}  Trades={tot}  WR={wr}  DD={dd}")
    return pf_v

def init_logs():
    header_md = f"""# Forensics Filter Sweep — XAUUSD
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')} — Stop at {STOP_HOUR:02d}:00*
*Base: XAUUSD M15 2022-2026, PF=4.67, 10T 70% WR, DD 10.53%*
*Goal: find which forensics filters improve PF/WR without killing too many trades*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
"""
    header_csv = "run_id,label,profit_factor,balance,max_dd_pct,traded,total_trades,win_rate,elapsed_s\n"
    with open(RESULTS_MD, "w") as f:
        f.write(header_md)
    with open(RESULTS_CSV, "w") as f:
        f.write(header_csv)

# Shorthand for boolean filters
T = "true||false||0||true||N"
F = "false||false||0||true||N"

def atr(v):   return f"{v}||0.0||0.1||10.0||N"
def maxrr(v): return f"{v}||0.0||0.1||10.0||N"

TEST_CASES = [
    # ── Baseline (all filters off) ─────────────────────────────────────
    ("baseline",        "Baseline (all forensics filters OFF)",          {}),

    # ── Single filter ON ──────────────────────────────────────────────
    # #56: Block Bull+Short (23% WR — highest efficiency 3.5x)
    ("f56_counter_htf", "#56 inpBlockCounterHTF=true",
     {"inpBlockCounterHTF": T}),

    # #57: Skip 09:00 UTC death zone (31% WR, 9 losses/13 trades)
    ("f57_09utc",       "#57 inpSkip09UTC=true",
     {"inpSkip09UTC": T}),

    # #58: Skip H4 inside bar (46% of losses vs 10% of wins)
    ("f58_h4inside",    "#58 inpSkipH4InsideBar=true",
     {"inpSkipH4InsideBar": T}),

    # #60: D1 wick rejection (p=0.014, most statistically significant)
    ("f60_d1wick",      "#60 inpD1WickFilter=true",
     {"inpD1WickFilter": T}),

    # #61: ATR minimum — test 3 thresholds
    # XAUUSD M15 ATR(18): typical range ~2-8 USD, ATR_max=8.2
    ("f61_atr10",       "#61 ATR_min=1.0 (skip very low vol)",
     {"ATR_min": atr("1.0")}),
    ("f61_atr20",       "#61 ATR_min=2.0",
     {"ATR_min": atr("2.0")}),
    ("f61_atr30",       "#61 ATR_min=3.0",
     {"ATR_min": atr("3.0")}),

    # #63: R:R max cap — test 3 thresholds
    # Loss mean R:R=2.84, win mean R:R=1.85; extreme >4 = very tight SL
    ("f63_rr30",        "#63 inpMaxRR=3.0 (cap extreme R:R)",
     {"inpMaxRR": maxrr("3.0")}),
    ("f63_rr40",        "#63 inpMaxRR=4.0",
     {"inpMaxRR": maxrr("4.0")}),
    ("f63_rr50",        "#63 inpMaxRR=5.0",
     {"inpMaxRR": maxrr("5.0")}),

    # ── Two-filter combos ─────────────────────────────────────────────
    # Best single filters combined (ranked by forensics efficiency)
    ("c56_60",          "#56 CounterHTF + #60 D1Wick",
     {"inpBlockCounterHTF": T, "inpD1WickFilter": T}),

    ("c56_58",          "#56 CounterHTF + #58 H4InsideBar",
     {"inpBlockCounterHTF": T, "inpSkipH4InsideBar": T}),

    ("c58_60",          "#58 H4InsideBar + #60 D1Wick",
     {"inpSkipH4InsideBar": T, "inpD1WickFilter": T}),

    ("c57_60",          "#57 09UTC + #60 D1Wick",
     {"inpSkip09UTC": T, "inpD1WickFilter": T}),

    ("c61_rr",          "#61 ATR_min=2.0 + #63 MaxRR=4.0",
     {"ATR_min": atr("2.0"), "inpMaxRR": maxrr("4.0")}),

    # ── Three-filter combos ───────────────────────────────────────────
    ("c56_58_60",       "#56 + #58 + #60 (top 3 by efficiency)",
     {"inpBlockCounterHTF": T, "inpSkipH4InsideBar": T, "inpD1WickFilter": T}),

    ("c56_57_60",       "#56 + #57 + #60",
     {"inpBlockCounterHTF": T, "inpSkip09UTC": T, "inpD1WickFilter": T}),

    ("c_all_bool",      "All 4 boolean filters ON",
     {"inpBlockCounterHTF": T, "inpSkip09UTC": T,
      "inpSkipH4InsideBar": T, "inpD1WickFilter": T}),

    # ── Full stack ────────────────────────────────────────────────────
    ("c_full_stack",    "All 4 booleans + ATR_min=2.0 + MaxRR=4.0",
     {"inpBlockCounterHTF": T, "inpSkip09UTC": T,
      "inpSkipH4InsideBar": T, "inpD1WickFilter": T,
      "ATR_min": atr("2.0"), "inpMaxRR": maxrr("4.0")}),
]

def main():
    print(f"\n{'='*55}")
    print(f"  Forensics Filter Sweep — XAUUSD")
    print(f"  Stop time: {STOP_HOUR:02d}:00  |  Tests: {len(TEST_CASES)}")
    print(f"  Base: PF=4.67, 10T 70% WR, DD 10.53%")
    print(f"{'='*55}\n")

    init_logs()
    base_content = read_set()
    best_pf    = 0.0
    best_label = "none"

    for i, (run_id, label, params) in enumerate(TEST_CASES):
        if should_stop():
            print(f"\n⏰ Stop time {STOP_HOUR:02d}:00 reached — exiting.")
            break

        now_str = datetime.now().strftime("%H:%M")
        print(f"\n[{i+1}/{len(TEST_CASES)}] {now_str} — {label}")
        print(f"  Params: {params if params else '(baseline)'}")

        content = apply_params(base_content, params)
        write_set(content)

        t0      = time.time()
        rc      = run_backtest()
        elapsed = time.time() - t0

        if rc != 0:
            print(f"  ⚠️  backtest.sh exited with code {rc}")

        data  = read_results()
        pf_v  = log_result(i+1, label, params, data, elapsed)

        if pf_v > best_pf:
            best_pf    = pf_v
            best_label = label
            with codecs.open(SET_SRC, "r", "utf-16") as f:
                best_content = f.read()
            with codecs.open(BEST_SET, "w", "utf-16") as f:
                f.write(best_content)
            print(f"  🏆 New best: PF={pf_v:.2f} saved to forensics_best.set")

    write_set(base_content)

    summary = f"""
---
## Summary
- **Baseline**: PF=4.67, 10T, 70% WR, DD 10.53%
- **Best**: PF={best_pf:.2f} — {best_label}
- **Best set**: `OBInclude/SetFiles/forensics_best.set`
- **Completed**: {datetime.now().strftime('%Y-%m-%d %H:%M')}

### Interpretation guide
- PF improvement with fewer trades = filter removes losses cleanly
- PF drops with fewer trades = filter also removes wins
- Trade count drop > 50% = filter too aggressive for XAUUSD (already sparse)
"""
    with open(RESULTS_MD, "a") as f:
        f.write(summary)

    print(f"\n{'='*55}")
    print(f"  DONE — Best: PF={best_pf:.2f} ({best_label})")
    print(f"  Results: docs/forensics_filter_results.md")
    print(f"  Best set: OBInclude/SetFiles/forensics_best.set")
    print(f"{'='*55}\n")

if __name__ == "__main__":
    main()
