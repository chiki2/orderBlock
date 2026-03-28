#!/bin/bash
# run_rerun.sh — Re-run EURJPY (D1Trend restored) + XAUUSD ATR/KZ (wins bug fixed)

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"
PYTHON="analytics/.venv/bin/python3"

echo "=========================================="
echo "  RE-RUN: EURJPY + XAUUSD ATR/KZ — $(date)"
echo "=========================================="

echo ""
echo "[ITEM 2 RERUN] EURJPY Trailing Sweep (D1Trend restored) — $(date)"
echo "---"
"$PYTHON" scripts/eurjpy_trailing_sweep.py 2>&1 | tee eurjpy_trailing.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

echo ""
echo "[ITEMS 4+5 RERUN] XAUUSD ATR + London KZ Sweep — $(date)"
echo "---"
"$PYTHON" scripts/xauusd_atr_kz_sweep.py 2>&1 | tee xauusd_atr_kz.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

echo ""
echo "=========================================="
echo "  RERUN DONE — $(date)"
echo "=========================================="
