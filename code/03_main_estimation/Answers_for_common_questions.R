# Answers_for_common_questions -- Filing-status x match-status worker counts
# Author - Ben Glasner
# research title - Saver's Match Eligibility Analysis (SECURE 2.0, IRC sec 6433)
# research question - How are SM-eligible workers distributed across filing
#                     status x match-eligibility cells, and how does that
#                     distribution change when restricted to workers who already
#                     hold a qualifying retirement account?
#
# DESCRIPTION:
# Produces two contingency tables on the project's standard SM-eligibility
# universe (age 18+, not a dependent proxy, not a full-time student proxy, has
# earned income, valid filing group), using SIPP 2024 Wave 1 person weights:
#
#   Table 1 -- count of workers (weighted N, millions) by
#                filing status (rows: Single incl. MFS / Head of Household /
#                Married Filing Jointly)
#                x match status (cols: Full Match Below / Phaseout Range /
#                                      No Match Above)
#              across the full SM-eligibility universe.
#
#   Table 2 -- same shape, restricted to workers who own a qualifying
#              retirement account (EOWN_THR401 == 1 OR EOWN_IRAKEO == 1; DB
#              pensions excluded), i.e., accounts eligible to receive the
#              Saver's Match.
#
#   Table 3 -- same shape, restricted to workers who do NOT own a qualifying
#              retirement account. The "access gap" view: workers who would
#              need to open a new account to receive the Saver's Match. By
#              construction equals Table 1 minus Table 2 cell by cell.
#
# Inputs:  data/raw/pu2024_expanded.csv  (built by 01_sipp_subset_from_dta.R)
#          code/_shared/calibration_cells.R
# Outputs: output/tables/answers_eligibility_by_filing_match.{rds,parquet,xlsx}
#          output/tables/answers_eligibility_account_holders_by_filing_match.{rds,parquet,xlsx}
#          output/tables/answers_eligibility_access_gap_by_filing_match.{rds,parquet,xlsx}
#
# The .rds and .parquet outputs are gitignored under output/** for size reasons;
# the .xlsx outputs are tracked by git so they sync to the GitHub repo. Each
# .xlsx workbook carries three sheets: Notes (run metadata, threshold reference,
# universe definition), Wide (3 x 3 contingency view with row + column totals),
# and Long (one row per cell, identical contents to the .rds/.parquet).
#
# DESIGN CHOICES:
#   - Universe definition is replicated from 03g_savers_match_eligibility_buckets.R
#     so cell counts reconcile to the published bucket totals. Each replicated
#     block is tagged "MIRRORS 03g lines XXX-YYY" so an RA reading both files
#     can audit drift directly. If 03g's universe definition changes, this
#     script must be updated in lockstep.
#   - Income concept and 2027 thresholds: identical to 03g (Option B annualized
#     TPTOTINC; MFJ uses U1 spouse-pair sum; cpi_projection_factor_num = 1.0
#     so thresholds equal the statutory 2024 amounts in IRC sec 6433).
#   - Cell boundaries follow make_income_cell_sm(): income at exactly the
#     lower threshold is "full_match"; income at exactly the upper threshold
#     is "above_ceiling".
#   - "Single" row folds in MFS, consistent with make_filing_group() which
#     groups EFSTATUS values 1 and 3 together because the statutory thresholds
#     for MFS equal the Single thresholds.
#   - Reconciliation check at the end stops the script if the weighted column
#     marginals do not match savers_match_eligibility_buckets.rds within
#     rounding tolerance.

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                              Load Packages                                  ###
###################################################################################
# openxlsx (pure R, no Java) is used for the .xlsx exports written alongside the
# .rds and .parquet outputs. Install once with install.packages("openxlsx") if
# the library() call below errors out on a fresh machine.
library(dplyr)
library(tidyr)
library(readr)
library(arrow)
library(openxlsx)

###################################################################################
###                              Project Paths                                  ###
###################################################################################
# Resolve project root mirroring 03g: env var -> walk up from getwd() ->
# walk up from sourced-script path. Error with actionable guidance if none hit.

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
  sourced_path_chr <- NA_character_
  frames_list <- sys.frames()
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
  stop(
    "Could not locate repo root. Either: ",
    "(a) Sys.setenv(EIG_PROJECT_ROOT = '<repo path>') before sourcing, ",
    "or (b) setwd() to the repo root (or any subfolder of it).",
    call. = FALSE
  )
}

message("Using project_root: ", project_root)

path_data_raw      <- file.path(project_root, "data", "raw")
path_output_tables <- file.path(project_root, "output", "tables")
if (!dir.exists(path_output_tables)) dir.create(path_output_tables, recursive = TRUE)

source(file.path(project_root, "code", "_shared", "calibration_cells.R"))

rsaa_constants <- rsaa_calibration_constants()
sm_lower <- rsaa_constants$sm_lower
sm_upper <- rsaa_constants$sm_upper

###################################################################################
###                          Tunable Parameters                                 ###
###################################################################################
# These mirror the 03g defaults so the universe matches the published buckets.
# Change here only if 03g changes; keep the two scripts in lockstep.

cpi_projection_factor_num            <- 1.0    # IRC sec 6433(h)(1): COLA TY2028+
student_earnings_cap_2024_nominal    <- 15000
dependent_earnings_cap_2024_nominal  <- 5050
restrict_to_full_year_flag           <- FALSE  # Option B (default in 03g)
drop_imputed_spouse_pointers_flag    <- FALSE  # default in 03g

###################################################################################
###                        Load SIPP Expanded Extract                           ###
###################################################################################
# 1) Read only the columns required for the universe build and the two tables.

sipp_cols_to_read_chr <- c(
  "SSUID", "PNUM", "MONTHCODE",
  "WPFINWGT",
  "TAGE", "EEDUC",
  "EFSTATUS", "TPTOTINC", "TPEARN",
  "EOWN_THR401", "EOWN_IRAKEO",
  "RENROLL", "EEDFTPT",
  "EPNSPOUSE", "APNSPOUSE"
)

sipp_expanded_csv_path_chr <- file.path(path_data_raw, "pu2024_expanded.csv")
if (!file.exists(sipp_expanded_csv_path_chr)) {
  stop(
    "Expanded SIPP extract not found at: ", sipp_expanded_csv_path_chr, ". ",
    "Run code/01_data_preparation/01_sipp_subset_from_dta.R first.",
    call. = FALSE
  )
}

sipp_raw_tbl <- tryCatch(
  readr::read_csv(
    sipp_expanded_csv_path_chr,
    col_select = dplyr::all_of(sipp_cols_to_read_chr),
    show_col_types = FALSE
  ),
  error = function(e) {
    message("ERROR reading SIPP with requested columns:")
    message(conditionMessage(e))
    stop(
      "Verify the SIPP 2024 variable names in pu2024_expanded.csv. ",
      "Consult the SIPP 2024 Wave 1 Data Dictionary before substituting alternatives.",
      call. = FALSE
    )
  }
)

message("Raw rows read: ", nrow(sipp_raw_tbl))

###################################################################################
###          Person-Year Income Aggregation (Option B)  -- MIRRORS 03g          ###
###################################################################################
# 2) Sum monthly TPTOTINC and TPEARN across observed MONTHCODE rows, then scale
#    to a 12-month basis: sum_observed * 12 / n_valid_months.
# MIRRORS 03g lines 318-345.

sipp_person_year_tbl <- sipp_raw_tbl |>
  dplyr::group_by(SSUID, PNUM) |>
  dplyr::summarise(
    tptotinc_sum_num            = sum(TPTOTINC, na.rm = TRUE),
    tpearn_sum_num              = sum(TPEARN,   na.rm = TRUE),
    n_months_observed_int       = dplyr::n(),
    n_months_tptotinc_valid_int = sum(!is.na(TPTOTINC)),
    n_months_tpearn_valid_int   = sum(!is.na(TPEARN)),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    tptotinc_annual_num = dplyr::if_else(
      n_months_tptotinc_valid_int > 0L,
      tptotinc_sum_num * 12 / n_months_tptotinc_valid_int,
      NA_real_
    ),
    tpearn_annual_num = dplyr::if_else(
      n_months_tpearn_valid_int > 0L,
      tpearn_sum_num * 12 / n_months_tpearn_valid_int,
      NA_real_
    )
  )

if (isTRUE(restrict_to_full_year_flag)) {
  pre_rows_int <- nrow(sipp_person_year_tbl)
  sipp_person_year_tbl <- sipp_person_year_tbl |>
    dplyr::filter(n_months_observed_int == 12L)
  message(sprintf(
    "Option-C sensitivity active: dropped %d partial-year respondents (%d remain).",
    pre_rows_int - nrow(sipp_person_year_tbl),
    nrow(sipp_person_year_tbl)
  ))
}

###################################################################################
###    December Restriction + U1 Spouse-Pair Joint Income  -- MIRRORS 03g       ###
###################################################################################
# 3) Restrict to MONTHCODE == 12L; carry annualized income/earnings onto the
#    December reference row. MIRRORS 03g lines 401-413.
# 4) U1 self-join: bring in spouse's annualized TPTOTINC via EPNSPOUSE.
#    MIRRORS 03g lines 478-573.

sipp_dec_tbl <- sipp_raw_tbl |>
  dplyr::filter(MONTHCODE == 12L) |>
  dplyr::left_join(
    sipp_person_year_tbl |>
      dplyr::select(SSUID, PNUM, tptotinc_annual_num, tpearn_annual_num),
    by = c("SSUID", "PNUM")
  )

message("Rows after December restriction: ", nrow(sipp_dec_tbl))

# Defensive scale check on monthly TPTOTINC (mirrors 03g lines 423-435).
tptotinc_median_num <- median(sipp_dec_tbl$TPTOTINC, na.rm = TRUE)
message("TPTOTINC median (monthly-scale check): ", round(tptotinc_median_num, 0L))
if (!is.na(tptotinc_median_num) && tptotinc_median_num > 15000) {
  stop(
    "TPTOTINC median is ", tptotinc_median_num,
    " -- expected monthly scale (~$3,000-$4,500). ",
    "If the extract is already annualized, the person-year aggregation ",
    "above has 12x-compounded the annualization.",
    call. = FALSE
  )
}

# U1 spouse self-join: keys on character to avoid floating-point drift.
sipp_dec_join_keys_tbl <- sipp_dec_tbl |>
  dplyr::mutate(
    SSUID_chr = as.character(SSUID),
    PNUM_chr  = as.character(PNUM)
  )

spouse_lookup_tbl <- sipp_person_year_tbl |>
  dplyr::transmute(
    SSUID_chr = as.character(SSUID),
    PNUM_chr  = as.character(PNUM),
    spouse_tptotinc_annual_num = tptotinc_annual_num
  )

sipp_dec_with_spouse_tbl <- sipp_dec_join_keys_tbl |>
  dplyr::mutate(
    epnspouse_chr = dplyr::if_else(
      is.na(EPNSPOUSE),
      NA_character_,
      as.character(EPNSPOUSE)
    )
  ) |>
  dplyr::left_join(
    spouse_lookup_tbl,
    by = c("SSUID_chr" = "SSUID_chr", "epnspouse_chr" = "PNUM_chr"),
    relationship = "many-to-one"
  )

if (isTRUE(drop_imputed_spouse_pointers_flag)) {
  sipp_dec_with_spouse_tbl <- sipp_dec_with_spouse_tbl |>
    dplyr::mutate(
      spouse_tptotinc_annual_num = dplyr::if_else(
        is.na(APNSPOUSE) | APNSPOUSE == 0L,
        spouse_tptotinc_annual_num,
        NA_real_
      )
    )
  message("U1 sensitivity: imputed APNSPOUSE pointers blanked.")
}

sipp_dec_tbl <- sipp_dec_with_spouse_tbl |>
  dplyr::select(-SSUID_chr, -PNUM_chr, -epnspouse_chr)

###################################################################################
###             Derived Flags + sm_income_num  -- MIRRORS 03g                   ###
###################################################################################
# 5) Filing group, sm_income_num (MFJ = spouse-pair sum; else personal annual).
# 6) Project 2027 thresholds (cpi_projection_factor_num = 1.0 -> statutory amounts).
# 7) Earned-income, student, dependent flags. Account-ownership flag.
# MIRRORS 03g lines 645-805.

sipp_derived_tbl <- sipp_dec_tbl |>
  dplyr::mutate(
    filing_group_chr = make_filing_group(EFSTATUS),

    # MFJ uses spouse-pair sum; fallback to personal annual when the spouse
    # pointer is unresolved. AGI scaffold (U2) keeps the subtraction visible
    # even though agi_above_line_adjust_num is currently 0.
    sm_gross_income_num = dplyr::case_when(
      filing_group_chr == "mfj" & !is.na(spouse_tptotinc_annual_num) ~
        tptotinc_annual_num + spouse_tptotinc_annual_num,
      filing_group_chr == "mfj" & is.na(spouse_tptotinc_annual_num) ~
        tptotinc_annual_num,
      filing_group_chr %in% c("single_mfs", "hoh") ~ tptotinc_annual_num,
      TRUE ~ NA_real_
    ),
    agi_above_line_adjust_num = 0,
    sm_income_num             = sm_gross_income_num - agi_above_line_adjust_num,

    sm_full_match_thresh_2027_num = dplyr::case_when(
      filing_group_chr == "single_mfs" ~ sm_lower[["Single"]] * cpi_projection_factor_num,
      filing_group_chr == "hoh"        ~ sm_lower[["HoH"]]    * cpi_projection_factor_num,
      filing_group_chr == "mfj"        ~ sm_lower[["MFJ"]]    * cpi_projection_factor_num,
      TRUE ~ NA_real_
    ),
    sm_upper_thresh_2027_num = dplyr::case_when(
      filing_group_chr == "single_mfs" ~ sm_upper[["Single"]] * cpi_projection_factor_num,
      filing_group_chr == "hoh"        ~ sm_upper[["HoH"]]    * cpi_projection_factor_num,
      filing_group_chr == "mfj"        ~ sm_upper[["MFJ"]]    * cpi_projection_factor_num,
      TRUE ~ NA_real_
    ),

    personal_annual_earnings_num = tpearn_annual_num,
    has_earned_income_flag = dplyr::case_when(
      is.na(personal_annual_earnings_num) ~ FALSE,
      personal_annual_earnings_num > 0    ~ TRUE,
      TRUE ~ FALSE
    ),

    student_enrollment_flag = dplyr::case_when(
      !is.na(RENROLL) & RENROLL == 1 &
        !is.na(EEDFTPT) & EEDFTPT == 1 ~ TRUE,
      TAGE >= 18 & TAGE <= 23 & EEDUC < 40 &
        personal_annual_earnings_num < student_earnings_cap_2024_nominal ~ TRUE,
      TRUE ~ FALSE
    ),

    dependent_flag = dplyr::case_when(
      TAGE < 19 ~ TRUE,
      TAGE >= 19 & TAGE <= 23 &
        student_enrollment_flag &
        personal_annual_earnings_num < dependent_earnings_cap_2024_nominal ~ TRUE,
      TRUE ~ FALSE
    ),

    owns_qualifying_account_flag = dplyr::case_when(
      EOWN_THR401 == 1 | EOWN_IRAKEO == 1 ~ TRUE,
      TRUE ~ FALSE
    )
  )

###################################################################################
###              Apply SM-Eligibility Universe Filter -- MIRRORS 03g            ###
###################################################################################
# 8) Universe: age 18+, not dependent (proxy), not full-time student (proxy),
#    has earned income, valid filing group. MIRRORS 03g lines 807-822.

sm_universe_tbl <- sipp_derived_tbl |>
  dplyr::filter(
    TAGE >= 18L,
    !dependent_flag,
    !student_enrollment_flag,
    has_earned_income_flag,
    !is.na(filing_group_chr)
  )

universe_weighted_n_num <- sum(sm_universe_tbl$WPFINWGT, na.rm = TRUE)
message("SM-eligibility universe rows: ", nrow(sm_universe_tbl),
        " | weighted N (M): ", round(universe_weighted_n_num / 1e6, 2))

###################################################################################
###                   Assign Match-Status Cell For Each Worker                  ###
###################################################################################
# 9) make_income_cell_sm() returns full_match / partial_match / above_ceiling.
#    Boundary convention: <= lower goes to full_match; >= upper goes to
#    above_ceiling; strictly between goes to partial_match.

sm_universe_tbl <- sm_universe_tbl |>
  dplyr::mutate(
    match_status_chr = make_income_cell_sm(
      sm_income       = sm_income_num,
      sm_lower_thresh = sm_full_match_thresh_2027_num,
      sm_upper_thresh = sm_upper_thresh_2027_num
    )
  )

n_unassigned_int <- sum(is.na(sm_universe_tbl$match_status_chr))
if (n_unassigned_int > 0L) {
  message("Note: ", n_unassigned_int, " universe rows have NA match_status_chr ",
          "(NA sm_income_num or NA threshold). These are excluded from cell counts.")
}

###################################################################################
###            Build Filing-Status x Match-Status Tables (Long Form)            ###
###################################################################################
# 10) Three long-format tables (one row per filing x match cell, 9 rows each):
#       - Table 1: full SM-eligibility universe
#       - Table 2: same, restricted to owns_qualifying_account_flag == TRUE
#       - Table 3: same, restricted to !owns_qualifying_account_flag (access gap)
#     Each table carries weighted N in millions (2 decimals) and the
#     unweighted SIPP row count for cell-size diagnostics. By construction
#     Table 1 == Table 2 + Table 3 cell by cell.

filing_levels_chr <- c("single_mfs", "hoh", "mfj")
match_levels_chr  <- c("full_match", "partial_match", "above_ceiling")

filing_label_lookup_chr <- c(
  single_mfs = "Single",
  hoh        = "Head of Household",
  mfj        = "Married Filing Jointly"
)
match_label_lookup_chr <- c(
  full_match    = "Full Match Below",
  partial_match = "Phaseout Range",
  above_ceiling = "No Match Above"
)

# Table 1: full universe
table1_long_tbl <- sm_universe_tbl |>
  dplyr::filter(!is.na(match_status_chr)) |>
  dplyr::group_by(filing_group_chr, match_status_chr) |>
  dplyr::summarise(
    weighted_n_num      = sum(WPFINWGT, na.rm = TRUE),
    unweighted_rows_int = dplyr::n(),
    .groups = "drop"
  ) |>
  tidyr::complete(
    filing_group_chr = filing_levels_chr,
    match_status_chr = match_levels_chr,
    fill = list(weighted_n_num = 0, unweighted_rows_int = 0L)
  ) |>
  dplyr::mutate(
    weighted_n_millions_num = round(weighted_n_num / 1e6, 2L),
    filing_status_chr       = filing_group_chr,
    filing_status_label_chr = filing_label_lookup_chr[filing_group_chr],
    match_status_label_chr  = match_label_lookup_chr[match_status_chr],
    universe_chr            = "sm_eligibility_universe"
  ) |>
  dplyr::select(
    universe_chr,
    filing_status_chr, filing_status_label_chr,
    match_status_chr,  match_status_label_chr,
    weighted_n_millions_num,
    unweighted_rows_int
  ) |>
  dplyr::arrange(
    factor(filing_status_chr, levels = filing_levels_chr),
    factor(match_status_chr,  levels = match_levels_chr)
  )

# Table 2: SM universe AND owns qualifying account
table2_long_tbl <- sm_universe_tbl |>
  dplyr::filter(!is.na(match_status_chr), owns_qualifying_account_flag) |>
  dplyr::group_by(filing_group_chr, match_status_chr) |>
  dplyr::summarise(
    weighted_n_num      = sum(WPFINWGT, na.rm = TRUE),
    unweighted_rows_int = dplyr::n(),
    .groups = "drop"
  ) |>
  tidyr::complete(
    filing_group_chr = filing_levels_chr,
    match_status_chr = match_levels_chr,
    fill = list(weighted_n_num = 0, unweighted_rows_int = 0L)
  ) |>
  dplyr::mutate(
    weighted_n_millions_num = round(weighted_n_num / 1e6, 2L),
    filing_status_chr       = filing_group_chr,
    filing_status_label_chr = filing_label_lookup_chr[filing_group_chr],
    match_status_label_chr  = match_label_lookup_chr[match_status_chr],
    universe_chr            = "sm_eligibility_universe_with_qualifying_account"
  ) |>
  dplyr::select(
    universe_chr,
    filing_status_chr, filing_status_label_chr,
    match_status_chr,  match_status_label_chr,
    weighted_n_millions_num,
    unweighted_rows_int
  ) |>
  dplyr::arrange(
    factor(filing_status_chr, levels = filing_levels_chr),
    factor(match_status_chr,  levels = match_levels_chr)
  )

# Table 3: SM universe AND lacks qualifying account (access gap)
table3_long_tbl <- sm_universe_tbl |>
  dplyr::filter(!is.na(match_status_chr), !owns_qualifying_account_flag) |>
  dplyr::group_by(filing_group_chr, match_status_chr) |>
  dplyr::summarise(
    weighted_n_num      = sum(WPFINWGT, na.rm = TRUE),
    unweighted_rows_int = dplyr::n(),
    .groups = "drop"
  ) |>
  tidyr::complete(
    filing_group_chr = filing_levels_chr,
    match_status_chr = match_levels_chr,
    fill = list(weighted_n_num = 0, unweighted_rows_int = 0L)
  ) |>
  dplyr::mutate(
    weighted_n_millions_num = round(weighted_n_num / 1e6, 2L),
    filing_status_chr       = filing_group_chr,
    filing_status_label_chr = filing_label_lookup_chr[filing_group_chr],
    match_status_label_chr  = match_label_lookup_chr[match_status_chr],
    universe_chr            = "sm_eligibility_universe_without_qualifying_account"
  ) |>
  dplyr::select(
    universe_chr,
    filing_status_chr, filing_status_label_chr,
    match_status_chr,  match_status_label_chr,
    weighted_n_millions_num,
    unweighted_rows_int
  ) |>
  dplyr::arrange(
    factor(filing_status_chr, levels = filing_levels_chr),
    factor(match_status_chr,  levels = match_levels_chr)
  )

###################################################################################
###            Build Wide Tables With Row + Column Totals (Memo-Ready)          ###
###################################################################################
# 11) Pivot each long table to a 3 (filing status) x 3 (match status) wide grid,
#     append a Row total column, and bind a Column total row underneath. These
#     wide tables feed both the .xlsx export and the console pretty-print.
#     Inline (not factored into a helper) per project convention.

# Table 1 wide
table1_wide_tbl <- table1_long_tbl |>
  dplyr::select(filing_status_label_chr, match_status_label_chr,
                weighted_n_millions_num) |>
  tidyr::pivot_wider(
    names_from  = match_status_label_chr,
    values_from = weighted_n_millions_num
  ) |>
  dplyr::mutate(
    `Row total` = round(
      `Full Match Below` + `Phaseout Range` + `No Match Above`, 2L
    )
  )

table1_col_totals_tbl <- data.frame(
  filing_status_label_chr = "Column total",
  `Full Match Below`      = round(sum(table1_wide_tbl$`Full Match Below`), 2L),
  `Phaseout Range`        = round(sum(table1_wide_tbl$`Phaseout Range`),   2L),
  `No Match Above`        = round(sum(table1_wide_tbl$`No Match Above`),   2L),
  `Row total`             = round(sum(table1_wide_tbl$`Row total`),        2L),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
table1_memo_tbl <- dplyr::bind_rows(table1_wide_tbl, table1_col_totals_tbl)

# Table 2 wide
table2_wide_tbl <- table2_long_tbl |>
  dplyr::select(filing_status_label_chr, match_status_label_chr,
                weighted_n_millions_num) |>
  tidyr::pivot_wider(
    names_from  = match_status_label_chr,
    values_from = weighted_n_millions_num
  ) |>
  dplyr::mutate(
    `Row total` = round(
      `Full Match Below` + `Phaseout Range` + `No Match Above`, 2L
    )
  )

table2_col_totals_tbl <- data.frame(
  filing_status_label_chr = "Column total",
  `Full Match Below`      = round(sum(table2_wide_tbl$`Full Match Below`), 2L),
  `Phaseout Range`        = round(sum(table2_wide_tbl$`Phaseout Range`),   2L),
  `No Match Above`        = round(sum(table2_wide_tbl$`No Match Above`),   2L),
  `Row total`             = round(sum(table2_wide_tbl$`Row total`),        2L),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
table2_memo_tbl <- dplyr::bind_rows(table2_wide_tbl, table2_col_totals_tbl)

# Table 3 wide (access gap)
table3_wide_tbl <- table3_long_tbl |>
  dplyr::select(filing_status_label_chr, match_status_label_chr,
                weighted_n_millions_num) |>
  tidyr::pivot_wider(
    names_from  = match_status_label_chr,
    values_from = weighted_n_millions_num
  ) |>
  dplyr::mutate(
    `Row total` = round(
      `Full Match Below` + `Phaseout Range` + `No Match Above`, 2L
    )
  )

table3_col_totals_tbl <- data.frame(
  filing_status_label_chr = "Column total",
  `Full Match Below`      = round(sum(table3_wide_tbl$`Full Match Below`), 2L),
  `Phaseout Range`        = round(sum(table3_wide_tbl$`Phaseout Range`),   2L),
  `No Match Above`        = round(sum(table3_wide_tbl$`No Match Above`),   2L),
  `Row total`             = round(sum(table3_wide_tbl$`Row total`),        2L),
  check.names = FALSE,
  stringsAsFactors = FALSE
)
table3_memo_tbl <- dplyr::bind_rows(table3_wide_tbl, table3_col_totals_tbl)

###################################################################################
###          Build Notes Sheets (Per-Workbook Metadata + Thresholds)            ###
###################################################################################
# 12) Two-column metadata tables, one per workbook. Captures the run timestamp,
#     source script path, universe definition, income concept, statutory
#     thresholds, and the universe weighted N. Travels with the workbook so the
#     file is interpretable on its own when opened from GitHub.

run_timestamp_chr <- format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")
script_path_chr   <- file.path(
  "code", "03_main_estimation", "Answers_for_common_questions.R"
)
universe_definition_chr <- paste(
  "Age 18+, not dependent (proxy), not full-time student (proxy),",
  "has earned income, valid filing group (EFSTATUS in 1/2/3/4)."
)
income_concept_chr <- paste(
  "Option B annualized TPTOTINC (sum of observed monthly values scaled to",
  "12 months). MFJ uses the U1 spouse-pair sum via EPNSPOUSE."
)
boundary_convention_chr <- paste(
  "<= lower goes to Full Match Below;",
  "> lower and < upper goes to Phaseout Range;",
  ">= upper goes to No Match Above."
)
universe_weighted_n_millions_chr <- format(
  round(universe_weighted_n_num / 1e6, 2), nsmall = 2
)

# Notes for Table 1 (full universe)
notes1_tbl <- data.frame(
  Field = c(
    "Workbook",
    "Generated by",
    "Generated at",
    "Source data",
    "Universe",
    "Universe weighted N (millions)",
    "Income concept",
    "CPI projection factor (2024 -> 2027)",
    "Threshold (Single, full match)",
    "Threshold (Single, upper)",
    "Threshold (Head of Household, full match)",
    "Threshold (Head of Household, upper)",
    "Threshold (Married Filing Jointly, full match)",
    "Threshold (Married Filing Jointly, upper)",
    "Cell boundary convention",
    "Account flag (Table 2 not applicable here)"
  ),
  Value = c(
    "answers_eligibility_by_filing_match.xlsx",
    script_path_chr,
    run_timestamp_chr,
    "data/raw/pu2024_expanded.csv (built from pu2024.dta, SIPP 2024 Wave 1)",
    universe_definition_chr,
    universe_weighted_n_millions_chr,
    income_concept_chr,
    sprintf("%.2f", cpi_projection_factor_num),
    sprintf("$%s", format(sm_lower[["Single"]], big.mark = ",")),
    sprintf("$%s", format(sm_upper[["Single"]], big.mark = ",")),
    sprintf("$%s", format(sm_lower[["HoH"]],    big.mark = ",")),
    sprintf("$%s", format(sm_upper[["HoH"]],    big.mark = ",")),
    sprintf("$%s", format(sm_lower[["MFJ"]],    big.mark = ",")),
    sprintf("$%s", format(sm_upper[["MFJ"]],    big.mark = ",")),
    boundary_convention_chr,
    "n/a -- this workbook covers the full SM-eligibility universe"
  ),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

# Notes for Table 2 (account holders)
notes2_tbl <- data.frame(
  Field = c(
    "Workbook",
    "Generated by",
    "Generated at",
    "Source data",
    "Universe",
    "Account flag",
    "Universe weighted N (millions, full SM-eligibility universe)",
    "Income concept",
    "CPI projection factor (2024 -> 2027)",
    "Threshold (Single, full match)",
    "Threshold (Single, upper)",
    "Threshold (Head of Household, full match)",
    "Threshold (Head of Household, upper)",
    "Threshold (Married Filing Jointly, full match)",
    "Threshold (Married Filing Jointly, upper)",
    "Cell boundary convention"
  ),
  Value = c(
    "answers_eligibility_account_holders_by_filing_match.xlsx",
    script_path_chr,
    run_timestamp_chr,
    "data/raw/pu2024_expanded.csv (built from pu2024.dta, SIPP 2024 Wave 1)",
    paste(universe_definition_chr,
          "Restricted to workers who own a qualifying retirement account."),
    "owns_qualifying_account_flag = (EOWN_THR401 == 1) OR (EOWN_IRAKEO == 1). DC-only; DB pensions excluded.",
    universe_weighted_n_millions_chr,
    income_concept_chr,
    sprintf("%.2f", cpi_projection_factor_num),
    sprintf("$%s", format(sm_lower[["Single"]], big.mark = ",")),
    sprintf("$%s", format(sm_upper[["Single"]], big.mark = ",")),
    sprintf("$%s", format(sm_lower[["HoH"]],    big.mark = ",")),
    sprintf("$%s", format(sm_upper[["HoH"]],    big.mark = ",")),
    sprintf("$%s", format(sm_lower[["MFJ"]],    big.mark = ",")),
    sprintf("$%s", format(sm_upper[["MFJ"]],    big.mark = ",")),
    boundary_convention_chr
  ),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

# Notes for Table 3 (access gap; lacks qualifying account)
notes3_tbl <- data.frame(
  Field = c(
    "Workbook",
    "Generated by",
    "Generated at",
    "Source data",
    "Universe",
    "Account flag (inverse)",
    "Universe weighted N (millions, full SM-eligibility universe)",
    "Income concept",
    "CPI projection factor (2024 -> 2027)",
    "Threshold (Single, full match)",
    "Threshold (Single, upper)",
    "Threshold (Head of Household, full match)",
    "Threshold (Head of Household, upper)",
    "Threshold (Married Filing Jointly, full match)",
    "Threshold (Married Filing Jointly, upper)",
    "Cell boundary convention",
    "Access-gap framing"
  ),
  Value = c(
    "answers_eligibility_access_gap_by_filing_match.xlsx",
    script_path_chr,
    run_timestamp_chr,
    "data/raw/pu2024_expanded.csv (built from pu2024.dta, SIPP 2024 Wave 1)",
    paste(universe_definition_chr,
          "Restricted to workers who do NOT own a qualifying retirement account."),
    "Workers counted here have owns_qualifying_account_flag == FALSE: neither EOWN_THR401 == 1 nor EOWN_IRAKEO == 1. DB pensions are excluded from the qualifying-account definition because they cannot receive Saver's Match contributions.",
    universe_weighted_n_millions_chr,
    income_concept_chr,
    sprintf("%.2f", cpi_projection_factor_num),
    sprintf("$%s", format(sm_lower[["Single"]], big.mark = ",")),
    sprintf("$%s", format(sm_upper[["Single"]], big.mark = ",")),
    sprintf("$%s", format(sm_lower[["HoH"]],    big.mark = ",")),
    sprintf("$%s", format(sm_upper[["HoH"]],    big.mark = ",")),
    sprintf("$%s", format(sm_lower[["MFJ"]],    big.mark = ",")),
    sprintf("$%s", format(sm_upper[["MFJ"]],    big.mark = ",")),
    boundary_convention_chr,
    "Counts represent the population that would need to open a new qualifying account to receive the Saver's Match. By construction the cells equal Table 1 minus Table 2."
  ),
  check.names = FALSE,
  stringsAsFactors = FALSE
)

###################################################################################
###             Save Tables (.rds + .parquet snappy + .xlsx)                    ###
###################################################################################
# 13) Three-format save per table: .rds (R-native), .parquet (snappy), .xlsx
#     (Notes / Wide / Long sheets). The .rds and .parquet are gitignored under
#     output/**; the .xlsx files are tracked by git so they sync to the GitHub
#     repo. Long-form contents in the Long sheet match the .rds/.parquet
#     contents exactly.

table1_rds_path_chr <- file.path(
  path_output_tables, "answers_eligibility_by_filing_match.rds"
)
table1_parquet_path_chr <- file.path(
  path_output_tables, "answers_eligibility_by_filing_match.parquet"
)
table1_xlsx_path_chr <- file.path(
  path_output_tables, "answers_eligibility_by_filing_match.xlsx"
)
table2_rds_path_chr <- file.path(
  path_output_tables, "answers_eligibility_account_holders_by_filing_match.rds"
)
table2_parquet_path_chr <- file.path(
  path_output_tables, "answers_eligibility_account_holders_by_filing_match.parquet"
)
table2_xlsx_path_chr <- file.path(
  path_output_tables, "answers_eligibility_account_holders_by_filing_match.xlsx"
)
table3_rds_path_chr <- file.path(
  path_output_tables, "answers_eligibility_access_gap_by_filing_match.rds"
)
table3_parquet_path_chr <- file.path(
  path_output_tables, "answers_eligibility_access_gap_by_filing_match.parquet"
)
table3_xlsx_path_chr <- file.path(
  path_output_tables, "answers_eligibility_access_gap_by_filing_match.xlsx"
)

# .rds + .parquet
saveRDS(table1_long_tbl, table1_rds_path_chr)
arrow::write_parquet(table1_long_tbl, table1_parquet_path_chr, compression = "snappy")
saveRDS(table2_long_tbl, table2_rds_path_chr)
arrow::write_parquet(table2_long_tbl, table2_parquet_path_chr, compression = "snappy")
saveRDS(table3_long_tbl, table3_rds_path_chr)
arrow::write_parquet(table3_long_tbl, table3_parquet_path_chr, compression = "snappy")

# Shared cell styles for the .xlsx workbooks
header_style    <- openxlsx::createStyle(textDecoration = "bold")
total_row_style <- openxlsx::createStyle(textDecoration = "bold")
number_style    <- openxlsx::createStyle(numFmt = "0.00")

# Workbook 1: full SM-eligibility universe
wb1 <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb1, "Notes")
openxlsx::writeData(wb1, "Notes", notes1_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb1, "Notes", cols = 1:2, widths = c(50, 90))
openxlsx::freezePane(wb1, "Notes", firstRow = TRUE)

openxlsx::addWorksheet(wb1, "Wide")
openxlsx::writeData(wb1, "Wide", table1_memo_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb1, "Wide", cols = 1:5, widths = c(28, 18, 18, 18, 14))
openxlsx::addStyle(
  wb1, "Wide",
  style = number_style,
  rows  = 2:(nrow(table1_memo_tbl) + 1L),
  cols  = 2:5,
  gridExpand = TRUE
)
openxlsx::addStyle(
  wb1, "Wide",
  style = total_row_style,
  rows  = nrow(table1_memo_tbl) + 1L,
  cols  = 1:5,
  gridExpand = TRUE,
  stack = TRUE
)
openxlsx::freezePane(wb1, "Wide", firstRow = TRUE)

openxlsx::addWorksheet(wb1, "Long")
openxlsx::writeData(wb1, "Long", table1_long_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb1, "Long", cols = 1:7, widths = c(50, 22, 28, 22, 22, 22, 22))
openxlsx::freezePane(wb1, "Long", firstRow = TRUE)

openxlsx::saveWorkbook(wb1, table1_xlsx_path_chr, overwrite = TRUE)

# Workbook 2: SM-eligibility universe AND owns qualifying account
wb2 <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb2, "Notes")
openxlsx::writeData(wb2, "Notes", notes2_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb2, "Notes", cols = 1:2, widths = c(60, 100))
openxlsx::freezePane(wb2, "Notes", firstRow = TRUE)

openxlsx::addWorksheet(wb2, "Wide")
openxlsx::writeData(wb2, "Wide", table2_memo_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb2, "Wide", cols = 1:5, widths = c(28, 18, 18, 18, 14))
openxlsx::addStyle(
  wb2, "Wide",
  style = number_style,
  rows  = 2:(nrow(table2_memo_tbl) + 1L),
  cols  = 2:5,
  gridExpand = TRUE
)
openxlsx::addStyle(
  wb2, "Wide",
  style = total_row_style,
  rows  = nrow(table2_memo_tbl) + 1L,
  cols  = 1:5,
  gridExpand = TRUE,
  stack = TRUE
)
openxlsx::freezePane(wb2, "Wide", firstRow = TRUE)

openxlsx::addWorksheet(wb2, "Long")
openxlsx::writeData(wb2, "Long", table2_long_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb2, "Long", cols = 1:7, widths = c(60, 22, 28, 22, 22, 22, 22))
openxlsx::freezePane(wb2, "Long", firstRow = TRUE)

openxlsx::saveWorkbook(wb2, table2_xlsx_path_chr, overwrite = TRUE)

# Workbook 3: SM-eligibility universe AND lacks qualifying account (access gap)
wb3 <- openxlsx::createWorkbook()
openxlsx::addWorksheet(wb3, "Notes")
openxlsx::writeData(wb3, "Notes", notes3_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb3, "Notes", cols = 1:2, widths = c(60, 100))
openxlsx::freezePane(wb3, "Notes", firstRow = TRUE)

openxlsx::addWorksheet(wb3, "Wide")
openxlsx::writeData(wb3, "Wide", table3_memo_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb3, "Wide", cols = 1:5, widths = c(28, 18, 18, 18, 14))
openxlsx::addStyle(
  wb3, "Wide",
  style = number_style,
  rows  = 2:(nrow(table3_memo_tbl) + 1L),
  cols  = 2:5,
  gridExpand = TRUE
)
openxlsx::addStyle(
  wb3, "Wide",
  style = total_row_style,
  rows  = nrow(table3_memo_tbl) + 1L,
  cols  = 1:5,
  gridExpand = TRUE,
  stack = TRUE
)
openxlsx::freezePane(wb3, "Wide", firstRow = TRUE)

openxlsx::addWorksheet(wb3, "Long")
openxlsx::writeData(wb3, "Long", table3_long_tbl, headerStyle = header_style)
openxlsx::setColWidths(wb3, "Long", cols = 1:7, widths = c(60, 22, 28, 22, 22, 22, 22))
openxlsx::freezePane(wb3, "Long", firstRow = TRUE)

openxlsx::saveWorkbook(wb3, table3_xlsx_path_chr, overwrite = TRUE)

message("Wrote: ", table1_rds_path_chr)
message("Wrote: ", table1_parquet_path_chr)
message("Wrote: ", table1_xlsx_path_chr)
message("Wrote: ", table2_rds_path_chr)
message("Wrote: ", table2_parquet_path_chr)
message("Wrote: ", table2_xlsx_path_chr)
message("Wrote: ", table3_rds_path_chr)
message("Wrote: ", table3_parquet_path_chr)
message("Wrote: ", table3_xlsx_path_chr)

###################################################################################
###                Pretty-Print Wide Versions With Marginal Totals              ###
###################################################################################
# Console-only display, not stored. Helps eyeball the cells against the memo.

message("\nTABLE 1 -- Workers in the SM-eligibility universe ",
        "(weighted N, millions)")
print(as.data.frame(table1_memo_tbl), row.names = FALSE)

message("\nTABLE 2 -- Workers with a qualifying retirement account ",
        "(weighted N, millions)")
print(as.data.frame(table2_memo_tbl), row.names = FALSE)

message("\nTABLE 3 -- Workers without a qualifying retirement account, the ",
        "access gap (weighted N, millions)")
print(as.data.frame(table3_memo_tbl), row.names = FALSE)

###################################################################################
###     Reconciliation Against savers_match_eligibility_buckets.rds (03g)       ###
###################################################################################
# 11) Verify column marginals match the published 03g overall counts within
#     a $50K (weighted N) tolerance. The mapping is:
#       sum of "Full Match Below" weighted N
#         = bucket2_weighted_n on the Overall row of 03g
#       sum of "Full Match Below" + "Phaseout Range" weighted N
#         = bucket1_weighted_n on the Overall row of 03g
#       sum of "Full Match Below" weighted N AND owns_qualifying_account
#         = bucket3_weighted_n on the Overall row of 03g
#     Stop on mismatch so a silent universe-definition drift surfaces loudly.

buckets_path_chr <- file.path(
  path_output_tables, "savers_match_eligibility_buckets.rds"
)

if (file.exists(buckets_path_chr)) {
  buckets_tbl <- readRDS(buckets_path_chr)

  overall_row_tbl <- buckets_tbl |>
    dplyr::filter(group_chr == "Overall", subgroup_chr == "All")

  if (nrow(overall_row_tbl) != 1L) {
    stop(
      "Expected a single Overall row in savers_match_eligibility_buckets.rds; ",
      "found ", nrow(overall_row_tbl), ".",
      call. = FALSE
    )
  }

  # Recompute headline weighted N (not millions) directly from sm_universe_tbl
  # so we compare apples to apples against bucketN_weighted_n in 03g.
  bucket2_recomputed_num <- sum(
    sm_universe_tbl$WPFINWGT *
      (!is.na(sm_universe_tbl$match_status_chr) &
         sm_universe_tbl$match_status_chr == "full_match"),
    na.rm = TRUE
  )
  bucket1_recomputed_num <- sum(
    sm_universe_tbl$WPFINWGT *
      (!is.na(sm_universe_tbl$match_status_chr) &
         sm_universe_tbl$match_status_chr %in% c("full_match", "partial_match")),
    na.rm = TRUE
  )
  bucket3_recomputed_num <- sum(
    sm_universe_tbl$WPFINWGT *
      (!is.na(sm_universe_tbl$match_status_chr) &
         sm_universe_tbl$match_status_chr == "full_match" &
         sm_universe_tbl$owns_qualifying_account_flag),
    na.rm = TRUE
  )

  # Access-gap recomputed totals: workers in B1 / B2 who do NOT own a
  # qualifying account. Expected values from 03g:
  #   B1 access gap = bucket1_weighted_n - bucket1_any_and_owns_weighted_n
  #   B2 access gap = bucket2_weighted_n - bucket3_weighted_n
  # The Table 1 vs. Table 2 cell-by-cell identity (Table 1 = Table 2 + Table 3)
  # is also implicitly tested by the bucket-level checks above; explicit
  # access-gap deltas surface a wrong inverse filter directly.
  access_gap_b1_recomputed_num <- sum(
    sm_universe_tbl$WPFINWGT *
      (!is.na(sm_universe_tbl$match_status_chr) &
         sm_universe_tbl$match_status_chr %in% c("full_match", "partial_match") &
         !sm_universe_tbl$owns_qualifying_account_flag),
    na.rm = TRUE
  )
  access_gap_b2_recomputed_num <- sum(
    sm_universe_tbl$WPFINWGT *
      (!is.na(sm_universe_tbl$match_status_chr) &
         sm_universe_tbl$match_status_chr == "full_match" &
         !sm_universe_tbl$owns_qualifying_account_flag),
    na.rm = TRUE
  )

  reconcile_tol_num <- 50000  # weighted N; ~$50K of weighted persons

  delta_b1_num <- abs(bucket1_recomputed_num - overall_row_tbl$bucket1_weighted_n)
  delta_b2_num <- abs(bucket2_recomputed_num - overall_row_tbl$bucket2_weighted_n)
  delta_b3_num <- abs(bucket3_recomputed_num - overall_row_tbl$bucket3_weighted_n)
  delta_gap_b1_num <- abs(
    access_gap_b1_recomputed_num -
      (overall_row_tbl$bucket1_weighted_n -
         overall_row_tbl$bucket1_any_and_owns_weighted_n)
  )
  delta_gap_b2_num <- abs(
    access_gap_b2_recomputed_num -
      (overall_row_tbl$bucket2_weighted_n - overall_row_tbl$bucket3_weighted_n)
  )

  message(sprintf(
    "Reconciliation deltas vs. 03g Overall (tolerance %s): B1=%.0f, B2=%.0f, B3=%.0f, gapB1=%.0f, gapB2=%.0f",
    format(reconcile_tol_num, big.mark = ","),
    delta_b1_num, delta_b2_num, delta_b3_num,
    delta_gap_b1_num, delta_gap_b2_num
  ))

  all_deltas_num <- c(
    delta_b1_num, delta_b2_num, delta_b3_num,
    delta_gap_b1_num, delta_gap_b2_num
  )
  if (any(all_deltas_num > reconcile_tol_num)) {
    stop(
      "Reconciliation FAILED. Cell marginals do not match ",
      "savers_match_eligibility_buckets.rds within tolerance. ",
      "Either 03g has been updated and this script needs to mirror the change, ",
      "or the universe construction has drifted. Compare the MIRRORS-tagged ",
      "blocks above against 03g_savers_match_eligibility_buckets.R.",
      call. = FALSE
    )
  }
  message("Reconciliation PASSED.")
} else {
  message(
    "Skipping reconciliation: ", buckets_path_chr, " not found. ",
    "Run code/03_main_estimation/03g_savers_match_eligibility_buckets.R first ",
    "to produce the comparison file."
  )
}

message("Answers_for_common_questions.R complete.")
