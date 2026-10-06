# ----------------------------------------------------------------------------
# SIPP 2024 retirement-module access flags: variable interpretation
# ----------------------------------------------------------------------------
# Audit completed 2026-05-06 against the SIPP 2024 instrument PDF (cited
# below by page number). The audit-corrected access flags below implement the
# fix specified in Infrastructure/specs/2026-05-08_access-flag-fix.md.
#
# Skip-pattern facts (verified against the 2024 SIPP instrument PDF):
#   - EMJOB_401  is asked only if EOWN_THR401  == 1 (page 1862).
#   - EMJOB_IRA  is asked only if EOWN_IRAKEO  == 1 (page 1881).
#   - EMJOB_PEN  is asked only if EOWN_PENSION == 1 (page 1932).
# Therefore EMJOB_*  identifies "owns plan via main current employer." A
# response of EMJOB_*  == 2 means "I own a plan of this type, but it is NOT
# via my main current employer" -- it is silent on whether the current
# employer offers a plan.
#
#   - EPENSNYN ("did your main employer or business have any retirement
#               plan?") is asked of the complement (workers without a plan
#               via main job), and is the actual employer-offer signal
#               (page 1939).
#   - EINCPENS ("were you included in the offered plan(s)?") is the
#               participation companion to EPENSNYN (page 1942).
#
# Therefore the audit-corrected access flag combines:
#   any_retirement_access_v2_chr = "Yes" if has_plan_via_main_job_v2_flag,
#                                       OR EPENSNYN == 1
#                                  "No"  if EPENSNYN == 2 (and not has_plan_via_main_job)
#                                  "Missing" otherwise
# where has_plan_via_main_job_v2_flag = (EMJOB_401 == 1 | EMJOB_IRA == 1 |
#                                        EMJOB_PEN == 1).
#
# This block is implemented additively below: the legacy ANY_RETIREMENT_ACCESS
# (which uses EMJOB_*  == 2 and EOWN_*  == 2 to infer "No," contrary to the
# skip-pattern interpretation) is preserved unchanged. The new flag
# any_retirement_access_v2_chr and the parallel RSAA_ELIGIBLE_B_v2 are added
# alongside. No existing consumer is migrated in this change set; downstream
# scripts opt into v2 explicitly. See Infrastructure/plans/2026-05-08_access-flag-fix.md.
# ----------------------------------------------------------------------------

sm_calibration_constants <- function() {
  list(
    median_income = 45140,
    age_min = 18,
    age_max = 65,
    contrib_rate_1 = 0.01,
    contrib_share_1 = 0.15,
    contrib_rate_2 = 0.03,
    contrib_share_2 = 0.25,
    contrib_rate_3 = 0.05,
    contrib_share_3 = 0.60,
    sm_lower = c(Single = 20500, MFJ = 41000, HoH = 30750, MFS = 20500),
    sm_upper = c(Single = 35500, MFJ = 71000, HoH = 53250, MFS = 35500),
    sm_match_rate_max = 0.50,
    sm_contrib_cap = 2000,
    rsaa_phaseout_mult = 1.00,
    rsaa_credit_limit_share = 0.05,
    rsaa_phaseout_slope = 75 / 1000,
    rsaa_auto_credit_rate = 0.01,
    rsaa_match_kink1 = 0.03,
    rsaa_match_kink2 = 0.05,
    rsaa_match_rate_below_k1 = 1.00,
    rsaa_match_rate_between = 0.50
  )
}

weighted_sum <- function(x, w) {
  sum(x * w, na.rm = TRUE)
}

weighted_mean <- function(x, w) {
  Hmisc::wtd.mean(x, w, na.rm = TRUE)
}

safe_weighted_share <- function(flag, w) {
  denom <- sum(w, na.rm = TRUE)
  if (is.na(denom) || denom <= 0) {
    return(NA_real_)
  }
  weighted_mean(as.numeric(flag), w)
}

safe_conditional_share <- function(flag, base_flag, w) {
  denom <- sum(w[base_flag %in% TRUE], na.rm = TRUE)
  if (length(base_flag) == 0) {
    return(NA_real_)
  }
  if (is.na(denom) || denom <= 0) {
    return(NA_real_)
  }
  weighted_sum(as.numeric(flag %in% TRUE & base_flag %in% TRUE), w) / denom
}

safe_weighted_mean_subset <- function(x, w, subset_flag) {
  denom <- sum(w[subset_flag %in% TRUE], na.rm = TRUE)
  if (is.na(denom) || denom <= 0) {
    return(NA_real_)
  }
  weighted_mean(x[subset_flag %in% TRUE], w[subset_flag %in% TRUE])
}

make_age_group <- function(age) {
  dplyr::case_when(
    age >= 18 & age <= 34 ~ "18_34",
    age >= 35 & age <= 49 ~ "35_49",
    age >= 50 & age <= 65 ~ "50_65",
    TRUE ~ NA_character_
  )
}

make_work_status <- function(hours) {
  dplyr::case_when(
    hours >= 35 ~ "full_time",
    hours > 0 & hours < 35 ~ "part_time",
    TRUE ~ NA_character_
  )
}

make_filing_group <- function(efstatus) {
  dplyr::case_when(
    efstatus %in% c(1, 3) ~ "single_mfs",
    efstatus == 2 ~ "mfj",
    efstatus == 4 ~ "hoh",
    TRUE ~ NA_character_
  )
}

make_income_cell_sm <- function(sm_income, sm_lower_thresh, sm_upper_thresh) {
  dplyr::case_when(
    is.na(sm_income) | is.na(sm_lower_thresh) | is.na(sm_upper_thresh) ~ NA_character_,
    sm_income <= sm_lower_thresh ~ "full_match",
    sm_income > sm_lower_thresh & sm_income < sm_upper_thresh ~ "partial_match",
    sm_income >= sm_upper_thresh ~ "above_ceiling",
    TRUE ~ NA_character_
  )
}

make_income_cell_rsaa <- function(gross_income, median_income, rsaa_ceiling) {
  dplyr::case_when(
    is.na(gross_income) ~ NA_character_,
    gross_income < 0.5 * median_income ~ "0_50_median",
    gross_income < 0.75 * median_income ~ "50_75_median",
    gross_income < 1.00 * median_income ~ "75_100_median",
    gross_income <= rsaa_ceiling ~ "100_median_to_positive_benefit_ceiling",
    gross_income > rsaa_ceiling ~ "above_positive_benefit_ceiling",
    TRUE ~ NA_character_
  )
}

assign_contrib_rate <- function(df, eligible_col, constants) {
  eligible_rates <- df %>%
    dplyr::filter(.data[[eligible_col]], !is.na(WPFINWGT)) %>%
    dplyr::arrange(u_contrib) %>%
    dplyr::mutate(
      cum_w = cumsum(WPFINWGT),
      share_w = cum_w / sum(WPFINWGT),
      contrib_rate = dplyr::case_when(
        share_w <= constants$contrib_share_1 ~ constants$contrib_rate_1,
        share_w <= constants$contrib_share_1 + constants$contrib_share_2 ~ constants$contrib_rate_2,
        TRUE ~ constants$contrib_rate_3
      )
    ) %>%
    dplyr::select(row_id, contrib_rate)

  df %>%
    dplyr::select(-dplyr::any_of("contrib_rate")) %>%
    dplyr::left_join(eligible_rates, by = "row_id") %>%
    dplyr::mutate(
      contrib_rate = dplyr::if_else(!.data[[eligible_col]] | is.na(contrib_rate), 0, contrib_rate)
    )
}

# aggregate_sipp_person_year() collapses raw SIPP person-month rows
# (one row per (SSUID, PNUM, MONTHCODE)) into person-year aggregates by
# summing TPTOTINC / TFTOTINC / TPEARN across all observed monthcodes
# per person, then scaling to a 12-month basis (Option B):
#
#   annual_x = sum(monthly_x, na.rm = TRUE) * 12 / n_months_x_valid
#
# For the typical SIPP respondent observed all 12 months this is the measured
# calendar-year total. For partial-year respondents (n_valid < 12) the sum is
# scaled up to a 12-month basis. See the Option B caveat in 02a lines 287-330.
#
# This helper is consumed by:
#   - build_modeled_sipp_frame_v2() below (replaces v1's TPTOTINC * 12 logic)
#   - 02a_eligibility_buckets.R (Option B income aggregation block)
#
# Why: TPTOTINC, TFTOTINC, and TPEARN are MONTHLY reference-month values in
# SIPP 2024. The deprecated v1 helper used the December reference-month value
# multiplied by 12, which (1) requires flat monthly earnings to be unbiased,
# (2) silently excludes anyone with zero December earnings but nonzero earnings
# earlier in the year, and (3) has 144x noise variance vs. the sum-over-months
# alternative. See EIG-Savers-match-sipp/output/reports/fact_check_v3_2026-04-25.md
# for the empirical magnitude (Option B raises B1 +16%, B2 +23%, B3 +14%
# vs. Dec x 12).
aggregate_sipp_person_year <- function(raw) {
  raw %>%
    dplyr::group_by(SSUID, PNUM) %>%
    dplyr::summarise(
      tptotinc_sum_num            = sum(TPTOTINC, na.rm = TRUE),
      tftotinc_sum_num            = sum(TFTOTINC, na.rm = TRUE),
      tpearn_sum_num              = sum(TPEARN,   na.rm = TRUE),
      n_months_observed_int       = dplyr::n(),
      n_months_tptotinc_valid_int = sum(!is.na(TPTOTINC)),
      n_months_tftotinc_valid_int = sum(!is.na(TFTOTINC)),
      n_months_tpearn_valid_int   = sum(!is.na(TPEARN)),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
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
}


build_modeled_sipp_frame <- function(raw, seed = 42L) {
  # DEPRECATED 2026-04-26: uses the December x 12 income annualization.
  # New callers should use build_modeled_sipp_frame_v2() which consumes
  # the Option B aggregate_sipp_person_year() output. v1 is retained for
  # one cycle for any external consumers.
  warning(
    "build_modeled_sipp_frame() uses the deprecated December x 12 income ",
    "annualization. Use the canonical builder code/_shared/build_frame.R ",
    "(build_modeled_frame), which wraps build_modeled_sipp_frame_v2() with the ",
    "Option B person-year aggregation and the TY2027 projection.",
    call. = FALSE
  )
  constants <- sm_calibration_constants()
  stopifnot(abs(
    constants$contrib_share_1 + constants$contrib_share_2 + constants$contrib_share_3 - 1
  ) < 1e-10)

  set.seed(seed)

  rsaa_phaseout_amount <- constants$rsaa_phaseout_mult * constants$median_income
  rsaa_credit_limit_base <- constants$rsaa_credit_limit_share * rsaa_phaseout_amount
  rsaa_ceiling <- rsaa_phaseout_amount + rsaa_credit_limit_base / constants$rsaa_phaseout_slope

  work <- raw %>%
    dplyr::filter(MONTHCODE == 12) %>%
    dplyr::mutate(
      row_id = dplyr::row_number(),
      TOTYEARINC = TPTOTINC * 12,
      TOTYEARFAMINC = TFTOTINC * 12,
      GROSS_INCOME = pmax(TOTYEARINC, 0),
      age_group = make_age_group(TAGE),
      work_status = make_work_status(TJB1_JOBHRS1),
      filing_group = make_filing_group(EFSTATUS),
      FILING_STATUS = dplyr::case_when(
        EFSTATUS == 1 ~ "Single",
        EFSTATUS == 2 ~ "MFJ",
        EFSTATUS == 3 ~ "MFS",
        EFSTATUS == 4 ~ "HoH",
        TRUE ~ NA_character_
      ),
      SM_INCOME = dplyr::case_when(
        EFSTATUS == 2 ~ TOTYEARFAMINC,
        TRUE ~ TOTYEARINC
      ),
      SM_LOWER_THRESH = dplyr::case_when(
        EFSTATUS %in% c(1, 3) ~ constants$sm_lower["Single"],
        EFSTATUS == 2 ~ constants$sm_lower["MFJ"],
        EFSTATUS == 4 ~ constants$sm_lower["HoH"],
        TRUE ~ NA_real_
      ),
      SM_UPPER_THRESH = dplyr::case_when(
        EFSTATUS %in% c(1, 3) ~ constants$sm_upper["Single"],
        EFSTATUS == 2 ~ constants$sm_upper["MFJ"],
        EFSTATUS == 4 ~ constants$sm_upper["HoH"],
        TRUE ~ NA_real_
      ),
      SM_FACTOR = pmax(
        0,
        pmin(1, (SM_UPPER_THRESH - SM_INCOME) / (SM_UPPER_THRESH - SM_LOWER_THRESH))
      ),
      EMPLOYMENT_TYPE = dplyr::case_when(
        EJB1_JBORSE == 1 ~ "Employer",
        EJB1_JBORSE == 2 ~ "Self-employed",
        EJB1_JBORSE == 3 ~ "Other",
        TRUE ~ "Missing"
      ),
      PRIVATE_SECTOR = EJB1_CLWRK %in% c(5, 6),
      HAS_HOURS = TJB1_JOBHRS1 > 0 & !is.na(TJB1_JOBHRS1),
      ANY_RETIREMENT_ACCESS = dplyr::case_when(
        EMJOB_401 == 1 | EMJOB_IRA == 1 | EMJOB_PEN == 1 ~ "Yes",
        EMJOB_401 == 2 ~ "No",
        EMJOB_IRA == 2 ~ "No",
        EMJOB_PEN == 2 ~ "No",
        EOWN_THR401 == 2 ~ "No",
        EOWN_IRAKEO == 2 ~ "No",
        EOWN_PENSION == 2 ~ "No",
        TRUE ~ "Missing"
      ),
      # ---- Audit-corrected access flag (additive; see top-of-file block) ----
      # any_retirement_access_v2_chr is the SIPP-instrument-correct read of
      # "any retirement access" using the EMJOB_*  ownership signal AND the
      # EPENSNYN employer-offer signal. The legacy ANY_RETIREMENT_ACCESS above
      # is preserved unchanged.
      has_plan_via_main_job_v2_flag = dplyr::case_when(
        EMJOB_401 == 1 | EMJOB_IRA == 1 | EMJOB_PEN == 1 ~ TRUE,
        is.na(EMJOB_401) & is.na(EMJOB_IRA) & is.na(EMJOB_PEN) ~ NA,
        TRUE ~ FALSE
      ),
      any_retirement_access_v2_chr = dplyr::case_when(
        has_plan_via_main_job_v2_flag %in% TRUE ~ "Yes",
        EPENSNYN == 1L ~ "Yes",
        EPENSNYN == 2L ~ "No",
        TRUE ~ "Missing"
      ),
      PARTICIPATING = dplyr::case_when(
        ESCNTYN_401 == 1 ~ "Yes",
        EECNTYN_401 == 1 ~ "Yes",
        EECNTYN_IRA == 1 ~ "Yes",  # added 2026-04-28 for symmetry with EECNTYN_401: employer IRA contribution implies enrollment
        ESCNTYN_PEN == 1 ~ "Yes",
        ESCNTYN_IRA == 1 ~ "Yes",
        ESCNTYN_401 == 2 ~ "No",
        ESCNTYN_PEN == 2 ~ "No",
        ESCNTYN_IRA == 2 ~ "No",
        EOWN_THR401 == 2 ~ "No",
        EOWN_IRAKEO == 2 ~ "No",
        EOWN_PENSION == 2 ~ "No",
        TRUE ~ "Missing"
      ),
      MATCHING = dplyr::case_when(
        EECNTYN_401 == 1 ~ "Yes",
        EECNTYN_IRA == 1 ~ "Yes",
        EECNTYN_401 == 2 ~ "No",
        EECNTYN_IRA == 2 ~ "No",
        EOWN_THR401 == 2 ~ "No",
        EOWN_IRAKEO == 2 ~ "No",
        EOWN_PENSION == 2 ~ "No",
        TRUE ~ "Missing"
      ),
      HAS_EXISTING_DC = (
        EOWN_THR401 == 1 | EOWN_IRAKEO == 1 | EMJOB_401 == 1 | EMJOB_IRA == 1
      ),
      HAS_IRA = EOWN_IRAKEO == 1,
      IN_AGE_RANGE = TAGE >= constants$age_min & TAGE <= constants$age_max,
      u_contrib = runif(dplyr::n()),
      common_private_worker = IN_AGE_RANGE &
        EMPLOYMENT_TYPE == "Employer" &
        PRIVATE_SECTOR &
        HAS_HOURS &
        TPTOTINC > 0 &
        ANY_RETIREMENT_ACCESS != "Missing" &
        PARTICIPATING != "Missing" &
        MATCHING != "Missing" &
        !is.na(work_status),
      sm_base_worker = common_private_worker & !is.na(filing_group),
      rsaa_base_worker = common_private_worker
    )

  work <- work %>%
    dplyr::mutate(
      SM_ELIGIBLE_A = sm_base_worker & !is.na(SM_INCOME) & SM_FACTOR > 0,
      SM_FULL_ZONE = SM_ELIGIBLE_A & SM_INCOME <= SM_LOWER_THRESH,
      SM_PARTIAL_ZONE = SM_ELIGIBLE_A & SM_INCOME > SM_LOWER_THRESH,
      SM_ELIGIBLE_A_DC = SM_ELIGIBLE_A & HAS_EXISTING_DC
    )

  work <- assign_contrib_rate(work, "SM_ELIGIBLE_A", constants)

  work <- work %>%
    dplyr::mutate(
      worker_contrib_dollars = contrib_rate * GROSS_INCOME,
      SM_GOVT_MATCH = dplyr::if_else(
        SM_ELIGIBLE_A,
        SM_FACTOR * constants$sm_match_rate_max * pmin(worker_contrib_dollars, constants$sm_contrib_cap),
        0
      )
    )

  work <- work %>%
    dplyr::mutate(
      RSAA_ELIGIBLE_B = rsaa_base_worker & ANY_RETIREMENT_ACCESS == "No",
      # Audit-corrected RSAA eligibility flag (additive; see top-of-file
      # block). Mirrors RSAA_ELIGIBLE_B but consumes the v2 access flag.
      # Preserved as a clean starting point for any future RSAA revival;
      # not consumed downstream in the current Saver's Match memo path.
      RSAA_ELIGIBLE_B_v2 = rsaa_base_worker & any_retirement_access_v2_chr == "No"
    )

  work <- assign_contrib_rate(work, "RSAA_ELIGIBLE_B", constants)

  work <- work %>%
    dplyr::mutate(
      contrib_rate_rsaa = dplyr::if_else(RSAA_ELIGIBLE_B, contrib_rate, 0),
      match_rate_share = dplyr::case_when(
        !RSAA_ELIGIBLE_B ~ 0,
        contrib_rate_rsaa <= constants$rsaa_match_kink1 ~
          constants$rsaa_match_rate_below_k1 * contrib_rate_rsaa,
        TRUE ~
          constants$rsaa_match_rate_below_k1 * constants$rsaa_match_kink1 +
          constants$rsaa_match_rate_between * (contrib_rate_rsaa - constants$rsaa_match_kink1)
      ),
      RSAA_MATCH_CREDIT = match_rate_share * GROSS_INCOME,
      RSAA_AUTO_CREDIT = dplyr::if_else(
        RSAA_ELIGIBLE_B,
        constants$rsaa_auto_credit_rate * GROSS_INCOME,
        0
      ),
      RSAA_CREDIT_RAW = RSAA_MATCH_CREDIT + RSAA_AUTO_CREDIT,
      RSAA_EXCESS = pmax(GROSS_INCOME - rsaa_phaseout_amount, 0),
      RSAA_CAP = pmax(rsaa_credit_limit_base - constants$rsaa_phaseout_slope * RSAA_EXCESS, 0),
      RSAA_GOVT_CONTRIB = dplyr::if_else(
        RSAA_ELIGIBLE_B,
        pmin(RSAA_CREDIT_RAW, RSAA_CAP),
        0
      ),
      RSAA_RECEIVES_BENEFIT_B = RSAA_ELIGIBLE_B & RSAA_GOVT_CONTRIB > 0,
      OVERLAP_C = SM_ELIGIBLE_A & RSAA_ELIGIBLE_B,
      OVERLAP_C_DC = OVERLAP_C & HAS_IRA,
      income_cell_sm = make_income_cell_sm(SM_INCOME, SM_LOWER_THRESH, SM_UPPER_THRESH),
      income_cell_rsaa = make_income_cell_rsaa(GROSS_INCOME, constants$median_income, rsaa_ceiling),
      rsaa_positive_benefit_ceiling = rsaa_ceiling
    )

  work
}


# build_modeled_sipp_frame_v2() reproduces v1's output shape but uses the
# Option B calendar-year income aggregation and the U1 spouse-pair income
# construction documented in the SIPP income-methodology migration (2026-04-26).
#
# Differences from v1 (column-by-column behavior preserved unless noted):
#   - TOTYEARINC    = tptotinc_annual_num (Option B sum, scaled to 12 months)
#                    instead of TPTOTINC * 12 (December reference month).
#   - TOTYEARFAMINC = tftotinc_annual_num (Option B family-income sum)
#                    instead of TFTOTINC * 12.
#   - SM_INCOME for MFJ filers (EFSTATUS == 2) is the U1 spouse-pair sum:
#     personal annual TPTOTINC + spouse's annual TPTOTINC, where the spouse
#     is identified via EPNSPOUSE (within-household pointer to spouse PNUM).
#     Non-MFJ rows use personal annual TPTOTINC, same as v1.
#     This replaces v1's TFTOTINC*12 family-income proxy, which over-included
#     income from non-spouse family members.
#
# All other columns (SM_FACTOR, FILING_STATUS, PRIVATE_SECTOR, HAS_HOURS,
# ANY_RETIREMENT_ACCESS, PARTICIPATING, MATCHING, HAS_EXISTING_DC,
# common_private_worker, sm_base_worker, rsaa_base_worker, SM_ELIGIBLE_A,
# RSAA_ELIGIBLE_B, contrib_rate, contrib_rate_rsaa, etc.) are computed
# identically to v1.
build_modeled_sipp_frame_v2 <- function(raw, seed = 42L) {
  constants <- sm_calibration_constants()
  stopifnot(abs(
    constants$contrib_share_1 + constants$contrib_share_2 + constants$contrib_share_3 - 1
  ) < 1e-10)

  set.seed(seed)

  rsaa_phaseout_amount <- constants$rsaa_phaseout_mult * constants$median_income
  rsaa_credit_limit_base <- constants$rsaa_credit_limit_share * rsaa_phaseout_amount
  rsaa_ceiling <- rsaa_phaseout_amount + rsaa_credit_limit_base / constants$rsaa_phaseout_slope

  # Step 1: Option B person-year aggregation across all monthcodes.
  person_year <- aggregate_sipp_person_year(raw)

  # Step 2: Restrict to December reference month (cross-sectional snapshot)
  #         and merge in the person-year aggregates.
  work <- raw %>%
    dplyr::filter(MONTHCODE == 12) %>%
    dplyr::mutate(row_id = dplyr::row_number()) %>%
    dplyr::left_join(
      dplyr::select(person_year,
                    SSUID, PNUM,
                    tptotinc_annual_num,
                    tftotinc_annual_num,
                    tpearn_annual_num,
                    n_months_observed_int),
      by = c("SSUID", "PNUM")
    )

  # Step 3: U1 spouse-pair income lookup. For each MFJ filer, locate the
  #         spouse's annual TPTOTINC via EPNSPOUSE (within-SSUID PNUM
  #         pointer) and attach it as spouse_tptotinc_annual_num.
  spouse_lookup <- person_year %>%
    dplyr::select(SSUID,
                  spouse_pnum = PNUM,
                  spouse_tptotinc_annual_num = tptotinc_annual_num)

  work <- work %>%
    dplyr::left_join(
      spouse_lookup,
      by = c("SSUID", "EPNSPOUSE" = "spouse_pnum")
    )

  # Step 4: Compute the v1-shape columns using the Option B + U1 inputs.
  #         The mutate block below is identical to v1's main mutate
  #         (lines 212-307 of this file) EXCEPT for the four lines marked
  #         "[v2 CHANGE]" — which substitute Option B / U1 values for the
  #         December x 12 / TFTOTINC family-income proxy.
  work <- work %>%
    dplyr::mutate(
      TOTYEARINC    = tptotinc_annual_num,                  # [v2 CHANGE]
      TOTYEARFAMINC = tftotinc_annual_num,                  # [v2 CHANGE]
      GROSS_INCOME  = pmax(TOTYEARINC, 0, na.rm = TRUE),
      age_group     = make_age_group(TAGE),
      work_status   = make_work_status(TJB1_JOBHRS1),
      filing_group  = make_filing_group(EFSTATUS),
      FILING_STATUS = dplyr::case_when(
        EFSTATUS == 1 ~ "Single",
        EFSTATUS == 2 ~ "MFJ",
        EFSTATUS == 3 ~ "MFS",
        EFSTATUS == 4 ~ "HoH",
        TRUE ~ NA_character_
      ),
      # SM_INCOME: U1 spouse-pair sum for MFJ with resolved spouse pointer;
      # personal annual TPTOTINC otherwise.            # [v2 CHANGE]
      SM_INCOME = dplyr::case_when(
        EFSTATUS == 2 & !is.na(spouse_tptotinc_annual_num) ~
          tptotinc_annual_num + spouse_tptotinc_annual_num,
        TRUE ~ tptotinc_annual_num
      ),
      SM_LOWER_THRESH = dplyr::case_when(
        EFSTATUS %in% c(1, 3) ~ constants$sm_lower["Single"],
        EFSTATUS == 2 ~ constants$sm_lower["MFJ"],
        EFSTATUS == 4 ~ constants$sm_lower["HoH"],
        TRUE ~ NA_real_
      ),
      SM_UPPER_THRESH = dplyr::case_when(
        EFSTATUS %in% c(1, 3) ~ constants$sm_upper["Single"],
        EFSTATUS == 2 ~ constants$sm_upper["MFJ"],
        EFSTATUS == 4 ~ constants$sm_upper["HoH"],
        TRUE ~ NA_real_
      ),
      SM_FACTOR = pmax(
        0,
        pmin(1, (SM_UPPER_THRESH - SM_INCOME) / (SM_UPPER_THRESH - SM_LOWER_THRESH))
      ),
      EMPLOYMENT_TYPE = dplyr::case_when(
        EJB1_JBORSE == 1 ~ "Employer",
        EJB1_JBORSE == 2 ~ "Self-employed",
        EJB1_JBORSE == 3 ~ "Other",
        TRUE ~ "Missing"
      ),
      PRIVATE_SECTOR = EJB1_CLWRK %in% c(5, 6),
      HAS_HOURS = TJB1_JOBHRS1 > 0 & !is.na(TJB1_JOBHRS1),
      ANY_RETIREMENT_ACCESS = dplyr::case_when(
        EMJOB_401 == 1 | EMJOB_IRA == 1 | EMJOB_PEN == 1 ~ "Yes",
        EMJOB_401 == 2 ~ "No",
        EMJOB_IRA == 2 ~ "No",
        EMJOB_PEN == 2 ~ "No",
        EOWN_THR401 == 2 ~ "No",
        EOWN_IRAKEO == 2 ~ "No",
        EOWN_PENSION == 2 ~ "No",
        TRUE ~ "Missing"
      ),
      # ---- Audit-corrected access flag (additive; see top-of-file block) ----
      # any_retirement_access_v2_chr is the SIPP-instrument-correct read of
      # "any retirement access" using the EMJOB_*  ownership signal AND the
      # EPENSNYN employer-offer signal. The legacy ANY_RETIREMENT_ACCESS above
      # is preserved unchanged.
      has_plan_via_main_job_v2_flag = dplyr::case_when(
        EMJOB_401 == 1 | EMJOB_IRA == 1 | EMJOB_PEN == 1 ~ TRUE,
        is.na(EMJOB_401) & is.na(EMJOB_IRA) & is.na(EMJOB_PEN) ~ NA,
        TRUE ~ FALSE
      ),
      any_retirement_access_v2_chr = dplyr::case_when(
        has_plan_via_main_job_v2_flag %in% TRUE ~ "Yes",
        EPENSNYN == 1L ~ "Yes",
        EPENSNYN == 2L ~ "No",
        TRUE ~ "Missing"
      ),
      PARTICIPATING = dplyr::case_when(
        ESCNTYN_401 == 1 ~ "Yes",
        EECNTYN_401 == 1 ~ "Yes",
        EECNTYN_IRA == 1 ~ "Yes",  # added 2026-04-28 for symmetry with EECNTYN_401: employer IRA contribution implies enrollment
        ESCNTYN_PEN == 1 ~ "Yes",
        ESCNTYN_IRA == 1 ~ "Yes",
        ESCNTYN_401 == 2 ~ "No",
        ESCNTYN_PEN == 2 ~ "No",
        ESCNTYN_IRA == 2 ~ "No",
        EOWN_THR401 == 2 ~ "No",
        EOWN_IRAKEO == 2 ~ "No",
        EOWN_PENSION == 2 ~ "No",
        TRUE ~ "Missing"
      ),
      MATCHING = dplyr::case_when(
        EECNTYN_401 == 1 ~ "Yes",
        EECNTYN_IRA == 1 ~ "Yes",
        EECNTYN_401 == 2 ~ "No",
        EECNTYN_IRA == 2 ~ "No",
        EOWN_THR401 == 2 ~ "No",
        EOWN_IRAKEO == 2 ~ "No",
        EOWN_PENSION == 2 ~ "No",
        TRUE ~ "Missing"
      ),
      HAS_EXISTING_DC = (
        EOWN_THR401 == 1 | EOWN_IRAKEO == 1 | EMJOB_401 == 1 | EMJOB_IRA == 1
      ),
      HAS_IRA = EOWN_IRAKEO == 1,
      IN_AGE_RANGE = TAGE >= constants$age_min & TAGE <= constants$age_max,
      u_contrib = runif(dplyr::n()),
      common_private_worker = IN_AGE_RANGE &
        EMPLOYMENT_TYPE == "Employer" &
        PRIVATE_SECTOR &
        HAS_HOURS &
        TPTOTINC > 0 &
        ANY_RETIREMENT_ACCESS != "Missing" &
        PARTICIPATING != "Missing" &
        MATCHING != "Missing" &
        !is.na(work_status),
      sm_base_worker = common_private_worker & !is.na(filing_group),
      rsaa_base_worker = common_private_worker
    )

  work <- work %>%
    dplyr::mutate(
      SM_ELIGIBLE_A = sm_base_worker & !is.na(SM_INCOME) & SM_FACTOR > 0,
      SM_FULL_ZONE = SM_ELIGIBLE_A & SM_INCOME <= SM_LOWER_THRESH,
      SM_PARTIAL_ZONE = SM_ELIGIBLE_A & SM_INCOME > SM_LOWER_THRESH,
      SM_ELIGIBLE_A_DC = SM_ELIGIBLE_A & HAS_EXISTING_DC
    )

  work <- assign_contrib_rate(work, "SM_ELIGIBLE_A", constants)

  work <- work %>%
    dplyr::mutate(
      worker_contrib_dollars = contrib_rate * GROSS_INCOME,
      SM_GOVT_MATCH = dplyr::if_else(
        SM_ELIGIBLE_A,
        SM_FACTOR * constants$sm_match_rate_max * pmin(worker_contrib_dollars, constants$sm_contrib_cap),
        0
      )
    )

  work <- work %>%
    dplyr::mutate(
      RSAA_ELIGIBLE_B = rsaa_base_worker & ANY_RETIREMENT_ACCESS == "No",
      # Audit-corrected RSAA eligibility flag (additive; see top-of-file
      # block). Mirrors RSAA_ELIGIBLE_B but consumes the v2 access flag.
      # Preserved as a clean starting point for any future RSAA revival;
      # not consumed downstream in the current Saver's Match memo path.
      RSAA_ELIGIBLE_B_v2 = rsaa_base_worker & any_retirement_access_v2_chr == "No"
    )

  work <- assign_contrib_rate(work, "RSAA_ELIGIBLE_B", constants)

  work <- work %>%
    dplyr::mutate(
      contrib_rate_rsaa = dplyr::if_else(RSAA_ELIGIBLE_B, contrib_rate, 0),
      match_rate_share = dplyr::case_when(
        !RSAA_ELIGIBLE_B ~ 0,
        contrib_rate_rsaa <= constants$rsaa_match_kink1 ~
          constants$rsaa_match_rate_below_k1 * contrib_rate_rsaa,
        TRUE ~
          constants$rsaa_match_rate_below_k1 * constants$rsaa_match_kink1 +
          constants$rsaa_match_rate_between * (contrib_rate_rsaa - constants$rsaa_match_kink1)
      ),
      RSAA_MATCH_CREDIT = match_rate_share * GROSS_INCOME,
      RSAA_AUTO_CREDIT = dplyr::if_else(
        RSAA_ELIGIBLE_B,
        constants$rsaa_auto_credit_rate * GROSS_INCOME,
        0
      ),
      RSAA_CREDIT_RAW = RSAA_MATCH_CREDIT + RSAA_AUTO_CREDIT,
      RSAA_EXCESS = pmax(GROSS_INCOME - rsaa_phaseout_amount, 0),
      RSAA_CAP = pmax(rsaa_credit_limit_base - constants$rsaa_phaseout_slope * RSAA_EXCESS, 0),
      RSAA_GOVT_CONTRIB = dplyr::if_else(
        RSAA_ELIGIBLE_B,
        pmin(RSAA_CREDIT_RAW, RSAA_CAP),
        0
      ),
      RSAA_RECEIVES_BENEFIT_B = RSAA_ELIGIBLE_B & RSAA_GOVT_CONTRIB > 0,
      OVERLAP_C = SM_ELIGIBLE_A & RSAA_ELIGIBLE_B,
      OVERLAP_C_DC = OVERLAP_C & HAS_IRA,
      income_cell_sm = make_income_cell_sm(SM_INCOME, SM_LOWER_THRESH, SM_UPPER_THRESH),
      income_cell_rsaa = make_income_cell_rsaa(GROSS_INCOME, constants$median_income, rsaa_ceiling),
      rsaa_positive_benefit_ceiling = rsaa_ceiling
    )

  work
}


# ----------------------------------------------------------------------------
# compute_match_rate() -- the match-rate schedule for the 04 Universal Account +
# Saver's Match hybrid simulation.
# ----------------------------------------------------------------------------
# Added 2026-05-27 with explicit approval (per the R-style rule against
# unnecessary custom functions). The schedule is reused in 04_03 (cost
# simulation), 04_05 (figures), and 04_06 (phaseout lenses); inlining it
# repeatedly creates a real drift risk.
#
# REPARAMETERIZED 2026-08-04 TO ENDPOINT FORM. The schedule is now stated with
# TWO numbers and no interior reference point:
#
#   200 percent match at $0 income, declining in a straight line to
#   0 percent match at the DESIGNATED ENDPOINT.
#
#   rate(income) = R_max * (1 - income / E),  clamped to [0, R_max]
#   slope        = -R_max / E                 percentage points per dollar
#
# where R_max = max_rate_pp_num (200) and E = the filing group's designated
# endpoint. That is the whole schedule. There is no "pivot" and no "anchor".
#
#   match_rate
#       |
#   200%|*   <- R_max, the rate at income = 0 and the clamp ceiling
#       | \
#       |  \
#       |   \
#     0%|----*------- the DESIGNATED ENDPOINT: rate reaches zero
#       +----+------- income
#       0    E
#
# WHAT WAS REMOVED AND WHY. The retired parameterization described this same line
# by an interior 50-percent crossing (the "pivot") plus a rule deriving that pivot
# from an external median (the "anchor"): "200 percent floor, 75 percent at
# two-thirds of the IRS single-filer median AGI, which places the 50-percent
# crossing at 0.8x that median and the zero crossing at 1.067x." Three clauses and
# two carried constants to describe a line that two numbers pin exactly. The
# pivot_rate_pp_num argument is gone; `endpoint_table` replaces `pivot_table`.
#
# AUDIT BRIDGE TO THE RETIRED FORM (for reconciling pre-2026-08-04 outputs only;
# not a live concept): old_pivot = 0.75 * endpoint, equivalently
# endpoint = (4/3) * old_pivot. The two produce a numerically identical schedule,
# so any figure computed under the old parameterization can be mapped across.
#
# FILING-STATUS STRUCTURE (unchanged). Endpoints scale from Single by the statutory
# IRC sec 6433 ratios: MFJ = 2.0 x Single, HoH = 1.5 x Single (mirroring the
# enacted thresholds, MFJ $41,000 / Single $20,500 = 2.0 and HoH $30,750 /
# $20,500 = 1.5). 04_02 sets the endpoint vector; this function is agnostic about
# where it came from.
#
# HOW THE FUNCTION IS USED:
#   endpoint_table is a named numeric vector keyed by filing_group_chr:
#     c(single_mfs = ..., mfj = ..., hoh = ...)
#   filing_group_chr is the output of make_filing_group(EFSTATUS).
#   match_rate is returned as a percentage (0 to 200), not a proportion.
#   Match per worker is then min(match_rate / 100 * contribution, 1000).
#
# ARGUMENTS:
#   magi_num          numeric vector of income on the schedule's basis (one per
#                     row). Nominal dollars of the SIPP reference year under the
#                     2026-08-04 respecification -- NOT projected.
#   filing_group_chr  character vector of filing-group labels ("single_mfs",
#                     "mfj", "hoh", or NA_character_), same length as magi_num.
#   endpoint_table    named numeric vector of designated endpoints, e.g.
#                     c(single_mfs = 44045, mfj = 88090, hoh = 66068).
#   max_rate_pp_num   scalar; the maximum match rate in percentage points -- the
#                     rate at income = 0 and the schedule's clamp ceiling.
#                     Default 200 (the current design).
#
# RETURNS:
#   numeric vector of match rates (0 to max_rate_pp_num percentage points), same
#   length as magi_num. Rows with NA filing_group_chr, an unmapped filing group,
#   or NA magi_num return NA_real_ -- never 0, so downstream aggregations cannot
#   silently zero-fill an unresolved row.
#
# DEFENSIVE BEHAVIOR:
#   - Stops if endpoint_table is missing any of the three expected names.
#   - Stops if any endpoint is non-positive or NA (divide-by-zero, or a schedule
#     that never declines).
#   - Stops unless max_rate_pp_num > 0.
#   - The upper pmin() enforces the design ceiling, so a worker with negative
#     income (a business loss) is held at the max rate rather than drawn above it.
compute_match_rate <- function(magi_num, filing_group_chr, endpoint_table,
                               max_rate_pp_num = 200) {
  required_groups_chr <- c("single_mfs", "mfj", "hoh")
  if (!all(required_groups_chr %in% names(endpoint_table))) {
    stop(sprintf(
      "endpoint_table is missing expected filing-group entries. Got: %s. Need: %s.",
      paste(names(endpoint_table), collapse = ", "),
      paste(required_groups_chr, collapse = ", ")
    ), call. = FALSE)
  }
  if (any(endpoint_table[required_groups_chr] <= 0, na.rm = TRUE) ||
      any(is.na(endpoint_table[required_groups_chr]))) {
    stop("endpoint_table entries must be strictly positive and non-NA.", call. = FALSE)
  }
  if (length(max_rate_pp_num) != 1L || is.na(max_rate_pp_num) ||
      max_rate_pp_num <= 0) {
    stop(sprintf("max_rate_pp_num must be a single positive value. Got: %s.",
                 paste(max_rate_pp_num, collapse = ", ")), call. = FALSE)
  }

  # Designated endpoint for each row (NA if filing group is missing or unmapped).
  endpoint_num <- dplyr::case_when(
    filing_group_chr == "single_mfs" ~ endpoint_table[["single_mfs"]],
    filing_group_chr == "mfj"        ~ endpoint_table[["mfj"]],
    filing_group_chr == "hoh"        ~ endpoint_table[["hoh"]],
    TRUE                             ~ NA_real_
  )

  # The straight line, clamped to [0, R_max]. pmax(0, .) floors it at the
  # endpoint so higher-income workers receive no match; pmin(R_max, .) enforces
  # the ceiling. NA propagates: any NA input yields NA output.
  rate_unclamped_num <- dplyr::if_else(
    is.na(magi_num) | is.na(endpoint_num),
    NA_real_,
    max_rate_pp_num * (1 - magi_num / endpoint_num)
  )

  pmin(max_rate_pp_num, pmax(0, rate_unclamped_num))
}

# ----------------------------------------------------------------------------
# Backward-compatibility alias. The constants accessor was renamed from
# rsaa_calibration_constants() to sm_calibration_constants() on 2026-06-08
# (it returns Saver's Match thresholds, not RSAA constants). The old name is
# retained as an alias so any external/legacy caller keeps working.
# ----------------------------------------------------------------------------
rsaa_calibration_constants <- sm_calibration_constants
