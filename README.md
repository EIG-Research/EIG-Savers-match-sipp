# Saver's Match Eligibility Analysis

Estimates of the population eligible for the Saver's Match under SECURE 2.0 (IRC sec 6433), projected to tax year 2027, using SIPP 2024 Wave 1 microdata.

## What this repo does

1. **Eligibility bucketing** — counts workers in three nested tiers:
   - **Bucket 1**: any-match eligible (AGI below the upper phase-out threshold)
   - **Bucket 2**: full-match eligible (AGI at or below the full-match threshold)
   - **Bucket 3**: full-match eligible AND currently holds a qualifying retirement account

2. **Access gap analysis** — of the any-match eligible population (B1), how many already hold a qualifying account vs. how many would need to open one (B1 without account)

3. **Filing-status × match-status decomposition** — three contingency tables (full universe, account holders, access gap) produced by `code/03_main_estimation/Answers_for_common_questions.R`. Reconciles cell-by-cell to the published bucket totals.

4. **Worker-basis comparison to CPS ASEC 2025** — primary external anchor. Each adult is counted separately on both sides. CPS ASEC 2025 covers income year 2024.

5. **Filer-basis comparison to CPS ASEC 2025 (secondary)** — collapses each resolved MFJ couple to one filer per side for the tax-return-basis comparison. Useful for fiscal-cost discussions; not the primary public-facing unit.

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

`run_all.R` runs Step 1 (`01_sipp_subset_from_dta.R`, skipped automatically if `pu2024_expanded.csv` already exists) and Step 2 (`03g_savers_match_eligibility_buckets.R`).

The filing-status × match-status contingency tables are produced by a separate, idempotent script that reads the same expanded CSV:

```r
source("code/03_main_estimation/Answers_for_common_questions.R")
```

This script reconciles its column marginals against `output/tables/savers_match_eligibility_buckets.rds` and stops on a mismatch, so 03g must run first.

## Outputs

| File | Location | Description |
|---|---|---|
| `savers_match_eligibility_buckets.rds` | `output/tables/` | Overall + by filing status + by age band (worker basis); columns: `bucket1_weighted_n`, `bucket2_weighted_n`, `bucket3_weighted_n`, `bucket1_any_and_owns_weighted_n`, `universe_weighted_n` plus parallel `_millions` versions |
| `savers_match_eligibility_buckets.parquet` | `output/tables/` | Same as above, parquet format |
| `savers_match_eligibility_buckets_filerbasis.rds` | `output/tables/` | Filer-basis SIPP counts (MFJ couples collapsed to one filer) |
| `savers_match_workers_vs_cps.rds` | `output/tables/` | **Primary.** Worker-basis SIPP counts with worker-basis CPS ASEC 2025 anchor and SIPP-as-percent-of-CPS ratios |
| `savers_match_filers_vs_cps.rds` | `output/tables/` | Secondary. Filer-basis SIPP counts with filer-basis CPS ASEC 2025 anchor and SIPP-as-percent-of-CPS ratios |
| `savers_match_validation_cps_vs_sipp.rds` | `output/tables/` | Combined worker-basis-and-filer-basis CPS comparison (requires IPUMS_API_KEY env var; runs by default) |
| `savers_match_eligibility_buckets.md` | `output/reports/` | Plain-English memo with headline numbers |
| `answers_eligibility_by_filing_match.{rds,parquet,xlsx}` | `output/tables/` | Filing-status × match-status decomposition of the full SM-eligibility universe. The `.xlsx` workbook carries `Notes`, `Wide`, and `Long` sheets and is tracked in git; `.rds` and `.parquet` are gitignored |
| `answers_eligibility_account_holders_by_filing_match.{rds,parquet,xlsx}` | `output/tables/` | Same shape, restricted to workers who already hold a qualifying retirement account |
| `answers_eligibility_access_gap_by_filing_match.{rds,parquet,xlsx}` | `output/tables/` | Same shape, restricted to workers without a qualifying account (the access gap; equals Table 1 minus Table 2 cell by cell) |

## Key design choices

- **Income concept (standard methodology)**: calendar-year personal income, built by summing observed monthly `TPTOTINC` across all twelve `MONTHCODE` rows per person. For the small share of partial-year respondents, the sum is scaled to twelve months via `sum * 12 / n_valid_months` (Option B). For the typical respondent observed all twelve months this is the measured calendar-year total. This replaces the prior `TPTOTINC × 12` (December-only annualization). The toggle `restrict_to_full_year_flag` in `03g` flips the partial-year handling to a full-year-only sensitivity (Option C). Above-the-line adjustments to AGI (IRC sec 62: IRA deduction, HSA, student-loan interest, etc.) are not yet applied, so all SIPP bucket counts are **lower bounds** on true AGI-defined eligibility.
- **MFJ income**: spouse-pair sum of annualized `TPTOTINC` via `EPNSPOUSE` self-join (U1 in code), not family `TFTOTINC`.
- **CPI projection factor**: 1.0 (IRC sec 6433(h)(1) COLA first applies to TY2028+; 2027 uses statutory thresholds as written).
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

By construction Bucket 1 (any-match eligible) equals **Full Match Below** + **Phaseout Range**, Bucket 2 (full-match eligible) equals **Full Match Below** in Table 1, and Bucket 3 (full-match eligible AND holds a qualifying account) equals **Full Match Below** in Table 2. Table 1 = Table 2 + Table 3 cell by cell. Tables are produced by `code/03_main_estimation/Answers_for_common_questions.R`; per-workbook run metadata, the universe definition, and the statutory thresholds are recorded on the `Notes` sheet of each `output/tables/answers_eligibility_*.xlsx` workbook.

### Table 1. Workers in the SM-eligibility universe, weighted N (millions)

| Filing status | Full Match Below | Phaseout Range | No Match Above | Row total |
|---|---:|---:|---:|---:|
| Single | 7.88 | 11.82 | 42.41 | 62.11 |
| Head of Household | 3.01 | 3.58 | 5.69 | 12.28 |
| Married Filing Jointly | 4.16 | 8.08 | 58.71 | 70.95 |
| Column total | 15.05 | 23.48 | 106.81 | 145.34 |

### Table 2. Workers who already hold a qualifying retirement account, weighted N (millions)

Restricted to workers with `EOWN_THR401 == 1` or `EOWN_IRAKEO == 1` (DC accounts only; DB pensions excluded).

| Filing status | Full Match Below | Phaseout Range | No Match Above | Row total |
|---|---:|---:|---:|---:|
| Single | 1.67 | 3.61 | 27.83 | 33.11 |
| Head of Household | 0.65 | 1.54 | 3.94 | 6.13 |
| Married Filing Jointly | 1.21 | 3.74 | 43.74 | 48.69 |
| Column total | 3.53 | 8.89 | 75.51 | 87.93 |

### Table 3. Access gap — workers without a qualifying retirement account, weighted N (millions)

These are workers who would need to open a new qualifying account to receive the Saver's Match.

| Filing status | Full Match Below | Phaseout Range | No Match Above | Row total |
|---|---:|---:|---:|---:|
| Single | 6.21 | 8.21 | 14.58 | 29.00 |
| Head of Household | 2.37 | 2.04 | 1.76 | 6.17 |
| Married Filing Jointly | 2.95 | 4.34 | 14.96 | 22.25 |
| Column total | 11.53 | 14.59 | 31.30 | 57.42 |

## External anchor

- **CPS ASEC 2025** (income year 2024): primary external anchor, computed inline in `03g` Phase 4 using IPUMS CPS via the `ipumsr` API and the AGI-concept variable `ADJGINC`. Requires `IPUMS_API_KEY` in the environment. The CPS comparison is reported on both a worker basis (each adult counted separately, the primary unit for population-eligibility communication) and a filer basis (MFJ couples collapsed to one filer, useful for fiscal-cost discussions). Worker-basis is the headline. Income-year mismatch caveat: SIPP 2024 Wave 1 covers reference year 2023, CPS ASEC 2025 covers income year 2024; the SIPP figure understates the 2024-on-2024 comparison by one year of nominal growth. This caveat drops when SIPP 2025 Wave 2 releases. The CPS earned-income filter on the universe uses `INCWAGE > 0 | INCBUS > 0 | INCFARM > 0` (IRC sec 32 / sec 6433 earned-income concept), applied per person, which is the de facto MFJ own-earnings rule on CPS.

## Historical references (not used as anchors)

- EBRI (Copeland 2024, Issue Brief No. 602, IRS SOI 2018 filers): 83.8M any-match, 69.0M full-match, 21.9M full-match-with-account. Not used as a baseline because the SOI 2018 vintage predates the SECURE 2.0 statutory thresholds by five years with no inflation adjustment, and the underlying filer population has shifted materially over that interval.
- Morningstar (January 2025, SCF 2022 households): ~27M eligible. Different unit (households not filers) and different reference year; noted for context only.

## Code structure

```
code/
  run_all.R                                   # Pipeline entry point
  00_setup/
    00_config.R                               # Paths and global options
  01_data_preparation/
    01_sipp_subset_from_dta.R                 # Build pu2024_expanded.csv from pu2024.dta
  03_main_estimation/
    03g_savers_match_eligibility_buckets.R    # Core eligibility engine
    Answers_for_common_questions.R            # Filing-status x match-status decomposition
                                              # (run after 03g; reconciles to its bucket totals)
  _shared/
    calibration_cells.R                       # Income thresholds, filing-group helpers
```

## Source repo

This pipeline is extracted from a larger internal cost-simulation repository. The older (simpler) SIPP methodology lives in a separate `savers_match_eligibility` repository and can be consulted as a reference for the access-gap plan-type breakdown.
