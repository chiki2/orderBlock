"""
XAUUSD Parameter Optimizer — Profile sweep + trade count improvement.
Usage: python3 xauusd_optimize.py
"""
import codecs, subprocess, json, os, time, re
from datetime import datetime, timedelta

BASE_DIR    = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC     = f"{BASE_DIR}/OBInclude/SetFiles/claude.set"
LAST_JSON   = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD  = f"{BASE_DIR}/docs/xauusd_test_results.md"
RESULTS_CSV = f"{BASE_DIR}/xauusd_test_results.csv"
BEST_SET    = f"{BASE_DIR}/OBInclude/SetFiles/xauusd_best.set"

STOP_HOUR = 7
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
        # Match entire line after "key=" to end — replaces the full value+metadata
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

    print(f"  → PF={pf}  Balance={bal:.2f}  Traded={trd}  Closed={tot}  WR={wr}  DD={dd}")
    return pf_v

def init_logs():
    header_md = f"""# XAUUSD Optimization Results
*Started: {datetime.now().strftime('%Y-%m-%d %H:%M')} — Stop at {STOP_HOUR:02d}:00*
*Base: Profile=5 Custom, KZ=11-14+20-23 UTC, LIMIT, D1+MacroTrend+DailyBias=true, 2022-2026*
*Goal: more trades while keeping PF >= 1.5*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
"""
    header_csv = "run_id,label,profit_factor,balance,max_dd_pct,traded,total_trades,win_rate,elapsed_s\n"
    with open(RESULTS_MD, "w") as f:
        f.write(header_md)
    with open(RESULTS_CSV, "w") as f:
        f.write(header_csv)

# Profile enum values map to:
# 0 = Very Aggressive:  KZ=OFF, DailyBias=OFF, MacroTrend=OFF, D1=OFF, H4=OFF
# 1 = Aggressive:       KZ=ON(8-17+18-23), DailyBias=OFF, MacroTrend=ON, D1=OFF, H4=OFF
# 2 = Balanced:         KZ=ON(9-15+20-23), DailyBias=ON,  MacroTrend=ON, D1=OFF, H4=OFF
# 3 = Conservative:     KZ=ON(11-14+20-23), DailyBias=ON, MacroTrend=ON, D1=ON,  H4=OFF
# 4 = Very Conservative:KZ=ON(11-14+20-23), DailyBias=ON, MacroTrend=ON, D1=ON,  H4=ON
# 5 = Custom:           use individual inputs (current baseline)

TEST_CASES = [
    # ── Preset profiles ──────────────────────────────────────────────
    ("baseline",       "Baseline (Profile=5 Custom, all filters)",     {}),
    ("p0_very_agg",   "Profile=0 VeryAggressive (no filters)",         {"inpRiskProfile": "0||0||0||5||N"}),
    ("p1_agg",        "Profile=1 Aggressive (wide KZ, D1=off)",        {"inpRiskProfile": "1||0||0||5||N"}),
    ("p2_balanced",   "Profile=2 Balanced (med KZ, D1=off)",           {"inpRiskProfile": "2||0||0||5||N"}),
    ("p3_conserv",    "Profile=3 Conservative (tight KZ, D1=on)",      {"inpRiskProfile": "3||0||0||5||N"}),
    ("p4_verycon",    "Profile=4 VeryConservative (+H4)",              {"inpRiskProfile": "4||0||0||5||N"}),

    # ── Custom variants targeting more trades ─────────────────────────
    ("d1_off",        "Custom: D1Trend=false (biggest filter off)",     {"inpRequireD1Trend": "false||false||0||true||N"}),
    ("macro_off",     "Custom: MacroTrend=false",                       {"inpMacroTrendEnabled": "false||false||0||true||N"}),
    ("kz_wide",       "Custom: KZ wide (08-17 + 18-23)",                {"inpKZ1Start": "8||7||1||70||N",
                                                                          "inpKZ1End":   "17||10||1||100||N",
                                                                          "inpKZ2Start": "18||12||1||120||N",
                                                                          "inpKZ2End":   "23||16||1||160||N"}),
    ("kz_off",        "Custom: KZ disabled",                            {"inpKillZoneEnabled": "false||false||0||true||N"}),
    ("outdated_160",  "Custom: outdatedOB=160 (OBs live longer)",       {"outdatedOB": "160||80||1||800||N"}),
    ("outdated_200",  "Custom: outdatedOB=200",                         {"outdatedOB": "200||80||1||800||N"}),

    # ── Combos: relax one filter at a time ───────────────────────────
    ("p2_d1on",       "Profile=2 Balanced + D1=true",                  {"inpRiskProfile":    "2||0||0||5||N",
                                                                          "inpRequireD1Trend": "true||false||0||true||N"}),
    ("kz_wide_d1on",  "KZ wide + D1=true + MacroTrend=true",           {"inpKZ1Start": "8||7||1||70||N",
                                                                          "inpKZ1End":   "17||10||1||100||N",
                                                                          "inpKZ2Start": "18||12||1||120||N",
                                                                          "inpKZ2End":   "23||16||1||160||N",
                                                                          "inpRequireD1Trend": "true||false||0||true||N"}),
    ("d1off_ob160",   "D1=false + outdatedOB=160",                     {"inpRequireD1Trend": "false||false||0||true||N",
                                                                          "outdatedOB":        "160||80||1||800||N"}),
    ("p2_ob160",      "Profile=2 + outdatedOB=160",                    {"inpRiskProfile": "2||0||0||5||N",
                                                                          "outdatedOB":    "160||80||1||800||N"}),
    ("p1_d1on_ob160", "Profile=1 + D1=true + outdatedOB=160",         {"inpRiskProfile":    "1||0||0||5||N",
                                                                          "inpRequireD1Trend": "true||false||0||true||N",
                                                                          "outdatedOB":        "160||80||1||800||N"}),
]

def main():
    print(f"\n{'='*55}")
    print(f"  XAUUSD Optimizer — Profile + Trade Count")
    print(f"  Stop time: {STOP_HOUR:02d}:00  |  Tests: {len(TEST_CASES)}")
    print(f"{'='*55}\n")

    init_logs()
    base_content = read_set()
    best_pf    = 0.0
    best_label = "none"
    best_trades = 0

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

        data   = read_results()
        pf_v   = log_result(i+1, label, params, data, elapsed)
        trades = int(str(data.get("total_trades", 0)).split()[0]) if data.get("total_trades") else 0

        # Save best by score = PF * log(trades+1) to balance quality vs quantity
        score = pf_v * (trades ** 0.5)
        if pf_v > best_pf:
            best_pf    = pf_v
            best_label = label
            best_trades = trades
            with codecs.open(SET_SRC, "r", "utf-16") as f:
                best_content = f.read()
            with codecs.open(BEST_SET, "w", "utf-16") as f:
                f.write(best_content)
            print(f"  🏆 New best PF: {pf_v:.2f} ({trades} trades) — saved to xauusd_best.set")

    write_set(base_content)

    summary = f"""
---
## Summary
- **Best PF**: {best_pf:.2f} ({best_trades} trades) — {best_label}
- **Best set**: `OBInclude/SetFiles/xauusd_best.set`
- **Completed**: {datetime.now().strftime('%Y-%m-%d %H:%M')}
"""
    with open(RESULTS_MD, "a") as f:
        f.write(summary)

    print(f"\n{'='*55}")
    print(f"  DONE — Best: PF={best_pf:.2f} ({best_trades}T) — {best_label}")
    print(f"  Results: docs/xauusd_test_results.md")
    print(f"  Best set: OBInclude/SetFiles/xauusd_best.set")
    print(f"{'='*55}\n")

if __name__ == "__main__":
    main()
