# Saver's Match: Eligibility and Cost Analysis

Eligibility, access-gap, and fiscal-cost estimates for the Saver's Match under SECURE 2.0 §103
(IRC sec 6433), projected to tax year 2027, using SIPP 2024 Wave 1 microdata. The repo covers three
bodies of work: the eligible-population buckets, the current-law (1.00×) and expanded (1.25× / 1.50× /
2.00×) cost simulations, and the Universal Saver's Match hybrid proposal.

## What this repo does

1. **Eligibility bucketing** — counts workers in three nested tiers:
   - **Bucket 1**: any-match eligible (AGI below the upper phase-out threshold)
   - **Bucket 2**: full-match eligible (AGI at or below the full-match threshold)
   - **Bucket 3**: full-match eligible AND currently holds a qualifying retirement account

2. **Access gap analysis** — of the any-match eligible population (B1), how many already hold a qualifying account vs. how many would need to open one (B1 without account)

3. **Filing-status × match-status decomposition** — three contingency tables (full universe, account holders, access gap) produced by `code/02_eligibility/02b_filing_match_decomposition.R`. Reconciles cell-by-cell to the published bucket totals.

Eligibility counts are reported on both a worker basis (each adult counted separately; the primary public-facing unit) and a filer basis (MFJ couples collapsed to one filer; useful for fiscal-cost discussions).

## Cost modeling

The repo also models the fiscal cost of the Saver's Match across three designs:

1. **Current law (1.00×)** — the SECURE 2.0 §103 enacted match, replicating the JCT score (JCX-21-22). Engine: `code/03_cost_simulation/03a_jct_replication.R`.
2. **Expanded (1.25× / 1.50× / 2.00×)** — filer AGI thresholds scaled by each multiplier, holding the $1,000 cap and linear phaseout constant. Produced by `03a` and the robustness sweep `03b_robustness_sweep.R`.
3. **Universal Saver's Match hybrid** — the universal-account hybrid proposal, a six-stage sub-pipeline under `code/04_universal_hybrid/04_universal_sm_hybrid/`.

Headline cost (universal access, full participation, TY2027): **1.00× = 33.08M eligible / $9.19B**; **2.00× (doubled thresholds) = 81.08M / $41.07B**. See `output/tables/main/sm_jct_replication_scenarios.xlsx` (eight scenarios), `output/tables/main/sm_robustness_scenarios.xlsx` (robustness sweep), and `output/tables/universal_sm_hybrid/` (hybrid headline and distributional incidence). Memo figures are in `output/figures/main/`; the simple-saver illustration (`03c`) is in `output/figures/appendix/` and `output/tables/appendix/`.

## Data required

Place these files in `data/raw/` before running:

| File | Source | Notes |
|---|---|---|
| `pu2024.dta` | [Census SIPP 2024 datasets page](https://www.census.gov/programs-surveys/sipp/data/datasets/2024-data.html) | ~3 GB Stata file; not committed to repo |

`pu2024_expanded.csv` is built automatically on first run from `pu2024.dta`. Do not commit it (listed in `.gitignore`).

## How to run

```r
# From the repo root in R:
source("code/run_all.R")

# Or from any directory with EIG_PROJECT_ROOT set:
Sys.setenv(EIG_PROJECT_ROOT = "C:/path/to/EIG-Savers-match-sipp")
source("code/run_all.R")
```

`run_all.R` runs the full pipeline in sequence, each stage in a fresh sourced environment. Each stage has a `RUN_*` flag at the top of the file; flip one to `FALSE` to skip it.

1. **01** — `01_data_preparation/01_sipp_subset_from_dta.R`. Builds the 58-column `pu2024_expanded.csv` from `pu2024.dta`. Skipped automatically if the expanded CSV already exists.
2. **01b** — `01_data_preparation/01b_build_modeled_frame.R`. Builds the **one canonical modeled frame** (`data/processed/sipp_modeled.parquet`): Option B income projected to TY2027, filing group, thresholds + eligibility per multiplier, account access, and per-person match dollars. Every stage below reads this frame.
3. **02a** — `02_eligibility/02a_eligibility_buckets.R`. Three-bucket eligibility estimates (worker and filer basis).
4. **02b** — `02_eligibility/02b_filing_match_decomposition.R`. Filing-status × match-status contingency tables (shares the frame with 02a, so the two agree by construction).
5. **03a** — `03_cost_simulation/03a_jct_replication.R`. JCT replication + four-multiplier cost simulation (thin `run_scenario` calls over the frame).
6. **03b** — `03_cost_simulation/03b_robustness_sweep.R`. 20-scenario robustness sweep (reads the same canonical frame).
7. **03c** — `03_cost_simulation/03c_simple_saver_illustration.R`. Standalone simple-saver illustration (no microdata dependency).
8. **04** — `04_universal_hybrid/04_universal_sm_hybrid.R`. Universal Saver's Match hybrid; a thin master that sources the six `04_0[1-6]_*.R` sub-scripts.
9. **05a** — `05_figures/05a_cost_comparison_figures.R`. Cost-comparison memo figures (consumes `03a` output).

(`00b_reexport_dta_to_csv.R` is an optional CSV-rebuild utility, off by default.)

## Outputs

| File | Location | Description |
|---|---|---|
| `savers_match_eligibility_buckets.rds` | `output/tables/` | Overall + by filing status + by age band (worker basis); columns: `bucket1_weighted_n`, `bucket2_weighted_n`, `bucket3_weighted_n`, `bucket1_any_and_owns_weighted_n`, `universe_weighted_n` plus parallel `_millions` versions |
| `savers_match_eligibility_buckets.parquet` | `output/tables/` | Same as above, parquet format |
| `savers_match_eligibility_buckets_filerbasis.rds` | `output/tables/` | Filer-basis SIPP counts (MFJ couples collapsed to one filer) |
| `savers_match_eligibility_buckets.md` | `output/reports/` | Plain-English memo with headline numbers |
| `answers_eligibility_by_filing_match.{rds,parquet,xlsx}` | `output/tables/` | Filing-status × match-status decomposition of the full SM-eligibility universe. The `.xlsx` workbook carries `Notes`, `Wide`, and `Long` sheets and is tracked in git; `.rds` and `.parquet` are gitignored |
| `answers_eligibility_account_holders_by_filing_match.{rds,parquet,xlsx}` | `output/tables/` | Same shape, restricted to workers who already hold a qualifying retirement account |
| `answers_eligibility_access_gap_by_filing_match.{rds,parquet,xlsx}` | `output/tables/` | Same shape, restricted to workers without a qualifying account (the access gap; equals Table 1 minus Table 2 cell by cell) |

## Key design choices

- **Income concept (standard methodology)**: calendar-year personal income, built by summing observed monthly `TPTOTINC` across all twelve `MONTHCODE` rows per person. For the small share of partial-year respondents, the sum is scaled to twelve months via `sum * 12 / n_valid_months` (Option B). For the typical respondent observed all twelve months this is the measured calendar-year total. This replaces the prior `TPTOTINC × 12` (December-only annualization). The toggle `restrict_to_full_year_flag` in `02a` flips the partial-year handling to a full-year-only sensitivity (Option C). Above-the-line adjustments to AGI (IRC sec 62: IRA deduction, HSA, student-loan interest, etc.) are not yet applied, so all SIPP bucket counts are **lower bounds** on true AGI-defined eligibility.
- **MFJ income**: spouse-pair sum of annualized `TPTOTINC` via `EPNSPOUSE` self-join (U1 in code), not family `TFTOTINC`.
- **Income projection (TY2027)**: SIPP 2024 incomes are projected to 2027 nominal dollars by ×1.093 (≈ 3%/yr CBO/JCT wage growth, 3 years) and compared to the statutory 2027 thresholds. This single construct is shared by the eligibility and cost stages (decision D1, 2026-06-08). It replaced the prior "hold income at 2024, CPI factor 1.0 on thresholds" convention; the bucket counts below reflect the projected basis.
- **Student / dependent exclusions**: IRC sec 25B cross-references apply; RENROLL + EEDFTPT are the primary student flags with an age/education/earnings fallback.
- **Account qualification**: SIPP `EOWN_THR401 == 1` (has 401k/403b) or `EOWN_IRAKEO == 1` (has IRA/Keogh). DB pensions excluded because they cannot receive Saver's Match contributions.

## Income thresholds (2027, no COLA adjustment)

| Filing status | Full-match ceiling | Phase-out ceiling |
|---|---|---|
| Single / MFS | $20,500 | $35,500 |
| Married filing jointly | $41,000 | $71,000 |
| Head of household | $30,750 | $53,250 |

## Eligible workers by filing status and match status (2027 thresholds)

The three tables below decompose the SM-eligibility universe by filing status (rows) and match status (columns). All cell values are weighted worker counts in millions, computed from SIPP 2024 Wave 1 person weights (`WPFINWGT`). Cell boundaries follow the statutory convention: income at or below the full-match ceiling falls in **Full Match Below**, income strictly above the full-match ceiling and strictly below the upper phase-out ceiling falls in **Phaseout Range**, and income at or above the upper phase-out ceiling falls in **No Match Above**. The **Single** row folds in married-filing-separately workers, who share the Single thresholds. Row and column totals are recomputed from rounded cell values, so they may differ from the raw weighted total by a rounding cent.

By construction Bucket 1 (any-match eligible) equals **Full Match Below** + **Phaseout Range**, Bucket 2 (full-match eligible) equals **Full Match Below** in Table 1, and Bucket 3 (full-match eligible AND holds a qualifying account) equals **Full Match Below** in Table 2. Table 1 = Table 2 + Table 3 cell by cell. Tables are produced by `code/02_eligibility/02b_filing_match_decomposition.R`; per-workbook run metadata, the universe definition, and the statutory thresholds are recorded on the `Notes` sheet of each `output/tables/answers_eligibility_*.xlsx` workbook.

### Table 1. Workers in the SM-eligibility universe, weighted N (millions)

| Filing status | Full Match Below | Phaseout Range | No Match Above | Row total |
|---|---:|---:|---:|---:|
| Single | 6.73 | 10.19 | 45.20 | 62.12 |
| Head of Household | 2.63 | 3.16 | 6.49 | 12.28 |
| Married Filing Jointly | 3.37 | 7.00 | 60.58 | 70.95 |
| Column total | 12.73 | 20.35 | 112.27 | 145.35 |

### Table 2. Workers who already hold a qualifying retirement account, weighted N (millions)

Restricted to workers with `EOWN_THR401 == 1` or `EOWN_IRAKEO == 1` (DC accounts only; DB pensions excluded).

| Filing status | Full Match Below | Phaseout Range | No Match Above | Row total |
|---|---:|---:|---:|---:|
| Single | 1.42 | 2.79 | 28.90 | 33.11 |
| Head of Household | 0.56 | 1.20 | 4.37 | 6.13 |
| Married Filing Jointly | 1.05 | 2.99 | 44.65 | 48.69 |
| Column total | 3.03 | 6.98 | 77.92 | 87.93 |

### Table 3. Access gap — workers without a qualifying retirement account, weighted N (millions)

These are workers who would need to open a new qualifying account to receive the Saver's Match.

| Filing status | Full Match Below | Phaseout Range | No Match Above | Row total |
|---|---:|---:|---:|---:|
| Single | 5.31 | 7.40 | 16.30 | 29.01 |
| Head of Household | 2.08 | 1.97 | 2.12 | 6.17 |
| Married Filing Jointly | 2.33 | 4.00 | 15.92 | 22.25 |
| Column total | 9.72 | 13.37 | 34.34 | 57.43 |

## External calibration

This is a SIPP-only analysis at this stage. The one external input is the IRS SOI Table 1 (TY2022)
AGI-bin filer counts (`data/raw/irs_soi/22in01pl.xls`), used to calibrate the contribution bands and as
a filer-count benchmark. No survey cross-validation against other microdata is used.

## Code structure

```
code/
  run_all.R                                   # Pipeline entry point (flagged stages)
  00_setup/
    00_config.R                               # Paths and global options
    00b_reexport_dta_to_csv.R                 # Optional: rebuild pu2024.csv from pu2024.dta
  01_data_preparation/
    01_sipp_subset_from_dta.R                 # Build 58-col pu2024_expanded.csv from pu2024.dta
    01b_build_modeled_frame.R                 # Build the ONE canonical modeled frame (all stages read it)
  02_eligibility/
    02a_eligibility_buckets.R                 # Core eligibility engine
    02b_filing_match_decomposition.R          # Filing-status x match-status decomposition
                                              # (reconciles to 02a's bucket totals)
  03_cost_simulation/
    03a_jct_replication.R                     # JCT replication + four-multiplier cost simulation
    03b_robustness_sweep.R                    # Robustness sweep (consumes 03a checkpoint)
    03c_simple_saver_illustration.R           # Standalone simple-saver illustration
  04_universal_hybrid/
    04_universal_sm_hybrid.R                  # Universal SM hybrid master (sources 6 sub-scripts)
    04_universal_sm_hybrid/                   # 04_01..06: universe, pivots, match, tables, figures, lenses
  05_figures/
    05a_cost_comparison_figures.R             # Cost-comparison memo figures
  _shared/                                    # the single sources of truth (sourced by 00_config.R)
    params.R                                  # all policy/methodology constants (+ params.json)
    build_frame.R                             # build_modeled_frame(): the one canonical frame
    scenario_engine.R                         # run_scenario(): the one scenario runner
    calibration_cells.R                       # lower-level helpers (frame builder, compute_match_rate)
    DATA_DICTIONARY.md                        # every canonical-frame column defined
```

> The former Python port (`code/python_port/`) was retired on 2026-06-08; R is the sole implementation.

## Lineage

This repository is the home for all Saver's Match eligibility and cost work. The cost-simulation,
four-multiplier, and universal-hybrid components were consolidated here on 2026-06-08 (see
`MIGRATION_PROVENANCE.md`). An older, simpler SIPP eligibility prototype lives in a separate
`savers_match_eligibility` repository and is retained only as a historical reference for the
access-gap plan-type breakdown.
