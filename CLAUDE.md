# OrderBlock EA — Project Rules for Claude

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

## Architecture Quick Reference
- `HTOB=16385` = PERIOD_H1 (trend timeframe)
- `CTOB=15` = PERIOD_M15 (signal timeframe)
- `typeofOrder=1` = LIMIT orders (STOP=2 never triggers in XAUUSD backtest)
- `g_reasonCounters` array size must equal `ENUM_REASON_last_value + 1` — crashes if wrong
- Do NOT add `#include "langs.mqh"` to `helpers.mqh` — causes 100+ compile errors

## Include Rule
`langs.mqh` → T() → uses `language` var declared in `OrderBlock.mq5` AFTER all includes.
Only include `langs.mqh` from files that are included AFTER `OrderBlock.mq5` processes it.

## GitHub Issues
Use the `gh-issue` skill when creating features or fixes. Close issues with summary comments.
