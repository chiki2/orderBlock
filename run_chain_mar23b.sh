#!/usr/bin/env bash
# Chain B — 2026-03-23 (fixes from chain A)
# 1. EURJPY STOP+TP combo (KZ now enabled, timeout=1800s) — 12 tests ~2h
# 2. USDX parameter tuning — 13 tests ~2h

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
LOG="/tmp/chain_mar23b.log"

cd "$BASE"

echo "========================================" | tee -a "$LOG"
echo "  Chain B started: $(date)" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> [1/2] EURJPY STOP+TP combo sweep (KZ=ON, timeout=1800s)" | tee -a "$LOG"
python3 eurjpy_combo_sweep.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> [2/2] USDX parameter tuning" | tee -a "$LOG"
python3 usdx_tune.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
echo "  Chain B COMPLETE: $(date)" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
