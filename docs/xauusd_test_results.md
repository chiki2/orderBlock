# XAUUSD Optimization Results
*Started: 2026-03-21 22:55 — Stop at 07:00*
*Base: Profile=5 Custom, KZ=11-14+20-23 UTC, LIMIT, D1+MacroTrend+DailyBias=true, 2022-2026*
*Goal: more trades while keeping PF >= 1.5*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Baseline (Profile=5 Custom, all filters) | 3.84 | 0.00 | 10.53% 1 308.88 | 0 | 10 | 7/10 (70%) | 604s | ✅ |
| 2 | Profile=0 VeryAggressive (no filters) | 3.84 | 10253.58 | 10.53% 1 308.88 | 6 | 10 | 51/143 (36%) | 807s | ✅ |
| 3 | Profile=1 Aggressive (wide KZ, D1=off) | 1.50 | 10075.18 | 65.26% 41 060.61 | 65 | 83 | 38/81 (47%) | 606s | ✅ |
| 4 | Profile=2 Balanced (med KZ, D1=off) | 1.83 | 25273.03 | 20.81% 3 034.23 | 29 | 21 | 11/20 (55%) | 482s | ✅ |
| 5 | Profile=3 Conservative (tight KZ, D1=on) | 3.84 | 23847.15 | 10.53% 1 308.88 | 15 | 10 | 7/10 (70%) | 362s | ✅ |
| 6 | Profile=4 VeryConservative (+H4) | 3.78 | 23379.53 | 10.53% 1 308.88 | 15 | 9 | 6/9 (67%) | 377s | ✅ |
| 7 | Custom: D1Trend=false (biggest filter off) | 3.84 | 23847.15 | 10.53% 1 308.88 | 15 | 10 | 7/10 (70%) | 363s | ✅ |
| 8 | Custom: MacroTrend=false | 1.37 | 23847.15 | 33.61% 5 182.17 | 15 | 15 | 7/15 (47%) | 397s | ⚠️ |
| 9 | Custom: KZ wide (08-17 + 18-23) | 2.56 | 0.00 | 28.93% 4 370.70 | 0 | 29 | 19/29 (66%) | 376s | ✅ |
| 10 | Custom: KZ disabled | 1.26 | 0.00 | 53.01% 7 217.93 | 0 | 44 | 22/45 (49%) | 543s | ⚠️ |
| 11 | Custom: outdatedOB=160 (OBs live longer) | 3.84 | 23847.15 | 10.53% 1 308.88 | 13 | 10 | 7/10 (70%) | 201s | ✅ |
| 12 | Custom: outdatedOB=200 | 3.84 | 23847.15 | 10.53% 1 308.88 | 13 | 10 | 7/10 (70%) | 204s | ✅ |
| 13 | Profile=2 Balanced + D1=true | 1.83 | 25273.03 | 20.81% 3 034.23 | 29 | 21 | 11/20 (55%) | 267s | ✅ |
| 14 | KZ wide + D1=true + MacroTrend=true | 1.83 | 25273.03 | 20.81% 3 034.23 | 29 | 21 | 19/29 (66%) | 371s | ✅ |
| 15 | D1=false + outdatedOB=160 | 3.84 | 23847.15 | 10.53% 1 308.88 | 13 | 10 | 7/10 (70%) | 204s | ✅ |
| 16 | Profile=2 + outdatedOB=160 | 1.83 | 25273.03 | 20.81% 3 034.23 | 26 | 21 | 11/20 (55%) | 295s | ✅ |
| 17 | Profile=1 + D1=true + outdatedOB=160 | 1.31 | 25273.03 | 71.42% 44 223.77 | 26 | 87 | 38/85 (45%) | 507s | ⚠️ |

---
## Summary
- **Best PF**: 3.84 (10 trades) — Baseline (Profile=5 Custom, all filters)
- **Best set**: `OBInclude/SetFiles/xauusd_best.set`
- **Completed**: 2026-03-22 00:51
