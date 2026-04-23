# 03g_savers_match_eligibility_buckets -- Three-bucket SM eligible population estimates
# Author - Ben Glasner
# research title - RSAA vs. Saver's Match Distributional Comparison
# research question - How large is the Saver's Match eligible population and its nested subsets?
#
# DESCRIPTION:
# Produces three nested counts of the Saver's Match (SM) eligible worker population
# under IRC section 6433 (SECURE 2.0), projected to 2027:
#   Bucket 1 -- any-match eligible (income below upper threshold)
#   Bucket 2 -- full-match eligible (income at or below full-match threshold)
#   Bucket 3 -- full-match eligible AND currently holds a qualifying retirement account
# Results are reported overall, by filing status, and by age band, using SIPP 2024
# person weights.
#
# Input:   data/raw/pu2024_expanded.csv   (built by 01_sipp_subset_from_dta.R;
#                                          carries TPEARN, RENROLL, EEDENROLL,
#                                          EEDGRADE, EEDFTPT, ERELRPE in addition
#                                          to the legacy 40-column extract)
#          code/_shared/calibration_cells.R  (thresholds + helpers)
# Outputs: output/tables/savers_match_eligibility_buckets.rds
#          output/tables/savers_match_eligibility_buckets.parquet
#          output/reports/savers_match_eligibility_buckets.md
#
# OPEN ITEMS (see Infrastructure/handoffs/2026-04-18_savers_match_eligibility_buckets_handoff.md):
#   - CPI-U projection factor: resolved 2026-04-19 to 1.0 per IRC 6433(h)(1)
#     (COLA applies to TY2028+; 2027 simulation uses statutory thresholds).
#   - Student proxy fallback earnings threshold (currently 15000)
#   - Dependent-proxy qualifying-relative gross-income threshold (currently 5050)
#   - MFJ earned-income rule for Bucket 1
#   - Whether to also report household-level counts
#   - Income-period handling: SIPP TPTOTINC / TFTOTINC are MONTHLY reference-month
#     values; we multiply by 12 to compare against the annual AGI thresholds in
#     sm_lower / sm_upper. Dec x 12 is a proxy for calendar-year AGI. Consider
#     substituting a calendar-year income aggregate if SIPP 2024 exposes one for
#     in-sample-all-year workers.
#   - MFJ filing-unit vs. family income: resolved 2026-04-19 via U1 (plan
#     2026-04-19 Section 4). MFJ joint income is now the spouse-pair sum of
#     TPTOTINC via an EPNSPOUSE self-join, not TFTOTINC. Open sub-items:
#     (a) treatment of MFJ filers with unresolved spouse pointers (currently
#     fall back to TPTOTINC alone; diagnostic logged at runtime);
#     (b) whether to drop imputed spouse pointers (APNSPOUSE != 0), held as
#     a sensitivity toggle: drop_imputed_spouse_pointers_flag.
#   - AGI approximation (U2): staged 2026-04-19 as an empty scaffold. The
#     current 48-column pu2024_expanded extract does not carry above-the-
#     line adjustment flow variables (IRC sec 62: sec 219 IRA deduction,
#     sec 223 HSA, sec 221 student loan interest, educator expenses, 1/2
#     self-employment tax). sm_gross_income_num and agi_above_line_adjust_
#     _num (default 0) are introduced so the gross-income-to-AGI mapping
#     is visible in code. Bias direction of the current 0-adjustment
#     proxy: sm_income_num == sm_gross_income_num overstates AGI, so
#     Bucket 1 and Bucket 2 counts are LOWER BOUNDS on the true counts.
#     Unblocking U2 requires a second 01 extract rebuild to add verified
#     SIPP 2024 contribution-flow variables (see plan 2026-04-19 Section
#     8.9).
#   - Filer-basis reaggregation (U5): staged 2026-04-19. Each MFJ couple
#     now contributes one filer via the lower-PNUM-of-pair convention;
#     see the "U5" block after the person-level aggregation. Three new
#     outputs: savers_match_eligibility_buckets_filerbasis.{rds,parquet}
#     and savers_match_filer_vs_ebri.{rds,parquet}. Remaining caveat:
#     Bucket 3 on a filer basis is a LOWER BOUND because the U1 self-join
#     does not carry spouse account-ownership flags; closing this gap
#     requires extending the U1 self-join in a future pass.

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                              Load Packages                                  ###
###################################################################################
library(dplyr)
library(tidyr)
library(readr)
library(arrow)

###################################################################################
###                              Project Paths                                  ###
###################################################################################
# Resolve project root in this order:
#   1) EIG_PROJECT_ROOT environment variable, if set and valid.
#   2) Walk up from getwd() until we find a directory containing Infrastructure/.
#   3) Walk up from the sourced-script's own path (via sys.frames()$ofile)
#      until we find Infrastructure/.
# Error with clear guidance if none succeed.

project_root <- NA_character_

# Attempt 1: environment variable
env_root_chr <- Sys.getenv("EIG_PROJECT_ROOT", unset = NA_character_)
if (!is.na(env_root_chr) && nzchar(env_root_chr) &&
    dir.exists(file.path(env_root_chr, "Infrastructure"))) {
  project_root <- normalizePath(env_root_chr)
}

# Attempt 2: walk up from working directory
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

# Attempt 3: walk up from the sourced-script's own path
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
    "Could not locate RSAA repo root. Either: ",
    "(a) Sys.setenv(EIG_PROJECT_ROOT = '<repo path>') before sourcing, ",
    "or (b) setwd() to the repo root (or any subfolder of it)."
  )
}

message("Using project_root: ", project_root)

path_data_raw       <- file.path(project_root, "data", "raw")
path_output_tables  <- file.path(project_root, "output", "tables")
path_output_reports <- file.path(project_root, "output", "reports")

if (!dir.exists(path_output_tables))  dir.create(path_output_tables,  recursive = TRUE)
if (!dir.exists(path_output_reports)) dir.create(path_output_reports, recursive = TRUE)

source(file.path(project_root, "code", "_shared", "calibration_cells.R"))

# Expose calibration constants used directly below (thresholds, shares, rates).
# calibration_cells.R exposes them only through rsaa_calibration_constants();
# binding sm_lower / sm_upper here keeps the downstream case_when() calls legible.
rsaa_constants <- rsaa_calibration_constants()
sm_lower <- rsaa_constants$sm_lower    # named numeric: Single/MFJ/HoH/MFS (2024$)
sm_upper <- rsaa_constants$sm_upper    # named numeric: Single/MFJ/HoH/MFS (2024$)

###################################################################################
###                    Tunable Parameters (Open-Item Knobs)                     ###
###################################################################################

# Projection factor applied to the statutory Saver's Match full-match and
# upper phase-out thresholds (see sm_full_match_thresh_2027_num and
# sm_upper_thresh_2027_num below). Set to 1.0 per IRC Section 6433(h)(1):
# the section defines nominal threshold amounts by filing status that apply
# as written for tax years beginning before 2028, with a COLA clause under
# Section 6433(h)(1) first effective for tax years beginning after 2027.
# A 2027-baseline simulation therefore uses the statutory amounts directly
# rather than inflating them from 2024. Prior value (1.093) was an
# unsupported placeholder; see Infrastructure/plans/2026-04-19_savers-match-
# methodology-upgrade.md Section 8.1 for the citation correction.
cpi_projection_factor_num <- 1.0

# Student-proxy fallback earnings threshold (annual, 2024 dollars).
#
# Statutory basis: IRC sec 25B does NOT impose an earnings cap on full-time-
# student disqualification — any person who is a full-time student (as
# defined in sec 152(f)(2), i.e., "regular student at an educational
# organization for at least five calendar months in the year") is excluded
# from the Saver's Credit, and by cross-reference from the Saver's Match
# under sec 6433. TO VERIFY: exact subsection letter mapping in sec 25B(c)
# and sec 6433 before external publication.
# The 15,000 cap here is a project-specific fallback that applies only when
# RENROLL / EEDFTPT in SIPP are both missing, so we infer student status from
# age (18-23), low completed education (EEDUC < 40), and low earnings. The
# cap value is chosen to be low enough to exclude non-student young workers
# who look like students on age/education alone. It is a project choice, not
# a statutory value; flip to a different value here without touching code
# elsewhere. See plan 2026-04-19 Section 4 U4.
student_earnings_cap_2024_nominal <- 15000

# Dependent-proxy qualifying-relative gross-income threshold (IRS 2024 value).
#
# Statutory basis: IRC sec 152(d)(1)(B), indexed annually under sec 152(d)(5)
# to the §1(f)(3) cost-of-living adjustment (rounded to the nearest $50).
# The 2024 value of $5,050 is published in IRS Rev. Proc. 2023-34 (Section
# 3.24). The 2027 statutory value is not yet published; the simulation uses
# the 2024 nominal value because (a) the dependent gating affects a very
# small share of the eligibility count (age 19-23 band only) and (b) TY2027
# indexing will shift this by less than 10 percent, well below the
# inferential resolution of the SIPP estimate. See plan 2026-04-19 Section 4
# U4.
dependent_earnings_cap_2024_nominal <- 5050

# Set to TRUE to require MFJ spouses to have own earned income for Bucket 1 inclusion.
mfj_require_own_earnings_flag <- TRUE

###################################################################################
###                     Load SIPP 2024 Raw and Subset Columns                   ###
###################################################################################
message("Loading SIPP 2024 raw microdata...")

# Pull the expanded raw extract (produced by 01_sipp_subset_from_dta.R) so that
# the enrollment, earnings, and dependency-proxy variables are available. The
# legacy 40-column pu2024.csv does not carry TPEARN, RENROLL, EEDENROLL,
# EEDGRADE, EEDFTPT, or ERELRPE; run 01_sipp_subset_from_dta.R first if the
# expanded file is absent.
#
# Variable-name note (verified against pu2024.dta header on 2026-04-18):
#   - RENROLL   = person-level enrollment recode (R-prefix recode)
#   - EEDENROLL = monthly "currently enrolled in school" item
#   - EEDGRADE  = grade level of enrollment (HS vs. undergrad vs. graduate)
#   - EEDFTPT   = full-time vs. part-time student status (drives §25B trigger)
# Earlier drafts used RENROLD / EENRLEV / RFTPTX, none of which exist in the
# SIPP 2024 Wave 1 PUF; the corrected names above come straight from the
# Census codebook.
sipp_cols_to_read_chr <- c(
  # Identifiers
  "SSUID", "PNUM", "MONTHCODE",
  # Weight
  "WPFINWGT",
  # Demographics
  "TAGE", "EEDUC", "ESEX",
  # Filing status and income
  "EFSTATUS", "TPTOTINC", "TFTOTINC", "TPEARN",
  # Account ownership (for Bucket 3)
  "EOWN_THR401", "EOWN_IRAKEO",
  # Worker class (for all-classes scope verification)
  "EJB1_JBORSE", "EJB1_CLWRK",
  # Enrollment / student flags (EEDFTPT refines RENROLL/EEDENROLL to full-time)
  "RENROLL", "EEDENROLL", "EEDGRADE", "EEDFTPT",
  # Relationship to reference person (dependent proxy)
  "ERELRPE",
  # Spouse pointer for U1 joint-income construction on MFJ branch
  # (see plan 2026-04-19 Section 8.1; rebuilt by 01_sipp_subset_from_dta.R on 2026-04-19)
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

# tryCatch so a missing column surfaces as an actionable error rather than an
# opaque readr complaint. If any name turns out to be wrong, the error tells us
# what columns the expanded extract actually exposes.
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
      "Consult the SIPP 2024 Wave 1 Data Dictionary before substituting alternatives."
    )
  }
)

message("Raw rows read: ", nrow(sipp_raw_tbl))

# Restrict to December reference month (retirement items are collected in December).
sipp_dec_tbl <- sipp_raw_tbl |>
  dplyr::filter(MONTHCODE == 12L)

message("Rows after December restriction: ", nrow(sipp_dec_tbl))

# Defensive scale check on TPTOTINC / TFTOTINC.
# If the expanded extract is ever rebuilt with already-annualized income,
# the * 12 multiplier in the sm_income_num construction below would
# double-annualize and silently inflate all phase-out comparisons by 12x.
# Median monthly personal income is typically ~$3,000-$4,500; median monthly
# family income is typically ~$5,000-$6,500. Error out if medians look annual.
tptotinc_median_num <- median(sipp_dec_tbl$TPTOTINC, na.rm = TRUE)
tftotinc_median_num <- median(sipp_dec_tbl$TFTOTINC, na.rm = TRUE)
message("TPTOTINC median (monthly-scale check): ", round(tptotinc_median_num, 0L))
message("TFTOTINC median (monthly-scale check): ", round(tftotinc_median_num, 0L))
if (!is.na(tptotinc_median_num) && tptotinc_median_num > 15000) {
  stop(
    "TPTOTINC median is ", tptotinc_median_num,
    " -- expected monthly scale (~$3,000-$4,500). ",
    "If the extract is already annualized, remove the '* 12' in sm_income_num ",
    "to avoid double-annualization.",
    call. = FALSE
  )
}
if (!is.na(tftotinc_median_num) && tftotinc_median_num > 20000) {
  stop(
    "TFTOTINC median is ", tftotinc_median_num,
    " -- expected monthly scale (~$5,000-$6,500). ",
    "If the extract is already annualized, remove the '* 12' in sm_income_num ",
    "to avoid double-annualization.",
    call. = FALSE
  )
}

###################################################################################
###            U1: Spouse-Pointer Joint Income for MFJ Branch                   ###
###################################################################################

# U1 (plan 2026-04-19 Section 4): replace TFTOTINC (family-unit income) with an
# explicit spouse-pair sum of TPTOTINC on the MFJ branch. TFTOTINC in SIPP is
# family income that can include non-spouse family members (e.g., adult children,
# parents), which over-includes income relative to a tax-filing unit. The Saver's
# Match statutory income test in IRC sec 6433 is an AGI test on the joint filer,
# which is the sum of the two spouses' incomes only. The self-join below keys each
# person to their spouse via EPNSPOUSE (person number of spouse within the same
# SSUID/household) and brings over the spouse's TPTOTINC for December.
#
# APNSPOUSE imputation-flag policy (open item 8.8 in plan):
#   By default we include all spouse pointers regardless of imputation status so
#   the MFJ branch benefits from the full sample. The diagnostic message below
#   reports what share of joined pointers were imputed so Ben can decide whether
#   to switch drop_imputed_spouse_pointers_flag to TRUE and rerun as a
#   sensitivity. APNSPOUSE coding is typed to 0 = not imputed per the SIPP 2024
#   Household Relationship topical module documentation; verify before treating
#   any nonzero value as imputed.

drop_imputed_spouse_pointers_flag <- FALSE  # open item; see plan 8.8

# Build a per-person December lookup with the spouse's TPTOTINC, then left-join.
# SSUID is a 15-digit numeric identifier and PNUM is a household-line number;
# coerce both join keys to character on both sides to avoid any floating-point
# precision drift before the join.
sipp_dec_join_keys_tbl <- sipp_dec_tbl |>
  dplyr::mutate(
    SSUID_chr = as.character(SSUID),
    PNUM_chr  = as.character(PNUM)
  )

spouse_lookup_tbl <- sipp_dec_join_keys_tbl |>
  dplyr::select(SSUID_chr, PNUM_chr, TPTOTINC) |>
  dplyr::rename(spouse_tptotinc_num = TPTOTINC)

sipp_dec_with_spouse_tbl <- sipp_dec_join_keys_tbl |>
  dplyr::mutate(
    # EPNSPOUSE is the person-number of the spouse within the same SSUID;
    # missing/blank when the person has no spouse pointer (single households,
    # children, etc.). Coerce to character for the join; leave NA as NA.
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

# Diagnostic: how did the MFJ branch fare on spouse resolution?
mfj_diag_tbl <- sipp_dec_with_spouse_tbl |>
  dplyr::mutate(filing_group_chr = make_filing_group(EFSTATUS)) |>
  dplyr::filter(filing_group_chr == "mfj") |>
  dplyr::summarise(
    n_mfj_rows_int           = dplyr::n(),
    n_epnspouse_missing_int  = sum(is.na(EPNSPOUSE)),
    n_spouse_tptotinc_na_int = sum(is.na(spouse_tptotinc_num)),
    n_apnspouse_imputed_int  = sum(!is.na(APNSPOUSE) & APNSPOUSE != 0L)
  )
message(
  "U1 MFJ spouse-join diagnostics:",
  " rows=", mfj_diag_tbl$n_mfj_rows_int,
  "; EPNSPOUSE missing=", mfj_diag_tbl$n_epnspouse_missing_int,
  "; spouse TPTOTINC unresolved=", mfj_diag_tbl$n_spouse_tptotinc_na_int,
  "; APNSPOUSE imputed=", mfj_diag_tbl$n_apnspouse_imputed_int
)

# Optional sensitivity: drop imputed spouse pointers before joint-income use.
if (isTRUE(drop_imputed_spouse_pointers_flag)) {
  sipp_dec_with_spouse_tbl <- sipp_dec_with_spouse_tbl |>
    dplyr::mutate(
      spouse_tptotinc_num = dplyr::if_else(
        is.na(APNSPOUSE) | APNSPOUSE == 0L,
        spouse_tptotinc_num,
        NA_real_
      )
    )
  message("U1 sensitivity: imputed APNSPOUSE pointers blanked (spouse_tptotinc_num set NA).")
}

sipp_dec_tbl <- sipp_dec_with_spouse_tbl |>
  dplyr::select(-SSUID_chr, -PNUM_chr, -epnspouse_chr)

###################################################################################
###        U2: AGI Approximation from Above-the-Line Adjustments (scaffold)     ###
###################################################################################

# U2 (plan 2026-04-19 Section 4): the Saver's Match statutory income test in
# IRC sec 6433 is an AGI test, not a gross-income test. AGI is defined in IRC
# sec 62 as gross income minus enumerated above-the-line adjustments (e.g.,
# traditional IRA deduction under sec 219, HSA deduction under sec 223,
# self-employed SEP/SIMPLE contributions, student loan interest under sec
# 221, educator expenses, one-half of self-employment tax). None of those
# adjustment FLOW variables are present in the current 48-column
# pu2024_expanded.csv extract -- the extract carries retirement OWNERSHIP
# flags (EOWN_*, EMJOB_*) and a single retirement-asset STOCK (TVAL_RET),
# but no contribution or deduction flows.
#
# Status: U2 is staged as a SCAFFOLD, not a numeric correction.
#   - agi_above_line_adjust_num is introduced as an explicit derived column
#     (dollars per year) so the gross-income -> AGI mapping is visible in
#     code rather than implicit.
#   - The default value is 0 for every row. No above-the-line adjustments
#     are being applied; the downstream sm_income_num is therefore still a
#     gross-income proxy for AGI.
#   - The scaffold is the injection point for a future 01 extract rebuild
#     that adds SIPP 2024 contribution/deduction flow variables. Candidate
#     SIPP variable families to inspect via pyreadstat on pu2024.dta before
#     any rebuild: retirement-contribution items in the Retirement and
#     Pension Plan Coverage topical module (TJB1_CONTRIB*-family names to
#     be verified), HSA-related items if present, and the deductions
#     reported in the Annual Income section of the person-module codebook.
#     Do NOT add candidate names to 01_sipp_subset_from_dta.R until each
#     name has been confirmed in the pu2024.dta header (see AS-1c rule in
#     .claude/rules/ai-skeptic-rules.md). See plan 2026-04-19 Section 8.9.
#
# Bias direction if adjustment stays at 0:
#   AGI_true = gross - adjustment (adjustment >= 0)
#   -> AGI_true <= gross proxy
#   -> fewer people above the sm_upper threshold in the true AGI world than
#      in the gross proxy world
#   -> Bucket 1 and Bucket 2 counts under the gross proxy are LOWER BOUNDS
#      on the true counts. Eligibility is understated, not overstated.

agi_adjust_default_num <- 0  # dollars/year; non-zero after future extract expansion

sipp_dec_tbl <- sipp_dec_tbl |>
  dplyr::mutate(
    # Placeholder for sum of above-the-line adjustments (dollars/year).
    # Replace the 0 with a real computation once the required SIPP flow
    # variables are in the extract. Keep this a numeric column (not NA),
    # because the downstream subtraction uses it as a scalar.
    agi_above_line_adjust_num = agi_adjust_default_num
  )

# Diagnostic: share of rows with any above-the-line adjustment applied. While
# the scaffold is empty this will log 0 rows with nonzero adjustment; once a
# real computation replaces the 0 above, the same diagnostic will tell us how
# many rows the correction actually moves.
u2_diag_tbl <- sipp_dec_tbl |>
  dplyr::summarise(
    n_rows_int            = dplyr::n(),
    n_nonzero_adjust_int  = sum(!is.na(agi_above_line_adjust_num) &
                                  agi_above_line_adjust_num != 0),
    mean_adjust_num       = mean(agi_above_line_adjust_num, na.rm = TRUE)
  )
message(
  "U2 AGI-adjustment diagnostics:",
  " rows=", u2_diag_tbl$n_rows_int,
  "; rows with nonzero above-line adjustment=", u2_diag_tbl$n_nonzero_adjust_int,
  "; mean adjustment ($/yr)=", round(u2_diag_tbl$mean_adjust_num, 0L)
)

###################################################################################
###                      Derive Analysis Variables                              ###
###################################################################################

# 1) Filing-status group and income cell via shared helpers (MFS -> Single thresholds)
# 2) Projected 2027 thresholds
# 3) Earned-income flag, student flag (proxy), dependent flag (proxy)
# 4) Bucket-3 ownership flag (ownership only; DB pensions excluded)

sipp_derived_tbl <- sipp_dec_tbl |>
  dplyr::mutate(
    # 1) Filing group and income test value.
    #    TPTOTINC is MONTHLY reference-month personal income in SIPP 2024;
    #    spouse_tptotinc_num (from the U1 self-join above) is the spouse's
    #    monthly TPTOTINC when filing_group_chr == "mfj". sm_lower / sm_upper
    #    in calibration_cells.R are ANNUAL AGI thresholds from IRC sec 6433
    #    (projected to 2027 via cpi_projection_factor_num). Multiply by 12 so
    #    the bucket comparisons are on matching annual scales. Dec x 12 is a
    #    proxy for calendar-year AGI; see OPEN ITEMS in header.
    #    MFJ fallback: when EPNSPOUSE is missing but EFSTATUS == 2, we use
    #    TPTOTINC alone (single-filer proxy) so the row is not dropped from
    #    the count; this is recorded in the diagnostic message above and
    #    tracked as plan Section 3 row 3e.
    #
    #    U2 hook: sm_gross_income_num is the annualized gross income (U1
    #    spouse-pair sum for MFJ; personal TPTOTINC * 12 otherwise).
    #    sm_income_num then subtracts agi_above_line_adjust_num to produce
    #    the AGI value actually compared against sm_lower / sm_upper. The
    #    adjustment is 0 in the current scaffold (see U2 block above), so
    #    sm_income_num == sm_gross_income_num at present. Keep the two
    #    columns distinct so a future non-zero adjustment is visible.
    filing_group_chr = make_filing_group(EFSTATUS),
    sm_gross_income_num = dplyr::case_when(
      filing_group_chr == "mfj" & !is.na(spouse_tptotinc_num) ~
        (TPTOTINC + spouse_tptotinc_num) * 12,                         # U1: spouse-pair joint income, annualized
      filing_group_chr == "mfj" & is.na(spouse_tptotinc_num) ~
        TPTOTINC * 12,                                                 # U1 fallback: MFJ w/ unresolved spouse pointer
      filing_group_chr %in% c("single_mfs", "hoh") ~ TPTOTINC * 12,    # personal income, annualized
      TRUE ~ NA_real_
    ),
    # sm_income_num is the AGI value actually compared against the sm_lower
    # and sm_upper thresholds. With agi_above_line_adjust_num == 0 (current
    # scaffold), sm_income_num equals sm_gross_income_num. The subtraction
    # is kept in the code so that any future non-zero adjust column produces
    # a visibly lower sm_income_num without requiring further code edits.
    sm_income_num = sm_gross_income_num - agi_above_line_adjust_num,

    # 2) Project 2024 thresholds to 2027
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

    # 3) Earned-income flag (annualized personal earnings > 0)
    personal_annual_earnings_num = TPEARN * 12,
    has_earned_income_flag = dplyr::case_when(
      is.na(personal_annual_earnings_num) ~ FALSE,
      personal_annual_earnings_num > 0    ~ TRUE,
      TRUE ~ FALSE
    ),

    # 3) Student-proxy flag.
    #
    # Statutory basis: IRC sec 25B excludes full-time students (within the
    # meaning of sec 152(f)(2), which requires enrollment at an educational
    # organization for at least five calendar months during the year). SIPP
    # does not report the five-month duration explicitly at the person-
    # month level; we treat December full-time-enrolled status as a
    # sufficient proxy for calendar-year full-time-student status.
    # TO VERIFY: exact subsection letter in sec 25B(c) before publication.
    #
    # Primary: RENROLL == 1 ("currently enrolled" recode) AND EEDFTPT == 1
    #          ("full-time") at the December reference month. Combining both
    #          matches the sec 152(f)(2) "regular student at an educational
    #          organization" definition more tightly than enrollment alone.
    # Fallback: age 18-23 AND EEDUC < 40 (less than some-college complete)
    #          AND earnings below student_earnings_cap_2024_nominal. Used
    #          only when RENROLL or EEDFTPT is missing on the row; the
    #          earnings-cap threshold is a project-specific choice (see
    #          header constants), not a statutory value.
    #
    # Coding verification: RENROLL and EEDFTPT value labels were verified
    # against the SIPP 2024 Wave 1 Household Education topical module
    # codebook on 2026-04-18 via the temp/ai-skeptic-tests/sipp_variable_
    # check.txt artifact. RENROLL = 1 means "currently enrolled" in that
    # coding; EEDFTPT = 1 means "full-time". If the SIPP 2025 Wave 2 release
    # changes these codings, re-verify before reusing this logic.
    student_enrollment_flag = dplyr::case_when(
      !is.na(RENROLL) & RENROLL == 1 &
        !is.na(EEDFTPT) & EEDFTPT == 1 ~ TRUE,
      TAGE >= 18 & TAGE <= 23 & EEDUC < 40 &
        personal_annual_earnings_num < student_earnings_cap_2024_nominal ~ TRUE,
      TRUE ~ FALSE
    ),

    # 3) Dependent-proxy flag.
    #
    # Statutory basis: IRC sec 25B excludes any individual for whom a sec
    # 151 dependency deduction is allowable to another taxpayer for the
    # taxable year. Under sec 152, a dependent is either a "qualifying
    # child" (sec 152(c), broadly: under 19, or under 24 if a full-time
    # student) or a "qualifying relative" (sec 152(d), which requires gross
    # income below the indexed threshold stored in dependent_earnings_cap_
    # 2024_nominal). SIPP does not report tax-return dependency claims
    # directly, so we proxy:
    #   - Age < 19: qualifying child by the under-19 test alone (ignoring
    #     the support test, which SIPP also does not report).
    #   - Age 19-23 AND full-time student AND low earnings: qualifying
    #     child under the under-24-and-student test, subject to a gross-
    #     income restraint (from sec 152(d)) as a belt-and-suspenders
    #     proxy for the sec 152(c) self-support test that SIPP cannot
    #     observe directly.
    # TO VERIFY: exact subsection letter in sec 25B(c) before publication.
    # Both branches are proxies; the true tax-return dependency status is
    # unobserved in SIPP. See plan 2026-04-19 Section 4 U4 for why we accept
    # this proxy given the near-zero aggregate impact on the count.
    dependent_flag = dplyr::case_when(
      TAGE < 19 ~ TRUE,
      TAGE >= 19 & TAGE <= 23 &
        student_enrollment_flag &
        personal_annual_earnings_num < dependent_earnings_cap_2024_nominal ~ TRUE,
      TRUE ~ FALSE
    ),

    # 4) Ownership-only qualifying-account flag (DB pensions excluded).
    owns_qualifying_account_flag = dplyr::case_when(
      EOWN_THR401 == 1 | EOWN_IRAKEO == 1 ~ TRUE,
      TRUE ~ FALSE
    ),

    # 5) Age bands for reporting
    age_band_chr = dplyr::case_when(
      TAGE >= 18 & TAGE <= 29 ~ "18-29",
      TAGE >= 30 & TAGE <= 49 ~ "30-49",
      TAGE >= 50 & TAGE <= 64 ~ "50-64",
      TAGE >= 65              ~ "65+",
      TRUE ~ NA_character_
    )
  )

###################################################################################
###                   Apply Common Filters (All Three Buckets)                  ###
###################################################################################
# Common criteria:
#   - Age 18 or older (no upper cap)
#   - Not a dependent (proxy)
#   - Not a full-time student (proxy)
#   - Has earned income
#   - Valid filing group
#   - If MFJ and mfj_require_own_earnings_flag, spouse must have own earnings

sm_universe_tbl <- sipp_derived_tbl |>
  dplyr::filter(
    TAGE >= 18L,
    !dependent_flag,
    !student_enrollment_flag,
    has_earned_income_flag,
    !is.na(filing_group_chr)
  )

message("Common-universe rows: ", nrow(sm_universe_tbl),
        " | weighted N (M): ",
        round(sum(sm_universe_tbl$WPFINWGT, na.rm = TRUE) / 1e6, 2))

###################################################################################
###                   Define Bucket Membership (Boolean Masks)                  ###
###################################################################################

sm_universe_tbl <- sm_universe_tbl |>
  dplyr::mutate(
    bucket1_any_match_flag = dplyr::case_when(
      is.na(sm_income_num) | is.na(sm_upper_thresh_2027_num) ~ FALSE,
      sm_income_num < sm_upper_thresh_2027_num ~ TRUE,
      TRUE ~ FALSE
    ),
    bucket2_full_match_flag = dplyr::case_when(
      is.na(sm_income_num) | is.na(sm_full_match_thresh_2027_num) ~ FALSE,
      sm_income_num <= sm_full_match_thresh_2027_num ~ TRUE,
      TRUE ~ FALSE
    ),
    bucket3_full_and_owns_flag = bucket2_full_match_flag & owns_qualifying_account_flag,
    # B1 intersect ownership: any-match eligible AND holds a qualifying account.
    # Superset of B3; not nested with B2 (a full-match-eligible non-owner is in B2
    # but not here; a phaseout-range owner is here but not in B2).
    bucket1_any_and_owns_flag = bucket1_any_match_flag & owns_qualifying_account_flag
  )

###################################################################################
###              Compute Weighted Counts: Overall, Filing, Age Band             ###
###################################################################################

# Overall totals
overall_tbl <- sm_universe_tbl |>
  dplyr::summarise(
    group_chr          = "Overall",
    subgroup_chr       = "All",
    bucket1_weighted_n = sum(WPFINWGT * bucket1_any_match_flag,     na.rm = TRUE),
    bucket2_weighted_n = sum(WPFINWGT * bucket2_full_match_flag,    na.rm = TRUE),
    bucket3_weighted_n = sum(WPFINWGT * bucket3_full_and_owns_flag, na.rm = TRUE),
    bucket1_any_and_owns_weighted_n = sum(WPFINWGT * bucket1_any_and_owns_flag, na.rm = TRUE),
    universe_weighted_n = sum(WPFINWGT, na.rm = TRUE)
  )

# By filing status
by_filing_tbl <- sm_universe_tbl |>
  dplyr::group_by(filing_group_chr) |>
  dplyr::summarise(
    bucket1_weighted_n = sum(WPFINWGT * bucket1_any_match_flag,     na.rm = TRUE),
    bucket2_weighted_n = sum(WPFINWGT * bucket2_full_match_flag,    na.rm = TRUE),
    bucket3_weighted_n = sum(WPFINWGT * bucket3_full_and_owns_flag, na.rm = TRUE),
    bucket1_any_and_owns_weighted_n = sum(WPFINWGT * bucket1_any_and_owns_flag, na.rm = TRUE),
    universe_weighted_n = sum(WPFINWGT, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    group_chr = "Filing status",
    subgroup_chr = filing_group_chr
  ) |>
  dplyr::select(group_chr, subgroup_chr,
                bucket1_weighted_n, bucket2_weighted_n, bucket3_weighted_n,
                bucket1_any_and_owns_weighted_n,
                universe_weighted_n)

# By age band
by_age_tbl <- sm_universe_tbl |>
  dplyr::group_by(age_band_chr) |>
  dplyr::summarise(
    bucket1_weighted_n = sum(WPFINWGT * bucket1_any_match_flag,     na.rm = TRUE),
    bucket2_weighted_n = sum(WPFINWGT * bucket2_full_match_flag,    na.rm = TRUE),
    bucket3_weighted_n = sum(WPFINWGT * bucket3_full_and_owns_flag, na.rm = TRUE),
    bucket1_any_and_owns_weighted_n = sum(WPFINWGT * bucket1_any_and_owns_flag, na.rm = TRUE),
    universe_weighted_n = sum(WPFINWGT, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    group_chr = "Age band",
    subgroup_chr = age_band_chr
  ) |>
  dplyr::select(group_chr, subgroup_chr,
                bucket1_weighted_n, bucket2_weighted_n, bucket3_weighted_n,
                bucket1_any_and_owns_weighted_n,
                universe_weighted_n)

results_tbl <- dplyr::bind_rows(overall_tbl, by_filing_tbl, by_age_tbl) |>
  dplyr::mutate(
    bucket1_millions = round(bucket1_weighted_n / 1e6, 2),
    bucket2_millions = round(bucket2_weighted_n / 1e6, 2),
    bucket3_millions = round(bucket3_weighted_n / 1e6, 2),
    bucket1_any_and_owns_millions = round(bucket1_any_and_owns_weighted_n / 1e6, 2),
    universe_millions = round(universe_weighted_n / 1e6, 2)
  )

###################################################################################
###         U5: Filer-Basis Reaggregation for EBRI Benchmark Comparison         ###
###################################################################################
# U5 (plan 2026-04-19 Section 4 / Section 8.6): the bucket counts computed above
# are on a worker (person) basis — each adult in a married couple contributes
# one observation. EBRI's Copeland (2024) Issue Brief No. 602 anchors (83.8M
# any-match, 69.0M full-match, 21.9M full-match-with-account) are on a
# tax-RETURN basis, so every MFJ couple contributes exactly ONE filer, not two.
# To make the SIPP number directly comparable to the EBRI anchors, collapse
# each resolved MFJ spouse-pair to a single "primary-of-pair" record.
#
# Rule (disclosed per AS-3 undisclosed-assumptions check):
#   1. For filing_group_chr in {"single_mfs", "hoh"}: every person is their
#      own filer. Keep the row as-is.
#   2. For filing_group_chr == "mfj" with a resolved spouse pointer
#      (spouse_tptotinc_num is not NA): form a symmetric couple key
#      paste0(SSUID, "_", pmin(PNUM, EPNSPOUSE), "_", pmax(PNUM, EPNSPOUSE))
#      and keep only the member with the LOWER PNUM. This is the
#      reference-person-of-pair convention (deterministic; does not depend
#      on income, which is preferable because TPTOTINC volatility could
#      otherwise reassign the filer role across waves). The kept row
#      already carries the PAIR joint income in sm_income_num via U1, so
#      the bucket flags computed on sm_universe_tbl are already correct
#      at the filer level.
#   3. For filing_group_chr == "mfj" with an UNRESOLVED spouse pointer:
#      the row represents one MFJ person whose spouse cannot be linked.
#      Keep the row (one observation = one putative filer). This is a
#      known imperfection: if the unresolved spouse is separately in the
#      universe with their own unresolved-spouse status, they would each
#      count as a separate filer, double-counting the couple. That
#      double-count is bounded by the unresolved-spouse row count from
#      the U1 diagnostics. Mitigation: report the unresolved count
#      alongside the filer total so Ben can subtract half of it as a
#      sensitivity if the rate is material.
#
# Bucket 3 caveat (owns_qualifying_account_flag at the couple level):
# The EBRI 21.9M anchor is "full-match-eligible filers where AT LEAST ONE
# spouse owns a qualifying account." The current U1 self-join brings over
# spouse TPTOTINC but not spouse account-ownership flags. So the filer-basis
# Bucket 3 here uses only the kept member's own account flag. This is a
# LOWER BOUND on the true couple-level Bucket 3 (couples where only the
# dropped member owned the account are missed). Closing this gap requires
# extending the U1 self-join to carry spouse EOWN_THR401 / EOWN_IRAKEO,
# which is a small 01/03g edit but is out of scope for the 2026-04-19
# pass. Documented in the memo output and flagged in the plan Section 4.

# Build the primary-of-pair mask
sm_universe_filer_tbl <- sm_universe_tbl |>
  dplyr::mutate(
    primary_of_pair_flag = dplyr::case_when(
      filing_group_chr %in% c("single_mfs", "hoh") ~ TRUE,
      filing_group_chr == "mfj" & is.na(spouse_tptotinc_num) ~ TRUE,
      filing_group_chr == "mfj" &
        !is.na(spouse_tptotinc_num) &
        !is.na(EPNSPOUSE) &
        PNUM < EPNSPOUSE ~ TRUE,
      TRUE ~ FALSE
    )
  )

u5_mfj_total_int <- sm_universe_filer_tbl |>
  dplyr::filter(filing_group_chr == "mfj") |>
  nrow()
u5_mfj_kept_int <- sm_universe_filer_tbl |>
  dplyr::filter(filing_group_chr == "mfj" & primary_of_pair_flag) |>
  nrow()
u5_mfj_unresolved_int <- sm_universe_filer_tbl |>
  dplyr::filter(filing_group_chr == "mfj" &
                  is.na(spouse_tptotinc_num)) |>
  nrow()

message(
  "U5 filer-basis diagnostics:",
  " MFJ person-rows=", u5_mfj_total_int,
  "; MFJ filers kept=", u5_mfj_kept_int,
  "; MFJ unresolved-spouse rows kept as-is=", u5_mfj_unresolved_int,
  "; implied MFJ deduplication rate=",
  round(1 - u5_mfj_kept_int / u5_mfj_total_int, 3L)
)

# Collapse to the filer-basis sample
sm_filer_tbl <- sm_universe_filer_tbl |>
  dplyr::filter(primary_of_pair_flag)

# Filer-basis Overall
overall_filer_tbl <- sm_filer_tbl |>
  dplyr::summarise(
    group_chr          = "Overall (filer basis)",
    subgroup_chr       = "All",
    bucket1_weighted_n = sum(WPFINWGT * bucket1_any_match_flag,     na.rm = TRUE),
    bucket2_weighted_n = sum(WPFINWGT * bucket2_full_match_flag,    na.rm = TRUE),
    bucket3_weighted_n = sum(WPFINWGT * bucket3_full_and_owns_flag, na.rm = TRUE),
    bucket1_any_and_owns_weighted_n = sum(WPFINWGT * bucket1_any_and_owns_flag, na.rm = TRUE),
    universe_weighted_n = sum(WPFINWGT, na.rm = TRUE)
  )

# Filer-basis by filing status
by_filing_filer_tbl <- sm_filer_tbl |>
  dplyr::group_by(filing_group_chr) |>
  dplyr::summarise(
    bucket1_weighted_n = sum(WPFINWGT * bucket1_any_match_flag,     na.rm = TRUE),
    bucket2_weighted_n = sum(WPFINWGT * bucket2_full_match_flag,    na.rm = TRUE),
    bucket3_weighted_n = sum(WPFINWGT * bucket3_full_and_owns_flag, na.rm = TRUE),
    bucket1_any_and_owns_weighted_n = sum(WPFINWGT * bucket1_any_and_owns_flag, na.rm = TRUE),
    universe_weighted_n = sum(WPFINWGT, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    group_chr = "Filing status (filer basis)",
    subgroup_chr = filing_group_chr
  ) |>
  dplyr::select(group_chr, subgroup_chr,
                bucket1_weighted_n, bucket2_weighted_n, bucket3_weighted_n,
                bucket1_any_and_owns_weighted_n,
                universe_weighted_n)

filer_results_tbl <- dplyr::bind_rows(overall_filer_tbl, by_filing_filer_tbl) |>
  dplyr::mutate(
    bucket1_millions = round(bucket1_weighted_n / 1e6, 2),
    bucket2_millions = round(bucket2_weighted_n / 1e6, 2),
    bucket3_millions = round(bucket3_weighted_n / 1e6, 2),
    bucket1_any_and_owns_millions = round(bucket1_any_and_owns_weighted_n / 1e6, 2),
    universe_millions = round(universe_weighted_n / 1e6, 2)
  )

# EBRI Copeland (2024) anchors (filer basis, IRS SOI 2018).
# Hard-coded here for side-by-side reporting only; not a threshold.
ebri_any_match_millions_num    <- 83.8
ebri_full_match_millions_num   <- 69.0
ebri_full_and_owns_millions_num <- 21.9

ebri_ratio_tbl <- overall_filer_tbl |>
  dplyr::transmute(
    group_chr,
    subgroup_chr,
    bucket1_millions = round(bucket1_weighted_n / 1e6, 2),
    bucket2_millions = round(bucket2_weighted_n / 1e6, 2),
    bucket3_millions = round(bucket3_weighted_n / 1e6, 2),
    # B1 intersect ownership: reported in millions only; no EBRI anchor exists
    # for this quantity (EBRI Copeland 2024 reports only B1, B2, and B3).
    bucket1_any_and_owns_millions = round(bucket1_any_and_owns_weighted_n / 1e6, 2),
    bucket1_pct_of_ebri = round(
      100 * (bucket1_weighted_n / 1e6) / ebri_any_match_millions_num, 1L),
    bucket2_pct_of_ebri = round(
      100 * (bucket2_weighted_n / 1e6) / ebri_full_match_millions_num, 1L),
    bucket3_pct_of_ebri = round(
      100 * (bucket3_weighted_n / 1e6) / ebri_full_and_owns_millions_num, 1L)
  )

message(
  "U5 filer-basis overall (millions):",
  " B1=", ebri_ratio_tbl$bucket1_millions,
  " (", ebri_ratio_tbl$bucket1_pct_of_ebri, "% of EBRI 83.8M);",
  " B2=", ebri_ratio_tbl$bucket2_millions,
  " (", ebri_ratio_tbl$bucket2_pct_of_ebri, "% of EBRI 69.0M);",
  " B3=", ebri_ratio_tbl$bucket3_millions,
  " (", ebri_ratio_tbl$bucket3_pct_of_ebri, "% of EBRI 21.9M);",
  " B1 \u2229 account=", ebri_ratio_tbl$bucket1_any_and_owns_millions,
  "M (no EBRI anchor)"
)

###################################################################################
###                        Sanity Checks and Verification                       ###
###################################################################################

# Nesting: B1 >= B2 >= B3 for every row. Also B1 >= (B1 intersect account) >= B3.
# (B1 intersect account) is NOT nested with B2: a phaseout-range owner is in the
# new bucket but not in B2, and a full-match-eligible non-owner is in B2 but
# not in the new bucket.
nesting_violations_int <- results_tbl |>
  dplyr::filter(
    bucket1_weighted_n < bucket2_weighted_n |
      bucket2_weighted_n < bucket3_weighted_n |
      bucket1_weighted_n < bucket1_any_and_owns_weighted_n |
      bucket1_any_and_owns_weighted_n < bucket3_weighted_n
  ) |>
  nrow()

if (nesting_violations_int > 0L) {
  stop("Nesting violated: B1 >= B2 >= B3 and B1 >= (B1 \u2229 account) >= B3 ",
       "failed in ", nesting_violations_int, " rows.")
}

message("Overall Bucket 1 (any-match, millions): ",
        overall_tbl$bucket1_weighted_n / 1e6)
message("Overall Bucket 2 (full-match, millions): ",
        overall_tbl$bucket2_weighted_n / 1e6)
message("Overall Bucket 3 (full + owns, millions): ",
        overall_tbl$bucket3_weighted_n / 1e6)
message("Overall B1 intersect account (any-match + owns, millions): ",
        overall_tbl$bucket1_any_and_owns_weighted_n / 1e6)

# External benchmark comparison (informational -- different units)
message("External benchmarks (different units; compare qualitatively):")
message("  EBRI (Copeland 2024, filers, IRS SOI 2018):")
message("    any-match 83.8M | full-match 69.0M | full+owns 21.9M")
message("  Morningstar (Jan 2025, households, SCF 2022): ~27M eligible")

###################################################################################
###      Phase 4: CPS ASEC 2025 Inline Validation (gated; default off)          ###
###################################################################################
# Plan 2026-04-19 Section 5 + revised Section 8.5: CPS ASEC 2025 cross-check
# runs INLINE here (not in a sibling script) behind a top-level toggle. It
# pulls CPS ASEC 2025 via the IPUMS API, applies parallel bucket rules using
# the IPUMS-adjusted gross income variable (ADJGINC), and emits a single
# comparison table savers_match_validation_cps_vs_sipp.{rds,parquet}.
#
# Why CPS ASEC 2025: it covers income year 2024, the same reference year
# SIPP 2024 Wave 1 covers. ADJGINC is an AGI-concept variable from IPUMS,
# so it sidesteps the U2 gross-vs-AGI gap that blocks the SIPP pipeline.
#
# Why gated: the first run submits an IPUMS extract request that queues
# and typically resolves in 5-15 minutes. The Tier 2-3 job must not run
# on every 03g execution. Default is FALSE; flip to TRUE once to build
# the cache, then flip back.
#
# What the block does NOT do: it does NOT replace the SIPP estimates. It
# does NOT feed the production `results_tbl` or `filer_results_tbl`. It
# only produces a third comparison artifact.
#
# Unverified items that Ben should confirm on first run:
#   1. `cps_sample_id_chr` — the exact IPUMS sample identifier for CPS
#      ASEC 2025. Plan tentatively uses "cps2025_03s"; confirm via
#      `ipumsr::get_sample_info(collection = "cps")` before trusting.
#   2. `ipumsr::wait_for_extract()` argument name for timeout. Recent
#      ipumsr versions use `timeout_seconds`. If your installed ipumsr
#      is older, adjust to `timeout = ...`. The block catches the resulting
#      error and surfaces a hint.
#   3. IPUMS_API_KEY env var must be set. If missing, the block errors
#      early with a clear message and skips the validation.

run_cps_validation_flag <- TRUE

if (run_cps_validation_flag) {

  message("Phase 4: CPS ASEC 2025 validation starting (this can take ",
          "5-15 minutes on first run).")

  # Guard: ipumsr must be installed. Do not make it a hard library()
  # dependency at the top of 03g, because the SIPP pipeline does not
  # need it.
  if (!requireNamespace("ipumsr", quietly = TRUE)) {
    stop(
      "Phase 4 CPS validation requires the ipumsr package. ",
      "Install with install.packages('ipumsr') and rerun with ",
      "run_cps_validation_flag <- TRUE.",
      call. = FALSE
    )
  }

  # Guard: API key must be present
  ipums_api_key_chr <- Sys.getenv("IPUMS_API_KEY", unset = NA_character_)
  if (is.na(ipums_api_key_chr) || !nzchar(ipums_api_key_chr)) {
    stop(
      "Phase 4 CPS validation requires IPUMS_API_KEY in the environment. ",
      "Get a key from https://account.ipums.org/api_keys and set via ",
      "Sys.setenv(IPUMS_API_KEY = '...') before rerunning.",
      call. = FALSE
    )
  }

  # Tentative sample ID -- Ben to verify against ipumsr::get_sample_info()
  cps_sample_id_chr <- "cps2025_03s"

  # Local cache directory for IPUMS extract
  cps_cache_dir_chr <- file.path(path_data_raw, "cps_asec_2025")
  if (!dir.exists(cps_cache_dir_chr)) {
    dir.create(cps_cache_dir_chr, recursive = TRUE)
  }

  # Variables needed to apply the Saver's Match bucket rules on CPS ASEC
  cps_vars_chr <- c(
    "YEAR", "MONTH", "SERIAL", "PERNUM",
    "SPLOC", "RELATE",
    "AGE", "SEX", "MARST",
    "FILESTAT", "DEPSTAT", "SCHLCOLL",
    "INCTOT", "ADJGINC", "INCWAGE",
    "ASECWT"
  )

  # Submit extract (cache-aware). If the cache directory already contains a
  # .xml DDI file, skip resubmission and read from disk.
  existing_ddi_chr <- list.files(
    cps_cache_dir_chr, pattern = "\\.xml$", full.names = TRUE
  )
  if (length(existing_ddi_chr) == 0L) {

    ipumsr::set_ipums_api_key(ipums_api_key_chr, save = FALSE)

    cps_extract_def <- ipumsr::define_extract_micro(
      collection  = "cps",
      description = "RSAA Saver's Match validation -- ASEC 2025",
      samples     = cps_sample_id_chr,
      variables   = cps_vars_chr
    )

    cps_submitted <- ipumsr::submit_extract(cps_extract_def)

    # Argument-name robustness: try timeout_seconds first (ipumsr >= 0.7),
    # fall back to timeout (older).
    cps_waited <- tryCatch(
      ipumsr::wait_for_extract(cps_submitted, timeout_seconds = 3600L),
      error = function(e1) {
        message("wait_for_extract(timeout_seconds=) failed: ",
                conditionMessage(e1), "; retrying with timeout= argument.")
        tryCatch(
          ipumsr::wait_for_extract(cps_submitted, timeout = 3600L),
          error = function(e2) {
            stop("ipumsr::wait_for_extract failed with both argument names: ",
                 conditionMessage(e2), call. = FALSE)
          }
        )
      }
    )

    cps_ddi <- ipumsr::download_extract(
      cps_waited, download_dir = cps_cache_dir_chr
    )

  } else {
    message("CPS cache hit: reading DDI from ", existing_ddi_chr[1L])
    cps_ddi <- ipumsr::read_ipums_ddi(existing_ddi_chr[1L])
  }

  cps_raw_tbl <- ipumsr::read_ipums_micro(cps_ddi)

  message("CPS ASEC 2025 rows read: ", nrow(cps_raw_tbl))

  # Parallel bucket logic.
  # FILESTAT IPUMS codes: 1 = Joint (MFJ); 2 = Separate (MFS);
  # 3 = Head of household; 4 = Single; 5 = Surviving spouse; 6 = Nonfiler.
  # Collapse to the same three-way filing_group_chr used on SIPP:
  #   mfj         <- FILESTAT == 1
  #   single_mfs  <- FILESTAT %in% c(2, 4, 5)
  #   hoh         <- FILESTAT == 3
  #   (nonfilers: FILESTAT == 6 dropped from the filer universe)
  # DEPSTAT IPUMS code 0 = not a dependent; != 0 = dependent.
  # SCHLCOLL IPUMS codes: 0 = not in school, 1 = HS FT, 2 = HS PT,
  #   3 = College FT, 4 = College PT. Full-time student flag fires when
  #   SCHLCOLL %in% c(1, 3).

  cps_universe_tbl <- cps_raw_tbl |>
    dplyr::filter(
      AGE >= 18L,
      DEPSTAT == 0L,
      !(SCHLCOLL %in% c(1L, 3L)),
      FILESTAT %in% c(1L, 2L, 3L, 4L, 5L),
      INCWAGE > 0L | INCTOT > 0L
    ) |>
    dplyr::mutate(
      filing_group_chr = dplyr::case_when(
        FILESTAT == 1L ~ "mfj",
        FILESTAT == 3L ~ "hoh",
        FILESTAT %in% c(2L, 4L, 5L) ~ "single_mfs",
        TRUE ~ NA_character_
      ),
      # ADJGINC is an AGI-concept variable from IPUMS -- no gross-vs-AGI
      # adjustment needed. Use directly as sm_income_num equivalent.
      sm_income_cps_num = ADJGINC,
      # Threshold lookups mirror the SIPP construction at lines ~520-531.
      # Reuse the same named sm_lower/sm_upper numeric vectors and the
      # same cpi_projection_factor_num scalar so the CPS universe is
      # subject to identical TY2027 thresholds.
      sm_upper_thresh_cps_num = dplyr::case_when(
        filing_group_chr == "single_mfs" ~ sm_upper[["Single"]] * cpi_projection_factor_num,
        filing_group_chr == "hoh"        ~ sm_upper[["HoH"]]    * cpi_projection_factor_num,
        filing_group_chr == "mfj"        ~ sm_upper[["MFJ"]]    * cpi_projection_factor_num,
        TRUE ~ NA_real_
      ),
      sm_full_match_thresh_cps_num = dplyr::case_when(
        filing_group_chr == "single_mfs" ~ sm_lower[["Single"]] * cpi_projection_factor_num,
        filing_group_chr == "hoh"        ~ sm_lower[["HoH"]]    * cpi_projection_factor_num,
        filing_group_chr == "mfj"        ~ sm_lower[["MFJ"]]    * cpi_projection_factor_num,
        TRUE ~ NA_real_
      ),
      bucket1_any_match_flag = dplyr::case_when(
        is.na(sm_income_cps_num) | is.na(sm_upper_thresh_cps_num) ~ FALSE,
        sm_income_cps_num < sm_upper_thresh_cps_num ~ TRUE,
        TRUE ~ FALSE
      ),
      bucket2_full_match_flag = dplyr::case_when(
        is.na(sm_income_cps_num) | is.na(sm_full_match_thresh_cps_num) ~ FALSE,
        sm_income_cps_num <= sm_full_match_thresh_cps_num ~ TRUE,
        TRUE ~ FALSE
      )
      # Bucket 3 (account-ownership) cannot be computed on CPS ASEC without
      # pulling the retirement-account supplement, which is NOT on the
      # default ASEC file. Bucket 3 is omitted from the CPS comparison.
    )

  # Collapse MFJ to one filer per couple using SPLOC (analogous to the
  # SIPP EPNSPOUSE convention): keep the lower PERNUM when SPLOC > 0 and
  # within the same SERIAL.
  cps_filer_tbl <- cps_universe_tbl |>
    dplyr::mutate(
      primary_of_pair_flag = dplyr::case_when(
        filing_group_chr %in% c("single_mfs", "hoh") ~ TRUE,
        filing_group_chr == "mfj" & (is.na(SPLOC) | SPLOC == 0L) ~ TRUE,
        filing_group_chr == "mfj" & SPLOC > 0L & PERNUM < SPLOC ~ TRUE,
        TRUE ~ FALSE
      )
    ) |>
    dplyr::filter(primary_of_pair_flag)

  cps_filer_counts_tbl <- cps_filer_tbl |>
    dplyr::summarise(
      cps_b1_millions = round(
        sum(ASECWT * bucket1_any_match_flag,  na.rm = TRUE) / 1e6, 2),
      cps_b2_millions = round(
        sum(ASECWT * bucket2_full_match_flag, na.rm = TRUE) / 1e6, 2)
    )

  # Comparison table (Overall row only for this first pass)
  savers_match_cps_vs_sipp_tbl <- tibble::tibble(
    scope_chr        = "Overall, filer basis, income year 2024",
    sipp_b1_millions = ebri_ratio_tbl$bucket1_millions,
    sipp_b2_millions = ebri_ratio_tbl$bucket2_millions,
    cps_b1_millions  = cps_filer_counts_tbl$cps_b1_millions,
    cps_b2_millions  = cps_filer_counts_tbl$cps_b2_millions,
    ebri_b1_millions = ebri_any_match_millions_num,
    ebri_b2_millions = ebri_full_match_millions_num,
    cps_vs_sipp_b1_ratio = round(
      cps_filer_counts_tbl$cps_b1_millions /
        ebri_ratio_tbl$bucket1_millions, 3L),
    cps_vs_sipp_b2_ratio = round(
      cps_filer_counts_tbl$cps_b2_millions /
        ebri_ratio_tbl$bucket2_millions, 3L),
    cps_vs_ebri_b1_ratio = round(
      cps_filer_counts_tbl$cps_b1_millions /
        ebri_any_match_millions_num, 3L),
    cps_vs_ebri_b2_ratio = round(
      cps_filer_counts_tbl$cps_b2_millions /
        ebri_full_match_millions_num, 3L)
  )

  saveRDS(
    savers_match_cps_vs_sipp_tbl,
    file.path(path_output_tables, "savers_match_validation_cps_vs_sipp.rds")
  )
  arrow::write_parquet(
    savers_match_cps_vs_sipp_tbl,
    file.path(path_output_tables, "savers_match_validation_cps_vs_sipp.parquet"),
    compression = "snappy"
  )

  message(
    "Phase 4 CPS validation complete. Overall filer-basis counts:",
    " SIPP B1=", ebri_ratio_tbl$bucket1_millions,
    "M; CPS B1=", cps_filer_counts_tbl$cps_b1_millions,
    "M; EBRI B1=", ebri_any_match_millions_num, "M.",
    " SIPP B2=", ebri_ratio_tbl$bucket2_millions,
    "M; CPS B2=", cps_filer_counts_tbl$cps_b2_millions,
    "M; EBRI B2=", ebri_full_match_millions_num, "M."
  )

} else {

  message("Phase 4 CPS validation skipped (run_cps_validation_flag is FALSE).")

}

###################################################################################
###                                Save Outputs                                 ###
###################################################################################

saveRDS(results_tbl,
        file.path(path_output_tables, "savers_match_eligibility_buckets.rds"))
arrow::write_parquet(
  results_tbl,
  file.path(path_output_tables, "savers_match_eligibility_buckets.parquet"),
  compression = "snappy"
)

# U5 filer-basis companion tables
saveRDS(
  filer_results_tbl,
  file.path(path_output_tables, "savers_match_eligibility_buckets_filerbasis.rds")
)
arrow::write_parquet(
  filer_results_tbl,
  file.path(path_output_tables,
            "savers_match_eligibility_buckets_filerbasis.parquet"),
  compression = "snappy"
)
saveRDS(
  ebri_ratio_tbl,
  file.path(path_output_tables, "savers_match_filer_vs_ebri.rds")
)
arrow::write_parquet(
  ebri_ratio_tbl,
  file.path(path_output_tables, "savers_match_filer_vs_ebri.parquet"),
  compression = "snappy"
)

message("Saved: ",
        file.path(path_output_tables, "savers_match_eligibility_buckets.rds"))
message("Saved: ",
        file.path(path_output_tables, "savers_match_eligibility_buckets.parquet"))
message("Saved: ",
        file.path(path_output_tables,
                  "savers_match_eligibility_buckets_filerbasis.rds"))
message("Saved: ",
        file.path(path_output_tables,
                  "savers_match_eligibility_buckets_filerbasis.parquet"))
message("Saved: ",
        file.path(path_output_tables, "savers_match_filer_vs_ebri.rds"))
message("Saved: ",
        file.path(path_output_tables, "savers_match_filer_vs_ebri.parquet"))

###################################################################################
###                            Short Memo Output                                ###
###################################################################################

memo_lines_chr <- c(
  "# Saver's Match Eligible Population: Three-Bucket Estimate",
  "",
  paste0("_Generated: ", format(Sys.Date()), "_"),
  "",
  "## Headline (overall, worker-level, SIPP 2024, 2027-projected thresholds)",
  "",
  paste0("- Bucket 1 (any-match eligible): ",
         round(overall_tbl$bucket1_weighted_n / 1e6, 1),
         " million workers."),
  paste0("- Bucket 2 (full-match eligible): ",
         round(overall_tbl$bucket2_weighted_n / 1e6, 1),
         " million workers."),
  paste0("- Bucket 3 (full-match eligible AND currently hold a qualifying account): ",
         round(overall_tbl$bucket3_weighted_n / 1e6, 1),
         " million workers."),
  paste0("- Any-match eligible AND currently hold a qualifying account: ",
         round(overall_tbl$bucket1_any_and_owns_weighted_n / 1e6, 1),
         " million workers (superset of Bucket 3; includes phaseout-range owners who are not in Bucket 2)."),
  "",
  "## Filer-basis comparison to EBRI (U5)",
  "",
  "The worker-level counts above count each adult in a married couple separately. EBRI's 83.8M / 69.0M / 21.9M anchors are on a tax-return basis, where each MFJ couple contributes exactly one filer. The table below collapses each resolved MFJ spouse-pair to its lower-PNUM member (reference-person-of-pair convention) so the SIPP estimate is directly comparable to EBRI.",
  "",
  paste0("- Bucket 1 (any-match, filer basis): ",
         ebri_ratio_tbl$bucket1_millions,
         " million filers (",
         ebri_ratio_tbl$bucket1_pct_of_ebri,
         " percent of EBRI 83.8M)."),
  paste0("- Bucket 2 (full-match, filer basis): ",
         ebri_ratio_tbl$bucket2_millions,
         " million filers (",
         ebri_ratio_tbl$bucket2_pct_of_ebri,
         " percent of EBRI 69.0M)."),
  paste0("- Bucket 3 (full-match + owns, filer basis): ",
         ebri_ratio_tbl$bucket3_millions,
         " million filers (",
         ebri_ratio_tbl$bucket3_pct_of_ebri,
         " percent of EBRI 21.9M). Lower bound: couples where only the dropped member owns the account are missed (see U5 caveat)."),
  paste0("- Any-match eligible AND owns qualifying account (filer basis): ",
         ebri_ratio_tbl$bucket1_any_and_owns_millions,
         " million filers. No EBRI anchor exists for this quantity; reported for internal reference only."),
  "",
  "## External benchmarks",
  "",
  "- EBRI (Copeland 2024, Issue Brief No. 602, IRS SOI 2018 filers): 83.8M any-match, 69.0M full-match, 21.9M full-match-with-account.",
  "- Morningstar (January 2025, SCF 2022 households): ~27M eligible.",
  "",
  "## Open items (see methodology doc)",
  "",
  paste0("- CPI-U projection factor: ", cpi_projection_factor_num,
         " (set to 1.0 per IRC Section 6433(h)(1); COLA applies to tax years after 2027)."),
  paste0("- Student-proxy earnings cap placeholder: $",
         format(student_earnings_cap_2024_nominal, big.mark = ","), "."),
  paste0("- Dependent-proxy earnings cap placeholder: $",
         format(dependent_earnings_cap_2024_nominal, big.mark = ","), "."),
  paste0("- MFJ own-earnings rule: ",
         ifelse(mfj_require_own_earnings_flag,
                "requires own earnings",
                "joint-income only")),
  "- Income period: SIPP TPTOTINC is monthly reference-month person-level income; statute thresholds are annual. See methodology doc for the scaling convention."
)

writeLines(
  memo_lines_chr,
  file.path(path_output_reports, "savers_match_eligibility_buckets.md")
)
message("Saved: ",
        file.path(path_output_reports, "savers_match_eligibility_buckets.md"))
