"""
USDX Order Cancellation Fix Sweep.
User observed many order cancels in MT5 backtester for USDX.
Root cause: LIMIT orders placed but cancelled before filling due to:
  1. outdatedOB=80 too short (80 × M15 = 20h — USDX retraces slowly)
  2. hasOppositeOB() in cOrderBlock.mqh:107 — when price moves away and
     a new opposite-direction OB with stars>=3 forms, pending LIMIT is
     cancelled via CancelPendingIfExists(). No input to disable this.
Note: maxGain is a STALE parameter — not in EA code, has zero effect.
Strategy: MacroTrend=false is confirmed unlock (PF=1.41, 15T).
Now test outdatedOB (200/300/400), tolerance variants, and STOP orders.
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime, timedelta

BASE_DIR    = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC     = f"{BASE_DIR}/OBInclude/SetFiles/usdx.set"
LAST_JSON   = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD  = f"{BASE_DIR}/docs/usdx_cancel_results.md"
RESULTS_CSV = f"{BASE_DIR}/usdx_cancel_results.csv"
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
    header_md = f"""# USDX Order Cancel Fix Sweep
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')} — Stop at {STOP_HOUR:02d}:00*
*Motivation: many order cancels observed — two root causes identified:*
*  1. outdatedOB=80×15min=20h too short for slowly-retracing USDX*
*  2. hasOppositeOB() (cOrderBlock.mqh:107) cancels pending when opposite OB (stars>=3) forms*
*Base: MacroTrend=false confirmed as unlock (PF=1.41, 15T, 40% WR)*
*All tests use MacroTrend=false as baseline*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
"""
    header_csv = "run_id,label,profit_factor,balance,max_dd_pct,traded,total_trades,win_rate,elapsed_s\n"
    with open(RESULTS_MD, "w") as f:
        f.write(header_md)
    with open(RESULTS_CSV, "w") as f:
        f.write(header_csv)

MACRO_OFF = "false||false||0||true||N"
T = "true||false||0||true||N"
F = "false||false||0||true||N"
STOP = "2||1||0||2||N"
def tp(v):  return f"{v}||1.27||0.127000||12.700000||N"
def ob(v):  return f"{v}||80||1||800||N"
def tol(v): return f"{v}||50||1||500||N"

TEST_CASES = [
    # Baseline — MacroTrend=false only (confirmed PF=1.41)
    ("macro_baseline",    "MacroTrend=false (baseline)",
     {"inpMacroTrendEnabled": MACRO_OFF}),

    # ── Fix 1: outdatedOB — give LIMIT orders more time to fill ──────────
    # Root cause: 80×15min=20h expiry too short; USDX retraces slowly
    ("ob160_macro",       "MacroOff + outdatedOB=160 (40h)",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(160)}),
    ("ob200_macro",       "MacroOff + outdatedOB=200 (50h)",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(200)}),
    ("ob300_macro",       "MacroOff + outdatedOB=300 (75h)",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(300)}),
    ("ob400_macro",       "MacroOff + outdatedOB=400 (100h)",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(400)}),

    # ── Fix 2: tolerance — widen zone for slower price action ────────────
    # Root cause: hasOppositeOB() cancels when opposite OB forms (stars>=3)
    # Wider tolerance = price "reaches" zone sooner before opposite OB forms
    ("tol60_macro",       "MacroOff + tolerance=60",
     {"inpMacroTrendEnabled": MACRO_OFF, "tolerance": tol(60)}),
    ("tol80_macro",       "MacroOff + tolerance=80",
     {"inpMacroTrendEnabled": MACRO_OFF, "tolerance": tol(80)}),
    ("tol100_macro",      "MacroOff + tolerance=100",
     {"inpMacroTrendEnabled": MACRO_OFF, "tolerance": tol(100)}),

    # ── Fix 3: Combined outdatedOB + tolerance ───────────────────────────
    ("ob200_tol60_macro", "MacroOff + ob=200 + tol=60",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(200), "tolerance": tol(60)}),
    ("ob300_tol80_macro", "MacroOff + ob=300 + tol=80",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(300), "tolerance": tol(80)}),

    # ── Fix 4: STOP orders — fill on breakout, no retracement needed ─────
    ("stop_macro",        "MacroOff + STOP orders",
     {"inpMacroTrendEnabled": MACRO_OFF, "typeofOrder": STOP}),
    ("stop_tp150_macro",  "MacroOff + STOP + tp=1.5",
     {"inpMacroTrendEnabled": MACRO_OFF, "typeofOrder": STOP, "fibo1rstTP": tp("1.5")}),
    ("stop_tp200_macro",  "MacroOff + STOP + tp=2.0",
     {"inpMacroTrendEnabled": MACRO_OFF, "typeofOrder": STOP, "fibo1rstTP": tp("2.0")}),
    ("stop_tp300_macro",  "MacroOff + STOP + tp=3.0",
     {"inpMacroTrendEnabled": MACRO_OFF, "typeofOrder": STOP, "fibo1rstTP": tp("3.0")}),

    # ── Best combos ───────────────────────────────────────────────────────
    ("ob200_stop_tp200",  "MacroOff + ob=200 + STOP + tp=2.0",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(200),
      "typeofOrder": STOP, "fibo1rstTP": tp("2.0")}),
    ("ob300_stop_tp150",  "MacroOff + ob=300 + STOP + tp=1.5",
     {"inpMacroTrendEnabled": MACRO_OFF, "outdatedOB": ob(300),
      "typeofOrder": STOP, "fibo1rstTP": tp("1.5")}),
]

def main():
    print(f"\n{'='*60}", flush=True)
    print(f"  USDX Order Cancel Fix Sweep — {len(TEST_CASES)} tests", flush=True)
    print(f"  Stop: {STOP_HOUR:02d}:00", flush=True)
    print(f"  Root cause 1: outdatedOB=80×15min=20h too short for USDX", flush=True)
    print(f"  Root cause 2: hasOppositeOB() cancels pending on opposite OB", flush=True)
    print(f"  Fix: longer outdatedOB + wider tolerance + STOP orders", flush=True)
    print(f"{'='*60}\n", flush=True)

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

    print(f"\n{'='*60}", flush=True)
    print(f"  DONE — Best: PF={best_pf:.2f} ({best_label})", flush=True)
    print(f"  Results: docs/usdx_cancel_results.md", flush=True)
    print(f"{'='*60}\n", flush=True)

if __name__ == "__main__":
    main()
