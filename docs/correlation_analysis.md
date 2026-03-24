# Correlation & Opportunity Analysis
*Generated: 2026-03-23 03:43*

---

## 1. Per-Year Performance Matrix (original 4 symbols)

| Year | EURUSD | GBPUSD | USDJPY | XAUUSD | Regime |
|---|---|---|---|---|---|
| 2022 | 1.10⚠️ | 1.52✅ | 2.49✅ | 286.14✅ | 🌟 All positive |
| 2023 | 0.38❌ | 1.53✅ | 1.22⚠️ | 203.79✅ | ✅ Strong |
| 2024 | 3.37✅ | 1.32⚠️ | 1.31⚠️ | 658.49✅ | 🌟 All positive |
| 2025 | 0.64❌ | 0.59❌ | 2.01✅ | 463.16✅ | ⚠️ Mixed |

---

## 2. Correlation Risk Analysis

### Years where symbols move together (drawdown correlation risk)
- **2025**: EURUSD, GBPUSD all below 1.0 → correlated drawdown risk

### Diversification assessment
- **USDJPY** is the only symbol profitable every year — acts as portfolio anchor
- **XAUUSD** (Skip09UTC) has very few trades — not meaningful for correlation
- **2023**: EURUSD bad (0.38) + GBPUSD weak — EUR weakness year. USDJPY OK (1.22). Good diversification.
- **2025**: EURUSD (0.64) + GBPUSD (0.59) both weak — macro regime. USDJPY strong (2.01). Validates JPY as hedge.

**Portfolio recommendation**: USDJPY + GBPUSD covers most scenarios. Adding EURJPY (if sweep confirms) adds JPY exposure in a different pair. Avoid holding EURUSD + GBPUSD simultaneously — they correlate in bad years.

---

## 3. JPY Crosses Sweep Results
- **GBPJPY**: Best PF=0.00 (n/a) ❌
- **EURJPY**: Best PF=0.00 (n/a) ❌
- **AUDJPY**: Best PF=0.00 (n/a) ❌

---

## 4. Opportunity Ranking — Next Session Priorities

| Priority | Action | Expected Impact | Effort |
|---|---|---|---|
| 1 | **GBPJPY**: PF=0.00 — needs major restructuring or skip | Low | High |
| 2 | **EURJPY**: PF=0.00 — needs major restructuring or skip | Low | High |
| 3 | **AUDJPY**: PF=0.00 — needs major restructuring or skip | Low | High |
| 4 | EURUSD: Add ADX/ranging filter to fix 2023/OOS | Medium | High |
| 5 | XAUUSD: Test inpRequireSweep=false for more trades | Medium | Low |
| 6 | XAGUSD: Test 2022-2024 only (avoid 2025 parabolic) | Low | Low |

---

## 5. Portfolio Deployment Recommendation

Based on all testing to date (2022-2026):

| Symbol | Deploy? | Best Config | Annual Trades | Notes |
|---|---|---|---|---|
| USDJPY | ✅ YES | tp=3.0, LIMIT | ~20/yr | Most robust — positive every year |
| GBPUSD | ✅ YES | FVG=true, LIMIT | ~30/yr | Strong 2022-2024, OOS excellent |
| XAUUSD | ⚠️ SMALL | Skip09UTC | ~2/yr | Very sparse but extreme PF |
| EURUSD | ❌ NO | — | — | Regime-dependent, OOS failed |
| GBPJPY | TBD | Sweep result | ~25/yr | Pending sweep results |
| EURJPY | TBD | Sweep result | ~25/yr | Pending sweep results |
| AUDJPY | TBD | Sweep result | ~20/yr | Pending sweep results |

*Generated automatically — verify against latest backtest results*
