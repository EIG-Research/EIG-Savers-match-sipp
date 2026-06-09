# Data

This repository computes Saver's Match (SECURE 2.0, IRC sec 6433) eligibility and cost estimates from the Survey of Income and Program Participation (SIPP) 2024 Wave 1. It is a SIPP-based analysis.

## Sources

- **SIPP 2024 Wave 1** (U.S. Census Bureau): person-level public-use file; the primary input. Variables pulled by `code/01_data_preparation/01_sipp_subset_from_dta.R` include `TPTOTINC`, `TFTOTINC`, `TPEARN`, `EFSTATUS`, `EOWN_THR401`, `EOWN_IRAKEO`, `EOWN_PENSION`, `EMJOB_401`, `EMJOB_IRA`, `EMJOB_PEN`, `EPNSPOUSE`, `APNSPOUSE`, the contribution-amount variables, plus standard demographic and weight columns. Available at https://www.census.gov/programs-surveys/sipp/data/datasets/2024-data.html.
- **IRS SOI Table 1, TY2022** (`data/raw/irs_soi/22in01pl.xls`): AGI-bin filer counts used to calibrate the contribution bands and as a filer-count benchmark.

## Directory layout

The `data/` directory holds raw and intermediate microdata. The files themselves are not tracked in git because they are large (the SIPP 2024 Wave 1 Stata file is approximately 3 GB) and reproducible from the public sources above.

- `data/raw/` — direct downloads from source: the SIPP 2024 Wave 1 `pu2024.dta` and the IRS SOI workbook. The pipeline expands the SIPP `.dta` to a CSV at first run; the expanded CSV is also kept here.
- `data/interim/` — intermediate transformations produced during pipeline execution.
- `data/processed/` — final analytic datasets produced by the pipeline.
- `data/external/` — external reference data such as CPI series, when used.

## Reproducing the analysis

From a fresh clone:

1. Download SIPP 2024 Wave 1 from the U.S. Census Bureau and place `pu2024.dta` in `data/raw/`.
2. From the repository root in R, run `source("code/run_all.R")`.

Outputs are written to `output/`. Small text outputs and figures are tracked in git; large binary outputs are not.
