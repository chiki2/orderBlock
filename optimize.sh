#!/bin/bash
# optimize.sh — Multi-round MT5 parameter optimization for OrderBlock EA (XAUUSD)
#
# Strategy: 3 focused rounds, each optimizing a related group of parameters.
# Uses MT5 COMPLETE search (Optimization=1) for small ranges, Sharpe Ratio max.
# Model=4 real ticks (already cached — Model=1 requires download).
# Period: 2025-only for speed (~36s/pass), then verify 2022-2026.
#
# Fixed (pre-tested best values from user):
#   inpRiskProfile=1          (aggressive)
#   inpLowQualityTrades=true  (trade sub-quality OBs)
#   typeofOrder=2             (STOP orders)
#   inpEntryMode=0            (fibonacci entry)
#   inpKillZoneEnabled=true   (only detect in kill zone)
#   inpMSSRequireFVG=true     (FVG required on MSS candle)
#
# Rounds:
#   Round 1 (kz)       — Kill zone timing: 144 combos, ~20min
#   Round 2 (filters)  — Filters + SL mode + entry: 40 combos, ~6min
#   Round 3 (tp)       — TP + trailing: 72 combos, ~10min
#
# Usage:
#   bash optimize.sh all      # run all 3 rounds + verify
#   bash optimize.sh kz       # round 1 only
#   bash optimize.sh filters  # round 2 only (uses XAUUSD_best.set from round 1)
#   bash optimize.sh tp       # round 3 only
#   bash optimize.sh verify   # verify best params on 2022-2026
#   bash optimize.sh report   # print summary

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MT5_ROOT="/home/charles/.mt5"
MT5_DIR="$MT5_ROOT/drive_c/Program Files/MetaTrader 5"
MT5_EXE="$MT5_DIR/terminal64.exe"
WINEPREFIX="$MT5_ROOT"
WINE="$(which wine)"

SET_DIR="$SCRIPT_DIR/OBInclude/SetFiles"
BASE_SET="$SET_DIR/XAUUSD_claude2.set"
BEST_SET="$SET_DIR/XAUUSD_best.set"

OPT_SET_NAME="claude_opt.set"
OPT_SET_PRESETS="$MT5_DIR/MQL5/Profiles/Tester/$OPT_SET_NAME"
CONFIG_PATH="$MT5_ROOT/drive_c/MT5_optimize.ini"
CONFIG_WIN='C:\MT5_optimize.ini'

RESULTS_DIR="$SCRIPT_DIR/opt_results"
mkdir -p "$RESULTS_DIR"

# ── Parameters ─────────────────────────────────────────────────────────────
SYMBOL="${SYMBOL:-XAUUSD}"
PERIOD="${PERIOD:-M15}"
FROM_DATE="${FROM_DATE:-2025.01.01}"   # 2025-only: ~36s per pass, data cached
TO_DATE="${TO_DATE:-2026.01.01}"
DEPOSIT="${DEPOSIT:-10000}"
LEVERAGE="${LEVERAGE:-500}"
MODEL="${MODEL:-4}"                     # Real ticks — CACHED locally, always works
OPT_ALGO="${OPT_ALGO:-1}"              # 1=complete (all combos), 2=fast genetic
MIN_TRADES="${MIN_TRADES:-3}"

ROUND="${1:-all}"

# ── Helpers ────────────────────────────────────────────────────────────────
red()    { echo -e "\033[31m$*\033[0m"; }
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

# Patch specific param values in a UTF-16 set file
# Args: set_file_path param=value [param=value ...]
patch_set() {
  local SET_FILE="$1"
  shift
  python3 - "$SET_FILE" "$@" << 'PYEOF'
import sys, codecs, re
path = sys.argv[1]
overrides = {}
for arg in sys.argv[2:]:
    k, v = arg.split('=', 1)
    overrides[k.strip()] = v.strip()

try:
    with codecs.open(path, 'r', 'utf-16') as f:
        content = f.read()
except Exception:
    with open(path, errors='replace') as f:
        content = f.read()

for param, val in overrides.items():
    pattern = re.compile(r'^(' + re.escape(param) + r'=)([^|]+)((\|\|[^\r\n]*)?)\r?$', re.MULTILINE)
    if pattern.search(content):
        content = pattern.sub(lambda m: m.group(1) + val + m.group(3), content)
    else:
        print(f"  [WARN] param not found: {param}", file=sys.stderr)

with codecs.open(path, 'w', 'utf-16') as f:
    f.write(content)
PYEOF
}

# Set optimization flags: all N first, then enable listed params with new ranges
setup_opt_params() {
  local SET_FILE="$1"
  shift  # remaining args: "PARAM=value||min||step||max||Y" ...
  python3 - "$SET_FILE" "$@" << 'PYEOF'
import sys, codecs, re
path = sys.argv[1]
params = {}
for arg in sys.argv[2:]:
    k, v = arg.split('=', 1)
    params[k.strip()] = v.strip()

with codecs.open(path, 'r', 'utf-16') as f:
    content = f.read()

# Freeze all params (handle CRLF)
content = re.sub(r'\|\|[YF]\r?$', '||N', content, flags=re.MULTILINE)

# Apply optimization ranges
for param, val in params.items():
    pattern = re.compile(r'^(' + re.escape(param) + r'=)([^\r\n]+)', re.MULTILINE)
    if pattern.search(content):
        content = pattern.sub(lambda m: m.group(1) + val, content)
    else:
        print(f"  [WARN] param not in set file: {param}", file=sys.stderr)

with codecs.open(path, 'w', 'utf-16') as f:
    f.write(content)
PYEOF
}

# Parse optimization results from the binary .opt cache file
# Extract top results by Sharpe ratio
parse_opt_results() {
  local OPT_FILE="$1"
  local ROUND_NAME="$2"
  python3 "$SCRIPT_DIR/parse_opt_binary.py" "$OPT_FILE" \
    --round "$ROUND_NAME" \
    --min-trades "$MIN_TRADES" \
    --top 5 \
    | tee "$RESULTS_DIR/best_${ROUND_NAME}.txt"
}

# Find the most recent .opt file for this symbol/period combination
find_opt_file() {
  local FROM="$1"
  local TO="$2"
  # Convert from YYYY.MM.DD to YYYYMMDD
  local FROM_CLEAN=$(echo "$FROM" | tr -d '.')
  local TO_CLEAN=$(echo "$TO" | tr -d '.')
  # Look for opt file matching our symbol and dates
  find "$MT5_DIR/Tester/cache" -name "OrderBlock.${SYMBOL}.${PERIOD}.${FROM_CLEAN}.${TO_CLEAN}.*.opt" \
    -newer "$BEST_SET" 2>/dev/null | sort -t. -k7 | tail -1
}

# Wait for optimization to complete and find results
run_optimization() {
  local ROUND_NAME="$1"
  local NUM_COMBOS="$2"
  local EST_MINUTES="$3"

  bold ""
  bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bold " Round: $ROUND_NAME ($NUM_COMBOS combinations, ~${EST_MINUTES}min)"
  bold " Symbol=$SYMBOL  Period=$PERIOD  Model=$MODEL"
  bold " Range: $FROM_DATE → $TO_DATE"
  bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  cp "$BEST_SET" "$OPT_SET_PRESETS"

  # Record timestamp for finding the new opt file
  local TIMESTAMP_FILE=$(mktemp)
  touch "$TIMESTAMP_FILE"

  cat > "$CONFIG_PATH" << EOF
[Tester]
Expert=orderBlock\OrderBlock
ExpertParameters=$OPT_SET_NAME
Symbol=$SYMBOL
Period=$PERIOD
Model=$MODEL
Optimization=$OPT_ALGO
OptimizationCriterion=5
FromDate=$FROM_DATE
ToDate=$TO_DATE
Deposit=$DEPOSIT
Leverage=1:$LEVERAGE
Currency=USD
Report=opt_${ROUND_NAME}
ReplaceReport=1
ShutdownTerminal=1
EOF

  pkill -f "terminal64" 2>/dev/null || true
  sleep 3

  START_TIME=$(date +%s)
  TODAY=$(date +%Y%m%d)

  WINEPREFIX="$WINEPREFIX" "$WINE" "$MT5_EXE" /portable "/config:$CONFIG_WIN" \
    > /tmp/mt5_opt_${ROUND_NAME}.log 2>&1 &
  MT5_PID=$!
  echo "  MT5 launched (pid $MT5_PID)..."

  while kill -0 "$MT5_PID" 2>/dev/null; do
    ELAPSED=$(( $(date +%s) - START_TIME ))
    # Show progress from agent logs
    PROGRESS=$(find "$MT5_DIR/Tester" -name "${TODAY}.log" -path "*/Agent-127*" 2>/dev/null \
      | xargs -I{} python3 -c "import codecs; lines=codecs.open('{}','r','utf-16').readlines(); [print(l.rstrip()[-60:]) for l in lines[-1:] if 'passes' in l]" 2>/dev/null | head -1 || echo "")
    if [[ -n "$PROGRESS" ]]; then
      printf "  %ds: %s\r" "$ELAPSED" "$PROGRESS"
    else
      printf "  ... %ds elapsed\r" "$ELAPSED"
    fi
    sleep 10
  done
  wait "$MT5_PID" 2>/dev/null || true
  sleep 2

  WALL_TIME=$(( $(date +%s) - START_TIME ))
  echo ""
  echo "  Finished in ${WALL_TIME}s"

  # Find the new .opt file
  local OPT_FILE=$(find "$MT5_DIR/Tester/cache" \
    -name "OrderBlock.${SYMBOL}.${PERIOD}.*.opt" \
    -newer "$TIMESTAMP_FILE" 2>/dev/null | sort -n | tail -1)

  rm -f "$TIMESTAMP_FILE"

  if [[ -n "$OPT_FILE" ]]; then
    green "  Opt cache found: $(basename $OPT_FILE)"
    cp "$OPT_FILE" "$RESULTS_DIR/opt_${ROUND_NAME}.opt"
  else
    # Fallback: find most recent opt file for XAUUSD
    OPT_FILE=$(ls -t "$MT5_DIR/Tester/cache/OrderBlock.${SYMBOL}.${PERIOD}".*.opt 2>/dev/null | head -1)
    if [[ -n "$OPT_FILE" ]]; then
      yellow "  Using most recent opt: $(basename $OPT_FILE)"
      cp "$OPT_FILE" "$RESULTS_DIR/opt_${ROUND_NAME}.opt"
    else
      yellow "  WARNING: No .opt file found"
    fi
  fi

  # Also check for HTML report
  local HTM_FILE="$MT5_DIR/opt_${ROUND_NAME}.htm"
  if [[ -f "$HTM_FILE" ]]; then
    cp "$HTM_FILE" "$RESULTS_DIR/opt_${ROUND_NAME}.htm"
    green "  HTML report: opt_${ROUND_NAME}.htm"
  fi
}

# Parse agent log and patch BEST_SET with best params for a round
# Args: ROUND_NAME PARAM_SPEC [PARAM_SPEC ...]
# PARAM_SPEC format: "name=min:step:max"
extract_and_patch() {
  local ROUND_NAME="$1"
  shift
  local PARAM_SPECS=("$@")   # remaining args are param range specs

  echo ""
  bold "  Extracting best params from round: $ROUND_NAME"

  # Merge all agent logs for today into a single file (agents distribute passes)
  local TODAY
  TODAY=$(date +%Y%m%d)
  local MERGED_LOG="/tmp/mt5_merged_${ROUND_NAME}.log"
  find "$MT5_DIR/Tester" -name "${TODAY}.log" -path "*/Agent-127*" 2>/dev/null \
    | sort | xargs -I{} sh -c 'python3 -c "import codecs; f=codecs.open(\"$0\",\"r\",\"utf-16\"); print(f.read())" "$0"' \
    > "$MERGED_LOG" 2>/dev/null || true

  if [[ ! -s "$MERGED_LOG" ]]; then
    yellow "  WARNING: No agent logs found — cannot extract params"
    return
  fi

  python3 "$SCRIPT_DIR/parse_agent_log.py" \
    --log "$MERGED_LOG" \
    --round "$ROUND_NAME" \
    --top 5 \
    --params "${PARAM_SPECS[@]}" \
    --patch-set "$BEST_SET" \
    | tee "$RESULTS_DIR/best_${ROUND_NAME}.txt"
}

# ── Initialize best set from base ─────────────────────────────────────────
init_best_set() {
  cp "$BASE_SET" "$BEST_SET"
  patch_set "$BEST_SET" "inpDataCollectionMode=false"
  patch_set "$BEST_SET" \
    "inpRiskProfile=1" \
    "inpLowQualityTrades=true" \
    "typeofOrder=2" \
    "inpEntryMode=0" \
    "inpKillZoneEnabled=true" \
    "inpMSSRequireFVG=true"
  green "  Initialized $BEST_SET from base"
}

# ── Round setups ──────────────────────────────────────────────────────────

setup_round_kz() {
  # Kill zone timing — 3×4×3×4 = 144 combinations
  setup_opt_params "$BEST_SET" \
    "inpKZ1Start=7||6||1||8||Y" \
    "inpKZ1End=10||9||1||12||Y" \
    "inpKZ2Start=12||12||1||14||Y" \
    "inpKZ2End=16||15||1||18||Y"
  echo "  Round KZ: 3×4×3×4 = 144 combinations"
}

setup_round_filters() {
  # Market structure + SL mode + entry fib — 2×4×5 = 40 combinations
  setup_opt_params "$BEST_SET" \
    "inpRequireD1Trend=true||false||0||true||Y" \
    "StopLossStartMode=0||0||1||3||Y" \
    "fiboEntry=0.65||0.55||0.05||0.75||Y"
  echo "  Round FILTERS: 2×4×5 = 40 combinations"
}

setup_round_tp() {
  # TP levels + trailing — 9×2×4 = 72 combinations
  setup_opt_params "$BEST_SET" \
    "fibo1rstTP=1.27||1.0||0.1||1.8||Y" \
    "enableTrailingStop=true||false||0||true||Y" \
    "trailingStopPoints=800||600||200||1200||Y"
  echo "  Round TP: 9×2×4 = 72 combinations"
}

# ── Verify best params with 2022-2026 real ticks ──────────────────────────
run_verify() {
  bold ""
  bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  bold " VERIFICATION: best params on 2022-2026 (Model=4)"
  bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Build final set file with data collection re-enabled
  cp "$BEST_SET" "$SET_DIR/XAUUSD_optimized.set"
  patch_set "$SET_DIR/XAUUSD_optimized.set" "inpDataCollectionMode=true"

  echo "  Copying XAUUSD_optimized.set → claude.set for verify run"
  cp "$SET_DIR/XAUUSD_optimized.set" "$SET_DIR/claude.set"

  FROM_DATE=2022.01.01 TO_DATE=2026.01.01 MODEL=4 \
    bash "$SCRIPT_DIR/backtest.sh" 2>&1 | tee "$RESULTS_DIR/verify_result.txt"
}

# ── Print final report ────────────────────────────────────────────────────
print_report() {
  echo ""
  bold "═══════════════════════════════════════════════"
  bold " OPTIMIZATION REPORT — OrderBlock EA XAUUSD"
  bold "═══════════════════════════════════════════════"
  for round in kz filters tp; do
    local BEST_FILE="$RESULTS_DIR/best_${round}.txt"
    if [[ -f "$BEST_FILE" ]]; then
      echo ""
      bold "  Round: $round"
      cat "$BEST_FILE"
    fi
  done
  if [[ -f "$RESULTS_DIR/verify_result.txt" ]]; then
    echo ""
    bold "  Verification (Model=4, 2022-2026):"
    grep -E "balance|profit_factor|sharpe|traded|max_dd" \
      "$RESULTS_DIR/verify_result.txt" 2>/dev/null | head -10 || true
  fi
}

# ── Main ──────────────────────────────────────────────────────────────────
case "$ROUND" in
  all)
    bold "Starting 3-round optimization for XAUUSD..."
    init_best_set

    bold "--- Round 1/3: Kill Zone timing ---"
    setup_round_kz
    run_optimization "kz" 144 20
    extract_and_patch "kz" \
      "inpKZ1Start=6:1:8" "inpKZ1End=9:1:12" \
      "inpKZ2Start=12:1:14" "inpKZ2End=15:1:18"

    bold "--- Round 2/3: Filters + SL mode + Entry ---"
    setup_round_filters
    run_optimization "filters" 40 6
    extract_and_patch "filters" \
      "inpRequireD1Trend=false:0:true" \
      "StopLossStartMode=0:1:3" \
      "fiboEntry=0.55:0.05:0.75"

    bold "--- Round 3/3: TP + Trailing ---"
    setup_round_tp
    run_optimization "tp" 72 10
    extract_and_patch "tp" \
      "fibo1rstTP=1.0:0.1:1.8" \
      "enableTrailingStop=false:0:true" \
      "trailingStopPoints=600:200:1200"

    bold "--- Verification: 2022-2026 full period ---"
    run_verify
    print_report
    ;;

  kz)
    [[ -f "$BEST_SET" ]] || init_best_set
    setup_round_kz
    run_optimization "kz" 144 20
    extract_and_patch "kz" \
      "inpKZ1Start=6:1:8" "inpKZ1End=9:1:12" \
      "inpKZ2Start=12:1:14" "inpKZ2End=15:1:18"
    ;;

  filters)
    [[ -f "$BEST_SET" ]] || init_best_set
    setup_round_filters
    run_optimization "filters" 40 6
    extract_and_patch "filters" \
      "inpRequireD1Trend=false:0:true" \
      "StopLossStartMode=0:1:3" \
      "fiboEntry=0.55:0.05:0.75"
    ;;

  tp)
    [[ -f "$BEST_SET" ]] || init_best_set
    setup_round_tp
    run_optimization "tp" 72 10
    extract_and_patch "tp" \
      "fibo1rstTP=1.0:0.1:1.8" \
      "enableTrailingStop=false:0:true" \
      "trailingStopPoints=600:200:1200"
    ;;

  verify)
    [[ -f "$BEST_SET" ]] || { red "No best.set found — run rounds first"; exit 1; }
    run_verify
    ;;

  report)
    print_report
    ;;

  init)
    init_best_set
    ;;

  *)
    echo "Usage: $0 [all|kz|filters|tp|verify|report|init]"
    exit 1
    ;;
esac

echo ""
green "Done."
