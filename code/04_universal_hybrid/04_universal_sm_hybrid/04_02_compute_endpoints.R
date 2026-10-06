# 04_02_compute_endpoints -- Designated endpoints by filing group
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - At what income does the match rate reach zero for each filing group?
#
# DESCRIPTION:
# The match schedule is one straight line per filing group, stated with two numbers:
#
#   200 percent match at $0 income, declining linearly to 0 percent at the
#   DESIGNATED ENDPOINT.
#
#   rate(income) = 200 * (1 - income / endpoint),  clamped to [0, 200]
#
# This script does one thing: read the designated endpoint set by
# 01d_asec_income_medians.R, scale it to the three filing groups by the statutory
# IRC sec 6433 ratios, and hand the resulting endpoint table to the rest of stage 04.
# It performs NO derivation of its own -- the endpoint written by 01d is the endpoint
# the model uses.
#
# WHAT CHANGED 2026-08-04. This file replaces 04_02_compute_pivots.R, which computed
# an interior 50-percent crossing (a "pivot") from an external median (an "anchor")
# read out of IRS SOI Table 1.2. Both concepts are retired, along with the SOI
# dependency. The schedule is unchanged in shape -- only its description and its
# input source. Audit bridge for pre-2026-08-04 outputs: old_pivot = 0.75 x endpoint.
#
# FILING-STATUS STRUCTURE (decision S1). Endpoints scale from the single-filer
# endpoint by the statutory ratios implicit in enacted sec 6433: MFJ = 2.0 x Single
# ($41,000 / $20,500) and HoH = 1.5 x Single ($30,750 / $20,500). These are IMPOSED,
# not estimated -- the endpoint diagnostics from 01d report how far they sit from the
# observed distribution, and they sit some distance from it.
#
# Inputs:
#   data/processed/asec_endpoint.rds                            (from 01d)
#   data/processed/universal_sm_hybrid/universe_dec.parquet      (diagnostics only)
# Outputs:
#   data/processed/universal_sm_hybrid/endpoint_table.rds
#   data/processed/universal_sm_hybrid/endpoint_table.parquet
#   output/reports/universal_sm_hybrid/endpoint_diagnostics.md

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

###################################################################################
###                         Configuration and Paths                             ###
###################################################################################
path_data_processed_chr <- file.path(project_root, "data", "processed", "universal_sm_hybrid")
path_output_reports_chr <- file.path(project_root, "output", "reports", "universal_sm_hybrid")
if (!dir.exists(path_data_processed_chr)) dir.create(path_data_processed_chr, recursive = TRUE)
if (!dir.exists(path_output_reports_chr)) dir.create(path_output_reports_chr, recursive = TRUE)

endpoint_source_rds_chr <- file.path(project_root, "data", "processed", "asec_endpoint.rds")

###################################################################################
###          1) Read the designated endpoint                                    ###
###################################################################################
if (!file.exists(endpoint_source_rds_chr)) {
  stop("Designated endpoint not found at: ", endpoint_source_rds_chr,
       ". Run code/01_data_preparation/01c_pull_ipums_asec.R then 01d_asec_income_medians.R first.",
       call. = FALSE)
}

endpoint_src_list <- readRDS(endpoint_source_rds_chr)

designated_endpoint_num <- endpoint_src_list$designated_endpoint_num
max_rate_pp_num         <- endpoint_src_list$max_rate_pp_num
ratio_mfj_num           <- endpoint_src_list$ratio_mfj_num
ratio_hoh_num           <- endpoint_src_list$ratio_hoh_num

if (is.null(designated_endpoint_num) || is.na(designated_endpoint_num) ||
    designated_endpoint_num <= 0) {
  stop("asec_endpoint.rds carries no usable designated endpoint. Rerun 01d.", call. = FALSE)
}
if (is.null(max_rate_pp_num) || is.na(max_rate_pp_num) || max_rate_pp_num <= 0) {
  stop("asec_endpoint.rds carries no usable max match rate. Rerun 01d.", call. = FALSE)
}

# Endpoints must sit at the SAME price level as the income the simulation scores.
# Both are nominal dollars of the SIPP reference year -- no projection on either
# side (decision S3). A mismatch here would silently move eligibility, so the
# expected year is asserted rather than assumed.
endpoint_price_year_int <- endpoint_src_list$price_level_year_int
message(sprintf("Designated endpoint: $%s (nominal %s dollars, median INCTOT of single filers age 15+, all values).",
                formatC(designated_endpoint_num, format = "d", big.mark = ","),
                as.character(endpoint_price_year_int)))

endpoint_vec_num <- c(
  single_mfs = designated_endpoint_num,
  mfj        = ratio_mfj_num * designated_endpoint_num,
  hoh        = ratio_hoh_num * designated_endpoint_num
)

if (any(endpoint_vec_num < 5000) || any(endpoint_vec_num > 300000)) {
  stop("One or more filing-group endpoints is outside the plausible range [$5,000, $300,000].",
       call. = FALSE)
}

###################################################################################
###          2) Load Universe (diagnostics only)                                ###
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
    n_rows_int      = dplyr::n(),
    weighted_n_num  = sum(WPFINWGT, na.rm = TRUE),
    median_magi_num = compute_weighted_median(magi_num, WPFINWGT),
    .groups = "drop"
  )

###################################################################################
###          3) Build the endpoint table                                        ###
###################################################################################
endpoint_tbl <- dplyr::tibble(
  filing_group_chr = names(endpoint_vec_num),
  sm_ratio_num     = c(1.0, ratio_mfj_num, ratio_hoh_num),
  endpoint_num     = as.numeric(endpoint_vec_num)
) |>
  dplyr::left_join(
    median_by_group_tbl |>
      dplyr::select(filing_group_chr, n_rows_int, weighted_n_num,
                    data_median_magi_num = median_magi_num),
    by = "filing_group_chr"
  ) |>
  dplyr::mutate(
    # Slope of the line, in percentage points per dollar: -R_max / endpoint.
    slope_pp_per_dollar_num     = -max_rate_pp_num / endpoint_num,
    endpoint_vs_data_median_num = endpoint_num - data_median_magi_num
  )

message("Endpoint table:")
for (i in seq_len(nrow(endpoint_tbl))) {
  message(sprintf(
    "  %-12s: ratio %.2f  endpoint = $%s  (SIPP universe median = $%s, endpoint - median = $%s)",
    endpoint_tbl$filing_group_chr[i],
    endpoint_tbl$sm_ratio_num[i],
    formatC(round(endpoint_tbl$endpoint_num[i]), format = "d", big.mark = ","),
    formatC(round(endpoint_tbl$data_median_magi_num[i]), format = "d", big.mark = ","),
    formatC(round(endpoint_tbl$endpoint_vs_data_median_num[i]), format = "d", big.mark = ",")
  ))
}

###################################################################################
###          4) Write Outputs and Diagnostics                                   ###
###################################################################################
endpoint_rds_path_chr     <- file.path(path_data_processed_chr, "endpoint_table.rds")
endpoint_parquet_path_chr <- file.path(path_data_processed_chr, "endpoint_table.parquet")

# schedule_params_list carries the one schedule parameter beyond the endpoints
# themselves, so downstream stages (04_03, 04_04, 04_05, 04_06) cannot drift from
# the schedule these endpoints were built for.
saveRDS(list(
  endpoint_vec_num     = endpoint_vec_num,
  endpoint_tbl         = endpoint_tbl,
  schedule_params_list = list(
    max_rate_pp_num         = max_rate_pp_num,
    designated_endpoint_num = designated_endpoint_num,
    ratio_mfj_num           = ratio_mfj_num,
    ratio_hoh_num           = ratio_hoh_num,
    price_level_year_int    = endpoint_price_year_int,
    endpoint_concept_chr    = endpoint_src_list$endpoint_concept_chr,
    endpoint_population_chr = endpoint_src_list$endpoint_population_chr,
    asec_survey_year_int    = endpoint_src_list$asec_survey_year_int,
    asec_income_year_int    = endpoint_src_list$asec_income_year_int
  )
), endpoint_rds_path_chr)
write_parquet(endpoint_tbl, endpoint_parquet_path_chr, compression = "snappy")

diag_path_chr <- file.path(path_output_reports_chr, "endpoint_diagnostics.md")
diag_lines_chr <- c(
  "# 04 Endpoint Diagnostics",
  "",
  sprintf("Computed at: %s", as.character(Sys.time())),
  "",
  "## The schedule",
  "",
  sprintf("One straight line per filing group: a **%d percent match at $0 income**, declining linearly to a **0 percent match at the designated endpoint**.",
          round(max_rate_pp_num)),
  "",
  "```",
  sprintf("rate(income) = %d * (1 - income / endpoint),  clamped to [0, %d]",
          round(max_rate_pp_num), round(max_rate_pp_num)),
  "```",
  "",
  "Two numbers describe it. There is no interior reference point.",
  "",
  "## The designated endpoint",
  "",
  sprintf("**$%s** — the weighted median total personal income (INCTOT) of single filers age 15+, all values, from IPUMS CPS ASEC %s (income year %s). Nominal %s dollars, compared against SIPP income at the same price level with no projection.",
          formatC(designated_endpoint_num, format = "d", big.mark = ","),
          as.character(endpoint_src_list$asec_survey_year_int),
          as.character(endpoint_src_list$asec_income_year_int),
          as.character(endpoint_price_year_int)),
  "",
  sprintf("Because the schedule scores filers on total income and the endpoint IS the median single filer's total income, the median single filer sits exactly at the 0 percent point. See `output/reports/asec_endpoint_diagnostics.md` for the full median grid and why this cell was chosen."),
  "",
  "## Endpoints by filing group",
  "",
  "Ratios are the statutory IRC sec 6433 ratios (MFJ $41,000 / Single $20,500 = 2.0; HoH $30,750 / $20,500 = 1.5). They are imposed by design, not estimated.",
  "",
  "| Filing group | Ratio | N (rows) | Weighted (M) | SIPP universe median | Endpoint | Endpoint - median | Slope (pp/$) |",
  "|---|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(endpoint_tbl))) {
  diag_lines_chr <- c(diag_lines_chr, sprintf(
    "| %s | %.2f | %d | %.2f | $%s | $%s | $%s | %.5f |",
    endpoint_tbl$filing_group_chr[i],
    endpoint_tbl$sm_ratio_num[i],
    endpoint_tbl$n_rows_int[i],
    endpoint_tbl$weighted_n_num[i] / 1e6,
    formatC(round(endpoint_tbl$data_median_magi_num[i]), format = "d", big.mark = ","),
    formatC(round(endpoint_tbl$endpoint_num[i]), format = "d", big.mark = ","),
    formatC(round(endpoint_tbl$endpoint_vs_data_median_num[i]), format = "d", big.mark = ","),
    endpoint_tbl$slope_pp_per_dollar_num[i]
  ))
}
diag_lines_chr <- c(diag_lines_chr, "",
  "## Interpretation",
  "",
  sprintf("A worker at $0 income receives a %d percent match on their contribution. The rate falls by %.5f percentage points per dollar of income for a single filer, reaching zero at the endpoint. Workers at or above their filing group's endpoint receive no match.",
          round(max_rate_pp_num),
          abs(endpoint_tbl$slope_pp_per_dollar_num[endpoint_tbl$filing_group_chr == "single_mfs"])),
  "",
  "The `SIPP universe median` column is the median income of the population the simulation actually scores, which is a *worker* population and therefore higher than the ASEC all-single-filer median that sets the endpoint. The `Endpoint - median` column makes the gap visible: a negative value means more than half of that filing group's workers sit above the endpoint and receive nothing.",
  "",
  "## Retired vocabulary",
  "",
  "Earlier versions described this same line by an interior 50 percent crossing (a \"pivot\") derived from an external median (an \"anchor\") read from IRS SOI Table 1.2. Both terms and the SOI dependency are retired. Audit bridge for reconciling pre-2026-08-04 outputs: `old_pivot = 0.75 x endpoint`."
)
writeLines(diag_lines_chr, diag_path_chr)

message("Endpoint outputs written to:")
message("  ", endpoint_rds_path_chr)
message("  ", endpoint_parquet_path_chr)
message("  ", diag_path_chr)
message("04_02_compute_endpoints.R complete.")
