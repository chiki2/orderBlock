# Order Block Analytics

Random Forest + SHAP model that learns which ICT Order Block patterns
succeed (WIN) vs fail (LOSS/EXPIRED) and which filtered OBs were missed
opportunities.

## Workflow

```
1. Backtest EA  →  MQL5/Files/ob_data_XAUUSD_*.csv
2. parse_ob_data.py  →  parsed_obs.csv
3. model.py          →  feature_importance.png + classification_report.txt
```

---

## 1. Run a backtest to generate data

In MetaTrader 5 Strategy Tester:
- Load `OrderBlock.mq5`
- Run on XAUUSD H1 (or your symbol/timeframe)
- After the test the file appears at:
  `%AppData%\MetaQuotes\Terminal\<id>\MQL5\Files\ob_data_XAUUSD_PERIOD_H1_<date>.csv`

The EA writes one CSV row per OB lifecycle event:

| event_type      | When                                      |
|-----------------|-------------------------------------------|
| DETECTED        | New OB found by `detectNewOB()`          |
| FILTERED_DETECT | OB rejected at detection (counter-trend) |
| FILTERED_TICK   | OB rejected in `onTick()` filter loop    |
| TRADED          | Order placed                              |
| CLOSED          | Trade closed (outcome=WIN/LOSS)           |
| EXPIRED         | OB timed out (too many candles)           |
| MITIGATED       | OB touched but no trade was taken         |

---

## 2. Install dependencies

```bash
pip install -r requirements.txt
```

---

## 3. Parse the raw CSV

```bash
python parse_ob_data.py \
    --input  "path/to/ob_data_XAUUSD_PERIOD_H1_20250101.csv" \
    --output parsed_obs.csv
```

Output: `parsed_obs.csv` — one row per OB, features from DETECTED snapshot,
label from final outcome.

---

## 4. Train the model

```bash
python model.py \
    --input      parsed_obs.csv \
    --point      0.01 \
    --output-dir results/
```

Output files in `results/`:

| File | Content |
|------|---------|
| `feature_importance.png`    | SHAP bar chart — most predictive features |
| `classification_report.txt` | Precision / recall / F1 per class + ROC-AUC |
| `missed_obs_analysis.csv`   | Missed OBs ranked by predicted WIN probability |
| `ob_model.pkl`              | Trained pipeline (for inference) |

---

## 5. Interpreting results

### feature_importance.png
Shows which OB fields most influence the WIN/LOSS prediction.
High `ob_size_pips` importance → OB size matters most.
High `htf_aligned` importance → trend alignment is critical.

### missed_obs_analysis.csv
Lists OBs that were filtered out but scored high `prob_win`.
Sort by `prob_win DESC` to find the best missed setups.
Use these insights to relax or re-tune EA filters.

---

## Notes

- You need **at least 50–100 traded OBs** (with known WIN/LOSS) for the
  model to be meaningful. Run 2–3 years of backtest data.
- The `--point` value must match your symbol:
  - Gold (XAUUSD): `0.01`
  - Forex pairs:   `0.00001`
  - Indices:       `0.1`
- The model is retrained on every run. No incremental training.
