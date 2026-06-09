# code/00_setup/

Project configuration and a small utility for rebuilding the SIPP CSV extract.

## Files

### `00_config.R`

Sourced by `03a_jct_replication.R`. Sets the project root, the path variables (`path_data_raw`, `path_code`, `path_output`, etc.), configuration tier, and logging defaults. No files written.

### `00b_reexport_dta_to_csv.R`

Utility that reads `data/raw/pu2024.dta` and writes `data/raw/pu2024.csv` with the 40-column base extract plus `TFTOTINC` (total family income) and `EFSTATUS` (filing status) that `03a` requires.

This script is optional. `03a` falls back to reading `pu2024.dta` directly via `haven::read_dta()` if `pu2024.csv` is missing the required columns, so you do not have to run `00b` unless you want the CSV read path for speed.

If you want to avoid reading the 3 GB `.dta` on every run, run `00b_reexport_dta_to_csv.R` once after you have placed `pu2024.dta` in `data/raw/`. The resulting `pu2024.csv` is about 60 MB.
