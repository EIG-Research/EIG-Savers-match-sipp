# EIG Figure & Table Style Guide

Cross-tool standards for charts, maps, and tables in EIG publications. Apply these rules in R, Python, Stata, and Excel. See the `Infrastructure/style/themes/` directory for ready-to-use code templates.

---

## 1. EIG Color Sequence for Data Series

Use this order for discrete data series (line charts, bar charts, grouped bars, etc.). Do not skip colors or change the order without a documented reason.

| Order | Name | Hex |
|-------|------|-----|
| 1 | Forest Green (primary) | `#19644d` |
| 2 | Gold | `#E1AD28` |
| 3 | Medium Blue | `#176F96` |
| 4 | Terra Cotta | `#D6936F` |
| 5 | Navy | `#194F8B` |
| 6 | Sage Green | `#5E9C86` |
| 7 | Purple | `#39274F` |
| 8 | Dark Teal | `#024140` |
| 9 | Peach | `#F0B799` |
| 10 | Light Blue | `#B3D6DD` |

### Notes on Color Use
- For single-series charts, use Forest Green (`#19644d`) as the default.
- For two-series charts, use Forest Green and Gold.
- For highlight/callout elements (e.g., one bar in a bar chart), use Gold.
- For diverging color scales (maps, heatmaps): use Forest Green (high/positive) → Light neutral → Terra Cotta or Gold (low/negative). Avoid pure red/green for accessibility.
- **Colorblind accessibility:** The default EIG sequence has not been validated against all colorblindness types. For publications with a public accessibility requirement, check using a colorblind simulation tool (e.g., Viz Palette, Coblis). Consider adding direct data labels to reduce color dependency.

---

## 2. Font Rules for Figures

EIG brand fonts are **Tiempos Text** (serif) and **Galaxie Polaris** (sans-serif). Font files are in `Infrastructure/style/assets/fonts/`; installation instructions are in `Infrastructure/style/assets/fonts/INSTALL.md`.

| Element | EIG Font | Fallback | Size (Print) | Size (Web/Screen) |
|---------|----------|---------|-------------|-------------------|
| Figure title / chart title | Tiempos Text Semibold | Georgia Bold | 11pt | 14px |
| Axis titles | Galaxie Polaris Book | Arial | 9pt | 12px |
| Axis labels (tick labels) | Galaxie Polaris Book | Arial | 8pt | 11px |
| Data labels | Galaxie Polaris Book | Arial | 7—8pt | 10—12px |
| Legend text | Galaxie Polaris Book | Arial | 8pt | 11px |
| Source / Note lines | Galaxie Polaris Light (italic) | Arial Italic | 7pt | 10px |

- **R / ggplot2:** Use `systemfonts::register_font()` to load Galaxie Polaris and Tiempos Text from `Infrastructure/style/assets/fonts/`. Use `ragg::agg_png()` as the graphics device to render them. Fall back to `"sans"` (Arial) if unavailable. See `Infrastructure/style/assets/fonts/INSTALL.md`.
- **Python / Matplotlib:** Use `matplotlib.font_manager.addfont()` to load fonts from `Infrastructure/style/assets/fonts/`. Set `rcParams["font.family"] = "Galaxie Polaris"`. Fall back to `"DejaVu Sans"`. See `Infrastructure/style/assets/fonts/INSTALL.md`.
- **Stata:** Install fonts via Windows font manager, then `graph set window fontface "Galaxie Polaris Book"`. The `eig_theme.do` template handles this with `capture`. See `Infrastructure/style/assets/fonts/INSTALL.md`.
- **Excel:** Set chart title font to Galaxie Polaris Semibold if installed; otherwise Calibri or Aptos Display. Set axis label font to Galaxie Polaris Book; otherwise Calibri or Arial.

---

## 3. Axis, Label, and Title Conventions

### Figure Title
- **Prefix:** "Figure N." — capital F, Arabic numeral, period. E.g., "Figure 1."
- **Caption:** Sentence case — capitalize only the first word and proper nouns.
- **Full format example:** `Figure 1. Share of workers earning below $15 per hour, 2000—2022`
- **In code:** Set as subtitle or annotation below the main plot area, not as the ggplot `ggtitle()` / matplotlib `title()` (which places it above). Many EIG figures include the title in the surrounding document text rather than in the figure itself — confirm with the layout designer.

### Axis Titles
- Sentence case; keep concise.
- Include units in parentheses: "Annual earnings (2023 dollars)"; "Share of workers (%)".
- Y-axis: horizontal label preferred over rotated where space permits.

### Tick Labels
- No unnecessary decimal places. Round to the precision that the data supports.
- Commas for thousands separators in numbers ≥ 1,000.
- Percent sign (%) in chart axis/tick labels (not "percent" spelled out — that rule is for body text only).
- Date axis: "2000," "2005," "2010" (year only, no "Jan 2000" unless month-level precision matters).

### Gridlines
- Horizontal gridlines: light gray (`#D9D9D9` or similar), thin (0.5pt).
- No vertical gridlines in standard bar/line charts.
- No border/box around the plot area.
- White or very light gray (`#F5F5F5`) plot background.

### Legend
- Position: right of plot or below plot — not overlapping data.
- No legend border.
- Label matches series name exactly (one-word-per-meaning rule applies).
- If the chart has only one series, omit the legend and label the series directly on the chart.

---

## 4. Source Line Format

Every figure must have a source line. Format:

```
Source: [Full Organization Name], [Year or Dataset Version].
```

- Italicize the source line in the layout where possible.
- Place below the figure, below any note line.
- Write out the source name in full if three words or fewer.
- If the source name is longer than three words, it may be abbreviated after first use in the document — but spell it out fully in the source line.
- For multiple sources: "Sources: [Source 1], [Year]; [Source 2], [Year]."
- For author-produced analysis: "Source: Author's analysis of [Dataset], [Year]."

### Note Line (Optional)
- Format: "Note: [Text]."
- Place above the source line.
- Use for methodological caveats, suppressed data, definitions, or rounding notices.
- Keep to one or two sentences. Move longer methodological notes to a footnote.

---

## 5. Per-Tool Quick Reference

| Tool | Template File | Key Features |
|------|--------------|--------------|
| R / ggplot2 | `Infrastructure/style/themes/r/eig_theme.R` | `eig_theme_ggplot()`, `eig_scale_color()`, `eig_scale_fill()` |
| R / Base R | `Infrastructure/style/themes/r/eig_theme.R` | `eig_base_defaults()`, `eig_palette()` |
| R / Plotly | `Infrastructure/style/themes/r/eig_theme.R` | `eig_plotly_layout()` |
| Python / Matplotlib | `Infrastructure/style/themes/python/eig_theme.py` | `set_eig_theme()` |
| Python / Plotly | `Infrastructure/style/themes/python/eig_theme.py` | `eig_plotly_template()` |
| Stata | `Infrastructure/style/themes/stata/eig_theme.do` | `eig_graph_defaults()`, color macros |
| Excel | *(Manual — no template file)* | See rules below |

### Excel Figure Rules (Manual Application)
- Chart type: Prefer line charts for time series; clustered bar for comparisons; map charts for geography.
- Remove chart border (Format Chart Area → No border).
- Remove gridlines or set to light gray, thin.
- Set font to Calibri or Aptos; chart title to Aptos Display or Calibri Bold.
- Apply EIG color sequence to data series manually.
- Delete the legend if only one series; otherwise, move legend below the chart.
- Add a text box below the chart for the "Source:" and "Note:" lines; set font to Calibri Italic, 8pt.

---

## 6. Accessibility Notes

- **Contrast:** All text elements (titles, labels, tick marks) must meet WCAG AA contrast against the background (4.5:1 for ≤18pt text).
- **Color independence:** Never encode information through color alone. Add:
  - Direct data labels on bars/lines
  - Distinct line styles (solid, dashed, dotted) for line charts
  - Pattern fills for bar charts if color printing is uncertain
- **Alt text:** For web-published figures, write descriptive alt text summarizing the chart's key finding (not its visual description).
  - Example: `alt="Bar chart showing that the bottom income quintile's wage growth lagged the top quintile by 12 percentage points between 2000 and 2022."`
- **Minimum font sizes:** Do not reduce figure text below 7pt (print) or 10px (screen).

---

## 7. Figure Checklist

Before finalizing any figure:

- [ ] "Figure N." prefix in sentence-case caption
- [ ] Source line present and formatted correctly
- [ ] EIG color sequence used in correct order
- [ ] No vertical gridlines; horizontal gridlines are light gray
- [ ] No plot border
- [ ] Font matches EIG guidelines (or approved fallback)
- [ ] Axis tick labels: % symbol (not "percent"), commas for thousands, minimal decimal places
- [ ] Legend positioned correctly (or direct labels used)
- [ ] Colorblind accessibility checked for public-facing publications
- [ ] Alt text written for web publication




