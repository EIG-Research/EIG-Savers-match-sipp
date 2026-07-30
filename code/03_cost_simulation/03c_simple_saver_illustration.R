# 03c_simple_saver_illustration -- multi-scenario nominal and real
#                                  accumulation for two illustrative savers,
#                                  with and without SECURE 2.0 Saver's Match
#                                  across four AGI-threshold multipliers
#                                  (1.0x, 1.25x, 1.5x, 2.0x), with
#                                  statute-correct threshold indexing per
#                                  IRC 6433(h).
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - For a single filer earning $30,000 at 5 percent and
#                     for a single filer earning $35,000 at 3 percent, both
#                     contributing from age 19 to age 58 (40 contribution
#                     years) into a TSP-like account, what is their
#                     end-of-career balance in nominal and real (year-1)
#                     dollars, and how much does the SECURE 2.0 Saver's
#                     Match add under the current-law single-filer AGI
#                     phase-out and under three alternative threshold
#                     multipliers (1.25x, 1.5x, 2.0x of the MFJ statutory
#                     anchors)?
#
# This script is intentionally STANDALONE and does not depend on any project
# microdata. It exists to anchor policy discussion in a concrete dollar
# illustration. Every assumption that drives the headline numbers is exposed
# as a top-level macro in the next section so the simulation can be rerun
# under alternative assumptions in seconds. Ten scenarios are run together
# so the contrast between own contribution and Saver's Match contribution is
# directly visible across both saver profiles and all four AGI-threshold
# multipliers, mirroring the four-multiplier contrast in
# Infrastructure/specs/2026-05-08_four-multiplier-contrast.md:
#   A         = $30,000 start, 5 percent own contribution, no Saver's Match
#   A_m100    = $30,000 start, 5 percent own contribution, Saver's Match @ 1.00x
#   A_m125    = $30,000 start, 5 percent own contribution, Saver's Match @ 1.25x
#   A_m150    = $30,000 start, 5 percent own contribution, Saver's Match @ 1.50x
#   A_m200    = $30,000 start, 5 percent own contribution, Saver's Match @ 2.00x
#   B         = $35,000 start, 3 percent own contribution, no Saver's Match
#   B_m100    = $35,000 start, 3 percent own contribution, Saver's Match @ 1.00x
#   B_m125    = $35,000 start, 3 percent own contribution, Saver's Match @ 1.25x
#   B_m150    = $35,000 start, 3 percent own contribution, Saver's Match @ 1.50x
#   B_m200    = $35,000 start, 3 percent own contribution, Saver's Match @ 2.00x
#
# Each multiplier scales BOTH the MFJ applicable dollar amount (which is
# then subject to statutory C-CPI-U indexing per IRC 6433(h)(1)) AND the
# MFJ phaseout range (which remains fixed at the multiplier-scaled value).
# The single-filer factor (50 percent), the $2,000 contribution cap, and
# the 50 percent match rate are unchanged across multipliers.
#
###################################################################
###                          Sources                            ###
###################################################################
#
# TSP fund returns (used to anchor ANNUAL_RETURN):
#   - Thrift Savings Plan, "Rates of Return," tsp.gov. 10-year annualized
#     lifecycle-fund returns run roughly 5-10 percent depending on horizon.
#   The 7.0 percent default is a conservative long-run balanced-portfolio
#   anchor that sits below recent L 2030 actuals and well below recent
#   L 2040 actuals; it is not an inception-to-date TSP figure.
#
# CBO wage-growth projection (used to anchor WAGE_GROWTH):
#   - Congressional Budget Office, The Budget and Economic Outlook: 2026 to
#     2036, February 11, 2026. CBO projects ECI for wages and salaries of
#     private-industry workers at roughly 3.5 percent in 2025, slowing
#     gradually but remaining above the 2.7 percent annual average observed
#     in 2015-2019. The 10-year window average implied by that path is
#     approximately 3.0 percent. Per Ben's instruction, this 10-year-window
#     average is then applied flat across years 11-40 of the saver's career,
#     which mechanically reduces to a single constant 3.0 percent nominal
#     wage-growth assumption for all 40 years.
#
# CPI-U (used as the NPV deflator for nominal-to-real conversion):
#   - CBO, The Budget and Economic Outlook: 2026 to 2036, February 11, 2026.
#   The 2.3 percent default is the long-run CPI-U projection in CBO's
#   outlook. Used ONLY as the price-index deflator for converting nominal
#   to real (year-1 / 2027) dollars. NOT used to index Saver's Match
#   thresholds: those use the statutory C-CPI-U index per IRC 6433(h).
#
# C-CPI-U (used to index the Saver's Match applicable dollar amount per
# the statutory mandate of IRC 6433(h) which references section 1(f)(3)):
#   - IRC 1(f)(3), as amended by Pub. L. 115-97 (Tax Cuts and Jobs Act,
#     2017), defines the cost-of-living adjustment using Chained CPI-U
#     (C-CPI-U), not CPI-U. C-CPI-U historically runs ~0.25 percentage
#     points lower than CPI-U.
#   - CBO long-run C-CPI-U projection ~ 2.0 percent (CBO Budget and
#     Economic Outlook 2026-2036).
#   The 2.0 percent default is therefore the statutory index applied to
#   the Saver's Match applicable dollar amount.
#
# SECURE 2.0 Saver's Match (statutory parameters, IRC 6433):
#   - Public Law 117-328, Division T, Section 103 ("Saver's Match"),
#     SECURE 2.0 Act of 2022. Effective for taxable years beginning after
#     December 31, 2026.
#   - 6433(a): Match equals the applicable percentage of qualified
#     retirement savings contributions "as does not exceed $2,000."
#     The $2,000 cap is fixed; it is NOT referenced in the inflation
#     adjustment subsection.
#   - 6433(b)(1): The applicable percentage is 50 percent.
#   - 6433(b)(3)(A): For joint returns and surviving spouses, the
#     applicable dollar amount is $41,000 and the phaseout range is
#     $30,000.
#   - 6433(b)(3)(B): Head of household = 3/4 of the (A) amounts; single
#     filers (and other non-joint, non-HoH filers) = 1/2 of the (A)
#     amounts.
#   - 6433(h)(1): "In the case of any taxable year beginning in a calendar
#     year after 2027, the $41,000 amount in subsection (b)(3)(A)(i) shall
#     be increased" by the COLA under section 1(f)(3) using calendar year
#     2026 as the base. ONLY the $41,000 applicable dollar amount is
#     indexed; the $30,000 phaseout range is FIXED. The $2,000
#     contribution cap and the $100 de minimis threshold are also fixed.
#   - 6433(h)(2): Any increase determined under (h)(1) shall be rounded
#     to the nearest multiple of $1,000. For single filers, the rounded
#     MFJ amount is then halved, so the single-filer threshold moves in
#     $500 increments.
#
###################################################################
###                       Setup                                 ###
###################################################################

rm(list = ls())
options(scipen = 999)
set.seed(42L)

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(tibble)
  library(ggplot2)
  library(scales)
  library(arrow)
  library(openxlsx)
})

# Resolve project root the same way run_all.R does so the script can be
# sourced interactively or run via Rscript.
local({
  root <- Sys.getenv("EIG_PROJECT_ROOT", unset = "")
  if (!nzchar(root)) {
    cur <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
    for (i in seq_len(10L)) {
      if (file.exists(file.path(cur, "PROJECT.md"))) {
        root <- cur
        break
      }
      parent <- normalizePath(file.path(cur, ".."), winslash = "/", mustWork = FALSE)
      if (identical(parent, cur)) break
      cur <- parent
    }
  }
  if (!nzchar(root) || !dir.exists(root)) {
    stop("Could not locate project root. Set EIG_PROJECT_ROOT or run from repo.", call. = FALSE)
  }
  Sys.setenv(EIG_PROJECT_ROOT = root)
})

path_project <- Sys.getenv("EIG_PROJECT_ROOT")
path_output_tbl <- file.path(path_project, "output", "tables", "appendix")
path_output_fig <- file.path(path_project, "output", "figures", "appendix")
dir.create(path_output_tbl, showWarnings = FALSE, recursive = TRUE)
dir.create(path_output_fig, showWarnings = FALSE, recursive = TRUE)

###################################################################
###                Macros - edit and rerun                      ###
###################################################################

# Career profile ----------------------------------------------------
START_AGE       <- 19L     # age at first contribution
END_AGE         <- 59L     # reporting age = one year after the final (age-58) contribution
YEARS_OF_SAVING <- 40L     # number of contribution years (ages 19..58)

# Account return ----------------------------------------------------
# Nominal annual return on the TSP-like account.
ANNUAL_RETURN <- 0.070

# Wage growth -------------------------------------------------------
# Nominal annual growth applied to baseline earnings each year.
WAGE_GROWTH <- 0.030

# CPI-U: NPV deflator only (nominal -> real / 2027 dollars). NOT used to
# index Saver's Match thresholds.
INFLATION <- 0.023

# Calendar anchor ---------------------------------------------------
base_year <- 2027L

# SECURE 2.0 Saver's Match statutory parameters --------------------
# These are the IRC 6433 base values. Single-filer values for the
# scenarios tibble below are derived from them via SM_SINGLE_FACTOR.
SM_BASE_YEAR              <- 2027L
SM_MFJ_AMOUNT_2027        <- 41000      # 6433(b)(3)(A)(i)
SM_MFJ_RANGE_2027         <- 30000      # 6433(b)(3)(A)(ii) -- FIXED
SM_HOH_FACTOR             <- 0.75       # 6433(b)(3)(B)(i)
SM_SINGLE_FACTOR          <- 0.50       # 6433(b)(3)(B)(ii)
SM_CONTRIB_CAP            <- 2000       # 6433(a) -- FIXED
SM_MATCH_RATE             <- 0.50       # 6433(b)(1)

# C-CPI-U projection used per 6433(h)(1) reference to section 1(f)(3).
# Distinct from CPI-U above (which is the NPV deflator).
SM_THRESHOLD_INFLATION    <- 0.020

# Per 6433(h)(2): the increase in the MFJ applicable dollar amount is
# rounded to the nearest multiple of $1,000. Set ROUND_BASE = 0 to
# disable rounding for sensitivity checks.
SM_THRESHOLD_ROUND_BASE   <- 1000

# Threshold multipliers -------------------------------------------
# Each multiplier scales BOTH the MFJ applicable dollar amount AND the
# MFJ phaseout range at the TY2027 base. Statutory C-CPI-U indexing
# per IRC 6433(h) is then applied to the multiplier-scaled MFJ amount.
# Single-filer thresholds inherit via SM_SINGLE_FACTOR. The 1.00x
# multiplier reproduces current law; the 2.00x multiplier reproduces
# the prior "doubled-threshold" counterfactual.
SM_MULTIPLIERS_NUM <- c(1.00, 1.25, 1.50, 2.00)
# Retained for documentary continuity with the prior two-design script
# and with Infrastructure/specs/2026-05-08_four-multiplier-contrast.md;
# the 2.0x case is now generated from SM_MULTIPLIERS_NUM rather than
# these scalars.
DT_AMOUNT_MULTIPLIER      <- 2.0
DT_RANGE_MULTIPLIER       <- 2.0

# Contribution timing -----------------------------------------------
CONTRIBUTION_TIMING <- "end_of_year"

# Targeted comparison-only government match -------------------------
# Separate from current-law Saver's Match. Used only for the
# standalone $33,350 @ 3 percent comparison export below.
DOLLAR_MATCH_CAP <- 1000L

# RSAA (S.1526, 119th Congress) Government Match Tax Credit (§25F) ---
# Added for the four-design comparison column. Verified against the bill text
# (economist-panel/_shared/sources/rsaa-s1526-119th-bill-text.pdf); mirrors
# rsaa_params() in code/_shared/params.R. See drafts/rsaa_comparison/00_comparison_design_spec.md.
#   credit = 1% of gross income + 100% of contributions up to 3% of income
#            + 50% of contributions from 3-5%, capped at 5% of the phaseout amount,
#            reduced $75 per $1,000 of income over the phaseout amount.
# Single-filer phaseout amount = applicable median income M (CPS median personal income,
# 15+); base $45,140 (2023) projected to TY2027 by 1.093. M is indexed forward at WAGE_GROWTH
# (median personal income is republished annually and tracks nominal wage growth, not C-CPI-U).
RSAA_AUTO_CREDIT_RATE     <- 0.01
RSAA_MATCH_RATE_BELOW_K1  <- 1.00
RSAA_MATCH_RATE_BETWEEN   <- 0.50
RSAA_MATCH_KINK1          <- 0.03
RSAA_MATCH_KINK2          <- 0.05
RSAA_CREDIT_LIMIT_SHARE   <- 0.05
RSAA_PHASEOUT_SLOPE       <- 75 / 1000
RSAA_MEDIAN_INCOME_2027   <- 45140 * 1.093   # single-filer phaseout amount at TY2027 (base year)

# Output toggles ----------------------------------------------------
# WRITE_FIGURE is FALSE for the 2026-05-11 four-multiplier extension
# round: ten scenarios on a single panel would be unreadable. A faceted
# redesign is deferred per the plan at
# Infrastructure/plans/2026-05-11_03h-four-multiplier-extension.md.
WRITE_TABLE  <- TRUE
WRITE_XLSX   <- TRUE
WRITE_FIGURE <- FALSE

# Bridge check ------------------------------------------------------
# Path to the pre-change summary snapshot. If present, the bridge
# block at the end of the verification section asserts post-change
# _m100 and _m200 final balances match pre-change _CL and _2X final
# balances to the dollar. Set to NA_character_ to skip the check.
BRIDGE_SNAPSHOT_PATH <- file.path(
  Sys.getenv("EIG_PROJECT_ROOT"),
  "temp", "2026-05-11_03h-bridge",
  "simple_saver_illustration_summary_PRE.rds"
)

###################################################################
###                Scenarios to run                             ###
###################################################################

# Each match scenario carries the MFJ-level statutory anchors that drive
# its threshold pair. The single-filer lower threshold for any year is
# SM_SINGLE_FACTOR x (indexed and rounded MFJ applicable dollar amount).
# The phaseout range is FIXED at SM_SINGLE_FACTOR x (multiplier-scaled MFJ
# range). Non-1.0x scenarios pre-multiply both anchors at TY2027; the
# same statutory indexing rule then applies to the scaled values.
#
# 1) Build the saver profile tibble. Two illustrative single filers.
saver_profiles_tbl <- tibble(
  saver_profile_chr = c("A_30k_5pct", "B_35k_3pct"),
  start_earnings_num = c(30000, 35000),
  savings_rate_num   = c(0.05, 0.03)
)

# 2) Build the design tibble. Five designs per saver: a no-match
#    baseline plus the four AGI-threshold multipliers. The design_id_chr
#    is empty for no-match and "_match_m<NNN>" for the match designs,
#    so the assembled scenario_id reads e.g. "A_30k_5pct_match_m125".
designs_tbl <- bind_rows(
  tibble(
    design_id_chr      = "",
    design_label_chr   = "no match",
    apply_match_flag   = FALSE,
    multiplier_num     = NA_real_
  ),
  tibble(
    design_id_chr      = sprintf("_match_m%03d", round(SM_MULTIPLIERS_NUM * 100)),
    design_label_chr   = sprintf("Saver's Match @ %.2fx", SM_MULTIPLIERS_NUM),
    apply_match_flag   = TRUE,
    multiplier_num     = SM_MULTIPLIERS_NUM
  )
)

# 3) Assemble the cross-join of profiles x designs. Earnings-rate labels
#    are reconstructed here for the human-readable scenario_label.
scenarios <- saver_profiles_tbl |>
  mutate(
    profile_label_chr = sprintf(
      "$%dK @ %d%%",
      as.integer(start_earnings_num / 1000),
      as.integer(round(savings_rate_num * 100))
    )
  ) |>
  tidyr::expand_grid(designs_tbl) |>
  mutate(
    scenario_id        = paste0(saver_profile_chr, design_id_chr),
    scenario_label     = paste0(profile_label_chr, ", ", design_label_chr),
    mfj_amount_2027_num = if_else(
      apply_match_flag,
      SM_MFJ_AMOUNT_2027 * multiplier_num,
      NA_real_
    ),
    mfj_range_2027_num  = if_else(
      apply_match_flag,
      SM_MFJ_RANGE_2027 * multiplier_num,
      NA_real_
    )
  ) |>
  select(
    scenario_id, scenario_label, saver_profile_chr,
    start_earnings_num, savings_rate_num,
    apply_match_flag, multiplier_num,
    mfj_amount_2027_num, mfj_range_2027_num
  )

###################################################################
###                Input validation                             ###
###################################################################

stopifnot(
  is.integer(START_AGE), is.integer(END_AGE), is.integer(YEARS_OF_SAVING),
  YEARS_OF_SAVING == (END_AGE - START_AGE),
  ANNUAL_RETURN > -0.5, ANNUAL_RETURN < 0.5,
  WAGE_GROWTH  > -0.1, WAGE_GROWTH  < 0.2,
  INFLATION    >  0,    INFLATION    < 0.2,
  SM_THRESHOLD_INFLATION > 0, SM_THRESHOLD_INFLATION < 0.2,
  SM_THRESHOLD_ROUND_BASE >= 0,
  SM_MFJ_AMOUNT_2027 > 0, SM_MFJ_RANGE_2027 > 0,
  SM_CONTRIB_CAP > 0,
  SM_MATCH_RATE > 0, SM_MATCH_RATE <= 1,
  SM_SINGLE_FACTOR > 0, SM_SINGLE_FACTOR <= 1,
  DOLLAR_MATCH_CAP >= 0,
  DT_AMOUNT_MULTIPLIER >= 1, DT_RANGE_MULTIPLIER >= 1,
  is.numeric(SM_MULTIPLIERS_NUM),
  length(SM_MULTIPLIERS_NUM) >= 1L,
  all(SM_MULTIPLIERS_NUM >= 1),
  !any(duplicated(SM_MULTIPLIERS_NUM)),
  # 1.0x and 2.0x must remain in the vector so the bridge check has a
  # baseline to compare against.
  any(abs(SM_MULTIPLIERS_NUM - 1.00) < 1e-9),
  any(abs(SM_MULTIPLIERS_NUM - 2.00) < 1e-9),
  SM_BASE_YEAR == base_year,
  CONTRIBUTION_TIMING == "end_of_year",
  nrow(scenarios) >= 1L,
  all(scenarios$start_earnings_num > 0),
  all(scenarios$savings_rate_num > 0 & scenarios$savings_rate_num < 1),
  is.logical(scenarios$apply_match_flag),
  !any(duplicated(scenarios$scenario_id)),
  all(!scenarios$apply_match_flag |
        (!is.na(scenarios$mfj_amount_2027_num) &
         !is.na(scenarios$mfj_range_2027_num) &
         scenarios$mfj_amount_2027_num > 0 &
         scenarios$mfj_range_2027_num  > 0))
)

###################################################################
###                Run scenarios                                ###
###################################################################

# 3) Pre-allocate a list to collect per-scenario long-form tibbles.
results_list <- vector("list", length = nrow(scenarios))

for (i in seq_len(nrow(scenarios))) {
  sc <- scenarios[i, ]

  start_earnings_num <- sc$start_earnings_num
  savings_rate_num   <- sc$savings_rate_num
  apply_match_flag   <- sc$apply_match_flag
  # Per-scenario MFJ-level anchors. NA for no-match rows; the
  # apply_match_flag multiplier zeroes the match flow in that case so
  # placeholder values are safe.
  mfj_amount_2027_used_num <- if (is.na(sc$mfj_amount_2027_num)) SM_MFJ_AMOUNT_2027 else sc$mfj_amount_2027_num
  mfj_range_2027_used_num  <- if (is.na(sc$mfj_range_2027_num))  SM_MFJ_RANGE_2027  else sc$mfj_range_2027_num

  # 3a) Year-indexed scaffold.
  one_path <- tibble(
    scenario_id    = sc$scenario_id,
    scenario_label = sc$scenario_label,
    year_idx       = seq_len(YEARS_OF_SAVING),
    age            = START_AGE + (year_idx - 1L),
    calendar_year  = base_year + (year_idx - 1L)
  )

  # 3b) Earnings grow geometrically at WAGE_GROWTH; own contribution is
  # savings_rate_num of nominal earnings.
  one_path <- one_path |>
    mutate(
      earnings_nominal_num         = start_earnings_num * (1 + WAGE_GROWTH)^(year_idx - 1L),
      own_contribution_nominal_num = earnings_nominal_num * savings_rate_num
    )

  # 3c) Statute-correct Saver's Match. Per IRC 6433(h):
  #   - Only the MFJ applicable dollar amount is indexed (at C-CPI-U).
  #   - The phaseout range is FIXED.
  #   - The increase to the MFJ amount is rounded to nearest $1,000.
  #   - Single-filer threshold = SM_SINGLE_FACTOR x rounded MFJ amount.
  #   - Single-filer phaseout range = SM_SINGLE_FACTOR x fixed MFJ range.
  #   - Contribution cap is fixed at $2,000 (NOT indexed).
  one_path <- one_path |>
    mutate(
      sm_threshold_index_num = (1 + SM_THRESHOLD_INFLATION)^(year_idx - 1L),
      mfj_amount_unrounded_num = mfj_amount_2027_used_num * sm_threshold_index_num,
      mfj_increase_unrounded_num = mfj_amount_unrounded_num - mfj_amount_2027_used_num,
      mfj_increase_rounded_num = if (SM_THRESHOLD_ROUND_BASE > 0) {
        round(mfj_increase_unrounded_num / SM_THRESHOLD_ROUND_BASE) * SM_THRESHOLD_ROUND_BASE
      } else {
        mfj_increase_unrounded_num
      },
      mfj_amount_indexed_num   = mfj_amount_2027_used_num + mfj_increase_rounded_num,
      sm_lower_num             = mfj_amount_indexed_num * SM_SINGLE_FACTOR,
      sm_upper_num             = sm_lower_num + (mfj_range_2027_used_num * SM_SINGLE_FACTOR),
      sm_contrib_cap_num       = SM_CONTRIB_CAP,
      phaseout_factor_num  = pmax(0, pmin(1,
        (sm_upper_num - earnings_nominal_num) / (sm_upper_num - sm_lower_num)
      )),
      match_nominal_num = SM_MATCH_RATE *
        pmin(own_contribution_nominal_num, sm_contrib_cap_num) *
        phaseout_factor_num *
        as.numeric(apply_match_flag),
      total_contribution_nominal_num = own_contribution_nominal_num + match_nominal_num
    )

  # 3d) End-of-year balance recurrence.
  balance_eoy_nominal_num <- numeric(YEARS_OF_SAVING)
  prior_balance_num <- 0
  for (t in seq_len(YEARS_OF_SAVING)) {
    balance_eoy_nominal_num[t] <- prior_balance_num * (1 + ANNUAL_RETURN) +
      one_path$total_contribution_nominal_num[t]
    prior_balance_num <- balance_eoy_nominal_num[t]
  }
  one_path$balance_eoy_nominal_num <- balance_eoy_nominal_num

  # 3e) Real (year-1 / 2027) dollar series at CPI-U.
  one_path <- one_path |>
    mutate(
      deflator_num                   = (1 + INFLATION)^(year_idx - 1L),
      earnings_real_num              = earnings_nominal_num             / deflator_num,
      own_contribution_real_num      = own_contribution_nominal_num     / deflator_num,
      match_real_num                 = match_nominal_num                / deflator_num,
      total_contribution_real_num    = total_contribution_nominal_num   / deflator_num,
      balance_eoy_real_num           = balance_eoy_nominal_num          / deflator_num
    )

  results_list[[i]] <- one_path
}

results_all <- bind_rows(results_list)

# 3f) Propagate saver-profile and multiplier identifiers from the
#     scenarios tibble onto the long panel for downstream ergonomics
#     (xlsx, console summary, Datawrapper-ready pivot). The per-scenario
#     loop body is left untouched so 1.0x and 2.0x numbers stay
#     bit-identical to the pre-change run.
results_all <- results_all |>
  left_join(
    scenarios |>
      select(scenario_id, saver_profile_chr, multiplier_num, apply_match_flag),
    by = "scenario_id"
  )

###################################################################
###                Closed-form verification                     ###
###################################################################

# 4) For the no-match scenarios, the contribution path is a clean
#    geometric series and the closed-form annuity identity should match
#    the iterative balance to the dollar.
verify_closed <- scenarios |>
  filter(!apply_match_flag) |>
  mutate(
    initial_contribution_num = start_earnings_num * savings_rate_num,
    s_ratio_num              = (1 + WAGE_GROWTH) / (1 + ANNUAL_RETURN),
    closed_balance_num = if (abs(ANNUAL_RETURN - WAGE_GROWTH) < 1e-12) {
      initial_contribution_num * YEARS_OF_SAVING *
        (1 + ANNUAL_RETURN)^(YEARS_OF_SAVING - 1L)
    } else {
      initial_contribution_num * (1 + ANNUAL_RETURN)^(YEARS_OF_SAVING - 1L) *
        (1 - s_ratio_num^YEARS_OF_SAVING) / (1 - s_ratio_num)
    }
  )

iter_balance_no_match <- results_all |>
  filter(scenario_id %in% verify_closed$scenario_id,
         year_idx == YEARS_OF_SAVING) |>
  select(scenario_id, iter_balance_num = balance_eoy_nominal_num)

verify_check <- verify_closed |>
  inner_join(iter_balance_no_match, by = "scenario_id") |>
  mutate(abs_diff_num = abs(closed_balance_num - iter_balance_num))

if (any(verify_check$abs_diff_num > 1)) {
  stop(sprintf(
    "Closed-form vs iterative disagree by more than $1 in: %s",
    paste(
      verify_check$scenario_id[verify_check$abs_diff_num > 1],
      collapse = ", "
    )
  ))
}

# 5) Match-flow sanity checks.
match_sanity <- results_all |>
  filter(scenario_id %in% scenarios$scenario_id[scenarios$apply_match_flag])

if (any(match_sanity$match_nominal_num < -1e-9)) {
  stop("Negative Saver's Match flow detected.")
}

match_cap_breach <- match_sanity |>
  mutate(cap_value_num = SM_MATCH_RATE * sm_contrib_cap_num,
         breach_flag   = match_nominal_num > cap_value_num + 1e-6) |>
  filter(breach_flag)
if (nrow(match_cap_breach) > 0L) {
  stop("Saver's Match flow exceeds 50 percent of fixed contribution cap.")
}

match_above_upper <- match_sanity |>
  filter(earnings_nominal_num > sm_upper_num, match_nominal_num > 1e-6)
if (nrow(match_above_upper) > 0L) {
  stop("Non-zero Saver's Match observed despite earnings above indexed upper threshold.")
}

###################################################################
###                Per-scenario summary                         ###
###################################################################

summary_tbl <- results_all |>
  group_by(scenario_id, scenario_label, saver_profile_chr, multiplier_num,
           apply_match_flag) |>
  summarise(
    final_age_int                  = max(age),
    final_earnings_nominal_num     = earnings_nominal_num[year_idx == YEARS_OF_SAVING],
    final_earnings_real_num        = earnings_real_num[year_idx == YEARS_OF_SAVING],
    sum_own_nominal_num            = sum(own_contribution_nominal_num),
    sum_match_nominal_num          = sum(match_nominal_num),
    sum_total_contrib_nominal_num  = sum(total_contribution_nominal_num),
    sum_own_real_num               = sum(own_contribution_real_num),
    sum_match_real_num             = sum(match_real_num),
    sum_total_contrib_real_num     = sum(total_contribution_real_num),
    final_balance_nominal_num      = balance_eoy_nominal_num[year_idx == YEARS_OF_SAVING],
    final_balance_real_num         = balance_eoy_real_num[year_idx == YEARS_OF_SAVING],
    .groups = "drop"
  ) |>
  mutate(
    investment_growth_nominal_num = final_balance_nominal_num - sum_total_contrib_nominal_num,
    investment_growth_real_num    = final_balance_real_num    - sum_total_contrib_real_num
  ) |>
  arrange(saver_profile_chr, !apply_match_flag, multiplier_num)

###################################################################
###                Monotonicity check across multipliers        ###
###################################################################

# 6a) Within each saver profile, final balances should be weakly
#     increasing in the multiplier (more generous thresholds -> at
#     least as much match flow -> at least as much accumulation).
mono_check <- summary_tbl |>
  filter(apply_match_flag) |>
  arrange(saver_profile_chr, multiplier_num) |>
  group_by(saver_profile_chr) |>
  mutate(
    prior_balance_num = lag(final_balance_nominal_num),
    violates_flag     = !is.na(prior_balance_num) &
                        final_balance_nominal_num < prior_balance_num - 1
  ) |>
  ungroup()

if (any(mono_check$violates_flag)) {
  stop(sprintf(
    "Final-balance monotonicity violated across multipliers in: %s",
    paste(
      mono_check$scenario_id[mono_check$violates_flag],
      collapse = ", "
    )
  ))
}

###################################################################
###                Bridge check vs pre-change snapshot          ###
###################################################################

# 6b) Per the 2026-05-11 plan: the four-multiplier extension must not
#     move pre-existing _CL or _2X numbers. Read the pre-change summary
#     snapshot if present and compare _m100 against _CL, _m200 against
#     _2X, to the dollar. Skipped if the snapshot is absent.
bridge_skip_flag <- is.na(BRIDGE_SNAPSHOT_PATH) ||
                    !nzchar(BRIDGE_SNAPSHOT_PATH) ||
                    !file.exists(BRIDGE_SNAPSHOT_PATH)

if (isTRUE(bridge_skip_flag)) {
  message("Bridge check skipped: no pre-change snapshot at ",
          BRIDGE_SNAPSHOT_PATH)
} else {
  pre_summary_tbl <- readRDS(BRIDGE_SNAPSHOT_PATH)
  bridge_pairs_tbl <- tibble(
    pre_id_chr  = c("A_30k_5pct_match_CL", "A_30k_5pct_match_2X",
                    "B_35k_3pct_match_CL", "B_35k_3pct_match_2X"),
    post_id_chr = c("A_30k_5pct_match_m100", "A_30k_5pct_match_m200",
                    "B_35k_3pct_match_m100", "B_35k_3pct_match_m200")
  )

  bridge_check_tbl <- bridge_pairs_tbl |>
    left_join(
      pre_summary_tbl |>
        select(pre_id_chr = scenario_id,
               pre_nominal_num  = final_balance_nominal_num,
               pre_real_num     = final_balance_real_num,
               pre_match_num    = sum_match_nominal_num),
      by = "pre_id_chr"
    ) |>
    left_join(
      summary_tbl |>
        select(post_id_chr = scenario_id,
               post_nominal_num = final_balance_nominal_num,
               post_real_num    = final_balance_real_num,
               post_match_num   = sum_match_nominal_num),
      by = "post_id_chr"
    ) |>
    mutate(
      abs_diff_nominal_num = abs(post_nominal_num - pre_nominal_num),
      abs_diff_real_num    = abs(post_real_num    - pre_real_num),
      abs_diff_match_num   = abs(post_match_num   - pre_match_num)
    )

  bridge_breach_tbl <- bridge_check_tbl |>
    filter(abs_diff_nominal_num > 1 |
           abs_diff_real_num    > 1 |
           abs_diff_match_num   > 1)

  if (nrow(bridge_breach_tbl) > 0L) {
    print(bridge_breach_tbl, n = Inf)
    stop(
      "Bridge check failed: _m100 or _m200 diverged from pre-change _CL or _2X by more than $1.",
      call. = FALSE
    )
  }

  message("Bridge check passed: _m100 = _CL and _m200 = _2X to the dollar across both savers.")
}

###################################################################
###                Console summary                              ###
###################################################################

message("===================================================================")
message("Multi-scenario saver illustration (statute-correct indexing)")
message(sprintf(
  "Ages %d-%d (%d years), nominal return %s, wage growth %s.",
  START_AGE, END_AGE - 1L, YEARS_OF_SAVING,
  percent(ANNUAL_RETURN, accuracy = 0.1),
  percent(WAGE_GROWTH, accuracy = 0.1)
))
message(sprintf(
  "CPI-U deflator %s; Saver's Match thresholds indexed at C-CPI-U %s with $%d rounding.",
  percent(INFLATION, accuracy = 0.1),
  percent(SM_THRESHOLD_INFLATION, accuracy = 0.1),
  SM_THRESHOLD_ROUND_BASE
))
message(sprintf(
  "Phaseout range FIXED at the multiplier-scaled MFJ range (single = SM_SINGLE_FACTOR x scaled range); contribution cap FIXED at $%d.",
  SM_CONTRIB_CAP
))
message(sprintf(
  "AGI-threshold multipliers (applied to MFJ amount and range at TY%d): %s",
  base_year,
  paste(sprintf("%.2fx", SM_MULTIPLIERS_NUM), collapse = ", ")
))
message(sprintf(
  "Real-dollar figures expressed in year-1 (%d) dollars.",
  base_year
))
message("===================================================================")

for (i in seq_len(nrow(summary_tbl))) {
  s <- summary_tbl[i, ]
  message("")
  message(sprintf("Scenario %s: %s", s$scenario_id, s$scenario_label))
  message("-------------------------------------------------------------------")
  message(sprintf("  Year %d earnings (nominal):              %s",
                  YEARS_OF_SAVING,
                  dollar(s$final_earnings_nominal_num, accuracy = 1)))
  message(sprintf("  Total own contributions (nominal):       %s",
                  dollar(s$sum_own_nominal_num, accuracy = 1)))
  message(sprintf("  Total Saver's Match (nominal):           %s",
                  dollar(s$sum_match_nominal_num, accuracy = 1)))
  message(sprintf("  Investment growth (nominal):             %s",
                  dollar(s$investment_growth_nominal_num, accuracy = 1)))
  message(sprintf("  FINAL BALANCE at age %d (nominal):       %s",
                  END_AGE,
                  dollar(s$final_balance_nominal_num, accuracy = 1)))
  message(sprintf("  FINAL BALANCE at age %d (real %d $):    %s",
                  END_AGE, base_year,
                  dollar(s$final_balance_real_num, accuracy = 1)))
}

# 7) Direct check on the B saver across all four multipliers. Highlights
#    how rapidly the match flow grows as the AGI thresholds expand.
b_match_tbl <- summary_tbl |>
  filter(saver_profile_chr == "B_35k_3pct", apply_match_flag) |>
  arrange(multiplier_num) |>
  select(scenario_id, multiplier_num, sum_match_nominal_num,
         final_balance_nominal_num, final_balance_real_num)

b_own_total_num <- summary_tbl |>
  filter(scenario_id == "B_35k_3pct_match_m100") |>
  pull(sum_own_nominal_num)

match_m100_num <- b_match_tbl |>
  filter(abs(multiplier_num - 1.00) < 1e-9) |>
  pull(sum_match_nominal_num)

message("")
message("===================================================================")
message("Direct check: $35K @ 3% saver, four-multiplier contrast")
message(sprintf("  Total own contributions, nominal:                %s",
                dollar(b_own_total_num, accuracy = 1)))
for (j in seq_len(nrow(b_match_tbl))) {
  r <- b_match_tbl[j, ]
  message(sprintf(
    "  Multiplier %.2fx -- match total %s | final balance %s nominal / %s real",
    r$multiplier_num,
    dollar(r$sum_match_nominal_num, accuracy = 1),
    dollar(r$final_balance_nominal_num, accuracy = 1),
    dollar(r$final_balance_real_num, accuracy = 1)
  ))
}
message(sprintf(
  "  Match increment vs 1.00x at 2.00x:               %s",
  dollar(
    (b_match_tbl |>
       filter(abs(multiplier_num - 2.00) < 1e-9) |>
       pull(sum_match_nominal_num)) - match_m100_num,
    accuracy = 1
  )
))
message("===================================================================")

###################################################################
###      Targeted comparison: $33,350 saver at 3 percent       ###
###################################################################

# 8) Separate wide-format export for a single worker earning
#    $33,350 in year 1 and contributing 3 percent. Three designs are
#    shown: no government match, a government dollar-for-dollar match
#    capped at a fixed nominal $1,000, and the current-law Saver's
#    Match. This export is intentionally separate from the main 03c
#    workbook so downstream memo work can lift a four-column
#    age-by-balance table directly.
comparison_scenarios_tbl <- tibble(
  comparison_id_chr = c(
    "worker_33350_3pct_no_match",
    "worker_33350_3pct_dollar_match",
    "worker_33350_3pct_savers_match",
    "worker_33350_3pct_rsaa"
  ),
  comparison_column_chr = c(
    "Savings without any match",
    "Savings with the dollar for dollar match",
    "Savings with the savers match",
    "Savings with the RSAA credit"
  ),
  start_earnings_num = c(33350, 33350, 33350, 33350),
  savings_rate_num = c(0.03, 0.03, 0.03, 0.03),
  apply_dollar_match_flag = c(FALSE, TRUE, FALSE, FALSE),
  apply_savers_match_flag = c(FALSE, FALSE, TRUE, FALSE),
  apply_rsaa_flag = c(FALSE, FALSE, FALSE, TRUE),
  mfj_amount_2027_num = c(NA_real_, NA_real_, SM_MFJ_AMOUNT_2027, NA_real_),
  mfj_range_2027_num = c(NA_real_, NA_real_, SM_MFJ_RANGE_2027, NA_real_)
)

comparison_results_list <- vector("list", length = nrow(comparison_scenarios_tbl))

for (i in seq_len(nrow(comparison_scenarios_tbl))) {
  sc <- comparison_scenarios_tbl[i, ]

  start_earnings_num <- sc$start_earnings_num
  savings_rate_num <- sc$savings_rate_num
  apply_dollar_match_flag <- sc$apply_dollar_match_flag
  apply_savers_match_flag <- sc$apply_savers_match_flag
  apply_rsaa_flag <- sc$apply_rsaa_flag
  mfj_amount_2027_used_num <- if (is.na(sc$mfj_amount_2027_num)) SM_MFJ_AMOUNT_2027 else sc$mfj_amount_2027_num
  mfj_range_2027_used_num <- if (is.na(sc$mfj_range_2027_num)) SM_MFJ_RANGE_2027 else sc$mfj_range_2027_num

  one_path <- tibble(
    comparison_id_chr = sc$comparison_id_chr,
    comparison_column_chr = sc$comparison_column_chr,
    year_idx = seq_len(YEARS_OF_SAVING),
    contribution_age_int = START_AGE + (year_idx - 1L),
    balance_age_int = START_AGE + year_idx,
    calendar_year = base_year + (year_idx - 1L)
  ) |>
    mutate(
      earnings_nominal_num = start_earnings_num * (1 + WAGE_GROWTH)^(year_idx - 1L),
      own_contribution_nominal_num = earnings_nominal_num * savings_rate_num,
      sm_threshold_index_num = (1 + SM_THRESHOLD_INFLATION)^(year_idx - 1L),
      mfj_amount_unrounded_num = mfj_amount_2027_used_num * sm_threshold_index_num,
      mfj_increase_unrounded_num = mfj_amount_unrounded_num - mfj_amount_2027_used_num,
      mfj_increase_rounded_num = if (SM_THRESHOLD_ROUND_BASE > 0) {
        round(mfj_increase_unrounded_num / SM_THRESHOLD_ROUND_BASE) * SM_THRESHOLD_ROUND_BASE
      } else {
        mfj_increase_unrounded_num
      },
      mfj_amount_indexed_num = mfj_amount_2027_used_num + mfj_increase_rounded_num,
      sm_lower_num = mfj_amount_indexed_num * SM_SINGLE_FACTOR,
      sm_upper_num = sm_lower_num + (mfj_range_2027_used_num * SM_SINGLE_FACTOR),
      sm_contrib_cap_num = SM_CONTRIB_CAP,
      phaseout_factor_num = pmax(0, pmin(1,
        (sm_upper_num - earnings_nominal_num) / (sm_upper_num - sm_lower_num)
      )),
      dollar_match_nominal_num = pmin(
        own_contribution_nominal_num,
        DOLLAR_MATCH_CAP
      ) * as.numeric(apply_dollar_match_flag),
      savers_match_nominal_num = SM_MATCH_RATE *
        pmin(own_contribution_nominal_num, sm_contrib_cap_num) *
        phaseout_factor_num *
        as.numeric(apply_savers_match_flag),
      # RSAA §25F: single-filer phaseout amount M indexed forward at WAGE_GROWTH.
      rsaa_phaseout_amount_num = RSAA_MEDIAN_INCOME_2027 * (1 + WAGE_GROWTH)^(year_idx - 1L),
      rsaa_tier1_num = pmin(own_contribution_nominal_num, RSAA_MATCH_KINK1 * earnings_nominal_num),
      rsaa_tier2_num = pmax(0, pmin(own_contribution_nominal_num, RSAA_MATCH_KINK2 * earnings_nominal_num) -
                              RSAA_MATCH_KINK1 * earnings_nominal_num),
      rsaa_credit_before_cap_num = RSAA_AUTO_CREDIT_RATE * earnings_nominal_num +
        RSAA_MATCH_RATE_BELOW_K1 * rsaa_tier1_num + RSAA_MATCH_RATE_BETWEEN * rsaa_tier2_num,
      # §25F(c)(2): $75 per $1,000 "or portion thereof" -- step function, not linear.
      rsaa_credit_limit_num = pmax(0, RSAA_CREDIT_LIMIT_SHARE * rsaa_phaseout_amount_num -
        (RSAA_PHASEOUT_SLOPE * 1000) *
          ceiling(pmax(0, earnings_nominal_num - rsaa_phaseout_amount_num) / 1000)),
      rsaa_match_nominal_num = pmin(rsaa_credit_before_cap_num, rsaa_credit_limit_num) *
        as.numeric(apply_rsaa_flag),
      government_match_nominal_num = dollar_match_nominal_num + savers_match_nominal_num +
        rsaa_match_nominal_num,
      total_contribution_nominal_num = own_contribution_nominal_num + government_match_nominal_num
    )

  balance_eoy_nominal_num <- numeric(YEARS_OF_SAVING)
  prior_balance_num <- 0

  for (t in seq_len(YEARS_OF_SAVING)) {
    balance_eoy_nominal_num[t] <- prior_balance_num * (1 + ANNUAL_RETURN) +
      one_path$total_contribution_nominal_num[t]
    prior_balance_num <- balance_eoy_nominal_num[t]
  }

  one_path$balance_eoy_nominal_num <- balance_eoy_nominal_num
  comparison_results_list[[i]] <- one_path
}

comparison_results_tbl <- bind_rows(comparison_results_list)

dollar_match_cap_check_tbl <- comparison_results_tbl |>
  filter(comparison_id_chr == "worker_33350_3pct_dollar_match") |>
  mutate(cap_breach_flag = dollar_match_nominal_num > DOLLAR_MATCH_CAP + 1e-6) |>
  filter(cap_breach_flag)

if (nrow(dollar_match_cap_check_tbl) > 0L) {
  stop("Dollar-for-dollar comparison match exceeds the fixed $1,000 cap.", call. = FALSE)
}

comparison_summary_tbl <- comparison_results_tbl |>
  group_by(comparison_id_chr, comparison_column_chr) |>
  summarise(
    total_own_contribution_nominal_num = sum(own_contribution_nominal_num),
    total_government_match_nominal_num = sum(government_match_nominal_num),
    final_balance_nominal_num = balance_eoy_nominal_num[year_idx == YEARS_OF_SAVING],
    .groups = "drop"
  ) |>
  arrange(match(comparison_id_chr, comparison_scenarios_tbl$comparison_id_chr))

comparison_wide_tbl <- comparison_results_tbl |>
  select(Age = balance_age_int, comparison_column_chr, balance_eoy_nominal_num) |>
  tidyr::pivot_wider(
    names_from = comparison_column_chr,
    values_from = balance_eoy_nominal_num
  ) |>
  arrange(Age)

if (!identical(comparison_wide_tbl$Age, seq.int(START_AGE + 1L, END_AGE))) {
  stop("Comparison export age axis is not the expected end-of-year range.", call. = FALSE)
}

comparison_final_wide_tbl <- comparison_wide_tbl |>
  filter(Age == max(Age)) |>
  tidyr::pivot_longer(
    cols = -Age,
    names_to = "comparison_column_chr",
    values_to = "wide_final_balance_nominal_num"
  )

comparison_final_check_tbl <- comparison_summary_tbl |>
  select(comparison_column_chr, final_balance_nominal_num) |>
  left_join(comparison_final_wide_tbl, by = "comparison_column_chr") |>
  mutate(abs_diff_num = abs(final_balance_nominal_num - wide_final_balance_nominal_num))

if (any(comparison_final_check_tbl$abs_diff_num > 1e-6)) {
  stop("Wide-format $33,350 comparison export failed final-balance reconciliation.", call. = FALSE)
}

message("")
message("===================================================================")
message("Targeted comparison: $33,350 worker at 3 percent")
for (i in seq_len(nrow(comparison_summary_tbl))) {
  r <- comparison_summary_tbl[i, ]
  message(sprintf(
    "  %s -- own contributions %s | government match %s | final balance %s",
    r$comparison_column_chr,
    dollar(r$total_own_contribution_nominal_num, accuracy = 1),
    dollar(r$total_government_match_nominal_num, accuracy = 1),
    dollar(r$final_balance_nominal_num, accuracy = 1)
  ))
}
message(sprintf(
  "  Dollar-for-dollar government match assumption: fixed nominal cap of %s per year (not inflation indexed).",
  dollar(DOLLAR_MATCH_CAP, accuracy = 1)
))
message("===================================================================")

###################################################################
###                Save artifacts                               ###
###################################################################

if (isTRUE(WRITE_TABLE)) {
  out_rds             <- file.path(path_output_tbl, "simple_saver_illustration.rds")
  out_parquet         <- file.path(path_output_tbl, "simple_saver_illustration.parquet")
  out_summary_rds     <- file.path(path_output_tbl, "simple_saver_illustration_summary.rds")
  out_summary_parquet <- file.path(path_output_tbl, "simple_saver_illustration_summary.parquet")

  saveRDS(results_all, out_rds)
  arrow::write_parquet(results_all, out_parquet, compression = "snappy")
  saveRDS(summary_tbl, out_summary_rds)
  arrow::write_parquet(summary_tbl, out_summary_parquet, compression = "snappy")

  message("Saved table: ", out_rds)
  message("Saved table: ", out_parquet)
  message("Saved table: ", out_summary_rds)
  message("Saved table: ", out_summary_parquet)
}

###################################################################
###                Save xlsx workbook                           ###
###################################################################

if (isTRUE(WRITE_XLSX)) {
  out_xlsx <- file.path(path_output_tbl, "simple_saver_illustration.xlsx")

  # 8a) Parameters sheet -- top-level macros plus the indexed single-filer
  #     thresholds at year 1 and year 40 for each multiplier. Helpful for
  #     a reader who wants to interpret the long panel without re-running
  #     the script.
  params_macros_tbl <- tibble(
    parameter_chr = c(
      "START_AGE", "END_AGE", "YEARS_OF_SAVING",
      "ANNUAL_RETURN", "WAGE_GROWTH", "INFLATION",
      "base_year",
      "SM_BASE_YEAR", "SM_MFJ_AMOUNT_2027", "SM_MFJ_RANGE_2027",
      "SM_HOH_FACTOR", "SM_SINGLE_FACTOR",
      "SM_CONTRIB_CAP", "SM_MATCH_RATE",
      "SM_THRESHOLD_INFLATION", "SM_THRESHOLD_ROUND_BASE",
      "SM_MULTIPLIERS_NUM (vector)", "CONTRIBUTION_TIMING"
    ),
    value_chr = c(
      as.character(START_AGE), as.character(END_AGE),
      as.character(YEARS_OF_SAVING),
      sprintf("%.4f", ANNUAL_RETURN), sprintf("%.4f", WAGE_GROWTH),
      sprintf("%.4f", INFLATION),
      as.character(base_year),
      as.character(SM_BASE_YEAR), as.character(SM_MFJ_AMOUNT_2027),
      as.character(SM_MFJ_RANGE_2027),
      sprintf("%.4f", SM_HOH_FACTOR), sprintf("%.4f", SM_SINGLE_FACTOR),
      as.character(SM_CONTRIB_CAP), sprintf("%.4f", SM_MATCH_RATE),
      sprintf("%.4f", SM_THRESHOLD_INFLATION),
      as.character(SM_THRESHOLD_ROUND_BASE),
      paste(sprintf("%.2f", SM_MULTIPLIERS_NUM), collapse = ", "),
      CONTRIBUTION_TIMING
    )
  )

  # 8b) Per-multiplier single-filer thresholds at the start and end of the
  #     career. Pulled directly from the long panel so the values are
  #     statute-correct and consistent with the rest of the workbook.
  params_thresholds_tbl <- results_all |>
    filter(apply_match_flag, year_idx %in% c(1L, YEARS_OF_SAVING)) |>
    distinct(multiplier_num, year_idx, age, calendar_year,
             sm_lower_num, sm_upper_num) |>
    arrange(multiplier_num, year_idx) |>
    rename(
      sm_lower_single_filer_num = sm_lower_num,
      sm_upper_single_filer_num = sm_upper_num
    )

  # 8c) Scenario summary -- one row per scenario.
  summary_sheet_tbl <- summary_tbl |>
    select(
      scenario_id, scenario_label, saver_profile_chr, multiplier_num,
      apply_match_flag, final_age_int,
      final_earnings_nominal_num, final_earnings_real_num,
      sum_own_nominal_num, sum_match_nominal_num, sum_total_contrib_nominal_num,
      sum_own_real_num, sum_match_real_num, sum_total_contrib_real_num,
      investment_growth_nominal_num, investment_growth_real_num,
      final_balance_nominal_num, final_balance_real_num
    )

  # 8d) Year-by-year long panel -- 10 scenarios x 40 years = 400 rows.
  panel_sheet_tbl <- results_all |>
    select(
      scenario_id, scenario_label, saver_profile_chr, multiplier_num,
      apply_match_flag,
      year_idx, age, calendar_year,
      earnings_nominal_num, own_contribution_nominal_num,
      match_nominal_num, total_contribution_nominal_num,
      balance_eoy_nominal_num,
      earnings_real_num, own_contribution_real_num,
      match_real_num, total_contribution_real_num,
      balance_eoy_real_num,
      sm_lower_num, sm_upper_num, phaseout_factor_num
    ) |>
    arrange(saver_profile_chr, !apply_match_flag, multiplier_num, year_idx)

  # 8e) Match flows by year, wide. Datawrapper-ready: rows are age, columns
  #     are one per match-bearing scenario (8 columns nominal + 8 columns
  #     real). The no-match baselines are omitted because their match
  #     flow is identically zero.
  match_flows_nominal_wide_tbl <- results_all |>
    filter(apply_match_flag) |>
    select(age, scenario_id, match_nominal_num) |>
    tidyr::pivot_wider(
      names_from  = scenario_id,
      values_from = match_nominal_num,
      names_glue  = "{scenario_id}_match_nominal_num"
    ) |>
    arrange(age)

  match_flows_real_wide_tbl <- results_all |>
    filter(apply_match_flag) |>
    select(age, scenario_id, match_real_num) |>
    tidyr::pivot_wider(
      names_from  = scenario_id,
      values_from = match_real_num,
      names_glue  = "{scenario_id}_match_real_num"
    ) |>
    arrange(age)

  match_flows_sheet_tbl <- match_flows_nominal_wide_tbl |>
    left_join(match_flows_real_wide_tbl, by = "age")

  # 8f) Methodology notes -- short prose block with the statutory anchors
  #     and the multiplier convention.
  methodology_tbl <- tibble(
    note_chr = c(
      "Statutory basis: SECURE 2.0 Act of 2022 (Pub. L. 117-328, Division T, Sec. 103); codified at IRC 6433.",
      "Match rate: 50 percent of qualified retirement savings contributions up to the contribution cap (IRC 6433(b)(1)).",
      "Contribution cap: $2,000, FIXED by statute; not indexed (IRC 6433(a)).",
      "MFJ applicable dollar amount at TY2027: $41,000. Indexed at C-CPI-U per IRC 6433(h)(1) using TY2026 as the base year, rounded to the nearest $1,000 per IRC 6433(h)(2).",
      "MFJ phaseout range at TY2027: $30,000, FIXED at the multiplier-scaled value (IRC 6433(b)(3)(A)(ii)).",
      "Single-filer thresholds are 50 percent of the MFJ values per IRC 6433(b)(3)(B)(ii); head-of-household are 75 percent (IRC 6433(b)(3)(B)(i)).",
      "Multiplier convention: each multiplier in SM_MULTIPLIERS_NUM scales BOTH the MFJ applicable dollar amount AND the MFJ phaseout range at TY2027; statutory C-CPI-U indexing is then applied to the scaled MFJ amount.",
      "Account return: 7.0 percent nominal annual return (TSP long-run anchor; conservative relative to recent L 2030/L 2040 actuals).",
      "Wage growth: 3.0 percent nominal annual (CBO Budget and Economic Outlook 2026-2036, 10-year ECI window).",
      "CPI-U deflator: 2.3 percent annual (CBO long-run projection); used only to convert nominal balances to year-1 (2027) real dollars.",
      "C-CPI-U threshold-indexing rate: 2.0 percent annual (CBO long-run projection); applied per IRC 6433(h)(1).",
      "Contribution timing: end-of-year. The closed-form geometric-annuity identity is checked against the iterative balance for both no-match scenarios; tolerance is $1.",
      "Bridge check: post-change _m100 and _m200 final balances must match pre-change _CL and _2X final balances to the dollar; failure halts the script."
    )
  )

  # 8g) Style helpers -- defined inline so this sheet block is self-contained.
  hdr_style <- openxlsx::createStyle(
    textDecoration = "bold",
    fgFill         = "#E8E8E8",
    border         = "Bottom"
  )
  money_style <- openxlsx::createStyle(numFmt = "$#,##0")
  num_style   <- openxlsx::createStyle(numFmt = "#,##0")
  pct_style   <- openxlsx::createStyle(numFmt = "0.0%")

  wb <- openxlsx::createWorkbook()

  # 8h) Parameters sheet
  openxlsx::addWorksheet(wb, "Parameters")
  openxlsx::writeData(wb, "Parameters", "Top-level macros", startRow = 1, startCol = 1)
  openxlsx::writeDataTable(wb, "Parameters", params_macros_tbl,
                           startRow = 2, startCol = 1, tableStyle = "TableStyleLight1")
  openxlsx::writeData(wb, "Parameters", "Single-filer thresholds by multiplier (year 1 and year 40)",
                      startRow = 2 + nrow(params_macros_tbl) + 3, startCol = 1)
  openxlsx::writeDataTable(wb, "Parameters", params_thresholds_tbl,
                           startRow = 2 + nrow(params_macros_tbl) + 4, startCol = 1,
                           tableStyle = "TableStyleLight1")
  openxlsx::setColWidths(wb, "Parameters", cols = 1:6, widths = c(40, 28, 14, 12, 14, 24))

  # 8i) Scenario summary sheet
  openxlsx::addWorksheet(wb, "Scenario summary")
  openxlsx::writeDataTable(wb, "Scenario summary", summary_sheet_tbl,
                           startRow = 1, startCol = 1, tableStyle = "TableStyleLight1")
  openxlsx::addStyle(wb, "Scenario summary", money_style,
                     rows = 2:(nrow(summary_sheet_tbl) + 1L),
                     cols = which(grepl("_num$",
                                        names(summary_sheet_tbl)) &
                                  !grepl("multiplier", names(summary_sheet_tbl))),
                     gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Scenario summary",
                         cols = seq_along(summary_sheet_tbl),
                         widths = "auto")

  # 8j) Year-by-year panel sheet
  openxlsx::addWorksheet(wb, "Year-by-year panel")
  openxlsx::writeDataTable(wb, "Year-by-year panel", panel_sheet_tbl,
                           startRow = 1, startCol = 1, tableStyle = "TableStyleLight1")
  panel_money_cols <- which(
    grepl("_num$", names(panel_sheet_tbl)) &
      !grepl("multiplier|year_idx|phaseout_factor", names(panel_sheet_tbl))
  )
  openxlsx::addStyle(wb, "Year-by-year panel", money_style,
                     rows = 2:(nrow(panel_sheet_tbl) + 1L),
                     cols = panel_money_cols,
                     gridExpand = TRUE)
  panel_pct_cols <- which(names(panel_sheet_tbl) == "phaseout_factor_num")
  if (length(panel_pct_cols) > 0L) {
    openxlsx::addStyle(wb, "Year-by-year panel", pct_style,
                       rows = 2:(nrow(panel_sheet_tbl) + 1L),
                       cols = panel_pct_cols,
                       gridExpand = TRUE)
  }
  openxlsx::setColWidths(wb, "Year-by-year panel",
                         cols = seq_along(panel_sheet_tbl),
                         widths = "auto")

  # 8k) Match flows by year sheet (Datawrapper-ready wide pivot)
  openxlsx::addWorksheet(wb, "Match flows by year")
  openxlsx::writeData(wb, "Match flows by year",
                      "Wide pivot of per-year Saver's Match flow (nominal and real, year-1 dollars). Datawrapper source.",
                      startRow = 1, startCol = 1)
  openxlsx::writeDataTable(wb, "Match flows by year", match_flows_sheet_tbl,
                           startRow = 3, startCol = 1, tableStyle = "TableStyleLight1")
  match_money_cols <- which(grepl("_num$", names(match_flows_sheet_tbl)))
  openxlsx::addStyle(wb, "Match flows by year", money_style,
                     rows = 4:(nrow(match_flows_sheet_tbl) + 3L),
                     cols = match_money_cols,
                     gridExpand = TRUE)
  openxlsx::setColWidths(wb, "Match flows by year",
                         cols = seq_along(match_flows_sheet_tbl),
                         widths = "auto")

  # 8l) Methodology notes sheet
  openxlsx::addWorksheet(wb, "Methodology notes")
  openxlsx::writeDataTable(wb, "Methodology notes", methodology_tbl,
                           startRow = 1, startCol = 1, tableStyle = "TableStyleLight1")
  openxlsx::setColWidths(wb, "Methodology notes", cols = 1, widths = 120)

  openxlsx::saveWorkbook(wb, out_xlsx, overwrite = TRUE)
  message("Saved xlsx: ", out_xlsx)

  comparison_out_xlsx <- file.path(
    path_output_tbl,
    "simple_saver_illustration_33350_3pct_match_comparison.xlsx"
  )
  comparison_methodology_tbl <- tibble(
    note_chr = c(
      "Balances are nominal end-of-year account balances.",
      "Worker profile: single filer earning $33,350 in year 1 and contributing 3 percent of earnings.",
      "Contribution years run from ages 19 to 58; the Age column reports end-of-year attained age, so the data sheet runs from age 20 to age 59.",
      "Dollar-for-dollar government match scenario: government matches own contributions dollar for dollar up to a fixed nominal $1,000 per year. The cap does not increase with inflation.",
      "Saver's Match scenario: current-law Saver's Match parameters from the 03c script, including the fixed $2,000 contribution cap and statutory threshold indexing."
    )
  )
  comparison_wb <- openxlsx::createWorkbook()
  openxlsx::addWorksheet(comparison_wb, "Savings comparison")
  openxlsx::writeDataTable(
    comparison_wb,
    "Savings comparison",
    comparison_wide_tbl,
    startRow = 1,
    startCol = 1,
    tableStyle = "TableStyleLight1"
  )
  openxlsx::addStyle(
    comparison_wb,
    "Savings comparison",
    money_style,
    rows = 2:(nrow(comparison_wide_tbl) + 1L),
    cols = 2:ncol(comparison_wide_tbl),
    gridExpand = TRUE
  )
  openxlsx::setColWidths(
    comparison_wb,
    "Savings comparison",
    cols = seq_along(comparison_wide_tbl),
    widths = "auto"
  )
  openxlsx::addWorksheet(comparison_wb, "Methodology notes")
  openxlsx::writeDataTable(
    comparison_wb,
    "Methodology notes",
    comparison_methodology_tbl,
    startRow = 1,
    startCol = 1,
    tableStyle = "TableStyleLight1"
  )
  openxlsx::setColWidths(
    comparison_wb,
    "Methodology notes",
    cols = 1,
    widths = 120
  )
  openxlsx::saveWorkbook(comparison_wb, comparison_out_xlsx, overwrite = TRUE)
  message("Saved xlsx: ", comparison_out_xlsx)
}

if (isTRUE(WRITE_FIGURE)) {

  scenario_levels <- scenarios$scenario_label

  fig_caption_chr <- sprintf(
    paste(
      "Single saver, ages %d-%d, %s nominal return, %s nominal wage growth,",
      "%s CPI-U deflator. Saver's Match thresholds indexed at %s C-CPI-U per",
      "IRC 6433(h)(1) with $%d rounding (h)(2); phaseout range and $%d",
      "contribution cap fixed."
    ),
    START_AGE, END_AGE - 1L,
    percent(ANNUAL_RETURN, accuracy = 0.1),
    percent(WAGE_GROWTH, accuracy = 0.1),
    percent(INFLATION, accuracy = 0.1),
    percent(SM_THRESHOLD_INFLATION, accuracy = 0.1),
    SM_THRESHOLD_ROUND_BASE,
    SM_CONTRIB_CAP
  )

  fig_data_nominal <- results_all |>
    select(age, scenario_label, balance_num = balance_eoy_nominal_num) |>
    mutate(scenario_label = factor(scenario_label, levels = scenario_levels))

  fig_nominal <- ggplot(fig_data_nominal,
                        aes(x = age, y = balance_num,
                            color = scenario_label, linetype = scenario_label)) +
    geom_line(linewidth = 1.0) +
    scale_y_continuous(labels = dollar_format(accuracy = 1)) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 8L)) +
    labs(
      title = "Nominal end-of-year balance, six scenarios (statute-correct indexing)",
      subtitle = sprintf("Ages %d-%d, end-of-year contribution timing",
                         START_AGE, END_AGE - 1L),
      x = "Age",
      y = "Nominal U.S. dollars",
      color = NULL, linetype = NULL,
      caption = fig_caption_chr
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position = "bottom",
      plot.caption = element_text(hjust = 0, size = 9, color = "grey30"),
      panel.grid.minor = element_blank()
    )

  fig_path_nominal <- file.path(path_output_fig, "simple_saver_illustration.png")
  ggsave(filename = fig_path_nominal, plot = fig_nominal,
         width = 9, height = 6, dpi = 200)
  message("Saved figure: ", fig_path_nominal)

  fig_data_real <- results_all |>
    select(age, scenario_label, balance_num = balance_eoy_real_num) |>
    mutate(scenario_label = factor(scenario_label, levels = scenario_levels))

  fig_real <- ggplot(fig_data_real,
                     aes(x = age, y = balance_num,
                         color = scenario_label, linetype = scenario_label)) +
    geom_line(linewidth = 1.0) +
    scale_y_continuous(labels = dollar_format(accuracy = 1)) +
    scale_x_continuous(breaks = scales::pretty_breaks(n = 8L)) +
    labs(
      title = sprintf("Real (year-1 / %d $) end-of-year balance, six scenarios",
                      base_year),
      subtitle = sprintf("Deflated at %s annual CPI-U",
                         percent(INFLATION, accuracy = 0.1)),
      x = "Age",
      y = sprintf("U.S. dollars (%d)", base_year),
      color = NULL, linetype = NULL,
      caption = fig_caption_chr
    ) +
    theme_minimal(base_size = 11) +
    theme(
      legend.position = "bottom",
      plot.caption = element_text(hjust = 0, size = 9, color = "grey30"),
      panel.grid.minor = element_blank()
    )

  fig_path_real <- file.path(path_output_fig, "simple_saver_illustration_real.png")
  ggsave(filename = fig_path_real, plot = fig_real,
         width = 9, height = 6, dpi = 200)
  message("Saved figure: ", fig_path_real)
}

invisible(list(results_all = results_all, summary_tbl = summary_tbl))
