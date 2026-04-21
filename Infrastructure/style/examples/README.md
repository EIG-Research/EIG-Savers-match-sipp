# EIG Example Outputs

This folder contains end-to-end example scripts that use the shared token-driven themes.

## Prerequisites
1. Sync tokens:
   `python3 scripts/sync_tokens.py`
2. Install fonts with an OS script in `scripts/fonts/`.
3. Run font checks:
   - Python: `python3 scripts/fonts/check-fonts.py --allow-fallback`
   - R: `Rscript scripts/fonts/check-fonts.R --allow-fallback`
   - Stata: `do scripts/fonts/check-fonts.do allow_fallback`

## Run Python Examples
`python3 examples/python/generate_examples.py`

Outputs:
- `examples/outputs/python/matplotlib_scatter.png`
- `examples/outputs/python/seaborn_bar.png`
- `examples/outputs/python/plotly_scatter.html`
- `examples/outputs/python/styled_table.html`

## Run R Examples
`Rscript examples/r/generate_examples.R`

Outputs:
- `examples/outputs/r/base_scatter.png`
- `examples/outputs/r/ggplot_scatter.png` (if `ggplot2` installed)
- `examples/outputs/r/plotly_scatter.html` (if `plotly` + `htmlwidgets` installed)
- `examples/outputs/r/gt_table.html` (if `gt` installed)

## Run Stata Examples
Run in Stata from repo root:
`do examples/stata/generate_examples.do`

Outputs:
- `examples/outputs/stata/twoway_scatter.png`
- `examples/outputs/stata/bar_chart.png`
- `examples/outputs/stata/eig_table_example.docx`
