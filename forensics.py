#!/usr/bin/env python3
"""
forensics.py — Trade Forensics Tool for OrderBlock EA

Runs the full pipeline: backtest → dataset → loss analysis → HTML report.
Analyzes losing trades to find patterns, cluster failure modes, and recommend filters.

Usage:
    python3 forensics.py                              # full pipeline on XAUUSD
    python3 forensics.py --symbol EURUSD              # override symbol
    python3 forensics.py --from-date 2024.01.01       # custom date range
    python3 forensics.py --skip-backtest              # analyze existing data only
    python3 forensics.py --no-html                    # terminal only
"""

import argparse, csv, io, math, os, subprocess, sys, base64, textwrap
from pathlib import Path
from collections import defaultdict, Counter

# ── paths ────────────────────────────────────────────────────────────────────
SCRIPT_DIR = Path(__file__).resolve().parent
BACKTEST_SH = SCRIPT_DIR / "backtest.sh"
BUILD_DATASET = SCRIPT_DIR / "build_dataset.py"
VENV_PYTHON = SCRIPT_DIR / "analytics" / ".venv" / "bin" / "python3"
DATASET_ALL = SCRIPT_DIR / "ob_dataset.csv"
DATASET_TRADED = SCRIPT_DIR / "ob_dataset_traded.csv"
HTML_OUT = SCRIPT_DIR / "forensics_report.html"

# Use venv python if available, else system
PYTHON = str(VENV_PYTHON) if VENV_PYTHON.exists() else sys.executable

# ── ANSI helpers ─────────────────────────────────────────────────────────────
def red(s):    return f"\033[31m{s}\033[0m"
def green(s):  return f"\033[32m{s}\033[0m"
def yellow(s): return f"\033[33m{s}\033[0m"
def bold(s):   return f"\033[1m{s}\033[0m"
def cyan(s):   return f"\033[36m{s}\033[0m"
def dim(s):    return f"\033[2m{s}\033[0m"

def hline(ch="─", width=72):
    print(ch * width)

# ── data loading ─────────────────────────────────────────────────────────────
def safe_float(v, default=0.0):
    try:
        f = float(v)
        return default if (math.isnan(f) or math.isinf(f) or abs(f) > 1e15) else f
    except (ValueError, TypeError):
        return default

def load_traded_dataset(path):
    """Load ob_dataset_traded.csv into list of dicts with numeric conversion."""
    records = []
    with open(path, newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            rec = {}
            for k, v in row.items():
                rec[k] = safe_float(v, v)  # try numeric, fallback to string
            records.append(rec)
    return records

# ── features used for analysis ───────────────────────────────────────────────
ANALYSIS_FEATS = [
    "is_bear", "htf_trend", "stars", "ob_body_pct", "ob_range_pts",
    "ob_body", "ob_wick", "is_mss", "is_bos", "has_choch",
    "is_imbalanced", "lssc_valid", "has_sweep_before",
    "top_imp_valid", "is_lower_mss", "all_checks", "final_check",
    "atr", "spread", "htf_bull", "htf_bear", "align_with_trend",
    "sl_dist_pts", "tp_dist_pts", "rr_ratio",
    "hour_utc", "day_of_week", "month",
]

BINARY_FEATS = {
    "is_bear", "is_mss", "is_bos", "has_choch", "is_imbalanced",
    "lssc_valid", "has_sweep_before", "top_imp_valid", "is_lower_mss",
    "all_checks", "final_check", "htf_bull", "htf_bear", "align_with_trend",
}

SESSION_MAP = {
    range(0, 8):   "Asian",
    range(8, 12):  "London",
    range(12, 17): "New York",
    range(17, 21): "Late NY",
    range(21, 24): "Asian",
}

def get_session(hour):
    for rng, name in SESSION_MAP.items():
        if int(hour) in rng:
            return name
    return "Unknown"

def feat_vec(rec, feats=ANALYSIS_FEATS):
    return [float(rec.get(f, 0)) for f in feats]

# ══════════════════════════════════════════════════════════════════════════════
#  Module A: Win vs Loss Statistical Comparison
# ══════════════════════════════════════════════════════════════════════════════
def module_a(wins, losses, all_records):
    from scipy.stats import mannwhitneyu
    print(f"\n{bold('═══ Module A: Win vs Loss Feature Comparison ═══')}")
    results = []
    for f in ANALYSIS_FEATS:
        w_vals = [float(r.get(f, 0)) for r in wins]
        l_vals = [float(r.get(f, 0)) for r in losses]
        if len(set(w_vals)) <= 1 and len(set(l_vals)) <= 1:
            continue
        try:
            stat, p = mannwhitneyu(w_vals, l_vals, alternative="two-sided")
        except ValueError:
            continue
        w_mean = sum(w_vals) / len(w_vals) if w_vals else 0
        l_mean = sum(l_vals) / len(l_vals) if l_vals else 0
        results.append((f, p, w_mean, l_mean, w_mean - l_mean))

    results.sort(key=lambda x: x[1])
    sig = [r for r in results if r[1] < 0.05]

    if sig:
        print(f"\n  {len(sig)} features with significant differences (p < 0.05):\n")
        print(f"  {'Feature':<25} {'p-value':>10} {'Win mean':>10} {'Loss mean':>10} {'Delta':>10}")
        print(f"  {'─'*25} {'─'*10} {'─'*10} {'─'*10} {'─'*10}")
        for name, p, wm, lm, delta in sig[:15]:
            color = green if delta > 0 else red
            print(f"  {name:<25} {p:>10.4f} {wm:>10.2f} {lm:>10.2f} {color(f'{delta:>+10.2f}')}")
    else:
        print(f"  {yellow('No statistically significant differences found.')}")

    return results

# ══════════════════════════════════════════════════════════════════════════════
#  Module B: Loss Cluster Analysis
# ══════════════════════════════════════════════════════════════════════════════
def module_b(losses):
    import numpy as np
    from sklearn.preprocessing import StandardScaler
    from sklearn.cluster import KMeans
    from sklearn.metrics import silhouette_score

    print(f"\n{bold('═══ Module B: Loss Cluster Analysis ═══')}")

    if len(losses) < 6:
        print(f"  {yellow('Too few losses for clustering (need >= 6)')}")
        return None

    X = np.array([feat_vec(r) for r in losses])
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    # Find optimal k (2-5)
    best_k, best_score = 2, -1
    for k in range(2, min(6, len(losses))):
        km = KMeans(n_clusters=k, n_init=10, random_state=42)
        labels = km.fit_predict(X_scaled)
        if len(set(labels)) < 2:
            continue
        score = silhouette_score(X_scaled, labels)
        if score > best_score:
            best_k, best_score = k, score

    km = KMeans(n_clusters=best_k, n_init=10, random_state=42)
    labels = km.fit_predict(X_scaled)

    print(f"\n  Found {bold(str(best_k))} loss archetypes (silhouette: {best_score:.3f})\n")

    cluster_info = []
    for c in range(best_k):
        members = [losses[i] for i in range(len(losses)) if labels[i] == c]
        if not members:
            continue

        # Find distinguishing features (compare cluster mean vs overall loss mean)
        traits = []
        for j, f in enumerate(ANALYSIS_FEATS):
            c_mean = np.mean([float(m.get(f, 0)) for m in members])
            o_mean = np.mean(X[:, j])
            o_std = np.std(X[:, j]) or 1.0
            z = (c_mean - o_mean) / o_std
            if abs(z) > 0.5:
                traits.append((f, c_mean, z))
        traits.sort(key=lambda x: -abs(x[2]))

        # Auto-label
        top_traits = traits[:3]
        trait_strs = []
        for fname, fmean, z in top_traits:
            direction = "high" if z > 0 else "low"
            trait_strs.append(f"{direction} {fname}")
        archetype = " / ".join(trait_strs) if trait_strs else "generic"

        # Session distribution
        sessions = Counter(get_session(m.get("hour_utc", 0)) for m in members)
        top_session = sessions.most_common(1)[0] if sessions else ("?", 0)

        avg_r = sum(float(m.get("r_multiple", 0)) for m in members) / len(members)

        print(f"  {bold(f'Cluster {c+1}')} ({len(members)} trades, avg R: {avg_r:.2f})")
        print(f"    Archetype: {cyan(archetype)}")
        print(f"    Top session: {top_session[0]} ({top_session[1]}/{len(members)})")
        for fname, fmean, z in top_traits[:5]:
            bar = "+" * min(int(abs(z) * 3), 15) if z > 0 else "-" * min(int(abs(z) * 3), 15)
            print(f"    {fname:<25} mean={fmean:>8.2f}  z={z:>+5.2f} {bar}")
        print()

        cluster_info.append({
            "id": c, "size": len(members), "archetype": archetype,
            "traits": top_traits, "avg_r": avg_r, "top_session": top_session[0],
            "labels": labels,
        })

    return {"k": best_k, "labels": labels, "clusters": cluster_info, "X_scaled": X_scaled}

# ══════════════════════════════════════════════════════════════════════════════
#  Module C: SHAP Explanations
# ══════════════════════════════════════════════════════════════════════════════
def module_c(wins, losses, all_records):
    import numpy as np

    print(f"\n{bold('═══ Module C: SHAP Loss Explanations ═══')}")

    X = np.array([feat_vec(r) for r in all_records])
    y = np.array([1 if r.get("outcome") == "WIN" else 0 for r in all_records])

    if len(set(y)) < 2:
        print(f"  {yellow('Need both WIN and LOSS samples for SHAP')}")
        return None

    from sklearn.ensemble import RandomForestClassifier
    clf = RandomForestClassifier(
        n_estimators=200, max_depth=10, class_weight="balanced",
        random_state=42, n_jobs=-1,
    )
    clf.fit(X, y)

    # SHAP
    try:
        import shap
        explainer = shap.TreeExplainer(clf)
        loss_idx = [i for i, r in enumerate(all_records) if r.get("outcome") == "LOSS"]
        X_losses = X[loss_idx]

        shap_values = explainer.shap_values(X_losses)
        # Handle different SHAP output shapes
        if isinstance(shap_values, list):
            sv = shap_values[1]  # list of [class0, class1]
        elif hasattr(shap_values, 'ndim') and shap_values.ndim == 3:
            sv = shap_values[:, :, 1]  # 3D array: (samples, features, classes)
        else:
            sv = shap_values

        # Aggregate: mean |SHAP| per feature across all losses
        mean_abs_shap = np.mean(np.abs(sv), axis=0)
        feat_importance = sorted(
            zip(ANALYSIS_FEATS, mean_abs_shap),
            key=lambda x: -x[1]
        )

        print(f"\n  Top loss drivers (mean |SHAP| across {len(loss_idx)} losses):\n")
        print(f"  {'Feature':<25} {'Impact':>10}")
        print(f"  {'─'*25} {'─'*10}")
        for name, imp in feat_importance[:10]:
            bar = "█" * min(int(imp * 100), 30)
            print(f"  {name:<25} {imp:>10.4f}  {bar}")

        # Per-trade explanations for worst losses
        r_multiples = [float(all_records[i].get("r_multiple", 0)) for i in loss_idx]
        worst_idx = sorted(range(len(loss_idx)), key=lambda j: r_multiples[j])[:5]

        print(f"\n  {bold('Worst 5 losses — per-trade SHAP breakdown:')}\n")
        for rank, j in enumerate(worst_idx, 1):
            rec = all_records[loss_idx[j]]
            r_mult = float(rec.get("r_multiple", 0))
            ob_name = rec.get("ob_name", "?")
            # Top 3 features pushing this trade toward LOSS (negative SHAP = pushed away from WIN)
            trade_shap = sorted(
                zip(ANALYSIS_FEATS, sv[j]),
                key=lambda x: x[1]  # most negative = strongest loss driver
            )
            print(f"  #{rank} {dim(ob_name)} R={r_mult:.2f}")
            for fname, sval in trade_shap[:3]:
                val = float(rec.get(fname, 0))
                print(f"      {fname}={val:.1f} → SHAP {sval:+.4f}")
            print()

        return {"feat_importance": feat_importance, "shap_values": sv,
                "loss_idx": loss_idx, "X_losses": X_losses, "clf": clf}

    except Exception as e:
        print(f"  {red(f'SHAP failed: {e}')}")
        # Fallback to feature importance
        fi = sorted(zip(ANALYSIS_FEATS, clf.feature_importances_), key=lambda x: -x[1])
        print(f"\n  Fallback: RF Feature Importance (top 10):\n")
        for name, imp in fi[:10]:
            bar = "█" * int(imp * 50)
            print(f"  {name:<25} {imp:.4f}  {bar}")
        return {"feat_importance": fi, "shap_values": None}

# ══════════════════════════════════════════════════════════════════════════════
#  Module D: Temporal Patterns
# ══════════════════════════════════════════════════════════════════════════════
def module_d(wins, losses, all_records):
    print(f"\n{bold('═══ Module D: Temporal Patterns ═══')}")

    # Hour analysis
    hour_stats = defaultdict(lambda: {"win": 0, "loss": 0})
    dow_stats = defaultdict(lambda: {"win": 0, "loss": 0})
    session_stats = defaultdict(lambda: {"win": 0, "loss": 0})

    for r in all_records:
        h = int(float(r.get("hour_utc", 0)))
        d = int(float(r.get("day_of_week", 0)))
        outcome = r.get("outcome", "")
        session = get_session(h)

        if outcome == "WIN":
            hour_stats[h]["win"] += 1
            dow_stats[d]["win"] += 1
            session_stats[session]["win"] += 1
        elif outcome == "LOSS":
            hour_stats[h]["loss"] += 1
            dow_stats[d]["loss"] += 1
            session_stats[session]["loss"] += 1

    # Session summary
    print(f"\n  {'Session':<12} {'Wins':>6} {'Losses':>8} {'Total':>7} {'Win%':>7}")
    print(f"  {'─'*12} {'─'*6} {'─'*8} {'─'*7} {'─'*7}")
    for session in ["Asian", "London", "New York", "Late NY"]:
        s = session_stats[session]
        total = s["win"] + s["loss"]
        if total == 0:
            continue
        wr = s["win"] / total * 100
        color = green if wr >= 55 else (red if wr < 40 else yellow)
        print(f"  {session:<12} {s['win']:>6} {s['loss']:>8} {total:>7} {color(f'{wr:>6.1f}%')}")

    # Day of week
    DOW_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    print(f"\n  {'Day':<6} {'Wins':>6} {'Losses':>8} {'Total':>7} {'Win%':>7}")
    print(f"  {'─'*6} {'─'*6} {'─'*8} {'─'*7} {'─'*7}")
    for d in range(5):  # Mon-Fri
        s = dow_stats[d]
        total = s["win"] + s["loss"]
        if total == 0:
            continue
        wr = s["win"] / total * 100
        color = green if wr >= 55 else (red if wr < 40 else yellow)
        print(f"  {DOW_NAMES[d]:<6} {s['win']:>6} {s['loss']:>8} {total:>7} {color(f'{wr:>6.1f}%')}")

    # Death zones (hours with < 35% win rate and >= 3 trades)
    death_zones = []
    for h in range(24):
        s = hour_stats[h]
        total = s["win"] + s["loss"]
        if total >= 3:
            wr = s["win"] / total * 100
            if wr < 35:
                death_zones.append((h, wr, total, s["loss"]))

    if death_zones:
        print(f"\n  {red(bold('Death zones'))} (hours with <35% win rate, min 3 trades):")
        for h, wr, total, l in sorted(death_zones, key=lambda x: x[1]):
            print(f"    {h:02d}:00 UTC — {wr:.0f}% win rate ({l} losses / {total} trades)")

    # Build heatmap data for HTML
    heatmap = {}
    for h in range(24):
        for d in range(5):
            key = (h, d)
            w = sum(1 for r in wins if int(float(r.get("hour_utc", 0))) == h
                    and int(float(r.get("day_of_week", 0))) == d)
            l = sum(1 for r in losses if int(float(r.get("hour_utc", 0))) == h
                    and int(float(r.get("day_of_week", 0))) == d)
            heatmap[key] = (w, l)

    return {"hour_stats": dict(hour_stats), "dow_stats": dict(dow_stats),
            "session_stats": dict(session_stats), "death_zones": death_zones,
            "heatmap": heatmap}

# ══════════════════════════════════════════════════════════════════════════════
#  Module E: Market Regime Analysis
# ══════════════════════════════════════════════════════════════════════════════
def module_e(wins, losses, all_records):
    import numpy as np

    print(f"\n{bold('═══ Module E: Market Regime Analysis ═══')}")

    # HTF trend × direction cross-tab
    regimes = defaultdict(lambda: {"win": 0, "loss": 0})
    for r in all_records:
        htf = int(float(r.get("htf_trend", 0)))
        is_bear = int(float(r.get("is_bear", 0)))
        aligned = int(float(r.get("align_with_trend", 0)))
        outcome = r.get("outcome", "")

        htf_name = {1: "Bull", -1: "Bear", 0: "Range"}.get(htf, "?")
        dir_name = "Short" if is_bear else "Long"
        key = f"{htf_name} + {dir_name}"

        if outcome in ("WIN", "LOSS"):
            regimes[key]["win" if outcome == "WIN" else "loss"] += 1

    print(f"\n  {'Regime':<20} {'Wins':>6} {'Losses':>8} {'Total':>7} {'Win%':>7}")
    print(f"  {'─'*20} {'─'*6} {'─'*8} {'─'*7} {'─'*7}")
    for regime in sorted(regimes.keys()):
        s = regimes[regime]
        total = s["win"] + s["loss"]
        if total == 0:
            continue
        wr = s["win"] / total * 100
        color = green if wr >= 55 else (red if wr < 40 else yellow)
        print(f"  {regime:<20} {s['win']:>6} {s['loss']:>8} {total:>7} {color(f'{wr:>6.1f}%')}")

    # ATR quartile analysis
    atr_vals = [float(r.get("atr", 0)) for r in all_records if float(r.get("atr", 0)) > 0]
    if atr_vals:
        q25, q50, q75 = np.percentile(atr_vals, [25, 50, 75])
        atr_bins = {"Low ATR": (0, q25), f"Med-Low": (q25, q50),
                    f"Med-High": (q50, q75), "High ATR": (q75, 1e10)}

        print(f"\n  {'ATR Quartile':<15} {'Wins':>6} {'Losses':>8} {'Total':>7} {'Win%':>7}")
        print(f"  {'─'*15} {'─'*6} {'─'*8} {'─'*7} {'─'*7}")
        for label, (lo, hi) in atr_bins.items():
            w = sum(1 for r in wins if lo <= float(r.get("atr", 0)) < hi)
            l = sum(1 for r in losses if lo <= float(r.get("atr", 0)) < hi)
            total = w + l
            if total == 0:
                continue
            wr = w / total * 100
            color = green if wr >= 55 else (red if wr < 40 else yellow)
            print(f"  {label:<15} {w:>6} {l:>8} {total:>7} {color(f'{wr:>6.1f}%')}")

    # Alignment summary
    aligned_w = sum(1 for r in wins if int(float(r.get("align_with_trend", 0))) == 1)
    aligned_l = sum(1 for r in losses if int(float(r.get("align_with_trend", 0))) == 1)
    counter_w = len(wins) - aligned_w
    counter_l = len(losses) - aligned_l

    print(f"\n  Trend Alignment:")
    for label, w, l in [("Aligned", aligned_w, aligned_l), ("Counter-trend", counter_w, counter_l)]:
        total = w + l
        if total == 0:
            continue
        wr = w / total * 100
        color = green if wr >= 55 else (red if wr < 40 else yellow)
        print(f"    {label:<20} {w} W / {l} L = {color(f'{wr:.1f}%')}")

    return {"regimes": dict(regimes)}

# ══════════════════════════════════════════════════════════════════════════════
#  Module F: Missed Filter Simulation
# ══════════════════════════════════════════════════════════════════════════════
def module_f(wins, losses, all_records):
    print(f"\n{bold('═══ Module F: Missed Filter Simulation ═══')}")

    total_w = len(wins)
    total_l = len(losses)
    if total_w == 0 or total_l == 0:
        print(f"  {yellow('Need both wins and losses for filter simulation')}")
        return None

    # Define candidate filters
    filters = []

    # Binary feature filters
    for f in ["align_with_trend", "has_sweep_before", "is_mss", "top_imp_valid",
              "is_lower_mss", "htf_bull", "htf_bear"]:
        # Filter: require f == 1
        w_kept = sum(1 for r in wins if int(float(r.get(f, 0))) == 1)
        l_kept = sum(1 for r in losses if int(float(r.get(f, 0))) == 1)
        w_removed = total_w - w_kept
        l_removed = total_l - l_kept
        if l_removed > 0:
            filters.append({
                "name": f"require {f}=1",
                "w_removed": w_removed, "l_removed": l_removed,
                "w_kept": w_kept, "l_kept": l_kept,
            })

        # Filter: require f == 0
        w_kept0 = sum(1 for r in wins if int(float(r.get(f, 0))) == 0)
        l_kept0 = sum(1 for r in losses if int(float(r.get(f, 0))) == 0)
        w_removed0 = total_w - w_kept0
        l_removed0 = total_l - l_kept0
        if l_removed0 > 0:
            filters.append({
                "name": f"require {f}=0",
                "w_removed": w_removed0, "l_removed": l_removed0,
                "w_kept": w_kept0, "l_kept": l_kept0,
            })

    # Session filters
    for session in ["Asian", "London", "New York", "Late NY"]:
        w_removed = sum(1 for r in wins if get_session(float(r.get("hour_utc", 0))) == session)
        l_removed = sum(1 for r in losses if get_session(float(r.get("hour_utc", 0))) == session)
        if l_removed > 0:
            filters.append({
                "name": f"skip {session} session",
                "w_removed": w_removed, "l_removed": l_removed,
                "w_kept": total_w - w_removed, "l_kept": total_l - l_removed,
            })

    # Day of week filters
    DOW = ["Mon", "Tue", "Wed", "Thu", "Fri"]
    for d in range(5):
        w_removed = sum(1 for r in wins if int(float(r.get("day_of_week", 0))) == d)
        l_removed = sum(1 for r in losses if int(float(r.get("day_of_week", 0))) == d)
        if l_removed > 0:
            filters.append({
                "name": f"skip {DOW[d]}",
                "w_removed": w_removed, "l_removed": l_removed,
                "w_kept": total_w - w_removed, "l_kept": total_l - l_removed,
            })

    # HTF range filter
    w_rem = sum(1 for r in wins if int(float(r.get("htf_trend", 0))) == 0)
    l_rem = sum(1 for r in losses if int(float(r.get("htf_trend", 0))) == 0)
    if l_rem > 0:
        filters.append({
            "name": "skip HTF=RANGE",
            "w_removed": w_rem, "l_removed": l_rem,
            "w_kept": total_w - w_rem, "l_kept": total_l - l_rem,
        })

    # Stars threshold filters
    for min_stars in [1, 2, 3]:
        w_rem = sum(1 for r in wins if float(r.get("stars", 0)) < min_stars)
        l_rem = sum(1 for r in losses if float(r.get("stars", 0)) < min_stars)
        if l_rem > 0:
            filters.append({
                "name": f"require stars >= {min_stars}",
                "w_removed": w_rem, "l_removed": l_rem,
                "w_kept": total_w - w_rem, "l_kept": total_l - l_rem,
            })

    # Compute efficiency scores
    for f in filters:
        loss_elim_rate = f["l_removed"] / total_l if total_l > 0 else 0
        win_elim_rate = f["w_removed"] / total_w if total_w > 0 else 0
        # Efficiency: high loss elimination with low win elimination
        f["efficiency"] = loss_elim_rate / (win_elim_rate + 0.01)
        f["loss_elim_%"] = loss_elim_rate * 100
        f["win_elim_%"] = win_elim_rate * 100
        new_total = f["w_kept"] + f["l_kept"]
        f["new_win%"] = f["w_kept"] / new_total * 100 if new_total > 0 else 0

        # Net R impact
        w_r_removed = sum(float(r.get("r_multiple", 0)) for r in wins
                         if _filter_matches(r, f["name"]))
        l_r_removed = sum(float(r.get("r_multiple", 0)) for r in losses
                         if _filter_matches(r, f["name"]))
        f["r_saved"] = -l_r_removed - w_r_removed  # losses are negative R, removing them is positive

    filters.sort(key=lambda x: -x["efficiency"])

    print(f"\n  Top filters ranked by efficiency (loss elimination / win cost):\n")
    print(f"  {'Filter':<30} {'LossElim':>9} {'WinCost':>9} {'NewWin%':>8} {'Effic':>7} {'R saved':>8}")
    print(f"  {'─'*30} {'─'*9} {'─'*9} {'─'*8} {'─'*7} {'─'*8}")
    for flt in filters[:15]:
        le_pct = flt["loss_elim_%"]
        wc_pct = flt["win_elim_%"]
        le_color = green if le_pct > 20 else dim
        wc_color = red if wc_pct > 20 else dim
        le_str = le_color(f"{le_pct:>7.1f}%")
        wc_str = wc_color(f"{wc_pct:>7.1f}%")
        print(f"  {flt['name']:<30} {le_str} {wc_str} "
              f"{flt['new_win%']:>7.1f}% {flt['efficiency']:>6.2f}x {flt['r_saved']:>+7.2f}")

    return filters

def _filter_matches(rec, filter_name):
    """Check if a record would be removed by a given filter."""
    if filter_name.startswith("require ") and "=" in filter_name:
        parts = filter_name.replace("require ", "").split("=")
        feat, val = parts[0], float(parts[1])
        return float(rec.get(feat, 0)) != val
    if filter_name.startswith("skip ") and "session" in filter_name:
        session = filter_name.replace("skip ", "").replace(" session", "")
        return get_session(float(rec.get("hour_utc", 0))) == session
    if filter_name.startswith("skip "):
        day_name = filter_name.replace("skip ", "")
        DOW = {"Mon": 0, "Tue": 1, "Wed": 2, "Thu": 3, "Fri": 4, "HTF=RANGE": None}
        if day_name == "HTF=RANGE":
            return int(float(rec.get("htf_trend", 0))) == 0
        d = DOW.get(day_name)
        if d is not None:
            return int(float(rec.get("day_of_week", 0))) == d
    if filter_name.startswith("require stars >= "):
        min_s = float(filter_name.split(">= ")[1])
        return float(rec.get("stars", 0)) < min_s
    return False

# ══════════════════════════════════════════════════════════════════════════════
#  Module G: Multi-Timeframe Candle Analysis
# ══════════════════════════════════════════════════════════════════════════════
CANDLE_TFS = ["PERIOD_M5", "PERIOD_M15", "PERIOD_H1", "PERIOD_H4", "PERIOD_D1"]
TF_SHORT = {"PERIOD_M5": "M5", "PERIOD_M15": "M15", "PERIOD_H1": "H1",
            "PERIOD_H4": "H4", "PERIOD_D1": "D1"}

def load_candle_csv(script_dir):
    """Load ob_candles_*.csv files from Tester agents or MQL5/Files."""
    import glob as glob_mod
    mt5 = Path(script_dir).parents[2]  # up to MQL5 root's parent
    patterns = [
        str(mt5 / "Tester" / "*" / "MQL5" / "Files" / "ob_candles_*.csv"),
        str(mt5 / "MQL5" / "Files" / "ob_candles_*.csv"),
    ]
    all_rows = []
    for pat in patterns:
        for path in sorted(glob_mod.glob(pat)):
            with open(path, newline="", encoding="utf-8", errors="replace") as fh:
                reader = csv.DictReader(fh)
                for row in reader:
                    all_rows.append(row)
    return all_rows

def classify_candle(body, upper_wick, lower_wick, range_val, bullish):
    """Classify a candle into a pattern type."""
    if range_val <= 0:
        return "doji"
    body_ratio = body / range_val
    if body_ratio < 0.1:
        return "doji"
    if body_ratio < 0.3:
        if lower_wick > body * 2 and upper_wick < body:
            return "hammer" if bullish else "hanging_man"
        if upper_wick > body * 2 and lower_wick < body:
            return "shooting_star" if not bullish else "inverted_hammer"
        return "spinning_top"
    if body_ratio > 0.7:
        return "marubozu_bull" if bullish else "marubozu_bear"
    return "normal_bull" if bullish else "normal_bear"

def compute_candle_features(candle_rows):
    """From a list of candle rows for one ob_name+phase, compute features."""
    features = {}
    for row in candle_rows:
        tf = row.get("tf", "")
        tf_short = TF_SHORT.get(tf, tf)
        prefix = tf_short

        for cn in ["c1", "c2", "c3"]:
            body = safe_float(row.get(f"{cn}_body", 0))
            upper = safe_float(row.get(f"{cn}_upper_wick", 0))
            lower = safe_float(row.get(f"{cn}_lower_wick", 0))
            rng = safe_float(row.get(f"{cn}_range", 0))
            bull = int(safe_float(row.get(f"{cn}_bullish", 0)))

            pattern = classify_candle(body, upper, lower, rng, bull)
            features[f"{prefix}_{cn}_bullish"] = bull
            features[f"{prefix}_{cn}_body_ratio"] = body / rng if rng > 0 else 0
            features[f"{prefix}_{cn}_upper_wick_ratio"] = upper / rng if rng > 0 else 0
            features[f"{prefix}_{cn}_lower_wick_ratio"] = lower / rng if rng > 0 else 0
            features[f"{prefix}_{cn}_pattern"] = pattern

        # Trend: how many of the 3 candles are bullish
        bulls = sum(int(safe_float(row.get(f"c{c}_bullish", 0))) for c in [1, 2, 3])
        features[f"{prefix}_trend_score"] = bulls / 3.0  # 0=all bear, 1=all bull

        # Engulfing pattern: c1 body fully contains c2 body
        c1_body = safe_float(row.get("c1_body", 0))
        c2_body = safe_float(row.get("c2_body", 0))
        features[f"{prefix}_engulfing"] = 1 if c1_body > c2_body * 1.5 else 0

        # Inside bar: c1 range within c2 range
        c1_rng = safe_float(row.get("c1_range", 0))
        c2_rng = safe_float(row.get("c2_range", 0))
        features[f"{prefix}_inside_bar"] = 1 if (c1_rng < c2_rng * 0.8 and c2_rng > 0) else 0

    return features

def module_g(wins, losses, all_records):
    """Multi-timeframe candle context analysis."""
    import numpy as np

    print(f"\n{bold('═══ Module G: Multi-Timeframe Candle Analysis ═══')}")

    candle_rows = load_candle_csv(str(SCRIPT_DIR))
    if not candle_rows:
        print(f"  {yellow('No candle data found. Run a backtest with the updated EA first.')}")
        print(f"  {dim('Expected: ob_candles_*.csv in Tester/Agent-*/MQL5/Files/')}")
        return None

    # Group by ob_name + phase
    grouped = defaultdict(list)
    for row in candle_rows:
        key = (row.get("ob_name", ""), row.get("phase", ""))
        grouped[key].append(row)

    # Build feature dicts for ENTRY phase
    ob_candle_features = {}
    for (ob_name, phase), rows in grouped.items():
        if phase == "ENTRY":
            ob_candle_features[ob_name] = compute_candle_features(rows)

    # Match with trade outcomes
    win_feats = []
    loss_feats = []
    for rec in all_records:
        ob_name = rec.get("ob_name", "")
        if ob_name in ob_candle_features:
            cf = ob_candle_features[ob_name]
            if rec.get("outcome") == "WIN":
                win_feats.append(cf)
            elif rec.get("outcome") == "LOSS":
                loss_feats.append(cf)

    matched = len(win_feats) + len(loss_feats)
    print(f"\n  Candle data matched: {matched} trades ({len(win_feats)}W / {len(loss_feats)}L)")

    if len(win_feats) < 2 or len(loss_feats) < 2:
        print(f"  {yellow('Not enough matched trades for comparison.')}")
        return {"candle_rows": candle_rows, "matched": matched}

    # Compare numeric features between wins and losses
    all_feat_keys = set()
    for d in win_feats + loss_feats:
        all_feat_keys.update(k for k, v in d.items() if isinstance(v, (int, float)))

    from scipy.stats import mannwhitneyu

    results = []
    for feat in sorted(all_feat_keys):
        w_vals = [f.get(feat, 0) for f in win_feats if isinstance(f.get(feat, 0), (int, float))]
        l_vals = [f.get(feat, 0) for f in loss_feats if isinstance(f.get(feat, 0), (int, float))]
        if len(set(w_vals)) <= 1 and len(set(l_vals)) <= 1:
            continue
        try:
            _, p = mannwhitneyu(w_vals, l_vals, alternative="two-sided")
        except ValueError:
            continue
        w_mean = sum(w_vals) / len(w_vals) if w_vals else 0
        l_mean = sum(l_vals) / len(l_vals) if l_vals else 0
        results.append((feat, p, w_mean, l_mean))

    results.sort(key=lambda x: x[1])
    sig = [r for r in results if r[1] < 0.15]  # relaxed threshold for small samples

    if sig:
        print(f"\n  MTF candle features that differ between W/L (p < 0.15):\n")
        print(f"  {'Feature':<35} {'p-val':>8} {'Win':>8} {'Loss':>8}")
        print(f"  {'─'*35} {'─'*8} {'─'*8} {'─'*8}")
        for name, p, wm, lm in sig[:15]:
            color = green if wm > lm else red
            print(f"  {name:<35} {p:>8.4f} {wm:>8.3f} {color(f'{lm:>8.3f}')}")
    else:
        print(f"  {yellow('No significant candle pattern differences found.')}")

    # Pattern distribution comparison per TF
    print(f"\n  {bold('Candle patterns at ENTRY by timeframe:')}\n")
    for tf in CANDLE_TFS:
        tf_short = TF_SHORT.get(tf, tf)
        for cn in ["c1"]:  # Most recent candle is most relevant
            w_patterns = Counter(f.get(f"{tf_short}_{cn}_pattern", "?") for f in win_feats)
            l_patterns = Counter(f.get(f"{tf_short}_{cn}_pattern", "?") for f in loss_feats)
            all_pats = set(list(w_patterns.keys()) + list(l_patterns.keys()))

            interesting = []
            for pat in all_pats:
                w_pct = w_patterns.get(pat, 0) / len(win_feats) * 100 if win_feats else 0
                l_pct = l_patterns.get(pat, 0) / len(loss_feats) * 100 if loss_feats else 0
                if abs(w_pct - l_pct) > 10:  # only show meaningful differences
                    interesting.append((pat, w_pct, l_pct))

            if interesting:
                print(f"  {bold(tf_short)} (last candle before entry):")
                for pat, wp, lp in sorted(interesting, key=lambda x: -(x[2] - x[1])):
                    indicator = red("▲ loss") if lp > wp else green("▲ win")
                    print(f"    {pat:<20} Win: {wp:>5.1f}%  Loss: {lp:>5.1f}%  {indicator}")

    # Trend alignment across TFs
    print(f"\n  {bold('Trend alignment at entry (% bullish candles):')}\n")
    print(f"  {'Timeframe':<10} {'Wins':>8} {'Losses':>8} {'Gap':>8}")
    print(f"  {'─'*10} {'─'*8} {'─'*8} {'─'*8}")
    for tf in CANDLE_TFS:
        tf_short = TF_SHORT.get(tf, tf)
        key = f"{tf_short}_trend_score"
        w_ts = [f.get(key, 0.5) for f in win_feats]
        l_ts = [f.get(key, 0.5) for f in loss_feats]
        w_avg = sum(w_ts) / len(w_ts) * 100 if w_ts else 50
        l_avg = sum(l_ts) / len(l_ts) * 100 if l_ts else 50
        gap = w_avg - l_avg
        color = green if gap > 5 else (red if gap < -5 else dim)
        print(f"  {tf_short:<10} {w_avg:>7.1f}% {l_avg:>7.1f}% {color(f'{gap:>+7.1f}%')}")

    # EXIT phase comparison (what the candles looked like when trade closed)
    exit_win_feats = []
    exit_loss_feats = []
    for (ob_name, phase), rows in grouped.items():
        if phase != "EXIT":
            continue
        cf = compute_candle_features(rows)
        outcome = rows[0].get("outcome", "") if rows else ""
        if outcome == "WIN":
            exit_win_feats.append(cf)
        elif outcome == "LOSS":
            exit_loss_feats.append(cf)

    if exit_win_feats and exit_loss_feats:
        print(f"\n  {bold('Trend at EXIT (% bullish candles):')}\n")
        print(f"  {'Timeframe':<10} {'Wins':>8} {'Losses':>8}")
        print(f"  {'─'*10} {'─'*8} {'─'*8}")
        for tf in CANDLE_TFS:
            tf_short = TF_SHORT.get(tf, tf)
            key = f"{tf_short}_trend_score"
            w_ts = [f.get(key, 0.5) for f in exit_win_feats]
            l_ts = [f.get(key, 0.5) for f in exit_loss_feats]
            w_avg = sum(w_ts) / len(w_ts) * 100 if w_ts else 50
            l_avg = sum(l_ts) / len(l_ts) * 100 if l_ts else 50
            print(f"  {tf_short:<10} {w_avg:>7.1f}% {l_avg:>7.1f}%")

    return {"results": results, "win_feats": win_feats, "loss_feats": loss_feats,
            "candle_rows": candle_rows, "matched": matched}


# ══════════════════════════════════════════════════════════════════════════════
#  Module H: Volume Profile Analysis
# ══════════════════════════════════════════════════════════════════════════════
def module_h(wins, losses, records):
    """Analyze trades relative to Volume Profile levels (POC, VAH, VAL).
    
    Volume Profile concepts:
    - POC (Point of Control): Price level with highest volume
    - VAH (Value Area High): Upper boundary of 70% volume zone
    - VAL (Value Area Low): Lower boundary of 70% volume zone
    - Inside VA: Price in equilibrium zone
    - Outside VA: Price in disequilibrium (potential mean reversion)
    """
    print(f"\n  {bold('Module H: Volume Profile Analysis')}")
    hline("─")
    
    if len(records) == 0:
        print(f"  {dim('No data available for VP analysis')}")
        return None
    
    DIGITS_MAP = {"XAUUSD": 2, "EURUSD": 5, "GBPUSD": 5, "USDJPY": 3, "NAS100": 2}
    digits = DIGITS_MAP.get(args.symbol, 2)
    point_mult = 10 ** digits
    
    def get_distance_pips(entry_price, level_price, digits=2):
        """Calculate distance in pips between entry and level."""
        return abs(entry_price - level_price) * point_mult
    
    def classify_distance(dist_pips):
        """Classify distance into categories."""
        if dist_pips < 5:
            return "very_close"
        elif dist_pips < 15:
            return "close"
        elif dist_pips < 30:
            return "medium"
        else:
            return "far"
    
    poc_near_wins = 0
    poc_near_losses = 0
    va_inside_wins = 0
    va_inside_losses = 0
    va_above_wins = 0
    va_above_losses = 0
    va_below_wins = 0
    va_below_losses = 0
    
    dist_pips_wins = []
    dist_pips_losses = []
    
    for rec in wins + losses:
        entry_price = safe_float(rec.get("entry_price", 0))
        if entry_price <= 0:
            continue
        
        poc_price = safe_float(rec.get("vp_poc_price", 0)
        vah_price = safe_float(rec.get("vp_vah_price", 0))
        val_price = safe_float(rec.get("vp_val_price", 0))
        
        if poc_price > 0:
            dist_pips = get_distance_pips(entry_price, poc_price, digits)
            if rec.get("outcome") == "WIN":
                dist_pips_wins.append(dist_pips)
            else:
                dist_pips_losses.append(dist_pips)
        
        if poc_price > 0 and dist_pips < 5:
            if rec.get("outcome") == "WIN":
                poc_near_wins += 1
            else:
                poc_near_losses += 1
        
        if vah_price > 0 and val_price > 0:
            if entry_price >= val_price and entry_price <= vah_price:
                if rec.get("outcome") == "WIN":
                    va_inside_wins += 1
                else:
                    va_inside_losses += 1
            elif entry_price > vah_price:
                if rec.get("outcome") == "WIN":
                    va_above_wins += 1
                else:
                    va_above_losses += 1
            else:
                if rec.get("outcome") == "WIN":
                    va_below_wins += 1
                else:
                    va_below_losses += 1
    
    total_wins = len(wins)
    total_losses = len(losses)
    
    print(f"\n  {bold('Entry Distance to POC:')}\n")
    print(f"  {'Category':<15} {'Wins':>8} {'Losses':>8} {'Win%':>8} {'Diff':>8}")
    print(f"  {'─'*15} {'─'*8} {'─'*8} {'─'*8} {'─'*8}")
    
    categories = ["very_close", "close", "medium", "far"]
    for cat in categories:
        if cat == "very_close":
            w_near = poc_near_wins
            l_near = poc_near_losses
        else:
            w_near = sum(1 for d in dist_pips_wins if classify_distance(d) == cat)
            l_near = sum(1 for d in dist_pips_losses if classify_distance(d) == cat)
        
        total = w_near + l_near
        if total > 0:
            wr = w_near / total * 100
            baseline = total_wins / (total_wins + total_losses) * 100 if (total_wins + total_losses) > 0 else 50
            diff = wr - baseline
            color = green if diff > 5 else (red if diff < -5 else dim)
            print(f"  {cat:<15} {w_near:>8} {l_near:>8} {wr:>7.1f}% {color(f'{diff:>+7.1f}%')}")
    
    if dist_pips_wins and dist_pips_losses:
        avg_wins = sum(dist_pips_wins) / len(dist_pips_wins)
        avg_losses = sum(dist_pips_losses) / len(dist_pips_losses)
        print(f"\n  Average distance to POC: {avg_wins:.1f} pips (wins) vs {avg_losses:.1f} pips (losses)")
    
    print(f"\n  {bold('Entry Location Relative to Value Area:')}\n")
    print(f"  {'Zone':<12} {'Wins':>8} {'Losses':>8} {'Win%':>8} {'Status':>12}")
    print(f"  {'─'*12} {'─'*8} {'─'*8} {'─'*8} {'─'*12}")
    
    zones = [
        ("Inside VA", va_inside_wins, va_inside_losses),
        ("Above VAH", va_above_wins, va_above_losses),
        ("Below VAL", va_below_wins, va_below_losses),
    ]
    
    findings = []
    for name, w, l in zones:
        total = w + l
        if total > 0:
            wr = w / total * 100
            baseline = total_wins / (total_wins + total_losses) * 100 if (total_wins + total_losses) > 0 else 50
            diff = wr - baseline
            
            if abs(diff) > 8:
                if diff > 0:
                    status = green("✓ Favors")
                    findings.append((name, diff, True))
                else:
                    status = red("✗ Avoid")
                    findings.append((name, diff, False))
            else:
                status = dim("Neutral")
                findings.append((name, diff, None))
            
            print(f"  {name:<12} {w:>8} {l:>8} {wr:>7.1f}% {status}")
    
    print(f"\n  {bold('Key Findings:')}\n")
    if findings:
        for name, diff, favorable in findings:
            if favorable is not None:
                if favorable:
                    print(f"  {green('✓')} {name}: +{diff:.1f}% win rate improvement")
                else:
                    print(f"  {red('✗')} {name}: {diff:.1f}% win rate reduction — consider filtering")
    
    recommendations = []
    for name, diff, favorable in findings:
        if favorable is False and abs(diff) > 5:
            recommendations.append({
                "name": f"Skip {name}",
                "loss_elim_%": abs(diff) * 1.5,
                "win_elim_%": abs(diff) * 0.8,
                "new_win%": 50,
                "efficiency": 1.5,
                "r_saved": diff / 10
            })
    
    return {
        "findings": findings,
        "recommendations": recommendations,
        "dist_pips_wins": dist_pips_wins,
        "dist_pips_losses": dist_pips_losses,
        "zone_counts": {
            "inside_va": (va_inside_wins, va_inside_losses),
            "above_vah": (va_above_wins, va_above_losses),
            "below_val": (va_below_wins, va_below_losses),
        }
    }


# ══════════════════════════════════════════════════════════════════════════════
#  HTML Report Generator
# ══════════════════════════════════════════════════════════════════════════════
def generate_html(all_records, wins, losses, results, output_path):
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import seaborn as sns

    charts = {}

    # ── Chart 1: Win/Loss violin plots for top features ──────────────────
    mod_a = results.get("module_a", [])
    sig_feats = [r[0] for r in mod_a if r[1] < 0.05][:6]
    if sig_feats:
        fig, axes = plt.subplots(2, 3, figsize=(14, 8))
        axes = axes.flatten()
        for i, f in enumerate(sig_feats):
            if i >= 6:
                break
            w_vals = [float(r.get(f, 0)) for r in wins]
            l_vals = [float(r.get(f, 0)) for r in losses]
            ax = axes[i]
            parts = ax.violinplot([w_vals, l_vals], positions=[0, 1], showmeans=True, showmedians=True)
            for pc in parts["bodies"]:
                pc.set_alpha(0.7)
            if len(parts["bodies"]) >= 2:
                parts["bodies"][0].set_facecolor("#2ecc71")
                parts["bodies"][1].set_facecolor("#e74c3c")
            ax.set_xticks([0, 1])
            ax.set_xticklabels(["WIN", "LOSS"])
            ax.set_title(f, fontsize=10)
        for j in range(len(sig_feats), 6):
            axes[j].set_visible(False)
        plt.suptitle("Win vs Loss Feature Distributions", fontsize=14, fontweight="bold")
        plt.tight_layout()
        charts["violin"] = fig_to_base64(fig)
        plt.close(fig)

    # ── Chart 2: Temporal heatmap ────────────────────────────────────────
    mod_d = results.get("module_d", {})
    heatmap_data = mod_d.get("heatmap", {})
    if heatmap_data:
        DOW = ["Mon", "Tue", "Wed", "Thu", "Fri"]
        grid = np.full((24, 5), np.nan)
        for (h, d), (w, l) in heatmap_data.items():
            total = w + l
            if total >= 1:
                grid[h, d] = w / total * 100

        fig, ax = plt.subplots(figsize=(8, 12))
        sns.heatmap(grid, annot=True, fmt=".0f", cmap="RdYlGn", vmin=0, vmax=100,
                    xticklabels=DOW, yticklabels=[f"{h:02d}:00" for h in range(24)],
                    ax=ax, cbar_kws={"label": "Win %"}, linewidths=0.5)
        ax.set_title("Win Rate by Hour × Day of Week", fontsize=14, fontweight="bold")
        ax.set_ylabel("Hour (UTC)")
        ax.set_xlabel("Day of Week")
        plt.tight_layout()
        charts["heatmap"] = fig_to_base64(fig)
        plt.close(fig)

    # ── Chart 3: SHAP summary ───────────────────────────────────────────
    mod_c = results.get("module_c", {})
    if mod_c and mod_c.get("shap_values") is not None:
        sv = mod_c["shap_values"]
        mean_abs = np.mean(np.abs(sv), axis=0)
        top_idx = np.argsort(mean_abs)[-10:][::-1]

        fig, ax = plt.subplots(figsize=(10, 6))
        feat_names = [ANALYSIS_FEATS[i] for i in top_idx]
        vals = [mean_abs[i] for i in top_idx]
        colors = ["#e74c3c" if v > np.median(vals) else "#3498db" for v in vals]
        ax.barh(range(len(feat_names)), vals, color=colors)
        ax.set_yticks(range(len(feat_names)))
        ax.set_yticklabels(feat_names)
        ax.invert_yaxis()
        ax.set_xlabel("Mean |SHAP value|")
        ax.set_title("Top Loss Drivers (SHAP)", fontsize=14, fontweight="bold")
        plt.tight_layout()
        charts["shap"] = fig_to_base64(fig)
        plt.close(fig)

    # ── Chart 4: Cluster scatter (PCA) ───────────────────────────────────
    mod_b = results.get("module_b")
    if mod_b and mod_b.get("X_scaled") is not None:
        from sklearn.decomposition import PCA
        X_sc = mod_b["X_scaled"]
        labels = mod_b["labels"]
        pca = PCA(n_components=2)
        X_2d = pca.fit_transform(X_sc)

        fig, ax = plt.subplots(figsize=(8, 6))
        scatter = ax.scatter(X_2d[:, 0], X_2d[:, 1], c=labels, cmap="tab10",
                            alpha=0.7, edgecolors="white", linewidth=0.5)
        ax.set_xlabel(f"PC1 ({pca.explained_variance_ratio_[0]:.0%} var)")
        ax.set_ylabel(f"PC2 ({pca.explained_variance_ratio_[1]:.0%} var)")
        ax.set_title("Loss Clusters (PCA projection)", fontsize=14, fontweight="bold")
        plt.colorbar(scatter, ax=ax, label="Cluster")
        plt.tight_layout()
        charts["clusters"] = fig_to_base64(fig)
        plt.close(fig)

    # ── Chart 5: Filter efficiency ───────────────────────────────────────
    mod_f = results.get("module_f", [])
    if mod_f:
        top_filters = mod_f[:10]
        fig, ax = plt.subplots(figsize=(10, 6))
        names = [f["name"] for f in top_filters]
        efficiencies = [f["efficiency"] for f in top_filters]
        loss_elims = [f["loss_elim_%"] for f in top_filters]
        win_costs = [f["win_elim_%"] for f in top_filters]

        x = range(len(names))
        width = 0.35
        ax.barh([i - width/2 for i in x], loss_elims, width, label="Loss eliminated %", color="#2ecc71")
        ax.barh([i + width/2 for i in x], win_costs, width, label="Win cost %", color="#e74c3c")
        ax.set_yticks(list(x))
        ax.set_yticklabels(names, fontsize=9)
        ax.invert_yaxis()
        ax.set_xlabel("Percentage")
        ax.set_title("Filter Impact: Loss Elimination vs Win Cost", fontsize=14, fontweight="bold")
        ax.legend()
        plt.tight_layout()
        charts["filters"] = fig_to_base64(fig)
        plt.close(fig)

    # ── Chart 6: MTF trend alignment (wins vs losses) ──────────────────
    mod_g = results.get("module_g")
    if mod_g and mod_g.get("win_feats") and mod_g.get("loss_feats"):
        wf = mod_g["win_feats"]
        lf = mod_g["loss_feats"]
        tf_labels = ["M5", "M15", "H1", "H4", "D1"]
        w_trends = []
        l_trends = []
        for tf_short in tf_labels:
            key = f"{tf_short}_trend_score"
            w_avg = sum(f.get(key, 0.5) for f in wf) / len(wf) * 100
            l_avg = sum(f.get(key, 0.5) for f in lf) / len(lf) * 100
            w_trends.append(w_avg)
            l_trends.append(l_avg)

        fig, ax = plt.subplots(figsize=(10, 5))
        x = np.arange(len(tf_labels))
        width = 0.35
        bars1 = ax.bar(x - width/2, w_trends, width, label="Wins", color="#2ecc71", alpha=0.85)
        bars2 = ax.bar(x + width/2, l_trends, width, label="Losses", color="#e74c3c", alpha=0.85)
        ax.set_ylabel("% Bullish Candles")
        ax.set_xlabel("Timeframe")
        ax.set_title("MTF Trend at Entry: Wins vs Losses", fontsize=14, fontweight="bold")
        ax.set_xticks(x)
        ax.set_xticklabels(tf_labels)
        ax.axhline(y=50, color="gray", linestyle="--", alpha=0.5)
        ax.legend()
        ax.set_ylim(0, 100)
        plt.tight_layout()
        charts["mtf_trend"] = fig_to_base64(fig)
        plt.close(fig)

    # ── Build HTML ───────────────────────────────────────────────────────
    n_total = len(all_records)
    n_wins = len(wins)
    n_losses = len(losses)
    win_rate = n_wins / n_total * 100 if n_total > 0 else 0

    html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<title>Trade Forensics Report</title>
<style>
  body {{ font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
         max-width: 1200px; margin: 0 auto; padding: 20px; background: #1a1a2e; color: #e0e0e0; }}
  h1 {{ color: #00d4ff; border-bottom: 2px solid #00d4ff; padding-bottom: 10px; }}
  h2 {{ color: #7fdbca; margin-top: 40px; }}
  .stats {{ display: flex; gap: 20px; margin: 20px 0; }}
  .stat {{ background: #16213e; border-radius: 12px; padding: 20px; flex: 1; text-align: center; }}
  .stat .value {{ font-size: 2em; font-weight: bold; }}
  .stat.wins .value {{ color: #2ecc71; }}
  .stat.losses .value {{ color: #e74c3c; }}
  .stat.rate .value {{ color: #f39c12; }}
  .chart {{ background: #16213e; border-radius: 12px; padding: 20px; margin: 20px 0; }}
  .chart img {{ width: 100%; border-radius: 8px; }}
  table {{ border-collapse: collapse; width: 100%; margin: 10px 0; }}
  th, td {{ padding: 8px 12px; text-align: left; border-bottom: 1px solid #333; }}
  th {{ background: #0f3460; color: #00d4ff; }}
  tr:hover {{ background: #1a1a3e; }}
  .good {{ color: #2ecc71; }}
  .bad {{ color: #e74c3c; }}
  .warn {{ color: #f39c12; }}
</style></head><body>
<h1>Trade Forensics Report — XAUUSD</h1>
<div class="stats">
  <div class="stat"><div class="value">{n_total}</div><div>Total Trades</div></div>
  <div class="stat wins"><div class="value">{n_wins}</div><div>Wins</div></div>
  <div class="stat losses"><div class="value">{n_losses}</div><div>Losses</div></div>
  <div class="stat rate"><div class="value">{win_rate:.1f}%</div><div>Win Rate</div></div>
</div>
"""

    for key, title in [("violin", "Win vs Loss Feature Distributions"),
                       ("heatmap", "Win Rate Heatmap (Hour x Day)"),
                       ("shap", "SHAP Loss Drivers"),
                       ("clusters", "Loss Cluster Analysis (PCA)"),
                       ("filters", "Filter Impact Analysis"),
                       ("mtf_trend", "Multi-Timeframe Trend at Entry")]:
        if key in charts:
            html += f'<h2>{title}</h2>\n<div class="chart"><img src="data:image/png;base64,{charts[key]}"></div>\n'

    # Filter table
    if mod_f:
        html += "<h2>Filter Recommendations</h2>\n<table>\n"
        html += "<tr><th>Filter</th><th>Loss Elim %</th><th>Win Cost %</th><th>New Win%</th><th>Efficiency</th><th>R Saved</th></tr>\n"
        for f in mod_f[:15]:
            le_cls = "good" if f["loss_elim_%"] > 20 else ""
            wc_cls = "bad" if f["win_elim_%"] > 20 else ""
            html += (f'<tr><td>{f["name"]}</td>'
                    f'<td class="{le_cls}">{f["loss_elim_%"]:.1f}%</td>'
                    f'<td class="{wc_cls}">{f["win_elim_%"]:.1f}%</td>'
                    f'<td>{f["new_win%"]:.1f}%</td>'
                    f'<td>{f["efficiency"]:.2f}x</td>'
                    f'<td>{f["r_saved"]:+.2f}</td></tr>\n')
        html += "</table>\n"

    html += "</body></html>"

    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(html)
    print(f"\n  HTML report → {output_path}")

def fig_to_base64(fig):
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=120, bbox_inches="tight",
                facecolor="#1a1a2e", edgecolor="none")
    buf.seek(0)
    return base64.b64encode(buf.read()).decode("ascii")

# ══════════════════════════════════════════════════════════════════════════════
#  Pipeline Orchestration
# ══════════════════════════════════════════════════════════════════════════════
def run_backtest(symbol, from_date, to_date):
    """Run backtest.sh with parameters."""
    print(f"\n{bold('Step 1/3: Running backtest...')}")
    env = os.environ.copy()
    env["SYMBOL"] = symbol
    env["FROM_DATE"] = from_date
    env["TO_DATE"] = to_date
    result = subprocess.run(
        ["bash", str(BACKTEST_SH)],
        cwd=str(SCRIPT_DIR), env=env,
        capture_output=False, timeout=600,
    )
    if result.returncode != 0:
        print(red("Backtest failed!"))
        sys.exit(1)
    print(green("  Backtest complete."))

def run_build_dataset():
    """Run build_dataset.py to create labeled dataset."""
    print(f"\n{bold('Step 2/3: Building dataset...')}")
    result = subprocess.run(
        [PYTHON, str(BUILD_DATASET)],
        cwd=str(SCRIPT_DIR),
        capture_output=True, text=True, timeout=120,
    )
    print(result.stdout)
    if result.returncode != 0:
        print(red(f"Dataset build failed: {result.stderr}"))
        sys.exit(1)
    print(green("  Dataset ready."))

def run_analysis(skip_html):
    """Load dataset and run all analysis modules."""
    print(f"\n{bold('Step 3/3: Running forensics analysis...')}")
    hline("═")

    if not DATASET_TRADED.exists():
        print(red(f"Traded dataset not found: {DATASET_TRADED}"))
        print("Run a backtest first or check build_dataset.py output.")
        sys.exit(1)

    records = load_traded_dataset(str(DATASET_TRADED))
    wins = [r for r in records if r.get("outcome") == "WIN"]
    losses = [r for r in records if r.get("outcome") == "LOSS"]

    print(f"\n  Dataset: {len(records)} traded OBs — {green(f'{len(wins)} wins')} / {red(f'{len(losses)} losses')}")
    if len(records) > 0:
        wr = len(wins) / len(records) * 100
        print(f"  Win rate: {wr:.1f}%")

    if len(losses) == 0:
        print(yellow("\n  No losses to analyze! The EA is perfect (or no trades taken)."))
        return

    results = {}

    # Module A
    results["module_a"] = module_a(wins, losses, records)

    # Module B
    results["module_b"] = module_b(losses)

    # Module C
    results["module_c"] = module_c(wins, losses, records)

    # Module D
    results["module_d"] = module_d(wins, losses, records)

    # Module E
    module_e(wins, losses, records)

    # Module F
    results["module_f"] = module_f(wins, losses, records)

    # Module G
    results["module_g"] = module_g(wins, losses, records)

    # Module H: Volume Profile Analysis
    results["module_h"] = module_h(wins, losses, records)

    # Summary
    hline("═")
    print(f"\n{bold('FORENSICS SUMMARY')}")
    print(f"  Trades analyzed: {len(records)} ({len(wins)}W / {len(losses)}L)")

    mod_a = results.get("module_a", [])
    sig_count = sum(1 for r in mod_a if r[1] < 0.05)
    print(f"  Significant feature differences: {sig_count}")

    mod_b = results.get("module_b")
    if mod_b:
        print(f"  Loss archetypes found: {mod_b['k']}")

    death_zones = results.get("module_d", {}).get("death_zones", [])
    if death_zones:
        zones = ", ".join(f"{h:02d}:00" for h, *_ in death_zones)
        print(f"  Death zones: {red(zones)}")

    mod_f = results.get("module_f", [])
    if mod_f:
        best = mod_f[0]
        print(f"  Best filter: {cyan(best['name'])} "
              f"(removes {best['loss_elim_%']:.0f}% losses, costs {best['win_elim_%']:.0f}% wins)")

    # HTML
    if not skip_html:
        print(f"\n{bold('Generating HTML report...')}")
        generate_html(records, wins, losses, results, str(HTML_OUT))

    print(f"\n{green(bold('Done.'))}")

# ══════════════════════════════════════════════════════════════════════════════
#  Main
# ══════════════════════════════════════════════════════════════════════════════
def main():
    ap = argparse.ArgumentParser(description="Trade Forensics Tool for OrderBlock EA")
    ap.add_argument("--symbol", default="XAUUSD", help="Symbol to analyze (default: XAUUSD)")
    ap.add_argument("--from-date", default="2025.01.01", help="Backtest start date")
    ap.add_argument("--to-date", default="2026.01.01", help="Backtest end date")
    ap.add_argument("--skip-backtest", action="store_true", help="Skip backtest, analyze existing data")
    ap.add_argument("--no-html", action="store_true", help="Skip HTML report generation")
    args = ap.parse_args()

    print(bold("╔══════════════════════════════════════════════════╗"))
    print(bold("║       TRADE FORENSICS — OrderBlock EA           ║"))
    print(bold("╚══════════════════════════════════════════════════╝"))
    print(f"  Symbol: {args.symbol}  Period: {args.from_date} → {args.to_date}")

    if not args.skip_backtest:
        run_backtest(args.symbol, args.from_date, args.to_date)
        run_build_dataset()

    run_analysis(args.no_html)

if __name__ == "__main__":
    main()
