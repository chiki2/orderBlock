# USDX Parameter Tuning
*Started: 2026-03-23 10:39 — Stop at 23:00*
*Base: USDX, KZ=08-12+13-17 UTC, claude.set adapted, 2022-2026*
*Probe result: 6T, 0% WR — default params mismatched for DXY price/ATR range*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Baseline (default claude.set params) | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/6 (0%) | 148s | ❌ |
| 2 | ATR_max=0.3 (USDX M15 high vol filter) | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/6 (0%) | 156s | ❌ |
| 3 | ATR_max=0.5 | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/6 (0%) | 162s | ❌ |
| 4 | ATR_max=1.0 (effectively off for USDX) | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/6 (0%) | 160s | ❌ |
| 5 | STOP orders (typeofOrder=2) | 0.00 | 9598.80 | 4.01% 401.20 | 14 | 8 | 0/8 (0%) | 110s | ❌ |
| 6 | STOP + tp=2.0 | 0.00 | 9598.80 | 4.01% 401.20 | 14 | 8 | 0/8 (0%) | 106s | ❌ |
| 7 | D1Trend=false | 0.00 | 9705.07 | 2.95% 294.93 | 16 | 9 | 0/9 (0%) | 151s | ❌ |
| 8 | MacroTrend=false | 1.41 | 10163.84 | 1.97% 197.33 | 25 | 15 | 6/15 (40%) | 219s | ⚠️ |
| 9 | LIMIT + tp=2.0 | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/6 (0%) | 144s | ❌ |
| 10 | LIMIT + tp=3.0 | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/6 (0%) | 148s | ❌ |
| 11 | ATR_max=0.3 + tp=2.0 | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/6 (0%) | 145s | ❌ |
| 12 | ATR_max=0.3 + STOP | 0.00 | 9598.80 | 4.01% 401.20 | 14 | 8 | 0/8 (0%) | 108s | ❌ |
| 13 | ATR_max=0.3 + D1=false | 0.00 | 9705.07 | 2.95% 294.93 | 16 | 9 | 0/9 (0%) | 157s | ❌ |

---
## Summary
- **Best PF**: 1.41 — MacroTrend=false
- **Best set**: `OBInclude/SetFiles/usdx_best.set`
- **Completed**: 2026-03-23 11:11
