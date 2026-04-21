"""EIG plotting/table theme helpers for Python."""

from __future__ import annotations

from typing import Iterable

import matplotlib.font_manager as fm
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns
import plotly.graph_objects as go

try:
    from .eig_tokens import (
        BRAND_COLORS,
        EIG_DISCRETE,
        LEGACY_SEMANTIC_SETS,
        SEQUENTIAL,
        TYPOGRAPHY,
        SIZING,
    )
except ImportError:
    from eig_tokens import (  # type: ignore
        BRAND_COLORS,
        EIG_DISCRETE,
        LEGACY_SEMANTIC_SETS,
        SEQUENTIAL,
        TYPOGRAPHY,
        SIZING,
    )


def _installed_fonts() -> set[str]:
    return {f.name for f in fm.fontManager.ttflist if getattr(f, "name", None)}


def assert_eig_fonts(allow_fallback: bool = False) -> None:
    """Raise RuntimeError when required fonts are not available."""
    available = _installed_fonts()
    headline_primary = TYPOGRAPHY["headline"]["primary_family"]
    body_primary = TYPOGRAPHY["body"]["primary_family"]

    if not allow_fallback:
        missing = [x for x in (headline_primary, body_primary) if x not in available]
        if missing:
            raise RuntimeError(
                "Missing required EIG primary fonts: "
                + ", ".join(missing)
                + ". Run scripts/fonts installers and restart session."
            )
        return

    headline_stack = [headline_primary] + TYPOGRAPHY["headline"]["fallback_stack"]
    body_stack = [body_primary] + TYPOGRAPHY["body"]["fallback_stack"]
    if not any(x in available for x in headline_stack):
        raise RuntimeError(f"No available headline font in stack: {headline_stack}")
    if not any(x in available for x in body_stack):
        raise RuntimeError(f"No available body font in stack: {body_stack}")


def eig_palette(name: str = "discrete") -> list[str]:
    if name == "discrete":
        return list(EIG_DISCRETE)
    if name in SEQUENTIAL:
        return list(SEQUENTIAL[name])
    if name in LEGACY_SEMANTIC_SETS:
        return list(LEGACY_SEMANTIC_SETS[name].values())
    raise KeyError(f"Unknown EIG palette: {name}")


def set_eig_theme(figsize: tuple[float, float] | None = None) -> None:
    if figsize is None:
        fig = SIZING["figure_default"]
        figsize = (float(fig["width_in"]), float(fig["height_in"]))

    plt.rcParams.update(
        {
            "figure.figsize": figsize,
            "figure.facecolor": BRAND_COLORS["eig_white"],
            "axes.facecolor": BRAND_COLORS["eig_white"],
            "axes.edgecolor": "#CFCFCF",
            "axes.labelcolor": BRAND_COLORS["eig_black"],
            "axes.titlecolor": BRAND_COLORS["eig_black"],
            "axes.titlesize": 15,
            "axes.titleweight": "semibold",
            "axes.titlelocation": "left",
            "xtick.color": BRAND_COLORS["eig_black"],
            "ytick.color": BRAND_COLORS["eig_black"],
            "grid.color": "#D9D9D9",
            "grid.linewidth": 0.6,
            "font.family": TYPOGRAPHY["body"]["primary_family"],
            "text.color": BRAND_COLORS["eig_black"],
            "legend.frameon": False,
        }
    )
    sns.set_palette(EIG_DISCRETE)
    sns.set_style("whitegrid", {"axes.grid.axis": "y", "axes.grid": True})


def eig_plotly_template() -> go.layout.Template:
    return go.layout.Template(
        layout=dict(
            font=dict(
                family=TYPOGRAPHY["body"]["primary_family"],
                size=11,
                color=BRAND_COLORS["eig_black"],
            ),
            title=dict(
                font=dict(
                    family=TYPOGRAPHY["headline"]["primary_family"],
                    size=20,
                    color=BRAND_COLORS["eig_black"],
                ),
                x=0,
            ),
            colorway=list(EIG_DISCRETE),
            paper_bgcolor=BRAND_COLORS["eig_white"],
            plot_bgcolor=BRAND_COLORS["eig_white"],
            xaxis=dict(showgrid=False, zeroline=False),
            yaxis=dict(showgrid=True, gridcolor="#D9D9D9", zeroline=False),
            legend=dict(bgcolor="rgba(0,0,0,0)"),
        )
    )


def style_table(df: pd.DataFrame) -> pd.io.formats.style.Styler:
    return df.style.set_table_styles(
        [
            {
                "selector": "th",
                "props": [
                    ("background-color", BRAND_COLORS["eig_teal_900"]),
                    ("color", BRAND_COLORS["eig_white"]),
                    ("font-family", TYPOGRAPHY["body"]["primary_family"]),
                    ("font-size", "10pt"),
                    ("font-weight", "600"),
                    ("text-align", "left"),
                    ("border", "0"),
                ],
            },
            {
                "selector": "td",
                "props": [
                    ("font-family", TYPOGRAPHY["body"]["primary_family"]),
                    ("font-size", "9pt"),
                    ("color", BRAND_COLORS["eig_black"]),
                    ("border-top", "1px dotted #D9D9D9"),
                    ("border-bottom", "1px dotted #D9D9D9"),
                    ("border-left", "0"),
                    ("border-right", "0"),
                ],
            },
            {"selector": "table", "props": [("border-collapse", "collapse")]},
        ]
    )

