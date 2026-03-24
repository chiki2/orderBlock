"""
USDX Full Parameter Sweep.
Symbol: USDX on Fusion Markets (confirmed).
Probe: 6T, 0% WR — default params mismatched for Dollar Index price/ATR range.
Dollar Index: price ~100-105, daily range ~0.3-0.8 pts, M15 ATR ~0.05-0.15.
Goal: find params that produce positive-expectancy trades.
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime, timedelta

BASE_DIR    = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC     = f"{BASE_DIR}/OBInclude/SetFiles/usdx.set"
LAST_JSON   = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD  = f"{BASE_DIR}/docs/usdx_full_results.md"
RESULTS_CSV = f"{BASE_DIR}/usdx_full_results.csv"
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
    header_md = f"""# USDX Full Parameter Sweep
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')} — Stop at {STOP_HOUR:02d}:00*
*Probe: 6T, 0% WR — default params completely mismatched for DXY*
*DXY price ~100-105, M15 ATR ~0.05-0.15 (vs XAUUSD ATR_max=8.2)*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
"""
    header_csv = "run_id,label,profit_factor,balance,max_dd_pct,traded,total_trades,win_rate,elapsed_s\n"
    with open(RESULTS_MD, "w") as f:
        f.write(header_md)
    with open(RESULTS_CSV, "w") as f:
        f.write(header_csv)

# Shorthands
STOP  = "2||1||0||2||N"
LIMIT = "1||1||0||2||N"
T     = "true||false||0||true||N"
F     = "false||false||0||true||N"
def tp(v):      return f"{v}||1.27||0.127000||12.700000||N"
def prof(v):    return f"{v}||0||0||5||N"
def atr_max(v): return f"{v}||8.2||0.820000||82.000000||N"
def atr_min(v): return f"{v}||0.0||0.1||10.0||N"
def body(v):    return f"{v}||40||1||100||N"
def tol(v):     return f"{v}||50||1||500||N"
def ob(v):      return f"{v}||80||1||800||N"
def kzs(v):     return f"{v}||8||1||70||N"
def kze(v):     return f"{v}||12||1||100||N"
def kz2s(v):    return f"{v}||13||1||120||N"
def kz2e(v):    return f"{v}||17||1||160||N"

TEST_CASES = [
    # ── Baseline ─────────────────────────────────────────────────────────
    ("baseline",          "Baseline (probe settings, 6T 0% WR)",                   {}),

    # ── ATR_max scaling — MOST CRITICAL fix for USDX ─────────────────────
    # DXY M15 ATR is ~0.05-0.15; 8.2 is effectively infinity
    ("atr_015",           "ATR_max=0.15 (DXY high-vol filter)",                    {"ATR_max": atr_max("0.15")}),
    ("atr_020",           "ATR_max=0.20",                                           {"ATR_max": atr_max("0.20")}),
    ("atr_030",           "ATR_max=0.30",                                           {"ATR_max": atr_max("0.30")}),
    ("atr_050",           "ATR_max=0.50",                                           {"ATR_max": atr_max("0.50")}),
    ("atr_100",           "ATR_max=1.0 (essentially off)",                          {"ATR_max": atr_max("1.0")}),

    # ── Risk Profiles ─────────────────────────────────────────────────────
    ("p0_very_agg",       "Profile=0 VeryAggressive (no filters)",                  {"inpRiskProfile": prof(0)}),
    ("p1_aggressive",     "Profile=1 Aggressive (wide KZ, D1=off)",                 {"inpRiskProfile": prof(1)}),
    ("p2_balanced",       "Profile=2 Balanced (med KZ, D1=off)",                    {"inpRiskProfile": prof(2)}),
    ("p3_conservative",   "Profile=3 Conservative",                                 {"inpRiskProfile": prof(3)}),

    # ── Order Type ────────────────────────────────────────────────────────
    ("stop_tp127",        "STOP + tp=1.27",                                          {"typeofOrder": STOP}),
    ("stop_tp200",        "STOP + tp=2.0",                                           {"typeofOrder": STOP, "fibo1rstTP": tp("2.0")}),
    ("stop_tp300",        "STOP + tp=3.0",                                           {"typeofOrder": STOP, "fibo1rstTP": tp("3.0")}),

    # ── TP Ratios (LIMIT) ─────────────────────────────────────────────────
    ("tp_200",            "LIMIT + tp=2.0",                                          {"fibo1rstTP": tp("2.0")}),
    ("tp_300",            "LIMIT + tp=3.0",                                          {"fibo1rstTP": tp("3.0")}),

    # ── Trend Filters ─────────────────────────────────────────────────────
    ("d1_off",            "D1Trend=false",                                            {"inpRequireD1Trend": F}),
    ("macro_off",         "MacroTrend=false",                                         {"inpMacroTrendEnabled": F}),
    ("both_trend_off",    "D1=false + Macro=false",                                   {"inpRequireD1Trend": F, "inpMacroTrendEnabled": F}),
    ("fvg_on",            "FVG=true",                                                  {"inpMSSRequireFVG": T}),
    ("skip09",            "Skip09UTC=true",                                            {"inpSkip09UTC": T}),

    # ── KZ Variants ───────────────────────────────────────────────────────
    ("kz_ny_focused",     "KZ NY-focused (13-17 + 20-23)",                           {"inpKZ1Start": kzs(13), "inpKZ1End": kze(17),
                                                                                       "inpKZ2Start": kz2s(20), "inpKZ2End": kz2e(23)}),
    ("kz_london",         "KZ London (07-12 + 13-17)",                               {"inpKZ1Start": kzs(7),  "inpKZ1End": kze(12)}),
    ("kz_wide",           "KZ wide (07-17 + 19-23)",                                 {"inpKZ1Start": kzs(7),  "inpKZ1End": kze(17),
                                                                                       "inpKZ2Start": kz2s(19), "inpKZ2End": kz2e(23)}),

    # ── OB Quality ────────────────────────────────────────────────────────
    ("ob_160",            "outdatedOB=160",                                            {"outdatedOB": ob(160)}),
    ("tol_30",            "tolerance=30",                                              {"tolerance": tol(30)}),
    ("body_20",           "minBodySize=20 (smaller body req for DXY)",                {"minBodySize": body(20)}),
    ("body_10",           "minBodySize=10",                                            {"minBodySize": body(10)}),

    # ── Key Combos ────────────────────────────────────────────────────────
    ("atr030_stop_tp200", "ATR_max=0.3 + STOP + tp=2.0",                            {"ATR_max": atr_max("0.30"),
                                                                                       "typeofOrder": STOP,
                                                                                       "fibo1rstTP": tp("2.0")}),
    ("atr030_d1off",      "ATR_max=0.3 + D1=false",                                  {"ATR_max": atr_max("0.30"),
                                                                                       "inpRequireD1Trend": F}),
    ("atr030_p2",         "ATR_max=0.3 + Profile=2",                                 {"ATR_max": atr_max("0.30"),
                                                                                       "inpRiskProfile": prof(2)}),
    ("p2_stop_tp200",     "Profile=2 + STOP + tp=2.0",                              {"inpRiskProfile": prof(2),
                                                                                       "typeofOrder": STOP,
                                                                                       "fibo1rstTP": tp("2.0")}),
    ("atr030_p1_tp300",   "ATR_max=0.3 + Profile=1 + tp=3.0",                       {"ATR_max": atr_max("0.30"),
                                                                                       "inpRiskProfile": prof(1),
                                                                                       "fibo1rstTP": tp("3.0")}),
    ("atr030_kzny_stop",  "ATR_max=0.3 + KZ NY + STOP + tp=2.0",                   {"ATR_max": atr_max("0.30"),
                                                                                       "inpKZ1Start": kzs(13),
                                                                                       "inpKZ1End": kze(17),
                                                                                       "inpKZ2Start": kz2s(20),
                                                                                       "inpKZ2End": kz2e(23),
                                                                                       "typeofOrder": STOP,
                                                                                       "fibo1rstTP": tp("2.0")}),
    ("body10_tol30_atr03","minBody=10 + tol=30 + ATR_max=0.3",                       {"minBodySize": body(10),
                                                                                       "tolerance": tol(30),
                                                                                       "ATR_max": atr_max("0.30")}),
]

def main():
    print(f"\n{'='*60}", flush=True)
    print(f"  USDX Full Sweep — {len(TEST_CASES)} tests", flush=True)
    print(f"  Stop: {STOP_HOUR:02d}:00", flush=True)
    print(f"  Symbol: USDX (Dollar Index, Fusion Markets)", flush=True)
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
    print(f"  Results: docs/usdx_full_results.md", flush=True)
    print(f"{'='*60}\n", flush=True)

if __name__ == "__main__":
    main()
