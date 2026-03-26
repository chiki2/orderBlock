#!/usr/bin/env python3
"""
Weak-year forensics: investigate losing trades in underperforming windows.
- EURJPY 2022 (PF=0.77, 12 trades)
- GBPUSD 2025 (PF=0.72, 6 trades)

For each weak window:
1. Run backtest with current settings
2. Export OB dataset
3. Analyze losing trades: time, direction, market regime
4. Compare with winning years to find divergence patterns
"""
import subprocess, json, time, codecs, os, csv, sys
from datetime import datetime

BASE = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
os.chdir(BASE)
sys.path.insert(0, BASE)
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log

TIMEOUT = 1800

def apply_overrides(set_file, overrides, symbol):
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
    tmp_name = f"_tmp_{symbol.lower()}_forensics.set"
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

def parse_html_trades(html_path):
    """Extract individual trades from MT5 HTML report."""
    if not os.path.exists(html_path):
        return []
    with open(html_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    trades = []
    # MT5 HTML reports have trade rows in tables
    # Look for rows with buy/sell entries
    import re
    # Find all table rows
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', content, re.DOTALL)
    for row in rows:
        cells = re.findall(r'<td[^>]*>(.*?)</td>', row, re.DOTALL)
        if len(cells) >= 8:
            # Clean HTML tags from cells
            clean_cells = [re.sub(r'<[^>]+>', '', c).strip() for c in cells]
            # Look for trade entry rows (buy/sell)
            trade_type = clean_cells[2].lower() if len(clean_cells) > 2 else ""
            if trade_type in ("buy", "sell"):
                trades.append({
                    "time": clean_cells[0],
                    "deal": clean_cells[1],
                    "type": clean_cells[2],
                    "direction": clean_cells[3] if len(clean_cells) > 3 else "",
                    "volume": clean_cells[4] if len(clean_cells) > 4 else "",
                    "price": clean_cells[5] if len(clean_cells) > 5 else "",
                    "profit": clean_cells[8] if len(clean_cells) > 8 else "",
                })
    return trades

# Windows to analyze
WEAK_WINDOWS = [
    ("EURJPY", "eurjpy.set", "2022", "2022.01.01", "2023.01.01", {}),
    ("EURJPY", "eurjpy.set", "2023", "2023.01.01", "2024.01.01", {}),  # comparison (winning year)
    ("GBPUSD", "gbpusd.set", "2025", "2025.01.01", "2026.01.01", {}),
    ("GBPUSD", "gbpusd.set", "2023", "2023.01.01", "2024.01.01", {}),  # comparison (best year)
]

def main():
    print(f"\n{'='*70}", flush=True)
    print(f"  WEAK-YEAR FORENSICS ANALYSIS", flush=True)
    print(f"  Purpose: Understand WHY certain years underperform", flush=True)
    print(f"{'='*70}\n", flush=True)

    report_path = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/claudeReport.htm"
    all_results = []

    for i, (symbol, set_file, year, from_d, to_d, overrides) in enumerate(WEAK_WINDOWS):
        print(f"\n{'='*50}", flush=True)
        print(f"  [{i+1}/{len(WEAK_WINDOWS)}] {symbol} {year}", flush=True)
        print(f"{'='*50}", flush=True)

        actual_set = set_file
        if overrides:
            actual_set = apply_overrides(set_file, overrides, symbol)

        t0 = time.time()
        result = run_backtest(symbol, actual_set, from_d, to_d)
        elapsed = time.time() - t0

        diag = scan_last_backtest()

        if result:
            pf = float(result.get("profit_factor", 0) or 0)
            trades_n = result.get("traded", 0) or result.get("total_trades", 0) or 0
            try:
                trades_n = int(trades_n)
            except:
                trades_n = 0
            dd = float(result.get("max_dd_pct", 0) or 0)
            net = float(result.get("net_profit", 0) or 0)

            print(f"  PF={pf:.2f}  Trades={trades_n}  DD={dd:.2f}%  Net={net:.2f}  ({elapsed:.0f}s)", flush=True)
            print(format_oneliner(diag), flush=True)

            # Parse individual trades from HTML
            trade_list = parse_html_trades(report_path)

            # Analyze trade distribution
            wins = [t for t in trade_list if t.get("profit") and float(t["profit"].replace(" ", "").replace(",", "")) > 0]
            losses = [t for t in trade_list if t.get("profit") and float(t["profit"].replace(" ", "").replace(",", "")) < 0]

            print(f"\n  Trade details from HTML report:", flush=True)
            print(f"  Parsed {len(trade_list)} entry deals ({len(wins)}W / {len(losses)}L)", flush=True)

            if trade_list:
                # Analyze by month
                from collections import Counter
                months = Counter()
                for t in trade_list:
                    try:
                        month = t["time"][:7]  # YYYY.MM
                        months[month] += 1
                    except:
                        pass
                if months:
                    print(f"\n  Monthly distribution:", flush=True)
                    for m in sorted(months.keys()):
                        print(f"    {m}: {months[m]} trades", flush=True)

                # Direction distribution
                buys = sum(1 for t in trade_list if "buy" in t.get("type", "").lower())
                sells = len(trade_list) - buys
                print(f"\n  Direction: {buys} BUY / {sells} SELL", flush=True)

                # Show individual trades
                print(f"\n  Individual trades:", flush=True)
                for t in trade_list:
                    profit_str = t.get("profit", "?")
                    print(f"    {t.get('time', '?')}  {t.get('type', '?'):4s}  {t.get('price', '?'):>10s}  P/L: {profit_str}", flush=True)

            all_results.append({
                "symbol": symbol, "year": year, "pf": pf, "trades": trades_n,
                "dd": dd, "net": net, "wins": len(wins), "losses": len(losses),
                "trade_list": trade_list,
            })
        else:
            print(f"  FAIL ({elapsed:.0f}s)", flush=True)
            print(format_oneliner(diag), flush=True)

        if overrides:
            tmp_path = os.path.join(BASE, "OBInclude", "SetFiles", f"_tmp_{symbol.lower()}_forensics.set")
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    # Cross-comparison
    print(f"\n\n{'='*70}", flush=True)
    print(f"  CROSS-COMPARISON: WEAK vs STRONG YEARS", flush=True)
    print(f"{'='*70}", flush=True)

    for symbol in ["EURJPY", "GBPUSD"]:
        sym_results = [r for r in all_results if r["symbol"] == symbol]
        if len(sym_results) >= 2:
            weak = [r for r in sym_results if r["pf"] < 1.0]
            strong = [r for r in sym_results if r["pf"] >= 1.0]

            print(f"\n  {symbol}:", flush=True)
            for r in sym_results:
                label = "WEAK" if r["pf"] < 1.0 else "STRONG"
                print(f"    {r['year']} [{label}]: PF={r['pf']:.2f}  {r['wins']}W/{r['losses']}L  Net={r['net']:.2f}", flush=True)

            if weak and strong:
                w = weak[0]
                s = strong[0]

                # Direction analysis
                w_buys = sum(1 for t in w["trade_list"] if "buy" in t.get("type","").lower())
                w_sells = len(w["trade_list"]) - w_buys
                s_buys = sum(1 for t in s["trade_list"] if "buy" in t.get("type","").lower())
                s_sells = len(s["trade_list"]) - s_buys

                print(f"\n    Direction shift:", flush=True)
                print(f"      {w['year']} (weak):   {w_buys}B / {w_sells}S", flush=True)
                print(f"      {s['year']} (strong): {s_buys}B / {s_sells}S", flush=True)

    print(f"\n\nDone.", flush=True)

if __name__ == "__main__":
    main()
