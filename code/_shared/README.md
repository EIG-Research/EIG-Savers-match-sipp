# code/_shared/

The single sources of truth, sourced by `code/00_setup/00_config.R` (so any stage gets them from one
`source()`). Not executable on their own.

## `params.R`
`sm_params()` returns the ONE canonical parameter set: statutory thresholds (and the m100/m125/m150/m200
multiplier ladder, *derived* not hard-coded), match rate, contribution cap, the TY2027 income-projection
factor (1.093), take-up rates, student/dependent caps, SOI contribution bands, the two contribution-rate
splits (`jct` 15/60/25, `alt` 15/25/60), and the JCT JCX-21-22 benchmark. `write_sm_params_json()` emits
`data/processed/params.json` for any non-R consumer. This replaced the former triplicate sources
(`sm_calibration_constants()`, 03a's inline `sm_params`, and the retired Python literals).

## `build_frame.R`
`build_modeled_frame(raw, params)` returns the ONE canonical person-level (December) frame with clean
`snake_case` columns: Option B income projected to TY2027, U1 spouse-pair MFJ income, filing group,
thresholds + Saver's Match factor + eligibility per multiplier, account-access flags, and per-person
match dollars under both the band (DC) and universal contribution assumptions. Every stage from 02 onward
reads the materialized frame (`data/processed/sipp_modeled.parquet`, written by `01b`). Column
definitions are in `DATA_DICTIONARY.md`.

## `scenario_engine.R`
`run_scenario()` — the ONE participation/cost scenario runner (weighted-cumulative take-up selection),
used by 03a and 03b. Replaced the former inline copies in 03a and 03b.

## `calibration_cells.R`
Lower-level helpers `build_modeled_frame()` builds on: `build_modeled_sipp_frame_v2()`,
`aggregate_sipp_person_year()`, `make_filing_group()`/`make_income_cell_sm()`/etc., and
`compute_match_rate()` (the universal-hybrid match-rate schedule).
