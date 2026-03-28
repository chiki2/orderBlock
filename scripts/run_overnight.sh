#!/bin/bash
# run_overnight.sh — Full overnight autonomous sweep
# Waits for EURJPY quality sweep to finish, then runs:
#   [A] OOS 2026 Q1 portfolio test (4 backtests)
#   [B] EURJPY forensics (1 backtest + analysis)
#   [C] Dynamic params sweep — WeekdayScaling + ATRTP (4 symbols × 4 configs)
#   [D] Apply any winners to set files + commit

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"
PYTHON="analytics/.venv/bin/python3"

echo "=========================================="
echo "  OVERNIGHT RUN — $(date)"
echo "=========================================="

# ── Wait for EURJPY quality sweep ──────────────────────────────────────────
echo ""
echo "[0] Waiting for EURJPY quality sweep to finish..."
while pgrep -f "eurjpy_quality_sweep.py" > /dev/null 2>&1; do
    sleep 30
done
echo "[0] EURJPY sweep done — $(date)"

# ── A. OOS 2026 Q1 ─────────────────────────────────────────────────────────
echo ""
echo "[A] Out-of-Sample 2026 Q1 — $(date)"
"$PYTHON" scripts/oos_2026q1.py 2>&1 | tee oos_2026q1.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

# ── B. EURJPY forensics ────────────────────────────────────────────────────
echo ""
echo "[B] EURJPY Forensics — $(date)"
DISPLAY=:0 SYMBOL=EURJPY SET_FILE=eurjpy.set \
  "$PYTHON" forensics.py --symbol EURJPY --from-date 2022.01.01 --to-date 2026.03.28 --no-html \
  2>&1 | tee eurjpy_forensics.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

# ── C. Dynamic params sweep ────────────────────────────────────────────────
echo ""
echo "[C] Dynamic Params Sweep — $(date)"
"$PYTHON" scripts/dynamic_params_sweep.py 2>&1 | tee dynamic_params.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

# ── D. Apply winners + commit ──────────────────────────────────────────────
echo ""
echo "[D] Applying winners and committing — $(date)"
"$PYTHON" scripts/apply_dynamic_winners.py 2>&1 | tee apply_winners.log

echo ""
echo "=========================================="
echo "  OVERNIGHT DONE — $(date)"
echo "=========================================="
echo ""
echo "Results:"
ls -1 oos_2026q1.log eurjpy_forensics.log dynamic_params.log apply_winners.log \
       eurjpy_quality.log 2>/dev/null
