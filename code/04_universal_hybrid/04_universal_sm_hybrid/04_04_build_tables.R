# 04_04_build_tables -- Headline and sensitivity tables
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - What table layout best communicates the headline cost, universe count,
#                     average match per worker, and the share of dollars by income decile?
#
# DESCRIPTION:
# Build three xlsx outputs:
#   1. hybrid_headline.xlsx                  -- one row per scenario
#   2. hybrid_distributional_incidence.xlsx  -- match-dollar share by income decile
#   3. hybrid_by_route.xlsx                  -- breakdown by routing (employer vs. universal)
#
# Inputs:
#   data/processed/universal_sm_hybrid/scenario_results.parquet
#   data/processed/universal_sm_hybrid/simulation_results.parquet
# Outputs:
#   output/tables/universal_sm_hybrid/hybrid_headline.xlsx
#   output/tables/universal_sm_hybrid/hybrid_distributional_incidence.xlsx
#   output/tables/universal_sm_hybrid/hybrid_by_route.xlsx

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                              Load Packages                                  ###
###################################################################################
suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
  library(openxlsx)
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

# Source calibration_cells.R for compute_match_rate(); needed to compute the
# per-decile contribution-rate-to-cap column added 2026-05-28.
source(file.path(project_root, "code", "_shared", "calibration_cells.R"))

###################################################################################
###                         Configuration and Paths                             ###
###################################################################################
path_data_processed_chr <- file.path(project_root, "data", "processed", "universal_sm_hybrid")
path_output_tables_chr  <- file.path(project_root, "output", "tables", "universal_sm_hybrid")
if (!dir.exists(path_output_tables_chr)) dir.create(path_output_tables_chr, recursive = TRUE)

###################################################################################
###                          1) Load Simulation Outputs                         ###
###################################################################################
scenarios_path_chr  <- file.path(path_data_processed_chr, "scenario_results.parquet")
simulation_path_chr <- file.path(path_data_processed_chr, "simulation_results.parquet")
pivot_rds_path_chr  <- file.path(path_data_processed_chr, "pivot_table.rds")
if (!file.exists(scenarios_path_chr) || !file.exists(simulation_path_chr)) {
  stop("Simulation outputs not found. Run 04_03_simulate_match.R first.", call. = FALSE)
}
if (!file.exists(pivot_rds_path_chr)) {
  stop("Pivot table not found. Run 04_02_compute_pivots.R first.", call. = FALSE)
}

scenarios_tbl     <- read_parquet(scenarios_path_chr)
simulation_tbl    <- read_parquet(simulation_path_chr)
pivot_obj_list    <- readRDS(pivot_rds_path_chr)
sm_pivot_2024_num <- pivot_obj_list$pivot_vec_num
max_credit_num    <- 1000  # spec Section 5.2; max credit per filer in USD

###################################################################################
###                  2) Headline + Sensitivity Table                            ###
###################################################################################
headline_tbl <- scenarios_tbl |>
  dplyr::transmute(
    scenario             = scenario_name_chr,
    scenario_group       = scenario_group_chr,
    eligible_M           = eligible_count_M_num,
    participants_M       = participant_count_M_num,
    takeup_rate          = takeup_rate_num,
    avg_match_per_person = avg_match_per_person_num,
    annual_cost_M_USD    = annual_cost_M_num,
    annual_cost_B_USD    = round(annual_cost_M_num / 1000, 2L)
  )

headline_xlsx_path_chr <- file.path(path_output_tables_chr, "hybrid_headline.xlsx")
write.xlsx(list(scenarios = headline_tbl), headline_xlsx_path_chr, overwrite = TRUE)
message("Wrote: ", headline_xlsx_path_chr)

###################################################################################
###          3) Distributional Incidence -- Three Decile Breakdowns             ###
###################################################################################
# 3a) Pooled-eligible deciles: deciles defined on the eligible sub-population
#     only. Shows how match dollars distribute across recipients (the legacy
#     view).
# 3b) Pooled-universe deciles: deciles defined on the FULL 04 universe
#     (eligible + ineligible). Match dollars are still computed for everyone
#     (zero for ineligibles by construction). Shows the policy's reach across
#     the whole workforce.
# 3c) Within-filing-status deciles: separate decile bins computed inside each
#     filing group's universe, with match-dollar share by decile within that
#     group. Compensates for the fact that MFJ has very different income
#     levels than Single/HoH.

# Helper: build a tibble with weighted deciles. magi_col_chr is the income
# column to decile on; weight_col_chr is the weight column. Returns the input
# tibble with a magi_decile_int column appended.
add_weighted_decile <- function(df, magi_col_chr, weight_col_chr,
                                 decile_col_chr = "magi_decile_int") {
  if (!nrow(df)) {
    df[[decile_col_chr]] <- integer(0)
    return(df)
  }
  df <- df |> dplyr::arrange(.data[[magi_col_chr]])
  w_num <- df[[weight_col_chr]]
  cum_wgt_num   <- cumsum(w_num)
  total_wgt_num <- cum_wgt_num[length(cum_wgt_num)]
  pct_num       <- cum_wgt_num / total_wgt_num
  df[[decile_col_chr]] <- pmin(10L, floor(pct_num * 10) + 1L)
  df
}

# 3a) Pooled-eligible deciles
incidence_pooled_eligible_tbl <- simulation_tbl |>
  dplyr::filter(eligible_flag == TRUE, !is.na(magi_num)) |>
  add_weighted_decile("magi_num", "WPFINWGT") |>
  dplyr::group_by(magi_decile_int) |>
  dplyr::summarise(
    n_rows_int                     = dplyr::n(),
    weighted_n_M_num               = sum(WPFINWGT, na.rm = TRUE) / 1e6,
    min_magi_num                   = min(magi_num, na.rm = TRUE),
    median_magi_num                = median(magi_num, na.rm = TRUE),
    max_magi_num                   = max(magi_num, na.rm = TRUE),
    median_rate_pp_num             = median(match_rate_pp_num, na.rm = TRUE),
    mean_match_per_worker_full_num = sum(match_per_worker_num * WPFINWGT, na.rm = TRUE) /
                                       sum(WPFINWGT, na.rm = TRUE),
    total_match_dollars_M_full_num = sum(match_per_worker_num * WPFINWGT, na.rm = TRUE) / 1e6,
    .groups = "drop"
  ) |>
  dplyr::mutate(
    share_of_full_dollars_num = total_match_dollars_M_full_num /
                                 sum(total_match_dollars_M_full_num, na.rm = TRUE)
  )

# 3b) Pooled-universe deciles -- deciles on the full universe, including
#     ineligible workers (who receive a $0 match). NA MAGI rows (if any
#     survived filtering) excluded from decile assignment.
incidence_pooled_universe_tbl <- simulation_tbl |>
  dplyr::filter(!is.na(magi_num)) |>
  add_weighted_decile("magi_num", "WPFINWGT") |>
  dplyr::mutate(
    # Match-per-worker for ineligibles is NA from compute_match_rate's NA
    # propagation; treat as 0 here for cost aggregation. The eligible_flag
    # column already encodes this; force-zero match_per_worker for ineligibles
    # to keep the universe-level sum coherent.
    match_per_worker_zerofill_num = dplyr::if_else(
      is.na(match_per_worker_num), 0, match_per_worker_num
    )
  ) |>
  dplyr::group_by(magi_decile_int) |>
  dplyr::summarise(
    n_rows_int                       = dplyr::n(),
    weighted_n_M_num                 = sum(WPFINWGT, na.rm = TRUE) / 1e6,
    weighted_n_eligible_M_num        = sum(WPFINWGT[eligible_flag == TRUE], na.rm = TRUE) / 1e6,
    share_eligible_in_decile_num     = sum(WPFINWGT[eligible_flag == TRUE], na.rm = TRUE) /
                                         sum(WPFINWGT, na.rm = TRUE),
    min_magi_num                     = min(magi_num, na.rm = TRUE),
    median_magi_num                  = median(magi_num, na.rm = TRUE),
    max_magi_num                     = max(magi_num, na.rm = TRUE),
    mean_match_per_worker_full_num   = sum(match_per_worker_zerofill_num * WPFINWGT, na.rm = TRUE) /
                                         sum(WPFINWGT, na.rm = TRUE),
    total_match_dollars_M_full_num   = sum(match_per_worker_zerofill_num * WPFINWGT, na.rm = TRUE) / 1e6,
    .groups = "drop"
  ) |>
  dplyr::mutate(
    share_of_full_dollars_num = total_match_dollars_M_full_num /
                                 sum(total_match_dollars_M_full_num, na.rm = TRUE)
  )

# 3c) Within-filing-status deciles -- one set of deciles per filing group,
#     each computed inside that group's own universe.
#
# Added 2026-05-28: per-decile contribution-rate-to-cap calculation.
#   match_rate_at_median_pp_num = compute_match_rate(median_magi, filing_group,
#                                                     sm_pivot_2024_num)
#   contrib_pct_to_hit_cap_num  = 100 * max_credit / (rate_frac * median_magi)
# Interpretation: the share of MAGI a worker at this decile's median would
# need to contribute to receive the full $1,000 cap. If match_rate is 0
# (above endpoint), the cap is unreachable -> NA_real_. If the implied
# contribution rate is below the 3 percent RSAA default, the cap binds at
# the 3 percent default and the worker receives the full $1,000.
incidence_within_filing_tbl <- simulation_tbl |>
  dplyr::filter(!is.na(magi_num),
                filing_group_chr %in% c("single_mfs", "mfj", "hoh")) |>
  dplyr::group_by(filing_group_chr) |>
  dplyr::group_modify(~ add_weighted_decile(.x, "magi_num", "WPFINWGT")) |>
  dplyr::ungroup() |>
  dplyr::mutate(
    match_per_worker_zerofill_num = dplyr::if_else(
      is.na(match_per_worker_num), 0, match_per_worker_num
    )
  ) |>
  dplyr::group_by(filing_group_chr, magi_decile_int) |>
  dplyr::summarise(
    n_rows_int                       = dplyr::n(),
    weighted_n_M_num                 = sum(WPFINWGT, na.rm = TRUE) / 1e6,
    weighted_n_eligible_M_num        = sum(WPFINWGT[eligible_flag == TRUE], na.rm = TRUE) / 1e6,
    share_eligible_in_decile_num     = sum(WPFINWGT[eligible_flag == TRUE], na.rm = TRUE) /
                                         sum(WPFINWGT, na.rm = TRUE),
    min_magi_num                     = min(magi_num, na.rm = TRUE),
    median_magi_num                  = median(magi_num, na.rm = TRUE),
    max_magi_num                     = max(magi_num, na.rm = TRUE),
    mean_match_per_worker_full_num   = sum(match_per_worker_zerofill_num * WPFINWGT, na.rm = TRUE) /
                                         sum(WPFINWGT, na.rm = TRUE),
    total_match_dollars_M_full_num   = sum(match_per_worker_zerofill_num * WPFINWGT, na.rm = TRUE) / 1e6,
    .groups = "drop"
  ) |>
  dplyr::group_by(filing_group_chr) |>
  dplyr::mutate(
    share_of_filing_group_dollars_num = total_match_dollars_M_full_num /
                                          sum(total_match_dollars_M_full_num, na.rm = TRUE)
  ) |>
  dplyr::ungroup() |>
  # Compute match rate at each decile's median MAGI, then derive the
  # contribution rate needed to hit the $1,000 cap.
  dplyr::mutate(
    match_rate_at_median_pp_num = compute_match_rate(
      magi_num         = median_magi_num,
      filing_group_chr = filing_group_chr,
      pivot_table      = sm_pivot_2024_num
    ),
    contrib_pct_to_hit_cap_num = dplyr::case_when(
      is.na(match_rate_at_median_pp_num)             ~ NA_real_,
      match_rate_at_median_pp_num <= 0               ~ NA_real_,
      is.na(median_magi_num) | median_magi_num <= 0  ~ NA_real_,
      TRUE                                            ~ 100 * max_credit_num /
        (match_rate_at_median_pp_num / 100 * median_magi_num)
    ),
    cap_binds_at_3pct_default_flag = dplyr::case_when(
      is.na(contrib_pct_to_hit_cap_num) ~ NA,
      contrib_pct_to_hit_cap_num <= 3   ~ TRUE,
      TRUE                               ~ FALSE
    )
  )

incidence_xlsx_path_chr <- file.path(path_output_tables_chr, "hybrid_distributional_incidence.xlsx")
write.xlsx(
  list(
    pooled_eligible_deciles    = incidence_pooled_eligible_tbl,
    pooled_universe_deciles    = incidence_pooled_universe_tbl,
    within_filing_status       = incidence_within_filing_tbl
  ),
  incidence_xlsx_path_chr,
  overwrite = TRUE
)
message("Wrote: ", incidence_xlsx_path_chr)
message(sprintf(
  "  pooled_eligible_deciles: %d rows; total match $%dM",
  nrow(incidence_pooled_eligible_tbl),
  round(sum(incidence_pooled_eligible_tbl$total_match_dollars_M_full_num), 0L)
))
message(sprintf(
  "  pooled_universe_deciles: %d rows; total match $%dM (should equal above)",
  nrow(incidence_pooled_universe_tbl),
  round(sum(incidence_pooled_universe_tbl$total_match_dollars_M_full_num), 0L)
))
message(sprintf(
  "  within_filing_status: %d rows across %d filing groups",
  nrow(incidence_within_filing_tbl),
  dplyr::n_distinct(incidence_within_filing_tbl$filing_group_chr)
))

###################################################################################
###                  4) Breakdown by Routing                                    ###
###################################################################################
route_tbl <- simulation_tbl |>
  dplyr::filter(eligible_flag == TRUE) |>
  dplyr::group_by(route_chr) |>
  dplyr::summarise(
    n_rows_int                    = dplyr::n(),
    weighted_n_M_num              = sum(WPFINWGT, na.rm = TRUE) / 1e6,
    mean_magi_num                 = sum(magi_num * WPFINWGT, na.rm = TRUE) /
                                      sum(WPFINWGT, na.rm = TRUE),
    mean_match_rate_pp_num        = sum(match_rate_pp_num * WPFINWGT, na.rm = TRUE) /
                                      sum(WPFINWGT, na.rm = TRUE),
    full_participation_cost_M_num = sum(match_per_worker_num * WPFINWGT, na.rm = TRUE) / 1e6,
    .groups = "drop"
  )

route_xlsx_path_chr <- file.path(path_output_tables_chr, "hybrid_by_route.xlsx")
write.xlsx(list(by_route = route_tbl), route_xlsx_path_chr, overwrite = TRUE)
message("Wrote: ", route_xlsx_path_chr)

message("Table outputs:")
message("  ", headline_xlsx_path_chr)
message("  ", incidence_xlsx_path_chr)
message("  ", route_xlsx_path_chr)
message("04_04_build_tables.R complete.")
