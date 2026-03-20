"""
NAS100 Overnight Parameter Optimizer
Runs systematic backtest sweeps, logs results, stops by 09:00.
Usage: python3 nas100_optimize.py
"""

import codecs, subprocess, json, os, sys, time
from datetime import datetime, timedelta

BASE_DIR = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC  = f"{BASE_DIR}/OBInclude/SetFiles/nas100.set"
LAST_JSON = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD = f"{BASE_DIR}/docs/nas100_test_results.md"
RESULTS_CSV = f"{BASE_DIR}/nas100_test_results.csv"
BEST_SET = f"{BASE_DIR}/OBInclude/SetFiles/nas100_best.set"

STOP_HOUR = 9   # stop at 09:00 local time
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
        import re
        pattern = rf"^({re.escape(key)}=)[^|]+(.*)"
        replacement = rf"\g<1>{value}\2"
        new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        if new_content == content:
            print(f"  WARNING: param '{key}' not found in set file")
        content = new_content
    return content

def run_backtest():
    env = os.environ.copy()
    env["SYMBOL"]    = "NAS100"
    env["SET_FILE"]  = "nas100.set"
    env["FROM_DATE"] = FROM_DATE
    env["TO_DATE"]   = TO_DATE
    result = subprocess.run(
        ["bash", "backtest.sh"],
        cwd=BASE_DIR,
        env=env,
        capture_output=True,
        text=True,
        timeout=900
    )
    return result.returncode

def read_results():
    try:
        with open(LAST_JSON) as f:
            return json.load(f)
    except Exception as e:
        return {"error": str(e)}

def should_stop():
    now = datetime.now()
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
    header_md = f"""# NAS100 Overnight Optimization Results
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')} — Stop at {STOP_HOUR:02d}:00*
*Base: Profile=5 Custom, KZ=13-16+19-22 UTC, D1+MacroTrend=true, LIMIT orders, 2022-2026*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
"""
    header_csv = "run_id,label,profit_factor,balance,max_dd_pct,traded,total_trades,win_rate,elapsed_s\n"
    with open(RESULTS_MD, "w") as f:
        f.write(header_md)
    with open(RESULTS_CSV, "w") as f:
        f.write(header_csv)

TEST_CASES = [
    ("base_run5",       "Baseline (run5 config)",           {}),

    ("outdatedOB_100",  "outdatedOB=100",                   {"outdatedOB": "100||80||1||800||N"}),
    ("outdatedOB_120",  "outdatedOB=120",                   {"outdatedOB": "120||80||1||800||N"}),
    ("outdatedOB_160",  "outdatedOB=160",                   {"outdatedOB": "160||80||1||800||N"}),
    ("outdatedOB_200",  "outdatedOB=200",                   {"outdatedOB": "200||80||1||800||N"}),

    ("kz_london_ny",    "KZ1=08-11 + KZ2=13-16",           {"inpKZ1Start": "8||12||1||14||N",
                                                             "inpKZ1End":   "11||15||1||17||N",
                                                             "inpKZ2Start": "13||18||1||20||N",
                                                             "inpKZ2End":   "16||21||1||23||N"}),
    ("kz_wider_ny",     "KZ1=12-17 + KZ2=19-23",           {"inpKZ1Start": "12||12||1||14||N",
                                                             "inpKZ1End":   "17||15||1||17||N",
                                                             "inpKZ2Start": "19||18||1||20||N",
                                                             "inpKZ2End":   "23||21||1||23||N"}),
    ("kz_off",          "KZ disabled",                     {"inpKillZoneEnabled": "false||false||0||true||N"}),
    ("kz_ny_only_wide", "KZ1=13-20 only",                  {"inpKZ1Start": "13||12||1||14||N",
                                                             "inpKZ1End":   "20||15||1||17||N",
                                                             "inpKZ2Start": "21||18||1||20||N",
                                                             "inpKZ2End":   "22||21||1||23||N"}),

    ("fvg_on",          "inpMSSRequireFVG=true",            {"inpMSSRequireFVG": "true||false||0||true||N"}),

    ("tp_2x",           "fibo1rstTP=2.0",                   {"fibo1rstTP": "2.0||1.0||0.1||1.8||N"}),
    ("tp_25x",          "fibo1rstTP=2.5",                   {"fibo1rstTP": "2.5||1.0||0.1||1.8||N"}),
    ("tp_3x",           "fibo1rstTP=3.0",                   {"fibo1rstTP": "3.0||1.0||0.1||1.8||N"}),

    ("tol_30",          "tolerance=30",                     {"tolerance": "30||50||1||500||N"}),
    ("tol_80",          "tolerance=80",                     {"tolerance": "80||50||1||500||N"}),
    ("tol_120",         "tolerance=120",                    {"tolerance": "120||50||1||500||N"}),

    ("body_5",          "minBodySize=5",                    {"minBodySize": "5||10||1||100||N"}),
    ("body_20",         "minBodySize=20",                   {"minBodySize": "20||10||1||100||N"}),

    ("scan_100",        "inpHistoricalScanBars=100",        {"inpHistoricalScanBars": "100||30||1||300||N"}),
    ("scan_200",        "inpHistoricalScanBars=200",        {"inpHistoricalScanBars": "200||30||1||300||N"}),

    ("imb_20",          "minImBalanced=20",                 {"minImBalanced": "20||40||1||400||N"}),
    ("imb_60",          "minImBalanced=60",                 {"minImBalanced": "60||40||1||400||N"}),

    ("d1_off",          "D1Trend=false",                    {"inpRequireD1Trend": "false||false||0||true||N"}),

    ("kz_london_ny_ob120", "KZ London+NY + outdatedOB=120", {"inpKZ1Start": "8||12||1||14||N",
                                                              "inpKZ1End":   "11||15||1||17||N",
                                                              "inpKZ2Start": "13||18||1||20||N",
                                                              "inpKZ2End":   "16||21||1||23||N",
                                                              "outdatedOB":  "120||80||1||800||N"}),
    ("best_combo_1",    "outdatedOB=120 + tp=2.0",          {"outdatedOB":  "120||80||1||800||N",
                                                              "fibo1rstTP": "2.0||1.0||0.1||1.8||N"}),
    ("best_combo_2",    "outdatedOB=120 + tol=80 + tp=2.0", {"outdatedOB":  "120||80||1||800||N",
                                                              "tolerance":   "80||50||1||500||N",
                                                              "fibo1rstTP": "2.0||1.0||0.1||1.8||N"}),
]

def main():
    print(f"\n{'='*55}")
    print(f"  NAS100 Overnight Optimizer")
    print(f"  Stop time: {STOP_HOUR:02d}:00  |  Tests: {len(TEST_CASES)}")
    print(f"{'='*55}\n")

    init_logs()
    base_content = read_set()
    best_pf = 0.0
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

        t0 = time.time()
        rc = run_backtest()
        elapsed = time.time() - t0

        if rc != 0:
            print(f"  ⚠️  backtest.sh exited with code {rc}")

        data = read_results()
        pf_v = log_result(i+1, label, params, data, elapsed)

        if pf_v > best_pf:
            best_pf = pf_v
            best_label = label
            with codecs.open(SET_SRC, "r", "utf-16") as f:
                best_content = f.read()
            with codecs.open(BEST_SET, "w", "utf-16") as f:
                f.write(best_content)
            print(f"  🏆 New best: PF={pf_v:.2f} saved to nas100_best.set")

    write_set(base_content)

    summary = f"""
---
## Summary
- **Best PF**: {best_pf:.2f} — {best_label}
- **Best set**: `OBInclude/SetFiles/nas100_best.set`
- **Completed**: {datetime.now().strftime('%Y-%m-%d %H:%M')}
"""
    with open(RESULTS_MD, "a") as f:
        f.write(summary)

    print(f"\n{'='*55}")
    print(f"  DONE — Best: PF={best_pf:.2f} ({best_label})")
    print(f"  Results: docs/nas100_test_results.md")
    print(f"  Best set: OBInclude/SetFiles/nas100_best.set")
    print(f"{'='*55}\n")

if __name__ == "__main__":
    main()
