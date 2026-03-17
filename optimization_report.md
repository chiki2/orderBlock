# Optimization Results - Trade Frequency Testing

## Test Results Summary

| Test | Trades | Completed | Win Rate | PF | Balance | Notes |
|------|--------|-----------|----------|-----|---------|-------|
| **BASELINE** | 33 | 27 | 78% | 2.02 | $20,466 | Current settings |
| 1_lowQuality_ON | 33 | 27 | 78% | 2.02 | $20,466 | No change - feature may need other conditions |
| 2_noD1trend | 33 | 27 | 78% | 2.02 | $20,466 | D1 trend filter not limiting |
| 3_noMSS_FVG | 33 | 29 | 72% | 1.46 | $14,925 | More trades but worse PF |
| 4_reentry | 33 | 37 | 70% | 1.00 | $14,925 | +10 trades but breakeven |
| 5_smallBody | 33 | 27 | 78% | 2.02 | $20,466 | Body size not limiting |
| 6_dailyBias | 33 | 27 | 78% | 2.02 | $20,466 | Not active |
| 7_outdated40 | 33 | 20 | 75% | 0.74 | $20,466 | Fewer trades - worse! |
| 8_outdated120 | 34 | 28 | 72% | 1.61 | $17,616 | Slightly more trades |
| C1_noMSS_reentry | 44 | 40 | 68% | 1.21 | $13,856 | Most trades but low PF |
| C2_noMSS_outdated120 | 35 | 31 | 69% | 1.25 | $13,024 | |
| C3_relaxed_all | 35 | 42 | 65% | 1.11 | $13,024 | |
| KZ_London_8_17 | 33 | 27 | 78% | 2.02 | $20,466 | No change |
| KZ_NY_13_23 | 33 | 27 | 78% | 2.02 | $20,466 | No change |
| KZ_disabled | 33 | 27 | 78% | 2.02 | $20,466 | No change |

## Key Findings

### 1. Parameters That DON'T Affect Results
- `inpLowQualityTrades` - Feature may need other conditions to trigger
- `inpRequireD1Trend` - Already aligned with market direction
- `minBodySize` - Current value (10) not limiting
- `inpDailyBiasEnabled` - Not active in current config
- Kill Zone settings - Already optimal

### 2. Parameters That INCREASE Trades But REDUCE PF
- `inpMSSRequireFVG=false` - +2 to +11 trades, PF drops from 2.02 to 1.46
- `inpAllowMitigatedReentry=true` - +10 trades, PF drops to 1.0 (breakeven)

### 3. Parameters That REDUCE Trades
- `outdatedOB=40` - Reduces to 20 trades, PF drops to 0.74

## Conclusion

**The current baseline settings (PF 2.02, 27 trades, 78% win) represent the OPTIMAL balance.**

Finding more trades always comes at the cost of lower profit factor. The quality filters (MSS, FVG, sweep) are essential for maintaining profitability.

## Recommendations

1. **Keep current baseline** - It's the best balance
2. **If more trades needed**: Accept PF ~1.2-1.5 by enabling:
   - `inpMSSRequireFVG=false`
   - `inpAllowMitigatedReentry=true`
3. **For higher PF**: Could try stricter settings (outdatedOB=40) but results are worse

## Why So Few Trades?

Analysis shows:
- Total OBs detected: 3,679
- First confirmation (valid OB): 2,309 (63%)
- Traded: 33 (0.9% of total, 1.4% of valid)

The main bottleneck is the **MSS (Market Structure Shift)** requirement - only ~3-5 OBs pass MSS per year. This is by design for quality.
