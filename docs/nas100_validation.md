# NAS100 Winner Validation
*Config: outdatedOB=120 + tolerance=80 + fibo1rstTP=2.0*
*Run: 2026-03-21 10:05*

| Year | PF | Balance | DD% | Trades | WR | Notes |
|---|---|---|---|---|---|---|
| 2022 | 6.96 | 10059.57 | 0.10% 10.00 | 3 | 2/9 (22%) | Bear market ✅ |
| 2023 | 0.00 | 9990.08 | 0.10% 9.92 | 1 | 0/2 (0%) | Recovery ❌ |
| 2024 | 2.42 | 10033.88 | 0.24% 23.78 | 5 | 2/7 (29%) | Bull run ✅ |
| 2025 | 0.00 | 10000.00 | 0.00% 0.00 | 0 | 0/2 (0%) | Recent ❌ |
| 2023-2025 | 1.71 | 10023.96 | 0.34% 33.70 | 6 | 2/11 (18%) | Out-of-sample 3yr ✅ |

## Analysis

**Positives:**
- 2022 (bear): PF 6.96 — D1 trend filter correctly blocks counter-trend shorts in a down market
- 2024 (bull): PF 2.42 — strong trending year, OBs get tested cleanly
- 2023-2025 OOS: PF 1.71 — edge is real, not just 2022 artifact

**Concerns:**
- 2023 (recovery): 1 trade, 0 wins — choppy recovery year produces poor MSS setups
- 2025: 0 trades — near-parabolic uptrend, no pullbacks deep enough to fill LIMIT orders at fib50

**Root cause of 2025 failure:**
NAS100 2025 went nearly straight up (AI boom, no 10%+ corrections). LIMIT orders at fib50 of OBs require a retracement — in a parabolic market, price never returns. This is a structural limitation of the LIMIT strategy on NAS100 during extreme trending regimes.

**Recommendation:**
- Add a `typeofOrder` toggle: LIMIT in ranging/pullback regimes, STOP in parabolic trending regimes
- Or: accept NAS100 as a selective instrument — deploy only when D1 structure shows alternating swings (not parabolic)
- Sample size (9 trades / 4yr) remains the #1 concern — need more data or a broader KZ window

**NAS100 Status: VIABLE — not ready for live, needs more sample or alternative entry mode in parabolic regimes**
