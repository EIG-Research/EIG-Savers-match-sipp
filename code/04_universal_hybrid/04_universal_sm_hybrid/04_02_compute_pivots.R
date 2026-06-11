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
  library(readxl)
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

# IRS SOI anchor source (design decision D1, 2026-06-11). The eligibility
# frontier is anchored to administrative IRS data, NOT to the SIPP sample, so
# the policy is reproducible without SIPP. SOI Table 1.2 (by marital status)
# supplies the single-filer AGI distribution; the latest available wave stands
# in for "the tax year immediately preceding implementation."
path_irs_soi_chr <- file.path(project_root, "data", "raw", "irs_soi", "23in12ms.xls")

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
# Anchor the Single pivot on the IRS all-single-filer median AGI (-> MAGI); scale
# for MFJ and HoH using the statutory Saver's Match lower-threshold ratios. This
# mirrors the existing SM structure (MFJ = 2.0 x Single, HoH = 1.5 x Single per
# IRC sec 6433 / sm_calibration_constants()$sm_lower) rather than rescaling each
# filing group to its own data-derived median.
#
# DESIGN DECISION D1 (2026-06-11): the eligibility frontier is anchored to
# administrative IRS data (SOI Table 1.2 single-filer median AGI), NOT to the
# SIPP sample median, so the policy is reproducible independent of SIPP. The
# 75% rate is fixed at TWO-THIRDS of the IRS single median (a legislator-legible
# "two-thirds of the median" rule). With the 200% floor that places the 50%
# crossing (the "pivot" compute_match_rate keys on) at 0.8 x the IRS single
# median and the 0% endpoint at (4/3)*0.8 = 1.067 x the median:
#   - Single: pivot = 0.8 * IRS single median; endpoint = (4/3) * pivot.
#   - MFJ:    pivot = 2.0 * Single pivot;       endpoint = (4/3) * 2.0 * Single pivot.
#   - HoH:    pivot = 1.5 * Single pivot;       endpoint = (4/3) * 1.5 * Single pivot.
# The two-thirds anchor was chosen so the IRS-anchored schedule reproduces the
# prior SIPP-median-anchored coverage within ~3-4% while moving the frontier onto
# a stable administrative basis. See Infrastructure/specs and
# economist-panel/DESIGN-DECISIONS.md (D1) plus economist-panel/_shared/anchoring/.
# Anchor history: 2026-05-28 = 300% floor, pivot (5/6)*SIPP-median; 2026-06-08 =
# 200% floor, 50% at SIPP median; 2026-06-08b = 200% floor, 75% at one-half the
# SIPP median (pivot 0.6x); 2026-06-11 = 200% floor, 75% at two-thirds the IRS
# single median (pivot 0.8x), SIPP relegated to simulation only.

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

# --- IRS single-filer median AGI (-> MAGI), projected to TY2027 ---------------
# Read SOI Table 1.2 (by marital status) and interpolate the weighted median AGI
# for single + MFS returns (the "single_mfs" filing group). AGI -> MAGI add-backs
# (sec 911 / 931 / 933) are ~0 at the median and are not applied. The TY2023 SOI
# median is projected to TY2027 to match the simulation's TY2027 income basis,
# using the repo's annualized wage-growth rate (1.093 over 3 years -> 1.093^(4/3)
# over 4 years). At actual enactment the policy uses the real prior-year IRS
# median with no projection.
irs_proj_factor_num <- 1.093^(4/3)        # ~1.1259; 2023 -> 2027 at the repo's ~3.0%/yr

compute_irs_single_median_agi <- function(soi_path_chr) {
  if (!file.exists(soi_path_chr)) {
    stop("IRS SOI file not found at: ", soi_path_chr,
         ". Required to anchor the pivot (design decision D1).", call. = FALSE)
  }
  d <- suppressMessages(readxl::read_excel(soi_path_chr, sheet = 1, col_names = FALSE))
  # SOI Table 1.2 layout (TY2023, 23in12ms.xls): AGI-size bins in rows 10-28
  # (row 10 = no/negative AGI). Marital-status column groups: Single returns
  # number-of-returns = col 50; MFS number-of-returns = col 26.
  rows_int <- 10:28
  lower_num <- c(-Inf, 1, 5e3, 10e3, 15e3, 20e3, 25e3, 30e3, 40e3, 50e3, 75e3,
                 100e3, 200e3, 500e3, 1e6, 1.5e6, 2e6, 5e6, 10e6)
  upper_num <- c(0, 5e3, 10e3, 15e3, 20e3, 25e3, 30e3, 40e3, 50e3, 75e3, 100e3,
                 200e3, 500e3, 1e6, 1.5e6, 2e6, 5e6, 10e6, Inf)
  counts_num <- as.numeric(d[[50]][rows_int]) + as.numeric(d[[26]][rows_int])  # single + MFS
  total_num  <- sum(counts_num, na.rm = TRUE)
  target_num <- total_num / 2
  cum_num    <- cumsum(counts_num)
  k_int      <- which(cum_num >= target_num)[1]
  lo_num <- if (is.infinite(lower_num[k_int])) 0 else lower_num[k_int]
  hi_num <- if (is.infinite(upper_num[k_int])) lo_num * 2 else upper_num[k_int]
  below_num <- if (k_int == 1) 0 else cum_num[k_int - 1]
  lo_num + (target_num - below_num) / counts_num[k_int] * (hi_num - lo_num)
}

irs_single_median_ty2023_num <- compute_irs_single_median_agi(path_irs_soi_chr)
single_median_num <- irs_single_median_ty2023_num * irs_proj_factor_num  # -> TY2027

# Diagnostic only: the SIPP in-universe single_mfs median, for comparison.
sipp_single_median_num <- median_by_group_tbl |>
  dplyr::filter(filing_group_chr == "single_mfs") |>
  dplyr::pull(median_magi_num)

if (length(single_median_num) != 1L || is.na(single_median_num) ||
    single_median_num <= 0) {
  stop("Could not derive a positive IRS single-filer median MAGI to anchor the pivot table.",
       call. = FALSE)
}
message(sprintf(
  "IRS single+MFS median AGI: $%d (TY2023) -> $%d (TY2027, x%.4f). SIPP in-universe single median (diag): $%d.",
  round(irs_single_median_ty2023_num, 0L), round(single_median_num, 0L),
  irs_proj_factor_num, round(sipp_single_median_num, 0L)
))

# Pivot anchor: derive the 50% crossing point (the "pivot" compute_match_rate
# keys on) from the design anchor "75% at TWO-THIRDS the IRS single median,"
# holding the 200% floor fixed. With a fixed floor the straight line is pinned
# by that one anchor point:
#   slope = (anchor_rate - floor) / anchor_magi
#   pivot = (50 - floor) / slope            (the MAGI where the rate equals 50%)
# This lands the 50% crossing at 0.8 x the IRS single median and the 0% endpoint
# at (4/3)*0.8 = 1.067 x the median.
anchor_floor_pp_num <- 200
anchor_rate_pp_num  <- 75
anchor_frac_num     <- 2 / 3
anchor_magi_num     <- anchor_frac_num * single_median_num
anchor_slope_num    <- (anchor_rate_pp_num - anchor_floor_pp_num) / anchor_magi_num
single_pivot_num    <- (50 - anchor_floor_pp_num) / anchor_slope_num
message(sprintf(
  "Single anchor: %d%% at $%d (= %.3f x IRS median $%d) -> 50%% pivot = $%d, endpoint = $%d",
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
  sprintf("The schedule is a single straight line with a 200 percent floor at $0 MAGI. Per design decision D1 (2026-06-11) the **design anchor** fixes the Single rate at **75 percent at two-thirds the IRS all-single-filer median AGI** (SOI Table 1.2, single + MFS returns; TY2023 median $%d projected to TY2027 $%d at x%.4f). The policy is anchored to administrative IRS data, not the SIPP sample (SIPP relegated to simulation only; the SIPP in-universe single median was $%d, shown for comparison). Holding the floor fixed, the two-thirds anchor places the 50 percent crossing (the pivot `compute_match_rate()` keys on) at 0.8 x the IRS single median and the 0 percent endpoint at (4/3) x pivot = 1.067 x the median. MFJ and HoH pivots are scaled from the Single pivot using the statutory Saver's Match lower-threshold ratios from `sm_calibration_constants()$sm_lower`:",
          round(irs_single_median_ty2023_num, 0L), round(single_median_num, 0L),
          irs_proj_factor_num, round(sipp_single_median_num, 0L)),
  "",
  "- **MFJ ratio:** sm_lower[MFJ] / sm_lower[Single] = 41000 / 20500 = 2.00",
  "- **HoH ratio:** sm_lower[HoH] / sm_lower[Single] = 30750 / 20500 = 1.50",
  "",
  "Endpoint (where the rate hits zero) = (4/3) x pivot for each filing group. The Single pivot is 0.8 x the IRS single median, so the Single endpoint is 1.067 x that median. For MFJ and HoH the pivot is 2.0 x and 1.5 x the Single pivot, and the endpoint is (4/3) x that pivot. The `data median` column below is the SIPP in-universe median for each group (the population the simulation scores), shown against the IRS-anchored frontier.",
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
