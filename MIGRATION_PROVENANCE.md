# Migration Provenance — Saver's Match port from RSAA-cost-simulation-static

**Copy date:** 2026-06-08
**SOURCE repo:** `RSAA-cost-simulation-static`
**SOURCE head commit:** `c1b5dfc466bb1b2508c0ff9b570c272f47f18b42` ("Now policy modeling")
**TARGET repo:** `EIG-Savers-match-sipp` @ `fabd9e6`
**Method:** content-only copy (no git history); see
`Infrastructure/plans/2026-06-08_savers-match-port-from-rsaa.md` for the full manifest and
the approved reconciliation decisions (D1–D7).

All paths below are identical between SOURCE and TARGET unless a "→" indicates remapping.
Every item was copied from SOURCE@`c1b5dfc` on 2026-06-08.

## Code (PORT — new to TARGET)
- `code/00_setup/00b_reexport_dta_to_csv.R`, `code/00_setup/README.md`
- `code/01_data_preparation/README.md`
- `code/03_main_estimation/03f_jct_replication_sm_simulation.R`
- `code/03_main_estimation/03f2_robustness_sweep.R`
- `code/03_main_estimation/03h_simple_saver_illustration.R`
- `code/03_main_estimation/03i_universal_sm_hybrid.R`
- `code/03_main_estimation/03i_universal_sm_hybrid/03i_0{1..6}_*.R` + `README.md`
- `code/03_main_estimation/README.md`
- `code/04_figures/04a_catherine_figures.R`
- `code/README.md`, `code/_shared/README.md`
- `code/python_port/{run_sm_simulation,run_sm_robustness,verify_coverage_2x,build_sm_chart,build_catherine_docx}.py` + `README.md`

## Code (RECONCILE — resolved per D1–D4)
- `code/_shared/calibration_cells.R` — **adopted SOURCE** (D2). Verified: all 12 base functions
  byte-identical to TARGET's prior version; SOURCE adds `aggregate_sipp_person_year()`,
  `build_modeled_sipp_frame_v2()`, `compute_match_rate()`. No TARGET consumer calls the v1
  `build_modeled_sipp_frame()`, so no behavior change for `03g`/`Answers_for_common_questions.R`.
- `code/01_data_preparation/01_sipp_subset_from_dta.R` — **adopted SOURCE** (D3); builds the
  58-column extract (superset of TARGET's 48; first 48 columns identical).
- `code/run_all.R` — **extended TARGET's** (D4), keeping its root-resolution + fresh-env `source()`
  idiom and adding the cost stages (03f, 03f2, 03h, 03i, 04a) with per-stage skip flags.
- `code/00_setup/00_config.R` — **kept TARGET** (identical to SOURCE apart from line endings).
- `code/03_main_estimation/03g_savers_match_eligibility_buckets.R` — **kept TARGET** (D1; TARGET's is
  the larger/newer engine). Not copied from SOURCE.
- Path-reference fix: normalized the stale error-message phrase "RSAA repo root" → "repo root" in 8
  ported scripts. The domain term "RSAA" (Retirement Savings for Americans Act, used by the hybrid)
  was preserved.

## Data — raw
- `data/raw/pu2024_expanded.csv`, `pu2024_expanded.parquet` — **adopted SOURCE** 58-col extract (D3).
- `data/raw/pu2024_expanded_variable_manifest.csv` — PORT.
- `data/raw/irs_soi/22in01pl.xls` — PORT (IRS SOI calibration benchmark).
- `data/raw/cps_asec_2025/cps_00550.dat.gz`, `cps_00550.xml` — PORT alongside TARGET's `cps_00549` (D6).
- `data/raw/README.md` — PORT.
- `data/raw/pu2024.csv` — **kept TARGET** 3.4 GB full CSV; SOURCE's 62 MB subset NOT copied (D5).
- `data/raw/pu2024.dta`, `pu2024_dta.zip` — identical in both; kept TARGET (non-redistributable SIPP, Rule 3).

## Data — processed (PORT; TARGET `processed/` was empty)
- `data/processed/README.md`, `sipp_2024_wrangled.csv`, `sipp_sm_modeled.{parquet,rds}`
- `data/processed/universal_sm_hybrid/` (8 artifacts: universe, pivots, simulation, scenario, phaseout lenses)

## Outputs (PORT — cost-modeling; TARGET's existing eligibility outputs kept per D1)
- `output/tables/main/sm_jct_replication_scenarios.xlsx`, `sm_robustness_scenarios.xlsx`
- `output/tables/appendix/simple_saver_illustration*` (7)
- `output/tables/universal_sm_hybrid/hybrid_{headline,distributional_incidence,by_route}.xlsx`
- `output/tables/savers_match_filer_vs_ebri.{parquet,rds}`
- `output/figures/main/sm_catherine_{cost_comparison,robustness_grouped}.png` (+ cost_comparison_data.csv)
- `output/figures/appendix/simple_saver_illustration{,_real}.png`
- `output/figures/universal_sm_hybrid/` (7 figures incl. 3 phaseout lenses)
- `output/reports/universal_sm_hybrid/` (4 diagnostics)
- `output/review-reports/catherine_memo_audit.html`
- `output/data/figure_data/` (8 CSV), `output/data/intermediate_results/` (README + 2 snapshots)
- `output/README.md`
- KEPT TARGET (regenerated outputs of TARGET's engine, not overwritten): `savers_match_eligibility_buckets.{md,parquet,rds}`, `savers_match_validation_cps_vs_sipp.{parquet,rds}`.

## Drafts & deliverables (PORT)
- `drafts/savers_match_jct_replication/` (4 .docx: Catherine memo + two-pagers, current + 2026-04-29)
- `drafts/README.md`
- `sm_jct_simulation_brief.html` (repo root)
- `review-prompt-savers-match-docs.md` → `Infrastructure/plans/review-prompt-savers-match-docs.md`

## Literature (PORT)
- `literature/x-21-22_jct_jcx-21-22.pdf`, `literature/README.md` — **kept together at top-level
  `literature/`** (deviation from the D7 default of `references/literature/papers/`): the README cites
  the PDF as a sibling and PROJECT.md points at `literature/README.md`; splitting them would break the
  reference. Flagged for your call.
- `Infrastructure/references/literature/catalog.yaml` and `data_dictionaries/2024_SIPP_Data_Dictionary.pdf`
  — identical in both; not re-copied.

## Infrastructure — SM-specific (PORT; TARGET previously held only READMEs)
- `Infrastructure/plans/` — 21 dated SM plans (2026-04-09 … 2026-06-08). Generic
  `2026-05-27_infra-sync-from-template.md` intentionally not ported.
- `Infrastructure/specs/` — 5 dated SM specs.
- `Infrastructure/session_logs/` — 12 dated SM logs. Generic `2026-05-27_infra-sync.md` not ported.

## Review reports (PORT — SM-scoped markdown only)
- `review-reports/{savers-match-verification,savers_match_aggregate_review,sipp-variable-crosswalk,
  critical-high-punchlist,cross-report-assessment_2026-04-24,draft-review-2026-04-18,fix-pass-2026-04-26}.md`
- TARGET's own `*-report.html` set was left in place (not overwritten).

## Left behind (Rule 5)
`archive/**` (incl. `rsaa_pipeline/`), `temp/**`, scratch/test artifacts, generic Infrastructure
scaffolding (rules/templates/agents/commands/style/skills/scripts/adapter_configs/root_instructions),
adapter dirs (`.claude`/`.codex`/`.agents`), and `migration-prompt-savers-match-to-sipp.md`.

## Surfaced for your decision
- `literature/README.md:73` cites the reproducibility package as `bnglasner/RSAA-cost-simulation-static`.
  Update to the EIG repo or keep as historical? (Not rewritten.)
- `PROJECT.md` / `README.md` cost-scope additions drafted separately for review (D7); not yet committed.
