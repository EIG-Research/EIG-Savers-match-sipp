#!/usr/bin/env python3
"""Generate EIG themed example outputs for Python."""

from __future__ import annotations

from pathlib import Path
import sys


REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

try:
    import matplotlib.pyplot as plt
    import numpy as np
    import pandas as pd
    import seaborn as sns
    import plotly.express as px
except ImportError as exc:
    print(f"ERROR: Missing dependency: {exc}", file=sys.stderr)
    print("Install with: pip install matplotlib seaborn plotly pandas numpy", file=sys.stderr)
    raise SystemExit(2)

from themes.python.eig_theme import (
    assert_eig_fonts,
    eig_palette,
    eig_plotly_template,
    set_eig_theme,
    style_table,
)


def make_data(n: int = 140) -> pd.DataFrame:
    rng = np.random.default_rng(42)
    weight = rng.normal(3.1, 0.65, n).clip(1.5, 5.7)
    cyl = rng.choice([4, 6, 8], n, p=[0.4, 0.35, 0.25])
    origin = rng.choice(["Domestic", "Foreign"], n, p=[0.58, 0.42])
    mpg = 41.5 - 5.0 * weight - 0.75 * (cyl - 4) + rng.normal(0, 2.1, n)
    return pd.DataFrame(
        {
            "weight": weight.round(3),
            "mpg": mpg.round(2),
            "cyl": cyl,
            "origin": origin,
        }
    )


def main() -> int:
    out_dir = REPO_ROOT / "examples" / "outputs" / "python"
    out_dir.mkdir(parents=True, exist_ok=True)

    assert_eig_fonts(allow_fallback=True)
    set_eig_theme()
    df = make_data()

    fig, ax = plt.subplots()
    sns.scatterplot(
        data=df,
        x="weight",
        y="mpg",
        hue="cyl",
        palette=eig_palette("discrete"),
        ax=ax,
        alpha=0.9,
    )
    ax.set_title("Fuel Economy by Vehicle Weight", loc="left")
    ax.set_xlabel("Weight")
    ax.set_ylabel("MPG")
    ax.grid(axis="x", visible=False)
    fig.tight_layout()
    fig.savefig(out_dir / "matplotlib_scatter.png", dpi=220)
    plt.close(fig)

    summary = (
        df.groupby("origin", as_index=False)
        .agg(mean_mpg=("mpg", "mean"), mean_weight=("weight", "mean"))
        .round(2)
    )
    fig2, ax2 = plt.subplots()
    sns.barplot(
        data=summary,
        x="origin",
        y="mean_mpg",
        palette=eig_palette("discrete")[:2],
        ax=ax2,
    )
    ax2.set_title("Average MPG by Origin", loc="left")
    ax2.set_xlabel("")
    ax2.set_ylabel("Mean MPG")
    fig2.tight_layout()
    fig2.savefig(out_dir / "seaborn_bar.png", dpi=220)
    plt.close(fig2)

    fig_plotly = px.scatter(
        df,
        x="weight",
        y="mpg",
        color=df["cyl"].astype(str),
        title="Fuel Economy by Vehicle Weight (Interactive)",
        color_discrete_sequence=eig_palette("discrete"),
    )
    fig_plotly.update_layout(template=eig_plotly_template())
    fig_plotly.write_html(out_dir / "plotly_scatter.html", include_plotlyjs="cdn")

    table_df = (
        df.groupby("cyl", as_index=False)
        .agg(avg_mpg=("mpg", "mean"), avg_weight=("weight", "mean"))
        .round(2)
    )
    styled = style_table(table_df)
    (out_dir / "styled_table.html").write_text(styled.to_html(), encoding="utf-8")

    print(f"Wrote outputs to: {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
