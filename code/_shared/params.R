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

  # --- Automatic seed contribution (universal-hybrid scenario; added 2026-07-28) ---
  # Flat annual federal deposit to the account of EVERY hybrid-eligible worker,
  # paid whether or not the worker contributes or participates (so its cost is
  # invariant to take-up assumptions and it does not count toward the $1,000
  # match cap). TY2027 nominal dollars; like the statutory thresholds it is a
  # policy parameter and is NOT scaled by income_projection_factor.
  # Phased variants (added 2026-07-28) share the same $100 maximum and derive
  # their geometry from the hybrid match schedule (pivot/endpoint carried in
  # pivot_table.rds):
  #   flat            -- $100 for every eligible worker (the headline design)
  #   pro_rata        -- $100 x match_rate / max_rate (declines along the line)
  #   flat_then_taper -- $100 to the pivot, then linear to $0 at the endpoint
  #   extended_taper  -- $100 across the eligible band, then linear to $0 at
  #                      seed_extended_endpoint_mult x the endpoint
  auto_seed_amount <- 100
  seed_extended_endpoint_mult <- 1.25

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
    auto_seed_amount = auto_seed_amount,
    seed_extended_endpoint_mult = seed_extended_endpoint_mult,
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
    auto_seed_amount >= 0,
    seed_extended_endpoint_mult > 1,
    # m200 lower must equal 2x base lower (derived, but assert the contract)
    all(abs(threshold_lower_by_multiplier$m200 - 2 * threshold_lower) < 1e-9)
  )

  params
}

# ----------------------------------------------------------------------------
# rsaa_params() -- S.1526 (119th Congress) Government Match Tax Credit (§25F)
# constants, for the common-basis RSAA-vs-hybrid comparison (03d_rsaa_comparison.R).
#
# Verified against the bill text (economist-panel/_shared/sources/rsaa-s1526-119th-bill-text.pdf),
# §25F and §2(15), 2026-07-13. See drafts/rsaa_comparison/00_comparison_design_spec.md.
# Kept SEPARATE from sm_params() so the canonical modeled frame is never touched by
# RSAA logic; the RSAA module reads sipp_modeled.parquet and computes fresh from these.
# ----------------------------------------------------------------------------
rsaa_params <- function() {
  # §25F(a)(1): 1% automatic credit on gross income.
  auto_credit_rate <- 0.01
  # §25F(b): applicable percentage on contributions, by tier of gross income.
  match_rate_below_kink1 <- 1.00   # 100% of contributions up to 3% of gross income
  match_rate_between      <- 0.50   # 50% of contributions from 3% to 5%
  match_kink1 <- 0.03               # 3% of gross income
  match_kink2 <- 0.05               # 5% of gross income (above this, 0%)

  # §25F(c)(1): credit limit = 5% of the phaseout amount (a filing-status constant).
  credit_limit_share <- 0.05
  # §25F(c)(2): limit reduced $75 for each $1,000 (or portion) of gross income over the
  # phaseout amount.
  phaseout_slope <- 75 / 1000

  # §25F(c)(3): phaseout amount = multiple of applicable median income M by filing status.
  #   MFJ = 2.0 M ; HoH = 3/4 of MFJ = 1.5 M ; any other (single/MFS) = 1/2 of MFJ = 1.0 M.
  phaseout_mult <- c(Single = 1.0, MFS = 1.0, HoH = 1.5, MFJ = 2.0)

  # §25F(c)(4): applicable median income M = most recent Census CPS Median Personal Income,
  # population 15+. Base value adopted from params.R median_income_2024 ($45,140, 2023 CPS
  # basis; confirm vintage against Census PINC-01 in methodology review), projected to TY2027
  # by the repo-wide 1.093 factor so M sits at the same price level as personal_income_2027.
  median_income_base_2024 <- 45140
  income_projection_factor <- 1.093
  applicable_median_income_2027 <- median_income_base_2024 * income_projection_factor

  # Statutory auto-enrollment default contribution rate (§104(a)(2)); headline for both designs.
  default_contribution_rate <- 0.03

  list(
    auto_credit_rate = auto_credit_rate,
    match_rate_below_kink1 = match_rate_below_kink1,
    match_rate_between = match_rate_between,
    match_kink1 = match_kink1,
    match_kink2 = match_kink2,
    credit_limit_share = credit_limit_share,
    phaseout_slope = phaseout_slope,
    phaseout_mult = phaseout_mult,
    median_income_base_2024 = median_income_base_2024,
    income_projection_factor = income_projection_factor,
    applicable_median_income_2027 = applicable_median_income_2027,
    default_contribution_rate = default_contribution_rate
  )
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
