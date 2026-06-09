# 04_02_compute_pivots -- Per-filing-group median MAGI and pivot table
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - At what MAGI does the match rate phase down through 50 percent for each
#                     filing group, and at what MAGI does the line cross zero?
#
# DESCRIPTION:
# Compute weighted median MAGI by filing group inside the 04_01 universe. Set
# the Single pivot to the Single weighted-median MAGI; scale MFJ and HoH from
# the Single median via the SM lower-threshold ratios. Under the 200%-floor /
# 50%-pivot single straight line, the rate crosses zero at (4/3) * pivot.
#
# Inputs:
#   data/processed/universal_sm_hybrid/universe_dec.parquet
# Outputs:
#   data/processed/universal_sm_hybrid/pivot_table.rds
#   data/processed/universal_sm_hybrid/pivot_table.parquet
#   output/reports/universal_sm_hybrid/pivot_diagnostics.md

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                              Load Packages                                  ###
###################################################################################
suppressPackageStartupMessages({
  library(dplyr)
  library(arrow)
  library(Hmisc)
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

# Source calibration_cells.R for sm_calibration_constants(), needed below to
# derive the MFJ-and-HoH-to-Single pivot ratios from the statutory Saver's
# Match lower thresholds (matching the existing SM structure rather than
# rescaling per filing-group median).
source(file.path(project_root, "code", "_shared", "calibration_cells.R"))

###################################################################################
###                         Configuration and Paths                             ###
###################################################################################
path_data_processed_chr <- file.path(project_root, "data", "processed", "universal_sm_hybrid")
path_output_reports_chr <- file.path(project_root, "output", "reports", "universal_sm_hybrid")
if (!dir.exists(path_data_processed_chr)) dir.create(path_data_processed_chr, recursive = TRUE)
if (!dir.exists(path_output_reports_chr)) dir.create(path_output_reports_chr, recursive = TRUE)

###################################################################################
###                          1) Load Universe                                   ###
###################################################################################
universe_parquet_path_chr <- file.path(path_data_processed_chr, "universe_dec.parquet")
if (!file.exists(universe_parquet_path_chr)) {
  stop("Universe parquet not found at: ", universe_parquet_path_chr,
       ". Run 04_01_build_universe.R first.", call. = FALSE)
}
universe_tbl <- read_parquet(universe_parquet_path_chr)
message(sprintf("Loaded universe: %d rows (weighted M: %.2f).",
                nrow(universe_tbl),
                sum(universe_tbl$WPFINWGT, na.rm = TRUE) / 1e6))

###################################################################################
###                  2) Weighted Median MAGI by Filing Group                    ###
###################################################################################
compute_weighted_median <- function(magi_num, weight_num) {
  ok_idx_int <- which(!is.na(magi_num) & !is.na(weight_num) & weight_num > 0)
  if (length(ok_idx_int) == 0L) return(NA_real_)
  as.numeric(Hmisc::wtd.quantile(magi_num[ok_idx_int],
                                  weights = weight_num[ok_idx_int],
                                  probs = 0.5, na.rm = TRUE))
}

median_by_group_tbl <- universe_tbl |>
  dplyr::group_by(filing_group_chr) |>
  dplyr::summarise(
    n_rows_int       = dplyr::n(),
    weighted_n_num   = sum(WPFINWGT, na.rm = TRUE),
    median_magi_num  = compute_weighted_median(magi_num, WPFINWGT),
    .groups = "drop"
  )

message("Weighted median MAGI by filing group:")
for (i in seq_len(nrow(median_by_group_tbl))) {
  message(sprintf("  %-12s: n = %7d  weighted (M) = %6.2f  median MAGI = $%d",
                  median_by_group_tbl$filing_group_chr[i],
                  median_by_group_tbl$n_rows_int[i],
                  median_by_group_tbl$weighted_n_num[i] / 1e6,
                  round(median_by_group_tbl$median_magi_num[i], 0L)))
}

###################################################################################
###                  3) Build the Pivot Table                                   ###
###################################################################################
# Anchor the Single pivot on the Single filer's weighted-median MAGI; scale for
# MFJ and HoH using the statutory Saver's Match lower-threshold ratios. This
# mirrors the existing SM structure (MFJ = 2.0 x Single, HoH = 1.5 x Single per
# IRC sec 6433 / sm_calibration_constants()$sm_lower) rather than rescaling
# each filing group to its own data-derived median.
#
# Geometric note: the schedule is a single straight line per filing group with a
# 200% floor at MAGI = 0 and the 50% point at the pivot, so the rate crosses zero
# at (4/3) * pivot. The DESIGN anchor (revised 2026-06-08b) fixes the Single rate
# at 75% at ONE HALF the Single median MAGI; with the 200% floor that places the
# 50% crossing (the "pivot" compute_match_rate keys on) at 0.6 x the Single median
# and the 0% endpoint at 0.8 x the Single median:
#   - Single: pivot = 0.6 * Single median;     endpoint = (4/3) * pivot = 0.8 * Single median.
#   - MFJ:    pivot = 2.0 * Single pivot;      endpoint = (4/3) * 2.0 * Single pivot.
#   - HoH:    pivot = 1.5 * Single pivot;      endpoint = (4/3) * 1.5 * Single pivot.
# All pivots and endpoints are anchored to the Single pivot via the SM ratios,
# not to each group's own data median.

sm_constants <- sm_calibration_constants()
sm_lower_num   <- sm_constants$sm_lower

# Pivot ratios from the statutory SM lower thresholds.
sm_pivot_ratios_num <- c(
  single_mfs = 1.0,
  mfj        = as.numeric(sm_lower_num[["MFJ"]] / sm_lower_num[["Single"]]),
  hoh        = as.numeric(sm_lower_num[["HoH"]] / sm_lower_num[["Single"]])
)
message(sprintf(
  "SM-anchored pivot ratios: single_mfs=%.2f  mfj=%.2f  hoh=%.2f",
  sm_pivot_ratios_num[["single_mfs"]],
  sm_pivot_ratios_num[["mfj"]],
  sm_pivot_ratios_num[["hoh"]]
))

# Single anchor: the weighted median MAGI for the single_mfs filing group within the
# analysis universe (in_universe). (Reverted 2026-06-09 from the full single-filer
# population median back to the in-universe median.)
single_median_num <- median_by_group_tbl |>
  dplyr::filter(filing_group_chr == "single_mfs") |>
  dplyr::pull(median_magi_num)
if (length(single_median_num) != 1L || is.na(single_median_num) ||
    single_median_num <= 0) {
  stop("Could not derive a positive Single-filer median MAGI to anchor the pivot table.",
       call. = FALSE)
}
# Pivot anchor: derive the 50% crossing point (the "pivot" compute_match_rate
# keys on) from the design anchor "75% at one half the Single median," holding
# the 200% floor fixed. With a fixed floor the straight line is pinned by that
# one anchor point:
#   slope = (anchor_rate - floor) / anchor_magi
#   pivot = (50 - floor) / slope            (the MAGI where the rate equals 50%)
# This lands the 50% crossing at 0.6 x the Single median and the 0% endpoint at
# 0.8 x the Single median. (History: 2026-05-28 used a 300% floor with the 50%
# point at (5/6) x median; 2026-06-08 used a 200% floor with 50% at the Single
# median; 2026-06-08b moved the anchor to 75% at one half the Single median to
# pull the eligibility ceiling back near current-law levels.)
anchor_floor_pp_num <- 200
anchor_rate_pp_num  <- 75
anchor_frac_num     <- 0.5
anchor_magi_num     <- anchor_frac_num * single_median_num
anchor_slope_num    <- (anchor_rate_pp_num - anchor_floor_pp_num) / anchor_magi_num
single_pivot_num    <- (50 - anchor_floor_pp_num) / anchor_slope_num
message(sprintf(
  "Single anchor: %d%% at $%d (= %.2f x median $%d) -> 50%% pivot = $%d, endpoint = $%d",
  anchor_rate_pp_num, round(anchor_magi_num, 0L), anchor_frac_num,
  round(single_median_num, 0L), round(single_pivot_num, 0L),
  round((4 / 3) * single_pivot_num, 0L)
))

# Build the pivot vector by scaling the single anchor.
sm_pivot_2024_num <- single_pivot_num * sm_pivot_ratios_num

# Build the diagnostic table. Carry the data-observed median alongside the
# SM-anchored pivot so the reader can see how the policy frontier compares to
# each group's empirical distribution.
pivot_tbl <- dplyr::tibble(
  filing_group_chr = names(sm_pivot_2024_num),
  sm_ratio_num     = as.numeric(sm_pivot_ratios_num),
  pivot_num        = as.numeric(sm_pivot_2024_num)
) |>
  dplyr::left_join(
    median_by_group_tbl |>
      dplyr::select(filing_group_chr, n_rows_int, weighted_n_num,
                    data_median_magi_num = median_magi_num),
    by = "filing_group_chr"
  ) |>
  dplyr::mutate(
    # Endpoint = (4/3) * pivot under the 200%-floor / 50%-pivot single line.
    # (Slope -150/pivot: 200 - (150/pivot) * M = 0 -> M = (4/3) * pivot.)
    endpoint_num            = (4 / 3) * pivot_num,
    slope_pp_per_dollar_num = -150 / pivot_num,
    endpoint_vs_data_median_num = endpoint_num - data_median_magi_num
  )

if (any(is.na(pivot_tbl$pivot_num)) || any(pivot_tbl$pivot_num <= 0)) {
  stop("One or more filing-group pivots is NA or non-positive. Review 04_01 output.",
       call. = FALSE)
}
if (any(pivot_tbl$pivot_num < 5000) || any(pivot_tbl$pivot_num > 200000)) {
  stop("One or more pivots is outside plausible range [$5,000, $200,000].",
       call. = FALSE)
}

message("Pivot table (SM-anchored, Single -> MFJ x2.0, HoH x1.5):")
for (i in seq_len(nrow(pivot_tbl))) {
  message(sprintf(
    "  %-12s: ratio %.2f  pivot = $%d  endpoint = $%d  (data median = $%d, endpoint - median = $%d)",
    pivot_tbl$filing_group_chr[i],
    pivot_tbl$sm_ratio_num[i],
    round(pivot_tbl$pivot_num[i], 0L),
    round(pivot_tbl$endpoint_num[i], 0L),
    round(pivot_tbl$data_median_magi_num[i], 0L),
    round(pivot_tbl$endpoint_vs_data_median_num[i], 0L)
  ))
}

###################################################################################
###                  4) Write Outputs and Diagnostics                           ###
###################################################################################
pivot_rds_path_chr     <- file.path(path_data_processed_chr, "pivot_table.rds")
pivot_parquet_path_chr <- file.path(path_data_processed_chr, "pivot_table.parquet")
saveRDS(list(pivot_vec_num = sm_pivot_2024_num, pivot_tbl = pivot_tbl), pivot_rds_path_chr)
write_parquet(pivot_tbl, pivot_parquet_path_chr, compression = "snappy")

diag_path_chr <- file.path(path_output_reports_chr, "pivot_diagnostics.md")
diag_lines_chr <- c(
  "# 04 Pivot Diagnostics",
  "",
  sprintf("Computed at: %s", as.character(Sys.time())),
  "",
  "## Method",
  "",
  "The schedule is a single straight line with a 200 percent floor at $0 MAGI. The **design anchor** fixes the Single rate at **75 percent at one half the Single weighted-median MAGI** (the median is computed inside the 04_01 universe via `Hmisc::wtd.quantile(probs = 0.5)`). Holding the floor fixed, that anchor places the 50 percent crossing (the pivot `compute_match_rate()` keys on) at 0.6 x the Single median and the 0 percent endpoint at (4/3) x pivot = 0.8 x the Single median. MFJ and HoH pivots are scaled from the Single pivot using the statutory Saver's Match lower-threshold ratios from `sm_calibration_constants()$sm_lower`:",
  "",
  "- **MFJ ratio:** sm_lower[MFJ] / sm_lower[Single] = 41000 / 20500 = 2.00",
  "- **HoH ratio:** sm_lower[HoH] / sm_lower[Single] = 30750 / 20500 = 1.50",
  "",
  "Endpoint (where the rate hits zero) = (4/3) x pivot for each filing group. The Single pivot is 0.6 x the Single median, so the Single endpoint is 0.8 x the Single median. For MFJ and HoH the pivot is 2.0 x and 1.5 x the Single pivot, and the endpoint is (4/3) x that pivot (not tied to that group's own data median).",
  "",
  "## Pivot table",
  "",
  "| Filing group | SM ratio | N (rows) | Weighted (M) | Data median MAGI | Pivot | Endpoint | Endpoint - data median | Slope (pp/$) |",
  "|---|---|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(pivot_tbl))) {
  diag_lines_chr <- c(diag_lines_chr, sprintf(
    "| %s | %.2f | %d | %.2f | $%d | $%d | $%d | $%d | %.5f |",
    pivot_tbl$filing_group_chr[i],
    pivot_tbl$sm_ratio_num[i],
    pivot_tbl$n_rows_int[i],
    pivot_tbl$weighted_n_num[i] / 1e6,
    round(pivot_tbl$data_median_magi_num[i], 0L),
    round(pivot_tbl$pivot_num[i], 0L),
    round(pivot_tbl$endpoint_num[i], 0L),
    round(pivot_tbl$endpoint_vs_data_median_num[i], 0L),
    pivot_tbl$slope_pp_per_dollar_num[i]
  ))
}
diag_lines_chr <- c(diag_lines_chr, "",
  "## Interpretation",
  "",
  "The match rate follows a single straight line per filing group: 200 percent at zero MAGI, declining linearly through 50 percent at the pivot, and continuing at the same slope to zero at (4/3) x pivot. Workers below the pivot receive a match rate above 50 percent; workers between the pivot and the endpoint receive a phased-down match from 50 percent to zero; workers at or above the endpoint receive no match.",
  "",
  "Because MFJ and HoH pivots are anchored to Single via the SM ratios rather than rescaled to each group's own median, the MFJ endpoint may sit well below the MFJ median (capturing a larger share of the MFJ distribution above the endpoint) and the HoH endpoint may sit above the HoH median (capturing more HoH filers within the eligibility band). The `Endpoint - data median` column makes this visible at a glance."
)
writeLines(diag_lines_chr, diag_path_chr)

message("Pivot outputs written to:")
message("  ", pivot_rds_path_chr)
message("  ", pivot_parquet_path_chr)
message("  ", diag_path_chr)
message("04_02_compute_pivots.R complete.")
