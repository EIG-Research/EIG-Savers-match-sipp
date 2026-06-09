# 06_universal_hybrid_brief -- Render the policy-maker-facing brief on the
#   Universal Saver's Match hybrid to a self-contained HTML document.
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
#
# This stage is the only one that produces an external-audience deliverable. It
# knits universal_hybrid_brief.Rmd, which reads the live universal-hybrid
# artifacts (scenario results, pivot table, per-worker simulation, universe
# funnel, schedule figures) and the current-law baseline table, then writes a
# roughly two-page HTML brief that assumes the reader has no access to this
# repository. Because the brief reads the artifacts at knit time, its numbers
# always match the most recent pipeline run.
#
# Inputs (all produced by stages 03a and 04):
#   data/processed/universal_sm_hybrid/scenario_results.parquet
#   data/processed/universal_sm_hybrid/pivot_table.rds
#   data/processed/universal_sm_hybrid/simulation_results.parquet
#   output/reports/universal_sm_hybrid/universe_funnel.csv
#   output/figures/universal_sm_hybrid/{match_rate_by_magi,incidence_by_decile,universe_funnel}.png
#   output/tables/main/sm_jct_replication_scenarios.xlsx   (current-law contrast)
# Output:
#   output/reports/universal_sm_hybrid/universal_hybrid_brief.html

rm(list = ls())
options(scipen = 999)

###################################################################################
###                            Project Root Resolution                          ###
###################################################################################
project_root <- NA_character_
env_root_chr <- Sys.getenv("EIG_PROJECT_ROOT", unset = NA_character_)
if (!is.na(env_root_chr) && nzchar(env_root_chr) &&
    dir.exists(file.path(env_root_chr, "Infrastructure"))) {
  project_root <- normalizePath(env_root_chr)
}
if (is.na(project_root)) {
  candidate_chr <- normalizePath(getwd())
  while (!dir.exists(file.path(candidate_chr, "Infrastructure")) &&
         candidate_chr != dirname(candidate_chr)) {
    candidate_chr <- dirname(candidate_chr)
  }
  if (dir.exists(file.path(candidate_chr, "Infrastructure"))) {
    project_root <- candidate_chr
  }
}
if (is.na(project_root)) {
  frames_list <- sys.frames()
  sourced_path_chr <- NA_character_
  for (i in rev(seq_along(frames_list))) {
    ofile_candidate <- frames_list[[i]]$ofile
    if (!is.null(ofile_candidate) && is.character(ofile_candidate) &&
        nzchar(ofile_candidate)) {
      sourced_path_chr <- ofile_candidate
      break
    }
  }
  if (!is.na(sourced_path_chr)) {
    candidate_chr <- normalizePath(dirname(sourced_path_chr))
    while (!dir.exists(file.path(candidate_chr, "Infrastructure")) &&
           candidate_chr != dirname(candidate_chr)) {
      candidate_chr <- dirname(candidate_chr)
    }
    if (dir.exists(file.path(candidate_chr, "Infrastructure"))) {
      project_root <- candidate_chr
    }
  }
}
if (is.na(project_root)) {
  stop("Could not locate repo root. Set EIG_PROJECT_ROOT or setwd().", call. = FALSE)
}
Sys.setenv(EIG_PROJECT_ROOT = project_root)
message("Using project_root: ", project_root)

###################################################################################
###                       Preconditions and Dependencies                       ###
###################################################################################
if (!requireNamespace("rmarkdown", quietly = TRUE) ||
    !rmarkdown::pandoc_available()) {
  warning("rmarkdown / pandoc unavailable; skipping the universal-hybrid brief.",
          call. = FALSE)
} else {

  rmd_path_chr <- file.path(project_root, "code", "06_report",
                            "universal_hybrid_brief.Rmd")
  if (!file.exists(rmd_path_chr)) {
    stop("Brief source not found at: ", rmd_path_chr, call. = FALSE)
  }

  # Required upstream artifacts. Fail fast with an actionable message rather than
  # rendering a brief full of missing-value errors.
  required_inputs_chr <- c(
    file.path(project_root, "data", "processed", "universal_sm_hybrid", "scenario_results.parquet"),
    file.path(project_root, "data", "processed", "universal_sm_hybrid", "pivot_table.rds"),
    file.path(project_root, "data", "processed", "universal_sm_hybrid", "simulation_results.parquet"),
    file.path(project_root, "output", "reports", "universal_sm_hybrid", "universe_funnel.csv")
  )
  missing_inputs_chr <- required_inputs_chr[!file.exists(required_inputs_chr)]
  if (length(missing_inputs_chr) > 0L) {
    stop("Cannot build the brief; the universal-hybrid stage has not produced:\n  ",
         paste(missing_inputs_chr, collapse = "\n  "),
         "\nRun the universal Saver's Match hybrid stage first.", call. = FALSE)
  }

  out_dir_chr  <- file.path(project_root, "output", "reports", "universal_sm_hybrid")
  if (!dir.exists(out_dir_chr)) dir.create(out_dir_chr, recursive = TRUE)
  out_file_chr <- "universal_hybrid_brief.html"

  message("Rendering universal-hybrid policy brief ...")
  rmarkdown::render(
    input       = rmd_path_chr,
    output_file = out_file_chr,
    output_dir  = out_dir_chr,
    params      = list(root = project_root),
    quiet       = TRUE,
    envir       = new.env(parent = globalenv())
  )
  message("Wrote: ", file.path(out_dir_chr, out_file_chr))
  message("06_universal_hybrid_brief.R complete.")
}
