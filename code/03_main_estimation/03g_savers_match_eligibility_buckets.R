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
#   - Income-period handling: RESOLVED 2026-04-24 (Option B). TPTOTINC /
#     TFTOTINC / TPEARN in SIPP are MONTHLY reference-month values. The
#     previous implementation approximated calendar-year values as
#     Dec x 12. We now aggregate across all observed MONTHCODE rows in
#     the person-year block (sum of monthly values scaled to 12 months
#     via sum * 12 / n_valid_months) and carry the annual columns onto
#     the December reference-month record. Retirement-module attributes
#     (EOWN_*, EMJOB_*, EPENSNYN, EINCPENS) remain on December. Option B
#     means partial-year respondents (n_valid < 12) are still scaled to
#     a 12-month basis; restrict_to_full_year_flag in the script body
#     toggles a Option-C sensitivity that drops partial-year records.
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
#     see the "U5" block after the person-level aggregation. Outputs:
#     savers_match_eligibility_buckets_filerbasis.{rds,parquet} and the
#     CPS-anchored savers_match_workers_vs_cps.{rds,parquet} (PRIMARY)
#     and savers_match_filers_vs_cps.{rds,parquet} (secondary). Remaining
#     caveat: Bucket 3 on a filer basis is a LOWER BOUND because the U1
#     self-join does not carry spouse account-ownership flags; closing
#     this gap requires extending the U1 self-join in a future pass.

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
  # Account ownership + main-employer retirement-plan access
  "EOWN_THR401", "EOWN_IRAKEO",
  "EPENSNYN", "EINCPENS",
  "EMJOB_401", "EMJOB_IRA", "EMJOB_PEN",
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

###################################################################################
###        Person-Year Income Aggregation (Option B: Observed-Months)           ###
###################################################################################
# Replaces the prior Dec x 12 proxy for calendar-year income. For each person,
# aggregate TPTOTINC, TFTOTINC, and TPEARN across all observed MONTHCODE rows
# (1..12), then scale the sum to a 12-month basis via
# (sum_observed * 12 / n_valid_months). For the typical SIPP respondent
# observed all 12 months, n_valid = 12 and the result is the measured
# calendar-year total with no further proxy.
#
# Why this dominates the prior Dec x 12 annualization:
#   1. For all-12-month respondents the quantity is measured, not extrapolated.
#      Dec x 12 requires flat monthly earnings to be unbiased; sum-over-months
#      does not.
#   2. Classical measurement error in one month enters the sum with variance
#      n * sigma^2 rather than 144 * sigma^2 under single-month scale-up, so
#      the new annual value is substantially less noisy.
#   3. Persons with zero December earnings but nonzero earnings earlier in
#      the year (mid-year job leavers, retirees, new UI recipients) are no
#      longer silently excluded via has_earned_income_flag = FALSE.
#
# Option B partial-year caveat: if a respondent is observed for only
# n_valid < 12 months, the 12 / n_valid scale-up assumes the observed
# months are representative of the unobserved months. This is wrong for
# seasonal workers and for mid-year entrants/exiters, and less wrong than
# Dec x 12 for the common case of a respondent with smooth earnings. A
# full-year restriction (n_valid == 12L) is available as a sensitivity
# toggle via restrict_to_full_year_flag below.
#
# Retirement-module attributes (EOWN_*, EMJOB_*, EPENSNYN, EINCPENS),
# enrollment, dependency proxy, filing status, age, and the person weight
# WPFINWGT all remain on the December reference-month record; only the
# income and earnings aggregates are recomputed here.

# Sensitivity toggle: restrict to respondents observed for all 12 months.
# Default FALSE (Option B as selected). Flip to TRUE for a Option-C
# sensitivity that drops partial-year respondents instead of scaling them.
restrict_to_full_year_flag <- FALSE

sipp_person_year_tbl <- sipp_raw_tbl |>
  dplyr::group_by(SSUID, PNUM) |>
  dplyr::summarise(
    tptotinc_sum_num            = sum(TPTOTINC, na.rm = TRUE),
    tftotinc_sum_num            = sum(TFTOTINC, na.rm = TRUE),
    tpearn_sum_num              = sum(TPEARN,   na.rm = TRUE),
    n_months_observed_int       = dplyr::n(),
    n_months_tptotinc_valid_int = sum(!is.na(TPTOTINC)),
    n_months_tftotinc_valid_int = sum(!is.na(TFTOTINC)),
    n_months_tpearn_valid_int   = sum(!is.na(TPEARN)),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    # Option B: observed-months annualization. Scale the sum of observed
    # months up to a 12-month basis. Return NA_real_ if a person has zero
    # valid months for a variable rather than forcing 0, which downstream
    # comparisons would otherwise treat as a valid zero income.
    tptotinc_annual_num = dplyr::if_else(
      n_months_tptotinc_valid_int > 0L,
      tptotinc_sum_num * 12 / n_months_tptotinc_valid_int,
      NA_real_
    ),
    tftotinc_annual_num = dplyr::if_else(
      n_months_tftotinc_valid_int > 0L,
      tftotinc_sum_num * 12 / n_months_tftotinc_valid_int,
      NA_real_
    ),
    tpearn_annual_num = dplyr::if_else(
      n_months_tpearn_valid_int > 0L,
      tpearn_sum_num * 12 / n_months_tpearn_valid_int,
      NA_real_
    )
  )

# Diagnostic: distribution of observed months across the sample. Full-year
# respondents (n_months_observed_int == 12L) are the common case; partial-
# year respondents are scaled up under Option B with the caveat above.
months_observed_summary_tbl <- sipp_person_year_tbl |>
  dplyr::count(n_months_observed_int, name = "n_persons") |>
  dplyr::arrange(n_months_observed_int)
message("Person-year aggregation: months-observed distribution")
for (i in seq_len(nrow(months_observed_summary_tbl))) {
  message(sprintf(
    "  %2d months: %8d persons",
    months_observed_summary_tbl$n_months_observed_int[i],
    months_observed_summary_tbl$n_persons[i]
  ))
}

n_partial_year_int <- sum(sipp_person_year_tbl$n_months_observed_int < 12L)
message(sprintf(
  "Partial-year respondents (< 12 months): %d of %d (%.2f%%)",
  n_partial_year_int,
  nrow(sipp_person_year_tbl),
  100 * n_partial_year_int / nrow(sipp_person_year_tbl)
))

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

# Restrict to December reference month (retirement items are collected in
# December) and attach the person-year annualized income and earnings columns.
sipp_dec_tbl <- sipp_raw_tbl |>
  dplyr::filter(MONTHCODE == 12L) |>
  dplyr::left_join(
    sipp_person_year_tbl,
    by = c("SSUID", "PNUM")
  )

message("Rows after December restriction: ", nrow(sipp_dec_tbl))

# Persons present for some months but absent from December exist in
# sipp_person_year_tbl but will not appear in sipp_dec_tbl. Log the count so
# the downstream universe-size story is auditable. Their annual income is
# computable but they drop out of the bucket estimation because they have no
# December filing status, retirement-ownership, or age record.
n_persons_year_int <- nrow(sipp_person_year_tbl)
n_persons_december_int <- nrow(sipp_dec_tbl)
message(sprintf(
  "Persons in year but missing December: %d (year: %d, December: %d)",
  n_persons_year_int - n_persons_december_int,
  n_persons_year_int,
  n_persons_december_int
))

# Defensive scale check on TPTOTINC / TFTOTINC (monthly December values).
# The person-year aggregation above sums monthly values; if the extract is
# ever rebuilt with already-annualized income, the sum would 12x-compound
# the annualization. Median monthly personal income is typically
# ~$3,000-$4,500; median monthly family income is typically ~$5,000-$6,500.
# Error out if medians look annual.
tptotinc_median_num <- median(sipp_dec_tbl$TPTOTINC, na.rm = TRUE)
tftotinc_median_num <- median(sipp_dec_tbl$TFTOTINC, na.rm = TRUE)
message("TPTOTINC median (monthly-scale check): ", round(tptotinc_median_num, 0L))
message("TFTOTINC median (monthly-scale check): ", round(tftotinc_median_num, 0L))
if (!is.na(tptotinc_median_num) && tptotinc_median_num > 15000) {
  stop(
    "TPTOTINC median is ", tptotinc_median_num,
    " -- expected monthly scale (~$3,000-$4,500). ",
    "If the extract is already annualized, the person-year aggregation ",
    "above has 12x-compounded the annualization.",
    call. = FALSE
  )
}
if (!is.na(tftotinc_median_num) && tftotinc_median_num > 20000) {
  stop(
    "TFTOTINC median is ", tftotinc_median_num,
    " -- expected monthly scale (~$5,000-$6,500). ",
    "If the extract is already annualized, the person-year aggregation ",
    "above has 12x-compounded the annualization.",
    call. = FALSE
  )
}

# Additional defensive check on the Option-B annual values produced above.
# tptotinc_annual_num and tftotinc_annual_num should land in an annual
# range (~$25,000-$80,000 medians including adults with low earnings).
# Bounds are wide so the check only trips on clearly-wrong values.
tptotinc_annual_median_num <- median(sipp_dec_tbl$tptotinc_annual_num, na.rm = TRUE)
tftotinc_annual_median_num <- median(sipp_dec_tbl$tftotinc_annual_num, na.rm = TRUE)
message("tptotinc_annual_num median (annual-scale check): ",
        round(tptotinc_annual_median_num, 0L))
message("tftotinc_annual_num median (annual-scale check): ",
        round(tftotinc_annual_median_num, 0L))
if (!is.na(tptotinc_annual_median_num) &&
    (tptotinc_annual_median_num < 10000 || tptotinc_annual_median_num > 500000)) {
  stop(
    "tptotinc_annual_num median is ", round(tptotinc_annual_median_num, 0L),
    " -- expected annual scale (~$25,000-$80,000). ",
    "Verify the person-year aggregation block produced the expected scale.",
    call. = FALSE
  )
}
if (!is.na(tftotinc_annual_median_num) &&
    (tftotinc_annual_median_num < 15000 || tftotinc_annual_median_num > 750000)) {
  stop(
    "tftotinc_annual_num median is ", round(tftotinc_annual_median_num, 0L),
    " -- expected annual scale (~$50,000-$120,000). ",
    "Verify the person-year aggregation block produced the expected scale.",
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

# Build a per-person lookup carrying the spouse's ANNUAL TPTOTINC, then
# left-join onto December records. SSUID is a 15-digit numeric identifier and
# PNUM is a household-line number; coerce both join keys to character on both
# sides to avoid any floating-point precision drift before the join.
#
# The spouse lookup is built from sipp_person_year_tbl rather than the
# December-only table so that a spouse's annual income is available even
# when the spouse is absent from the December reference row (partial-year
# observation). The EPNSPOUSE pointer still comes from the reference
# person's December record; only the spouse's annual income lookup is
# broadened.
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
    n_mfj_rows_int                  = dplyr::n(),
    n_epnspouse_missing_int         = sum(is.na(EPNSPOUSE)),
    n_spouse_tptotinc_annual_na_int = sum(is.na(spouse_tptotinc_annual_num)),
    n_apnspouse_imputed_int         = sum(!is.na(APNSPOUSE) & APNSPOUSE != 0L)
  )
message(
  "U1 MFJ spouse-join diagnostics:",
  " rows=", mfj_diag_tbl$n_mfj_rows_int,
  "; EPNSPOUSE missing=", mfj_diag_tbl$n_epnspouse_missing_int,
  "; spouse annual TPTOTINC unresolved=", mfj_diag_tbl$n_spouse_tptotinc_annual_na_int,
  "; APNSPOUSE imputed=", mfj_diag_tbl$n_apnspouse_imputed_int
)

# Optional sensitivity: drop imputed spouse pointers before joint-income use.
if (isTRUE(drop_imputed_spouse_pointers_flag)) {
  sipp_dec_with_spouse_tbl <- sipp_dec_with_spouse_tbl |>
    dplyr::mutate(
      spouse_tptotinc_annual_num = dplyr::if_else(
        is.na(APNSPOUSE) | APNSPOUSE == 0L,
        spouse_tptotinc_annual_num,
        NA_real_
      )
    )
  message("U1 sensitivity: imputed APNSPOUSE pointers blanked ",
          "(spouse_tptotinc_annual_num set NA).")
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
    #    tptotinc_annual_num is the Option-B observed-months annualization
    #    of TPTOTINC built in the person-year aggregation block above
    #    (sum of observed monthly values scaled to 12 months). For the
    #    typical all-12-months respondent this is the measured calendar-
    #    year total. spouse_tptotinc_annual_num is the corresponding value
    #    for the spouse, attached via the U1 self-join when
    #    filing_group_chr == "mfj". sm_lower / sm_upper in
    #    calibration_cells.R are ANNUAL AGI thresholds from IRC sec 6433
    #    (projected to 2027 via cpi_projection_factor_num), so no * 12
    #    scaling is applied here.
    #    MFJ fallback: when EPNSPOUSE is missing but EFSTATUS == 2, we use
    #    tptotinc_annual_num alone (single-filer proxy) so the row is not
    #    dropped from the count; this is recorded in the diagnostic above
    #    and tracked as plan Section 3 row 3e.
    #
    #    U2 hook: sm_gross_income_num is the annualized gross income (U1
    #    spouse-pair sum for MFJ; personal tptotinc_annual_num otherwise).
    #    sm_income_num then subtracts agi_above_line_adjust_num to produce
    #    the AGI value actually compared against sm_lower / sm_upper. The
    #    adjustment is 0 in the current scaffold (see U2 block above), so
    #    sm_income_num == sm_gross_income_num at present. Keep the two
    #    columns distinct so a future non-zero adjustment is visible.
    filing_group_chr = make_filing_group(EFSTATUS),
    sm_gross_income_num = dplyr::case_when(
      filing_group_chr == "mfj" & !is.na(spouse_tptotinc_annual_num) ~
        tptotinc_annual_num + spouse_tptotinc_annual_num,             # U1: spouse-pair joint annual income
      filing_group_chr == "mfj" & is.na(spouse_tptotinc_annual_num) ~
        tptotinc_annual_num,                                          # U1 fallback: MFJ w/ unresolved spouse pointer
      filing_group_chr %in% c("single_mfs", "hoh") ~ tptotinc_annual_num,
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

    # 3) Earned-income flag (Option-B observed-months-annualized personal
    #    earnings > 0). tpearn_annual_num is the sum of observed monthly
    #    TPEARN scaled to a 12-month basis (person-year aggregation block
    #    above). Any positive earnings during the year qualifies the
    #    respondent on the IRC sec 6433 earned-income requirement. This
    #    is a behavior change from the prior Dec x 12 test, which silently
    #    excluded anyone with zero December earnings (mid-year job leavers,
    #    retirees with earnings earlier in the year, new UI recipients).
    personal_annual_earnings_num = tpearn_annual_num,
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

    # 5) Main-employer retirement-plan access (distinct from ownership).
    #
    # EPENSNYN is the broad screen: whether the respondent's main employer or
    # business had any retirement plan for anyone in the company/organization.
    # EINCPENS asks whether the respondent was included in the offered plan(s).
    # For the worker-level "may not have an employer-provided retirement plan"
    # addition, code "No" when the employer had no plan at all OR when a plan
    # existed but the respondent was not included. We leave unresolved patterns
    # as "Missing" rather than infer from plan-type or ownership variables.
    main_employer_retirement_access_chr = dplyr::case_when(
      EINCPENS == 1 ~ "Yes",
      EPENSNYN == 2 | EINCPENS == 2 ~ "No",
      TRUE ~ "Missing"
    ),
    no_main_employer_retirement_access_flag =
      main_employer_retirement_access_chr == "No",

    # 6) Age bands for reporting
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
    bucket1_any_and_owns_flag = bucket1_any_match_flag & owns_qualifying_account_flag,
    # Additive employer-plan access outputs. These do not alter the bucket
    # definitions above; they only count eligible workers who may not have an
    # employer-provided retirement plan through their main employer or business.
    bucket1_any_no_main_employer_plan_flag =
      bucket1_any_match_flag & no_main_employer_retirement_access_flag,
    bucket2_full_no_main_employer_plan_flag =
      bucket2_full_match_flag & no_main_employer_retirement_access_flag
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
    bucket1_no_main_employer_plan_weighted_n = sum(
      WPFINWGT * bucket1_any_no_main_employer_plan_flag, na.rm = TRUE
    ),
    bucket2_no_main_employer_plan_weighted_n = sum(
      WPFINWGT * bucket2_full_no_main_employer_plan_flag, na.rm = TRUE
    ),
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
    bucket1_no_main_employer_plan_weighted_n = sum(
      WPFINWGT * bucket1_any_no_main_employer_plan_flag, na.rm = TRUE
    ),
    bucket2_no_main_employer_plan_weighted_n = sum(
      WPFINWGT * bucket2_full_no_main_employer_plan_flag, na.rm = TRUE
    ),
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
                bucket1_no_main_employer_plan_weighted_n,
                bucket2_no_main_employer_plan_weighted_n,
                universe_weighted_n)

# By age band
by_age_tbl <- sm_universe_tbl |>
  dplyr::group_by(age_band_chr) |>
  dplyr::summarise(
    bucket1_weighted_n = sum(WPFINWGT * bucket1_any_match_flag,     na.rm = TRUE),
    bucket2_weighted_n = sum(WPFINWGT * bucket2_full_match_flag,    na.rm = TRUE),
    bucket3_weighted_n = sum(WPFINWGT * bucket3_full_and_owns_flag, na.rm = TRUE),
    bucket1_any_and_owns_weighted_n = sum(WPFINWGT * bucket1_any_and_owns_flag, na.rm = TRUE),
    bucket1_no_main_employer_plan_weighted_n = sum(
      WPFINWGT * bucket1_any_no_main_employer_plan_flag, na.rm = TRUE
    ),
    bucket2_no_main_employer_plan_weighted_n = sum(
      WPFINWGT * bucket2_full_no_main_employer_plan_flag, na.rm = TRUE
    ),
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
                bucket1_no_main_employer_plan_weighted_n,
                bucket2_no_main_employer_plan_weighted_n,
                universe_weighted_n)

results_tbl <- dplyr::bind_rows(overall_tbl, by_filing_tbl, by_age_tbl) |>
  dplyr::mutate(
    bucket1_millions = round(bucket1_weighted_n / 1e6, 2),
    bucket2_millions = round(bucket2_weighted_n / 1e6, 2),
    bucket3_millions = round(bucket3_weighted_n / 1e6, 2),
    bucket1_any_and_owns_millions = round(bucket1_any_and_owns_weighted_n / 1e6, 2),
    bucket1_no_main_employer_plan_millions =
      round(bucket1_no_main_employer_plan_weighted_n / 1e6, 2),
    bucket2_no_main_employer_plan_millions =
      round(bucket2_no_main_employer_plan_weighted_n / 1e6, 2),
    universe_millions = round(universe_weighted_n / 1e6, 2)
  )

###################################################################################
###       U5: Filer-Basis Reaggregation for Tax-Return-Basis Comparison         ###
###################################################################################
# U5 (plan 2026-04-19 Section 4 / Section 8.6): the bucket counts computed above
# are on a worker (person) basis — each adult in a married couple contributes
# one observation. The primary external anchor (CPS ASEC 2025, Phase 4 below)
# is constructed on a tax-RETURN basis, where every MFJ couple contributes
# exactly ONE filer, not two. To make the SIPP number directly comparable,
# collapse each resolved MFJ spouse-pair to a single "primary-of-pair" record.
#
# Rule (disclosed per AS-3 undisclosed-assumptions check):
#   1. For filing_group_chr in {"single_mfs", "hoh"}: every person is their
#      own filer. Keep the row as-is.
#   2. For filing_group_chr == "mfj" with a resolved spouse pointer
#      (spouse_tptotinc_annual_num is not NA): form a symmetric couple key
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
# A correct couple-level full-match-with-account count would treat a couple
# as in-bucket if AT LEAST ONE spouse owns a qualifying account. The
# current U1 self-join brings over spouse TPTOTINC but not spouse account-
# ownership flags. So the filer-basis Bucket 3 here uses only the kept
# member's own account flag. This is a LOWER BOUND on the true couple-
# level Bucket 3 (couples where only the dropped member owned the account
# are missed). Closing this gap requires extending the U1 self-join to
# carry spouse EOWN_THR401 / EOWN_IRAKEO, which is a small 01/03g edit
# but is out of scope for the 2026-04-19
# pass. Documented in the memo output and flagged in the plan Section 4.

# Build the primary-of-pair mask
sm_universe_filer_tbl <- sm_universe_tbl |>
  dplyr::mutate(
    primary_of_pair_flag = dplyr::case_when(
      filing_group_chr %in% c("single_mfs", "hoh") ~ TRUE,
      filing_group_chr == "mfj" & is.na(spouse_tptotinc_annual_num) ~ TRUE,
      filing_group_chr == "mfj" &
        !is.na(spouse_tptotinc_annual_num) &
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
                  is.na(spouse_tptotinc_annual_num)) |>
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

# Historical reference only (NOT used as a baseline anchor):
#   EBRI Copeland (2024) Issue Brief No. 602 reports a filer-basis Saver's
#   Match eligible population of 83.8M (any-match), 69.0M (full-match), and
#   21.9M (full-match-with-account), built from IRS SOI 2018 tax return
#   microdata. We do not anchor against these numbers because (a) the SOI
#   2018 vintage predates the SECURE 2.0 statutory thresholds by five years
#   with no inflation adjustment applied, and (b) the underlying filer
#   population has shifted materially over that interval. The 2024
#   Morningstar SCF estimate of ~27M eligible households is a different
#   unit and also not comparable. The CPS ASEC 2025 cross-check (Phase 4
#   below) is the primary external anchor for this pipeline.
ebri_historical_any_match_millions_num     <- 83.8
ebri_historical_full_match_millions_num    <- 69.0
ebri_historical_full_and_owns_millions_num <- 21.9

# SIPP filer-basis summary. CPS-comparison columns are populated after the
# Phase 4 CPS ASEC 2025 block runs; before that, cps_*_millions are NA.
sipp_filer_overall_tbl <- overall_filer_tbl |>
  dplyr::transmute(
    group_chr,
    subgroup_chr,
    bucket1_millions              = round(bucket1_weighted_n / 1e6, 2),
    bucket2_millions              = round(bucket2_weighted_n / 1e6, 2),
    bucket3_millions              = round(bucket3_weighted_n / 1e6, 2),
    # B1 intersect ownership: reported in millions only; CPS ADJGINC has
    # no parallel quantity because the ASEC core file does not carry
    # retirement-account ownership flags.
    bucket1_any_and_owns_millions = round(bucket1_any_and_owns_weighted_n / 1e6, 2)
  )

# Top-level CPS scalars. Populated by Phase 4 below; remain NA if the
# Phase 4 block is gated off or otherwise skipped. Worker-basis is the
# primary comparison unit; filer-basis is kept as a secondary reference.
cps_b1_workers_millions_num <- NA_real_
cps_b2_workers_millions_num <- NA_real_
cps_b1_filers_millions_num  <- NA_real_
cps_b2_filers_millions_num  <- NA_real_

message(
  "U5 filer-basis overall (millions, SIPP, pre-CPS comparison):",
  " B1=", sipp_filer_overall_tbl$bucket1_millions,
  "; B2=", sipp_filer_overall_tbl$bucket2_millions,
  "; B3=", sipp_filer_overall_tbl$bucket3_millions,
  "; B1 \u2229 account=", sipp_filer_overall_tbl$bucket1_any_and_owns_millions
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

# External anchor: CPS ASEC 2025 (income year 2024). Phase 4 below
# produces the comparable filer-basis CPS counts on the same SECURE 2.0
# bucket rules. EBRI Copeland 2024 and Morningstar SCF 2022 are
# documented as historical references in the constants block above; we
# do not baseline against them.
message("Primary external anchor: CPS ASEC 2025 (Phase 4 below).")

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

  # Variables needed to apply the Saver's Match bucket rules on CPS ASEC.
  # INCBUS and INCFARM are needed for the IRC sec 32 / sec 6433 earned-
  # income concept (wages plus self-employment business plus self-
  # employment farm). Adding these two requires re-pulling the IPUMS
  # extract; an extract built without them will fail at the filter step
  # because the variables will be absent from the DDI.
  cps_vars_chr <- c(
    "YEAR", "MONTH", "SERIAL", "PERNUM",
    "SPLOC", "RELATE",
    "AGE", "SEX", "MARST",
    "FILESTAT", "DEPSTAT", "SCHLCOLL",
    "INCTOT", "ADJGINC", "INCWAGE", "INCBUS", "INCFARM",
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

  # CPS U1 (parallel to the SIPP U1 spouse self-join): for MFJ persons,
  # the IRC sec 6433 income test is on JOINT AGI, not own AGI. ADJGINC in
  # CPS ASEC is per-person, so testing each MFJ spouse's own ADJGINC
  # against the MFJ threshold is wrong (and inflates the bucket counts
  # because per-person ADJGINC is by construction <= joint ADJGINC, so
  # more MFJ persons clear the threshold individually than would clear it
  # jointly). Build a person-level lookup keyed on (SERIAL, PERNUM),
  # then left-join onto cps_raw_tbl by (SERIAL, SPLOC = PERNUM) so each
  # row gains the spouse's ADJGINC. SPLOC is the within-household pointer
  # to the spouse's PERNUM; it is 0 (or NA) when the person has no
  # in-household spouse.
  cps_spouse_lookup_tbl <- cps_raw_tbl |>
    dplyr::transmute(
      SERIAL,
      spouse_pernum_int  = PERNUM,
      spouse_adjginc_num = ADJGINC
    )

  cps_with_spouse_tbl <- cps_raw_tbl |>
    dplyr::left_join(
      cps_spouse_lookup_tbl,
      by = c("SERIAL" = "SERIAL", "SPLOC" = "spouse_pernum_int"),
      relationship = "many-to-one"
    )

  # Diagnostic: how many CPS MFJ rows have an unresolved SPLOC pointer?
  # Mirrors the SIPP U1 MFJ diagnostic. Filer-basis MFJ rows with
  # unresolved pointers fall back to own ADJGINC (single-filer proxy on
  # the joint test), which is conservative.
  cps_u1_diag_tbl <- cps_with_spouse_tbl |>
    dplyr::filter(FILESTAT == 1L) |>
    dplyr::summarise(
      n_mfj_rows_int               = dplyr::n(),
      n_sploc_zero_int             = sum(is.na(SPLOC) | SPLOC == 0L),
      n_spouse_adjginc_unresolved  = sum(is.na(spouse_adjginc_num))
    )
  message(
    "CPS U1 MFJ spouse-join diagnostics:",
    " rows=", cps_u1_diag_tbl$n_mfj_rows_int,
    "; SPLOC missing or zero=", cps_u1_diag_tbl$n_sploc_zero_int,
    "; spouse ADJGINC unresolved=", cps_u1_diag_tbl$n_spouse_adjginc_unresolved
  )

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

  cps_universe_tbl <- cps_with_spouse_tbl |>
    dplyr::filter(
      AGE >= 18L,
      DEPSTAT == 0L,
      !(SCHLCOLL %in% c(1L, 3L)),
      FILESTAT %in% c(1L, 2L, 3L, 4L, 5L),
      # IRC sec 32 / sec 6433 earned-income concept: wages plus self-
      # employment income (business or farm). Replaces the prior loose
      # `INCWAGE > 0 | INCTOT > 0` test, which let pension- and Social-
      # Security-only retirees clear the universe filter even though they
      # have no earned income and are not Saver's Match eligible. Applied
      # per-person, which makes this the de facto MFJ own-earnings rule on
      # CPS: each MFJ spouse must individually have earned income to enter
      # the universe, mirroring the SIPP `has_earned_income_flag` filter.
      INCWAGE > 0L | INCBUS > 0L | INCFARM > 0L
    ) |>
    dplyr::mutate(
      filing_group_chr = dplyr::case_when(
        FILESTAT == 1L ~ "mfj",
        FILESTAT == 3L ~ "hoh",
        FILESTAT %in% c(2L, 4L, 5L) ~ "single_mfs",
        TRUE ~ NA_character_
      ),
      # ADJGINC is an AGI-concept variable from IPUMS, recorded per
      # person. For MFJ filers, the Saver's Match income test is on
      # JOINT AGI (sum of both spouses' contributions), so we add the
      # spouse_adjginc_num pulled in via the CPS U1 self-join above.
      # For MFJ rows with unresolved SPLOC, fall back to own ADJGINC --
      # conservative because joint income would be at least as large.
      # For non-MFJ persons (single, MFS, HoH), use own ADJGINC.
      sm_income_cps_num = dplyr::case_when(
        filing_group_chr == "mfj" & !is.na(spouse_adjginc_num) ~
          ADJGINC + spouse_adjginc_num,
        filing_group_chr == "mfj" & is.na(spouse_adjginc_num) ~
          ADJGINC,                                              # MFJ unresolved-SPLOC fallback
        filing_group_chr %in% c("single_mfs", "hoh") ~ ADJGINC,
        TRUE ~ NA_real_
      ),
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

  # Diagnostic: median sm_income_cps_num by filing_group, plus weighted
  # bucket-1 counts split MFJ vs. non-MFJ. If the U1 spouse-join is
  # populating joint income for MFJ, the MFJ median should land near the
  # MFJ joint-income population median (~$80,000-$100,000), not near the
  # MFJ individual income median (~$40,000-$50,000).
  cps_phase4_diag_tbl <- cps_universe_tbl |>
    dplyr::group_by(filing_group_chr) |>
    dplyr::summarise(
      n_rows                         = dplyr::n(),
      median_sm_income_cps_num       = stats::median(sm_income_cps_num, na.rm = TRUE),
      median_own_adjginc             = stats::median(ADJGINC, na.rm = TRUE),
      n_with_spouse_resolved         = sum(!is.na(spouse_adjginc_num)),
      weighted_b1_millions           = round(
        sum(ASECWT * bucket1_any_match_flag, na.rm = TRUE) / 1e6, 3),
      weighted_b2_millions           = round(
        sum(ASECWT * bucket2_full_match_flag, na.rm = TRUE) / 1e6, 3),
      .groups = "drop"
    )
  message("CPS Phase 4 sanity diagnostic by filing group:")
  for (i in seq_len(nrow(cps_phase4_diag_tbl))) {
    message(sprintf(
      "  fg=%s  n=%d  median(sm_income)=%d  median(own ADJGINC)=%d  spouse-resolved=%d  B1=%.3fM  B2=%.3fM",
      cps_phase4_diag_tbl$filing_group_chr[i],
      cps_phase4_diag_tbl$n_rows[i],
      as.integer(cps_phase4_diag_tbl$median_sm_income_cps_num[i]),
      as.integer(cps_phase4_diag_tbl$median_own_adjginc[i]),
      cps_phase4_diag_tbl$n_with_spouse_resolved[i],
      cps_phase4_diag_tbl$weighted_b1_millions[i],
      cps_phase4_diag_tbl$weighted_b2_millions[i]
    ))
  }

  # Worker-basis CPS counts (PRIMARY). Each adult in an MFJ couple is
  # counted separately, mirroring the SIPP worker-level overall_tbl.
  # No primary-of-pair collapse is applied; we sum bucket flags directly
  # over cps_universe_tbl (the post-universe-filter person-level frame).
  cps_universe_counts_tbl <- cps_universe_tbl |>
    dplyr::summarise(
      cps_b1_workers_millions = round(
        sum(ASECWT * bucket1_any_match_flag,  na.rm = TRUE) / 1e6, 2),
      cps_b2_workers_millions = round(
        sum(ASECWT * bucket2_full_match_flag, na.rm = TRUE) / 1e6, 2)
    )

  # Filer-basis CPS counts (SECONDARY, kept for reference). Each MFJ couple
  # is collapsed to one filer via SPLOC: keep the member with PERNUM < SPLOC
  # within the same SERIAL household. Mirrors the SIPP U5 filer collapse.
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
      cps_b1_filers_millions = round(
        sum(ASECWT * bucket1_any_match_flag,  na.rm = TRUE) / 1e6, 2),
      cps_b2_filers_millions = round(
        sum(ASECWT * bucket2_full_match_flag, na.rm = TRUE) / 1e6, 2)
    )

  # Diagnostic on filer-basis post-collapse: median sm_income_cps_num and
  # weighted bucket counts by filing group, parallel to the universe-level
  # diagnostic above. If the joint-income fix is reaching the filer table,
  # the MFJ median here should also be the joint-income median.
  cps_filer_diag_tbl <- cps_filer_tbl |>
    dplyr::group_by(filing_group_chr) |>
    dplyr::summarise(
      n_rows                   = dplyr::n(),
      median_sm_income_cps_num = stats::median(sm_income_cps_num, na.rm = TRUE),
      weighted_b1_millions     = round(
        sum(ASECWT * bucket1_any_match_flag, na.rm = TRUE) / 1e6, 3),
      weighted_b2_millions     = round(
        sum(ASECWT * bucket2_full_match_flag, na.rm = TRUE) / 1e6, 3),
      .groups = "drop"
    )
  message("CPS Phase 4 filer-basis diagnostic by filing group:")
  for (i in seq_len(nrow(cps_filer_diag_tbl))) {
    message(sprintf(
      "  fg=%s  n=%d  median(sm_income)=%d  B1=%.3fM  B2=%.3fM",
      cps_filer_diag_tbl$filing_group_chr[i],
      cps_filer_diag_tbl$n_rows[i],
      as.integer(cps_filer_diag_tbl$median_sm_income_cps_num[i]),
      cps_filer_diag_tbl$weighted_b1_millions[i],
      cps_filer_diag_tbl$weighted_b2_millions[i]
    ))
  }

  # Surface CPS scalars at top-level scope so the post-Phase-4 ratio
  # tables and the memo can read them whether or not Phase 4 is gated on.
  # Worker-basis is primary; filer-basis is kept for reference.
  cps_b1_workers_millions_num <- cps_universe_counts_tbl$cps_b1_workers_millions
  cps_b2_workers_millions_num <- cps_universe_counts_tbl$cps_b2_workers_millions
  cps_b1_filers_millions_num  <- cps_filer_counts_tbl$cps_b1_filers_millions
  cps_b2_filers_millions_num  <- cps_filer_counts_tbl$cps_b2_filers_millions

  # Validation table carrying both worker-basis (primary) and filer-basis
  # (secondary) comparisons. Income-year mismatch noted in scope_chr:
  # SIPP 2024 Wave 1 covers reference year 2023; CPS ASEC 2025 covers
  # income year 2024. The SIPP figure will lift when SIPP 2025 Wave 2
  # releases.
  savers_match_cps_vs_sipp_tbl <- tibble::tibble(
    scope_chr        = paste0(
      "Overall. SIPP reference year 2023 (Wave 1); ",
      "CPS ASEC 2025 income year 2024."
    ),
    # Worker basis (primary)
    sipp_b1_workers_millions = round(overall_tbl$bucket1_weighted_n / 1e6, 2),
    sipp_b2_workers_millions = round(overall_tbl$bucket2_weighted_n / 1e6, 2),
    cps_b1_workers_millions  = cps_b1_workers_millions_num,
    cps_b2_workers_millions  = cps_b2_workers_millions_num,
    sipp_pct_of_cps_workers_b1 = round(
      100 * (overall_tbl$bucket1_weighted_n / 1e6) /
        cps_b1_workers_millions_num, 1),
    sipp_pct_of_cps_workers_b2 = round(
      100 * (overall_tbl$bucket2_weighted_n / 1e6) /
        cps_b2_workers_millions_num, 1),
    # Filer basis (secondary)
    sipp_b1_filers_millions = sipp_filer_overall_tbl$bucket1_millions,
    sipp_b2_filers_millions = sipp_filer_overall_tbl$bucket2_millions,
    cps_b1_filers_millions  = cps_b1_filers_millions_num,
    cps_b2_filers_millions  = cps_b2_filers_millions_num,
    sipp_pct_of_cps_filers_b1 = round(
      100 * sipp_filer_overall_tbl$bucket1_millions /
        cps_b1_filers_millions_num, 1),
    sipp_pct_of_cps_filers_b2 = round(
      100 * sipp_filer_overall_tbl$bucket2_millions /
        cps_b2_filers_millions_num, 1)
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
    "Phase 4 CPS validation complete. Worker-basis counts (PRIMARY):",
    " SIPP B1=", round(overall_tbl$bucket1_weighted_n / 1e6, 2),
    "M; CPS B1=", cps_b1_workers_millions_num,
    "M (SIPP is ", savers_match_cps_vs_sipp_tbl$sipp_pct_of_cps_workers_b1,
    "% of CPS).",
    " SIPP B2=", round(overall_tbl$bucket2_weighted_n / 1e6, 2),
    "M; CPS B2=", cps_b2_workers_millions_num,
    "M (SIPP is ", savers_match_cps_vs_sipp_tbl$sipp_pct_of_cps_workers_b2,
    "% of CPS)."
  )
  message(
    "Filer-basis counts (secondary):",
    " SIPP B1=", sipp_filer_overall_tbl$bucket1_millions,
    "M; CPS B1=", cps_b1_filers_millions_num,
    "M (SIPP is ", savers_match_cps_vs_sipp_tbl$sipp_pct_of_cps_filers_b1,
    "% of CPS).",
    " SIPP B2=", sipp_filer_overall_tbl$bucket2_millions,
    "M; CPS B2=", cps_b2_filers_millions_num,
    "M (SIPP is ", savers_match_cps_vs_sipp_tbl$sipp_pct_of_cps_filers_b2,
    "% of CPS)."
  )

} else {

  message("Phase 4 CPS validation skipped (run_cps_validation_flag is FALSE). ",
          "CPS-based ratio columns will be NA in the comparison tables.")

}

###################################################################################
###          CPS-Anchored Comparison Tables (post Phase 4)                      ###
###################################################################################
# Built after Phase 4 so cps_b*_millions_num scalars are populated. Two
# tables: worker basis (PRIMARY) and filer basis (SECONDARY). Columns are
# NA when Phase 4 is gated off; downstream consumers (memo, validation)
# handle NAs.

# Worker basis (PRIMARY): each adult counted separately on both sides.
# This is the public-communication unit. Built off overall_tbl, which is
# the worker-level SIPP summary, paired against the worker-basis CPS
# counts surfaced from the cps_universe_tbl summary in Phase 4.
cps_ratio_workers_tbl <- tibble::tibble(
  group_chr                     = "Overall (worker basis)",
  subgroup_chr                  = "All",
  bucket1_millions              = round(overall_tbl$bucket1_weighted_n / 1e6, 2),
  bucket2_millions              = round(overall_tbl$bucket2_weighted_n / 1e6, 2),
  bucket3_millions              = round(overall_tbl$bucket3_weighted_n / 1e6, 2),
  bucket1_any_and_owns_millions = round(
    overall_tbl$bucket1_any_and_owns_weighted_n / 1e6, 2),
  cps_bucket1_millions          = cps_b1_workers_millions_num,
  cps_bucket2_millions          = cps_b2_workers_millions_num,
  bucket1_pct_of_cps            = dplyr::if_else(
    is.na(cps_b1_workers_millions_num) | cps_b1_workers_millions_num == 0,
    NA_real_,
    round(100 * (overall_tbl$bucket1_weighted_n / 1e6) /
            cps_b1_workers_millions_num, 1)
  ),
  bucket2_pct_of_cps            = dplyr::if_else(
    is.na(cps_b2_workers_millions_num) | cps_b2_workers_millions_num == 0,
    NA_real_,
    round(100 * (overall_tbl$bucket2_weighted_n / 1e6) /
            cps_b2_workers_millions_num, 1)
  )
)

# Filer basis (SECONDARY): MFJ couples collapsed to one filer per couple
# on both sides via SIPP U5 (EPNSPOUSE) and CPS Phase 4 (SPLOC). Kept for
# reference and for downstream consumers that need a tax-return-basis
# comparison. The primary public framing is worker basis; this table is
# the supporting sidebar.
cps_ratio_filers_tbl <- sipp_filer_overall_tbl |>
  dplyr::mutate(
    cps_bucket1_millions = cps_b1_filers_millions_num,
    cps_bucket2_millions = cps_b2_filers_millions_num,
    bucket1_pct_of_cps   = dplyr::if_else(
      is.na(cps_b1_filers_millions_num) | cps_b1_filers_millions_num == 0,
      NA_real_,
      round(100 * bucket1_millions / cps_b1_filers_millions_num, 1)
    ),
    bucket2_pct_of_cps   = dplyr::if_else(
      is.na(cps_b2_filers_millions_num) | cps_b2_filers_millions_num == 0,
      NA_real_,
      round(100 * bucket2_millions / cps_b2_filers_millions_num, 1)
    )
  )

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
  cps_ratio_workers_tbl,
  file.path(path_output_tables, "savers_match_workers_vs_cps.rds")
)
arrow::write_parquet(
  cps_ratio_workers_tbl,
  file.path(path_output_tables, "savers_match_workers_vs_cps.parquet"),
  compression = "snappy"
)
saveRDS(
  cps_ratio_filers_tbl,
  file.path(path_output_tables, "savers_match_filers_vs_cps.rds")
)
arrow::write_parquet(
  cps_ratio_filers_tbl,
  file.path(path_output_tables, "savers_match_filers_vs_cps.parquet"),
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
        file.path(path_output_tables, "savers_match_workers_vs_cps.rds"))
message("Saved: ",
        file.path(path_output_tables, "savers_match_workers_vs_cps.parquet"))
message("Saved: ",
        file.path(path_output_tables, "savers_match_filers_vs_cps.rds"))
message("Saved: ",
        file.path(path_output_tables, "savers_match_filers_vs_cps.parquet"))

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
  paste0("- Any-match eligible AND may not have an employer-provided retirement plan through their main employer/business: ",
         round(overall_tbl$bucket1_no_main_employer_plan_weighted_n / 1e6, 1),
         " million workers."),
  paste0("- Full-match eligible AND may not have an employer-provided retirement plan through their main employer/business: ",
         round(overall_tbl$bucket2_no_main_employer_plan_weighted_n / 1e6, 1),
         " million workers."),
  paste0("- Phaseout-range eligible AND may not have an employer-provided retirement plan through their main employer/business: ",
         round(
           (overall_tbl$bucket1_no_main_employer_plan_weighted_n -
              overall_tbl$bucket2_no_main_employer_plan_weighted_n) / 1e6,
           1
         ),
         " million workers."),
  "",
  "Employer-plan-access note: this addition is distinct from the ownership-based qualifying-account measure above. It uses EPENSNYN (whether the main employer/business had any retirement plan) together with EINCPENS (whether the worker was included in the offered plan(s)). Workers are counted in the no-plan group when the employer had no plan at all or when a plan existed but the worker was not included.",
  "",
  "## Worker-basis comparison to CPS ASEC 2025 (PRIMARY)",
  "",
  "The headline counts above are reported on a worker basis: each adult in a married couple is counted separately. CPS ASEC 2025 (income year 2024) is the primary external anchor and is constructed on the same worker basis here so the comparison is unit-consistent. SIPP 2024 Wave 1 covers reference year 2023, so the SIPP figure understates the 2024-on-2024 comparison by one income year of nominal growth — this caveat drops when SIPP 2025 Wave 2 releases.",
  "",
  paste0("- Bucket 1 (any-match, worker basis): ",
         cps_ratio_workers_tbl$bucket1_millions,
         " million SIPP workers vs. ",
         ifelse(is.na(cps_ratio_workers_tbl$cps_bucket1_millions),
                "CPS not run",
                paste0(cps_ratio_workers_tbl$cps_bucket1_millions, " million CPS workers")),
         ifelse(is.na(cps_ratio_workers_tbl$bucket1_pct_of_cps),
                ".",
                paste0(" (SIPP is ",
                       cps_ratio_workers_tbl$bucket1_pct_of_cps,
                       " percent of CPS)."))),
  paste0("- Bucket 2 (full-match, worker basis): ",
         cps_ratio_workers_tbl$bucket2_millions,
         " million SIPP workers vs. ",
         ifelse(is.na(cps_ratio_workers_tbl$cps_bucket2_millions),
                "CPS not run",
                paste0(cps_ratio_workers_tbl$cps_bucket2_millions, " million CPS workers")),
         ifelse(is.na(cps_ratio_workers_tbl$bucket2_pct_of_cps),
                ".",
                paste0(" (SIPP is ",
                       cps_ratio_workers_tbl$bucket2_pct_of_cps,
                       " percent of CPS)."))),
  paste0("- Bucket 3 (full-match + owns, worker basis): ",
         cps_ratio_workers_tbl$bucket3_millions,
         " million SIPP workers. CPS ASEC core does not carry retirement-account ownership flags, so there is no CPS anchor for this quantity."),
  paste0("- Any-match eligible AND owns qualifying account (worker basis): ",
         cps_ratio_workers_tbl$bucket1_any_and_owns_millions,
         " million SIPP workers. CPS has no parallel quantity."),
  "",
  "## Filer-basis comparison to CPS ASEC 2025 (secondary)",
  "",
  "The filer-basis comparison collapses each resolved MFJ couple to its lower-PNUM member (SIPP) or lower-PERNUM member (CPS) so each tax-filing unit contributes one observation. The IRS administers the Saver's Match per filer, so filer-basis numbers are the right unit for fiscal-cost discussions. For population-eligibility communication the worker-basis numbers above are primary.",
  "",
  paste0("- Bucket 1 (any-match, filer basis): ",
         cps_ratio_filers_tbl$bucket1_millions,
         " million SIPP filers vs. ",
         ifelse(is.na(cps_ratio_filers_tbl$cps_bucket1_millions),
                "CPS not run",
                paste0(cps_ratio_filers_tbl$cps_bucket1_millions, " million CPS filers")),
         ifelse(is.na(cps_ratio_filers_tbl$bucket1_pct_of_cps),
                ".",
                paste0(" (SIPP is ",
                       cps_ratio_filers_tbl$bucket1_pct_of_cps,
                       " percent of CPS)."))),
  paste0("- Bucket 2 (full-match, filer basis): ",
         cps_ratio_filers_tbl$bucket2_millions,
         " million SIPP filers vs. ",
         ifelse(is.na(cps_ratio_filers_tbl$cps_bucket2_millions),
                "CPS not run",
                paste0(cps_ratio_filers_tbl$cps_bucket2_millions, " million CPS filers")),
         ifelse(is.na(cps_ratio_filers_tbl$bucket2_pct_of_cps),
                ".",
                paste0(" (SIPP is ",
                       cps_ratio_filers_tbl$bucket2_pct_of_cps,
                       " percent of CPS)."))),
  paste0("- Bucket 3 (full-match + owns, filer basis): ",
         cps_ratio_filers_tbl$bucket3_millions,
         " million SIPP filers. CPS has no parallel quantity. Note: lower bound — couples where only the dropped member owns the account are missed (see U5 caveat)."),
  "",
  "## Methodology notes",
  "",
  "- Income concept: calendar-year personal income built by summing observed monthly TPTOTINC across all twelve MONTHCODE rows per person (sum scaled to 12 months via sum * 12 / n_valid_months for the small share of partial-year respondents). This replaces the prior December-times-twelve proxy. See the Income period entry under Open items below for the partial-year share from this run.",
  "- Above-the-line adjustments to AGI (IRC sec 62: IRA deduction, HSA, student-loan interest, etc.) are not yet applied to the SIPP gross-income proxy. SIPP bucket counts are therefore lower bounds on true AGI-defined eligibility.",
  "- Historical references not used as anchors: EBRI Copeland (2024, Issue Brief No. 602, IRS SOI 2018 filers, no inflation adjustment) and Morningstar (January 2025, SCF 2022 households). Both are noted for context only.",
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
  paste0("- Income period: SIPP TPTOTINC, TFTOTINC, and TPEARN are monthly reference-month values. ",
         "Calendar-year values are built by aggregating across all observed MONTHCODE rows per person ",
         "(sum scaled to 12 months via sum * 12 / n_valid_months; Option B). ",
         "Retirement-module attributes remain on the December reference-month record. ",
         "Partial-year (< 12 months observed) share from run: ",
         sprintf("%.2f%%", 100 * n_partial_year_int / n_persons_year_int), ".")
)

writeLines(
  memo_lines_chr,
  file.path(path_output_reports, "savers_match_eligibility_buckets.md")
)
message("Saved: ",
        file.path(path_output_reports, "savers_match_eligibility_buckets.md"))
