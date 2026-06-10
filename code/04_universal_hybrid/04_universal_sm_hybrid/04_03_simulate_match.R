# 04_03_simulate_match -- Cost and incidence simulation under the hybrid policy
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - Under the single-line match schedule (200% at $0 MAGI, declining to 50% at the
#                     pivot -- the design fixes the Single rate at 75% at one-half the Single
#                     weighted-median MAGI, which places the 50% pivot at 0.6x that median -- with
#                     MFJ/HoH pivots scaled by the SM lower-threshold ratios), what is the cost,
#                     eligible-worker count, and distributional incidence?
#
# DESCRIPTION:
# Apply compute_match_rate() to every worker in the 04 universe. Compute match
# per worker as min(rate / 100 * contribution, $1,000) where contribution is
# the 3 percent RSAA default applied uniformly per the spec.
#
# Routing per spec Section 3:
#   - Universal account: any_retirement_access_v2_chr != "Yes" OR self_employed
#   - Employer plan:     any_retirement_access_v2_chr == "Yes" AND NOT self_employed
#
# Behavioral scenarios:
#   Headline:    SIPP-observed conditional DC participation, row-level
#                PARTICIPATING_DC for DC-access workers + uniform scalar for
#                universal-account workers.
#   Sensitivity: 5.7%, 80%, 100% take-up.
#
# Inputs:
#   data/processed/universal_sm_hybrid/universe_dec.parquet
#   data/processed/universal_sm_hybrid/pivot_table.rds
#   code/_shared/calibration_cells.R
# Outputs:
#   data/processed/universal_sm_hybrid/simulation_results.parquet
#   data/processed/universal_sm_hybrid/scenario_results.parquet
#   output/reports/universal_sm_hybrid/scenario_diagnostics.md

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                              Load Packages                                  ###
###################################################################################
suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
})

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
message("Using project_root: ", project_root)

source(file.path(project_root, "code", "_shared", "calibration_cells.R"))

###################################################################################
###                         Configuration and Paths                             ###
###################################################################################
path_data_processed_chr <- file.path(project_root, "data", "processed", "universal_sm_hybrid")
path_output_reports_chr <- file.path(project_root, "output", "reports", "universal_sm_hybrid")
if (!dir.exists(path_data_processed_chr)) dir.create(path_data_processed_chr, recursive = TRUE)
if (!dir.exists(path_output_reports_chr)) dir.create(path_output_reports_chr, recursive = TRUE)

###################################################################################
###                      1) Policy Parameters and Sanity Asserts                ###
###################################################################################
policy_params <- list(
  default_contrib_rate_num = 0.03,
  max_credit_num           = 1000,
  # NOTE: the two schedule values below are DESCRIPTIVE ONLY. compute_match_rate()
  # in calibration_cells.R is the single source of truth for the match-rate
  # schedule and does not read these; they are kept in sync purely for
  # documentation. 2026-06-08 redesign: floor is 200 percent at $0 MAGI (down
  # from the 2026-05-28 300 percent), and the 50 percent point sits at the pivot,
  # which the design anchors by fixing the Single rate at 75 percent at one-half
  # the Single weighted-median MAGI (placing the 50 percent pivot at 0.6x that
  # median and the 0 percent endpoint at (4/3)x pivot = 0.8x the median).
  match_rate_floor_pp_num  = 200,
  match_rate_pivot_pp_num  = 50,
  takeup_no_auto_num       = 0.057,
  takeup_auto_enroll_num   = 0.80,
  takeup_full_num          = 1.00
)

stopifnot(
  "default_contrib_rate_num must be in (0, 1)" =
    policy_params$default_contrib_rate_num > 0 && policy_params$default_contrib_rate_num < 1,
  "max_credit_num must be > 0" = policy_params$max_credit_num > 0,
  "takeup parameters must be in [0, 1]" =
    all(c(policy_params$takeup_no_auto_num,
          policy_params$takeup_auto_enroll_num,
          policy_params$takeup_full_num) >= 0) &&
    all(c(policy_params$takeup_no_auto_num,
          policy_params$takeup_auto_enroll_num,
          policy_params$takeup_full_num) <= 1)
)

###################################################################################
###                      2) Load Universe and Pivot Table                       ###
###################################################################################
universe_parquet_path_chr <- file.path(path_data_processed_chr, "universe_dec.parquet")
pivot_rds_path_chr        <- file.path(path_data_processed_chr, "pivot_table.rds")

if (!file.exists(universe_parquet_path_chr)) {
  stop("Universe not found at: ", universe_parquet_path_chr, call. = FALSE)
}
if (!file.exists(pivot_rds_path_chr)) {
  stop("Pivot table not found at: ", pivot_rds_path_chr, call. = FALSE)
}

universe_tbl      <- read_parquet(universe_parquet_path_chr)
pivot_obj_list    <- readRDS(pivot_rds_path_chr)
sm_pivot_2024_num <- pivot_obj_list$pivot_vec_num

message(sprintf("Universe: %d rows (weighted M: %.2f).",
                nrow(universe_tbl),
                sum(universe_tbl$WPFINWGT, na.rm = TRUE) / 1e6))
message("Pivot table:")
for (g in names(sm_pivot_2024_num)) {
  message(sprintf("  %-12s: pivot = $%d", g, round(sm_pivot_2024_num[[g]], 0L)))
}

###################################################################################
###          3) Construct Access Flags and Routing on the Universe              ###
###################################################################################
# Access flags (has_existing_dc_flag, participating_dc_flag, any_retirement_access_v2_chr) are now
# carried on the canonical-frame-derived universe (04_01) -- the single source of truth -- so they are
# not re-derived from raw SIPP here. Only the hybrid-specific routing rule is applied.
universe_tbl <- universe_tbl |>
  dplyr::mutate(
    # Routing is explicit about NA/missing inputs (no reliance on the TRUE
    # fall-through to absorb them): `%in% TRUE` treats NA self-employment as
    # not-self-employed, and missing/NA access routes to the universal account.
    # This is behaviorally identical to the prior fall-through but self-documenting.
    route_chr = dplyr::case_when(
      self_employed_flag %in% TRUE                          ~ "universal_account",
      any_retirement_access_v2_chr == "Yes"                 ~ "employer_plan",
      is.na(any_retirement_access_v2_chr) |
        any_retirement_access_v2_chr %in% c("No", "Missing") ~ "universal_account",
      TRUE                                                  ~ "universal_account"
    )
  )

routing_counts_tbl <- universe_tbl |>
  dplyr::group_by(route_chr) |>
  dplyr::summarise(
    n_rows_int     = dplyr::n(),
    weighted_n_num = sum(WPFINWGT, na.rm = TRUE),
    .groups = "drop"
  )
message("Routing distribution:")
for (i in seq_len(nrow(routing_counts_tbl))) {
  message(sprintf("  %-20s: n = %7d  weighted (M) = %6.2f",
                  routing_counts_tbl$route_chr[i],
                  routing_counts_tbl$n_rows_int[i],
                  routing_counts_tbl$weighted_n_num[i] / 1e6))
}

###################################################################################
###          4) Apply Match-Rate Schedule and Compute Match Per Worker          ###
###################################################################################
universe_tbl <- universe_tbl |>
  dplyr::mutate(
    match_rate_pp_num    = compute_match_rate(
      magi_num         = magi_num,
      filing_group_chr = filing_group_chr,
      pivot_table      = sm_pivot_2024_num
    ),
    match_rate_frac_num  = match_rate_pp_num / 100,
    # Contribution base is PERSONAL EARNINGS (earnings_num), not joint MAGI.
    # Revised 2026-05-28 to align with current-law IRC sec 6433 per-individual
    # cap semantics: each eligible individual contributes from their own
    # earnings; the 3 percent default applies to wages/earnings, not to total
    # personal income or joint MAGI. Match rate continues to use magi_num
    # (which for MFJ is the joint MAGI via the U1 spouse-pair sum) -- that
    # determines the schedule position; only the contribution base changes.
    # The prior implementation used magi_num as the contribution base,
    # which for MFJ effectively assumed each spouse contributed 3 percent of
    # joint MAGI -- a doubled household contribution at low incomes.
    default_contrib_num  = policy_params$default_contrib_rate_num * earnings_num,
    # Match per worker: floor at zero (defensive for any future edge case where
    # rate or contribution could produce negative values), cap at $1,000.
    match_per_worker_num = pmax(
      0,
      pmin(match_rate_frac_num * default_contrib_num,
           policy_params$max_credit_num)
    ),
    eligible_flag = dplyr::case_when(
      is.na(match_rate_pp_num) ~ FALSE,
      match_rate_pp_num > 0    ~ TRUE,
      TRUE                      ~ FALSE
    )
  )

eligible_n_int     <- sum(universe_tbl$eligible_flag, na.rm = TRUE)
eligible_wgt_M_num <- sum(universe_tbl$WPFINWGT[universe_tbl$eligible_flag], na.rm = TRUE) / 1e6
message(sprintf("Eligible workers: %d unweighted (%.2f M weighted)",
                eligible_n_int, eligible_wgt_M_num))

###################################################################################
###     5) Compute SIPP-Observed Conditional DC Participation Rate (scalar)     ###
###################################################################################
dc_universe_mask_flag <- universe_tbl$has_existing_dc_flag &
                          universe_tbl$eligible_flag &
                          !is.na(universe_tbl$participating_dc_flag)
sipp_observed_dc_rate_num <- if (sum(universe_tbl$WPFINWGT[dc_universe_mask_flag], na.rm = TRUE) > 0) {
  sum(universe_tbl$WPFINWGT[dc_universe_mask_flag] *
        as.numeric(universe_tbl$participating_dc_flag[dc_universe_mask_flag]),
      na.rm = TRUE) /
    sum(universe_tbl$WPFINWGT[dc_universe_mask_flag], na.rm = TRUE)
} else {
  NA_real_
}
message(sprintf("SIPP-observed conditional DC participation rate: %.4f",
                sipp_observed_dc_rate_num))

if (is.na(sipp_observed_dc_rate_num) || sipp_observed_dc_rate_num <= 0 ||
    sipp_observed_dc_rate_num >= 1) {
  warning("SIPP-observed conditional DC participation rate is ",
          round(sipp_observed_dc_rate_num, 4L),
          ". Expected in (0, 1). Verify before publishing.", call. = FALSE)
}

###################################################################################
###          6) Inline run_scenario() Helper (Copied from 03a)                  ###
###################################################################################
run_scenario <- function(df,
                         scenario_name_chr,
                         participation_rate_num = NULL,
                         use_observed_dc_flag   = FALSE,
                         eligible_col_chr       = "eligible_flag",
                         match_col_chr          = "match_per_worker_num",
                         scenario_group_chr     = "headline") {

  # No RNG: the uniform-rate scenarios use the closed-form expectation (below),
  # not a random realization, so this function is deterministic.

  eligible_flag    <- df[[eligible_col_chr]] == TRUE
  match_values_num <- df[[match_col_chr]]
  w_num            <- df$WPFINWGT

  total_eligible_wgt_num <- sum(w_num[eligible_flag], na.rm = TRUE)
  # Full-participation cost over the eligible set: the deterministic basis for the
  # expected cost under any uniform participation rate.
  full_participation_cost_num <- sum(match_values_num[eligible_flag] *
                                       w_num[eligible_flag], na.rm = TRUE)

  if (isTRUE(use_observed_dc_flag)) {
    # Row-level observed participation (SIPP data, not a draw): deterministic.
    participant_flag <- eligible_flag &
                        !is.na(df$participating_dc_flag) &
                        df$participating_dc_flag == TRUE
    total_participants_wgt_num <- sum(w_num[participant_flag], na.rm = TRUE)
    total_sm_cost_num          <- sum(match_values_num[participant_flag] *
                                        w_num[participant_flag], na.rm = TRUE)
  } else if (!is.null(participation_rate_num) && participation_rate_num >= 1.0) {
    total_participants_wgt_num <- total_eligible_wgt_num
    total_sm_cost_num          <- full_participation_cost_num
  } else if (!is.null(participation_rate_num) && participation_rate_num <= 0.0) {
    total_participants_wgt_num <- 0
    total_sm_cost_num          <- 0
  } else {
    # EXPECTED-VALUE (closed form), not a single random realization. Applying a
    # uniform participation rate selects each eligible worker with probability =
    # rate, independent of match size, so E[participants] = rate x eligible weight
    # and E[cost] = rate x full-participation cost. Using the expectation removes
    # the arbitrary seed dependence of the former runif()-based selection, which
    # moved the headline cost by ~$90M (SD) across seeds (decision C(ii),
    # 2026-06-09). The 04 universe uses a flat 3% contribution, so with the random
    # take-up draw removed the hybrid estimates are now fully deterministic.
    total_participants_wgt_num <- participation_rate_num * total_eligible_wgt_num
    total_sm_cost_num          <- participation_rate_num * full_participation_cost_num
  }

  avg_match_per_participant_num <- if (total_participants_wgt_num > 0) {
    total_sm_cost_num / total_participants_wgt_num
  } else NA_real_

  list(
    scenario_name_chr        = scenario_name_chr,
    scenario_group_chr       = scenario_group_chr,
    eligible_count_M_num     = round(total_eligible_wgt_num / 1e6, 2L),
    participant_count_M_num  = round(total_participants_wgt_num / 1e6, 2L),
    takeup_rate_num          = if (total_eligible_wgt_num > 0) round(total_participants_wgt_num / total_eligible_wgt_num, 4L) else NA_real_,
    avg_match_per_person_num = round(avg_match_per_participant_num, 0L),
    annual_cost_M_num        = round(total_sm_cost_num / 1e6, 0L)
  )
}

###################################################################################
###             7) Run the Headline and Sensitivity Scenarios                   ###
###################################################################################
dc_access_mask_flag <- universe_tbl$has_existing_dc_flag
universe_dc_tbl     <- universe_tbl[dc_access_mask_flag, ]
headline_dc_result_list <- run_scenario(
  df                   = universe_dc_tbl,
  scenario_name_chr    = "headline_dc_access_row_level",
  use_observed_dc_flag = TRUE,
  scenario_group_chr   = "headline"
)

universal_account_mask_flag <- !dc_access_mask_flag
universe_universal_tbl      <- universe_tbl[universal_account_mask_flag, ]
headline_universal_result_list <- run_scenario(
  df                     = universe_universal_tbl,
  scenario_name_chr      = "headline_universal_account_uniform",
  participation_rate_num = sipp_observed_dc_rate_num,
  scenario_group_chr     = "headline"
)

# Take the eligible count from the single unrounded universe total (the DC-access
# and universal-account branches partition the eligible universe), rather than
# summing the two separately-rounded branch counts -- this avoids a 0.01M
# double-rounding artifact that otherwise made the headline eligible count (46.06M)
# disagree with the single-population sensitivity rows (46.07M).
headline_eligible_M_num     <- round(eligible_wgt_M_num, 2L)
headline_participants_M_num <- headline_dc_result_list$participant_count_M_num +
                                 headline_universal_result_list$participant_count_M_num
headline_cost_M_num         <- headline_dc_result_list$annual_cost_M_num +
                                 headline_universal_result_list$annual_cost_M_num
headline_avg_match_num <- if (headline_participants_M_num > 0) {
  round(
    (headline_dc_result_list$avg_match_per_person_num * headline_dc_result_list$participant_count_M_num +
       headline_universal_result_list$avg_match_per_person_num * headline_universal_result_list$participant_count_M_num) /
      headline_participants_M_num,
    0L
  )
} else NA_real_

headline_combined_list <- list(
  scenario_name_chr        = "headline_sipp_observed_conditional",
  scenario_group_chr       = "headline",
  eligible_count_M_num     = headline_eligible_M_num,
  participant_count_M_num  = headline_participants_M_num,
  takeup_rate_num          = if (headline_eligible_M_num > 0) round(headline_participants_M_num / headline_eligible_M_num, 4L) else NA_real_,
  avg_match_per_person_num = headline_avg_match_num,
  annual_cost_M_num        = headline_cost_M_num
)

# Note: the former 5.7% "no-auto-enrollment floor" sensitivity (anchored on the
# legacy Saver's Credit opt-in claim rate) was removed -- that rate is not a
# realistic participation assumption under an auto-enrollment design, and the
# legacy-credit claim rate is not relevant to this policy. The reported range runs
# from the headline (observed conditional participation) up to full participation.
sens_auto_enroll_list <- run_scenario(
  df                     = universe_tbl,
  scenario_name_chr      = "sens_auto_enroll_80pct",
  participation_rate_num = policy_params$takeup_auto_enroll_num,
  scenario_group_chr     = "sensitivity"
)
sens_full_list <- run_scenario(
  df                     = universe_tbl,
  scenario_name_chr      = "sens_full_participation_100pct",
  participation_rate_num = policy_params$takeup_full_num,
  scenario_group_chr     = "sensitivity"
)

scenarios_list <- list(
  headline_combined_list,
  headline_dc_result_list,
  headline_universal_result_list,
  sens_auto_enroll_list,
  sens_full_list
)

scenarios_tbl <- dplyr::bind_rows(lapply(scenarios_list, as.data.frame))

message("Scenario results:")
for (i in seq_len(nrow(scenarios_tbl))) {
  message(sprintf(
    "  %-40s %-12s  eligible_M = %5.2f  participants_M = %5.2f  takeup = %.4f  avg = $%4d  cost_M = $%5d",
    scenarios_tbl$scenario_name_chr[i],
    scenarios_tbl$scenario_group_chr[i],
    scenarios_tbl$eligible_count_M_num[i],
    scenarios_tbl$participant_count_M_num[i],
    scenarios_tbl$takeup_rate_num[i],
    scenarios_tbl$avg_match_per_person_num[i],
    scenarios_tbl$annual_cost_M_num[i]
  ))
}

###################################################################################
###                  8) Write Scenario Results and Per-Row Simulation           ###
###################################################################################
scenarios_parquet_path_chr  <- file.path(path_data_processed_chr, "scenario_results.parquet")
simulation_parquet_path_chr <- file.path(path_data_processed_chr, "simulation_results.parquet")

# Defensive verification: write_parquet() can silently fail on Windows when the
# target file is held open by another process (RStudio viewer, Power BI, etc.).
# Three-pronged check after each write:
#   (a) File exists.
#   (b) File mtime is at or after the pre-write timestamp (rounded down to the
#       second to tolerate filesystem precision).
#   (c) File ends with the PAR1 magic-bytes Parquet footer (catches partial
#       writes that update mtime but produce a corrupt file).
# Any failure stops the script with an actionable message.
script_write_start_time <- as.POSIXct(trunc(Sys.time(), units = "secs"))

write_parquet(scenarios_tbl, scenarios_parquet_path_chr, compression = "snappy")
write_parquet(universe_tbl,  simulation_parquet_path_chr, compression = "snappy")

verify_parquet_fresh <- function(path_chr, must_be_after_time) {
  if (!file.exists(path_chr)) {
    stop(sprintf("write_parquet failed: file does not exist at %s", path_chr), call. = FALSE)
  }
  mtime_val <- file.info(path_chr)$mtime
  if (is.na(mtime_val) || mtime_val < must_be_after_time) {
    stop(sprintf(
      "write_parquet reported success but %s did not refresh (mtime %s is older than write start %s). The file is likely held open by another process; close any data viewer / Excel / Power BI session pointed at this file, delete the file, and rerun.",
      path_chr,
      format(mtime_val, "%Y-%m-%d %H:%M:%S"),
      format(must_be_after_time, "%Y-%m-%d %H:%M:%S")
    ), call. = FALSE)
  }
  # Magic-bytes footer check: a valid Parquet file's last four bytes are PAR1.
  con <- file(path_chr, open = "rb")
  on.exit(close(con), add = TRUE)
  file_size_int <- file.info(path_chr)$size
  if (file_size_int < 8L) {
    stop(sprintf("Parquet file %s is too small (%d bytes); write produced a stub.",
                 path_chr, file_size_int), call. = FALSE)
  }
  seek(con, where = file_size_int - 4L, origin = "start")
  tail_bytes_raw <- readBin(con, what = "raw", n = 4L)
  if (!identical(tail_bytes_raw, charToRaw("PAR1"))) {
    stop(sprintf(
      "Parquet file %s does not end with PAR1 magic bytes (got %s). The write is corrupted -- the file is likely held open by another process. Delete the file manually and rerun.",
      path_chr,
      paste(sprintf("0x%02x", as.integer(tail_bytes_raw)), collapse = " ")
    ), call. = FALSE)
  }
}
verify_parquet_fresh(scenarios_parquet_path_chr,  script_write_start_time)
verify_parquet_fresh(simulation_parquet_path_chr, script_write_start_time)

# ------------------------------------------------------------
# EXTERNAL VALIDATION (mirrors 03a's external-validation block)
# ------------------------------------------------------------
# Triangulate 04 headline numbers against external benchmarks. These checks
# are NOT automated -- they are recorded so Ben can verify before publication.
#
# Benchmark 1: Saver's Match analysis universe size.
#   Target: the 04 universe equals the Saver's Match `in_universe` (all classes of worker,
#   ~145M weighted) -- it is NOT restricted to private-sector + self-employed.
#   Confidence: HIGH (same universe construction as 02a/03a).
#
# Benchmark 2: Routing split (employer-plan vs. universal-account) is informational only;
#   the private-sector and self-employed flags drive routing within the full universe, not
#   the universe membership.
#
# Benchmark 3: Median earnings by filing group (Census P60-286)
#   Target: Single $40k-$55k; MFJ $95k-$125k; HoH $45k-$60k.
#   Confidence: MEDIUM (Census reports earnings, not MAGI).
#
# Benchmark 4: Saver's Credit utilization rate (IRS SOI TY2021)
#   Target: 5.7% take-up sensitivity recovers IRS-observed claim count.
#   Confidence: HIGH on anchor; LOW on whether auto-enrollment hits floor.
#
# Benchmark 5: Current-law SM headline ($9.19B / 33.08M at full participation)
#   Target: 04 parameterized at current-law schedule reproduces existing
#   universal-access full-participation row to within 1 percent.
#   Confidence: HIGH on regression test; gating check before publication.
# ------------------------------------------------------------
# Automated benchmark checks (warn-only, so a miss flags for review without
# breaking the pipeline). Bands are deliberately broad -- they catch gross
# regressions (a broken universe, a sign error), not normal sampling movement.
benchmark_results_list <- list()
check_benchmark <- function(label_chr, value_num, lo_num, hi_num, fmt_chr = "%.2f") {
  pass_lgl <- !is.na(value_num) && value_num >= lo_num && value_num <= hi_num
  benchmark_results_list[[label_chr]] <<- pass_lgl
  message(sprintf(paste0("  [%s] %-42s value=", fmt_chr, "  expected [", fmt_chr, ", ", fmt_chr, "]"),
                  if (pass_lgl) "PASS" else "WARN", label_chr, value_num, lo_num, hi_num))
  if (!pass_lgl) {
    warning(sprintf("Benchmark '%s' outside expected band: %s not in [%s, %s].",
                    label_chr, value_num, lo_num, hi_num), call. = FALSE)
  }
  invisible(pass_lgl)
}
message("Automated benchmark checks:")
universe_wgt_M_num <- sum(universe_tbl$WPFINWGT, na.rm = TRUE) / 1e6
check_benchmark("B1 universe size (weighted, M)", universe_wgt_M_num, 140, 152)
check_benchmark("B-elig eligible workers (weighted, M)", eligible_wgt_M_num, 40, 52)
check_benchmark("B4 conditional DC rate (0,1)", sipp_observed_dc_rate_num, 0.01, 0.99, "%.4f")
# Benchmark 3: weighted median EARNINGS by filing group vs. broad Census-anchored bands
# (TY2027-projected, so bands are widened from the 2024 Census P60-286 reference).
wmed_earn <- function(fg_chr) {
  idx <- which(universe_tbl$filing_group_chr == fg_chr & !is.na(universe_tbl$earnings_num))
  if (!length(idx)) return(NA_real_)
  o <- order(universe_tbl$earnings_num[idx]); ii <- idx[o]
  cw <- cumsum(universe_tbl$WPFINWGT[ii])
  universe_tbl$earnings_num[ii][which(cw >= 0.5 * cw[length(cw)])[1]]
}
check_benchmark("B3 median earnings Single ($)", wmed_earn("single_mfs"), 25000, 75000, "%.0f")
check_benchmark("B3 median earnings MFJ ($)",    wmed_earn("mfj"),        40000, 120000, "%.0f")
check_benchmark("B3 median earnings HoH ($)",    wmed_earn("hoh"),        25000, 80000, "%.0f")
if (!all(unlist(benchmark_results_list))) {
  message("  NOTE: one or more benchmarks flagged WARN above; review before publication.")
} else {
  message("  All automated benchmarks within expected bands.")
}
# Note: Benchmark 5 (current-law regression) is a cross-stage check against 03a's
# universal_m100 row and is verified in the run log / PROJECT notes, not inline here.

###################################################################################
###                  9) Write Human-Readable Scenario Diagnostics               ###
###################################################################################
diag_path_chr <- file.path(path_output_reports_chr, "scenario_diagnostics.md")
diag_lines_chr <- c(
  "# 04 Scenario Diagnostics",
  "",
  sprintf("Computed at: %s", as.character(Sys.time())),
  "",
  sprintf("SIPP-observed conditional DC participation rate: %.4f",
          sipp_observed_dc_rate_num),
  "",
  "## Scenario results",
  "",
  "| Scenario | Group | Eligible (M) | Participants (M) | Take-up | Avg match | Annual cost ($M) |",
  "|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(scenarios_tbl))) {
  diag_lines_chr <- c(diag_lines_chr, sprintf(
    "| %s | %s | %.2f | %.2f | %.4f | $%d | $%d |",
    scenarios_tbl$scenario_name_chr[i],
    scenarios_tbl$scenario_group_chr[i],
    scenarios_tbl$eligible_count_M_num[i],
    scenarios_tbl$participant_count_M_num[i],
    scenarios_tbl$takeup_rate_num[i],
    scenarios_tbl$avg_match_per_person_num[i],
    scenarios_tbl$annual_cost_M_num[i]
  ))
}
diag_lines_chr <- c(diag_lines_chr, "",
  "## Notes",
  "",
  "- Headline scenario combines: (A) DC-access workers using row-level PARTICIPATING_DC, and (B) universal-account workers using the SIPP-observed conditional DC rate as a uniform participation assumption.",
  "- Sensitivities apply the rate uniformly across the whole universe."
)
writeLines(diag_lines_chr, diag_path_chr)

message("Outputs written to:")
message("  ", scenarios_parquet_path_chr)
message("  ", simulation_parquet_path_chr)
message("  ", diag_path_chr)
message("04_03_simulate_match.R complete.")
