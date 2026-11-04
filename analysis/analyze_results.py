#!/usr/bin/env python3
"""Analisis statistik hasil benchmark A* (Manhattan vs Euclidean).

Pemakaian:
    python analysis/analyze_results.py --paired out/results_paired_X.csv \
        [--raw out/results_raw_X.csv] [--outdir analysis]
"""
import argparse
import os

import numpy as np
import pandas as pd
from scipy import stats

ALPHA = 0.05
KEYS = ["gridSize", "obstacleDensityPct", "movementMode"]
METRICS = {"time": "timeUs", "expanded": "expanded", "cost": "cost"}


def holm(pvals):
    """Koreksi Holm-Bonferroni; NaN dipertahankan."""
    p = np.asarray(pvals, dtype=float)
    out = np.full_like(p, np.nan)
    idx = np.where(~np.isnan(p))[0]
    order = idx[np.argsort(p[idx])]
    m = len(order)
    running = 0.0
    for rank, i in enumerate(order):
        running = max(running, min(1.0, (m - rank) * p[i]))
        out[i] = running
    return out


def compare(man, euc):
    """Uji berpasangan: Shapiro-Wilk -> paired t-test atau Wilcoxon."""
    diff = man - euc
    res = {"n": len(diff), "mean_manhattan": man.mean(), "std_manhattan": man.std(ddof=1),
           "mean_euclidean": euc.mean(), "std_euclidean": euc.std(ddof=1),
           "mean_diff": diff.mean()}
    res["pct_diff_vs_euclidean"] = (diff.mean() / euc.mean() * 100) if euc.mean() else np.nan
    if len(diff) < 3 or np.allclose(diff, 0):
        res.update(normal_p=np.nan, test="none (identical or n<3)", p=1.0 if np.allclose(diff, 0) else np.nan,
                   effect_size=0.0 if np.allclose(diff, 0) else np.nan, effect_type="")
        return res
    normal_p = stats.shapiro(diff).pvalue
    res["normal_p"] = normal_p
    if normal_p >= ALPHA:
        res["test"] = "paired t-test"
        res["p"] = stats.ttest_rel(man, euc).pvalue
        sd = diff.std(ddof=1)
        res["effect_size"] = diff.mean() / sd if sd else np.nan
        res["effect_type"] = "cohen_d"
    else:
        res["test"] = "wilcoxon"
        nz = diff[diff != 0]
        r = stats.wilcoxon(nz)
        res["p"] = r.pvalue
        ranks = stats.rankdata(np.abs(nz))
        pos, neg = ranks[nz > 0].sum(), ranks[nz < 0].sum()
        res["effect_size"] = (pos - neg) / (pos + neg)
        res["effect_type"] = "rank_biserial"
    return res


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--paired", required=True)
    ap.add_argument("--raw")
    ap.add_argument("--outdir", default=os.path.dirname(os.path.abspath(__file__)))
    a = ap.parse_args()
    out = os.path.join(a.outdir, "output")
    fig = os.path.join(a.outdir, "figures")
    os.makedirs(out, exist_ok=True)
    os.makedirs(fig, exist_ok=True)

    df = pd.read_csv(a.paired)
    mismatch = (df["mapHash"] == "MISMATCH").sum()
    if mismatch:
        raise SystemExit(f"{mismatch} pasangan memakai peta berbeda (mapHash MISMATCH)")

    # Tabel ringkasan mean ± std per konfigurasi (Tabel 4 & 5)
    rows = []
    for key, g in df.groupby(KEYS):
        row = dict(zip(KEYS, key))
        for name, col in METRICS.items():
            for h in ("manhattan", "euclidean"):
                v = g[f"{col}_{h}"].dropna()
                row[f"{name}_{h}"] = f"{v.mean():.3f} ± {v.std(ddof=1):.3f}"
        rows.append(row)
    summary = pd.DataFrame(rows)
    summary.to_csv(os.path.join(out, "summary_mean_std.csv"), index=False)

    # Uji statistik per konfigurasi + koreksi Holm per metrik
    results = []
    for key, g in df.groupby(KEYS):
        for name, col in METRICS.items():
            sub = g[[f"{col}_manhattan", f"{col}_euclidean"]].dropna()
            if sub.empty:
                continue
            r = compare(sub.iloc[:, 0].to_numpy(float), sub.iloc[:, 1].to_numpy(float))
            r.update(dict(zip(KEYS, key)), metric=name)
            results.append(r)
    tests = pd.DataFrame(results)
    tests["p_holm"] = np.nan
    for name in METRICS:
        m = tests["metric"] == name
        tests.loc[m, "p_holm"] = holm(tests.loc[m, "p"].to_numpy(float))
    tests["significant_holm"] = tests["p_holm"] < ALPHA
    tests.to_csv(os.path.join(out, "statistical_tests.csv"), index=False)

    gap = df[df["movementMode"] == "eightDirections"]
    gap_tab = gap.groupby(["gridSize", "obstacleDensityPct"])["costGapPct"].describe()
    gap_tab.to_csv(os.path.join(out, "cost_gap_8dir.csv"))

    with open(os.path.join(out, "report.md"), "w") as f:
        f.write("# Ringkasan (mean ± std)\n\n" + summary.to_markdown(index=False) + "\n\n")
        f.write("# Uji statistik (alpha=0.05, Holm per metrik)\n\n")
        f.write(tests.to_markdown(index=False, floatfmt=".4g") + "\n\n")
        f.write("# costGapPct 8 arah\n\n" + gap_tab.to_markdown(floatfmt=".4g") + "\n")

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    t = df.groupby(["gridSize", "movementMode"])[["timeUs_manhattan", "timeUs_euclidean"]].mean().reset_index()
    fig1, ax = plt.subplots(figsize=(6, 4))
    for mode, g in t.groupby("movementMode"):
        ax.plot(g["gridSize"], g["timeUs_manhattan"], "o-", label=f"Manhattan {mode}")
        ax.plot(g["gridSize"], g["timeUs_euclidean"], "s--", label=f"Euclidean {mode}")
    ax.set_xlabel("Ukuran grid")
    ax.set_ylabel("Waktu rata-rata (µs)")
    ax.set_yscale("log")
    ax.legend(fontsize=7)
    fig1.tight_layout()
    fig1.savefig(os.path.join(fig, "time_vs_gridsize.png"), dpi=150)

    e = df.groupby(["obstacleDensityPct", "movementMode"])[["expanded_manhattan", "expanded_euclidean"]].mean().reset_index()
    fig2, ax = plt.subplots(figsize=(6, 4))
    for mode, g in e.groupby("movementMode"):
        ax.plot(g["obstacleDensityPct"], g["expanded_manhattan"], "o-", label=f"Manhattan {mode}")
        ax.plot(g["obstacleDensityPct"], g["expanded_euclidean"], "s--", label=f"Euclidean {mode}")
    ax.set_xlabel("Kepadatan rintangan (%)")
    ax.set_ylabel("Node ter-expand (rata-rata)")
    ax.legend(fontsize=7)
    fig2.tight_layout()
    fig2.savefig(os.path.join(fig, "expanded_vs_density.png"), dpi=150)

    fig3, ax = plt.subplots(figsize=(6, 4))
    groups = [g["costGapPct"].dropna().to_numpy() for _, g in gap.groupby(["gridSize", "obstacleDensityPct"])]
    labels = [f"{k[0]}/{k[1]}%" for k, _ in gap.groupby(["gridSize", "obstacleDensityPct"])]
    ax.boxplot(groups, tick_labels=labels)
    ax.set_ylabel("costGapPct (8 arah)")
    ax.tick_params(axis="x", rotation=45)
    fig3.tight_layout()
    fig3.savefig(os.path.join(fig, "costgap_8dir_boxplot.png"), dpi=150)
    print("Selesai. Output di", out, "dan", fig)


if __name__ == "__main__":
    main()
