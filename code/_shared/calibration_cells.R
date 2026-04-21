rsaa_calibration_constants <- function() {
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

build_modeled_sipp_frame <- function(raw, seed = 42L) {
  constants <- rsaa_calibration_constants()
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
      PARTICIPATING = dplyr::case_when(
        ESCNTYN_401 == 1 ~ "Yes",
        EECNTYN_401 == 1 ~ "Yes",
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
      RSAA_ELIGIBLE_B = rsaa_base_worker & ANY_RETIREMENT_ACCESS == "No"
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
