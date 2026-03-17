# Optimization Plan - Trade Frequency Improvement

## Objective
Find the optimal parameter combination that maximizes trades while maintaining good win rate and profit factor.

## Current Baseline (Reference)
| Metric | Value |
|--------|-------|
| Period | 2025.01.01 - 2026.01.01 |
| Trades | 27 |
| Win Rate | 78% |
| Profit Factor | 2.02 |
| Balance | $20,466 |

## Parameters to Test (Grouped by Category)

### Category 1: Trade Opportunity Parameters
| Parameter | Current | Test Range | Rationale |
|-----------|---------|-------------|-----------|
| `outdatedOB` | 80 | 40, 60, 80, 120 | How long OB stays valid |
| `inpHistoricalScanBars` | 30 | 10, 20, 30, 50 | Bars scanned on startup |
| `inpLowQualityTrades` | false | true, false | Allow sub-quality OBs |

### Category 2: Kill Zone Filters
| Parameter | Current | Test Range | Rationale |
|-----------|---------|-------------|-----------|
| `inpKillZoneEnabled` | false | true, false | Enable/disable KZ |
| `inpKZ1Start` | 11 | 8, 9, 10, 11 | KZ1 start hour |
| `inpKZ1End` | 14 | 12, 13, 14 | KZ1 end hour |
| `inpKZ2Start` | 20 | 18, 19, 20 | KZ2 start hour |
| `inpKZ2End` | 23 | 22, 23 | KZ2 end hour |

### Category 3: Trend Filters
| Parameter | Current | Test Range | Rationale |
|-----------|---------|-------------|-----------|
| `inpRequireD1Trend` | true | true, false | D1 trend alignment |
| `inpRequireH4Trend` | false | true, false | H4 trend alignment |
| `inpMacroTrendEnabled` | false | true, false | Weekly trend filter |
| `inpDailyBiasEnabled` | false | true, false | Daily open bias |

### Category 4: OB Quality Filters
| Parameter | Current | Test Range | Rationale |
|-----------|---------|-------------|-----------|
| `inpMSSRequireFVG` | true | true, false | Require FVG on MSS |
| `minBodySize` | 10 | 5, 10, 20 | Minimum OB candle body |
| `maxWickRatio` | 1.6 | 1.0, 1.6, 2.0 | Max wick/body ratio |
| `minImBalanced` | 40 | 20, 40, 60 | Minimum FVG size |

### Category 5: Re-entry & Mitigation
| Parameter | Current | Test Range | Rationale |
|-----------|---------|-------------|-----------|
| `inpAllowMitigatedReentry` | false | true, false | Re-enter after mitigation |
| `MitigatedMode` | 1 (midline) | 0, 1, 2 | When OB is mitigated |

## Test Strategy

### Phase 1: Individual Parameter Impact (Fast)
Test each parameter individually to find promising ranges.

### Phase 2: Combination Testing (Medium)
Test top combinations from Phase 1.

### Phase 3: Final Optimization (If needed)
Fine-tune the best combination.

## Expected Test Matrix

| Test # | Focus | Parameters Changed | Expected Trades |
|--------|-------|-------------------|----------------|
| 1 | Baseline | Current settings | ~27 |
| 2 | OB Freshness | outdatedOB=40 | + |
| 3 | OB Freshness | outdatedOB=120 | + |
| 4 | Historical | inpHistoricalScanBars=50 | + |
| 5 | Low Quality | inpLowQualityTrades=true | ++ |
| 6 | Kill Zone | inpKillZoneEnabled=true (default KZ) | - |
| 7 | Kill Zone | inpKillZoneEnabled=false | ++ |
| 8 | D1 Trend | inpRequireD1Trend=false | + |
| 9 | Daily Bias | inpDailyBiasEnabled=true | ~ |
| 10 | MSS FVG | inpMSSRequireFVG=false | ++ |
| 11 | Body Size | minBodySize=5 | + |
| 12 | Re-entry | inpAllowMitigatedReentry=true | + |
| 13 | COMBO 1 | Relax filters (low quality + no KZ) | +++ |
| 14 | COMBO 2 | Fresh OB + re-entry | ++ |
| 15 | COMBO 3 | All relaxed | ++++ |

## Output Files
- `optimization_results.csv` - All test results
- `optimization_report.md` - Summary and recommendations

## Notes
- News filter excluded (doesn't work in backtest)
- Parameters that affect trade FREQUENCY are prioritized
- Win rate should stay above 60% minimum
- Profit factor should stay above 1.5 minimum
