# Pipeline input/output manifest

Exact inputs and outputs of every stage in `run_all.R`, and the artifact dependencies between stages.
Derived from the read/write calls in the code (2026-06-08). All stages from `02` onward read the one
canonical frame `data/processed/sipp_modeled.parquet`.

## Dependency graph (artifact flow)

```
data/raw/pu2024.dta
   │  01_sipp_subset_from_dta.R
   ▼
data/raw/pu2024_expanded.csv (+ .parquet, + _variable_manifest.csv)
   │  01b_build_modeled_frame.R   (+ data/raw/irs_soi/22in01pl.xls via params, indirectly)
   ▼
data/processed/sipp_modeled.parquet (+ .rds)   ← THE canonical frame; + data/processed/params.json
   ├─► 02a_eligibility_buckets.R ─► eligibility bucket tables + report
   │        └─► 02b_filing_match_decomposition.R (also reads 02a's buckets.rds to reconcile)
   ├─► 03a_jct_replication.R ─► sm_jct_replication_scenarios.xlsx ─► 05a figures
   ├─► 03b_robustness_sweep.R ─► sm_robustness_scenarios.xlsx + snapshot json
   └─► 04_universal_hybrid (04_01 reads frame) ─► universe_dec ─► pivots ─► sim ─► tables/figures/lenses

03c_simple_saver_illustration.R : standalone (no microdata input); reads nothing from the frame.
```

## Per-stage I/O

| Stage | Reads | Writes |
|---|---|---|
| **00_config.R** | `PROJECT.md` (root marker) | (sets paths/params/helpers in memory; no files) |
| **00b_reexport_dta_to_csv.R** (optional, off) | `data/raw/pu2024.dta` | `data/raw/pu2024.csv` |
| **01_sipp_subset_from_dta.R** (auto-skips if extract exists) | `data/raw/pu2024.dta` | `data/raw/pu2024_expanded.csv`, `pu2024_expanded.parquet`, `pu2024_expanded_variable_manifest.csv` |
| **01b_build_modeled_frame.R** | `data/raw/pu2024_expanded.csv` | `data/processed/sipp_modeled.parquet`, `sipp_modeled.rds`, `data/processed/params.json` |
| **02a_eligibility_buckets.R** | `data/processed/sipp_modeled.parquet` | `output/tables/savers_match_eligibility_buckets.{rds,parquet}`, `..._filerbasis.{rds,parquet}`; `output/reports/savers_match_eligibility_buckets.md` |
| **02b_filing_match_decomposition.R** | `sipp_modeled.parquet`; `output/tables/savers_match_eligibility_buckets.rds` (reconcile) | `output/tables/answers_eligibility_by_filing_match.{rds,parquet,xlsx}`, `..._account_holders_by_filing_match.{rds,parquet,xlsx}`, `..._access_gap_by_filing_match.{rds,parquet,xlsx}` |
| **03a_jct_replication.R** | `sipp_modeled.parquet` | `output/tables/main/sm_jct_replication_scenarios.xlsx` |
| **03b_robustness_sweep.R** | `sipp_modeled.parquet` | `output/tables/main/sm_robustness_scenarios.xlsx`; `output/data/intermediate_results/sm_robustness_snapshot.json` |
| **03c_simple_saver_illustration.R** | none (self-contained; optional temp bridge snapshot, absent → skipped) | `output/tables/appendix/simple_saver_illustration.{rds,parquet}`, `..._summary.{rds,parquet}`, `simple_saver_illustration.xlsx`. **Figures gated OFF** (`WRITE_FIGURE=FALSE`) — no PNGs written. |
| **04_01_build_universe.R** | `sipp_modeled.parquet` | `data/processed/universal_sm_hybrid/universe_dec.{rds,parquet}`; `output/reports/universal_sm_hybrid/universe_funnel.csv`, `universe_summary_stats.{csv,md}` |
| **04_02_compute_pivots.R** | `universe_dec.parquet` | `data/processed/universal_sm_hybrid/pivot_table.{rds,parquet}`; `output/reports/universal_sm_hybrid/pivot_diagnostics.md` |
| **04_03_simulate_match.R** | `universe_dec.parquet`, `pivot_table.rds` | `data/processed/universal_sm_hybrid/scenario_results.parquet`, `simulation_results.parquet`; `output/reports/universal_sm_hybrid/scenario_diagnostics.md` |
| **04_04_build_tables.R** | `scenario_results.parquet`, `simulation_results.parquet`, `pivot_table.rds` | `output/tables/universal_sm_hybrid/hybrid_headline.xlsx`, `hybrid_distributional_incidence.xlsx`, `hybrid_by_route.xlsx` |
| **04_05_build_figures.R** | `pivot_table.rds`, `simulation_results.parquet`, `universe_funnel.csv` | `output/figures/universal_sm_hybrid/match_rate_by_magi.png`, `incidence_by_decile.png`, `universe_funnel.png`, `universe_magi_distribution.png`; `output/data/figure_data/universal_sm_hybrid_{match_rate_schedule,incidence_by_decile,universe_funnel,universe_magi_distribution}.csv` |
| **04_06_phaseout_lenses.R** | `pivot_table.rds` | `output/figures/universal_sm_hybrid/lens_0{1,2,3}_*.png`; `output/data/figure_data/universal_sm_hybrid_phaseout_lenses.csv`; `data/processed/universal_sm_hybrid/phaseout_lenses.{parquet,rds}`; `output/reports/universal_sm_hybrid/phaseout_lenses_anchors.md` |
| **05a_cost_comparison_figures.R** | `output/tables/main/sm_jct_replication_scenarios.xlsx` | `output/figures/main/sm_cost_comparison.png`, `sm_robustness_grouped.png`; `output/data/figure_data/sm_cost_comparison_data.csv`, `sm_robustness_grouped_data.csv` |
| **06_universal_hybrid_brief.R** | `data/processed/universal_sm_hybrid/{scenario_results.parquet,pivot_table.rds,simulation_results.parquet}`, `output/reports/universal_sm_hybrid/universe_funnel.csv`, `output/figures/universal_sm_hybrid/{match_rate_by_magi,incidence_by_decile,universe_funnel}.png`, `output/tables/main/sm_jct_replication_scenarios.xlsx` | `output/reports/universal_sm_hybrid/universal_hybrid_brief.html` |

## Expected output inventory (what a clean `run_all.R` should (re)write)

**data/processed/** — `sipp_modeled.{parquet,rds}`, `params.json`, and `universal_sm_hybrid/`:
`universe_dec.{rds,parquet}`, `pivot_table.{rds,parquet}`, `scenario_results.parquet`,
`simulation_results.parquet`, `phaseout_lenses.{parquet,rds}`.

**output/tables/** — `savers_match_eligibility_buckets{,_filerbasis}.{rds,parquet}`,
`answers_eligibility_{by_filing_match,account_holders_by_filing_match,access_gap_by_filing_match}.{rds,parquet,xlsx}`;
`main/sm_jct_replication_scenarios.xlsx`, `main/sm_robustness_scenarios.xlsx`;
`appendix/simple_saver_illustration{,_summary}.{rds,parquet}` + `simple_saver_illustration.xlsx`;
`universal_sm_hybrid/hybrid_{headline,distributional_incidence,by_route}.xlsx`.

**output/figures/** — `main/sm_cost_comparison.png`, `main/sm_robustness_grouped.png`;
`universal_sm_hybrid/{match_rate_by_magi,incidence_by_decile,universe_funnel,universe_magi_distribution,lens_01_match_rate,lens_02_required_contribution,lens_03_required_share_of_earnings}.png`.

**output/reports/** — `savers_match_eligibility_buckets.md`;
`universal_sm_hybrid/{universe_funnel.csv,universe_summary_stats.csv,universe_summary_stats.md,pivot_diagnostics.md,scenario_diagnostics.md,phaseout_lenses_anchors.md,universal_hybrid_brief.html}`.

**output/data/figure_data/** — `sm_cost_comparison_data.csv`, `sm_robustness_grouped_data.csv`,
`universal_sm_hybrid_{match_rate_schedule,incidence_by_decile,universe_funnel,universe_magi_distribution,phaseout_lenses}.csv`.

**output/data/intermediate_results/** — `sm_robustness_snapshot.json`.

## Known NOT-(re)produced by a default run (candidates for stale orphans)
- `output/figures/appendix/simple_saver_illustration{,_real}.png` — `03c` figures are gated off.
- `output/tables/appendix/simple_saver_illustration_sensitivity.{csv,parquet}` — not written by current `03c`.
- `output/data/intermediate_results/sm_simulation_snapshot.json` — `03a` (rewritten) no longer writes a snapshot.
- `output/figures/main/sm_cost_comparison_data.csv` — `05a` writes this CSV to `figure_data/`, not `figures/main/`.
- `output/figures/universal_sm_hybrid/lens_01_match_rate.pdf` — `04_06` writes `.png`, not `.pdf`.
- `output/data/figure_data/sm_scenario_results.csv`, `sm_robustness_results.csv` — produced by the retired Python port.

## Verification (run 2026-06-09)
`run_all.R` executed end-to-end (all stages OK). Every file in the "Expected output inventory" was
freshly (re)written, and the 9 files in "Known NOT-(re)produced" were confirmed as the only non-refreshed
artifacts — all of them stale orphans, now removed. Post-removal, **every file in `output/` and
`data/processed/` is produced by a pipeline stage** (no orphans remain). Spot-checked headline values:
cost m100/m125/m150/m200 = $9,192 / $16,114 / $24,267 / $41,067M; eligibility B1/B2/B3 = 33.08 / 12.73 /
3.02M.
