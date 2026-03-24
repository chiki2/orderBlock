#!/usr/bin/env bash
# Sequential sweep chain — 2026-03-23
# 1. XAUUSD inpRequireSweep=false (2 tests, ~15 min)
# 2. EURJPY STOP+TP combo (11 tests, ~90 min)
# 3. USDX probe (1-4 tests, ~30 min)

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
LOG="/tmp/chain_mar23.log"

cd "$BASE"

echo "========================================" | tee -a "$LOG"
echo "  Chain started: $(date)" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> [1/3] XAUUSD inpRequireSweep=false test" | tee -a "$LOG"
python3 sweep_require_sweep.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> [2/3] EURJPY STOP+TP combo sweep" | tee -a "$LOG"
python3 eurjpy_combo_sweep.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> [3/3] Dollar Index (USDX) probe" | tee -a "$LOG"
python3 usdx_probe.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
echo "  Chain COMPLETE: $(date)" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
