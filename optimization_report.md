# Complete Optimization Results

## Summary of All Tests

### Phase 1: Quality/Trade Filters (No Impact)
These parameters had NO effect on results:
- `inpLowQualityTrades`
- `inpRequireD1Trend`
- `minBodySize`
- `inpDailyBiasEnabled`
- Kill Zone settings
- `typeOfTrade` (BUY/SELL/BOTH)
- ADX parameters
- Spread filters

### Phase 2: Entry/SL/TP Parameters (MAJOR IMPACT)

| Test | Trades | Win Rate | PF | Balance | Notes |
|------|--------|----------|-----|---------|-------|
| **Baseline** | 18 | 78% | 2.66 | $19,121 | Default settings |
| fiboEntry=0.618 | 26 | 78% | 2.66 | $19,120 | More trades |
| fibo1rstTP=1.618 | 26 | 78% | 2.66 | $19,120 | Same |
| **entry=AUTO** | 13 | 92% | 7.01 | $17,402 | BEST PF but few trades |
| **entry=CISD** | 13 | 92% | 6.75 | $17,100 | Similar to AUTO |
| trailing=OFF | 33 | 67% | 1.90 | $28,369 | MORE trades, WORSE PF |
| minRR=1.5 | 25 | 79% | 3.64 | $18,293 | Better PF |
| minRR=3.0 | 18 | 50% | 1.33 | $10,091 | Too strict |

### Best Configurations Found

1. **Best Overall** (balanced):
   - `fiboEntry=0.618`
   - `fibo1rstTP=1.618`
   - 26 trades, 78% win, PF 2.66, $19,120

2. **Best Profit Factor** (conservative):
   - `inpEntryMode=AUTO` (or CISD)
   - 13 trades, 92% win, PF 7.01, $17,402

3. **Best Balance** (aggressive):
   - `enableTrailingStop=false`
   - 33 trades, 67% win, PF 1.90, $28,369

### Key Insights

1. **fiboEntry=0.618** increases trades (26 vs 18) by entering at 61.8% instead of 65%
2. **entry=AUTO** gives highest win rate (92%) but only 13 trades
3. **Trailing stop OFF** gives highest balance but worse PF (1.90)
4. **minRR filter** improves PF but reduces trades significantly

### Recommended Settings

**For maximum profit factor (conservative):**
```
inpEntryMode = ENUM_EM_AUTO (1)
```

**For balanced (recommended):**
```
fiboEntry = 0.618
fibo1rstTP = 1.618
```

**For maximum balance (aggressive):**
```
enableTrailingStop = false
fiboEntry = 0.618
```
