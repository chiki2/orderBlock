"""
NAS100 Winner Validation — tests best config across year windows.
Usage: python3 nas100_validate.py
"""
import codecs, subprocess, json, os, sys, time
from datetime import datetime

BASE_DIR  = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
BEST_SET  = f"{BASE_DIR}/OBInclude/SetFiles/nas100_best.set"
SET_SRC   = f"{BASE_DIR}/OBInclude/SetFiles/nas100.set"
LAST_JSON = f"{BASE_DIR}/backtest_last.json"
RESULTS_MD = f"{BASE_DIR}/docs/nas100_validation.md"

WINDOWS = [
    ("2022", "2022.01.01", "2023.01.01"),
    ("2023", "2023.01.01", "2024.01.01"),
    ("2024", "2024.01.01", "2025.01.01"),
    ("2025", "2025.01.01", "2026.01.01"),
    ("2023-2025", "2023.01.01", "2026.01.01"),
]

def run_backtest(from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"]    = "NAS100"
    env["SET_FILE"]  = "nas100.set"
    env["FROM_DATE"] = from_date
    env["TO_DATE"]   = to_date
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
    print(f"\n{'='*55}")
    print(f"  NAS100 Winner Validation — {len(WINDOWS)} windows")
    print(f"  Config: outdatedOB=120 + tol=80 + fibo1rstTP=2.0")
    print(f"{'='*55}\n")

    with codecs.open(BEST_SET, "r", "utf-16") as f:
        best_content = f.read()
    with codecs.open(SET_SRC, "w", "utf-16") as f:
        f.write(best_content)

    header = f"""# NAS100 Winner Validation
*Config: outdatedOB=120 + tolerance=80 + fibo1rstTP=2.0*
*Run: {datetime.now().strftime('%Y-%m-%d %H:%M')}*

| Year | PF | Balance | DD% | Trades | WR | Notes |
|---|---|---|---|---|---|---|
"""
    with open(RESULTS_MD, "w") as f:
        f.write(header)

    for label, from_d, to_d in WINDOWS:
        print(f"\n[{label}] {from_d} → {to_d}")
        t0 = time.time()
        rc = run_backtest(from_d, to_d)
        elapsed = time.time() - t0
        data = read_results()

        pf  = data.get("profit_factor", "n/a")
        bal = data.get("balance", 0)
        dd  = data.get("max_dd_pct", "n/a")
        tot = data.get("total_trades", "n/a")
        wr  = data.get("win_rate_str", "n/a")
        pf_v = float(str(pf).split()[0]) if pf != "n/a" else 0

        emoji = "✅" if pf_v >= 1.5 else ("⚠️" if pf_v >= 1.0 else "❌")
        note = ""
        if label == "2022":
            note = "Bear market"
        elif label == "2023":
            note = "Recovery"
        elif label == "2024":
            note = "Bull run"
        elif label == "2025":
            note = "Recent"
        elif label == "2023-2025":
            note = "Out-of-sample 3yr"

        line = f"| {label} | {pf} | {bal:.2f} | {dd} | {tot} | {wr} | {note} {emoji} |\n"
        with open(RESULTS_MD, "a") as f:
            f.write(line)

        print(f"  PF={pf}  Balance={bal:.2f}  Trades={tot}  WR={wr}  DD={dd}  ({elapsed:.0f}s)")

    print(f"\n{'='*55}")
    print(f"  Validation done — {RESULTS_MD}")
    print(f"{'='*55}\n")

if __name__ == "__main__":
    main()
