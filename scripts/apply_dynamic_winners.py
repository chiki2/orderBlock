#!/usr/bin/env python3
"""
apply_dynamic_winners.py

Reads dynamic_params_xv.csv to find verified PASS configs,
applies the winning parameter overrides to the appropriate .set files,
and commits the result.

Rules:
- Only apply if XV verdict = PASS (3+/4 annual profitable, Full PF >= 1.5)
- Do NOT apply if PF is worse than or within 5% of baseline (no regression)
- Commit with clear message listing what changed
"""
import csv, codecs, os, subprocess, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)

SET_MAP = {
    "XAUUSD": "claude.set",
    "USDJPY": "usdjpy.set",
    "EURJPY": "eurjpy.set",
    "GBPUSD": "gbpusd.set",
}

WEEKDAY_OVERRIDES = {
    "inpWeekdayScaling": "true||false||0||true||N",
    "inpWdMon":          "1.0||1.0||0.1||2.0||N",
    "inpWdTue":          "0.5||1.0||0.1||2.0||N",
    "inpWdWed":          "0.75||1.0||0.1||2.0||N",
    "inpWdThu":          "1.0||1.0||0.1||2.0||N",
    "inpWdFri":          "0.75||1.0||0.1||2.0||N",
}

ATRTP_OVERRIDES = {
    "inpATRTP":          "true||false||0||true||N",
    "inpATRTPPeriod":    "50||50||10||200||N",
    "inpATRTPHighPct":   "0.70||0.70||0.1||0.9||N",
    "inpATRTPHighMult":  "1.5||1.5||1.0||3.0||N",
    "inpATRTPLowPct":    "0.30||0.30||0.1||0.5||N",
    "inpATRTPLowMult":   "0.85||0.85||0.5||1.0||N",
}

CONFIG_OVERRIDES = {
    "WeekdayScale": WEEKDAY_OVERRIDES,
    "ATRTP":        ATRTP_OVERRIDES,
    "Both":         {**WEEKDAY_OVERRIDES, **ATRTP_OVERRIDES},
}


def apply_to_set_file(set_file, overrides):
    path = os.path.join(BASE, "OBInclude", "SetFiles", set_file)
    with codecs.open(path, "r", "utf-16") as f:
        lines = f.readlines()
    new_lines = []
    applied = set()
    for line in lines:
        key = line.split("=")[0].strip() if "=" in line else ""
        if key in overrides:
            new_lines.append(f"{key}={overrides[key]}\n")
            applied.add(key)
        else:
            new_lines.append(line)
    for key, val in overrides.items():
        if key not in applied:
            new_lines.append(f"{key}={val}\n")
    with codecs.open(path, "w", "utf-16") as f:
        f.writelines(new_lines)


def compute_verdict(rows, symbol, config):
    """Returns (ok_years, full_pf, verdict) for a symbol+config combo."""
    sym_rows = [r for r in rows if r["symbol"] == symbol and r["config"] == config]
    annual   = [r for r in sym_rows if r["window"] != "Full"]
    full_r   = next((r for r in sym_rows if r["window"] == "Full"), None)
    ok_years = sum(1 for r in annual if r["ok"] == "True")
    full_pf  = float(full_r["pf"]) if full_r else 0.0
    verdict  = ok_years >= 3 and full_pf >= 1.5
    return ok_years, full_pf, verdict


def main():
    xv_file = os.path.join(BASE, "dynamic_params_xv.csv")
    ph1_file = os.path.join(BASE, "dynamic_params_phase1.csv")

    if not os.path.exists(xv_file):
        print("No dynamic_params_xv.csv found — no winners to apply.")
        return

    with open(xv_file) as f:
        xv_rows = list(csv.DictReader(f))

    baseline_pf = {}
    if os.path.exists(ph1_file):
        with open(ph1_file) as f:
            for row in csv.DictReader(f):
                if row["label"] == "Baseline":
                    baseline_pf[row["symbol"]] = float(row["pf"])

    applied = []
    skipped = []

    for symbol, set_file in SET_MAP.items():
        for config, overrides in CONFIG_OVERRIDES.items():
            ok_years, full_pf, verdict = compute_verdict(xv_rows, symbol, config)
            base_pf = baseline_pf.get(symbol, 0)
            if verdict and full_pf > base_pf * 1.05:
                print(f"  APPLY  {symbol} {config}: {ok_years}/4, Full PF={full_pf:.2f} (vs baseline {base_pf:.2f})")
                apply_to_set_file(set_file, overrides)
                applied.append(f"{symbol}/{config}")
            else:
                reason = "not a PASS" if not verdict else f"PF {full_pf:.2f} not > baseline {base_pf:.2f}×1.05"
                print(f"  SKIP   {symbol} {config}: {reason}")
                skipped.append(f"{symbol}/{config}")

    if not applied:
        print("\n  No winning configs to apply — set files unchanged.")
        return

    # Commit
    msg_body = "\n".join(f"  - {a}" for a in applied)
    commit_msg = f"""feat(dynamic-params): deploy verified dynamic parameter configs

Applied configs that passed cross-year validation (3+/4 annual, PF>baseline×1.05):
{msg_body}

WeekdayScaling: Tue=0.5×, Wed=0.75×, Fri=0.75× (forensics: worst WR days)
ATRTP: High-ATR regime TP×1.5, Low-ATR TP×0.85 (regime-aware TP)

Co-Authored-By: claude-flow <ruv@ruv.net>"""

    files_to_add = [f"OBInclude/SetFiles/{SET_MAP[s.split('/')[0]]}" for s in applied]
    subprocess.run(["git", "add"] + files_to_add, cwd=BASE)
    result = subprocess.run(["git", "commit", "-m", commit_msg], cwd=BASE, capture_output=True, text=True)
    if result.returncode == 0:
        subprocess.run(["git", "push"], cwd=BASE)
        print(f"\n  Committed and pushed: {applied}")
    else:
        print(f"\n  Git commit failed: {result.stderr}")


if __name__ == "__main__":
    main()
