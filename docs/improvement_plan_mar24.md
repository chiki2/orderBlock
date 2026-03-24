# Improvement Plan — 2026-03-24

Based on overnight cross-year validation (35 tests) and deep code analysis.

## Current State

| Symbol | Cross-Year | Status |
|--------|-----------|--------|
| USDJPY | 5/5 profitable | DEPLOY |
| GBPUSD | 4/5 profitable | DEPLOY |
| XAUUSD | 4/5 profitable but 2-6 trades/yr | Too sparse |
| EURJPY | **5/5** (tolerance=80) | DEPLOY (upgraded overnight) |
| AUDJPY | 2/5 | Not robust (KZ sweep confirmed) |
| GBPJPY | 1/5 | Not robust (KZ sweep confirmed) |
| USDX | 1/5 | Not robust |

## Overnight Results (completed)

### EURJPY tolerance=80 — PROMOTED TO DEPLOY
- Combo sweep (10 tests): tolerance=80 best (PF 1.27→1.42, DD 3.19%→2.85%)
- Cross-year revalidation: **5/5 profitable** (was 3/5 with tolerance=50)
- 2023: 0.82→1.01 | 2024: 0.94→1.06 | Applied to eurjpy.set

### GBPJPY/AUDJPY KZ Sweep (8 tests) — CONFIRMED NOT VIABLE
- Kill zones halve GBPJPY DD (12.55→5.20%) but PF stays <1.0
- AUDJPY: KZ actually worsens PF (0.91→0.72-0.78)
- Neither symbol is fixable by parameter tuning alone

### XAUUSD Sparsity Sweep (10 tests) — CURRENT CONFIG IS OPTIMAL
- Every filter relaxation causes DD explosion (28-57%)
- MacroTrend is the critical filter
- Wider KZ: 3x trades but 280x DD
- The strategy is inherently sparse for gold (2-6 high-quality setups/yr)

### Code Analysis — Key Findings
- `hasOppositeOB()` is dead code — declared but never called
- USDX cancellations come from: MT5 expiry timer + daily bias + OB mitigation
- ATR_max/ATR_min use raw price units — dead for non-XAUUSD (#64)
- ~30 unused input parameters in inputs.mqh

## Priority 1 — ATR Normalization Fix (GitHub #64)

**Problem**: `ATR_max=8.2` is raw price units, only works for XAUUSD. Dead for all other symbols.

**Location**: `OBInclude/OrderProcess.mqh:78-83`

**Fix**: Normalize to percentage of price:
```cpp
// Replace raw ATR comparison with normalized percentage
double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
double atr_pct = (bid > 0) ? (atr[0] / bid) * 100.0 : 0.0;

if(inpATR_MaxPct > 0 && atr_pct > inpATR_MaxPct)
{
    g_reasonCounters[ENUM_REASON_ATR_TOO_HIGH]++;
    return false;
}

if(inpATR_MinPct > 0 && atr_pct < inpATR_MinPct)
{
    g_reasonCounters[ENUM_REASON_ATR_TOO_LOW]++;
    return false;
}
```

**New inputs** in `inputs.mqh`:
```cpp
input double inpATR_MaxPct = 0.5;  // ATR Max (% of price, 0=disabled)
input double inpATR_MinPct = 0.0;  // ATR Min (% of price, 0=disabled)
```

**Default values** (based on XAUUSD calibration):
- XAUUSD @ $3000, ATR~8.2 → 0.27% → set max=0.5%
- EURUSD @ 1.08, typical ATR 0.003-0.008 → 0.28-0.74%
- USDJPY @ 150, typical ATR 0.5-2.0 → 0.33-1.33%

**Impact**: Enables ATR filtering for all symbols uniformly.

## Priority 2 — XAUUSD Trade Count

**Problem**: Only 2-6 trades/year with current filters. OOS 2026 has 0 trades.

**Root cause**: Kill zones (11-14 + 20-23 UTC = 6 hours/day) + Skip09UTC + D1Trend + MacroTrend stack multiplicatively.

**Options to test** (parameter-only, no code change):
1. **Widen KZ**: Try 08-16 + 18-23 (13 hours instead of 6)
2. **Disable Skip09UTC**: It removes 09:00 hour, but KZ already excludes it
3. **Disable D1Trend for XAUUSD**: Gold trends differently than FX
4. **Lower stars threshold**: Currently minimum quality might be too high

**Test plan**: Create `xauusd_sparsity_sweep.py` with 8-12 parameter combos.

## Priority 3 — GBPJPY/AUDJPY Kill Zones

**Finding**: GBPJPY and AUDJPY have `inpKillZoneEnabled=false` while USDJPY (5/5 profitable) has it enabled. Trading 24/7 includes low-liquidity hours.

**Fix**: Enable kill zones in set files:
```
inpKillZoneEnabled=true
inpKZ1Start=8    (same as USDJPY)
inpKZ1End=12
inpKZ2Start=13
inpKZ2End=17
```

**Test plan**: Run cross-year validation with KZ enabled for both symbols.

## Priority 4 — Dead Code Cleanup

### hasOppositeOB() — Dead Code
- Declared at `cOrderBlock.mqh:25`, implemented at `cOrderBlock.mqh:107-129`
- **Never called** from anywhere in the EA
- The actual USDX cancellations come from:
  1. MT5 `ORDER_TIME_SPECIFIED` expiry (outdatedOB timer)
  2. Daily bias realignment (OrderBlock.mq5:420)
  3. OB mitigation (OrderBlock.mq5:1510)
- **Action**: Remove dead function OR wire it up if opposite-OB detection is desired

### ATR reason tracking missing
- `OrderProcess.mqh:78-83` — ATR filters return false without incrementing `g_reasonCounters`
- **Fix**: Add reason tracking (trivial)

### ~30 unused input parameters
- ADX_Max, ADX_Period, ADX_Threshold
- EnableCheckNews, MinutesBeforeNews, MinutesAfterNews
- FirstBalance, SecondBalance, Npair
- Many display flags (displayCPR, displayPremiumDiscount, etc.)
- **Action**: Audit and remove in a cleanup commit

## Priority 5 — EURJPY Combo Testing

EURJPY is 3/5 profitable (2022, 2025, 2026 good; 2023, 2024 losing).

**Untested combo**: STOP + tp=1.5 + tolerance=80
- STOP orders work for momentum pairs
- tp=1.5 was the sweep winner
- tolerance=80 might help with partial fills

**Test plan**: Run EURJPY combo sweep with 6-8 variants.

## Priority 6 — Log Scanner Integration

`scripts/scan_tester_log.py` exists but is only used in `cross_year_mar23.py`.

**Action**: Integrate into all sweep scripts:
```python
from scripts.scan_tester_log import scan_last_backtest, format_oneliner, clear_log
# Before each backtest:
clear_log()
# After each backtest:
diag = scan_last_backtest()
print(format_oneliner(diag))
```

## Execution Order (suggested for Mar 24)

1. ATR normalization fix (#64) — code change + compile + test
2. GBPJPY/AUDJPY KZ enable — set file change + cross-year retest
3. XAUUSD sparsity sweep — parameter sweep (no code change)
4. EURJPY combo test — parameter sweep
5. Dead code cleanup — remove hasOppositeOB, unused params
6. Log scanner integration — update existing sweep scripts
