# code/05_figures/

Publication figures for the cost memo, built with ggplot2 and the EIG style tokens.

## `05a_cost_comparison_figures.R`

**Role.** Builds the two cost-memo figures (replaces the deprecated Python `build_sm_chart.py`).
Reads the scenario costs produced by `03a_jct_replication.R`.

**Writes.**
- `output/figures/main/sm_cost_comparison.png` (Figure 1) + `sm_cost_comparison_data.csv`
- `output/figures/main/sm_robustness_grouped.png` (Figure 2) + `sm_robustness_grouped_data.csv`
