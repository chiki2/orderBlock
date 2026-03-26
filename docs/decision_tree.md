# OrderBlock EA — Filter Decision Tree & Test Coverage Matrix

*Generated: 2026-03-24 | Branch: 1.60 | Symbols analysed: XAUUSD, EURUSD, GBPUSD, USDJPY, EURJPY, GBPJPY, AUDJPY, NAS100, USDX*

---

## 1. Visual Decision Tree

Every Order Block (OB) detected on the M15 chart must pass each gate in sequence.
The cascade is ordered from cheapest (time-based, computed once per bar) to most expensive
(MSS/SWEEP GPU-accelerated). A filter that fires early cancels all downstream checks.

```
OB DETECTED on M15 (detectNewOB)
│
├── [GATE 1] DAILY BIAS CHECK (inpDailyBiasEnabled)
│   ├── true  → check current daily bias; skip if OB direction opposes bias
│   └── false → pass (no daily bias required)
│
├── [GATE 2] allChecks CACHE
│   └── returns cached result if OB already evaluated this bar
│
├── [GATE 3] IMBALANCE / FVG SIZE (isImbalanced)
│   ├── minImBalanced (raw MT5 points, symbol-calibrated)
│   │   XAUUSD: 40 | EURUSD: 40 | USDJPY: 40 | GBPUSD: 40 | NAS100: 40
│   └── inpMSSRequireFVG (require FVG to exist at MSS break point)
│       ├── true  → MSS break must co-occur with imbalance — HIGH QUALITY
│       └── false → MSS break alone sufficient (more signals, lower quality)
│
├── [GATE 4] MITIGATION CHECK (isMitigated)
│   └── skip OB if price has already closed through it
│
├── [GATE 5] LAST SIGNIFICANT STRUCTURE CANDLE (lssc)
│   └── internal quality threshold
│
├── [GATE 6] MSS BREAK (checkForMSSBefore / isMSS)
│   ├── lookback = 20 bars (do NOT reduce; 0 trades below 15)
│   ├── lastCandleCheck > 30 bars
│   └── inpMSSRequireFVG (also checked here)
│
├── [GATE 7] CISD / LOWER MSS (isLowerMss)
│   └── confirms internal structure break inside the OB zone
│
├── [GATE 8] LIQUIDITY SWEEP BEFORE OB (checkLiquiditySweepBeforeOB)
│   ├── inpRequireSweep (bool)
│   │   ├── true  → liquidity sweep REQUIRED before OB (default — strict gate)
│   │   │           XAUUSD: drops 6520 OBs → ~16 tradeable
│   │   └── false → no sweep required (XAUUSD: 0 trades; EURJPY: floods with low quality)
│   └── tolerance (sweep proximity in raw points)
│       XAUUSD: 50 | EURUSD: 50 | USDJPY: 80 | GBPUSD: 50 | EURJPY: 80
│       tested: tol=30,50,80,100 across symbols
│
├── [GATE 9] IMBALANCE FILLED CHECK (ImbalancedFilled)
│   └── FVG above OB must not already be filled
│
├── [GATE 10] ZONE VALIDITY (isZoneValid)
│   └── OB zone price bounds still valid
│
├── [GATE 11] TOP IMPACT VALIDITY (topImpValid)
│   └── top-of-OB impulse candle check
│
├── [GATE 12] HTF RANGE CHECK
│   └── skip if higher timeframe is in a ranging state
│
├── [GATE 13] W1 MACRO TREND (inpMacroTrendEnabled)
│   ├── true  → skip ALL OBs when W1 trend = RANGE (lookback=24 bars)
│   │           CRITICAL: disabling causes 280x DD explosion on XAUUSD
│   └── false → no W1 filter (more signals but far lower quality)
│
├── [GATE 14] D1 TREND FILTER (inpRequireD1Trend)
│   ├── true  → reject OBs counter to daily trend (lookback=5)
│   └── false → no D1 direction requirement
│       Note: D1=false is a big unlock for USDJPY (+60 trades, PF 6.65 but DD 10%)
│
├── [GATE 15] H4 TREND FILTER (inpRequireH4Trend)
│   ├── true  → reject OBs counter to H4 trend (lookback=5) — tested, consistently hurts
│   └── false → no H4 requirement (CONFIRMED DEFAULT — H4 filter degrades all symbols)
│
├── [GATE 16] HTF COUNTER-TREND BLOCK (inpBlockCounterHTF)
│   ├── true  → block SELL when W1 bullish / BUY when W1 bearish
│   └── false → allow counter-trend entries (default)
│       Forensics: Bull+Short = 23% WR; but enabling has zero effect on XAUUSD (all 10 trades kept)
│
├── [GATE 17] SWING STRUCTURE (inpRequireSwingStructure)
│   └── additional swing high/low structure validation
│
│   --- OB PASSES QUALITY GATES — NOW CHECK TIME + VOLATILITY FILTERS ---
│
├── [GATE 18] OB AGE / EXPIRY (outdatedOB)
│   ├── Default: 80 bars (OB expires after 80 M15 bars = ~20 hours)
│   ├── 40  → fewer, fresher OBs — USDJPY WINNER (5/5 cross-year)
│   ├── 120 → EURUSD: worsens | USDJPY: worsens | GBPUSD: neutral
│   ├── 160 → EURUSD: neutral | XAUUSD: no effect
│   └── 200 → XAUUSD: no effect
│
├── [GATE 19] KILL ZONE TIME FILTER (inpKillZoneEnabled)
│   ├── false → trade 24/7 (more signals, more noise; mixed results per symbol)
│   ├── KZ1: inpKZ1Start / inpKZ1End (first session window)
│   └── KZ2: inpKZ2Start / inpKZ2End (second session window)
│       Tested configurations:
│       XAUUSD:  11-14 + 20-23 UTC (gold: Tokyo close + NY close)
│       USDJPY:  08-12 + 13-16 UTC (London + NY)
│       EURJPY:  08-12 + 13-17 UTC (London + NY)
│       GBPUSD:  08-12 + 13-16 UTC (London + NY)
│       EURUSD:  08-12 + 13-16 UTC (London + NY)
│       London only (07/08-12):   tested — worsens all symbols vs dual-session
│       NY only (13-17):          tested — worsens
│       Tokyo+London (00-04+08-12): tested — worsens EURJPY, USDJPY, AUDJPY
│       Wide (08-17+18-23):       tested — worsens USDJPY, EURJPY
│       KZ disabled:              tested — mixed (GBPUSD slightly better; others worse)
│
├── [GATE 20] DAY-OF-WEEK FILTER (forbidMondayFriday)
│   ├── true  → skip Monday AND Friday entries
│   │           EURJPY: PF 1.22→1.81 (+48%), 4/5 cross-year WINNER
│   │           GBPUSD: PF 1.17→1.67 (+43%), 4/5 cross-year WINNER
│   └── false → trade all days (default before Mar 2026)
│       Note: Skip Tuesday also tested (XAUUSD forensics: +3.13R net, not implemented as input)
│
├── [GATE 21] DEATH HOUR FILTER (inpSkip09UTC)
│   ├── true  → skip entries at 09:00 UTC (London open fakeout zone)
│   │           XAUUSD: PF 6.65→357.65 (massive DD reduction, -1 trade)
│   └── false → allow 09:00 entries (default)
│
├── [GATE 22] H4 INSIDE BAR FILTER (inpSkipH4InsideBar)
│   ├── true  → skip entry when H4 candle is an inside bar (indecision)
│   │           XAUUSD forensics: 46% of losses vs 10% of wins had H4 IB at entry
│   │           Effect: zero on XAUUSD dataset (no trades removed from 10T sample)
│   └── false → allow H4 inside bar entries (default)
│
├── [GATE 23] D1 WICK REJECTION FILTER (inpD1WickFilter)
│   ├── true  → skip entry when D1 lower wick ratio > threshold (institutional rejection)
│   │           XAUUSD forensics: losses had 0.381 wick ratio vs 0.159 for wins
│   │           Effect in sweep: removes 3 trades, drops PF from 6.65 to 3.27
│   └── false → allow high-wick D1 entries (default)
│
├── [GATE 24] ATR VOLATILITY FILTER (inpATR_MaxPct / inpATR_MinPct)
│   ├── inpATR_MaxPct > 0 → skip if ATR% of price exceeds threshold (avoid chaotic days)
│   │   XAUUSD: 0.5% calibrated | FX: ~0.3-0.7% typical
│   │   Bug note: old ATR_max used raw price units — fixed in #64 (Mar 2026)
│   ├── inpATR_MinPct > 0 → skip if ATR% too low (avoid dead-market entries)
│   │   XAUUSD forensics: ATR_min=1.0 no effect | =2.0 modest | =3.0 kills good trades
│   └── Both disabled (0) = default for all FX symbols
│       ATR MaxPct sweep (GBPUSD, 10 tests): zero effect on FX symbols
│
├── [GATE 25] MAX SPREAD FILTER (inpMaxSpread)
│   ├── 2 pips → tested EURUSD, zero effect (spread always within range in backtest)
│   ├── 5 pips → tested EURUSD, zero effect
│   └── 0 (disabled) → tested EURUSD, zero effect
│       NOTE: all 3 values produce identical results — spread filter dead in backtest
│
├── [GATE 26] OB GEOMETRY FILTERS
│   ├── maxWickRatio (OB candle wick-to-body ratio)
│   │   1.2 → tested (no improvement), 2.0 → tested (no improvement)
│   │   FINDING: zero/negative effect on all tested symbols
│   ├── minBodySize (OB candle minimum body in points)
│   │   5 → tested (no effect on EURUSD/GBPUSD), 20 → tested (no effect)
│   │   FINDING: zero effect on all tested symbols
│   └── Both parameters are effectively dead filters for current symbol set
│
│   --- OB PASSES ALL FILTERS — NOW CHECK TRADE VALIDITY ---
│
├── [GATE 27] ENTRY MODE SELECTION
│   ├── typeofOrder (1=LIMIT, 2=STOP)
│   │   LIMIT: entry at OB midpoint/fib50 — lower win rate but better R:R
│   │   STOP:  entry at OB break — higher win rate but tighter SL
│   │   Per-symbol:
│   │     XAUUSD: LIMIT only (STOP never triggers)
│   │     EURUSD: LIMIT (STOP tested — marginal improvement)
│   │     USDJPY: LIMIT (PF 1.00 → STOP 1.07; both weak on 2022-2026 baseline)
│   │     EURJPY: STOP WINNER (PF 1.04→1.19, then to 1.22 with tp=1.5)
│   │     GBPUSD: LIMIT (STOP tested — no improvement vs LIMIT baseline)
│   ├── inpEntryMode (fib50 = OB midpoint, fib80 = deeper entry)
│   └── fiboEntry (numeric fib level for entry placement)
│
├── [GATE 28] MINIMUM R:R CHECK (inpMinRR)
│   ├── > 0 → skip if TP_distance < SL_distance × inpMinRR
│   │   UNTESTED on all symbols — identified as surgical fix for GBPUSD pathological cases
│   └── 0 (disabled) → all R:R accepted (current default)
│
├── [GATE 29] MAXIMUM R:R CAP (inpMaxRR)
│   ├── > 0 → skip if R:R ratio > inpMaxRR (avoid noise trades with extreme ratios)
│   │   XAUUSD tested: MaxRR=3.0 (PF drops), =4.0 (neutral), =5.0 (neutral)
│   │   SHAP finding: rr_ratio > 4:1 is top loss driver
│   └── 0 (disabled) → current default for all non-XAUUSD symbols
│
├── [GATE 30] SL DISTANCE LIMITS (inpMaxSLPoints / inpMinSLPoints)
│   ├── inpMaxSLPoints → skip if SL distance exceeds max (avoid huge stops)
│   └── inpMinSLPoints → skip if SL distance below min (avoid noise stops)
│       UNTESTED on all symbols — SHAP shows sl_dist_pts < 2 is a top loss driver
│
│   --- TRADE PLACED (LIMIT or STOP ORDER) ---
│
└── [POST-PLACEMENT MANAGEMENT]
    │
    ├── [PM-1] OB EXPIRY CANCEL (outdatedOB timer)
    │   └── Cancel pending order if OB age > outdatedOB bars without fill
    │
    ├── [PM-2] BREAKEVEN / PROTECTION (enableProtection)
    │   ├── true  → move SL to BE when price reaches inpProtectionLevel
    │   └── false → no breakeven (default off for most symbols)
    │
    ├── [PM-3] EARLY BREAKEVEN (inpEarlyBreakEven)
    │   ├── true  → move SL to BE earlier (before fib80)
    │   └── false → default BE timing
    │       UNTESTED on all symbols
    │
    ├── [PM-4] TRAILING STOP (enableTrailingStop + trailingStopPoints)
    │   ├── Tested values: 400 pts, 800 pts (3 FX symbols)
    │   │   FINDING: both values worsen results vs no trailing stop
    │   └── Disabled = current best for all tested symbols
    │
    ├── [PM-5] PARTIAL CLOSE (PartialMode)
    │   ├── true  → close part of position at fib80 (first partial TP)
    │   └── false → hold full position to fib127 TP
    │       UNTESTED — current default is PartialMode=true for most symbols
    │
    └── [PM-6] TAKE PROFIT LEVEL (fibo1rstTP)
        └── Fib level for TP placement:
            1.27 → default (conservative TP at 1.27× OB range)
            2.0  → tested GBPUSD (worse), EURUSD (worse), USDJPY (better but DD up)
            2.5  → tested GBPUSD (worse), EURUSD (marginal), EURJPY (worse)
            3.0  → tested USDJPY (WINNER: PF 1.00→1.57), GBPUSD (worse), EURUSD (best but DD ×1.7)
            1.5  → tested EURJPY (WINNER with STOP orders: PF 1.22)
```

---

## 2. Coverage Matrix

Legend: `W` = tested, winner applied | `T` = tested, not winner | `-` = not tested | `NA` = not applicable

### Time Filters

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| inpKillZoneEnabled on/off | W | T | W | W | T | T | T | - | - |
| KZ: London only (08-12) | T | T | T | T | T | - | - | - | - |
| KZ: NY only (13-17) | - | - | - | T | - | - | - | - | - |
| KZ: London+NY (08-17 split) | T | W | W | W | W | W | - | - | - |
| KZ: Tokyo+London (00-04+08-12) | T | - | T | T | - | - | T | - | - |
| KZ: Wide (08-17+18-23) | T | - | T | T | - | - | - | - | - |
| KZ: Custom gold (11-14+20-23) | W | - | - | - | - | - | - | - | - |
| forbidMondayFriday | - | - | T | W | W | - | - | - | - |
| inpSkip09UTC | W | - | - | T | - | - | - | - | - |
| inpSkipTuesday (not an input yet) | - | - | - | - | - | - | - | - | - |
| EnableCheckNews | - | - | - | - | - | - | - | - | - |

### Trend Filters

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| inpMacroTrendEnabled (W1) | W | T | T | T | T | - | - | - | T |
| inpRequireD1Trend | W | T | T | T | T | - | - | - | - |
| inpRequireH4Trend | T | - | - | T | - | - | - | - | - |
| inpBlockCounterHTF | T | - | - | - | - | - | - | - | - |
| D1=false + Macro=false combo | - | - | - | T | - | - | - | - | - |
| MacroTrend=false alone | T | T | T | T | T | - | - | - | T |
| D1=false alone | T | T | W | T | T | - | - | - | - |

### OB Quality / Structure Filters

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| minImBalanced (FVG size) | - | - | - | - | - | - | - | - | - |
| inpMSSRequireFVG (enable/disable) | T | T | T | - | W | - | - | - | - |
| inpRequireSweep (enable/disable) | T | - | - | T | - | - | - | - | - |
| outdatedOB=40 | - | - | W | T | T | - | - | - | - |
| outdatedOB=80 (default) | W | W | W | W | W | W | W | W | W |
| outdatedOB=120 | - | T | T | T | T | - | - | - | - |
| outdatedOB=160 | T | T | - | T | - | - | - | - | - |
| outdatedOB=200 | T | - | - | - | - | - | - | - | - |
| tolerance=30 | - | - | - | T | - | - | - | - | - |
| tolerance=50 (default FX) | W | W | W | T | W | W | W | - | - |
| tolerance=80 (JPY calibrated) | - | T | T | W | T | - | - | - | T |
| tolerance=100 | - | - | - | - | - | - | - | - | T |
| maxWickRatio sweep | - | T | T | T | T | - | - | - | - |
| minBodySize sweep | - | T | T | T | T | - | - | - | - |
| inpSkipH4InsideBar | T | T | T | T | T | - | - | - | - |
| inpD1WickFilter | T | T | T | T | T | - | - | - | - |
| inpRequireSwingStructure | - | - | - | - | - | - | - | - | - |
| inpHistoricalScanBars sweep | - | - | - | - | - | - | - | - | - |
| MSS lookback sweep | - | - | - | - | - | - | - | - | - |
| lastCandleCheck sweep | - | - | - | - | - | - | - | - | - |

### Volatility Filters

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| ATR_max (raw, old — deprecated) | T | NA | NA | NA | NA | NA | NA | NA | NA |
| inpATR_MaxPct (normalized %) | - | - | - | - | T | - | - | - | - |
| inpATR_MinPct (normalized %) | T | - | - | - | T | - | - | - | - |
| inpMaxSpread | - | T | - | - | - | - | - | - | - |
| inpVolumeFilter | T | T | T | T | T | - | - | - | - |

### Entry Mode

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| typeofOrder LIMIT (=1) | W | W | W | T | W | W | W | W | W |
| typeofOrder STOP (=2) | NA | T | T | W | T | - | - | - | - |
| inpEntryMode (fib50/fib80) | - | - | - | - | - | - | - | - | - |
| fiboEntry value sweep | - | - | - | - | - | - | - | - | - |

### Risk / TP

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| fibo1rstTP=1.27 (default) | W | W | T | T | W | W | W | W | W |
| fibo1rstTP=1.5 | - | - | - | W | - | - | - | - | - |
| fibo1rstTP=2.0 | - | T | T | T | T | - | - | - | - |
| fibo1rstTP=2.5 | - | T | T | T | T | - | - | - | - |
| fibo1rstTP=3.0 | - | T | W | T | T | - | - | - | - |
| inpMinRR | - | - | - | - | - | - | - | - | - |
| inpMaxRR=3.0 | T | - | - | - | - | - | - | - | - |
| inpMaxRR=4.0 | T | - | - | - | - | - | - | - | - |
| inpMaxRR=5.0 | T | - | - | - | - | - | - | - | - |
| inpMaxSLPoints | - | - | - | - | - | - | - | - | - |
| inpMinSLPoints | - | - | - | - | - | - | - | - | - |

### Position Management

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| enableTrailingStop | - | T | T | T | T | - | - | - | - |
| trailingStopPoints=400 | - | T | T | T | T | - | - | - | - |
| trailingStopPoints=800 | - | T | T | T | T | - | - | - | - |
| enableProtection (BE) | - | - | - | - | - | - | - | - | - |
| inpEarlyBreakEven | - | - | - | - | - | - | - | - | - |
| PartialMode on/off | - | - | - | - | - | - | - | - | - |

### Signal Timeframe

| Parameter | XAUUSD | EURUSD | USDJPY | EURJPY | GBPUSD | GBPJPY | AUDJPY | NAS100 | USDX |
|---|---|---|---|---|---|---|---|---|---|
| CTOB=M5 | T | - | - | - | - | - | - | - | - |
| CTOB=M15 (confirmed best) | W | W | W | W | W | W | W | W | W |
| CTOB=M30 | T | - | - | - | - | - | - | - | - |
| CTOB=H1 | T | - | - | - | - | - | - | - | - |
| HTOB=H1 (confirmed) | W | W | W | W | W | W | W | W | W |

---

## 3. Untested Combinations — Priority List

Ranked by estimated impact on deployable symbols (USDJPY, EURJPY, GBPUSD, XAUUSD).

### Priority 1 — XAUUSD Trade Volume (Critical — OOS 2026 = 0 trades)

The current XAUUSD configuration is effectively dead in live trading (0 trades Jan-Mar 2026).
The following have NOT been tested and are the most likely remedies:

| # | Untested Combination | Rationale | Expected Effect | Risk |
|---|---|---|---|---|
| 1a | XAUUSD: Disable Skip09UTC, widen KZ to 08-16 | KZ already restricts; Skip09UTC double-restricts | +3-5 trades/yr | May re-add 09 losses |
| 1b | XAUUSD: KZ 07-10 + 11-14 + 20-23 (3-session) | London open is active for gold | +2-3 trades/yr | Modest DD increase |
| 1c | XAUUSD: Lower minimum stars threshold | Quality gate may be too aggressive | +2-4 trades/yr | Lower WR |
| 1d | XAUUSD: inpHistoricalScanBars=50-100 (from 30) | Older unmitigated OBs missed at init | +1-2 trades/yr | Old OBs lower quality |
| 1e | XAUUSD: forbidMondayFriday=true | Active forensic finding (Wed/Tue worst days) | Cleaner PF | Further sparsity |
| 1f | XAUUSD: inpMaxRR=4.0 + Skip09UTC=false | MaxRR=4 already tested, skip09=false uncharted | Unknown | May flood losses |

### Priority 2 — EURUSD Improvement (Currently: PF 1.14, regime-dependent, NOT deployed)

EURUSD has had 24 tests but remains fragile. These combinations are untested:

| # | Untested Combination | Rationale | Expected Effect | Risk |
|---|---|---|---|---|
| 2a | EURUSD: forbidMondayFriday=true | Works for GBPUSD, EURJPY — likely applies | Remove 2023 weakness | May reduce trade count too much |
| 2b | EURUSD: fibo1rstTP=3.0 + FVG=true | FVG=true is winner; tp=3.0 best on other symbols | Better balance | Higher DD |
| 2c | EURUSD: STOP + tp=3.0 | STOP+high TP untested combo | Better R:R for euro | Low WR |
| 2d | EURUSD: inpMinRR=0.8 (min R:R gate) | Filters pathological trades; no code change needed if param exists | Remove bad R:R setups | Lose a few good ones |
| 2e | EURUSD: MacroTrend=false + forbidMondayFriday=true | Macro hurts EURUSD; NoMonFri compensates | Net positive? | Untested interaction |
| 2f | EURUSD: tolerance=20-30 (tighter sweep) | Tighter sweep = higher-quality entries only | Higher WR, fewer trades | Low sample size |
| 2g | EURUSD: outdatedOB=40 | Works for USDJPY — fresher OBs reduce stale setups | Fewer, cleaner trades | May reduce already-small count |

### Priority 3 — USDJPY Further Hardening (Currently: 5/5, PF 1.86 — DEPLOYED)

USDJPY is the best symbol but can potentially be improved:

| # | Untested Combination | Rationale | Expected Effect | Risk |
|---|---|---|---|---|
| 3a | USDJPY: forbidMondayFriday=true | Untested for JPY; proven for EUR/GBP | PF improvement? | Fewer than 34 trades |
| 3b | USDJPY: inpMinRR=0.8-1.0 | SHAP: sl_dist_pts < 2 is top loss driver | Filter noise trades | Small effect expected |
| 3c | USDJPY: fibo1rstTP=3.0 + outdatedOB=40 (combined) | Both are winners individually — interaction untested | Compounding improvement? | Overfitting risk |
| 3d | USDJPY: inpSkip09UTC=true | Tested for XAUUSD only; London open noise relevant for USDJPY too | +WR | -Trades |
| 3e | USDJPY: PartialMode=false (hold full position to TP) | Partial close may cut winners early | Higher PF per trade | More variance |
| 3f | USDJPY: enableProtection (BE) + tp=3.0 | BE at fib80, ride to tp=3.0 | Higher R:R per winner | BE may trigger prematurely |

### Priority 4 — EURJPY Final Hardening (Currently: 4/5, PF 1.81 — DEPLOYED)

EURJPY 2022 is the weak year (PF not confirmed). Options to address:

| # | Untested Combination | Rationale | Expected Effect | Risk |
|---|---|---|---|---|
| 4a | EURJPY: STOP + tp=1.5 + forbidMondayFriday + tol=80 | All three individually improve results; combo untested | PF 1.81→2.0+? | May reduce to <30 trades |
| 4b | EURJPY: inpSkip09UTC=true + STOP + tp=1.5 | Death hour applies to JPY too | Remove bad opens | -Trades |
| 4c | EURJPY: fibo1rstTP=1.5 + outdatedOB=40 | Fresher OBs + shorter TP tested separately | Interaction unknown | Small sample |
| 4d | EURJPY: inpMinRR=1.0 (enforce 1:1 minimum) | STOP orders have structural R:R issue near entry | Remove <1:1 trades | Unknown count effect |
| 4e | EURJPY: MacroTrend=false + forbidMondayFriday | MacroTrend was borderline for EURJPY; NoMonFri compensates | Net positive? | Untested |

### Priority 5 — GBPUSD 2025 Weakness Fix (Currently: 4/5, PF 1.67 — DEPLOYED)

2025 is the only failing year (PF 0.59). Solutions not yet tested:

| # | Untested Combination | Rationale | Expected Effect | Risk |
|---|---|---|---|---|
| 5a | GBPUSD: fibo1rstTP=1.5 (short TP) | Forensics: many GBP losses come from giving back gains | Better lock-in? | Lower overall PF |
| 5b | GBPUSD: inpMinRR=0.8 | Filters the Dec 2025 disaster (1.7 pip TP vs 18.7 pip SL) | Direct fix for 2025 | Needs input param |
| 5c | GBPUSD: forbidMondayFriday + FVG + inpMinRR | Stack all three winners + new filter | Maximum hardening | Overfitting risk |
| 5d | GBPUSD: outdatedOB=40 + FVG=true | Fresher OBs + FVG quality — interaction untested | Cleaner entries | Fewer trades |
| 5e | GBPUSD: enableProtection + forbidMondayFriday | BE prevents giving back profits (2025 pattern) | Lower DD in bad years | Complexity increase |
| 5f | GBPUSD: fibo1rstTP=3.0 with LIMIT | High TP + LIMIT (vs previously tested STOP + high TP) | Untested combination | High DD risk |

### Priority 6 — Cross-Filter Interaction Effects (All Symbols)

These two-dimensional interactions have NEVER been tested together:

| # | Combination | Symbols to Test | Rationale |
|---|---|---|---|
| 6a | forbidMondayFriday + Skip09UTC | EURUSD, USDJPY, XAUUSD | Double time filter — additive or redundant? |
| 6b | inpMSSRequireFVG + outdatedOB=40 | EURUSD, USDJPY | Quality stack: fresh OBs + FVG confirmation |
| 6c | tolerance=80 + outdatedOB=40 + STOP | EURJPY, GBPJPY | JPY-specific triple combo |
| 6d | MacroTrend=false + forbidMondayFriday | EURUSD, EURJPY | MacroTrend blocks too aggressively in ranging years; NoMonFri partially compensates |
| 6e | fibo1rstTP=3.0 + inpMinRR=1.0 | USDJPY, EURUSD | High TP only taken when R:R justifies it |
| 6f | PartialMode=false + fibo1rstTP=2.0 | USDJPY, GBPUSD | Holding full position to middle TP |
| 6g | enableProtection + fibo1rstTP=3.0 | USDJPY | BE at fib80, ride to fib300 TP |
| 6h | inpHistoricalScanBars=60 + outdatedOB=40 | XAUUSD | More OBs detected + shorter validity window |

### Priority 7 — Unexplored Code Capabilities

Parameters that exist in inputs.mqh but have NEVER been swept on ANY symbol:

| Parameter | Type | Current Default | Why Never Tested | Priority |
|---|---|---|---|---|
| inpMinRR | double | 0 (disabled) | Exists as input; never activated | HIGH — surgical fix for R:R |
| inpMaxSLPoints | int | 0 (disabled) | Noise-stop filter | HIGH — per SHAP findings |
| inpMinSLPoints | int | 0 (disabled) | Noise-stop filter | HIGH — per SHAP findings |
| inpEarlyBreakEven | bool | false | Post-entry management untested | MEDIUM |
| PartialMode | bool | true | Assumed optimal; never tested false | MEDIUM |
| enableProtection (BE) | bool | false | Breakeven never tested | MEDIUM |
| inpRequireSwingStructure | bool | false | Swing structure gate dormant | LOW |
| fiboEntry (entry fib level) | double | 0.5 | Entry precision never swept | LOW |
| inpEntryMode | enum | fib50 | Alternate entry modes untested | LOW |
| inpHistoricalScanBars | int | 30 | Only XAUUSD sparsity context raised it | MEDIUM |
| EnableCheckNews | bool | false | News filter never tested | LOW |
| MinutesBeforeNews | int | 30 | Paired with above | LOW |
| ADX_Max/Period/Threshold | doubles | 0 | ADX regime filter proposed but never coded as live filter | LOW |

---

## 4. Recommended Next Sweeps

Ordered by expected information gain per backtest-hour invested.

### Sweep A — XAUUSD Sparsity Fix (Urgent: OOS 2026 = 0 trades)

**Objective**: Restore trade flow without destroying the high PF.
**Estimate**: 8-12 tests, ~30 minutes

```python
configs = [
    {"label": "Disable Skip09UTC only",      "inpSkip09UTC": False},
    {"label": "KZ: 07-10 + 11-14 + 20-23",  "inpKZ1Start":7, "inpKZ1End":10, "inpKZ2Start":11, "inpKZ2End":14},
    {"label": "KZ: 08-16 + 20-23 (wider)",  "inpKZ1Start":8, "inpKZ1End":16, "inpKZ2Start":20, "inpKZ2End":23},
    {"label": "forbidMondayFriday=true",     "forbidMondayFriday": True},
    {"label": "outdatedOB=40 (fresh only)",  "outdatedOB": 40},
    {"label": "Skip09UTC=false + forbidMonFri", "inpSkip09UTC": False, "forbidMondayFriday": True},
    {"label": "Widen KZ + no D1Wick",        "inpKZ1Start":8, "inpKZ1End":16, "inpD1WickFilter": False},
    {"label": "inpHistoricalScanBars=60",    "inpHistoricalScanBars": 60},
]
```

**Success criteria**: >= 4 trades/yr with PF >= 3.0 across 2022-2026.

---

### Sweep B — EURUSD Robustness (Currently not deployed, PF 1.14)

**Objective**: Find a configuration that passes cross-year validation (4/5 windows).
**Estimate**: 10-14 tests, ~45 minutes

```python
configs = [
    {"label": "forbidMondayFriday=true",                         "forbidMondayFriday": True},
    {"label": "forbidMondayFriday + FVG=true",                   "forbidMondayFriday": True, "inpMSSRequireFVG": True},
    {"label": "forbidMondayFriday + tp=3.0",                     "forbidMondayFriday": True, "fibo1rstTP": 3.0},
    {"label": "forbidMondayFriday + tp=3.0 + FVG",               "forbidMondayFriday": True, "fibo1rstTP": 3.0, "inpMSSRequireFVG": True},
    {"label": "outdatedOB=40 + FVG=true",                        "outdatedOB": 40, "inpMSSRequireFVG": True},
    {"label": "forbidMondayFriday + outdatedOB=40",              "forbidMondayFriday": True, "outdatedOB": 40},
    {"label": "tolerance=30 (tighter sweep)",                    "tolerance": 30},
    {"label": "STOP + tp=1.5 + forbidMonFri",                    "typeofOrder": 2, "fibo1rstTP": 1.5, "forbidMondayFriday": True},
]
```

**Success criteria**: PF >= 1.3 over 2022-2026 with 3+/5 years profitable.

---

### Sweep C — USDJPY+EURJPY+GBPUSD Combined Hardening

**Objective**: Test inpMinRR, PartialMode=false, and forbidMondayFriday combos for deployed symbols.
**Estimate**: 12-18 tests across 3 symbols, ~60 minutes

```python
configs_usdjpy = [
    {"label": "forbidMondayFriday=true",              "forbidMondayFriday": True},
    {"label": "forbidMondayFriday + tp=3.0 + OB=40", "forbidMondayFriday": True, "fibo1rstTP": 3.0, "outdatedOB": 40},
    {"label": "PartialMode=false",                    "PartialMode": False},
    {"label": "Skip09UTC=true",                       "inpSkip09UTC": True},
]

configs_eurjpy = [
    {"label": "STOP + tp=1.5 + tol=80 + NoMonFri",   "typeofOrder": 2, "fibo1rstTP": 1.5, "tolerance": 80, "forbidMondayFriday": True},
    {"label": "STOP + tp=1.5 + Skip09UTC",            "typeofOrder": 2, "fibo1rstTP": 1.5, "inpSkip09UTC": True},
    {"label": "STOP + tp=1.5 + outdatedOB=40",        "typeofOrder": 2, "fibo1rstTP": 1.5, "outdatedOB": 40},
]

configs_gbpusd = [
    {"label": "FVG + NoMonFri + outdatedOB=40",       "inpMSSRequireFVG": True, "forbidMondayFriday": True, "outdatedOB": 40},
    {"label": "FVG + NoMonFri + Skip09UTC",           "inpMSSRequireFVG": True, "forbidMondayFriday": True, "inpSkip09UTC": True},
    {"label": "FVG + NoMonFri + PartialMode=false",   "inpMSSRequireFVG": True, "forbidMondayFriday": True, "PartialMode": False},
]
```

---

### Sweep D — inpMinRR Gate (Code Required First)

**Prerequisite**: Verify `inpMinRR` is already wired in `cOrderBlock.mqh`. If not, add it (SHAP priority #1).
**Objective**: Filter out pathologically bad R:R trades on deployed symbols.
**Estimate**: 9 tests (3 values × 3 symbols), ~30 minutes after code is confirmed working

```python
rr_values = [0.5, 0.8, 1.0]  # minimum acceptable R:R
symbols = ["USDJPY", "GBPUSD", "EURJPY"]
```

**Expected impact based on SHAP analysis**: Primary loss driver is extreme rr_ratio.
MinRR=0.8 should remove the worst outliers without touching normal trades.

---

### Sweep E — GBPJPY/AUDJPY Re-evaluation (Not viable yet — informational)

**Objective**: Determine if any combination achieves cross-year viability, or confirm "do not deploy" verdict.
**Estimate**: 8 tests each, ~30 minutes total

```python
configs_gbpjpy = [
    {"label": "forbidMondayFriday=true",              "forbidMondayFriday": True},
    {"label": "KZ + forbidMondayFriday",              "inpKillZoneEnabled": True, "forbidMondayFriday": True},
    {"label": "STOP + tp=1.5 + forbidMonFri",         "typeofOrder": 2, "fibo1rstTP": 1.5, "forbidMondayFriday": True},
    {"label": "KZ + outdatedOB=40 + NoMonFri",        "inpKillZoneEnabled": True, "outdatedOB": 40, "forbidMondayFriday": True},
]
```

**Success criteria**: ANY window achieving >= 3/5 profitable years with PF >= 1.4 would warrant continued optimization.
Currently at 1/5 for GBPJPY and 2/5 for AUDJPY — likely not fixable by parameters alone.

---

## 5. Key Known Results Summary

### Confirmed Winners (applied in set files)
| Finding | Symbol | Effect | Commit |
|---|---|---|---|
| Skip09UTC=true | XAUUSD | PF 6.65→357.65 (-1 trade, -99.9% DD) | 744739e |
| fibo1rstTP=3.0 | USDJPY | PF 1.00→1.57, 5/5 cross-year | 744739e |
| STOP + tp=1.5 + tol=80 | EURJPY | PF 1.04→1.81, 4/5 cross-year | 6e9eccc |
| forbidMondayFriday | EURJPY | PF 1.42→1.81, 3/5→4/5 | 6e9eccc |
| forbidMondayFriday | GBPUSD | PF 1.30→1.67, 3/5→4/5 | 6e9eccc |
| inpMSSRequireFVG=true | GBPUSD | PF 0.94→1.17 initially, then +NoMonFri | 744739e |
| outdatedOB=40 | USDJPY | 5/5 cross-year (was 1.63 with OB=80) | 6e9eccc |

### Confirmed Non-Winners (do not re-test)
| Finding | Effect | Symbols Tested |
|---|---|---|
| H4 trend filter | Consistently hurts (fewer trades, same or worse PF) | XAUUSD, EURJPY |
| maxWickRatio sweep | Zero / negative effect | EURUSD, USDJPY, EURJPY, GBPUSD |
| minBodySize sweep | Zero effect | EURUSD, USDJPY, EURJPY, GBPUSD |
| inpVolumeFilter | Zero / negative effect | EURUSD, USDJPY, EURJPY, GBPUSD, XAUUSD |
| inpD1WickFilter | Removes too many valid trades | XAUUSD (PF 6.65→3.27) |
| TrailingStop (400/800 pts) | Worsens all tested symbols | EURUSD, USDJPY, EURJPY, GBPUSD |
| ATR MaxPct | Zero effect on FX symbols | GBPUSD |
| inpRequireSweep=false | 0 trades XAUUSD; low quality EURJPY | XAUUSD, EURJPY |
| KZ: London-only | Worse than dual-session on all symbols | EURUSD, USDJPY, EURJPY, GBPUSD |
| KZ: Tokyo+London | Worse than standard on JPY symbols | USDJPY, EURJPY, AUDJPY |
| LIMIT + tp > 1.27 | Worsens EURUSD, GBPUSD (USDJPY exception) | EURUSD, GBPUSD |
| STOP + tp=3.0 | Catastrophic for EURJPY (PF 0.75) | EURJPY |

### Symbols by Deploy Status
| Symbol | Status | Cross-Year | Config |
|---|---|---|---|
| USDJPY | DEPLOY | 5/5 | KZ+D1+Macro+tp=3.0+OB=40 |
| EURJPY | DEPLOY | 4/5 | STOP+tp=1.5+tol=80+D1+Macro+NoMonFri |
| GBPUSD | DEPLOY | 4/5 | KZ+FVG+NoMonFri |
| XAUUSD | DEPLOY (sparse) | 4/5 | KZ+DailyBias+Macro+D1+Skip09UTC |
| EURUSD | NOT DEPLOYED | 1/5 | Regime-dependent; 2023 broken |
| GBPJPY | DO NOT DEPLOY | 1/5 | Fundamental issues |
| AUDJPY | DO NOT DEPLOY | 2/5 | Declining trend |
| NAS100 | NOT TESTED (2022-26) | - | 0 trades in vertical uptrend |
| USDX | DO NOT DEPLOY | 1/5 | Cancellation storm; unstable |

---

*This document should be updated after each sweep session. Key data source files:*
- *`/docs/usdjpy_test_results.md` — 17 USDJPY tests*
- *`/docs/eurjpy_full_results.md` — 41 EURJPY tests*
- *`/docs/eurjpy_combo_results.md` — 12 EURJPY combo tests*
- *`/docs/gbpusd_test_results.md` — 16 GBPUSD tests*
- *`/docs/eurusd_test_results.md` — 24 EURUSD tests*
- *`/docs/xauusd_test_results.md` — 17 XAUUSD profile/sparsity tests*
- *`/docs/forensics_filter_results.md` — 20 XAUUSD forensics filter tests*
- *`/docs/cross_year_results.md` — 20 cross-year validation tests*
- *`/docs/cross_year_validation_mar23.md` — 35 cross-year validation tests (7 symbols)*
- *`/docs/jpy_crosses_probe.md` — 3 JPY cross probe tests*
- *`/docs/require_sweep_results.md` — inpRequireSweep test*
- *`/docs/correlation_analysis.md` — multi-symbol correlation study*
