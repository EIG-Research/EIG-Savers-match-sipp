# build_frame.R -- the ONE canonical modeled-frame builder.
#
# build_modeled_frame(raw, params) returns a single person-level (December
# reference-month) frame with clean snake_case columns that every stage reads.
# It replaces the inline frame re-derivations in 02a, 02b, 03a, and 04_01.
#
# Design (decision D1, 2026-06-08): income is projected to TY2027 (x1.093) ONCE,
# and the Saver's Match factor is computed on projected income vs statutory 2027
# thresholds. Eligibility and cost therefore share one construct.
#
# Implementation note: this function builds on the validated
# `build_modeled_sipp_frame_v2()` (in calibration_cells.R) for the 2024-base
# columns (Option B income, U1 spouse-pair MFJ income, access flags), then adds
# the projection and the multiplier ladder. Wrapping the validated builder (rather
# than re-deriving it) is deliberate: it guarantees the cost path stays identical
# to the prior 03a results while giving every consumer one entry point.
# Requires: calibration_cells.R and params.R already sourced.

build_modeled_frame <- function(raw, params = sm_params(), seed = 42L) {

  base <- build_modeled_sipp_frame_v2(raw, seed = seed)

  mult_names <- names(params$multipliers)            # m100, m125, m150, m200
  scalar     <- params$income_projection_factor      # 1.093

  fr <- base |>
    dplyr::transmute(
      # --- identifiers & weight ---
      ssuid = SSUID,
      pnum  = PNUM,
      weight = WPFINWGT,
      age = TAGE,
      efstatus = EFSTATUS,                    # raw SIPP filing-status code (1/2/3/4)
      spouse_pnum = EPNSPOUSE,                # within-SSUID spouse pointer (for filer-basis collapse)
      filing_group = filing_group,            # "single_mfs" / "mfj" / "hoh"
      filing_status = FILING_STATUS,          # "Single" / "MFJ" / "MFS" / "HoH"

      # --- income: 2024 base (for contribution bands) and TY2027 projection (D1) ---
      sm_income_2024       = SM_INCOME,            # MFJ-aware (U1 spouse-pair) base, 2024 nominal
      earnings_2027        = tpearn_annual_num * scalar,
      personal_income_2027 = tptotinc_annual_num * scalar,
      sm_income_2027       = SM_INCOME * scalar,   # MFJ-aware (U1 spouse-pair) base, projected

      # --- universe sub-population flags (broad universe = 02a/03a-aligned) ---
      has_earned_income = dplyr::coalesce(tpearn_annual_num > 0, FALSE),
      is_student  = dplyr::case_when(
        !is.na(RENROLL) & RENROLL == 1 & !is.na(EEDFTPT) & EEDFTPT == 1 ~ TRUE,
        age >= 18 & age <= 23 & EEDUC < 40 &
          dplyr::coalesce(tpearn_annual_num, 0) < params$student_earnings_cap ~ TRUE,
        TRUE ~ FALSE
      ),
      is_dependent = dplyr::case_when(
        age < 19 ~ TRUE,
        age >= 19 & age <= 23 & is_student &
          dplyr::coalesce(tpearn_annual_num, 0) < params$dependent_earnings_cap ~ TRUE,
        TRUE ~ FALSE
      ),
      in_universe = age >= 18L & !is_dependent & !is_student &
        has_earned_income & !is.na(filing_group),

      # --- worker-class sub-flags (used for the universal-hybrid ROUTING in 04_03, not as a filter) ---
      is_private_sector_employee = (EJB1_JBORSE == 1L) & (EJB1_CLWRK %in% c(5L, 6L)),
      is_self_employed = (EJB1_JBORSE == 2L),

      # --- retirement-account access ---
      # Coerce NA -> FALSE: "has a DC account" is a definite flag (no evidence = no account).
      # This matches the prior 04 hybrid behavior and is neutral for cost eligibility
      # (is_anymatch & NA was already treated as not-eligible by the scenario engine).
      has_dc_account = dplyr::coalesce(HAS_EXISTING_DC, FALSE),
      any_retirement_access = any_retirement_access_v2_chr,   # "Yes"/"No"/"Missing" (employer-offer aware; for hybrid routing)
      is_participating_dc = dplyr::case_when(
        ESCNTYN_401 == 1 ~ TRUE, EECNTYN_401 == 1 ~ TRUE,
        ESCNTYN_IRA == 1 ~ TRUE, EECNTYN_IRA == 1 ~ TRUE,
        ESCNTYN_401 == 2 & EECNTYN_401 == 2 & ESCNTYN_IRA == 2 & EECNTYN_IRA == 2 ~ FALSE,
        HAS_EXISTING_DC == TRUE ~ FALSE,
        TRUE ~ NA
      ),

      # carry the 2024-base contribution-rate draw for cost stages (Phase 4)
      contrib_rate_draw = u_contrib
    )

  # --- multiplier ladder: thresholds, factor, eligibility per multiplier ---
  # For each multiplier m: lower/upper scale by m; factor on projected income;
  # any-match = factor > 0 (income below upper); full-match = income <= lower.
  for (m in mult_names) {
    lower_vec <- params$threshold_lower_by_multiplier[[m]]   # named Single/MFJ/HoH/MFS
    upper_vec <- params$threshold_upper_by_multiplier[[m]]
    lower_col <- dplyr::case_when(
      base$EFSTATUS %in% c(1, 3) ~ lower_vec[["Single"]],
      base$EFSTATUS == 2 ~ lower_vec[["MFJ"]],
      base$EFSTATUS == 4 ~ lower_vec[["HoH"]],
      TRUE ~ NA_real_
    )
    upper_col <- dplyr::case_when(
      base$EFSTATUS %in% c(1, 3) ~ upper_vec[["Single"]],
      base$EFSTATUS == 2 ~ upper_vec[["MFJ"]],
      base$EFSTATUS == 4 ~ upper_vec[["HoH"]],
      TRUE ~ NA_real_
    )
    factor_col <- pmax(0, pmin(1, (upper_col - fr$sm_income_2027) / (upper_col - lower_col)))
    is_anymatch  <- fr$in_universe & !is.na(factor_col) & factor_col > 0
    is_fullmatch <- fr$in_universe & !is.na(fr$sm_income_2027) & fr$sm_income_2027 <= lower_col

    fr[[paste0("threshold_lower_", m)]] <- lower_col
    fr[[paste0("threshold_upper_", m)]] <- upper_col
    fr[[paste0("sm_factor_", m)]] <- factor_col
    fr[[paste0("is_anymatch_", m)]] <- is_anymatch
    fr[[paste0("is_fullmatch_", m)]] <- is_fullmatch
    fr[[paste0("is_anymatch_with_account_", m)]]  <- is_anymatch  & fr$has_dc_account
    fr[[paste0("is_fullmatch_with_account_", m)]] <- is_fullmatch & fr$has_dc_account
    # DC-account-eligible (the JCT-baseline population): any-match AND holds a DC account.
    fr[[paste0("is_eligible_dc_", m)]] <- is_anymatch & fr$has_dc_account
  }

  # ===========================================================================
  # Cost columns -- per-person Saver's Match dollars under the two contribution
  # assumptions used by the cost stage (03a/03b). Folded here so the cost
  # stages become thin run_scenario() calls and cannot drift. Reproduces the
  # former 03a Sections 5 / 5B / 5C math.
  # ===========================================================================
  cap      <- params$contribution_cap          # 2000
  rate_max <- params$match_rate_max            # 0.50
  bands    <- params$contribution_bands

  # (a) Contribution-band assignment from 2024 SM income (band thresholds are 2024$);
  #     project to 2027 and cap. Defined for every worker.
  band_idx <- findInterval(fr$sm_income_2024, c(-Inf, bands$income_hi_2024)) # 1..4
  band_idx <- pmin(pmax(band_idx, 1L), nrow(bands))
  fr$contrib_for_sm <- pmin(bands$avg_contrib_2024[band_idx] * scalar, cap)

  # Band-based per-person match (JCT / DC-access scenarios), current-law factor.
  fr$sm_match_per_person <- fr$sm_factor_m100 * rate_max * fr$contrib_for_sm

  # (b) Universal-access contribution: DC holders keep their band amount; workers
  #     without a plan get a rate-split draw (1/3/5% by the JCT 15/60/25 shares)
  #     applied to projected personal income, then capped.
  rates  <- params$contribution_rates          # c(0.01, 0.03, 0.05)
  shares <- params$contribution_split_jct       # c(0.15, 0.60, 0.25)
  cum    <- cumsum(shares)
  set.seed(seed + 1L)                           # distinct draw from v2's band draw and run_scenario
  u_univ <- runif(nrow(fr))
  univ_rate <- dplyr::case_when(
    fr$has_dc_account %in% TRUE ~ NA_real_,
    u_univ <= cum[1] ~ rates[1],
    u_univ <= cum[2] ~ rates[2],
    TRUE ~ rates[3]
  )
  univ_contrib_for_sm <- dplyr::if_else(
    fr$has_dc_account %in% TRUE,
    fr$contrib_for_sm,
    pmin(univ_rate * fr$personal_income_2027, cap)
  )
  fr$univ_contrib_for_sm <- univ_contrib_for_sm

  # Universal per-person match per multiplier: only the factor varies by multiplier;
  # the per-worker contribution assignment does not.
  for (m in mult_names) {
    fr[[paste0("univ_sm_match_", m)]] <-
      fr[[paste0("sm_factor_", m)]] * rate_max * univ_contrib_for_sm
  }

  # (c) Alternative contribution split (15/25/60, tilted to 5%) for the robustness
  #     sweep. Same draw u_univ, different share cut-points.
  cum_alt <- cumsum(params$contribution_split_alt)
  univ_rate_alt <- dplyr::case_when(
    fr$has_dc_account %in% TRUE ~ NA_real_,
    u_univ <= cum_alt[1] ~ rates[1],
    u_univ <= cum_alt[2] ~ rates[2],
    TRUE ~ rates[3]
  )
  univ_contrib_for_sm_alt <- dplyr::if_else(
    fr$has_dc_account %in% TRUE,
    fr$contrib_for_sm,
    pmin(univ_rate_alt * fr$personal_income_2027, cap)
  )
  for (m in mult_names) {
    fr[[paste0("univ_sm_match_", m, "_alt")]] <-
      fr[[paste0("sm_factor_", m)]] * rate_max * univ_contrib_for_sm_alt
  }

  fr
}
