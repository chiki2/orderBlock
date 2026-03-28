#!/bin/bash
# Final remaining phases: EURUSD xv + weak-year forensics
# Waits for post_sweeps.sh to finish phases 5-6 first

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"

echo "=========================================="
echo "  REMAINING SWEEPS — $(date)"
echo "=========================================="

# Wait for post_sweeps runner to finish
echo "Waiting for post-sweep runner (PID 667743)..."
while ps -p 667743 > /dev/null 2>&1; do
    sleep 60
done
echo "Post-sweeps done at $(date)"

# EURUSD cross-year validation
echo ""
echo "[PHASE A] EURUSD Cross-Year Validation — $(date)"
echo "---"
python3 scripts/eurusd_crossyear.py

# MinRR cross-year validation (critical finding from untested params sweep)
echo ""
echo "[PHASE B] MinRR Cross-Year Validation — $(date)"
echo "---"
python3 scripts/minrr_crossyear.py

# Trailing stop cross-year validation (auto-detects winners from Phase 5)
echo ""
echo "[PHASE C] Trailing Stop Cross-Year Validation — $(date)"
echo "---"
python3 scripts/trailing_stop_crossyear.py

echo ""
echo "=========================================="
echo "  REMAINING SWEEPS COMPLETE — $(date)"
echo "=========================================="
