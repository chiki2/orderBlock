#!/bin/bash
# Chain: ATR sweep (already running) → Unexplored params sweep
# Usage: This script waits for the ATR sweep to finish, then runs the next sweep.

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"

echo "=== Waiting for ATR sweep to finish ==="
while pgrep -f "atr_pct_sweep.py" > /dev/null 2>&1; do
    sleep 30
done
echo "=== ATR sweep done at $(date) ==="

echo ""
echo "=== Starting Unexplored Parameters Sweep at $(date) ==="
python3 scripts/unexplored_sweep.py 2>&1 | tee /tmp/unexplored_sweep.log

echo ""
echo "=== ALL SWEEPS COMPLETE at $(date) ==="
