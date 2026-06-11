# Data Guide for Panelists

This repository already contains the full simulation pipeline and its outputs. Panelists should *read* these outputs and the row-level frames; do not re-run or modify the pipeline itself.

## Running R

- R 4.4.3 is installed. Run scripts with:
  `& "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/NN-your-folder/code/script.R`
- Always run from the repository root; use relative paths in scripts.
- Available packages: `arrow`, `dplyr`, `tidyr`, `ggplot2`, `scales`, `readxl`, `openxlsx` (and dependencies). Do not install new packages.
- `python` on PATH is a Microsoft Store stub — do not use Python.

## Key documents

| File | Content |
|---|---|
| `Infrastructure/specs/2026-05-28_universal-account-savers-match-hybrid-proposal.md` | The policy proposal under review (read this first, in full). |
| `Infrastructure/specs/2026-05-27_universal-account-savers-match-hybrid.md` | Technical spec, including legal-scholar review of SIPP-vs-§6433 divergences. |
| `output/reports/universal_sm_hybrid/universal_hybrid_brief.html` | Auto-generated brief; regenerates all numbers from the live model. |
| `PROJECT.md` | Repository profile, income-concept decisions, current-law baselines. |
| `economist-panel/_shared/policy-context.md` | Common factual brief: Saver's Match political economy, Trump EO / TrumpIRA.gov, RSAA. |

## Row-level data (Apache parquet, read with `arrow::read_parquet()`)

All dollar values are SIPP 2024 incomes projected once to TY2027 (×1.093) and compared against statutory 2027 thresholds. All person weights are `WPFINWGT`/`weight` (SIPP final person weights); divide weighted sums by 1e6 for millions.

### `data/processed/universal_sm_hybrid/simulation_results.parquet` (14,961 rows = the 145.34M-worker universe)

| Column | Meaning |
|---|---|
| `SSUID`, `PNUM` | Person identifiers |
| `WPFINWGT` | Person weight |
| `EFSTATUS`, `TAGE` | Family status code, age |
| `filing_group_chr` | `single_mfs`, `mfj`, `hoh` |
| `magi_num` | MAGI proxy (TY2027 dollars; joint income for MFJ) |
| `earnings_num` | Personal earnings (TY2027 dollars) |
| `has_existing_dc_flag`, `participating_dc_flag` | Existing DC account / observed participation |
| `any_retirement_access_v2_chr` | Workplace retirement access |
| `private_sector_employee_flag`, `self_employed_flag` | Class-of-worker flags |
| `route_chr` | Channel routing: employer plan vs. federal universal account |
| `match_rate_pp_num`, `match_rate_frac_num` | Hybrid match rate (percentage points / fraction) |
| `default_contrib_num` | 3 percent default contribution (dollars) |
| `match_per_worker_num` | Federal match at full participation, `min(rate × contrib, $1,000)` |
| `eligible_flag` | In the hybrid eligibility band (46.07M weighted) |

### `data/processed/universal_sm_hybrid/universe_dec.parquet`
Same universe rows without simulation columns (pre-simulation frame).

### `data/processed/universal_sm_hybrid/scenario_results.parquet` (5 rows)
Scenario ladder: eligible (M), participants (M), take-up, average match, annual cost ($M). Headline = SIPP-observed conditional participation (59.8 percent, $14.9B); 80 percent auto-enrollment ($19.9B); 100 percent ($24.9B).

### `data/processed/universal_sm_hybrid/pivot_table.parquet` (3 rows)
Per filing group: pivot MAGI, endpoint, slope (pp per dollar), weighted median MAGI. Pivots: Single $32,879 / MFJ $65,758 / HoH $49,319; endpoints at 4/3 of pivot.

### `data/processed/sipp_modeled.parquet` (36,214 rows = full modeled SIPP frame, incl. out-of-universe persons)
Canonical frame behind the current-law (1.00×) and expanded-threshold (1.25×/1.50×/2.00×) Saver's Match scenarios. Key columns: `weight`, `age`, `filing_group`, `sm_income_2027` (MAGI proxy), `earnings_2027`, `in_universe`, `has_dc_account`, `any_retirement_access`, `is_participating_dc`, `is_self_employed`, `is_private_sector_employee`, plus per-multiplier flags `is_anymatch_m100` … `is_eligible_dc_m200`, current-law match `sm_match_per_person`, and universal-access match columns `univ_sm_match_m100` … `_m200`. Current-law thresholds (TY2027): Single $20,500–$35,500; MFJ $41,000–$71,000; HoH $30,750–$53,250.

### Figure-ready CSVs in `output/data/figure_data/`
- `universal_sm_hybrid_match_rate_schedule.csv` — match rate vs. MAGI by filing group (proposal schedule).
- `universal_sm_hybrid_incidence_by_decile.csv` — pooled-universe decile incidence.
- `universal_sm_hybrid_universe_funnel.csv` — universe → eligible funnel.
- `universal_sm_hybrid_phaseout_lenses.csv` — phaseout diagnostics (incl. contribution-to-hit-cap).
- `sm_cost_comparison_data.csv`, `sm_robustness_grouped_data.csv` — current-law and expanded-threshold cost scenarios.

### Headline tables (`.xlsx`, read with `readxl::read_excel()`)
- `output/tables/universal_sm_hybrid/hybrid_headline.xlsx`, `hybrid_by_route.xlsx`, `hybrid_distributional_incidence.xlsx`
- `output/tables/main/sm_jct_replication_scenarios.xlsx` (current-law 1.00× row: 33.08M eligible, $9.19B full participation, $278 avg match)

> **Superseded 2026-06-11 (D1 re-anchoring).** The numbers in this section are the basis the ten panelists analyzed. The production model was subsequently re-anchored to the IRS single-filer median (75% at ⅔ of the median); the current canonical headline is **44.47M eligible / $14.15B / $23.87B ceiling**, pivots Single $32,235 / HoH $48,353 / MFJ $64,471. See `economist-panel/DESIGN-DECISIONS.md` (D1) and `_shared/anchoring/FINDINGS.md`. The panel assessments below were written against the pre-re-anchoring figures and are intentionally preserved as historical analysis.

## Canonical headline numbers (snapshot 2026-06-09; superseded — see note above)

- Universe: 145.34M workers; eligible under hybrid: 46.07M (31.7 percent).
- Headline cost $14.9B/yr at 59.8 percent take-up; $543 average match per participant; full-participation ceiling $24.9B.
- Routing: 26.65M (57.9 percent) of eligible default to the federal universal account; 19.41M via employer plans.
- Match schedule: 200 percent at zero MAGI, linear to 50 percent at the pivot, zero at 4/3 × pivot; $1,000 per-individual cap; 3 percent default contribution.
- Current-law §6433 contrast: 33.08M eligible, $9.2B full participation, $278 average match, 50 percent rate, $20,500/$30,750/$41,000 phaseout starts.

## Known measurement caveats (from the legal-scholar review — do not rediscover these as if new)

1. SIPP total-income proxy diverges from true §6433 MAGI (material; cost likely within ±15 percent).
2. §6433(d)(2) distribution-recapture not modeled (overstates cost somewhat).
3. 2024 incomes projected to TY2027 by a single 1.093 factor.
4. Self-employed contribution mechanism unspecified (take-up likely overstated for the 4.41M self-employed eligibles).
5. No employer-response, labor-supply, or administrative-cost modeling.
6. Point estimates only; no replicate-weight standard errors yet.

## Write discipline

Panelists write **only** inside `economist-panel/<your-folder>/`. Anything outside (pipeline code, outputs, specs) is read-only.
