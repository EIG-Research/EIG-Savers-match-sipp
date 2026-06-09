# code/03_cost_simulation/

Fiscal-cost simulation of the Saver's Match: current-law (1.00×) JCT replication and the
1.25× / 1.50× / 2.00× threshold-scaling counterfactuals.

## `03a_jct_replication.R`

**Role.** Core cost simulation. Replicates the JCT JCX-21-22 methodology on SIPP 2024 microdata,
projected to tax year 2027, and produces the headline scenarios (current law plus the four AGI-threshold
multipliers) under varying participation assumptions.

**Reads.**
- `code/_shared/calibration_cells.R` (sourced for thresholds and `build_modeled_sipp_frame_v2()`).
- `data/raw/pu2024_expanded.csv` (from `01_sipp_subset_from_dta.R`).
- `data/raw/irs_soi/22in01pl.xls` (IRS SOI calibration benchmark).

**Writes.** `output/tables/main/sm_jct_replication_scenarios.xlsx` and a parquet checkpoint consumed
by `03b`.

## `03b_robustness_sweep.R`

**Role.** Robustness sweep across alternative participation, take-up, and contribution-distribution
assumptions. Consumes the `03a` checkpoint.

**Writes.** `output/tables/main/sm_robustness_scenarios.xlsx`.

## `03c_simple_saver_illustration.R`

**Role.** Standalone single-saver illustration (match received and NPV for an example filer). No
microdata dependency.

**Writes.** `output/tables/appendix/simple_saver_illustration*` and
`output/figures/appendix/simple_saver_illustration*.png`.
