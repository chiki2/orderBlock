#!/usr/bin/env python3
"""
KZ hour optimization via coordinate descent.
Phase 1: Fix KZ2=18-20, sweep KZ1 (start/end).
Phase 2: Fix KZ1=best, sweep KZ2 (start/end).
Uses MODEL=1 (1-min OHLC, fast) for grid; validates top-5 with MODEL=4.
"""
import codecs, subprocess, json, os, re, csv, sys
from itertools import product

SCRIPT_DIR = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
SET_SRC    = f"{SCRIPT_DIR}/OBInclude/SetFiles/claude.set"
RESULT_CSV = f"{SCRIPT_DIR}/kz_results.csv"

FROM_DATE = "2022.01.01"
TO_DATE   = "2025.01.01"

def patch_kz(kz1s, kz1e, kz2s, kz2e):
    with codecs.open(SET_SRC, 'r', 'utf-16') as f:
        c = f.read()
    c = re.sub(r'^(inpKZ1Start=)\d+(\|\|)', rf'\g<1>{kz1s}\2', c, flags=re.MULTILINE)
    c = re.sub(r'^(inpKZ1End=)\d+(\|\|)',   rf'\g<1>{kz1e}\2', c, flags=re.MULTILINE)
    c = re.sub(r'^(inpKZ2Start=)\d+(\|\|)', rf'\g<1>{kz2s}\2', c, flags=re.MULTILINE)
    c = re.sub(r'^(inpKZ2End=)\d+(\|\|)',   rf'\g<1>{kz2e}\2', c, flags=re.MULTILINE)
    with codecs.open(SET_SRC, 'w', 'utf-16') as f:
        f.write(c)

def run_backtest(model=1):
    env = os.environ.copy()
    env['FROM_DATE'] = FROM_DATE
    env['TO_DATE']   = TO_DATE
    env['MODEL']     = str(model)
    proc = subprocess.run(
        ['bash', 'backtest.sh'], cwd=SCRIPT_DIR, env=env,
        capture_output=True, text=True, timeout=600
    )
    try:
        with open(f"{SCRIPT_DIR}/backtest_last.json") as f:
            return json.load(f)
    except Exception:
        return {}

def score(d):
    """OnTester composite: winRate * PF * (1-DD) * log10(trades+1)"""
    return float(d.get('ontester', 0) or 0)

def pf(d):
    try: return float(d.get('profit_factor', 0) or 0)
    except: return 0.0

def trades(d):
    try: return int(d.get('traded', 0) or 0)
    except: return 0

# ── Phase 1: sweep KZ1, fix KZ2=18-20 ─────────────────────────────────────
print("\n═══ PHASE 1: Sweep KZ1 (KZ2 fixed at 18-20 UTC) ═══")
print(f"{'KZ1':>12} {'KZ2':>12} {'Placed':>7} {'PF':>7} {'Score':>8}  bal")

phase1 = []
KZ2_FIXED = (18, 20)

for kz1s, kz1e in product(range(6, 13), range(13, 18)):
    if kz1e <= kz1s + 2:      # need at least 3h window
        continue
    patch_kz(kz1s, kz1e, *KZ2_FIXED)
    d = run_backtest(model=1)
    s = score(d); p = pf(d); t = trades(d); b = d.get('balance', 10000)
    label1 = f"{kz1s:02d}-{kz1e:02d}"
    label2 = f"{KZ2_FIXED[0]:02d}-{KZ2_FIXED[1]:02d}"
    print(f"  KZ1={label1}  KZ2={label2}  {t:>6}  {p:>7.2f}  {s:>8.4f}  {b:.0f}")
    phase1.append({'kz1s': kz1s, 'kz1e': kz1e, 'kz2s': KZ2_FIXED[0], 'kz2e': KZ2_FIXED[1],
                   'score': s, 'pf': p, 'traded': t, 'balance': b, 'phase': 1})
    sys.stdout.flush()

phase1.sort(key=lambda x: x['score'], reverse=True)
best_kz1 = (phase1[0]['kz1s'], phase1[0]['kz1e'])
print(f"\n→ Best KZ1: {best_kz1[0]:02d}-{best_kz1[1]:02d}  (score={phase1[0]['score']:.4f})")

# ── Phase 2: sweep KZ2, fix KZ1=best ──────────────────────────────────────
print(f"\n═══ PHASE 2: Sweep KZ2 (KZ1 fixed at {best_kz1[0]:02d}-{best_kz1[1]:02d} UTC) ═══")
print(f"{'KZ1':>12} {'KZ2':>12} {'Placed':>7} {'PF':>7} {'Score':>8}  bal")

phase2 = []
for kz2s, kz2e in product(range(15, 22), range(18, 24)):
    if kz2e <= kz2s + 1:
        continue
    if kz2s >= best_kz1[1]:   # KZ2 should not overlap heavily with KZ1 end
        pass                   # allow some overlap — let data decide
    patch_kz(*best_kz1, kz2s, kz2e)
    d = run_backtest(model=1)
    s = score(d); p = pf(d); t = trades(d); b = d.get('balance', 10000)
    label1 = f"{best_kz1[0]:02d}-{best_kz1[1]:02d}"
    label2 = f"{kz2s:02d}-{kz2e:02d}"
    print(f"  KZ1={label1}  KZ2={label2}  {t:>6}  {p:>7.2f}  {s:>8.4f}  {b:.0f}")
    phase2.sort(key=lambda x: x['score'], reverse=True)
    phase2.append({'kz1s': best_kz1[0], 'kz1e': best_kz1[1], 'kz2s': kz2s, 'kz2e': kz2e,
                   'score': s, 'pf': p, 'traded': t, 'balance': b, 'phase': 2})
    sys.stdout.flush()

phase2.sort(key=lambda x: x['score'], reverse=True)

# ── Validation: top 5 unique configs with Model=4 ─────────────────────────
all_results = phase1 + phase2
all_results.sort(key=lambda x: x['score'], reverse=True)

# deduplicate by (kz1s, kz1e, kz2s, kz2e)
seen = set(); top5 = []
for r in all_results:
    key = (r['kz1s'], r['kz1e'], r['kz2s'], r['kz2e'])
    if key not in seen:
        seen.add(key)
        top5.append(r)
    if len(top5) == 5:
        break

print(f"\n═══ VALIDATION: Top-5 with Model=4 (real ticks, 2022-2025) ═══")
print(f"{'Config':>25} {'M1 score':>10} {'M4 traded':>10} {'M4 PF':>8} {'M4 score':>10}  M4 balance")
validated = []
for r in top5:
    patch_kz(r['kz1s'], r['kz1e'], r['kz2s'], r['kz2e'])
    d = run_backtest(model=4)
    s4 = score(d); p4 = pf(d); t4 = trades(d); b4 = d.get('balance', 10000)
    label = f"KZ1={r['kz1s']:02d}-{r['kz1e']:02d} KZ2={r['kz2s']:02d}-{r['kz2e']:02d}"
    print(f"  {label:<23}  {r['score']:>10.4f}  {t4:>10}  {p4:>8.2f}  {s4:>10.4f}  {b4:.0f}")
    validated.append({**r, 'm4_score': s4, 'm4_pf': p4, 'm4_traded': t4, 'm4_balance': b4})
    sys.stdout.flush()

validated.sort(key=lambda x: x['m4_score'], reverse=True)
best = validated[0]
print(f"\n★ WINNER: KZ1={best['kz1s']:02d}-{best['kz1e']:02d} KZ2={best['kz2s']:02d}-{best['kz2e']:02d}")
print(f"  M4 score={best['m4_score']:.4f}  PF={best['m4_pf']:.2f}  trades={best['m4_traded']}  balance={best['m4_balance']:.0f}")

# ── Save CSV ───────────────────────────────────────────────────────────────
with open(RESULT_CSV, 'w', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(validated[0].keys()))
    w.writeheader(); w.writerows(validated)
print(f"\nResults saved: {RESULT_CSV}")

# ── Restore best config ────────────────────────────────────────────────────
patch_kz(best['kz1s'], best['kz1e'], best['kz2s'], best['kz2e'])
print("claude.set updated to winner config.")
