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
WINEPREFIX="$MT5_ROOT"
WINE="$(which wine)"

EA_EX5="$MT5_DIR/MQL5/Experts/orderBlock/OrderBlock.ex5"
# Write config to a space-free path to avoid wine quoting issues with /config: arg
CONFIG_PATH="$MT5_ROOT/drive_c/MT5_backtest.ini"
CONFIG_WIN='C:\MT5_backtest.ini'
# ExpertParameters must be just the filename — MT5 looks in MQL5\Profiles\Tester\
SET_FILE_NAME='claude.set'
SET_FILE_PRESETS="$MT5_DIR/MQL5/Profiles/Tester/$SET_FILE_NAME"

LAST_JSON="$SCRIPT_DIR/backtest_last.json"
BASELINE_JSON="$SCRIPT_DIR/backtest_baseline.json"

# ── Parameters (overridable via env) ───────────────────────────────────────
SYMBOL="${SYMBOL:-XAUUSD}"
PERIOD="${PERIOD:-M15}"
FROM_DATE="${FROM_DATE:-2025.01.01}"
TO_DATE="${TO_DATE:-2026.01.01}"
DEPOSIT="${DEPOSIT:-10000}"
LEVERAGE="${LEVERAGE:-500}"
MODEL="${MODEL:-4}"   # 0=Every tick  1=1-min OHLC (fast)  4=Real ticks
REPORT="${REPORT:-claudeReport}"
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

# ── Paths for compile ───────────────────────────────────────────────────────
EA_SRC="$MT5_DIR/MQL5/Experts/orderBlock/OrderBlock.mq5"
EDITOR_EXE="$MT5_DIR/MetaEditor64.exe"
METAEDITOR_LOG="$MT5_DIR/logs/metaeditor.log"

compile_ea() {
  # Compile the EA via MetaEditor command-line mode:
  #   MetaEditor64.exe /compile:"C:\MT5\..." /log
  # Uses C:\MT5 symlink (→ Program Files\MetaTrader 5) to avoid spaces in path.
  # MetaEditor exits after compilation — no GUI interaction needed.
  # Returns 0 on success, 1 on failure.

  # Space-free Windows path via C:\MT5 symlink
  local EA_SRC_WIN='C:\MT5\MQL5\Experts\orderBlock\OrderBlock.mq5'

  pkill -f "MetaEditor64" 2>/dev/null || true
  sleep 1

  # Touch the source to ensure MetaEditor sees it as modified and recompiles
  touch "$EA_SRC"

  echo "  Launching MetaEditor (CLI compile)..."
  (set +e; WINEPREFIX="$WINEPREFIX" "$WINE" "$EDITOR_EXE" \
    "/compile:$EA_SRC_WIN" /log \
    > /tmp/me_compile.log 2>&1)

  # MetaEditor exits after compile — check for .ex5
  if [[ -f "$EA_EX5" ]]; then
    return 0
  fi

  # Show last lines of compile log to help debug
  echo "  MetaEditor compile log (last 20 lines):"
  tail -20 /tmp/me_compile.log 2>/dev/null | sed 's/^/    /' || true

  # Also check metaeditor.log for errors
  if [[ -f "$METAEDITOR_LOG" ]]; then
    echo "  MetaEditor log (last 10 lines):"
    read_log "$METAEDITOR_LOG" 2>/dev/null | tail -10 | sed 's/^/    /' || true
  fi

  return 1
}

# ── Step 1: Ensure EA is compiled ────────────────────────────────────────────
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold " Step 1/3: Checking EA binary"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -f "$EA_EX5" ]]; then
  # Check if source is newer than binary (stale)
  if [[ "$EA_SRC" -nt "$EA_EX5" ]]; then
    yellow "  Source is newer than binary — attempting recompile..."
    if compile_ea; then
      green "  Recompiled successfully"
    else
      yellow "  Recompile failed — running with existing binary (may be outdated)"
    fi
  else
    green "  OrderBlock.ex5 is up to date"
  fi
else
  yellow "  No .ex5 found — attempting to compile with MetaEditor..."
  if compile_ea; then
    green "  Compiled successfully"
  else
    red "  Compile failed. Please open MetaEditor and press F7 to compile OrderBlock.mq5, then re-run this script."
    exit 1
  fi
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

REPORT_FILE="$MT5_DIR/${REPORT}.htm"

# Copy set file to MQL5\presets\ — ExpertParameters must be relative filename in that dir
SET_FILE_LINUX="$MT5_DIR/MQL5/Experts/orderBlock/OBInclude/SetFiles/claude.set"
echo "  Copying claude.set → MQL5/presets/$SET_FILE_NAME"
cp "$SET_FILE_LINUX" "$SET_FILE_PRESETS"

cat > "$CONFIG_PATH" << EOF
[Tester]
Expert=orderBlock\OrderBlock
ExpertParameters=$SET_FILE_NAME
Symbol=$SYMBOL
Period=$PERIOD
Model=$MODEL
Optimization=0
FromDate=$FROM_DATE
ToDate=$TO_DATE
Deposit=$DEPOSIT
Leverage=1:$LEVERAGE
Currency=USD
Report=$REPORT
ReplaceReport=1
ShutdownTerminal=1
EOF

# Kill any existing MT5 instance — a running terminal hands off the config
# to itself and exits immediately, so we must start fresh
if pgrep -f "terminal64" > /dev/null 2>&1; then
  yellow "  Killing existing MT5 instance..."
  pkill -f "terminal64" 2>/dev/null || true
  sleep 3   # let it write its state before dying
fi

START_TIME=$(date +%s)
TODAY=$(date +%Y%m%d)

# Launch MT5 in portable mode — runs the strategy tester in-process,
# so this single wine process covers the entire backtest lifetime
WINEPREFIX="$WINEPREFIX" "$WINE" "$MT5_EXE" /portable "/config:$CONFIG_WIN" \
  > /tmp/mt5_wine.log 2>&1 &
MT5_PID=$!
echo "  MT5 launched (pid $MT5_PID) — running test..."

# Show progress while waiting for MT5 to finish
while kill -0 "$MT5_PID" 2>/dev/null; do
  ELAPSED=$(( $(date +%s) - START_TIME ))
  printf "  ... %ds elapsed\r" "$ELAPSED"
  sleep 2
done
wait "$MT5_PID" 2>/dev/null || true
sleep 1  # allow final log flush

END_TIME=$(date +%s)
WALL_TIME=$(( END_TIME - START_TIME ))
echo ""

# Find the agent log written during this run (most recently modified, after start)
FRESH_LOG=""
while IFS= read -r candidate; do
  MTIME=$(stat -c %Y "$candidate" 2>/dev/null || echo 0)
  if [[ $MTIME -gt $START_TIME ]]; then
    FRESH_LOG="$candidate"
    break
  fi
done < <(find "$MT5_DIR/Tester" -name "${TODAY}.log" -path "*/Agent-127*" \
  -printf '%T@ %p\n' 2>/dev/null | sort -rn | cut -d' ' -f2-)

echo "  Finished after ${WALL_TIME}s"

# ── Step 3: Parse results ───────────────────────────────────────────────────
bold ""
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
bold " Step 3/3: Parsing results"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Use the log identified by the polling loop, or fall back to most recent
AGENT_LOG="$FRESH_LOG"
if [[ -z "$AGENT_LOG" ]]; then
  AGENT_LOG=$(find "$MT5_DIR/Tester" -name "${TODAY}.log" -path "*/Agent-127*" \
              -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
fi

if [[ -z "$AGENT_LOG" || ! -f "$AGENT_LOG" ]]; then
  red "No agent log found for $TODAY. Did the test run?"
  exit 1
fi

echo "  Log: $AGENT_LOG"
LOG_TEXT=$(read_log "$AGENT_LOG")

# Extract metrics
BALANCE=$(echo "$LOG_TEXT"    | grep -oP 'final balance \K[\d.]+' | tail -1 || echo "0")
ONTESTER=$(echo "$LOG_TEXT"   | grep -oP 'OnTester result \K[\d.]+' | tail -1 || echo "0")
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

# ── Parse HTML report for financial metrics ─────────────────────────────────
PROFIT_FACTOR="n/a"; EXPECTED_PAYOFF="n/a"; SHARPE="n/a"
MAX_DD="n/a"; MAX_DD_PCT="n/a"; RECOVERY="n/a"
TOTAL_TRADES="n/a"; PROFIT_TRADES="n/a"; LOSS_TRADES="n/a"

if [[ -f "$REPORT_FILE" ]]; then
  eval "$(python3 - "$REPORT_FILE" << 'PYEOF'
import re, sys, html, codecs

def extract(text, label):
    # MT5 report structure: label ends with ':' inside <td>, value in <b> in next <td>
    pattern = re.escape(label) + r'[^<]*</td>\s*<td[^>]*>\s*(?:<[^>]+>)*([^<]+)'
    m = re.search(pattern, text, re.IGNORECASE)
    return html.unescape(m.group(1).strip()) if m else "n/a"

# MT5 reports are UTF-16 encoded
try:
    with codecs.open(sys.argv[1], 'r', 'utf-16') as f:
        txt = f.read()
except Exception:
    with open(sys.argv[1], encoding='utf-8', errors='replace') as f:
        txt = f.read()

fields = {
    "PROFIT_FACTOR":   extract(txt, "Profit Factor:"),
    "EXPECTED_PAYOFF": extract(txt, "Expected Payoff:"),
    "SHARPE":          extract(txt, "Sharpe Ratio:"),
    "MAX_DD":          extract(txt, "Balance Drawdown Maximal:"),
    "MAX_DD_PCT":      extract(txt, "Balance Drawdown Relative:"),
    "RECOVERY":        extract(txt, "Recovery Factor:"),
    "TOTAL_TRADES":    extract(txt, "Total Trades:"),
    "PROFIT_TRADES":   extract(txt, "Profit Trades"),
    "LOSS_TRADES":     extract(txt, "Loss Trades"),
}
for k, v in fields.items():
    # Shell-safe: strip everything except digits, dot, percent, space, slash, minus
    safe = re.sub(r"[^0-9a-zA-Z%. /\-]", "", v)
    print(f'{k}="{safe}"')
PYEOF
  )"
fi

# Win rate from ob_data CSV if available
WIN_RATE="n/a"
OB_CSV=$(find "$MT5_DIR/Tester" -name "ob_data_${SYMBOL}*.csv" \
         -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)
if [[ -n "$OB_CSV" && -f "$OB_CSV" ]]; then
  WIN_RATE=$(python3 - "$OB_CSV" << 'PYEOF'
import csv, sys
wins = losses = 0
try:
    with open(sys.argv[1]) as f:
        for row in csv.DictReader(f):
            o = row.get('outcome', '').strip()
            if o == 'WIN':
                wins += 1
            elif o in ('LOSS', 'EXPIRED'):
                losses += 1
except Exception as e:
    print("n/a")
    sys.exit(0)
total = wins + losses
print(f"{wins}/{total} ({100*wins/total:.0f}%)" if total > 0 else "n/a")
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
printf "  │  %-20s  %16s │\n" "Profit factor"    "$PROFIT_FACTOR"
printf "  │  %-20s  %16s │\n" "Expected payoff"  "$EXPECTED_PAYOFF"
printf "  │  %-20s  %16s │\n" "Sharpe ratio"     "$SHARPE"
printf "  │  %-20s  %16s │\n" "Max drawdown"     "$MAX_DD"
printf "  │  %-20s  %16s │\n" "Max DD %"         "$MAX_DD_PCT"
printf "  │  %-20s  %16s │\n" "Recovery factor"  "$RECOVERY"
printf "  │  %-20s  %16s │\n" "Total trades"     "$TOTAL_TRADES"
printf "  │  %-20s  %16s │\n" "Profit trades"    "$PROFIT_TRADES"
printf "  │  %-20s  %16s │\n" "Loss trades"      "$LOSS_TRADES"
bold "  ├─────────────────────────────────────────┤"
printf "  │  %-20s  %16s │\n" "Test duration"    "$TEST_DUR"
printf "  │  %-20s  %16s │\n" "Wall time"        "${WALL_TIME}s"
printf "  │  %-20s  %16s │\n" "Ticks"            "$TICKS"
bold "  └─────────────────────────────────────────┘"
if [[ -f "$REPORT_FILE" ]]; then
  echo "  Report: $REPORT_FILE"
fi

# ── Save current results as JSON ────────────────────────────────────────────
python3 << PYEOF > "$LAST_JSON"
import json
data = {
    "symbol": "$SYMBOL", "period": "$PERIOD",
    "from": "$FROM_DATE", "to": "$TO_DATE",
    "model": $MODEL, "deposit": $DEPOSIT,
    "balance": float("$BALANCE") if "$BALANCE" else 0,
    "ontester": float("$ONTESTER") if "$ONTESTER" else 0,
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
    "profit_factor": "$PROFIT_FACTOR",
    "expected_payoff": "$EXPECTED_PAYOFF",
    "sharpe": "$SHARPE",
    "max_dd": "$MAX_DD",
    "max_dd_pct": "$MAX_DD_PCT",
    "recovery_factor": "$RECOVERY",
    "total_trades": "$TOTAL_TRADES",
    "profit_trades": "$PROFIT_TRADES",
    "loss_trades": "$LOSS_TRADES",
    "report": "$REPORT_FILE",
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
import json, sys, re

def to_num(v):
    if v in (None, "", "n/a"): return None
    try: return float(str(v).split()[0].replace(',', '.'))
    except: return None

def delta(new, old, key, fmt=".2f", pct=False, invert=False):
    """invert=True means lower is better (e.g. drawdown)"""
    n = to_num(new.get(key))
    o = to_num(old.get(key))
    if n is None or o is None:
        nv = new.get(key, "n/a"); ov = old.get(key, "n/a")
        print(f"  \033[33m─\033[0m  {key:<22} {ov} → {nv}")
        return
    d = n - o
    good = (d < 0) if invert else (d > 0)
    arrow = "▲" if d > 0 else ("▼" if d < 0 else "─")
    color = "\033[32m" if good else ("\033[31m" if d != 0 else "\033[33m")
    reset = "\033[0m"
    pct_str = f" ({100*d/o:+.1f}%)" if pct and o != 0 else ""
    print(f"  {color}{arrow}{reset}  {key:<22} {o:{fmt}} → {n:{fmt}}{color}{pct_str}{reset}")

with open(sys.argv[1]) as f:
    new = json.load(f)
with open(sys.argv[2]) as f:
    old = json.load(f)

delta(new, old, "balance",        ".2f", pct=True)
delta(new, old, "ontester",       ".0f", pct=True)
delta(new, old, "profit_factor",  ".2f")
delta(new, old, "sharpe",         ".2f")
delta(new, old, "max_dd_pct",     ".2f", invert=True)
delta(new, old, "recovery_factor",".2f")
delta(new, old, "traded",         ".0f", pct=True)
delta(new, old, "overdue",        ".0f")
delta(new, old, "mitigated",      ".0f")
delta(new, old, "no_mss",         ".0f")
delta(new, old, "wall_time_s",    ".0f")
PYEOF
else
  yellow ""
  yellow "  No baseline yet. Run with --baseline to save current results as baseline."
fi

bold ""
echo "  Full results: $LAST_JSON"
