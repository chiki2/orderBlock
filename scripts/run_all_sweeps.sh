#!/bin/bash
# Master sweep runner — chains all pending sweeps after EURUSD combo
# Run: nohup bash scripts/run_all_sweeps.sh > /tmp/all_sweeps.log 2>&1 &

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"

echo "=========================================="
echo "  MASTER SWEEP RUNNER — $(date)"
echo "=========================================="

# Wait for any running backtest to finish
echo "Waiting for any running backtests..."
while pgrep -f "eurusd_combo.py" > /dev/null 2>&1; do
    sleep 60
done
echo "EURUSD combo done at $(date)"

# 1. Weak-year forensics
echo ""
echo "[PHASE 1] Weak-Year Forensics — $(date)"
echo "---"
python3 scripts/weak_year_forensics.py

# 2. Trailing stop optimization
echo ""
echo "[PHASE 2] Trailing Stop Sweep — $(date)"
echo "---"
python3 scripts/trailing_stop_sweep.py

# 3. Untested parameters
echo ""
echo "[PHASE 3] Untested Parameters Sweep — $(date)"
echo "---"
python3 scripts/untested_params_sweep.py

# 4. EURUSD cross-year validation (DailyBias)
echo ""
echo "[PHASE 4] EURUSD Cross-Year Validation — $(date)"
echo "---"
python3 scripts/eurusd_crossyear.py

# 5. Trailing stop sweep (redo — crashed in phase 2 due to old code)
echo ""
echo "[PHASE 5] Trailing Stop Sweep (redo) — $(date)"
echo "---"
python3 scripts/trailing_stop_sweep.py

# 6. Weak-year forensics (redo — crashed in phase 1)
echo ""
echo "[PHASE 6] Weak-Year Forensics (redo) — $(date)"
echo "---"
python3 scripts/weak_year_forensics.py

echo ""
echo "=========================================="
echo "  ALL SWEEPS COMPLETE — $(date)"
echo "=========================================="
