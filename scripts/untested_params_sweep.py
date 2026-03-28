#!/usr/bin/env python3
"""
Sweep high-priority NEVER-TESTED parameters from decision tree Priority 7:
- inpMinRR: minimum risk:reward ratio (surgical filter for bad R:R trades)
- inpMaxSLPoints: max stop-loss distance (noise filter)
- inpMinSLPoints: min stop-loss distance (noise filter — SHAP #1 loss driver)
- PartialMode=false: hold full position (never tested vs default=true)
- enableProtection: breakeven at +30 pts (never tested)

Test on all 3 deploy-ready symbols.
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

SYMBOLS = [
    ("USDJPY", "usdjpy.set"),
    ("EURJPY", "eurjpy.set"),
    ("GBPUSD", "gbpusd.set"),
]

PARAM_TESTS = [
    ("Baseline", {}),
    ("MinRR=0.5", {"inpMinRR": "0.5||0||0.1||2||N"}),
    ("MinRR=0.8", {"inpMinRR": "0.8||0||0.1||2||N"}),
    ("MinRR=1.0", {"inpMinRR": "1.0||0||0.1||2||N"}),
    ("MaxSL=500", {"inpMaxSLPoints": "500||0||50||2000||N"}),
    ("MaxSL=300", {"inpMaxSLPoints": "300||0||50||2000||N"}),
    ("MinSL=30", {"inpMinSLPoints": "30||0||10||200||N"}),
    ("MinSL=50", {"inpMinSLPoints": "50||0||10||200||N"}),
    ("NoPartial", {"PartialMode": "false||false||0||true||N"}),
    ("Protection", {"enableProtection": "true||false||0||true||N"}),
    ("MinRR0.5+Protection", {
        "inpMinRR": "0.5||0||0.1||2||N",
        "enableProtection": "true||false||0||true||N",
    }),
]


def apply_overrides(set_file, overrides, tag):
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
    tmp_name = f"_tmp_param_{tag}.set"
    tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", tmp_name)
    with codecs.open(tmp_path, "w", "utf-16") as f:
        f.writelines(new_lines)
    return tmp_name


def run_backtest(symbol, set_file, from_date, to_date):
    env = os.environ.copy()
    env["SYMBOL"] = symbol
    env["SET_FILE"] = set_file
    env["FROM_DATE"] = from_date
    env["TO_DATE"] = to_date
    env["DISPLAY"] = ":0"
    json_path = os.path.join(BASE, "backtest_last.json")
    if os.path.exists(json_path):
        os.remove(json_path)
    clear_log()
    subprocess.run(["bash", "backtest.sh"], capture_output=True, text=True,
                   timeout=TIMEOUT, env=env)
    if not os.path.exists(json_path):
        return None
    try:
        with open(json_path) as f:
            return json.load(f)
    except Exception:
        return None


def main():
    total = len(SYMBOLS) * len(PARAM_TESTS)
    print(f"\n{'='*70}", flush=True)
    print(f"  UNTESTED PARAMS SWEEP — {len(SYMBOLS)} symbols × {len(PARAM_TESTS)} tests = {total}", flush=True)
    print(f"{'='*70}\n", flush=True)

    csv_rows = []
    run_num = 0

    for symbol, set_file in SYMBOLS:
        print(f"\n{'='*50}", flush=True)
        print(f"  {symbol}", flush=True)
        print(f"{'='*50}", flush=True)

        for label, overrides in PARAM_TESTS:
            run_num += 1
            ts = datetime.now().strftime("%H:%M")
            print(f"\n[{run_num}/{total}] {ts} -- {symbol} {label}", flush=True)

            tag = f"{symbol.lower()}_{label.lower().replace('+','_').replace('=','')}"
            actual_set = apply_overrides(set_file, overrides, tag) if overrides else set_file

            t0 = time.time()
            result = run_backtest(symbol, actual_set, "2022.01.01", "2026.03.25")
            elapsed = time.time() - t0

            diag = scan_last_backtest()

            if result:
                pf = float(result.get("profit_factor", 0) or 0)
                trades = int(result.get("traded", 0) or result.get("total_trades", 0) or 0)
                dd_raw = str(result.get("max_dd_pct", 0) or 0)
                dd = float(dd_raw.split("%")[0].strip().split()[0]) if dd_raw and dd_raw != "0" else 0.0
                net_raw = str(result.get("net_profit", 0) or 0)
                net = float(net_raw.split()[0].replace(",", ".")) if net_raw and net_raw != "0" else 0.0
                print(f"  -> PF={pf:<8.2f} Trades={trades:<4} DD={dd:.2f}%  Net={net:+.2f}  ({elapsed:.0f}s)", flush=True)
            else:
                pf, trades, dd, net = 0, 0, 0, 0
                print(f"  -> FAIL ({elapsed:.0f}s)", flush=True)

            print(format_oneliner(diag), flush=True)

            csv_rows.append({
                "symbol": symbol, "test": label, "pf": pf,
                "trades": trades, "dd_pct": dd, "net": net,
            })

            tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_param_{tag}.set")
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    # Save CSV
    csv_file = "untested_params_results.csv"
    if csv_rows:
        with open(csv_file, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=csv_rows[0].keys())
            w.writeheader()
            w.writerows(csv_rows)
        print(f"\nCSV saved: {csv_file}", flush=True)

    # Summary
    print(f"\n{'='*70}", flush=True)
    print(f"  UNTESTED PARAMS RESULTS", flush=True)
    print(f"{'='*70}", flush=True)
    for symbol, _ in SYMBOLS:
        sym_rows = [r for r in csv_rows if r["symbol"] == symbol]
        baseline = next((r for r in sym_rows if r["test"] == "Baseline"), None)
        if not baseline:
            continue
        print(f"\n  {symbol} (baseline PF={baseline['pf']:.2f}, {baseline['trades']}T):", flush=True)
        for r in sym_rows:
            if r["test"] == "Baseline":
                continue
            delta = r["pf"] - baseline["pf"]
            trade_delta = r["trades"] - baseline["trades"]
            mark = "+" if delta > 0 else ""
            star = " ***" if delta > 0.1 else ""
            print(f"    {r['test']:<22s} PF={r['pf']:<8.2f} T={r['trades']:<4} DD={r['dd_pct']:.2f}%  dPF={mark}{delta:.2f}  dT={trade_delta:+d}{star}", flush=True)


if __name__ == "__main__":
    main()
