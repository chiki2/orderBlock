#!/usr/bin/env python3
"""
parse_opt_binary.py — Parse MT5 strategy tester optimization cache (.opt)

MT5 does NOT write XML in headless mode; it writes a binary .opt cache file
in Tester/cache/. This script reverse-engineers that format to extract:
  - Pass number
  - Sharpe ratio, Profit Factor, balance, drawdown
  - Parameter values for each pass
Then patches BEST_SET with the winning parameter values.

Usage:
    python3 parse_opt_binary.py opt_kz.opt --round kz --min-trades 3 --top 5
    python3 parse_opt_binary.py opt_kz.opt --patch-set XAUUSD_best.set
"""

import sys, struct, codecs, argparse, re, os
from pathlib import Path

# ── .opt file structure (reverse-engineered from MetaTrader 5 build 5663) ──
# Header: 512 bytes (version, copyright, product name, padding)
# Then: variable-length metadata (EA path, symbol, etc.)
# Then: records — each optimization pass is one record
#
# Record layout (approximate, 176 bytes per pass):
#   +0  : uint32  ff ff ff ff  (record marker)
#   +4  : uint32  pass_number
#   +8  : double  optimization criterion value (Sharpe when criterion=5)
#   +16 : double  profit
#   +24 : double  profit_factor
#   +32 : double  expected_payoff
#   +40 : double  equity_dd_pct
#   +48 : double  recovery_factor
#   +56 : double  sharpe_ratio
#   +64 : uint64  trades_count
#   +72 : double  win_pct
#   +80 : ... parameter section (UTF-16 name / value pairs)
#
# Note: this layout is INFERRED from file analysis. Offsets may shift
# between MT5 builds. We use heuristic validation (value range checks).

RECORD_MARKER = b'\xff\xff\xff\xff'
RECORD_SIZE   = 176  # bytes per pass record (empirically observed)


def read_file(path: str) -> bytes:
    with open(path, 'rb') as f:
        return f.read()


def find_records(data: bytes):
    """Find all pass records by locating the 0xFFFFFFFF markers."""
    records = []
    pos = 0
    while pos < len(data) - 4:
        idx = data.find(RECORD_MARKER, pos)
        if idx == -1:
            break
        # Quick sanity check: marker must be at a position that leaves
        # room for the full record
        if idx + RECORD_SIZE <= len(data):
            records.append(idx)
        pos = idx + RECORD_SIZE  # advance by one record
    return records


def parse_record(data: bytes, offset: int, pass_num_expected: int = None):
    """
    Parse one optimization pass record at `offset`.
    Returns a dict or None if the record looks invalid.
    """
    if offset + RECORD_SIZE > len(data):
        return None

    try:
        # Marker check
        marker = struct.unpack_from('<I', data, offset)[0]
        if marker != 0xFFFFFFFF:
            return None

        pass_num = struct.unpack_from('<I', data, offset + 4)[0]
        if pass_num > 100000:  # sanity: unlikely to have >100k passes
            return None

        # Read result doubles starting at offset+8
        # Layout based on analysis of real .opt files:
        crit_val      = struct.unpack_from('<d', data, offset + 8)[0]
        profit        = struct.unpack_from('<d', data, offset + 16)[0]
        profit_factor = struct.unpack_from('<d', data, offset + 24)[0]
        expected_pay  = struct.unpack_from('<d', data, offset + 32)[0]
        dd_pct        = struct.unpack_from('<d', data, offset + 40)[0]
        recovery      = struct.unpack_from('<d', data, offset + 48)[0]
        sharpe        = struct.unpack_from('<d', data, offset + 56)[0]
        trades_raw    = struct.unpack_from('<Q', data, offset + 64)[0]
        win_pct       = struct.unpack_from('<d', data, offset + 72)[0]

        # Sanity checks — skip obviously garbage records
        trades = int(trades_raw) if trades_raw < 100000 else 0
        if abs(profit) > 1e12:
            profit = 0.0
        if abs(profit_factor) > 1000 or profit_factor < 0:
            profit_factor = 0.0
        if abs(sharpe) > 1000:
            sharpe = 0.0
        if dd_pct < 0 or dd_pct > 100:
            dd_pct = 0.0

        # Parse parameter names/values from the text section (after offset+80)
        params = {}
        text_start = offset + 80
        text_end   = offset + RECORD_SIZE
        raw_text = data[text_start:text_end]

        # Try to decode as UTF-16-LE pairs
        try:
            text = raw_text.decode('utf-16-le', errors='ignore').rstrip('\x00')
            # Parameters are packed as name\x00value\x00name\x00value...
            parts = [p for p in text.split('\x00') if p.strip()]
            i = 0
            while i + 1 < len(parts):
                name = parts[i].strip()
                val  = parts[i+1].strip()
                if name and not name.startswith('\x00'):
                    params[name] = val
                i += 2
        except Exception:
            pass

        return {
            'pass':          pass_num,
            'criterion':     crit_val,
            'profit':        profit,
            'profit_factor': profit_factor,
            'expected_pay':  expected_pay,
            'dd_pct':        dd_pct,
            'recovery':      recovery,
            'sharpe':        sharpe,
            'trades':        trades,
            'win_pct':       win_pct,
            'params':        params,
        }
    except struct.error:
        return None


def load_opt_file(path: str):
    """Load and parse a .opt binary file. Returns list of pass dicts."""
    data = read_file(path)
    record_offsets = find_records(data)
    passes = []
    for off in record_offsets:
        rec = parse_record(data, off)
        if rec is not None:
            passes.append(rec)
    return passes


def patch_set_file(set_path: str, best_params: dict):
    """Patch the best parameter values into a UTF-16 .set file."""
    try:
        with codecs.open(set_path, 'r', 'utf-16') as f:
            content = f.read()
    except Exception:
        with open(set_path, errors='replace') as f:
            content = f.read()

    patched = 0
    for param, val in best_params.items():
        if not val or not param:
            continue
        pattern = re.compile(r'^(' + re.escape(param) + r'=)([^|]+)((\|\|[^\r\n]*)?)\r?$',
                             re.MULTILINE)
        if pattern.search(content):
            content = pattern.sub(lambda m: m.group(1) + str(val) + m.group(3), content)
            patched += 1

    with codecs.open(set_path, 'w', 'utf-16') as f:
        f.write(content)
    return patched


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('opt', help='Path to .opt binary file')
    ap.add_argument('--round',      default='opt',  help='Round name for output')
    ap.add_argument('--top',        type=int, default=5)
    ap.add_argument('--min-trades', type=int, default=3)
    ap.add_argument('--patch-set',  default=None, help='Set file to patch with best params')
    ap.add_argument('--criterion',  default='sharpe',
                    choices=['sharpe','pf','profit','trades'])
    args = ap.parse_args()

    if not os.path.exists(args.opt):
        print(f"ERROR: file not found: {args.opt}")
        sys.exit(1)

    passes = load_opt_file(args.opt)
    print(f"Passes found in .opt: {len(passes)}")

    if not passes:
        print("WARNING: no pass records could be parsed from the binary file.")
        print("         This may indicate a format change in this MT5 build.")
        print("         Displaying raw hex for debugging:")
        data = read_file(args.opt)
        for i in range(0, min(len(data), 512), 16):
            chunk = data[i:i+16]
            hex_s = ' '.join(f'{b:02x}' for b in chunk)
            asc_s = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
            print(f"  {i:4d}: {hex_s:<48}  {asc_s}")
        sys.exit(0)

    # Filter by minimum trades
    valid = [p for p in passes if p['trades'] >= args.min_trades]
    print(f"Passes with >= {args.min_trades} trades: {len(valid)}")

    sort_keys = {
        'sharpe':  lambda p: p['sharpe'],
        'pf':      lambda p: p['profit_factor'],
        'profit':  lambda p: p['profit'],
        'trades':  lambda p: p['trades'],
    }
    valid.sort(key=sort_keys[args.criterion], reverse=True)

    if not valid:
        print("No valid passes with sufficient trades.")
        print("\nAll passes (including 0-trade ones):")
        passes.sort(key=lambda p: p['sharpe'], reverse=True)
        for p in passes[:10]:
            print(f"  Pass {p['pass']:4d}: Sharpe={p['sharpe']:.4f}"
                  f"  PF={p['profit_factor']:.2f}  Trades={p['trades']}"
                  f"  Profit={p['profit']:.2f}")
        sys.exit(0)

    best = valid[0]

    print(f"\n{'='*68}")
    print(f" TOP {min(args.top, len(valid))} by {args.criterion.upper()} — Round: {args.round}")
    print(f"{'='*68}")

    for i, p in enumerate(valid[:args.top], 1):
        print(f"\n  #{i}  Sharpe={p['sharpe']:.4f}  PF={p['profit_factor']:.2f}"
              f"  Trades={p['trades']}  Win={p['win_pct']:.1f}%"
              f"  DD={p['dd_pct']:.2f}%  Profit={p['profit']:.2f}")
        if p['params']:
            for k, v in p['params'].items():
                print(f"       {k} = {v}")

    print(f"\n{'='*68}")
    print(f" BEST (#{1}): Sharpe={best['sharpe']:.4f}  PF={best['profit_factor']:.2f}"
          f"  Trades={best['trades']}  Profit={best['profit']:.2f}")
    print(f"{'='*68}")

    if args.patch_set and best['params']:
        n = patch_set_file(args.patch_set, best['params'])
        print(f"\n  Patched {n} params → {args.patch_set}")


if __name__ == '__main__':
    main()
