# Agent 04: Python Specialist (First Pass)

## Scope
Translate `docs/agent-01-design-spec.md` into reusable Python style code for:
- `matplotlib` / `seaborn`
- `plotly`
- Table styling with `pandas.Styler`

## 1) Setup and Font Installation Prompts
```bash
# Package install prompt
pip install matplotlib seaborn plotly pandas numpy requests
```

```python
# Font download/install prompt (run once)
from pathlib import Path
import requests
import matplotlib.font_manager as fm

font_dir = Path.home() / ".local" / "share" / "fonts" / "eig"
font_dir.mkdir(parents=True, exist_ok=True)

font_urls = {
    "OpenSans-Regular.ttf": "https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-Regular.ttf",
    "OpenSans-SemiBold.ttf": "https://github.com/google/fonts/raw/main/apache/opensans/OpenSans-SemiBold.ttf",
    "SourceSerifPro-SemiBold.ttf": "https://github.com/google/fonts/raw/main/ofl/sourceserif4/SourceSerif4-SemiBold.ttf",
}

for filename, url in font_urls.items():
    out = font_dir / filename
    if not out.exists():
        out.write_bytes(requests.get(url, timeout=30).content)
    fm.fontManager.addfont(str(out))
```

## 2) Design Tokens
```python
EIG_COLORS = {
    "eig_teal_900": "#024140",
    "eig_green_700": "#19644D",
    "eig_green_500": "#5E9C86",
    "eig_blue_800": "#194F8B",
    "eig_blue_200": "#B3D6DD",
    "eig_cream_100": "#FEECD6",
    "eig_purple_800": "#39274F",
    "eig_gold_600": "#E1AD28",
    "eig_cyan_700": "#176F96",
    "eig_tan_500": "#D6936F",
    "eig_tan_300": "#F0B799",
    "eig_black": "#000000",
    "eig_white": "#FFFFFF",
}

EIG_DISCRETE = [
    EIG_COLORS["eig_teal_900"],
    EIG_COLORS["eig_blue_800"],
    EIG_COLORS["eig_green_500"],
    EIG_COLORS["eig_gold_600"],
    EIG_COLORS["eig_purple_800"],
    EIG_COLORS["eig_cyan_700"],
    EIG_COLORS["eig_tan_500"],
]

EIG_SEQ_BLUE = ["#164C87", "#236BB7", "#419EF1", "#79C5FD", "#C1DCFD"]
EIG_SEQ_RED  = ["#97310E", "#D34917", "#F97D1E", "#FBA94F", "#FDD7A8"]

EIG_LEGACY = {
    "dci_quintile": {
        "distressed": "#97310E",
        "at_risk": "#F97D1E",
        "mid_tier": "#9FD2C0",
        "comfortable": "#419EF1",
        "prosperous": "#164C87",
    }
}
```

## 3) Matplotlib / Seaborn Theme
```python
import matplotlib.pyplot as plt
import seaborn as sns

def set_eig_theme():
    plt.rcParams.update({
        "figure.figsize": (6.5, 3.5),
        "figure.facecolor": EIG_COLORS["eig_white"],
        "axes.facecolor": EIG_COLORS["eig_white"],
        "axes.edgecolor": "#CFCFCF",
        "axes.labelcolor": EIG_COLORS["eig_black"],
        "axes.titlecolor": EIG_COLORS["eig_black"],
        "axes.titlesize": 15,
        "axes.titleweight": "semibold",
        "axes.titlelocation": "left",
        "xtick.color": EIG_COLORS["eig_black"],
        "ytick.color": EIG_COLORS["eig_black"],
        "grid.color": "#D9D9D9",
        "grid.linewidth": 0.6,
        "font.family": "Open Sans",
        "text.color": EIG_COLORS["eig_black"],
        "legend.frameon": False,
    })
    sns.set_palette(EIG_DISCRETE)
    sns.set_style("whitegrid", {"axes.grid.axis": "y", "axes.grid": True})
```

### Example (`matplotlib` + `seaborn`)
```python
import pandas as pd

set_eig_theme()
df = sns.load_dataset("mpg").dropna(subset=["weight", "mpg", "origin"])

fig, ax = plt.subplots()
sns.scatterplot(data=df, x="weight", y="mpg", hue="origin", ax=ax)
ax.set_title("Fuel Economy by Vehicle Weight", fontname="Source Serif Pro")
ax.set_xlabel("Weight")
ax.set_ylabel("MPG")
ax.grid(axis="x", visible=False)
plt.tight_layout()
plt.show()
```

## 4) Plotly Theme
```python
import plotly.graph_objects as go

def eig_plotly_template():
    return go.layout.Template(
        layout=dict(
            font=dict(family="Open Sans", size=11, color=EIG_COLORS["eig_black"]),
            title=dict(font=dict(family="Source Serif Pro", size=20, color=EIG_COLORS["eig_black"]), x=0),
            colorway=EIG_DISCRETE,
            paper_bgcolor=EIG_COLORS["eig_white"],
            plot_bgcolor=EIG_COLORS["eig_white"],
            xaxis=dict(showgrid=False, zeroline=False),
            yaxis=dict(showgrid=True, gridcolor="#D9D9D9", zeroline=False),
            legend=dict(bgcolor="rgba(0,0,0,0)"),
        )
    )
```

### Example (`plotly`)
```python
import plotly.express as px

fig = px.scatter(
    df, x="weight", y="mpg", color="origin",
    title="Fuel Economy by Vehicle Weight",
    color_discrete_sequence=EIG_DISCRETE
)
fig.update_layout(template=eig_plotly_template())
fig.show()
```

## 5) Table Styling (`pandas.Styler`)
```python
import pandas as pd

def eig_style_table(df: pd.DataFrame):
    return (
        df.style
        .set_table_styles([
            {"selector": "th", "props": [
                ("background-color", EIG_COLORS["eig_teal_900"]),
                ("color", EIG_COLORS["eig_white"]),
                ("font-family", "Open Sans"),
                ("font-size", "10pt"),
                ("font-weight", "600"),
                ("text-align", "left"),
                ("border", "0")
            ]},
            {"selector": "td", "props": [
                ("font-family", "Open Sans"),
                ("font-size", "9pt"),
                ("color", EIG_COLORS["eig_black"]),
                ("border-top", "1px dotted #D9D9D9"),
                ("border-bottom", "1px dotted #D9D9D9"),
                ("border-left", "0"),
                ("border-right", "0")
            ]},
            {"selector": "table", "props": [("border-collapse", "collapse")]}
        ])
    )
```

### Example (table)
```python
tbl = df[["origin", "mpg", "horsepower"]].groupby("origin").mean().round(1).reset_index()
styled = eig_style_table(tbl)
styled
```

## 6) Coverage Checklist
- Matplotlib/seaborn static figures: yes
- Plotly interactive figures: yes
- Table outputs via pandas Styler: yes
- Legacy semantic palette bridge: included
