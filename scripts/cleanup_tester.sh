#!/bin/bash
# cleanup_tester.sh — Free disk space after backtest series
#
# What it removes:
#   1. ob_data_* and ob_candles_* CSVs from all tester agent Files/ dirs
#   2. Tick data for symbols NOT in the deployed portfolio (safe to re-download)
#
# What it KEEPS:
#   - Tick data for: XAUUSD, USDJPY, EURJPY, GBPUSD, EURUSD (+ any passed as args)
#   - All .set files, EA logs, backtest_last.json, etc.
#
# Usage:
#   bash scripts/cleanup_tester.sh              # default keep list
#   bash scripts/cleanup_tester.sh XAUUSD USDJPY EURUSD   # explicit keep list

set -euo pipefail

MT5_TESTER="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/Tester"
MT5_FILES="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Files"

# Symbols to KEEP (won't delete their tick data)
if [ $# -gt 0 ]; then
    KEEP=("$@")
else
    KEEP=(XAUUSD USDJPY EURJPY GBPUSD EURUSD)
fi

echo "========================================"
echo "  MT5 Tester Cleanup — $(date '+%Y-%m-%d %H:%M')"
echo "========================================"
echo "  Keeping ticks for: ${KEEP[*]}"
echo ""

# ── 1. Remove ob_data / ob_candles CSVs from tester agents ─────────────────
echo "[1/2] Removing ob_data/ob_candles from tester agent Files/..."
DELETED_CSV=0
while IFS= read -r -d '' f; do
    rm -f "$f"
    ((DELETED_CSV++)) || true
done < <(find "$MT5_TESTER" -type f \( -name "ob_data_*.csv" -o -name "ob_candles_*.csv" \) -print0 2>/dev/null)
echo "      Removed $DELETED_CSV CSV files from tester agents"

# ── 2. Remove tick data for non-deployed symbols ────────────────────────────
echo "[2/2] Removing tick data for non-deployed symbols..."
TICKS_DIR="$MT5_TESTER/bases/FusionMarkets-Live/ticks"
FREED=0
if [ -d "$TICKS_DIR" ]; then
    for sym_dir in "$TICKS_DIR"/*/; do
        sym=$(basename "$sym_dir")
        keep=false
        for k in "${KEEP[@]}"; do
            if [ "$sym" = "$k" ]; then
                keep=true
                break
            fi
        done
        if [ "$keep" = false ]; then
            size=$(du -sm "$sym_dir" 2>/dev/null | cut -f1)
            rm -rf "$sym_dir"
            echo "      Deleted ticks/$sym  (~${size}MB)"
            FREED=$((FREED + size))
        else
            echo "      Kept   ticks/$sym"
        fi
    done
fi
echo ""
echo "  ~${FREED}MB of tick data freed"

# ── Summary ─────────────────────────────────────────────────────────────────
echo ""
echo "  Cleanup complete."
df -h /home/charles | tail -1 | awk '{print "  Disk: " $3 " used / " $2 " total (" $5 " full)"}'
echo "========================================"
