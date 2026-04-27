# Project Profile

## Research Project Title
- `Saver's Match Eligibility Analysis — SECURE 2.0, IRC sec 6433`

## Research Question
- How many workers are eligible for the Saver's Match (any-match, full-match, full-match-with-account) under the SECURE 2.0 design, projected to tax year 2027?
- Of the eligible population, how many already hold a qualifying retirement account vs. how many face an access gap and would need to open one?

## Data in Scope

| Data Source | Type | Owner/Location | Time Coverage | Access Notes |
|---|---|---|---|---|
| SIPP 2024 Wave 1 | Survey microdata | Census Bureau (`data/raw/pu2024.dta`) | Reference year 2023, Dec interview month | Download `pu2024.dta` from Census SIPP FTP; not committed to repo |
| CPS ASEC 2025 | Survey microdata | IPUMS CPS API | Income year 2024 | Optional cross-validation; requires IPUMS_API_KEY env var |

## Deliverables
- Three-bucket eligibility count table (`output/tables/savers_match_eligibility_buckets.rds/.parquet`)
- Access gap summary (B1 total vs. B1-with-account vs. B1-without-account)
- Worker-basis CPS ASEC 2025 comparison table (`output/tables/savers_match_workers_vs_cps.rds/.parquet`) — primary external anchor
- Filer-basis CPS ASEC 2025 comparison table (`output/tables/savers_match_filers_vs_cps.rds/.parquet`) — secondary anchor for fiscal-cost discussions
- Plain-English memo (`output/reports/savers_match_eligibility_buckets.md`)
- Validation table cross-checking draft document numbers against code output

## Constraints
- Do not commit raw data files (`data/raw/pu2024.dta`, `pu2024_expanded.csv`) — too large
- CPI projection factor is 1.0 (statutory 2027 thresholds apply as written; COLA starts TY2028)
- Income concept (standard): calendar-year personal income built by summing observed monthly TPTOTINC across all twelve MONTHCODE rows per person, scaled to twelve months for partial-year respondents (Option B). Replaces the prior Dec × 12 proxy. Above-the-line adjustments to AGI are not yet applied; all SIPP bucket counts are lower bounds on true AGI-defined eligibility (documented in 03g header)
- Primary external anchor: CPS ASEC 2025 (income year 2024). Comparison is reported on both a worker basis (primary, public-facing) and a filer basis (secondary, fiscal-cost). EBRI Copeland (2024) Issue Brief No. 602 and Morningstar SCF 2022 are documented as historical references and are not used as baselines

## Additional Context (Open Notes)
- Source repo: `RSAA-cost-simulation-static` — this repo contains only the Saver's Match eligibility pipeline extracted from the larger RSAA comparison project
- Key script: `code/03_main_estimation/03g_savers_match_eligibility_buckets.R` (the core eligibility engine)
- Data prep: `code/01_data_preparation/01_sipp_subset_from_dta.R` (builds expanded 48-column extract from pu2024.dta)
- Shared helpers: `code/_shared/calibration_cells.R` (thresholds, filing-group helpers)
- Income thresholds (from calibration_cells.R): Single/MFS $20,500–$35,500 | MFJ $41,000–$71,000 | HoH $30,750–$53,250
- Reference for access gap / older SIPP methodology: `savers_match_eligibility` repo on this machine
