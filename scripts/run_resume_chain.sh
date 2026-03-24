#!/bin/bash
# Chain: GBPUSD ATR rerun → Unexplored resume sweep
# Uses lockfile to prevent multiple instances
BASE="/home/charles/.mt5/drive_c/Program Files/MetaTrader 5/MQL5/Experts/orderBlock"
LOCKFILE="/tmp/sweep_chain.lock"

if [ -f "$LOCKFILE" ]; then
    OTHER_PID=$(cat "$LOCKFILE")
    if kill -0 "$OTHER_PID" 2>/dev/null; then
        echo "ERROR: Another sweep is running (PID $OTHER_PID). Exiting."
        exit 1
    else
        echo "Stale lockfile found (PID $OTHER_PID dead). Removing."
        rm -f "$LOCKFILE"
    fi
fi

echo $$ > "$LOCKFILE"
trap "rm -f $LOCKFILE" EXIT

cd "$BASE"

# Kill any stale MT5 processes
pkill -9 -f "terminal64.exe" 2>/dev/null || true
pkill -9 -f "metatester" 2>/dev/null || true
sleep 3

echo "=== Starting GBPUSD ATR Re-run at $(date) ==="
python3 scripts/gbpusd_atr_rerun.py 2>&1 | tee /tmp/gbpusd_atr_rerun.log

echo ""
echo "=== Starting Unexplored Sweep Resume at $(date) ==="
python3 scripts/unexplored_resume.py 2>&1 | tee /tmp/unexplored_resume.log

echo ""
echo "=== ALL SWEEPS COMPLETE at $(date) ==="
