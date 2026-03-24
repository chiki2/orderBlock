# OrderBlock EA — Project Rules for Claude

# Règles de délégation

## OBLIGATOIRE : déléguer à Aider pour ces tâches

Avant de traiter toi-même, vérifie si la tâche entre dans ces catégories.
Si oui, utilise TOUJOURS la commande de délégation.

### Tâches à déléguer (modèle local, pas de raisonnement requis)
- Ajouter des commentaires ou docstrings
- Reformater du code
- Renommer des variables/méthodes
- Générer du boilerplate (getters, setters, constructeurs)
- Ajouter des logs
- Traduire des commentaires
- Corriger le style (indentation, conventions)
- Générer des classes Unity MonoBehaviour vides
- Ajouter des serialized fields Unity

### Tâches à traiter toi-même (raisonnement requis)
- Architecture et design patterns
- Debugging logique
- Optimisation de performance
- Intégration entre systèmes
- Tout ce qui concerne MQL5
- Questions complexes multi-fichiers

## Commande de délégation

Quand tu délègues, utilise exactement cette syntaxe :

\`\`\`bash
python .claude/delegate.py "description précise de la tâche" chemin/fichier.cs
\`\`\`

### Exemples

\`\`\`bash
# Ajouter des commentaires
python .claude/delegate.py "Ajoute des commentaires XML sur toutes les méthodes publiques" Assets/Scripts/PlayerController.cs

# Boilerplate
python .claude/delegate.py "Ajoute les getters et setters pour tous les champs privés" Assets/Scripts/GameManager.cs

# Reformatage
python .claude/delegate.py "Applique les conventions de nommage Unity (PascalCase méthodes, camelCase champs)" Assets/Scripts/Enemy.cs
\`\`\`

## Workflow

1. Reçois la demande
2. Est-ce une tâche mécanique ? → `python .claude/delegate.py ...`
3. Est-ce une tâche complexe ? → Traite toi-même
4. En cas de doute → délègue, tu pourras corriger ensuite

## File Encoding — CRITICAL
- **All `.mqh` / `.mq5` files are UTF-16** — NEVER use the Edit tool on them (corrupts BOM)
- **Exception**: `OBInclude/cOrderBlock.mqh` is **UTF-8** — use `open(path, encoding='utf-8')`
- Always read/write MQL5 files via Bash with inline Python:
  ```bash
  python3 -c "
  import codecs
  with codecs.open('path.mqh', 'r', 'utf-16') as f: content = f.read()
  content = content.replace('old', 'new')
  with codecs.open('path.mqh', 'w', 'utf-16') as f: f.write(content)
  "
  ```

## Backtest Workflow
```bash
cd "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
bash backtest.sh
```
- HTML report is always from the LAST run: `claudeReport.htm`
- JSON results: `backtest_last.json`
- To compare, run the baseline backtest first to regenerate the HTML
- **Always `touch OrderBlock.mq5 && bash backtest.sh` after any code change** — MT5 caches the `.ex5` binary and will silently backtest stale code otherwise.

## Architecture Quick Reference
- `HTOB=16385` = PERIOD_H1 (trend timeframe)
- `CTOB=15` = PERIOD_M15 (signal timeframe) — **confirmed best; M5/M30/H1 tested and inferior**
- `typeofOrder=1` = LIMIT orders (STOP=2 never triggers in XAUUSD backtest)
- `g_reasonCounters` array size must equal `ENUM_REASON_last_value + 1` — crashes if wrong
- Do NOT add `#include "langs.mqh"` to `helpers.mqh` — causes 100+ compile errors

## Per-Symbol Calibration — minImBalanced & tolerance
Both `minImBalanced` (FVG size) and `tolerance` (sweep proximity) are in **raw MT5 points** (not pips, not price units). The conversion depends on `_Point` / `Digits()`:

| Symbol | Digits | _Point | 50 pts = | Calibrated defaults |
|--------|--------|--------|----------|-------------------|
| XAUUSD | 2 | 0.01 | $0.50 (5 pips) | minImB=40, tol=50 |
| EURUSD | 5 | 0.00001 | 0.5 pips | minImB=40, tol=50 |
| USDJPY | 3 | 0.001 | 0.5 pips | minImB=40, tol=80 |
| GBPUSD | 5 | 0.00001 | 0.5 pips | minImB=40, tol=50 |
| NAS100 | 2 | 0.01 | $0.50 | minImB=40, tol=50 |

**Rule**: When adding a new symbol, check `Digits()` and scale tolerance accordingly. For JPY crosses (3 digits), tol=80 has been validated as optimal via cross-year testing.

## OB State Machine — Critical Quirks
- **`setOBOrder()` sets `isDone=true` immediately** after placing a limit order (OrderProcess.mqh ~line 300).
  Any code gated on `!obBuffer[i].isDone` will be silently skipped for pending orders.
  To act on pending orders post-placement, check `tradeTicket != INVALID_TICKET && OrderSelect(ticket)` instead.
- **Resetting `isDone=false` without an `isNewBar` gate causes tick-level oscillation**: cancel → isDone=false →
  isAllGood passes → re-place → cancel again (sub-second loop). Always gate cancellation/reset on `isNewBar`.
- **`OrderSelect(ticket)`** returns true for pending (unfilled) limit orders; `PositionSelectByTicket(ticket)`
  returns true for open positions. Use to distinguish the two states.

## Timeframe Testing
- To test a different signal timeframe: change `CTOB=N` in `OBInclude/SetFiles/claude.set` AND pass `PERIOD=MX` env var to `backtest.sh`
- Both must match: `PERIOD=M5` + `CTOB=5`, `PERIOD=M30` + `CTOB=30`, etc.
- Example: `PERIOD=M30 bash backtest.sh` with `CTOB=30` in claude.set

## Include Rule
`langs.mqh` → T() → uses `language` var declared in `OrderBlock.mq5` AFTER all includes.
Only include `langs.mqh` from files that are included AFTER `OrderBlock.mq5` processes it.

## GitHub Issues
Use the `gh-issue` skill when creating features or fixes. Close issues with summary comments.

---

## Trade Forensics Tool (`forensics.py`)

A post-backtest analysis tool that runs 7 analysis modules on traded OBs to find loss patterns and recommend filters.

### How to run
```bash
# Full pipeline: backtest → dataset → analysis → HTML report
python3 forensics.py

# Analyze existing data without re-running backtest
python3 forensics.py --skip-backtest

# Different symbol (default: XAUUSD)
python3 forensics.py --symbol EURUSD

# Custom date range
python3 forensics.py --from-date 2024.01.01 --to-date 2025.01.01

# Terminal only, no HTML
python3 forensics.py --no-html
```

### Adapting for other symbols
1. Set the symbol: `python3 forensics.py --symbol GBPUSD`
2. Make sure `.set` file matches: `SET_FILE=gbpusd.set python3 forensics.py --symbol GBPUSD`
3. Date range should cover enough trades (min ~50 traded OBs for meaningful analysis)
4. The tool auto-invokes `backtest.sh` and `build_dataset.py` — no manual steps
5. Results are symbol-specific: findings for XAUUSD do NOT apply to EURUSD/NAS100

### What it analyzes (7 modules)
| Module | What | Output |
|--------|------|--------|
| A. Feature Comparison | Mann-Whitney U test on all features, win vs loss | Features where distributions diverge significantly |
| B. Loss Clustering | K-Means on losing trades | 2-5 "archetypes" of failure (e.g., counter-trend, low-vol) |
| C. SHAP Explanations | Per-trade "why did this lose?" | Top loss drivers + worst-5-trade breakdowns |
| D. Temporal Patterns | Win rate by hour/day/session | Death zones (hours with <35% win rate) |
| E. Market Regime | HTF trend × direction × ATR quartile | Which regimes to avoid |
| F. Filter Simulation | Tests 30+ candidate filters | Efficiency ranking: loss removed / win cost |
| G. MTF Candle Analysis | 3 candles × 5 TFs at ENTRY and EXIT | Candle pattern + trend alignment differences |

### MTF Candle Export (added to EA)
- `ExportCandleContext()` in `exportOB.mqh` writes `ob_candles_*.csv`
- Captures 3 candles on M5, M15, H1, H4, D1 at ENTRY and EXIT
- Each candle: OHLC + body/upper_wick/lower_wick/range/bullish
- Called from `OrderProcess.mqh` (TRADED event) and `OrderBlock.mq5` (CLOSED event)

### Dependencies
- Uses Python venv at `analytics/.venv/` (pandas, scikit-learn, shap, matplotlib, seaborn, scipy)
- Reads from: `ob_dataset_traded.csv` (built by `build_dataset.py`) + `ob_candles_*.csv`
- Outputs: terminal report + `forensics_report.html`

---

## Forensics Findings — XAUUSD (2022-2026, 126 trades: 57W / 54L)

**Date of analysis: 2026-03-22**

### Confirmed Loss Patterns (actionable — see GitHub issues)

1. **Bull + Short regime = 23% win rate** (3W / 10L)
   - Shorting when HTF is bullish is catastrophic
   - Recommendation: Block SELL orders when `mHTFTrend == TREND_BULLISH`

2. **09:00 UTC death zone = 31% win rate** (4W / 9L)
   - Consistent across datasets. Likely London open volatility fakeouts
   - Recommendation: Add kill zone filter for 09:00-09:59 UTC

3. **H4 inside bar at entry → 46% of losses vs 10% of wins**
   - H4 consolidation = indecision, OB entries get chopped
   - Recommendation: Detect H4 inside bar and skip entry

4. **H4 engulfing at entry → 50% of wins vs 15% of losses**
   - H4 momentum confirmation strongly favors winners
   - Recommendation: Add H4 engulfing as a quality star / bonus filter

5. **D1 large lower wick ratio → losses (0.381 vs 0.159)**
   - Daily rejection wicks signal institutional activity opposing the OB
   - Recommendation: Skip entry when D1 candle lower wick > 35% of range

6. **New York session = 38.5% win rate** (15W / 24L)
   - Worst session by far. Asian (75%) and Late NY (62.5%) much better
   - Recommendation: Consider restricting or adding extra filters for NY session entries

7. **Wednesday = worst day** (43.3% win rate, 13W / 17L)
   - Mid-week reversals. Tuesday also weak at 38.9%
   - Skip Tuesday filter has positive R impact (+3.13R net)

8. **Low ATR environments = weaker** (44.8% win rate in lowest ATR quartile)
   - High ATR = 64.3% win rate. EA needs volatility to work
   - Current `ATR_max` filter exists but no `ATR_min` — consider adding one

### Top SHAP loss drivers (in order)
1. `rr_ratio` — extreme R:R trades (>4:1) lose more often (tight SL = noise)
2. `ob_body` / `ob_wick` — OB candle geometry matters
3. `sl_dist_pts` — very tight stops (< 2 pts) get stopped out by noise
4. `hour_utc` — time of day is a real factor
5. `stars` — quality scoring works, but minimum should be higher

### Loss archetypes
- **Cluster 1 (26%)**: Small OBs with tiny body/wick, tight TP — "noise trades"
- **Cluster 2 (74%)**: Normal-sized OBs, concentrated in NY session — "NY reversal victims"
