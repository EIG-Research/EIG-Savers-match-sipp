# params.R -- single source of truth for every policy and methodology constant.
#
# This is the ONLY place Saver's Match thresholds, rates, caps, projection scalars,
# contribution distributions, take-up rates, multipliers, and external benchmarks are
# defined. Every R stage reads them via `sm_params()`; the Python port (if ever revived)
# reads the JSON emitted by `write_sm_params_json()`. Doubled / multiplier thresholds are
# DERIVED here, never hard-coded, so they cannot drift from the base thresholds.
#
# Replaces the former triplicate sources: calibration_cells.R::sm_calibration_constants(),
# 03a's inline `sm_params` list, and the hard-coded literals in the (retired) Python port.

# ----------------------------------------------------------------------------
# sm_params() -- return the immutable canonical parameter set.
# ----------------------------------------------------------------------------
sm_params <- function() {

  # --- Statutory Saver's Match parameters (SECURE 2.0 §103; effective TY2027) ---
  # Lower bound = full-match ceiling; upper bound = any-match (phase-out) ceiling.
  # These are the STATIC statutory nominal amounts (IRC §6433(b)(3)): MFJ applicable
  # amount $41,000 with a $30,000 phaseout range; Single = 1/2, HoH = 3/4 of MFJ.
  # They are NOT projected: §6433(h)(1) indexes them only for taxable years beginning
  # after 2027 (base year 2026), so the TY2027 values are these literal amounts.
  # The 1.093 projection (decision D1) is applied to INCOME, not to these thresholds,
  # so TY2027 incomes are compared against the fixed TY2027 thresholds. See
  # Infrastructure/specs/2026-04-18_savers_match_eligibility_buckets_methodology.md, Section 10.
  threshold_lower <- c(Single = 20500, MFJ = 41000, HoH = 30750, MFS = 20500)
  threshold_upper <- c(Single = 35500, MFJ = 71000, HoH = 53250, MFS = 35500)
  match_rate_max  <- 0.50    # 50% federal match on eligible contributions
  contribution_cap <- 2000   # max eligible contribution per filer ($)

  # --- AGI-threshold multipliers (current law + expanded counterfactuals) ---
  # All multiplier/doubled thresholds are derived from the base, never stored.
  multipliers <- c(m100 = 1.00, m125 = 1.25, m150 = 1.50, m200 = 2.00)
  threshold_lower_by_multiplier <- lapply(multipliers, function(m) threshold_lower * m)
  threshold_upper_by_multiplier <- lapply(multipliers, function(m) threshold_upper * m)

  # --- Income projection: SIPP 2024 reference -> TY2027 nominal ---
  # CBO/JCT nominal wage growth ~3%/yr; (1.03)^3 ≈ 1.093. Adopted repo-wide
  # (decision D1, 2026-06-08): incomes AND contribution amounts are projected to
  # 2027 and compared to statutory 2027 thresholds. Used by BOTH eligibility and cost.
  income_projection_factor <- 1.093

  # --- Participation / take-up scalars ---
  # no_auto: IRS Saver's Credit utilization (TY2021): 8.4M claimants / ~147M returns ≈ 5.7%.
  # auto_enroll: industry auto-enrollment participation (Vanguard HAS 2024 ≈ 80-93%).
  takeup_no_auto     <- 0.057
  takeup_auto_enroll <- 0.80

  # --- Universe sub-population caps (used to flag students / dependents) ---
  # 2024 nominal dollars. Previously hard-coded identically in 4 scripts.
  student_earnings_cap  <- 15000
  dependent_earnings_cap <- 5050

  # --- Average annual DC contribution by income band (active contributors, 2024 $) ---
  # Back-calculated from IRS SOI Table 1 TY2022 (data/raw/irs_soi/22in01pl.xls).
  # Scaled to 2027 by income_projection_factor; the $2,000 cap applies after scaling.
  contribution_bands <- data.frame(
    band_label       = c("under_25k", "25k_to_37k", "37k_to_55k", "55k_and_up"),
    income_lo_2024   = c(0,           25000,        37000,        55000),
    income_hi_2024   = c(25000,       37000,        55000,        Inf),
    avg_contrib_2024 = c(650,         1350,         2200,         3500),
    stringsAsFactors = FALSE
  )

  # --- Contribution-rate distribution for universal-access (no existing plan) workers ---
  # Rates are fractions of personal income; shares sum to 1.
  # Two named splits (previously the cryptic "JCT" vs "RSAA" infix):
  #   jct  = 15/60/25  -> tilted to the 3% default (Saver's Match alone, no auto-escalation)
  #   alt  = 15/25/60  -> tilted to 5% (RSAA-style auto-enrollment + default escalation)
  contribution_rates       <- c(0.01, 0.03, 0.05)
  contribution_split_jct   <- c(0.15, 0.60, 0.25)
  contribution_split_alt   <- c(0.15, 0.25, 0.60)

  # --- Age window and reference medians ---
  age_min <- 18L
  age_max <- 65L
  median_income_2024 <- 45140   # weighted median personal income, calibration reference

  # --- External benchmarks (JCT JCX-21-22; reconciliation only, not estimated here) ---
  jct_total_fy2028_2032_M <- 9318
  jct_annual_M <- c(FY2028 = 2097, FY2029 = 1907, FY2030 = 1819, FY2031 = 1807, FY2032 = 1687)

  params <- list(
    threshold_lower = threshold_lower,
    threshold_upper = threshold_upper,
    match_rate_max = match_rate_max,
    contribution_cap = contribution_cap,
    multipliers = multipliers,
    threshold_lower_by_multiplier = threshold_lower_by_multiplier,
    threshold_upper_by_multiplier = threshold_upper_by_multiplier,
    income_projection_factor = income_projection_factor,
    takeup_no_auto = takeup_no_auto,
    takeup_auto_enroll = takeup_auto_enroll,
    student_earnings_cap = student_earnings_cap,
    dependent_earnings_cap = dependent_earnings_cap,
    contribution_bands = contribution_bands,
    contribution_rates = contribution_rates,
    contribution_split_jct = contribution_split_jct,
    contribution_split_alt = contribution_split_alt,
    age_min = age_min,
    age_max = age_max,
    median_income_2024 = median_income_2024,
    jct_total_fy2028_2032_M = jct_total_fy2028_2032_M,
    jct_annual_M = jct_annual_M
  )

  # --- Internal consistency assertions (fail fast on a bad edit) ---
  stopifnot(
    all(c("Single","MFJ","HoH","MFS") %in% names(threshold_lower)),
    all(threshold_upper > threshold_lower),
    abs(sum(contribution_split_jct) - 1) < 1e-9,
    abs(sum(contribution_split_alt) - 1) < 1e-9,
    length(contribution_rates) == length(contribution_split_jct),
    match_rate_max > 0, contribution_cap > 0, income_projection_factor > 0,
    # m200 lower must equal 2x base lower (derived, but assert the contract)
    all(abs(threshold_lower_by_multiplier$m200 - 2 * threshold_lower) < 1e-9)
  )

  params
}

# ----------------------------------------------------------------------------
# write_sm_params_json() -- emit the canonical params to data/processed/params.json
# so any non-R consumer reads the same source of truth.
# ----------------------------------------------------------------------------
write_sm_params_json <- function(path_chr) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    warning("jsonlite not available; skipping params.json emission.")
    return(invisible(NULL))
  }
  p <- sm_params()
  # contribution_bands is a data.frame; jsonlite handles it as records.
  jsonlite::write_json(p, path_chr, pretty = TRUE, auto_unbox = TRUE, dataframe = "rows")
  invisible(path_chr)
}
