# code/

Analytic pipeline for the Saver's Match eligibility and cost analysis (R 4.4). Every stage reads a
single canonical modeled frame built once per run, so the income concept, thresholds, eligibility,
access flags, and per-person match dollars are defined exactly once.

## Shared core (`_shared/`) — the single sources of truth

| File | Provides |
|---|---|
| `params.R` | `sm_params()` — the ONE policy/methodology parameter set (thresholds, multipliers, projection factor, take-up rates, contribution bands/splits, caps, JCT benchmarks); also emits `data/processed/params.json`. |
| `build_frame.R` | `build_modeled_frame()` — the ONE canonical person-level frame (Option B income projected to TY2027, U1 spouse-pair MFJ income, filing group, thresholds + eligibility per multiplier, access flags, per-person match dollars). |
| `scenario_engine.R` | `run_scenario()` — the ONE participation/cost scenario runner. |
| `calibration_cells.R` | Lower-level helpers (`build_modeled_sipp_frame_v2`, `aggregate_sipp_person_year`, `make_*`, `compute_match_rate`). |
| `DATA_DICTIONARY.md` | Every canonical-frame column defined. |

`00_setup/00_config.R` resolves the project root, sets path variables, and sources the shared core, so
any stage gets everything from one `source(".../00_config.R")`.

## Stage layout

```
code/
├── run_all.R                          pipeline orchestrator (per-stage RUN_* flags)
├── 00_setup/00_config.R               paths + cfg + bootstraps the shared core
├── 00_setup/00b_reexport_dta_to_csv.R optional: rebuild pu2024.csv
├── 01_data_preparation/
│   ├── 01_sipp_subset_from_dta.R      build 58-col pu2024_expanded.csv from pu2024.dta
│   └── 01b_build_modeled_frame.R      build the canonical frame -> data/processed/sipp_modeled.parquet
├── 02_eligibility/
│   ├── 02a_eligibility_buckets.R      three-bucket eligible-population estimates (worker + filer basis)
│   └── 02b_filing_match_decomposition.R  filing-status x match-status contingency tables
├── 03_cost_simulation/
│   ├── 03a_jct_replication.R          JCT (JCX-21-22) replication + four-multiplier cost sim
│   ├── 03b_robustness_sweep.R         20-scenario robustness sweep
│   └── 03c_simple_saver_illustration.R  standalone single-saver illustration (no microdata)
├── 04_universal_hybrid/04_universal_sm_hybrid.R   master: sources the six sub-scripts
│   └── 04_universal_sm_hybrid/04_0[1-6]_*.R        universe / pivots / match / tables / figures / lenses
├── 05_figures/05a_cost_comparison_figures.R       cost-comparison memo figures
├── 06_report/06_universal_hybrid_brief.R          knit the policy-maker-facing hybrid brief (HTML)
└── _shared/                           the shared core (above)
```

## Run order

`Rscript code/run_all.R` (the `RUN_*` flags control which stages execute). Dependency order:
`01` → `01b` (canonical frame) → `02a` → `02b` → `03a` → `03b` → `03c` → `04` → `05a` → `06`. Every stage
from 02 onward reads `data/processed/sipp_modeled.parquet`; none rebuilds the frame.

## Which script produces what

| Output | Produced by |
|---|---|
| `data/processed/sipp_modeled.parquet` (canonical frame) | `01b_build_modeled_frame.R` |
| `savers_match_eligibility_buckets.*` (worker + filer basis), eligibility report | `02a_eligibility_buckets.R` |
| `answers_eligibility_*.{rds,parquet,xlsx}` | `02b_filing_match_decomposition.R` |
| `output/tables/main/sm_jct_replication_scenarios.xlsx` | `03a_jct_replication.R` |
| `output/tables/main/sm_robustness_scenarios.xlsx` | `03b_robustness_sweep.R` |
| `output/tables/appendix/simple_saver_illustration*` | `03c_simple_saver_illustration.R` |
| `output/tables/universal_sm_hybrid/*`, `output/figures/universal_sm_hybrid/*` | `04_universal_sm_hybrid/` sub-scripts |
| `output/figures/main/sm_cost_comparison.png`, `sm_robustness_grouped.png` | `05a_cost_comparison_figures.R` |
| `output/reports/universal_sm_hybrid/universal_hybrid_brief.html` (policy brief) | `06_universal_hybrid_brief.R` |

## Data inputs

| Script | Inputs |
|---|---|
| `01_sipp_subset_from_dta.R` | `data/raw/pu2024.dta` → writes `pu2024_expanded.csv` / `.parquet` |
| `01b_build_modeled_frame.R` | `data/raw/pu2024_expanded.csv` → writes `data/processed/sipp_modeled.parquet` |
| `02a` / `02b` / `03a` / `03b` / `04_*` | `data/processed/sipp_modeled.parquet`; `03a` also uses `data/raw/irs_soi/22in01pl.xls` |
| `03c` | none (self-contained deterministic illustration) |

The former Python port (`code/python_port/`) was retired on 2026-06-08; R is the sole implementation.
See `data/raw/README.md` for the Census Bureau download and file placement.
