#!/usr/bin/env bash
# Chain C — 2026-03-23 — Full sweeps (post chain B)
# 1. EURJPY full sweep — 40 tests, ~6h
# 2. USDX full sweep  — 33 tests, ~5h

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
LOG="/tmp/chain_mar23c.log"

cd "$BASE"

echo "========================================" | tee -a "$LOG"
echo "  Chain C started: $(date)" | tee -a "$LOG"
echo "  EURJPY: 40 tests | USDX: 33 tests" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> [1/2] EURJPY Full Sweep (40 tests)" | tee -a "$LOG"
python3 eurjpy_full_sweep.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> [2/2] USDX Full Sweep (33 tests)" | tee -a "$LOG"
python3 usdx_full_sweep.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
echo "  Chain C COMPLETE: $(date)" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
