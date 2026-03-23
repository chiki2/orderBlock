#!/usr/bin/env python3
"""
MT5 Tester Agent Log Scanner.
Extracts diagnostics from the most recent backtest log:
  - Order cancellations (EA-side via hasOppositeOB)
  - Order expirations (MT5 outdatedOB timer)
  - "Not enough money" errors
  - Other errors (excluding harmless permission/email ones)
  - Opposite OB detections

Usage as module:
    from scripts.scan_tester_log import scan_last_backtest
    diag = scan_last_backtest()
    print(diag["summary"])     # one-line summary
    print(diag["details"])     # multi-line breakdown

Usage standalone:
    python3 scripts/scan_tester_log.py
"""
import codecs, os, glob
from datetime import datetime
from collections import Counter

LOG_DIR = os.path.join(
    os.environ.get("MT5_ROOT",
        "/home/charles/.mt5/drive_c/Program Files/MetaTrader 5"),
    "Tester", "Agent-127.0.0.1-3000", "logs"
)


def _today_log():
    """Return path to today's agent log."""
    today = datetime.now().strftime("%Y%m%d")
    return os.path.join(LOG_DIR, f"{today}.log")


def _latest_log():
    """Return path to most recent agent log."""
    logs = sorted(glob.glob(os.path.join(LOG_DIR, "*.log")), reverse=True)
    return logs[0] if logs else None


def clear_log():
    """Delete today's agent log so the next scan only sees the current test."""
    path = _today_log()
    if os.path.exists(path):
        os.remove(path)


def _read_log(path, since_line=0):
    """Read UTF-16 agent log, return lines from since_line onwards."""
    with codecs.open(path, "r", "utf-16") as f:
        lines = f.readlines()
    return lines[since_line:]


def scan_lines(lines):
    """Scan log lines and return diagnostic counters + sample lines."""
    counts = Counter()
    samples = {
        "order_canceled": [],
        "order_expired": [],
        "not_enough_money": [],
        "opposite_ob": [],
        "other_error": [],
    }
    MAX_SAMPLES = 5

    for line in lines:
        low = line.lower()

        # Order canceled (EA-side: hasOppositeOB or explicit cancel)
        if "order canceled" in low or "orderdelete" in low.replace(" ", ""):
            counts["order_canceled"] += 1
            if len(samples["order_canceled"]) < MAX_SAMPLES:
                samples["order_canceled"].append(line.strip()[:150])

        # Order expired (MT5 outdatedOB timer)
        elif "order expired" in low:
            counts["order_expired"] += 1
            if len(samples["order_expired"]) < MAX_SAMPLES:
                samples["order_expired"].append(line.strip()[:150])

        # Not enough money
        elif "not enough money" in low:
            counts["not_enough_money"] += 1
            if len(samples["not_enough_money"]) < MAX_SAMPLES:
                samples["not_enough_money"].append(line.strip()[:150])

        # Opposite OB detection
        elif "opposite orderblock" in low:
            counts["opposite_ob"] += 1
            if len(samples["opposite_ob"]) < MAX_SAMPLES:
                samples["opposite_ob"].append(line.strip()[:150])

        # Real errors (skip harmless permission/screenshot/email ones)
        elif ("error" in low
              and "permission" not in low
              and "cancel" not in low
              and "screenshot" not in low
              and "4202" not in low
              and "4014" not in low):
            counts["other_error"] += 1
            if len(samples["other_error"]) < MAX_SAMPLES:
                samples["other_error"].append(line.strip()[:150])

    return counts, samples


def scan_last_backtest(since_line=0):
    """
    Scan the most recent agent log and return a diagnostic dict.

    Returns:
        dict with keys:
            log_path: str
            total_lines: int
            counts: Counter  {order_canceled, order_expired, not_enough_money, opposite_ob, other_error}
            samples: dict    {category: [sample_lines]}
            summary: str     one-line summary
            details: str     multi-line breakdown
            has_issues: bool True if any non-zero diagnostic count
    """
    path = _latest_log()
    if not path:
        return {
            "log_path": None, "total_lines": 0,
            "counts": Counter(), "samples": {},
            "summary": "No agent log found",
            "details": "No agent log found",
            "has_issues": False,
        }

    lines = _read_log(path, since_line)
    counts, samples = scan_lines(lines)

    # Build summary
    parts = []
    if counts["order_canceled"]:
        parts.append(f"{counts['order_canceled']} cancelled")
    if counts["order_expired"]:
        parts.append(f"{counts['order_expired']} expired")
    if counts["not_enough_money"]:
        parts.append(f"{counts['not_enough_money']} margin errors")
    if counts["opposite_ob"]:
        parts.append(f"{counts['opposite_ob']} opposite-OB")
    if counts["other_error"]:
        parts.append(f"{counts['other_error']} errors")

    summary = " | ".join(parts) if parts else "clean"

    # Build details
    detail_lines = [f"Log: {os.path.basename(path)} ({len(lines)} lines scanned)"]
    for cat, label in [
        ("order_canceled", "Order Cancelled"),
        ("order_expired", "Order Expired"),
        ("not_enough_money", "Not Enough Money"),
        ("opposite_ob", "Opposite OB Detected"),
        ("other_error", "Other Errors"),
    ]:
        if counts[cat]:
            detail_lines.append(f"\n  {label}: {counts[cat]}")
            for s in samples[cat]:
                detail_lines.append(f"    → {s}")

    details = "\n".join(detail_lines)

    return {
        "log_path": path,
        "total_lines": len(lines),
        "counts": counts,
        "samples": samples,
        "summary": summary,
        "details": details,
        "has_issues": any(counts.values()),
    }


def format_oneliner(diag):
    """Format diagnostic as a compact one-liner for sweep output."""
    if not diag["has_issues"]:
        return "  📋 Log: clean"
    return f"  📋 Log: {diag['summary']}"


if __name__ == "__main__":
    diag = scan_last_backtest()
    print(diag["details"])
