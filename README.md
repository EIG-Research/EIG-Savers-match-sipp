# Saver's Match Eligibility Analysis

Estimates of the population eligible for the Saver's Match under SECURE 2.0 (IRC sec 6433), projected to tax year 2027, using SIPP 2024 Wave 1 microdata.

## What this repo does

1. **Eligibility bucketing** — counts workers in three nested tiers:
   - **Bucket 1**: any-match eligible (AGI below the upper phase-out threshold)
   - **Bucket 2**: full-match eligible (AGI at or below the full-match threshold)
   - **Bucket 3**: full-match eligible AND currently holds a qualifying retirement account

2. **Access gap analysis** — of the any-match eligible population (B1), how many already hold a qualifying account vs. how many would need to open one (B1 without account)

3. **Filer-basis comparison** — collapses each resolved MFJ couple to one filer for direct comparison against EBRI Copeland (2024) anchors (83.8M / 69.0M / 21.9M)

## Data required

Place these files in `data/raw/` before running:

| File | Source | Notes |
|---|---|---|
| `pu2024.dta` | [Census SIPP 2024 FTP](https://www.census.gov/programs-surveys/sipp/data/datasets/2024-data.html) | ~2GB Stata file; not committed to repo |

`pu2024_expanded.csv` is built automatically on first run from `pu2024.dta`. Do not commit it (listed in `.gitignore`).

## How to run

```r
# From the repo root in R:
source("code/run_all.R")

# Or from any directory with EIG_PROJECT_ROOT set:
Sys.setenv(EIG_PROJECT_ROOT = "C:/path/to/EIG-Savers-match-sipp")
source("code/run_all.R")
```

The pipeline skips Step 1 automatically if `pu2024_expanded.csv` already exists.

## Outputs

| File | Location | Description |
|---|---|---|
| `savers_match_eligibility_buckets.rds` | `output/tables/` | Overall + by filing status + by age band (worker basis) |
| `savers_match_eligibility_buckets.parquet` | `output/tables/` | Same as above, parquet format |
| `savers_match_eligibility_buckets_filerbasis.rds` | `output/tables/` | Filer-basis counts for EBRI comparison |
| `savers_match_filer_vs_ebri.rds` | `output/tables/` | SIPP filer counts vs. EBRI 83.8M / 69.0M / 21.9M anchors |
| `savers_match_validation_cps_vs_sipp.rds` | `output/tables/` | Optional CPS ASEC 2025 cross-validation (requires IPUMS key) |
| `savers_match_eligibility_buckets.md` | `output/reports/` | Plain-English memo with headline numbers |

## Key design choices

- **Income proxy**: SIPP `TPTOTINC` (monthly) × 12 as AGI proxy. Above-the-line adjustments (IRA deduction, HSA, student loan interest, etc.) are not applied — this makes all bucket counts **lower bounds** on true eligibility.
- **MFJ income**: spouse-pair sum of `TPTOTINC` via `EPNSPOUSE` self-join (U1 in code), not family `TFTOTINC`.
- **CPI projection factor**: 1.0 (IRC sec 6433(h)(1) COLA first applies to TY2028+; 2027 uses statutory thresholds as written).
- **Student / dependent exclusions**: IRC sec 25B cross-references apply; RENROLL + EEDFTPT are the primary student flags with an age/education/earnings fallback.
- **Account qualification**: SIPP `EOWN_THR401 == 1` (has 401k/403b) or `EOWN_IRAKEO == 1` (has IRA/Keogh). DB pensions excluded.

## Income thresholds (2027, no COLA adjustment)

| Filing status | Full-match ceiling | Phase-out ceiling |
|---|---|---|
| Single / MFS | $20,500 | $35,500 |
| Married filing jointly | $41,000 | $71,000 |
| Head of household | $30,750 | $53,250 |

## External benchmarks

- **EBRI** (Copeland 2024, Issue Brief No. 602, IRS SOI 2018 filers): 83.8M any-match, 69.0M full-match, 21.9M full-match-with-account
- **Morningstar** (January 2025, SCF 2022 households): ~27M eligible

## Code structure

```
code/
  run_all.R                          # Pipeline entry point
  00_setup/
    00_config.R                      # Paths and global options
  01_data_preparation/
    01_sipp_subset_from_dta.R        # Build pu2024_expanded.csv from pu2024.dta
  03_main_estimation/
    03g_savers_match_eligibility_buckets.R  # Core eligibility engine
  _shared/
    calibration_cells.R             # Income thresholds, filing-group helpers
```

## Source repo

This pipeline is extracted from `RSAA-cost-simulation-static`. The older (simpler) SIPP methodology lives in the `savers_match_eligibility` repo on this machine and can be used as a reference for the access gap plan-type breakdown.
