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
