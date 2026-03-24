# USDX Order Cancel Fix Sweep
*Started: 2026-03-23 19:08 — Stop at 23:00*
*Motivation: many order cancels observed — two root causes identified:*
*  1. outdatedOB=80×15min=20h too short for slowly-retracing USDX*
*  2. hasOppositeOB() (cOrderBlock.mqh:107) cancels pending when opposite OB (stars>=3) forms*
*Base: MacroTrend=false confirmed as unlock (PF=1.41, 15T, 40% WR)*
*All tests use MacroTrend=false as baseline*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
| 13 | MacroOff + STOP + tp=3.0 | 0.00 | 9802.22 | 1.98% 197.78 | 12 | 6 | 0/1 (0%) | 21s | ❌ |
| 1 | MacroTrend=false (baseline) | 0.56 | 9802.22 | 9.02% 902.22 | 12 | 24 | 7/30 (23%) | 607s | ❌ |
| 2 | MacroOff + outdatedOB=160 (40h) | 1.41 | 10163.48 | 1.97% 197.33 | 26 | 16 | 6/16 (38%) | 203s | ⚠️ |
| 3 | MacroOff + outdatedOB=200 (50h) | 1.41 | 10163.48 | 1.97% 197.33 | 25 | 16 | 6/22 (27%) | 207s | ⚠️ |
| 4 | MacroOff + outdatedOB=300 (75h) | 1.41 | 10163.48 | 1.97% 197.33 | 28 | 16 | 6/16 (38%) | 171s | ⚠️ |
| 5 | MacroOff + outdatedOB=400 (100h) | 1.41 | 10163.48 | 1.97% 197.33 | 28 | 16 | 6/16 (38%) | 123s | ⚠️ |
| 6 | MacroOff + tolerance=60 | 1.41 | 10163.70 | 1.97% 197.33 | 26 | 16 | 6/16 (38%) | 234s | ⚠️ |
| 7 | MacroOff + tolerance=80 | 1.70 | 10277.30 | 1.97% 197.33 | 27 | 17 | 7/17 (41%) | 252s | ✅ |
| 8 | MacroOff + tolerance=100 | 1.79 | 10312.92 | 1.97% 197.54 | 29 | 19 | 8/19 (42%) | 286s | ✅ |
| 9 | MacroOff + ob=200 + tol=60 | 1.41 | 10163.34 | 1.97% 197.33 | 27 | 17 | 6/23 (26%) | 202s | ⚠️ |
| 10 | MacroOff + ob=300 + tol=80 | 1.70 | 10276.94 | 1.97% 197.33 | 31 | 18 | 7/18 (39%) | 141s | ✅ |
| 11 | MacroOff + STOP orders | 0.74 | 9811.09 | 5.19% 518.89 | 32 | 20 | 7/20 (35%) | 105s | ❌ |
| 12 | MacroOff + STOP + tp=1.5 | 0.49 | 9588.23 | 8.10% 809.70 | 32 | 20 | 6/20 (30%) | 107s | ❌ |
| 13 | MacroOff + STOP + tp=2.0 | 0.71 | 9762.09 | 8.10% 809.65 | 32 | 20 | 6/20 (30%) | 106s | ❌ |
| 14 | MacroOff + STOP + tp=3.0 | 1.14 | 10109.93 | 8.10% 809.54 | 32 | 20 | 5/20 (25%) | 105s | ⚠️ |
| 15 | MacroOff + ob=200 + STOP + tp=2.0 | 0.63 | 9661.55 | 8.09% 809.41 | 33 | 23 | 7/29 (24%) | 110s | ❌ |
| 16 | MacroOff + ob=300 + STOP + tp=1.5 | 0.40 | 9390.81 | 8.09% 809.48 | 36 | 24 | 7/24 (29%) | 102s | ❌ |

---
## Summary
- **Best PF**: 1.79 — MacroOff + tolerance=100
- **Best set**: `OBInclude/SetFiles/usdx_best.set`
- **Completed**: 2026-03-23 20:00
