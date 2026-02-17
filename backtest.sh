#!/bin/bash
# backtest.sh — Compile + run MetaTrader 5 Strategy Tester, parse results, compare with baseline
#
# Usage:
#   ./backtest.sh               # run with defaults
#   ./backtest.sh --baseline    # save current results as the new baseline
#   SYMBOL=EURUSD FROM_DATE=2024.01.01 ./backtest.sh
#
# Output:
#   backtest_last.json     — metrics from the latest run
#   backtest_baseline.json — saved baseline to compare against

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MT5_ROOT="/home/charles/.mt5"
MT5_DIR="$MT5_ROOT/drive_c/Program Files/MetaTrader 5"
MT5_EXE="$MT5_DIR/terminal64.exe"
EDITOR_EXE="$MT5_DIR/MetaEditor64.exe"
WINEPREFIX="$MT5_ROOT"
WINE="$(which wine)"

EA_SRC_WIN='C:\Program Files\MetaTrader 5\MQL5\Experts\orderBlock\OrderBlock.mq5'
CONFIG_PATH="$MT5_DIR/Config/backtest.ini"
CONFIG_WIN='C:\Program Files\MetaTrader 5\Config\backtest.ini'

LAST_JSON="$SCRIPT_DIR/backtest_last.json"
BASELINE_JSON="$SCRIPT_DIR/backtest_baseline.json"

# ── Parameters (overridable via env) ───────────────────────────────────────
SYMBOL="${SYMBOL:-XAUUSD}"
PERIOD="${PERIOD:-M15}"
FROM_DATE="${FROM_DATE:-2025.01.01}"
TO_DATE="${TO_DATE:-2026.01.01}"
DEPOSIT="${DEPOSIT:-10000}"
LEVERAGE="${LEVERAGE:-100}"
MODEL="${MODEL:-1}"   # 0=Every tick  1=1-min OHLC (fast)  4=Real ticks
SAVE_BASELINE=false

for arg in "$@"; do
  [[ "$arg" == "--baseline" ]] && SAVE_BASELINE=true
done

# ── Helpers ────────────────────────────────────────────────────────────────
red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

read_log() {
  # Read a potentially UTF-16 log file, strip null bytes and return plain text
  python3 - "$1" << 'PYEOF'
import sys, codecs
path = sys.argv[1]
try:
    with codecs.open(path, 'r', 'utf-16') as f:
        print(f.read())
except Exception:
    with open(path, errors='replace') as f:
        print(f.read().replace('\x00', ''))
PYEOF
}

# ── Step 1: Compile ─────────────────────────────────────────────────────────
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold " Step 1/3: Compiling EA with MetaEditor"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

COMPILE_LOG="$MT5_DIR/MQL5/Experts/orderBlock/compile.log"

WINEPREFIX="$WINEPREFIX" "$WINE" "$EDITOR_EXE" \
  "/compile:$EA_SRC_WIN" \
  "/log:C:\\Program Files\\MetaTrader 5\\MQL5\\Experts\\orderBlock\\compile.log" \
  2>/dev/null
EDITOR_EXIT=$?

# Give MetaEditor a moment to write the log
sleep 2

if [[ -f "$COMPILE_LOG" ]]; then
  COMPILE_TEXT=$(read_log "$COMPILE_LOG")
  ERRORS=$(echo "$COMPILE_TEXT" | grep -c " error" || true)
  WARNINGS=$(echo "$COMPILE_TEXT" | grep -c " warning" || true)
  if [[ "$ERRORS" -gt 0 ]]; then
    red "Compile FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    echo "$COMPILE_TEXT" | grep -E "error|warning" | head -20
    exit 1
  else
    green "Compile OK — $WARNINGS warning(s)"
  fi
else
  yellow "No compile log found — assuming EA is up to date"
fi

# ── Step 2: Write tester config + run backtest ─────────────────────────────
bold ""
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold " Step 2/3: Running Strategy Tester"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Symbol:  $SYMBOL"
echo "  Period:  $PERIOD"
echo "  Range:   $FROM_DATE → $TO_DATE"
echo "  Model:   $MODEL  (0=tick 1=1min-OHLC 4=real-ticks)"
echo "  Deposit: $DEPOSIT USD  Leverage: 1:$LEVERAGE"

cat > "$CONFIG_PATH" << EOF
[Tester]
Expert=orderBlock\OrderBlock
Symbol=$SYMBOL
Period=$PERIOD
Model=$MODEL
Optimization=0
FromDate=$FROM_DATE
ToDate=$TO_DATE
Deposit=$DEPOSIT
Leverage=1:$LEVERAGE
Currency=USD
ShutdownTerminal=1
EOF

START_TIME=$(date +%s)
WINEPREFIX="$WINEPREFIX" "$WINE" "$MT5_EXE" /portable "/config:$CONFIG_WIN" 2>/dev/null
MT5_EXIT=$?
END_TIME=$(date +%s)
WALL_TIME=$(( END_TIME - START_TIME ))

echo "  MT5 exited after ${WALL_TIME}s (exit code: $MT5_EXIT)"

# ── Step 3: Parse results ───────────────────────────────────────────────────
bold ""
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold " Step 3/3: Parsing results"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TODAY=$(date +%Y%m%d)

# Find most recently modified agent log for today
AGENT_LOG=$(find "$MT5_DIR/Tester" -name "${TODAY}.log" -path "*/Agent-127*" \
            -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

if [[ -z "$AGENT_LOG" || ! -f "$AGENT_LOG" ]]; then
  red "No agent log found for $TODAY. Did the test run?"
  exit 1
fi

echo "  Log: $AGENT_LOG"
LOG_TEXT=$(read_log "$AGENT_LOG")

# Extract metrics
BALANCE=$(echo "$LOG_TEXT"    | grep -oP 'final balance \K[\d.]+' | tail -1 || echo "0")
ONTESTER=$(echo "$LOG_TEXT"   | grep -oP 'OnTester result \K[\d]+' | tail -1 || echo "0")
TOTAL_OB=$(echo "$LOG_TEXT"   | grep -oP 'Total OB : \K\d+' | tail -1 || echo "0")
TRADED=$(echo "$LOG_TEXT"     | grep -oP 'Step ENUM_FC_All_CHECK : \K\d+' | tail -1 || echo "0")
FC_OB=$(echo "$LOG_TEXT"      | grep -oP 'Step ENUM_FC_VALID_OB : \K\d+' | tail -1 || echo "0")
FC_MSS=$(echo "$LOG_TEXT"     | grep -oP 'Step ENUM_FC_VALID_MSS : \K\d+' | tail -1 || echo "0")
FC_SWEEP=$(echo "$LOG_TEXT"   | grep -oP 'Step ENUM_FC_VALID_SWEEP : \K\d+' | tail -1 || echo "0")
FC_TIMP=$(echo "$LOG_TEXT"    | grep -oP 'Step ENUM_FC_IN_TOP_IMP : \K\d+' | tail -1 || echo "0")
OVERDUE=$(echo "$LOG_TEXT"    | grep -oP 'OB is overdue : \K\d+' | tail -1 || echo "0")
MITIGATED=$(echo "$LOG_TEXT"  | grep -oP 'OB is mitigated : \K\d+' | tail -1 || echo "0")
NO_MSS=$(echo "$LOG_TEXT"     | grep -oP 'No real MSS for this OB. Soon deleted : \K\d+' | tail -1 || echo "0")
ONGOING=$(echo "$LOG_TEXT"    | grep -oP 'A trade is ongoing : \K\d+' | tail -1 || echo "0")
TEST_DUR=$(echo "$LOG_TEXT"   | grep -oP 'Test passed in \K[0-9:\.]+' | tail -1 || echo "?")
TICKS=$(echo "$LOG_TEXT"      | grep -oP '(\d+) ticks,' | grep -oP '\d+' | tail -1 || echo "0")

# Win rate from ob_data CSV if available
WIN_RATE="n/a"
OB_CSV=$(find "$MT5_DIR/Tester" -name "ob_data_${SYMBOL}*.csv" \
         -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [[ -n "$OB_CSV" && -f "$OB_CSV" ]]; then
  WIN_RATE=$(python3 << PYEOF
import csv
wins = losses = 0
try:
    with open("$OB_CSV") as f:
        for row in csv.DictReader(f):
            o = row.get('outcome','').strip()
            if o == 'WIN':   wins += 1
            elif o in ('LOSS','EXPIRED'): losses += 1
total = wins + losses
if total > 0:
    print(f"{wins}/{total} ({100*wins/total:.0f}%)")
else:
    print("n/a")
PYEOF
)
fi

# Funnel conversion rate (OB → traded)
if [[ "$TOTAL_OB" -gt 0 ]]; then
  FUNNEL_PCT=$(python3 -c "print(f'{100*$TRADED/$TOTAL_OB:.1f}%')" 2>/dev/null || echo "?")
else
  FUNNEL_PCT="?"
fi

# ── Display results ─────────────────────────────────────────────────────────
bold ""
bold "  ┌─────────────────────────────────────────┐"
bold "  │         BACKTEST RESULTS                │"
bold "  ├─────────────────────────────────────────┤"
printf "  │  %-20s  %16s │\n" "Balance (pips)"   "$BALANCE"
printf "  │  %-20s  %16s │\n" "OnTester score"   "$ONTESTER"
printf "  │  %-20s  %16s │\n" "Win rate"         "$WIN_RATE"
bold "  ├─────────────────────────────────────────┤"
printf "  │  %-20s  %16s │\n" "Total OBs"        "$TOTAL_OB"
printf "  │  %-20s  %16s │\n" "→ pass VALID_OB"  "$FC_OB"
printf "  │  %-20s  %16s │\n" "→ pass MSS"       "$FC_MSS"
printf "  │  %-20s  %16s │\n" "→ pass SWEEP"     "$FC_SWEEP"
printf "  │  %-20s  %16s │\n" "→ pass TOP_IMP"   "$FC_TIMP"
printf "  │  %-20s  %16s │\n" "→ TRADED"         "$TRADED ($FUNNEL_PCT)"
bold "  ├─────────────────────────────────────────┤"
printf "  │  %-20s  %16s │\n" "Overdue"          "$OVERDUE"
printf "  │  %-20s  %16s │\n" "Mitigated"        "$MITIGATED"
printf "  │  %-20s  %16s │\n" "No MSS"           "$NO_MSS"
printf "  │  %-20s  %16s │\n" "Skipped (ongoing)" "$ONGOING"
bold "  ├─────────────────────────────────────────┤"
printf "  │  %-20s  %16s │\n" "Test duration"    "$TEST_DUR"
printf "  │  %-20s  %16s │\n" "Wall time"        "${WALL_TIME}s"
printf "  │  %-20s  %16s │\n" "Ticks"            "$TICKS"
bold "  └─────────────────────────────────────────┘"

# ── Save current results as JSON ────────────────────────────────────────────
python3 << PYEOF > "$LAST_JSON"
import json
data = {
    "symbol": "$SYMBOL", "period": "$PERIOD",
    "from": "$FROM_DATE", "to": "$TO_DATE",
    "model": $MODEL, "deposit": $DEPOSIT,
    "balance": float("$BALANCE") if "$BALANCE" else 0,
    "ontester": int("$ONTESTER") if "$ONTESTER" else 0,
    "win_rate_str": "$WIN_RATE",
    "total_ob": int("$TOTAL_OB"),
    "fc_ob": int("$FC_OB"),
    "fc_mss": int("$FC_MSS"),
    "fc_sweep": int("$FC_SWEEP"),
    "fc_timp": int("$FC_TIMP"),
    "traded": int("$TRADED"),
    "overdue": int("$OVERDUE"),
    "mitigated": int("$MITIGATED"),
    "no_mss": int("$NO_MSS"),
    "ongoing": int("$ONGOING"),
    "test_duration": "$TEST_DUR",
    "wall_time_s": $WALL_TIME,
    "ticks": int("$TICKS"),
}
print(json.dumps(data, indent=2))
PYEOF

# ── Compare with baseline ───────────────────────────────────────────────────
if $SAVE_BASELINE; then
  cp "$LAST_JSON" "$BASELINE_JSON"
  green ""
  green "  ✓ Saved as new baseline: $BASELINE_JSON"
elif [[ -f "$BASELINE_JSON" ]]; then
  bold ""
  bold "  ┌─────────────────────────────────────────┐"
  bold "  │     DELTA vs BASELINE                   │"
  bold "  └─────────────────────────────────────────┘"
  python3 - "$LAST_JSON" "$BASELINE_JSON" << 'PYEOF'
import json, sys

def delta(new, old, key, fmt=".0f", pct=False):
    n = new.get(key, 0)
    o = old.get(key, 0)
    if isinstance(n, float) or isinstance(o, float):
        d = float(n) - float(o)
    else:
        d = int(n) - int(o)
    arrow = "▲" if d > 0 else ("▼" if d < 0 else "─")
    color = "\033[32m" if d > 0 else ("\033[31m" if d < 0 else "\033[33m")
    reset = "\033[0m"
    pct_str = f"({100*d/float(o):.1f}%)" if pct and o != 0 else ""
    print(f"  {color}{arrow}{reset}  {key:<22} {format(float(o), fmt)} → {format(float(n), fmt)} {color}{pct_str}{reset}")

with open(sys.argv[1]) as f:
    new = json.load(f)
with open(sys.argv[2]) as f:
    old = json.load(f)

delta(new, old, "balance",     ".2f", pct=True)
delta(new, old, "ontester",    ".0f", pct=True)
delta(new, old, "traded",      ".0f", pct=True)
delta(new, old, "overdue",     ".0f")
delta(new, old, "mitigated",   ".0f")
delta(new, old, "no_mss",      ".0f")
delta(new, old, "wall_time_s", ".0f")
PYEOF
else
  yellow ""
  yellow "  No baseline yet. Run with --baseline to save current results as baseline."
fi

bold ""
echo "  Full results: $LAST_JSON"
