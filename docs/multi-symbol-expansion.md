# Multi-Symbol Expansion — OrderBlock EA

**Date**: 2026-03-20
**Branch**: 1.60
**XAUUSD baseline**: 10T, PF 3.84, DD 10.53%, $23,847 (2022-2026, commit 0b30fe9)

---

## Motivation

The EA was designed and tuned exclusively for XAUUSD. The ICT/SMC methodology behind it (order blocks, market structure shifts, liquidity sweeps) is instrument-agnostic and should transfer to other liquid, institutionally-driven markets.

---

## Instrument Ranking (OB Strategy Compatibility)

### Tier 1 — Best Fit

| Instrument | Grade | Kill Zone Fit | Key Strength |
|---|---|---|---|
| **XAUUSD** | A+ | London 11-14 ✓, NY 20-23 ✓ | Deepest sweeps, cleanest OBs, #1 ICT instrument |
| **NAS100** | A | NY open 13-16 ✓, PM 19-22 ✓ | High ATR, clean MSS, NY open = reliable displacement |
| **EURUSD** | A- | London retracements ✓ | Cleanest FX structure, lowest false-positive rate |
| **GBPUSD** | A- | London + NY ✓ | High displacement, sweep behavior mirrors Gold |

### Tier 2 — Good (needs tuning)

| Instrument | Grade | Caveat |
|---|---|---|
| **GER40 (DAX)** | B+ | Frankfurt open 06-09 UTC outside current KZs — needs new KZ |
| **USDJPY** | B+ | Shallower pullbacks → fewer LIMIT fills |
| **US500** | B | Lower ATR than NAS100, smaller R:R |
| **XAGUSD** | B- | Follows Gold but thinner liquidity, more false signals |
| **GBPJPY** | B- | High R:R but wide spread hurts LIMIT strategy |

### Tier 3 — Poor Fit

| Instrument | Reason |
|---|---|
| **BTCUSD/Crypto** | 24/7 market = no session-based liquidity pools; KZ logic breaks |
| **WTI Crude** | OPEC/inventory news destroys OBs unpredictably |
| **Exotic FX** | Thin liquidity, spreads eliminate edge |
| **Individual stocks** | Earnings destroy multi-day OBs |

---

## What Makes an Instrument OB-Compatible

1. **Deep institutional participation** — large orders leave footprints across multiple candles (OBs)
2. **High liquidity** — tight spreads, large daily volume; thin markets produce noise
3. **Session-based structure** — liquidity pools (BSL/SSL) form at predictable session boundaries
4. **Trending with structured retracements** — OBs only matter if price returns before continuing
5. **Clean swing highs/lows** — institutions must target liquidity predictably

---

## NAS100 — Expansion #1

### Why NAS100 First

- Architecture maps directly: M15 + H1, LIMIT orders, MSS + SWEEP work identically
- NY open (13:30 UTC) falls inside existing kill zone window (13-16 UTC)
- High ATR = good R:R with deep retracements to OBs
- Massive CME futures institutional footprint → clean OBs
- Community consensus: 55-68% win rates with MSS confirmation on NAS100

### Parameter Adaptations vs XAUUSD

| Parameter | XAUUSD (claude.set) | NAS100 (nas100.set) | Reason |
|---|---|---|---|
| `inpKillZoneEnabled` | false | **true** | Asian session is noisy for US indices — must filter |
| `inpKZ1Start/End` | 13-17 | **13-16** | NY pre-market/open window |
| `inpKZ2Start/End` | 13-23 | **19-22** | NY afternoon power hour |
| `inpMSSRequireFVG` | false | **false** | FVGs less common on NAS100 M15 (keep disabled to get more trades first) |
| `inpMaxSpread` | 0 (no limit) | **5 pts** | NAS100 has wider spread than Gold |
| `inpMacroTrendEnabled` | false | **false** | NAS100 2022-2026 had bear + bull; W1 trend filter risky |
| `inpRequireD1Trend` | true | **true** | Keep quality filter |
| `uniqueMagicNumber` | 1234555 | **1234566** | Avoid conflicts when running both EAs simultaneously |
| `Npair` | USD | **USD** | NAS100 is USD-denominated |

### NAS100 Kill Zone Logic

```
UTC  00  01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20  21  22  23
          [Asia quiet ─────────────────────────────────────────] [London──] [NY open ──] [─────] [PM──]
                                                                             ████████████       ████████
                                                                             KZ1 (13-16)        KZ2 (19-22)
```

- **KZ1 (13-16 UTC)**: Captures NY pre-market + cash open (09:00-12:00 EDT). Highest volatility window for NAS100. OBs formed earlier get tested as NY participants enter.
- **KZ2 (19-22 UTC)**: NY afternoon session. Institutional re-positioning after lunch. Momentum continuation plays.

### Parameters NOT Changed (require backtested justification)

- `ATR_max=8.2` — may need scaling for NAS100 point values (monitor first run)
- `minBodySize=10` — internal EA units; may behave differently for NAS100 points
- `lookback=20` in checkForMSSBefore — XAUUSD-tuned, may need adjustment
- `lastCandleCheck=30` — keep same initially
- `riskByTrade=0.2` — keep same (0.2% per trade)

---

## How to Run NAS100 Backtest

```bash
cd "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"

# Full 2022-2026 test (recommended for proper sample size)
SYMBOL=NAS100 SET_FILE=nas100.set FROM_DATE=2022.01.01 TO_DATE=2026.01.01 bash backtest.sh

# 2025-only fast sanity check
SYMBOL=NAS100 SET_FILE=nas100.set FROM_DATE=2025.01.01 TO_DATE=2026.01.01 bash backtest.sh
```

The `SET_FILE` env var was added to `backtest.sh` (2026-03-20) to support multiple set files without overwriting `claude.set`.

---

## backtest.sh — SET_FILE Support

`backtest.sh` now accepts a `SET_FILE` env variable:

```bash
# Default (unchanged)
bash backtest.sh                          # uses claude.set + XAUUSD

# NAS100
SYMBOL=NAS100 SET_FILE=nas100.set bash backtest.sh

# EURUSD (future)
SYMBOL=EURUSD SET_FILE=eurusd.set bash backtest.sh
```

The set file is resolved from `OBInclude/SetFiles/$SET_FILE` and copied to the MT5 presets folder before each run.

---

## Expansion Roadmap

### Phase 1 — NAS100 (current)
- [x] Create `nas100.set` with NY session kill zones
- [x] Add `SET_FILE` env support to `backtest.sh`
- [ ] Run initial 2022-2026 backtest
- [ ] Compare funnel metrics (totalOB, fc_mss, fc_sweep) vs XAUUSD
- [ ] Tune parameters if needed (ATR scaling, MSS lookback, KZ windows)

### Phase 2 — EURUSD
- Create `eurusd.set`: London KZ (08-12 UTC), consider STOP orders, `inpMSSRequireFVG` test
- Key watch: `tolerance` and `minBodySize` (EURUSD moves in pips, different scale)

### Phase 3 — GBPUSD
- Similar to EURUSD but wider stops; sweep filter should work well

### Phase 4 — GER40 (conditional)
- Requires adding Frankfurt KZ (06-09 UTC) to the EA inputs
- Only pursue if NAS100 and EURUSD show positive results

---

## Key Risk Factors for Multi-Symbol Deployment

1. **Regime sensitivity**: EA was optimized for XAUUSD's 2022-2026 regime (parabolic uptrend). NAS100 had a 2022 bear market — the D1 trend filter is critical.
2. **Point/pip scaling**: Parameters like `minBodySize`, `tolerance`, `ATR_max` may behave differently across symbols with different point values. Monitor first run output carefully.
3. **LIMIT fill rate**: Gold has deep 50%+ retracements to OBs. NAS100 sometimes has shallower pullbacks — watch the `overdue` counter; if high, consider `typeofOrder=1` (STOP) as alternative.
4. **Spread**: NAS100 spread during volatile moments can spike. `inpMaxSpread=5` will filter some entries — tune if too restrictive.
5. **Magic number collision**: Each symbol must use a unique `uniqueMagicNumber` to avoid EA managing wrong positions.

---

## Backtest Results Log

### XAUUSD — Baseline (2022-2026)
| Metric | Value |
|---|---|
| Trades | 10 |
| Win% | 70% |
| PF | 3.84 |
| Balance | $23,847 |
| DD% | 10.53% |
| Set file | claude.set |
| Commit | 0b30fe9 |

### NAS100 — Run 1 (2022-2026, MacroTrend=false, RiskProfile=Aggressive)
**Status: Aborted** — main terminal exited before MetaTester finished (race condition in backtest.sh).
Parser picked up stale UltraScalp results. Real results captured from agent log: 9 trades, 2 wins, 7 losses (all losses = counter-trend sells into 2023-2024 bull run). **backtest.sh race condition fixed** (now polls MetaTester agent log).

### NAS100 — Run 2 (2022-2026, MacroTrend=true, RiskProfile=1=Aggressive)
| Metric | Value |
|---|---|
| Date | 2026-03-20 |
| Trades closed | 10 |
| Trades placed | 47 |
| Win% | 20% (2/10) |
| PF | 0.13 |
| Balance | ,934 (-0.7%) |
| DD% | 0.73% (2) |
| Total OBs | 14,810 |
| No MSS | 9,160 |
| Wall time | 361s |
| Set file | nas100.set (MacroTrend=true, KZ=13-16+19-22) |
| Notes | **RiskProfile=1 (Aggressive) overrides KZ and D1=false** — custom settings ignored! |

**Critical finding**:  hardcodes  and , overriding the set file's , , . EA started with .

### NAS100 — Run 3 (2022-2026, inpRiskProfile=0=Custom, all individual settings active)
**Status: Running** (2026-03-20)
Expected: KZ=13-16+19-22, D1=true, MacroTrend=true to properly apply.

### NAS100 — TBD
