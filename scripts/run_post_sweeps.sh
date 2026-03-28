#!/bin/bash
# Post sweeps: runs after run_all_sweeps.sh finishes phases 3-4
# Redoes trailing stop (crashed) and weak-year forensics (crashed)

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"

echo "=========================================="
echo "  POST-SWEEP RUNNER — $(date)"
echo "=========================================="

# Wait for main sweep runner to finish
echo "Waiting for main sweep runner..."
while ps -p 658448 > /dev/null 2>&1; do
    sleep 60
done
echo "Main sweeps done at $(date)"

# 5. Trailing stop sweep (redo — crashed earlier)
echo ""
echo "[PHASE 5] Trailing Stop Sweep (redo) — $(date)"
echo "---"
python3 scripts/trailing_stop_sweep.py

# 6. Weak-year forensics (redo — crashed earlier)
echo ""
echo "[PHASE 6] Weak-Year Forensics (redo) — $(date)"
echo "---"
python3 scripts/weak_year_forensics.py

echo ""
echo "=========================================="
echo "  POST-SWEEPS COMPLETE — $(date)"
echo "=========================================="
