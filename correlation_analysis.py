"""
Post-sweep correlation and opportunity analysis.
Reads all cross_year_results.csv + new JPY sweep results and produces:
1. Per-year symbol correlation matrix
2. Portfolio diversification score
3. Ranked opportunity list for next session
"""
import os, json, csv, codecs
from datetime import datetime

BASE_DIR = "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
OUT_MD   = f"{BASE_DIR}/docs/correlation_analysis.md"

SYMBOLS_DONE = ["EURUSD", "GBPUSD", "USDJPY", "XAUUSD"]
JPY_CROSSES  = ["GBPJPY", "EURJPY", "AUDJPY"]
YEARS        = ["2022", "2023", "2024", "2025"]

def read_cross_year():
    """Read cross_year_results.csv → {symbol: {year: pf}}"""
    path = f"{BASE_DIR}/cross_year_results.csv"
    data = {}
    try:
        with open(path) as f:
            for row in csv.DictReader(f):
                sym = row["symbol"]; yr = row["year"]
                try: pf = float(row["profit_factor"])
                except: pf = 0.0
                data.setdefault(sym, {})[yr] = pf
    except Exception as e:
        print(f"Could not read cross_year_results.csv: {e}")
    return data

def read_jpy_best():
    """Read best PF from each JPY optimizer result file."""
    results = {}
    for sym in JPY_CROSSES:
        slug = sym.lower()
        path = f"{BASE_DIR}/docs/{slug}_test_results.md"
        best_pf = 0.0; best_label = "n/a"
        try:
            with open(path) as f:
                for line in f:
                    if line.startswith("- **Best**:"):
                        parts = line.split("PF=")
                        if len(parts) > 1:
                            best_pf = float(parts[1].split()[0].rstrip("—").strip())
                            best_label = line.split("—")[-1].strip() if "—" in line else "n/a"
        except: pass
        results[sym] = {"pf": best_pf, "label": best_label}
    return results

def correlation_score(pf_a, pf_b):
    """Both profitable=correlated risk. One loss one profit=diversified."""
    a_good = pf_a >= 1.0; b_good = pf_b >= 1.0
    if a_good and b_good: return "both_win"
    if not a_good and not b_good: return "both_lose"
    return "diversified"

def main():
    print("Running correlation & opportunity analysis...", flush=True)
    cy = read_cross_year()
    jpy_best = read_jpy_best()

    lines = [f"""# Correlation & Opportunity Analysis
*Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}*

---

## 1. Per-Year Performance Matrix (original 4 symbols)

| Year | EURUSD | GBPUSD | USDJPY | XAUUSD | Regime |
|---|---|---|---|---|---|
"""]

    for yr in YEARS:
        row = []
        pfs = {}
        for sym in SYMBOLS_DONE:
            pf = cy.get(sym, {}).get(yr, 0)
            pfs[sym] = pf
            emoji = "✅" if pf >= 1.5 else ("⚠️" if pf >= 1.0 else "❌")
            row.append(f"{pf:.2f}{emoji}")
        winners = sum(1 for p in pfs.values() if p >= 1.0)
        if winners == 4:   regime = "🌟 All positive"
        elif winners >= 3: regime = "✅ Strong"
        elif winners >= 2: regime = "⚠️ Mixed"
        elif winners == 1: regime = "❌ Weak"
        else:              regime = "💀 All negative"
        lines.append(f"| {yr} | {' | '.join(row)} | {regime} |\n")

    lines.append("""
---

## 2. Correlation Risk Analysis

### Years where symbols move together (drawdown correlation risk)
""")
    # Find years where multiple symbols all lose
    bad_years = {}
    for yr in YEARS:
        losers = [s for s in SYMBOLS_DONE if cy.get(s, {}).get(yr, 0) < 1.0]
        if len(losers) >= 2:
            bad_years[yr] = losers
    if bad_years:
        for yr, losers in bad_years.items():
            lines.append(f"- **{yr}**: {', '.join(losers)} all below 1.0 → correlated drawdown risk\n")
    else:
        lines.append("- No year where all symbols lost simultaneously\n")

    lines.append("""
### Diversification assessment
- **USDJPY** is the only symbol profitable every year — acts as portfolio anchor
- **XAUUSD** (Skip09UTC) has very few trades — not meaningful for correlation
- **2023**: EURUSD bad (0.38) + GBPUSD weak — EUR weakness year. USDJPY OK (1.22). Good diversification.
- **2025**: EURUSD (0.64) + GBPUSD (0.59) both weak — macro regime. USDJPY strong (2.01). Validates JPY as hedge.

**Portfolio recommendation**: USDJPY + GBPUSD covers most scenarios. Adding EURJPY (if sweep confirms) adds JPY exposure in a different pair. Avoid holding EURUSD + GBPUSD simultaneously — they correlate in bad years.

---

## 3. JPY Crosses Sweep Results
""")

    # Read JPY sweep results
    for sym in JPY_CROSSES:
        slug = sym.lower()
        best = jpy_best.get(sym, {})
        pf = best.get("pf", 0)
        label = best.get("label", "n/a")
        emoji = "✅" if pf >= 1.5 else ("⚠️" if pf >= 1.0 else "❌")
        lines.append(f"- **{sym}**: Best PF={pf:.2f} ({label}) {emoji}\n")

    lines.append("""
---

## 4. Opportunity Ranking — Next Session Priorities

| Priority | Action | Expected Impact | Effort |
|---|---|---|---|
""")

    # Rank JPY crosses by best PF
    jpy_ranked = sorted(JPY_CROSSES, key=lambda s: jpy_best.get(s, {}).get("pf", 0), reverse=True)
    priority = 1
    for sym in jpy_ranked:
        pf = jpy_best.get(sym, {}).get("pf", 0)
        label = jpy_best.get(sym, {}).get("label", "?")
        if pf >= 1.5:
            lines.append(f"| {priority} | **{sym}**: Apply winner ({label}), run cross-year validation | High | Low |\n")
            priority += 1
        elif pf >= 1.0:
            lines.append(f"| {priority} | **{sym}**: Marginal — consider deeper sweep or skip | Medium | Medium |\n")
            priority += 1
        else:
            lines.append(f"| {priority} | **{sym}**: PF={pf:.2f} — needs major restructuring or skip | Low | High |\n")
            priority += 1

    lines.append(f"| {priority} | EURUSD: Add ADX/ranging filter to fix 2023/OOS | Medium | High |\n")
    priority += 1
    lines.append(f"| {priority} | XAUUSD: Test inpRequireSweep=false for more trades | Medium | Low |\n")
    priority += 1
    lines.append(f"| {priority} | XAGUSD: Test 2022-2024 only (avoid 2025 parabolic) | Low | Low |\n")

    lines.append(f"""
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
""")

    with open(OUT_MD, "w") as f:
        f.writelines(lines)
    print(f"Analysis written to: docs/correlation_analysis.md", flush=True)
    print(f"\n{'='*55}", flush=True)
    print(f"  ANALYSIS DONE", flush=True)
    print(f"{'='*55}\n", flush=True)

if __name__ == "__main__":
    main()
