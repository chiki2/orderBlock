#!/usr/bin/env python3
"""
Trailing stop parameter sweep — MODEL=4 (real ticks) throughout.
Search space reduced to ~20 focused combinations for runtime ~30 min.

Parameters:
  - enableTrailingStop: false (baseline)
  - trailingStrat: 0=CLASSIC, 1=ATR
  - trailingStopPoints: 400, 600, 800, 1000, 1200  (classic only)
  - ATR_multiplier: 1.0, 1.5, 2.0, 2.5, 3.0       (ATR only)
  - tslTrigger: 0=ALWAYS, 1=FIB127, 2=FIB161, 3=FIB238
"""
import codecs, subprocess, json, os, re, csv, sys

SCRIPT_DIR = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC    = f"{SCRIPT_DIR}/OBInclude/SetFiles/claude.set"
RESULT_CSV = f"{SCRIPT_DIR}/trail_results.csv"

FROM_DATE = "2022.01.01"
TO_DATE   = "2025.01.01"
MODEL     = 4          # real ticks throughout

TSL_NAMES = {0: "ALWAYS", 1: "FIB127", 2: "FIB161", 3: "FIB238"}

def patch(key, val):
    with codecs.open(SET_SRC, 'r', 'utf-16') as f:
        c = f.read()
    pattern = rf'^({re.escape(key)}=)[^|]*(\|\|.*)'
    c2 = re.sub(pattern, rf'\g<1>{val}\2', c, flags=re.MULTILINE)
    with codecs.open(SET_SRC, 'w', 'utf-16') as f:
        f.write(c2)

def patch_trail(enable, strat, points, atr_mult, trigger):
    patch('enableTrailingStop', 'true' if enable else 'false')
    patch('trailingStrat',      str(strat))
    patch('trailingStopPoints', f'{float(points):.1f}')
    patch('ATR_multiplier',     f'{float(atr_mult):.1f}')
    patch('tslTrigger',         str(trigger))

def run_backtest():
    env = os.environ.copy()
    env['FROM_DATE'] = FROM_DATE
    env['TO_DATE']   = TO_DATE
    env['MODEL']     = str(MODEL)
    subprocess.run(
        ['bash', 'backtest.sh'], cwd=SCRIPT_DIR, env=env,
        capture_output=True, text=True, timeout=600
    )
    try:
        with open(f"{SCRIPT_DIR}/backtest_last.json") as f:
            return json.load(f)
    except Exception:
        return {}

def score(d):   return float(d.get('ontester', 0) or 0)
def pf(d):
    try:    return float(d.get('profit_factor', 0) or 0)
    except: return 0.0
def trades(d):
    try:    return int(d.get('traded', 0) or 0)
    except: return 0
def bal(d):
    try:    return float(d.get('balance', 0) or 0)
    except: return 0.0

results = []

def run_config(label, enable, strat, points, atr_mult, trigger, phase):
    patch_trail(enable, strat, points, atr_mult, trigger)
    d = run_backtest()
    s = score(d); p = pf(d); t = trades(d); b = bal(d)
    print(f"  {label:<32}  {t:>6}  {p:>7.2f}  {s:>8.4f}  {b:.0f}")
    sys.stdout.flush()
    results.append({'label': label, 'enable': enable, 'strat': strat,
                    'points': points, 'atr': atr_mult, 'trigger': trigger,
                    'score': s, 'pf': p, 'traded': t, 'balance': b, 'phase': phase})

header = f"  {'Label':<32}  {'Traded':>6}  {'PF':>7}  {'Score':>8}  bal"

# ── Baseline ────────────────────────────────────────────────────────────────
print(f"\n═══ BASELINE  (MODEL=4, 2022-2025) ═══")
print(header)
run_config("NO_TSL",  False, 0, 800,  2.0, 0, 0)

# ── Classic trailing stop — sweep points × trigger ──────────────────────────
# Points: 400, 600, 800, 1000, 1200  ×  Trigger: ALWAYS, FIB127, FIB161
# (skip FIB238 — very rarely triggered; 15 combinations)
print(f"\n═══ CLASSIC trailing stop (MODEL=4) ═══")
print(header)
for pts in [400, 600, 800, 1000, 1200]:
    for trig in [0, 1, 2]:
        label = f"CLASSIC pts={pts} {TSL_NAMES[trig]}"
        run_config(label, True, 0, pts, 2.0, trig, 1)

# ── ATR trailing stop — sweep multiplier × trigger ──────────────────────────
# ATR mult: 1.0, 1.5, 2.0, 2.5, 3.0  ×  Trigger: ALWAYS, FIB127
# (10 combinations — most impactful subset)
print(f"\n═══ ATR trailing stop (MODEL=4) ═══")
print(header)
for atr in [1.0, 1.5, 2.0, 2.5, 3.0]:
    for trig in [0, 1]:
        label = f"ATR x{atr:.1f} {TSL_NAMES[trig]}"
        run_config(label, True, 1, 800, atr, trig, 2)

# ── Results ─────────────────────────────────────────────────────────────────
results.sort(key=lambda x: x['score'], reverse=True)
print(f"\n═══ FULL RANKING (all {len(results)} configs) ═══")
print(header)
for r in results:
    mark = " ★" if r == results[0] else ""
    print(f"  {r['label']:<32}  {r['traded']:>6}  {r['pf']:>7.2f}  {r['score']:>8.4f}  {r['balance']:.0f}{mark}")

best = results[0]
baseline = next(r for r in results if not r['enable'])
print(f"\n★ WINNER: {best['label']}")
print(f"  score={best['score']:.4f}  PF={best['pf']:.2f}  trades={best['traded']}  balance={best['balance']:.0f}")
print(f"\n  Baseline (no TSL): PF={baseline['pf']:.2f}  trades={baseline['traded']}  balance={baseline['balance']:.0f}")
print(f"  Δ balance: {best['balance']-baseline['balance']:+.0f}")

# ── Save CSV ────────────────────────────────────────────────────────────────
with open(RESULT_CSV, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(results[0].keys()))
    w.writeheader(); w.writerows(results)
print(f"\nResults saved: {RESULT_CSV}")

# ── Apply winner ─────────────────────────────────────────────────────────────
patch_trail(best['enable'], best['strat'], best['points'], best['atr'], best['trigger'])
print("claude.set updated to winner config.")
