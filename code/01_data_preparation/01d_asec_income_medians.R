# 01d_asec_income_medians.R -- ASEC median-income grid and the DESIGNATED ENDPOINT.
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - What are the median personal income (INCTOT) and median wage and salary income
#                     (INCWAGE) of all persons and of single filers, with and without restricting to
#                     positive values -- and which of those sets the designated endpoint?
#
# DESCRIPTION:
# Reads the IPUMS CPS ASEC extract from 01c and produces a 2 x 2 x 2 grid:
#   income concept  {INCTOT personal income, INCWAGE wage and salary}
#   x population    {all persons, single filers}
#   x positivity    {all in-universe values, positive values only}
# plus supporting cuts. Selects one cell as the DESIGNATED ENDPOINT -- the single
# policy dial in the respecified match schedule -- and writes it for stage 04.
#
# THE POLICY, IN FULL: a 200 percent match at $0 income, declining in a straight
# line to a 0 percent match at the designated endpoint. Two numbers. The endpoint
# is the only quantity being chosen here.
#
# THE DESIGNATED ENDPOINT (settled 2026-08-04): the median total personal income
# (INCTOT) of single filers age 15+, ALL VALUES, from the most recent CPS ASEC.
#
# WHY THIS CELL. The schedule scores filers on total income, so the endpoint must
# be a total-income statistic for the policy statement to be literally true. It is:
# the median single filer's income equals the endpoint by construction, so that
# filer sits exactly at the 0 percent point. A wage-based endpoint would sit BELOW
# the total-income median and push the median filer outside the band while the
# headline still said "at the median". "All values" rather than positive-only
# because it needs no qualifier to state, and for single filers the two differ by
# $38 (19 records carry negative INCTOT; none carry zero).
#
# ---------------------------------------------------------------------------
# TWO FINDINGS THAT CHANGE HOW THESE NUMBERS MUST BE READ
# ---------------------------------------------------------------------------
#
# (1) FILESTAT CANNOT IDENTIFY MARRIED-FILING-SEPARATELY.
#     Codes are 1/2/3 Joint (split by age), 4 Head of household, 5 Single,
#     6 Nonfiler. There is no MFS category, in either IPUMS FILESTAT or the
#     underlying Census tax-model variable, because the Census tax model assigns
#     married couples to joint filing. The requested "single and MFS filers" cut
#     is therefore reported as SINGLE FILERS ONLY, and every label says so. MFS is
#     roughly 2-3 percent of returns nationally, so the omission is small but it is
#     real and it is not correctable from this source. MARST is carried in the
#     extract so an MFS proxy could be constructed, but a marital-status proxy is
#     a modelling choice, not a measurement, so none is used in a headline here.
#
# (2) THE DOCUMENTED ASEC 2019 INCWAGE UNIVERSE BREAK DOES NOT BIND IN THE
#     DELIVERED DATA -- VERIFIED, NOT ASSUMED. The IPUMS universe note says the
#     INCWAGE universe narrowed from "persons age 15+" (through ASEC 2018) to
#     "persons age 15+ with earnings last year" (ASEC 2019 onward), which would
#     imply non-earners arrive as NIU sentinels and drop out as NA -- making the
#     "all values" median an earners-only median that nearly equals the
#     positive-only one.
#
#     Measured on ASEC 2025 (2026-08-04), that is NOT what happens. ZERO records
#     age 15+ carry the INCWAGE NIU code; 45,877 non-earners carry INCWAGE == 0.
#     The `n_out_of_universe_int` column is 0 in every cell. The delivered data
#     therefore still behaves like an age-15+ universe with explicit zeros, and the
#     two cells differ enormously: $20,000 (all values) versus $50,002 (positive
#     only) for all persons age 15+.
#
#     KEEP THE CHECK RATHER THAN DELETING IT. The universe note is real
#     documentation, so a future vintage could start emitting NIU sentinels. The
#     `n_out_of_universe_int` column is what would reveal it; a non-zero value in
#     that column on any future run means this comment must be revisited before the
#     "all values" medians are used or quoted.
#
#     INCTOT is unaffected either way: universe is all persons age 15+, and its
#     "all values" cells genuinely include zeros and negatives.
#
#     Source for the documented note: IPUMS INCWAGE universe description,
#     cross-checked against Household-income-and-composition
#     Infrastructure/references/literature/data_dictionaries/2026_ipums_cps_incwage_dictionary.md.
#     Source for the empirical finding: this script's own output,
#     data/processed/asec_income_medians.csv.
#
# ---------------------------------------------------------------------------
# STATED IMPLICIT CHOICES (decisions, not defaults)
# ---------------------------------------------------------------------------
#   a. RESERVED CODES ARE CLEARED BEFORE ANY STATISTIC. INCTOT 999999999 (NIU) and
#      999999998 (missing); INCWAGE 99999999 (NIU) and 99999998 (missing). Failing
#      to clear these would put nine-digit sentinels in the distribution and drag
#      every mean and upper quantile catastrophically.
#   b. INCTOT NEGATIVES ARE KEPT in the "all values" cells. Personal income can be
#      genuinely negative (business and farm losses). Dropping them would be a
#      substantive edit, not cleaning. They are necessarily excluded from the
#      positive-only cells.
#   c. AGE FLOOR IS 15, matching the INCTOT universe, so the "all persons" rows
#      describe the income-eligible population rather than including children who
#      are structurally out of universe. An 18-64 variant is also reported, since
#      the Saver's Match universe is age 18+.
#   d. ASECWT IS THE WEIGHT, not WTFINL. WTFINL is the basic monthly weight and
#      ignores the ASEC oversample; using it for an income statistic is a known
#      error class.
#   e. NO TOPCODE ADJUSTMENT. Topcoding compresses the upper tail and cannot move a
#      median. Recorded so the omission is not mistaken for an oversight.
#   f. SINGLE-YEAR CROSS-SECTION, so no inflation adjustment is applied or needed.
#      Values are nominal dollars of the ASEC income year.
#
# Inputs:  data/raw/ipums_cps_asec/ipums_cps_asec_person_level.csv.gz
#          data/raw/ipums_cps_asec/ipums_cps_asec_extract_metadata.json
# Outputs: data/processed/asec_endpoint.rds
#          data/processed/asec_income_medians.csv
#          output/reports/asec_endpoint_diagnostics.md

rm(list = ls())
options(scipen = 999)
set.seed(42L)

suppressMessages({
  library(dplyr); library(readr); library(jsonlite); library(Hmisc)
})

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()),
                 "code", "00_setup", "00_config.R"))
source(file.path(path_code, "_shared", "weighted_stats.R"))

message("Starting 01d_asec_income_medians.R")

###################################################################################
###                    1) Locate inputs and assert the vintage contract         ###
###################################################################################
path_ipums_dir_chr <- file.path(path_data_raw, "ipums_cps_asec")
extract_csv_chr      <- file.path(path_ipums_dir_chr, "ipums_cps_asec_person_level.csv.gz")
extract_metadata_chr <- file.path(path_ipums_dir_chr, "ipums_cps_asec_extract_metadata.json")

if (!file.exists(extract_csv_chr)) {
  stop("IPUMS ASEC extract not found at: ", extract_csv_chr, "\n",
       "Run code/01_data_preparation/01c_pull_ipums_asec.R first.", call. = FALSE)
}

# Reference year of the SIPP file stage 01 reads. The 2025 SIPP covers reference
# period January-December 2024. Update this alongside any SIPP vintage change.
sipp_reference_year_int <- 2024L

metadata_lst <- tryCatch(
  jsonlite::read_json(extract_metadata_chr, simplifyVector = TRUE),
  error = function(e) NULL
)

if (is.null(metadata_lst)) {
  stop("Extract metadata is missing or unreadable at: ", extract_metadata_chr,
       ". The ASEC vintage cannot be verified, so the nominal-on-nominal contract ",
       "(decision S3) cannot be enforced. Delete the cached extract and rerun 01c.",
       call. = FALSE)
}

asec_survey_year_int <- as.integer(metadata_lst$asec_survey_year)
asec_income_year_int <- as.integer(metadata_lst$asec_income_year)

if (is.na(asec_income_year_int) || asec_income_year_int != sipp_reference_year_int) {
  stop(sprintf(
    "VINTAGE CONTRACT VIOLATION. ASEC income year is %s but the SIPP reference year is %d.\nEligibility is scored nominal-on-nominal (decision S3), so these must match.\nEither pin asec_sample_year_int = %dL in 01c, or update sipp_reference_year_int here to match the SIPP file actually in use.",
    as.character(asec_income_year_int), sipp_reference_year_int,
    sipp_reference_year_int + 1L
  ), call. = FALSE)
}

message(sprintf("Vintage contract satisfied: ASEC %d (income year %d) = SIPP reference year %d.",
                asec_survey_year_int, asec_income_year_int, sipp_reference_year_int))

###################################################################################
###                    2) Read and clean                                        ###
###################################################################################
asec_raw_tbl <- readr::read_csv(extract_csv_chr, show_col_types = FALSE,
                                progress = FALSE)
names(asec_raw_tbl) <- toupper(names(asec_raw_tbl))

required_chr <- c("ASECWT", "AGE", "INCTOT", "INCWAGE", "FILESTAT")
missing_chr  <- setdiff(required_chr, names(asec_raw_tbl))
if (length(missing_chr) > 0L) {
  stop("Extract is missing required column(s): ", paste(missing_chr, collapse = ", "),
       ".", call. = FALSE)
}

message(sprintf("Read %d person records.", nrow(asec_raw_tbl)))

# Reserved-code clearing (implicit choice a). Guard rather than assume: if a future
# vintage changes the sentinels, the assertion below catches it.
INCTOT_NIU  <- 999999999
INCTOT_MISS <- 999999998
INCWAGE_NIU  <- 99999999
INCWAGE_MISS <- 99999998

asec_tbl <- asec_raw_tbl |>
  dplyr::transmute(
    weight_num   = as.numeric(ASECWT),
    age_int      = as.integer(AGE),
    filestat_int = as.integer(FILESTAT),
    inctot_num   = dplyr::if_else(as.numeric(INCTOT)  >= INCTOT_MISS,  NA_real_, as.numeric(INCTOT)),
    incwage_num  = dplyr::if_else(as.numeric(INCWAGE) >= INCWAGE_MISS, NA_real_, as.numeric(INCWAGE))
  )

stopifnot(
  "reserved INCTOT codes survived cleaning"  = !any(asec_tbl$inctot_num  >= INCTOT_MISS,  na.rm = TRUE),
  "reserved INCWAGE codes survived cleaning" = !any(asec_tbl$incwage_num >= INCWAGE_MISS, na.rm = TRUE)
)

message(sprintf("Weighted population (ASECWT): %.2f M.",
                sum(asec_tbl$weight_num, na.rm = TRUE) / 1e6))

FILESTAT_SINGLE   <- 5L
FILESTAT_NONFILER <- 6L
FILESTAT_JOINT    <- c(1L, 2L, 3L)
FILESTAT_HOH      <- 4L

###################################################################################
###                    3) The median grid                                       ###
###################################################################################
# One row per (concept x population x positivity) cell. Both weighted-median
# estimators are computed: `weighted_quantile` (ported from
# Household-income-and-composition, so figures are comparable to that project) and
# Hmisc::wtd.quantile (used by 04_02 elsewhere in this repo). Reporting the gap
# prevents the choice of estimator from silently moving the policy threshold.
median_hmisc <- function(x_num, w_num) {
  ok <- !is.na(x_num) & !is.na(w_num) & w_num > 0
  if (!any(ok)) return(NA_real_)
  as.numeric(Hmisc::wtd.quantile(x_num[ok], weights = w_num[ok],
                                 probs = 0.5, na.rm = TRUE))
}

summarize_cell <- function(pop_mask_lgl, pop_label_chr, concept_chr,
                           positive_only_lgl, note_chr = "") {
  value_num <- if (concept_chr == "INCTOT") asec_tbl$inctot_num else asec_tbl$incwage_num

  # In-universe for this concept = reserved codes already cleared.
  base_lgl <- pop_mask_lgl & !is.na(value_num)
  keep_lgl <- if (positive_only_lgl) base_lgl & value_num > 0 else base_lgl

  v <- value_num[keep_lgl]
  w <- asec_tbl$weight_num[keep_lgl]

  # Denominator composition, so each cell's population is auditable.
  base_v <- value_num[base_lgl]
  base_w <- asec_tbl$weight_num[base_lgl]
  n_na_int <- sum(pop_mask_lgl & is.na(value_num), na.rm = TRUE)

  data.frame(
    concept_chr          = concept_chr,
    population_chr       = pop_label_chr,
    positive_only_lgl    = positive_only_lgl,
    n_rows_int           = length(v),
    weighted_n_M_num     = round(sum(w, na.rm = TRUE) / 1e6, 2),
    median_num           = round(weighted_quantile(v, w, 0.5), 0L),
    median_hmisc_num     = round(median_hmisc(v, w), 0L),
    n_zero_in_base_int   = sum(base_v == 0, na.rm = TRUE),
    n_negative_in_base_int = sum(base_v < 0, na.rm = TRUE),
    wgt_zero_share_num   = round(sum(base_w[base_v == 0], na.rm = TRUE) /
                                   sum(base_w, na.rm = TRUE), 4L),
    n_out_of_universe_int = n_na_int,
    note_chr             = note_chr,
    stringsAsFactors     = FALSE
  )
}

# Populations. Age floor 15 matches the INCTOT universe (implicit choice c).
mask_all_lgl    <- asec_tbl$age_int >= 15L
mask_single_lgl  <- mask_all_lgl & asec_tbl$filestat_int == FILESTAT_SINGLE
mask_all_1864_lgl    <- asec_tbl$age_int >= 18L & asec_tbl$age_int <= 64L
mask_single_1864_lgl <- mask_all_1864_lgl & asec_tbl$filestat_int == FILESTAT_SINGLE

note_single_chr <- "SINGLE FILERS ONLY (FILESTAT == 5). MFS is not identifiable in FILESTAT and is NOT included."

grid_tbl <- dplyr::bind_rows(
  # --- the eight requested cells -------------------------------------------
  summarize_cell(mask_all_lgl,    "all_persons_15plus",   "INCTOT",  FALSE),
  summarize_cell(mask_all_lgl,    "all_persons_15plus",   "INCTOT",  TRUE),
  summarize_cell(mask_single_lgl, "single_filers_15plus", "INCTOT",  FALSE, note_single_chr),
  summarize_cell(mask_single_lgl, "single_filers_15plus", "INCTOT",  TRUE,  note_single_chr),
  summarize_cell(mask_all_lgl,    "all_persons_15plus",   "INCWAGE", FALSE,
                 "Non-earners enter as INCWAGE == 0, not NIU (verified: out_of_universe = 0), so this IS a population median including zeros."),
  summarize_cell(mask_all_lgl,    "all_persons_15plus",   "INCWAGE", TRUE),
  summarize_cell(mask_single_lgl, "single_filers_15plus", "INCWAGE", FALSE,
                 paste(note_single_chr, "Includes single filers with zero wage income.")),
  summarize_cell(mask_single_lgl, "single_filers_15plus", "INCWAGE", TRUE, note_single_chr),
  # --- working-age sensitivity ---------------------------------------------
  summarize_cell(mask_all_1864_lgl,    "all_persons_18_64",   "INCTOT",  TRUE),
  summarize_cell(mask_single_1864_lgl, "single_filers_18_64", "INCTOT",  TRUE, note_single_chr),
  summarize_cell(mask_all_1864_lgl,    "all_persons_18_64",   "INCWAGE", TRUE),
  summarize_cell(mask_single_1864_lgl, "single_filers_18_64", "INCWAGE", TRUE, note_single_chr),
  # --- filer-group diagnostics against the imposed statutory ratios --------
  # INCTOT versions are the load-bearing ones: they share the endpoint's concept,
  # so the observed-vs-imposed ratio comparison is like-for-like. INCWAGE versions
  # are kept for continuity with the wage-based cuts above.
  summarize_cell(mask_all_lgl & asec_tbl$filestat_int %in% FILESTAT_JOINT,
                 "joint_filers_15plus", "INCTOT", TRUE,
                 "Diagnostic: tests the imposed MFJ = 2.0x Single ratio on the endpoint's own concept."),
  summarize_cell(mask_all_lgl & asec_tbl$filestat_int == FILESTAT_HOH,
                 "hoh_filers_15plus", "INCTOT", TRUE,
                 "Diagnostic: tests the imposed HoH = 1.5x Single ratio on the endpoint's own concept."),
  summarize_cell(mask_all_lgl & asec_tbl$filestat_int %in% FILESTAT_JOINT,
                 "joint_filers_15plus", "INCWAGE", TRUE,
                 "Diagnostic: MFJ wage median, for continuity with the wage cuts."),
  summarize_cell(mask_all_lgl & asec_tbl$filestat_int == FILESTAT_HOH,
                 "hoh_filers_15plus", "INCWAGE", TRUE,
                 "Diagnostic: HoH wage median, for continuity with the wage cuts."),
  summarize_cell(mask_all_lgl & asec_tbl$filestat_int != FILESTAT_NONFILER,
                 "all_filers_15plus", "INCWAGE", TRUE,
                 "Diagnostic: all filers, excludes nonfilers only.")
)

# Estimator divergence check. A large gap means the distribution is heaped enough
# that the median definition matters; surface it rather than let it pass.
grid_tbl <- grid_tbl |>
  dplyr::mutate(
    estimator_gap_num = median_num - median_hmisc_num,
    estimator_gap_pct = round(
      100 * dplyr::if_else(median_hmisc_num != 0,
                           (median_num - median_hmisc_num) / median_hmisc_num,
                           NA_real_), 2L)
  )

max_gap_pct_num <- max(abs(grid_tbl$estimator_gap_pct), na.rm = TRUE)
if (is.finite(max_gap_pct_num) && max_gap_pct_num > 2) {
  warning(sprintf(
    "The two weighted-median estimators disagree by up to %.2f percent on some cell. Inspect asec_income_medians.csv before adopting an endpoint.",
    max_gap_pct_num), call. = FALSE)
}

message("ASEC median grid:")
for (i in seq_len(nrow(grid_tbl))) {
  message(sprintf("  %-8s %-22s positive_only=%-5s  n=%7d  wgt_M=%7.2f  median=$%s",
                  grid_tbl$concept_chr[i], grid_tbl$population_chr[i],
                  grid_tbl$positive_only_lgl[i], grid_tbl$n_rows_int[i],
                  grid_tbl$weighted_n_M_num[i],
                  formatC(grid_tbl$median_num[i], format = "d", big.mark = ",")))
}

###################################################################################
###                    4) Select the DESIGNATED ENDPOINT                        ###
###################################################################################
# The single policy dial. Median INCTOT, single filers age 15+, all values.
# The schedule scores filers on total income, so a total-income endpoint is what
# makes "0 percent at the median" literally true rather than approximately true.
# Single filers because the MFJ and HoH endpoints are derived from Single by the
# statutory sec 6433 ratios (2.0x and 1.5x), so Single is the quantity being set.
endpoint_row_tbl <- grid_tbl |>
  dplyr::filter(concept_chr == "INCTOT",
                population_chr == "single_filers_15plus",
                !positive_only_lgl)

if (nrow(endpoint_row_tbl) != 1L) {
  stop("Expected exactly one designated-endpoint row; found ",
       nrow(endpoint_row_tbl), ".", call. = FALSE)
}

designated_endpoint_num <- endpoint_row_tbl$median_num

if (is.na(designated_endpoint_num) || designated_endpoint_num <= 0) {
  stop("Designated endpoint is NA or non-positive. Check FILESTAT coding for this vintage.",
       call. = FALSE)
}
if (designated_endpoint_num < 15000 || designated_endpoint_num > 150000) {
  stop(sprintf("Designated endpoint $%d is outside the plausible range [$15,000, $150,000]. Refusing to write a suspect value.",
               round(designated_endpoint_num, 0L)), call. = FALSE)
}

# Expected value at the vintage this design was settled on (ASEC 2025, income year
# 2024). A drift warning, NOT a stop: a new ASEC vintage SHOULD move this number,
# and that is the intended behavior. The warning exists so the move is noticed and
# the published figures are refreshed rather than silently diverging.
expected_endpoint_num <- 44045
if (abs(designated_endpoint_num - expected_endpoint_num) > 500) {
  warning(sprintf(
    "Designated endpoint is $%s, which differs from the $%s expected at ASEC 2025 by more than $500. If the ASEC vintage changed this is expected -- refresh every published figure. If the vintage did NOT change, investigate before using.",
    formatC(designated_endpoint_num, format = "d", big.mark = ","),
    formatC(expected_endpoint_num, format = "d", big.mark = ",")
  ), call. = FALSE)
}

# The derived endpoints stage 04 consumes. Statutory sec 6433 ratios (decision S1).
SM_RATIO_MFJ <- 2.0
SM_RATIO_HOH <- 1.5
endpoint_table_num <- c(
  single_mfs = designated_endpoint_num,
  mfj        = SM_RATIO_MFJ * designated_endpoint_num,
  hoh        = SM_RATIO_HOH * designated_endpoint_num
)

get_median <- function(concept_chr, population_chr, positive_lgl) {
  v <- grid_tbl$median_num[grid_tbl$concept_chr == concept_chr &
                             grid_tbl$population_chr == population_chr &
                             grid_tbl$positive_only_lgl == positive_lgl]
  if (length(v) == 1L) v else NA_real_
}

# Observed inter-group ratios on the SAME concept as the endpoint (INCTOT), so the
# comparison against the imposed statutory ratios is like-for-like. Diagnostic only:
# decision S1 imposes 2.0x / 1.5x regardless of what the data show.
observed_ratio_mfj_num <- get_median("INCTOT", "joint_filers_15plus", TRUE) /
  designated_endpoint_num
observed_ratio_hoh_num <- get_median("INCTOT", "hoh_filers_15plus", TRUE) /
  designated_endpoint_num

message(sprintf("DESIGNATED ENDPOINT: $%s (median INCTOT, single filers age 15+, all values, nominal %d dollars).",
                formatC(designated_endpoint_num, format = "d", big.mark = ","),
                asec_income_year_int))
message(sprintf("  Derived endpoints: single_mfs $%s | mfj $%s | hoh $%s",
                formatC(endpoint_table_num[["single_mfs"]], format = "d", big.mark = ","),
                formatC(endpoint_table_num[["mfj"]],        format = "d", big.mark = ","),
                formatC(endpoint_table_num[["hoh"]],        format = "d", big.mark = ",")))

###################################################################################
###                    5) Write outputs                                         ###
###################################################################################
endpoint_list <- list(
  designated_endpoint_num  = designated_endpoint_num,
  endpoint_table_num       = endpoint_table_num,
  endpoint_concept_chr     = "INCTOT",
  endpoint_population_chr  = "single_filers_15plus_all_values",
  endpoint_includes_mfs_lgl = FALSE,
  ratio_mfj_num            = SM_RATIO_MFJ,
  ratio_hoh_num            = SM_RATIO_HOH,
  max_rate_pp_num          = 200,
  asec_survey_year_int     = asec_survey_year_int,
  asec_income_year_int     = asec_income_year_int,
  price_level_year_int     = asec_income_year_int,   # nominal; NOT projected (S3)
  grid_tbl                 = grid_tbl,
  observed_ratios_num      = c(mfj = observed_ratio_mfj_num, hoh = observed_ratio_hoh_num),
  source_extract_chr       = extract_csv_chr,
  computed_at_chr          = as.character(Sys.time())
)

endpoint_rds_chr <- file.path(path_data_processed, "asec_endpoint.rds")
grid_csv_chr     <- file.path(path_data_processed, "asec_income_medians.csv")
saveRDS(endpoint_list, endpoint_rds_chr)
readr::write_csv(grid_tbl, grid_csv_chr)

path_output_reports_chr <- file.path(path_output, "reports")
if (!dir.exists(path_output_reports_chr)) dir.create(path_output_reports_chr, recursive = TRUE)
diag_chr <- file.path(path_output_reports_chr, "asec_endpoint_diagnostics.md")

fmt_dollar <- function(x_num) {
  ifelse(is.na(x_num), "—", paste0("$", formatC(x_num, format = "d", big.mark = ",")))
}

diag_lines_chr <- c(
  "# CPS ASEC Income Medians and the Designated Endpoint",
  "",
  sprintf("Computed at: %s", as.character(Sys.time())),
  sprintf("Source: IPUMS CPS ASEC %d (income year %d), variables INCTOT, INCWAGE, FILESTAT, ASECWT, AGE.",
          asec_survey_year_int, asec_income_year_int),
  sprintf("All values are nominal %d dollars. No inflation adjustment and no projection (decision S3).",
          asec_income_year_int),
  "",
  "## The policy, in full",
  "",
  sprintf("A **200 percent match at $0 income**, declining in a straight line to a **0 percent match at %s** for single filers. Two numbers. Married filing jointly and head of household endpoints follow from the single-filer endpoint by the statutory IRC sec 6433 ratios (%.1fx and %.1fx).",
          fmt_dollar(designated_endpoint_num), SM_RATIO_MFJ, SM_RATIO_HOH),
  "",
  "| Filing group | Designated endpoint | Ratio to single |",
  "|---|---|---|",
  sprintf("| Single / MFS | %s | 1.0 |", fmt_dollar(endpoint_table_num[["single_mfs"]])),
  sprintf("| Married filing jointly | %s | %.1f |", fmt_dollar(endpoint_table_num[["mfj"]]), SM_RATIO_MFJ),
  sprintf("| Head of household | %s | %.1f |", fmt_dollar(endpoint_table_num[["hoh"]]), SM_RATIO_HOH),
  "",
  "## Which median sets the endpoint, and why",
  "",
  sprintf("The designated endpoint is the **weighted median total personal income (INCTOT) of single filers age 15+, all values**: %s.",
          fmt_dollar(designated_endpoint_num)),
  "",
  "Total income rather than wages, because the schedule scores filers on total income — so a total-income endpoint makes \"zero percent at the median\" literally true. The median single filer's income equals the endpoint by construction and therefore sits exactly at the zero-percent point. A wage-based endpoint sits below the total-income median and would push the median filer outside the band while the headline still said \"at the median\".",
  "",
  "All values rather than positive-only, because it needs no qualifier to state, and for single filers the two differ by $38.",
  "",
  "## Two findings that change how these numbers read",
  "",
  "**1. FILESTAT cannot identify married-filing-separately.** Codes are 1/2/3 Joint (split by age), 4 Head of household, 5 Single, 6 Nonfiler. Neither IPUMS FILESTAT nor the underlying Census tax-model variable carries an MFS category, because the tax model assigns married couples to joint filing. The requested \"single and MFS filers\" cut is therefore **single filers only**, and every label below says so. MFS is roughly 2-3 percent of returns nationally — small, but the omission is real and not correctable from this source.",
  "",
  "**2. The documented ASEC 2019 INCWAGE universe break does not bind in the delivered data.** The IPUMS universe note says the INCWAGE universe narrowed from persons age 15+ (through ASEC 2018) to persons age 15+ *with earnings last year* (ASEC 2019 onward). Taken at face value that would mean non-earners arrive as not-in-universe sentinels and drop out as missing, making the \"all values\" median an earners-only median almost equal to the positive-only one. **Measured here, that is not what happens:** the `out_of_universe` column is **0 in every cell**, and non-earners instead carry `INCWAGE == 0`. The two cells therefore differ enormously rather than converging. The check is retained deliberately — the universe note is real documentation, so a future vintage could begin emitting sentinels, and a non-zero `out_of_universe` on a later run means this section must be revisited before the \"all values\" medians are quoted.",
  "",
  "## Median grid",
  "",
  "| Concept | Population | Positive only | N rows | Weighted (M) | Median | Median (Hmisc) | Zeros in base | Negatives in base | Out of universe |",
  "|---|---|---|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(grid_tbl))) {
  diag_lines_chr <- c(diag_lines_chr, sprintf(
    "| %s | %s | %s | %d | %.2f | %s | %s | %d | %d | %d |",
    grid_tbl$concept_chr[i], grid_tbl$population_chr[i],
    ifelse(grid_tbl$positive_only_lgl[i], "yes", "no"),
    grid_tbl$n_rows_int[i], grid_tbl$weighted_n_M_num[i],
    fmt_dollar(grid_tbl$median_num[i]), fmt_dollar(grid_tbl$median_hmisc_num[i]),
    grid_tbl$n_zero_in_base_int[i], grid_tbl$n_negative_in_base_int[i],
    grid_tbl$n_out_of_universe_int[i]
  ))
}
diag_lines_chr <- c(diag_lines_chr, "",
  sprintf("Largest disagreement between the two weighted-median estimators across all cells: %.2f percent. The `weighted_quantile` column is the headline (it matches the Household-income-and-composition estimator); the Hmisc column is the estimator used elsewhere in this repo.",
          max_gap_pct_num),
  "",
  "## Statutory vs. observed inter-group ratios",
  "",
  "Decision S1 imposes the statutory sec 6433 ratios (MFJ = 2.0x Single, HoH = 1.5x Single) regardless of the data. Observed ratios are diagnostic only — they show how far the imposed geometry sits from the empirical distribution. Computed on INCTOT, the same concept as the endpoint, so the comparison is like-for-like.",
  "",
  "| Group | Statutory ratio | Observed ratio (INCTOT, positive) |",
  "|---|---|---|",
  sprintf("| MFJ | %.2f | %.2f |", SM_RATIO_MFJ, observed_ratio_mfj_num),
  sprintf("| HoH | %.2f | %.2f |", SM_RATIO_HOH, observed_ratio_hoh_num),
  "",
  "## Stated implicit choices",
  "",
  "a. Reserved codes cleared before any statistic: INCTOT 999999999 (NIU) / 999999998 (missing); INCWAGE 99999999 / 99999998. Leaving them would put nine-digit sentinels in the distribution.",
  "b. INCTOT negatives are **kept** in the all-values cells — personal income can genuinely be negative (business and farm losses). Dropping them would be a substantive edit, not cleaning.",
  "c. Age floor 15, matching the INCTOT universe. An 18-64 variant is reported because the Saver's Match universe is age 18+.",
  "d. ASECWT is the weight, not WTFINL. WTFINL is the basic monthly weight and ignores the ASEC oversample.",
  "e. No topcode adjustment — topcoding compresses the upper tail and cannot move a median.",
  "f. Single-year cross-section, so no inflation adjustment is applied or needed.",
  "",
  "## Downstream contract",
  "",
  "This script writes `data/processed/asec_endpoint.rds`, carrying the designated endpoint and the three derived filing-group endpoints. `04_02_compute_endpoints.R` reads it and passes the endpoint table to `compute_match_rate()`. There is no intermediate derivation: the endpoint written here is the endpoint the model uses.",
  "",
  "## Retired vocabulary",
  "",
  "Earlier versions of this design described the same straight line by an interior 50 percent crossing (a \"pivot\") derived from an external median (an \"anchor\"). Both terms are retired. Audit bridge for reconciling pre-2026-08-04 outputs only: `old_pivot = 0.75 x endpoint`."
)
writeLines(diag_lines_chr, diag_chr)

message("Outputs written to:")
message("  ", endpoint_rds_chr)
message("  ", grid_csv_chr)
message("  ", diag_chr)
message("Finished 01d_asec_income_medians.R")
