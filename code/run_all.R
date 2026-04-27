# run_all.R -- Saver's Match eligibility pipeline orchestrator
# Author: Ben Glasner
# Research title: Saver's Match Eligibility Analysis (SECURE 2.0, IRC sec 6433)
# Research question: How large is the Saver's Match eligible population and its nested subsets?
#
# Pipeline:
#   Step 1 -- 01_data_preparation/01_sipp_subset_from_dta.R
#             Reads pu2024.dta from data/raw/ and writes pu2024_expanded.csv
#             (expanded 48-column extract needed by 03g). Skipped automatically
#             if pu2024_expanded.csv already exists.
#
#   Step 2 -- 03_main_estimation/03g_savers_match_eligibility_buckets.R
#             Produces three nested bucket estimates (any-match, full-match,
#             full-match-with-account) plus access gap counts. Outputs go to
#             output/tables/ and output/reports/.
#
# Required data:
#   data/raw/pu2024.dta  (SIPP 2024 Wave 1 Stata file; download from Census)
#
# Optional: set EIG_PROJECT_ROOT to the repo root before running, or run
#   from inside the repo tree and the root will be detected automatically.

rm(list = ls())
options(scipen = 999)
set.seed(42L)

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
# Step 1: SIPP expanded extract (skip if already built)
# ---------------------------------------------------------------------------
expanded_csv_chr <- file.path(project_root_chr, "data", "raw", "pu2024_expanded.csv")

if (file.exists(expanded_csv_chr)) {
  message("Step 1 SKIPPED: pu2024_expanded.csv already exists.")
} else {
  message("Step 1: Building pu2024_expanded.csv from pu2024.dta ...")
  # Source into a fresh env so the child script's rm(list = ls()) at the top
  # does not clear project_root_chr (and other run_all.R state) from the
  # global env. Each child script re-resolves project_root via the
  # EIG_PROJECT_ROOT env var that run_all.R sets above.
  source(file.path(project_root_chr, "code", "01_data_preparation",
                   "01_sipp_subset_from_dta.R"),
         local = new.env(parent = globalenv()))
  message("Step 1 COMPLETE.")
}

# ---------------------------------------------------------------------------
# Step 2: Eligibility bucket estimation
# ---------------------------------------------------------------------------
message("Step 2: Running 03g_savers_match_eligibility_buckets.R ...")
# Same fresh-env pattern as Step 1: child rm(list = ls()) is local to the
# new env and does not wipe run_all.R's variables.
source(file.path(project_root_chr, "code", "03_main_estimation",
                 "03g_savers_match_eligibility_buckets.R"),
       local = new.env(parent = globalenv()))
message("Step 2 COMPLETE.")

message("run_all.R finished. Outputs in output/tables/ and output/reports/.")
