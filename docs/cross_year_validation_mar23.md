# Cross-Year Validation Results — 2026-03-23

7 symbols x 5 windows (2022, 2023, 2024, 2025, OOS 2026) = 35 backtests.
Each symbol uses its dedicated set file with current optimized parameters.

## Summary Ranking

| Symbol | Windows PF>1.0 | Best PF | Worst PF | Avg Trades/yr | Max DD% | Verdict |
|--------|---------------|---------|----------|---------------|---------|---------|
| USDJPY | **5/5** | 2.60 | 1.22 | 8 | 1.66% | DEPLOY - most robust |
| XAUUSD | 4/5 | 658 | 0.00 | 3 | 0.10% | Good but sparse; OOS dry |
| GBPUSD | 4/5 | 14.53 | 0.59 | 14 | 2.92% | DEPLOY - 2025 weak |
| EURJPY | 3/5 | 2.82 | 0.82 | 15 | 2.48% | Marginal; 2023-2024 losing |
| AUDJPY | 2/5 | 1.77 | 0.41 | 16 | 3.87% | Not robust; declining trend |
| GBPJPY | 1/5 | 1.10 | 0.27 | 20 | 8.30% | DO NOT DEPLOY |
| USDX | 1/5 | 542 | 0.00 | 6 | 1.97% | Unstable; massive variance |

## Detailed Results

### USDJPY (usdjpy.set) — BEST
Active: KZ (08-12 + 13-16) + D1 + Macro + fibo1rstTP=3.0

| Year | PF | Trades | WR | DD% | Balance |
|------|-----|--------|-----|------|---------|
| 2022 | 2.49 | 7 | 62% | 0.99% | 10258 |
| 2023 | 1.22 | 15 | 54% | 1.66% | 10099 |
| 2024 | 1.31 | 8 | 61% | 1.64% | 10169 |
| 2025 | 2.01 | 6 | 62% | 0.64% | 10178 |
| OOS 2026 | 2.60 | 3 | 33% | 0.60% | 10096 |

Log diagnostics: 2 expired orders in 2022, otherwise clean.

### XAUUSD (claude.set)
Active: KZ (11-14 + 20-23) + DailyBias + MacroTrend + D1Trend + Skip09UTC=true

| Year | PF | Trades | WR | DD% | Balance |
|------|-----|--------|-----|------|---------|
| 2022 | 286.14 | 6 | 60% | 0.10% | 18574 |
| 2023 | 203.79 | 2 | 100% | 0.06% | 10285 |
| 2024 | 658.49 | 2 | 100% | 0.03% | 10340 |
| 2025 | 463.16 | 4 | 100% | 0.03% | 10258 |
| OOS 2026 | 0.00 | 0 | n/a | 0.00% | 10000 |

Very high PF but extremely few trades (2-6/year). The filters are too aggressive — Skip09UTC removed most opportunities. OOS 2026 has zero trades.

Log diagnostics: 5 cancelled in 2022, otherwise clean.

### GBPUSD (gbpusd.set)
Active: KZ + FVG=true

| Year | PF | Trades | WR | DD% | Balance |
|------|-----|--------|-----|------|---------|
| 2022 | 1.52 | 26 | 61% | 1.57% | 10268 |
| 2023 | 1.53 | 27 | 69% | 1.00% | 10193 |
| 2024 | 1.32 | 8 | 74% | 1.95% | 10110 |
| 2025 | 0.59 | 11 | 55% | 2.92% | 9766 |
| OOS 2026 | 14.53 | 0 | 86% | 0.04% | 10072 |

2025 is the only losing year. Good trade count. 2 expired orders per year (normal).

### EURJPY (eurjpy.set)
Active: STOP orders + fibo1rstTP=1.5 + Macro + D1 + KZ (08-12 + 13-17)

| Year | PF | Trades | WR | DD% | Balance |
|------|-----|--------|-----|------|---------|
| 2022 | 1.50 | 15 | 61% | 0.75% | 10078 |
| 2023 | 0.82 | 21 | 50% | 2.48% | 9928 |
| 2024 | 0.94 | 15 | 62% | 0.72% | 9985 |
| 2025 | 1.78 | 18 | 58% | 1.53% | 10265 |
| OOS 2026 | 2.82 | 5 | 50% | 0.31% | 10061 |

Decent trade count but 2023-2024 are losing. Not reliable enough for live.

### AUDJPY (audjpy.set)

| Year | PF | Trades | WR | DD% | Balance |
|------|-----|--------|-----|------|---------|
| 2022 | 1.01 | 16 | 57% | 1.41% | 10006 |
| 2023 | 1.77 | 13 | 67% | 0.84% | 10221 |
| 2024 | 0.89 | 24 | 50% | 2.82% | 9944 |
| 2025 | 0.62 | 22 | 46% | 3.87% | 9724 |
| OOS 2026 | 0.41 | 6 | 25% | 0.98% | 9904 |

Clear degradation trend: PF declining year over year. Not viable.

### GBPJPY (gbpjpy.set)

| Year | PF | Trades | WR | DD% | Balance |
|------|-----|--------|-----|------|---------|
| 2022 | 0.87 | 4 | 69% | 2.82% | 9946 |
| 2023 | 0.79 | 40 | 55% | 2.80% | 9811 |
| 2024 | 0.27 | 33 | 31% | 8.30% | 9197 |
| 2025 | 0.76 | 15 | 52% | 2.41% | 9847 |
| OOS 2026 | 1.10 | 9 | 33% | 0.98% | 10013 |

Worst performer. 2024 had 8.3% DD with PF=0.27. Do not deploy.

### USDX (usdx.set)
Active: MacroOff + tolerance=100

| Year | PF | Trades | WR | DD% | Balance |
|------|-----|--------|-----|------|---------|
| 2022 | 0.34 | 5 | 50% | 1.00% | 9934 |
| 2023 | 0.71 | 7 | 33% | 1.97% | 9915 |
| 2024 | 542.03 | 12 | 45% | 0.00% | 10471 |
| 2025 | 0.00 | 5 | n/a | 0.00% | 10000 |
| OOS 2026 | 0.00 | 2 | 50% | 0.95% | 9905 |

Massive variance. 2024 is an outlier. 19-27 order cancellations per year (hasOppositeOB issue).
High cancellation rate + low win rate = not viable.

## Key Findings

1. **USDJPY is the only consistently profitable symbol** — positive in every year, low DD, clean logs
2. **GBPUSD is second-best** — 4/5 profitable, good trade count, only 2025 weak
3. **XAUUSD filters are too aggressive** — PF is astronomical but 0-6 trades/year is too sparse
4. **JPY crosses (GBPJPY, AUDJPY) are not robust** — need different parameter optimization
5. **USDX order cancellation remains a problem** — 19-27 cancels/year despite tolerance=100
6. **EURJPY is borderline** — 3/5 profitable but not reliable enough

## Recommendations

1. **Deploy**: USDJPY (primary), GBPUSD (secondary)
2. **Revisit**: XAUUSD — consider relaxing Skip09UTC or other filters to get more trades
3. **Re-optimize**: EURJPY — try wider KZ, different TP levels
4. **Drop**: GBPJPY, AUDJPY, USDX — fundamental issues not fixable by parameter tuning
