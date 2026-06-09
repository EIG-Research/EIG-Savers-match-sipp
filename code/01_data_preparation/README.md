# code/01_data_preparation/

Two scripts: build the SIPP extract, then the canonical modeled frame.

## `01_sipp_subset_from_dta.R`

Reads `data/raw/pu2024.dta` (Census SIPP 2024 Wave 1 public-use person-month microdata) and writes the
**58-column** extract used downstream:

- `data/raw/pu2024_expanded.csv` (~80 MB) and `data/raw/pu2024_expanded.parquet` (snappy).
- `data/raw/pu2024_expanded_variable_manifest.csv` — the per-variable manifest.

The 58 columns add the contribution-amount variables (`TSCNTAMT_*`, `ASCNTAMT_*`) to the demographic,
income, filing-status, and retirement-access variables. Run once after placing `pu2024.dta` in
`data/raw/`.

## `01b_build_modeled_frame.R`

Builds the one canonical modeled frame from `pu2024_expanded.csv` via `build_modeled_frame()` and writes
`data/processed/sipp_modeled.parquet` (+ `.rds`) and `data/processed/params.json`. Every stage from 02
onward reads this frame. See `code/_shared/DATA_DICTIONARY.md` for the column definitions.
