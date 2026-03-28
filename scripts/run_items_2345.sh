#!/bin/bash
# run_items_2345.sh — Items 2-5: EURJPY trailing, EURUSD NoBias, XAUUSD ATR+LondonKZ
# Runs 3 sweep scripts sequentially, cleans up tester files between runs.

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"
PYTHON="analytics/.venv/bin/python3"
LOG_DIR="$BASE"

echo "=========================================="
echo "  ITEMS 2-5 SWEEP RUNNER — $(date)"
echo "=========================================="

# ── Item 2: EURJPY trailing stop sweep ─────────────────────────────────────
echo ""
echo "[ITEM 2] EURJPY Trailing Stop Sweep — $(date)"
echo "---"
"$PYTHON" scripts/eurjpy_trailing_sweep.py 2>&1 | tee "$LOG_DIR/eurjpy_trailing.log"
echo ""
echo "Cleanup after EURJPY sweep..."
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

# ── Item 3: EURUSD NoBias cross-year ───────────────────────────────────────
echo ""
echo "[ITEM 3] EURUSD No-DailyBias Cross-Year — $(date)"
echo "---"
"$PYTHON" scripts/eurusd_nobias_xv.py 2>&1 | tee "$LOG_DIR/eurusd_nobias_xv.log"
echo ""
echo "Cleanup after EURUSD sweep..."
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

# ── Items 4 & 5: XAUUSD ATR min + London-only KZ ──────────────────────────
echo ""
echo "[ITEMS 4+5] XAUUSD ATR Min + London KZ Sweep — $(date)"
echo "---"
"$PYTHON" scripts/xauusd_atr_kz_sweep.py 2>&1 | tee "$LOG_DIR/xauusd_atr_kz.log"
echo ""
echo "Final cleanup..."
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

echo ""
echo "=========================================="
echo "  ALL DONE — $(date)"
echo "=========================================="
echo ""
echo "Results:"
echo "  eurjpy_trailing_sweep_results.csv"
echo "  eurusd_nobias_xv_results.csv"
echo "  xauusd_atr_kz_sweep_results.csv"
echo "  xauusd_atr_kz_xv_results.csv  (if winners found)"
echo ""
echo "Logs:"
echo "  eurjpy_trailing.log"
echo "  eurusd_nobias_xv.log"
echo "  xauusd_atr_kz.log"
