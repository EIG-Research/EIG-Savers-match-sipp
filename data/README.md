# Data

This repository computes Saver's Match (SECURE 2.0, IRC sec 6433) eligibility and cost estimates from the Survey of Income and Program Participation (SIPP). It is a SIPP-based analysis, with the policy eligibility frontier anchored to an external published statistic.

## Sources

- **SIPP public-use file** (U.S. Census Bureau): person-level; the primary input. The respecified analysis uses the **2025 SIPP** (`pu2025.dta`, reference period January–December 2024); the prior analysis used the 2024 SIPP (reference period January–December **2023**). Each collection-year file **pools four panels** — the 2025 file carries `SPANEL` 2022/2023/2024/2025 at `SWAVE` 4/3/2/1, and `WPFINWGT` is calibrated so the pooled file represents the national population (pooled December-reference-month total ≈ 333M). Earlier drafts of this README described the input as "SIPP 2024 Wave 1"; that label was incorrect — the pipeline uses all four pooled panels, which is why the analysis universe is ~145M rather than ~28M. Variables pulled by `code/01_data_preparation/01_sipp_subset_from_dta.R` include `TPTOTINC`, `TFTOTINC`, `TPEARN`, `EFSTATUS`, `EOWN_THR401`, `EOWN_IRAKEO`, `EOWN_PENSION`, `EMJOB_401`, `EMJOB_IRA`, `EMJOB_PEN`, `EPNSPOUSE`, `APNSPOUSE`, the contribution-amount variables, plus standard demographic and weight columns. Available at https://www.census.gov/programs-surveys/sipp/data/datasets/2024-data.html.
- **IRS SOI Table 1.2, TY2023** (`data/raw/irs_soi/23in12ms.xls`): returns by marital status and size of AGI. Read at runtime by `code/04_universal_hybrid/04_universal_sm_hybrid/04_02_compute_pivots.R`, which interpolates the single-plus-MFS median AGI to anchor the Universal Saver's Match hybrid eligibility frontier (design decision D1). This is a hard dependency: stage 04 stops if the file is missing.
- **IRS SOI Table 1, TY2022** (`data/raw/irs_soi/22in01pl.xls`): AGI-bin filer counts, used as a filer-count benchmark and as the offline source for the `contribution_bands` constants in `code/_shared/params.R`. No script reads this file — the values are hard-coded literals.
- **IRS SOI Table 1.2, TY2022** (`data/raw/irs_soi/22in12ms.xls`): unused; the superseded prior vintage of the anchor table. Retained for anchor-sensitivity checks only.
- **CPS ASEC via the IPUMS CPS API** (`data/raw/ipums_cps_asec/`): pulled by `code/01_data_preparation/01c_pull_ipums_asec.R` (variables `INCTOT`, `INCWAGE`, `FILESTAT`, `ASECWT`, `AGE`, `SEX`, plus `MARST` and `CLASSWKR` as supporting cuts), then reduced to medians by `01d_asec_income_medians.R`. Supplies the anchor for the respecified Universal Saver's Match phasedown (spec `Infrastructure/specs/2026-08-04_asec-median-anchor-respecification.md`) and **supersedes the IRS SOI Table 1.2 anchor**; the SOI workbook is retained as an external calibration check. Requires `IPUMS_API_KEY` in the R environment. The extract is cached: `01c` re-submits only when the target ASEC year or the requested variable list changes.

## Directory layout

The `data/` directory holds raw and intermediate microdata. The files themselves are not tracked in git because they are large (the SIPP Stata file is approximately 2.8 GB) and reproducible from the public sources above.

- `data/raw/` — direct downloads from source: the SIPP `.dta` (`pu2025.dta`), the CPS ASEC person records in `cps_asec/`, and the IRS SOI workbooks in `irs_soi/`. The pipeline expands the SIPP `.dta` to a CSV at first run; the expanded CSV is also kept here. See `data/raw/README.md` for which SOI workbook is read at runtime and which are provenance only.
- `data/interim/` — intermediate transformations produced during pipeline execution.
- `data/processed/` — final analytic datasets produced by the pipeline.
- `data/external/` — external reference data such as CPI series, when used.

## Reproducing the analysis

From a fresh clone:

Nothing under `data/raw/` is tracked in git — `.gitignore` excludes the directory wholesale, so a fresh
clone has an empty `data/raw/` and **all** downloads below are required.

1. Download the SIPP public-use file from the U.S. Census Bureau and place the `.dta` in `data/raw/`.
   The respecified analysis uses the **2025 SIPP** (`pu2025.dta`, reference period January–December
   **2024**), from https://www2.census.gov/programs-surveys/sipp/data/datasets/2025/pu2025_dta.zip.
   Note that each SIPP collection-year file pools four panels (the 2025 file carries `SPANEL`
   2022/2023/2024/2025 at waves 4/3/2/1) and `WPFINWGT` is calibrated so the **pooled** file
   represents the national population — do not filter to a single panel or wave.
2. Set `IPUMS_API_KEY` in `~/.Renviron` (request a key at https://account.ipums.org/api_keys) and
   run `code/01_data_preparation/01c_pull_ipums_asec.R`, then `01d_asec_income_medians.R`. The pull
   targets the most recent ASEC sample by default; pin `asec_sample_year_int` in `01c` to freeze a
   vintage once the anchor is published. No manual download is needed — the extract is fetched and
   cached under `data/raw/ipums_cps_asec/`.
3. Download IRS SOI Table 1.2 for TY2023 (`23in12ms.xls`) from
   https://www.irs.gov/statistics/soi-tax-stats-individual-statistical-tables-by-size-of-adjusted-gross-income
   and place it in `data/raw/irs_soi/`. This was the anchor source under design decision D1 and is
   now retained as an external calibration check.
4. From the repository root in R, run `source("code/run_all.R")`.

**Vintage contract:** the ASEC income year must equal the SIPP reference year, because eligibility is
scored nominal-on-nominal with no projection. ASEC survey year Y reports income for calendar year Y-1.
`01d_asec_income_medians.R` asserts this and stops on a mismatch. Pairing the 2025 SIPP (reference year
2024) with ASEC 2025 (income year 2024) satisfies it; the 2024 SIPP (reference year **2023**) would
require ASEC 2024.

- `data/raw/ipums_cps_asec/` — IPUMS CPS extract, DDI codebook, extract definition, and extract
  metadata. The metadata JSON records the ASEC year and variable list and is what the cache check
  reads; if it is deleted, `01d` stops rather than assume a vintage.

`22in01pl.xls` (SOI Table 1, TY2022) is *not* required to run the pipeline. It is the offline provenance
for the `contribution_bands` literals in `code/_shared/params.R`; download it only if you need to re-derive
those constants.

Outputs are written to `output/`. Small text outputs and figures are tracked in git; large binary outputs are not.
