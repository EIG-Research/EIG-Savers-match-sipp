# Data

This repository computes Saver's Match (SECURE 2.0, IRC sec 6433) eligibility estimates from the Survey of Income and Program Participation (SIPP) 2024 Wave 1, with cross-validation against the Current Population Survey (CPS) ASEC 2025.

## Sources

- **SIPP 2024 Wave 1** (U.S. Census Bureau): person-level public-use file. Primary input for eligibility estimates. Variables actually pulled by `code/01_data_preparation/01_sipp_subset_from_dta.R` include `TPTOTINC`, `TFTOTINC`, `TPEARN`, `EFSTATUS`, `EOWN_THR401`, `EOWN_IRAKEO`, `EOWN_PENSION`, `EMJOB_401`, `EMJOB_IRA`, `EMJOB_PEN`, `EPNSPOUSE`, `APNSPOUSE`, plus standard demographic and weight columns. Available at https://www.census.gov/programs-surveys/sipp/data/datasets/2024-data.html.
- **CPS ASEC 2025** (income year 2024) via IPUMS CPS: person-level extract used as the primary external anchor on a worker basis. Variables of interest include `ADJGINC`, `INCWAGE`, `INCBUS`, `INCFARM`, `FILESTAT`, `SPLOC`, and `ASECWT`. Requires an IPUMS API key in the `IPUMS_API_KEY` environment variable. Pulled inline by `code/03_main_estimation/03g_savers_match_eligibility_buckets.R` Phase 4.

## Directory layout

The `data/` directory holds raw and intermediate microdata. The files themselves are not tracked in git because they are large (the SIPP 2024 Wave 1 Stata file is approximately 3 GB) and reproducible from the public sources above.

- `data/raw/` — direct downloads from source. Includes the SIPP 2024 Wave 1 `pu2024.dta` and IPUMS CPS extract files. The pipeline expands the SIPP `.dta` to a CSV at first run; the expanded CSV is also kept here.
- `data/interim/` — intermediate transformations produced during pipeline execution.
- `data/processed/` — final analytic datasets produced by the pipeline.
- `data/external/` — external reference data such as CPI series, when used.

## Reproducing the analysis

From a fresh clone:

1. Download SIPP 2024 Wave 1 from the U.S. Census Bureau and place `pu2024.dta` (or an equivalent CSV) in `data/raw/`.
2. Set the `IPUMS_API_KEY` environment variable to a valid IPUMS API key.
3. From the repository root in R, run `source("code/run_all.R")`.

Outputs are written to `output/`. Small text outputs and figures are tracked in git; large binary outputs are not.
