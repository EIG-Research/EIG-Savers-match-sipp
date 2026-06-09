# 04 Universal Account + Saver's Match Hybrid Simulation

Simulation scripts for the policy described in `Infrastructure/specs/2026-05-27_universal-account-savers-match-hybrid.md`.

## Read order

1. `04_01_build_universe.R` — restrict the canonical frame to the **Saver's Match analysis universe** (`in_universe`: age 18+, non-dependent, non-student, positive annual earnings, valid filing group) — the SAME universe as the Saver's Match simulations, all classes of worker including government. Worker-class flags are carried only to drive the employer-plan vs. universal-account routing in 04_03, not to filter the population.
2. `04_02_compute_pivots.R` — compute weighted median MAGI by filing group inside the analysis universe; set `sm_pivot_2024_num = 0.75 × median`. Writes a diagnostics CSV to `output/reports/universal_sm_hybrid/`.
3. `04_03_simulate_match.R` — apply the piecewise-linear match rate schedule per Section 3 of the spec and compute the implicit `min(rate × contribution, $1,000)` cap. Routes workers into either the employer plan (where `any_retirement_access_v2_chr == "Yes"`) or the federal universal account.
4. `04_04_build_tables.R` — produce headline and sensitivity tables. Writes to `output/tables/universal_sm_hybrid/`.
5. `04_05_build_figures.R` — produce the match-rate-by-MAGI line, the distributional incidence chart, and the universe-funnel diagnostic. Writes to `output/figures/universal_sm_hybrid/`.
6. `04_06_phaseout_lenses.R` — three visual lenses on the hybrid phaseout (Single filer). Writes to `output/figures/universal_sm_hybrid/`.

Run all six in order via the master `code/04_universal_hybrid/04_universal_sm_hybrid.R` (or `code/run_all.R`).

## Dependencies

Upstream: `code/01_data_preparation/01_sipp_subset_from_dta.R` must complete with the refreshed retirement-contribution flow variables before any 04 script can run. See `Infrastructure/plans/2026-05-27_universal-sm-hybrid-implementation.md` for the variable list and the §6433 MAGI rationale.

Shared utilities consumed from `code/_shared/calibration_cells.R`:

- `aggregate_sipp_person_year()` — Option B observed-months annualization
- `make_filing_group()` — EFSTATUS → Single/MFS, HoH, MFJ
- `build_modeled_sipp_frame_v2()` — produces `any_retirement_access_v2_chr`, `HAS_EXISTING_DC`, `PARTICIPATING_DC`, U1 spouse-pair SM_INCOME, and the contribution-rate quantile assignment
- `sm_pivot_2024_num` — new named numeric vector to be added with this simulation (pivot table)
- `compute_match_rate()` — new helper to be added with this simulation, pending RA-review approval per Ben's R-style rule

Reused from `code/03_cost_simulation/03a_jct_replication.R`:

- The `run_scenario()` helper for the weighted-selection participation mechanic (inline copy, not source — 03a is too coupled to the four-multiplier output schema to source directly)
- The funnel-step weighted-count diagnostic pattern

## Outputs

- `data/processed/universal_sm_hybrid/` — intermediate parquet and rds checkpoints
- `output/tables/universal_sm_hybrid/` — final tables
- `output/figures/universal_sm_hybrid/` — final figures
- `output/reports/universal_sm_hybrid/` — diagnostic logs (pivot table, universe funnel, scenario sensitivity)
- `drafts/universal_sm_hybrid/` — memo, two-pager, and any social or blog drafts
