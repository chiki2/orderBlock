#!/bin/bash
# run_next_batch.sh — GBPUSD trailing, AUDUSD Option C, XAUUSD quality, 2022 forensics

BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
cd "$BASE"
PYTHON="analytics/.venv/bin/python3"

echo "=========================================="
echo "  NEXT BATCH — $(date)"
echo "=========================================="

# ── GBPUSD trailing stop sweep ─────────────────────────────────────────────
echo ""
echo "[A] GBPUSD Trailing Stop Sweep — $(date)"
"$PYTHON" scripts/gbpusd_trailing_sweep.py 2>&1 | tee gbpusd_trailing.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

# ── AUDUSD Option C cross-year ─────────────────────────────────────────────
echo ""
echo "[B] AUDUSD Option C Cross-Year — $(date)"
"$PYTHON" scripts/audusd_option_c_xv.py 2>&1 | tee audusd_optionc.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD AUDUSD 2>/dev/null || true

# ── XAUUSD quality/filter sweep ────────────────────────────────────────────
echo ""
echo "[C] XAUUSD Quality Sweep — $(date)"
"$PYTHON" scripts/xauusd_quality_sweep.py 2>&1 | tee xauusd_quality.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

# ── XAUUSD 2022-only forensics ─────────────────────────────────────────────
echo ""
echo "[D] XAUUSD 2022 Forensics — $(date)"
"$PYTHON" forensics.py --from-date 2022.01.01 --to-date 2023.01.01 --no-html 2>&1 | tee xauusd_2022_forensics.log
bash scripts/cleanup_tester.sh XAUUSD USDJPY EURJPY GBPUSD EURUSD 2>/dev/null || true

echo ""
echo "=========================================="
echo "  BATCH DONE — $(date)"
echo "=========================================="
echo ""
echo "Results:"
ls -1 gbpusd_trailing* audusd_optionc* xauusd_quality* xauusd_2022* 2>/dev/null
