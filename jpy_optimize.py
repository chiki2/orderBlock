"""
JPY Crosses Optimizer — GBPJPY, EURJPY, AUDJPY
Applies learnings from GBPUSD/USDJPY sweeps.
Usage: python3 jpy_optimize.py [GBPJPY|EURJPY|AUDJPY]
"""
import codecs, subprocess, json, os, time, re, sys
from datetime import datetime, timedelta

SYMBOL   = sys.argv[1] if len(sys.argv) > 1 else "GBPJPY"
SET_MAP  = {"GBPJPY": "gbpjpy.set", "EURJPY": "eurjpy.set", "AUDJPY": "audjpy.set"}
SET_FILE = SET_MAP[SYMBOL]

BASE_DIR    = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC     = f"{BASE_DIR}/OBInclude/SetFiles/{SET_FILE}"
LAST_JSON   = f"{BASE_DIR}/backtest_last.json"
slug        = SYMBOL.lower()
RESULTS_MD  = f"{BASE_DIR}/docs/{slug}_test_results.md"
RESULTS_CSV = f"{BASE_DIR}/{slug}_test_results.csv"
BEST_SET    = f"{BASE_DIR}/OBInclude/SetFiles/{slug}_best.set"

STOP_HOUR = 7   # stop at 07:00 next morning
FROM_DATE = "2022.01.01"
TO_DATE   = "2026.01.01"

def read_set():
    with codecs.open(SET_SRC, "r", "utf-16") as f: return f.read()
def write_set(content):
    with codecs.open(SET_SRC, "w", "utf-16") as f: f.write(content)
def apply_params(base, params):
    content = base
    for key, value in params.items():
        new = re.sub(rf"^({re.escape(key)}=).*$", rf"\g<1>{value}", content, flags=re.MULTILINE)
        if new == content: print(f"  WARNING: '{key}' not found", flush=True)
        content = new
    return content
def run_backtest():
    env = os.environ.copy()
    env["SYMBOL"] = SYMBOL; env["SET_FILE"] = SET_FILE
    env["FROM_DATE"] = FROM_DATE; env["TO_DATE"] = TO_DATE
    r = subprocess.run(["bash", "backtest.sh"], cwd=BASE_DIR, env=env,
                       capture_output=True, text=True, timeout=900)
    return r.returncode
def read_results():
    try:
        with open(LAST_JSON) as f: return json.load(f)
    except Exception as e: return {"error": str(e)}
def should_stop():
    now = datetime.now()
    stop = now.replace(hour=STOP_HOUR, minute=0, second=0, microsecond=0)
    if stop <= now: stop += timedelta(days=1)
    return now >= stop
def log_result(run_id, label, data, elapsed):
    pf  = data.get("profit_factor", "n/a"); bal = data.get("balance", 0)
    dd  = data.get("max_dd_pct", "n/a");    trd = data.get("traded", 0)
    tot = data.get("total_trades", "n/a");  wr  = data.get("win_rate_str", "n/a")
    pf_v = float(str(pf).split()[0]) if pf != "n/a" else 0
    with open(RESULTS_CSV, "a") as f:
        f.write(f'{run_id},"{label}",{pf},{bal},{dd},{trd},{tot},"{wr}",{elapsed:.0f}\n')
    emoji = "✅" if pf_v >= 1.5 else ("⚠️" if pf_v >= 1.0 else "❌")
    with open(RESULTS_MD, "a") as f:
        f.write(f"| {run_id} | {label} | {pf} | {bal:.2f} | {dd} | {trd} | {tot} | {wr} | {elapsed:.0f}s | {emoji} |\n")
    print(f"  → PF={pf}  Balance={bal:.2f}  Placed={trd}  Closed={tot}  WR={wr}  DD={dd}", flush=True)
    return pf_v

# Baseline results for reference:
# GBPJPY: PF=0.68, 108T  EURJPY: PF=1.04, 101T  AUDJPY: PF=0.89, 89T
COMMON_TESTS = [
    ("baseline",       "Baseline",                              {}),
    ("fvg_on",         "FVG=true",                             {"inpMSSRequireFVG":    "true||false||0||true||N"}),
    ("stop_orders",    "STOP orders",                          {"typeofOrder":         "2||1||0||2||N"}),
    ("tp_15",          "fibo1rstTP=1.5",                       {"fibo1rstTP":          "1.5||1.0||0.1||1.8||N"}),
    ("tp_20",          "fibo1rstTP=2.0",                       {"fibo1rstTP":          "2.0||1.0||0.1||1.8||N"}),
    ("tp_25",          "fibo1rstTP=2.5",                       {"fibo1rstTP":          "2.5||1.0||0.1||1.8||N"}),
    ("tp_30",          "fibo1rstTP=3.0",                       {"fibo1rstTP":          "3.0||1.0||0.1||1.8||N"}),
    ("d1_off",         "D1Trend=false",                        {"inpRequireD1Trend":   "false||false||0||true||N"}),
    ("macro_off",      "MacroTrend=false",                     {"inpMacroTrendEnabled":"false||false||0||true||N"}),
    ("kz_london",      "KZ London only (08-12)",               {"inpKZ2Start":         "20||13||1||120||N",
                                                                 "inpKZ2End":           "23||16||1||160||N"}),
    ("kz_off",         "KZ disabled",                         {"inpKillZoneEnabled":  "false||false||0||true||N"}),
    ("outdated_120",   "outdatedOB=120",                       {"outdatedOB":          "120||80||1||800||N"}),
    ("fvg_tp25",       "FVG + tp=2.5",                        {"inpMSSRequireFVG":    "true||false||0||true||N",
                                                                 "fibo1rstTP":          "2.5||1.0||0.1||1.8||N"}),
    ("fvg_tp30",       "FVG + tp=3.0",                        {"inpMSSRequireFVG":    "true||false||0||true||N",
                                                                 "fibo1rstTP":          "3.0||1.0||0.1||1.8||N"}),
    ("stop_tp30",      "STOP + tp=3.0",                       {"typeofOrder":         "2||1||0||2||N",
                                                                 "fibo1rstTP":          "3.0||1.0||0.1||1.8||N"}),
    ("fvg_d1off",      "FVG + D1=false",                      {"inpMSSRequireFVG":    "true||false||0||true||N",
                                                                 "inpRequireD1Trend":   "false||false||0||true||N"}),
    ("d1off_tp30",     "D1=false + tp=3.0",                   {"inpRequireD1Trend":   "false||false||0||true||N",
                                                                 "fibo1rstTP":          "3.0||1.0||0.1||1.8||N"}),
]

# AUDJPY: also test London+NY KZ (00-04 Tokyo may be wrong)
AUDJPY_EXTRA = [
    ("kz_london_ny",   "KZ London+NY (08-12+13-17)",          {"inpKZ1Start":         "8||0||1||70||N",
                                                                 "inpKZ1End":           "12||4||1||100||N",
                                                                 "inpKZ2Start":         "13||8||1||120||N",
                                                                 "inpKZ2End":           "17||12||1||160||N"}),
    ("kz_tok_tp30",    "Tokyo KZ + tp=3.0",                   {"fibo1rstTP":          "3.0||1.0||0.1||1.8||N"}),
]

TEST_CASES = COMMON_TESTS + (AUDJPY_EXTRA if SYMBOL == "AUDJPY" else [])

def init_logs():
    baseline_ref = {"GBPJPY": "PF=0.68, 108T, 54% WR, DD 5.20%",
                    "EURJPY": "PF=1.04, 101T, 57% WR, DD 3.68%",
                    "AUDJPY": "PF=0.89, 89T, 52% WR, DD 2.93%"}
    with open(RESULTS_MD, "w") as f:
        f.write(f"""# {SYMBOL} Optimization Results
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')} — Stop at {STOP_HOUR:02d}:00*
*Probe baseline: {baseline_ref[SYMBOL]}*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
""")
    with open(RESULTS_CSV, "w") as f:
        f.write("run_id,label,profit_factor,balance,max_dd_pct,traded,total_trades,win_rate,elapsed_s\n")

def main():
    print(f"\n{'='*55}", flush=True)
    print(f"  {SYMBOL} Optimizer — {len(TEST_CASES)} tests", flush=True)
    print(f"  Stop: {STOP_HOUR:02d}:00 | Period: {FROM_DATE}→{TO_DATE}", flush=True)
    print(f"{'='*55}\n", flush=True)
    init_logs()
    base_content = read_set()
    best_pf = 0.0; best_label = "none"
    for i, (run_id, label, params) in enumerate(TEST_CASES):
        if should_stop():
            print(f"\n⏰ Stop time reached.", flush=True); break
        print(f"\n[{i+1}/{len(TEST_CASES)}] {datetime.now().strftime('%H:%M')} — {label}", flush=True)
        write_set(apply_params(base_content, params))
        t0 = time.time()
        rc = run_backtest()
        elapsed = time.time() - t0
        if rc != 0: print(f"  ⚠️  exit {rc}", flush=True)
        data = read_results()
        pf_v = log_result(i+1, label, data, elapsed)
        if pf_v > best_pf:
            best_pf = pf_v; best_label = label
            with codecs.open(SET_SRC, "r", "utf-16") as f: bc = f.read()
            with codecs.open(BEST_SET, "w", "utf-16") as f: f.write(bc)
            print(f"  🏆 New best: PF={pf_v:.2f} → {slug}_best.set", flush=True)
    write_set(base_content)
    with open(RESULTS_MD, "a") as f:
        f.write(f"\n---\n## Summary\n- **Best**: PF={best_pf:.2f} — {best_label}\n- **Completed**: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
    print(f"\n{'='*55}", flush=True)
    print(f"  DONE — Best: PF={best_pf:.2f} ({best_label})", flush=True)
    print(f"{'='*55}\n", flush=True)

if __name__ == "__main__":
    main()
