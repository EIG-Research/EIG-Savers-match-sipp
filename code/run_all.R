# run_all.R -- Saver's Match pipeline orchestrator
# Author: Ben Glasner
# Research title: Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
#
# Three bodies of work:
#   1. Eligibility (any-match / full-match / full-match-with-account buckets and the
#      filing-status x match-status decomposition).
#   2. Cost simulation: current-law (1.00x) JCT (JCX-21-22) replication and the
#      1.25x / 1.50x / 2.00x threshold-scaling counterfactuals.
#   3. The Universal Saver's Match hybrid proposal.
#
# Pipeline (toggle the RUN_* flags below to skip a stage):
#   00b  -- 00_setup/00b_reexport_dta_to_csv.R              (optional CSV rebuild)
#   01   -- 01_data_preparation/01_sipp_subset_from_dta.R
#           Reads pu2024.dta and writes the 58-column pu2024_expanded.csv (the
#           contribution-amount columns TSCNTAMT_*/ASCNTAMT_* are required by the
#           universal hybrid). Auto-skips if the extract already exists.
#   02a  -- 02_eligibility/02a_eligibility_buckets.R
#   02b  -- 02_eligibility/02b_filing_match_decomposition.R (consumes 02a's .rds)
#   03a  -- 03_cost_simulation/03a_jct_replication.R
#   03b  -- 03_cost_simulation/03b_robustness_sweep.R       (consumes 03a checkpoint)
#   03c  -- 03_cost_simulation/03c_simple_saver_illustration.R
#   04   -- 04_universal_hybrid/04_universal_sm_hybrid.R
#           Thin master sourcing the six 04_0[1-6]_*.R sub-scripts in order.
#   05a  -- 05_figures/05a_cost_comparison_figures.R        (consumes 03a output)
#   06   -- 06_report/06_universal_hybrid_brief.R
#           Knits the policy-maker-facing universal-hybrid brief to HTML
#           (consumes the stage-04 artifacts and the 03a current-law table).
#
# Required data:
#   data/raw/pu2024.dta            (SIPP 2024 Wave 1 Stata file; download from Census)
#   data/raw/irs_soi/22in01pl.xls  (IRS SOI calibration benchmark)
#
# Optional: set EIG_PROJECT_ROOT to the repo root before running, or run from
#   inside the repo tree and the root will be detected automatically.
#
#   Rscript code/run_all.R

rm(list = ls())
options(scipen = 999)
set.seed(42L)

# ---------------------------------------------------------------------------
# Run flags -- flip a stage to FALSE to skip it.
# ---------------------------------------------------------------------------
RUN_00B_REEXPORT_DTA_TO_CSV <- FALSE  # optional; only if pu2024.csv lacks cols
RUN_01_SIPP_SUBSET          <- TRUE   # auto-skips if pu2024_expanded.csv exists
RUN_01B_BUILD_FRAME         <- TRUE   # build the ONE canonical modeled frame (all stages read it)
RUN_02A_ELIGIBILITY_BUCKETS <- TRUE
RUN_02B_FILING_MATCH_DECOMP <- TRUE   # consumes 02a savers_match_eligibility_buckets.rds
RUN_03A_JCT_REPLICATION     <- TRUE
RUN_03B_ROBUSTNESS_SWEEP    <- TRUE   # consumes 03a parquet checkpoint
RUN_03C_SIMPLE_SAVER        <- TRUE   # standalone illustration; no microdata dep
RUN_04_UNIVERSAL_SM_HYBRID  <- TRUE   # sources 04_0[1-6]_*.R sub-scripts
RUN_05A_COST_COMPARISON_FIG <- TRUE   # consumes 03a output
RUN_06_UNIVERSAL_HYBRID_BRIEF <- TRUE # knits the policy brief; consumes stage-04 + 03a artifacts

# ---------------------------------------------------------------------------
# Resolve project root (mirrors the three-tier logic in individual scripts)
# ---------------------------------------------------------------------------
project_root_chr <- Sys.getenv("EIG_PROJECT_ROOT", unset = "")

if (!nzchar(project_root_chr) || !dir.exists(project_root_chr)) {
  candidate_chr <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(10L)) {
    if (file.exists(file.path(candidate_chr, "PROJECT.md"))) {
      project_root_chr <- candidate_chr
      break
    }
    parent_chr <- normalizePath(file.path(candidate_chr, ".."),
                                winslash = "/", mustWork = FALSE)
    if (identical(parent_chr, candidate_chr)) break
    candidate_chr <- parent_chr
  }
}

if (!nzchar(project_root_chr) || !dir.exists(project_root_chr)) {
  stop(
    "Cannot locate repo root. Set EIG_PROJECT_ROOT or run from within the repo.",
    call. = FALSE
  )
}

Sys.setenv(EIG_PROJECT_ROOT = project_root_chr)
message("Project root: ", project_root_chr)

# ---------------------------------------------------------------------------
# Stage runner -- source into a fresh env so the child script's rm(list = ls())
# does not clear run_all.R state. Each child re-resolves the root via
# EIG_PROJECT_ROOT, set above.
# ---------------------------------------------------------------------------
run_stage <- function(flag, rel_path, label) {
  if (!isTRUE(flag)) {
    message("[SKIP]  ", label)
    return(invisible(NULL))
  }
  message("[RUN]   ", label, " (", rel_path, ")")
  start_time <- Sys.time()
  source(file.path(project_root_chr, rel_path),
         local = new.env(parent = globalenv()))
  elapsed <- round(as.numeric(difftime(Sys.time(), start_time, units = "secs")), 2)
  message("[OK]    ", label, " finished in ", elapsed, "s")
  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Step 01: SIPP expanded extract (also auto-skips if the extract already exists)
# ---------------------------------------------------------------------------
expanded_csv_chr <- file.path(project_root_chr, "data", "raw", "pu2024_expanded.csv")
if (isTRUE(RUN_01_SIPP_SUBSET) && file.exists(expanded_csv_chr)) {
  message("[SKIP]  01   pu2024_expanded.csv already exists.")
} else {
  run_stage(RUN_01_SIPP_SUBSET,
            file.path("code", "01_data_preparation", "01_sipp_subset_from_dta.R"),
            "01   Build pu2024_expanded.csv")
}

run_stage(RUN_00B_REEXPORT_DTA_TO_CSV,
          file.path("code", "00_setup", "00b_reexport_dta_to_csv.R"),
          "00b  Rebuild pu2024.csv from pu2024.dta")

run_stage(RUN_01B_BUILD_FRAME,
          file.path("code", "01_data_preparation", "01b_build_modeled_frame.R"),
          "01b  Build canonical modeled frame (sipp_modeled.parquet)")

run_stage(RUN_02A_ELIGIBILITY_BUCKETS,
          file.path("code", "02_eligibility", "02a_eligibility_buckets.R"),
          "02a  Saver's Match three-bucket eligibility report")

run_stage(RUN_02B_FILING_MATCH_DECOMP,
          file.path("code", "02_eligibility", "02b_filing_match_decomposition.R"),
          "02b  Filing-status x match-status decomposition")

run_stage(RUN_03A_JCT_REPLICATION,
          file.path("code", "03_cost_simulation", "03a_jct_replication.R"),
          "03a  JCT replication + four-multiplier cost simulation")

run_stage(RUN_03B_ROBUSTNESS_SWEEP,
          file.path("code", "03_cost_simulation", "03b_robustness_sweep.R"),
          "03b  Robustness sweep")

run_stage(RUN_03C_SIMPLE_SAVER,
          file.path("code", "03_cost_simulation", "03c_simple_saver_illustration.R"),
          "03c  Simple saver illustration")

run_stage(RUN_04_UNIVERSAL_SM_HYBRID,
          file.path("code", "04_universal_hybrid", "04_universal_sm_hybrid.R"),
          "04   Universal Saver's Match hybrid (sources six sub-scripts)")

run_stage(RUN_05A_COST_COMPARISON_FIG,
          file.path("code", "05_figures", "05a_cost_comparison_figures.R"),
          "05a  Cost-comparison memo figures")

run_stage(RUN_06_UNIVERSAL_HYBRID_BRIEF,
          file.path("code", "06_report", "06_universal_hybrid_brief.R"),
          "06   Universal Saver's Match hybrid policy brief (HTML)")

message("\nrun_all.R finished. Outputs in output/tables/, output/figures/, output/reports/.")
