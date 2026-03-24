# Strategy Improvement Analysis
*Written: 2026-03-21 — post multi-symbol expansion (XAUUSD/NAS100/EURUSD/GBPUSD)*

---

## 1. The Real Bottleneck: OB Funnel

The biggest constraint across all symbols is how few OBs survive to trade:

| Symbol | Total OBs | Pass MSS | Pass SWEEP | Traded | Closed |
|---|---|---|---|---|---|
| XAUUSD 2022-26 | 6520 | ~100 | ~16 | 15 | 10 |
| EURUSD 2022-26 | ~5000+ | ~250 | ~90 | ~87 | 87 |
| GBPUSD 2022-26 (STOP) | ~5000+ | — | — | 119 | 119 |

**XAUUSD drops from 16 to 15 at the trading stage — the SWEEP filter is the killer.**
Of ~6520 OBs → ~3695 pass minimum quality → ~16 pass SWEEP+MSS → 15 traded.
The sweep requirement (liquidity sweep BEFORE the MSS) is extremely strict.

### Option A: Relax the Sweep Requirement
`checkLiquiditySweepBeforeOB()` is called inside `checkForMSSBefore()`. Currently a hard gate.
Could add an input `inpRequireSweep=true` and test with `=false` → would flood with more
signals but potentially much lower quality. Worth one test on XAUUSD.

### Option B: Loosen Sweep Tolerance
The sweep detection has a tolerance/distance parameter. Widening it would catch
"near-sweeps" that don't quite grab the liquidity pool but come close.

### Option C: Increase MSS Lookback Further
Currently `lastCandleCheck > 30` (was 12 → 30 gave +1T). Increasing to 50-60 would
catch delayed MSS breaks. Risk: lower quality (older MSS = weaker signal).

---

## 2. The 2025 Regime Problem (All Symbols)

Every symbol weakens in 2025:
- **XAUUSD**: 2 trades (sparse — parabolic uptrend, no pullbacks to OBs)
- **NAS100**: 0 trades (LIMIT orders never fill in vertical uptrend)
- **EURUSD**: PF 1.28 (OK but below average)
- **GBPUSD**: PF 0.58 (STOP orders false-breakout losses in Sept 2025)

**Root cause hypothesis**: 2025 saw impulsive, one-directional moves (XAUUSD parabolic to $3000+,
NAS100 sustained rally) driven by macro events (tariffs, rate expectations). OB-based strategies
rely on pullbacks and structure breaks — these didn't materialize cleanly.

### Option: ATR-Based Regime Filter
If D1 ATR > X × baseline_ATR (e.g. 2.0×), skip new OBs for that session.
Would automatically avoid parabolic/high-vol periods. Risk of overfitting to 2025 specifically.

### Option: Require Minimum Consolidation Before OB
Before accepting an OB, require N bars of consolidation (low ATR) after the impulse candle.
More OB-quality focused than regime-based. Less overfit risk.

### Option: Accept 2025 as Noise
4-year edge exists. A single weak year (even -2% balance) is within normal variance for
a 10-20 trade/year system. The edge hasn't broken — it's just a regime that doesn't suit
OB strategies. Many successful strategies have one weak year per 4-5.

**Recommendation**: Accept for now. Add ATR filter only if a 5th year of data also shows weakness.

---

## 3. XAUUSD Sparsity — Specific Ideas

Current: 10 closed trades in 4 years = 2.5/year. Goal: 15-25/year minimum for statistical significance.

### 3a. Profile Sweep (being tested now)
Profile 2 (Balanced, D1=off) is the most promising — same macro filter but wider KZ and
no D1 requirement. Profile 1 (Aggressive) removes DailyBias too.

### 3b. Second Entry on Mitigated OBs
Currently: once an OB is mitigated (price touches it), it's dead.
Idea: if price touches the OB but closes ABOVE it (for bullish), allow a second limit
entry on the next bar. The first touch validated the zone; the second retest is often
higher-probability.
**Complexity: medium. Impact: potentially +30-50% more trades from valid zones.**

### 3c. H1 OBs in Addition to M15
Currently signal timeframe = M15 (CTOB=15). H1 OBs (from CTOB=60) were tested and gave
0 trades for XAUUSD. But H1 as a *secondary* scan (detect H1 OBs, enter at M15 precision)
could add larger-timeframe setups. Different from just running on H1 — the entry would
still be precise (M15 candle confirmation within the H1 zone).

### 3d. Relax inpHistoricalScanBars
Currently scans 30 historical bars at init. Increasing to 50-100 would catch older OBs
that are still unmitigated. Risk: very old OBs may have low quality.

### 3e. Add London-Tokyo Overlap
Current KZ: 11-14 + 20-23 UTC. XAUUSD also moves significantly in the Asian session
(00-03 UTC) and London open (07-10 UTC). A 3rd KZ (07-10) might add 2-3 trades/year.

---

## 4. GBPUSD: STOP Orders R:R Fix

STOP orders with fibo1rstTP=1.27 have structural R:R ≈ 0.27:1.27 = 0.21:1.
Most 2025 losses come from trades with TP only 2-10 pips away while SL is 15-45 pips.

### Test: STOP orders + fibo1rstTP=2.0
For STOP entry at OB top: TP = 1.0× range above entry, SL = 1.27× range below.
R:R = 1.0:1.27 = 0.79:1. Better, but still below 1:1.

### Test: STOP orders + fibo1rstTP=3.0
R:R = 2.0:1.27 = 1.57:1. Proper positive expectancy but win rate will drop significantly.

### Test: Minimum R:R Input (Code Change)
Add `inpMinRR=0.8` input: skip any trade where TP_distance < SL_distance × inpMinRR.
This filters out the pathological cases (Dec 2025 trade: 1.7 pip TP vs 18.7 pip SL).
**Most surgical fix — only skips genuinely bad setups, doesn't change good ones.**

---

## 5. EURUSD: 2023 Weakness

EURUSD 2023 = PF 0.18 (ranging year — EUR/USD oscillated between 1.05-1.11 without
clean directional bias). The OB strategy needs trending conditions.

### Option: MacroTrend on D1 (not just W1)
Currently MacroTrend uses W1 (weekly). A D1-level range detector could also skip OBs
when D1 is clearly in a range. The existing D1Trend filter checks direction but not
the ranging vs trending character.

### Option: ADX-Based Filter
ADX > 25 = trending. ADX < 20 = ranging. Adding an ADX check on D1 would automatically
skip ranging months. Would need a new input and indicator call.

---

## 6. Multi-Symbol Correlation Management

Now running 4+ symbols simultaneously raises a new risk:
**Correlated drawdowns** — EURUSD and GBPUSD often move together. If a macro event
hits both at once (e.g. dollar squeeze), both can SL simultaneously.

### Option: Currency Exposure Cap
Don't allow simultaneous positions on USD pairs in the same direction.
If EUR/USD is long AND GBP/USD is long simultaneously, both are effectively long USD-basket.
A "max USD exposure" input could cap this. Moderate complexity.

### Option: Accept Correlation
For now, both symbols trade rarely enough (87 EURUSD + 119 GBPUSD = ~50/yr each)
that simultaneous positions are unlikely. Revisit if adding more USD pairs.

---

## 7. Priority Ranking (Impact vs Effort)

| # | Idea | Impact | Effort | Next Step |
|---|---|---|---|---|
| 1 | XAUUSD profile sweep results | High | Done | Review tomorrow |
| 2 | GBPUSD: STOP+fibo1rstTP=2.0/3.0 test | Medium | Low | 2 quick backtests |
| 3 | XAUUSD: test sweep=false (more signals) | High | Low | 1 set file change |
| 4 | USDJPY expansion | High | Low | Probe ready |
| 5 | Minimum R:R input (code change) | Medium | Medium | inputs.mqh + cOrderBlock |
| 6 | Second entry on mitigated OBs | High | High | Architecture change |
| 7 | 3rd KZ for XAUUSD (07-10 UTC) | Medium | Low | Test in optimizer |
| 8 | ATR regime filter | Low | High | Overfit risk too high |
| 9 | H1+M15 dual-timeframe entry | High | Very High | Major refactor |

---

## 8. Quick-Win List for Next Session

1. **Fix the binary**: `git checkout HEAD -- OrderBlock.ex5` before any XAUUSD retest
2. **GBPUSD**: test STOP+fibo1rstTP=2.0 and STOP+fibo1rstTP=3.0 (2 backtests, ~10 min)
3. **USDJPY probe**: run baseline (already prepped, watcher script waiting)
4. **XAUUSD sweep=false**: single test to see raw trade count without sweep requirement
5. **Review profile optimizer results** and pick winner for cross-year validation
