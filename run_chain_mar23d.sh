#!/usr/bin/env bash
# Chain D — 2026-03-23 — USDX cancel fix sweep (post chain C)
# Root cause analysis complete: two cancellation mechanisms identified:
#   1. outdatedOB=80×15min=20h too short for slowly-retracing USDX
#   2. hasOppositeOB() in cOrderBlock.mqh:107 cancels pending on opposite OB (stars>=3)
# Note: maxGain is a stale orphan parameter — not in EA code, zero effect
# Fix attempts: longer outdatedOB, wider tolerance, STOP orders

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
LOG="/tmp/chain_mar23d.log"
CHAIN_C_LOG="/tmp/chain_mar23c.log"

cd "$BASE"

echo "========================================" | tee -a "$LOG"
echo "  Chain D started: $(date)" | tee -a "$LOG"
echo "  USDX cancel fix sweep — 16 tests" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo ">>> USDX Cancel Fix Sweep (16 tests)" | tee -a "$LOG"
python3 usdx_cancel_sweep.py 2>&1 | tee -a "$LOG"

echo "" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
echo "  Chain D COMPLETE: $(date)" | tee -a "$LOG"
echo "========================================" | tee -a "$LOG"
