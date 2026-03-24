# Forensics Filter Sweep — XAUUSD
*Started: 2026-03-22 17:22 — Stop at 23:00*
*Base: XAUUSD M15 2022-2026, PF=4.67, 10T 70% WR, DD 10.53%*
*Goal: find which forensics filters improve PF/WR without killing too many trades*

| # | Label | PF | Balance | DD% | Placed | Closed | WR | Time | |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Baseline (all forensics filters OFF) | 6.65 | 28277.60 | 10.09% 3 174.66 | 15 | 10 | 7/10 (70%) | 128s | ✅ |
| 2 | #56 inpBlockCounterHTF=true | 6.65 | 28277.60 | 10.09% 3 174.66 | 15 | 10 | 7/10 (70%) | 126s | ✅ |
| 3 | #57 inpSkip09UTC=true | 357.65 | 31452.26 | 0.10% 16.01 | 14 | 9 | 7/9 (78%) | 128s | ✅ |
| 4 | #58 inpSkipH4InsideBar=true | 6.65 | 28277.60 | 10.09% 3 174.66 | 15 | 10 | 7/10 (70%) | 126s | ✅ |
| 5 | #60 inpD1WickFilter=true | 3.27 | 13505.39 | 10.09% 1 515.19 | 11 | 7 | 4/7 (57%) | 126s | ✅ |
| 6 | #61 ATR_min=1.0 (skip very low vol) | 6.65 | 28277.60 | 10.09% 3 174.66 | 15 | 10 | 7/10 (70%) | 128s | ✅ |
| 7 | #61 ATR_min=2.0 | 6.25 | 24337.42 | 9.97% 2 693.66 | 14 | 8 | 5/8 (62%) | 126s | ✅ |
| 8 | #61 ATR_min=3.0 | 0.65 | 9278.29 | 10.29% 1 028.84 | 11 | 4 | 1/4 (25%) | 129s | ❌ |
| 9 | #63 inpMaxRR=3.0 (cap extreme R:R) | 5.69 | 21567.28 | 10.12% 2 429.11 | 13 | 7 | 6/7 (86%) | 127s | ✅ |
| 10 | #63 inpMaxRR=4.0 | 6.65 | 28279.73 | 10.09% 3 174.66 | 14 | 9 | 7/9 (78%) | 127s | ✅ |
| 11 | #63 inpMaxRR=5.0 | 6.65 | 28277.60 | 10.09% 3 174.66 | 15 | 10 | 7/10 (70%) | 131s | ✅ |
| 12 | #56 CounterHTF + #60 D1Wick | 3.27 | 13505.39 | 10.09% 1 515.19 | 11 | 7 | 4/7 (57%) | 127s | ✅ |
| 13 | #56 CounterHTF + #58 H4InsideBar | 6.65 | 28277.60 | 10.09% 3 174.66 | 15 | 10 | 7/10 (70%) | 127s | ✅ |
| 14 | #58 H4InsideBar + #60 D1Wick | 3.27 | 13505.39 | 10.09% 1 515.19 | 11 | 7 | 4/7 (57%) | 129s | ✅ |
| 15 | #57 09UTC + #60 D1Wick | 189.25 | 15020.58 | 0.13% 13.28 | 10 | 6 | 4/6 (67%) | 127s | ✅ |
| 16 | #61 ATR_min=2.0 + #63 MaxRR=4.0 | 6.25 | 24339.55 | 9.96% 2 693.66 | 13 | 7 | 5/7 (71%) | 129s | ✅ |
| 17 | #56 + #58 + #60 (top 3 by efficiency) | 3.27 | 13505.39 | 10.09% 1 515.19 | 11 | 7 | 4/7 (57%) | 127s | ✅ |
| 18 | #56 + #57 + #60 | 189.25 | 15020.58 | 0.13% 13.28 | 10 | 6 | 4/6 (67%) | 127s | ✅ |
| 19 | All 4 boolean filters ON | 189.25 | 15020.58 | 0.13% 13.28 | 10 | 6 | 4/6 (67%) | 129s | ✅ |
| 20 | All 4 booleans + ATR_min=2.0 + MaxRR=4.0 | 222.18 | 12912.99 | 0.10% 9.55 | 8 | 3 | 2/3 (67%) | 127s | ✅ |

---
## Summary
- **Baseline**: PF=4.67, 10T, 70% WR, DD 10.53%
- **Best**: PF=357.65 — #57 inpSkip09UTC=true
- **Best set**: `OBInclude/SetFiles/forensics_best.set`
- **Completed**: 2026-03-22 18:04

### Interpretation guide
- PF improvement with fewer trades = filter removes losses cleanly
- PF drops with fewer trades = filter also removes wins
- Trade count drop > 50% = filter too aggressive for XAUUSD (already sparse)
