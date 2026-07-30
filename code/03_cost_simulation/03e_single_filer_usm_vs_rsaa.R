# 03e_single_filer_usm_vs_rsaa.R -- Single-filer lifetime illustration: Universal Saver's Match
# (USM, the hybrid proposal) vs. RSAA (S.1526). USM-vs-RSAA ONLY.
# Author: Ben Glasner
#
# IMPORTANT SCOPE GUARD: this script compares ONLY the USM proposal and the RSAA as designed.
# It deliberately does NOT compute the enacted SECURE 2.0 §6433 Saver's Match. Do not add it here.
#
# For a representative single worker at several starting incomes, computes the annual federal credit
# and the 40-year account balance under each design, holding contribution at the 3% auto-default that
# both designs use. Both eligibility bands are indexed at wage growth (steady-state: RSAA republishes
# its median annually; USM re-anchors to a fresh median each decade), isolating the formula/cap
# difference from an indexing artifact. See drafts/rsaa_comparison/.

rm(list = ls())
suppressMessages({ library(dplyr); library(arrow); library(openxlsx) })
source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "_shared", "params.R"))
R <- rsaa_params()

# --- Lifetime assumptions (match 03c for continuity) ---
START_AGE       <- 19L
YEARS_OF_SAVING <- 40L
WAGE_GROWTH     <- 0.030
ANNUAL_RETURN   <- 0.070
CONTRIB_RATE    <- 0.03
base_year       <- 2027L

# --- USM (hybrid) single-filer schedule, TY2027 base (from the hybrid pivot table) ---
USM_PIVOT_2027    <- 32235.32     # 50% match rate at this MAGI
USM_ENDPOINT_2027 <- 42980.43     # 0% match rate at/above this MAGI (= 4/3 x pivot)
USM_FLOOR_RATE    <- 2.00         # match rate at MAGI = 0
USM_PIVOT_RATE    <- 0.50
USM_MATCH_CAP     <- 1000         # per-individual dollar cap

# USM match rate as a function of MAGI (200% at 0 -> 50% at pivot -> 0 at endpoint).
usm_rate <- function(magi, pivot, endpoint) {
  seg1 <- USM_FLOOR_RATE - (USM_FLOOR_RATE - USM_PIVOT_RATE) * (magi / pivot)
  seg2 <- USM_PIVOT_RATE * (endpoint - magi) / (endpoint - pivot)
  pmax(0, ifelse(magi <= pivot, seg1, ifelse(magi <= endpoint, seg2, 0)))
}

# RSAA single-filer credit at the 3% default (1% auto + 100% of the 3% contribution = 4% of income),
# capped at 5% of M, reduced $75 per $1,000 (or portion) of income above M. Single phaseout amount = M.
rsaa_credit_single <- function(income, M) {
  contribution <- CONTRIB_RATE * income
  tier1 <- pmin(contribution, R$match_kink1 * income)
  match <- R$match_rate_below_kink1 * tier1                          # tier2 = 0 at a 3% contribution
  auto  <- R$auto_credit_rate * income
  cap   <- pmax(0, R$credit_limit_share * M -
                  (R$phaseout_slope * 1000) * ceiling(pmax(0, income - M) / 1000))
  pmin(auto + match, cap)
}

# --- Representative single-filer starting incomes (TY2027) ---
start_incomes <- c(18000, 25000, 33350, 45000)

run_worker <- function(start_income) {
  yr <- seq_len(YEARS_OF_SAVING)
  income      <- start_income * (1 + WAGE_GROWTH)^(yr - 1L)
  wage_index  <- (1 + WAGE_GROWTH)^(yr - 1L)                 # both bands track wages (steady-state)
  usm_pivot   <- USM_PIVOT_2027    * wage_index
  usm_end     <- USM_ENDPOINT_2027 * wage_index
  usm_cap     <- USM_MATCH_CAP     * wage_index
  M_t         <- R$applicable_median_income_2027 * wage_index

  contribution <- CONTRIB_RATE * income
  usm_credit  <- pmin(usm_rate(income, usm_pivot, usm_end) * contribution, usm_cap)
  rsaa_credit <- rsaa_credit_single(income, M_t)

  bal <- function(gov) {
    b <- numeric(YEARS_OF_SAVING); prev <- 0
    for (t in yr) { b[t] <- prev * (1 + ANNUAL_RETURN) + contribution[t] + gov[t]; prev <- b[t] }
    b
  }
  data.frame(
    start_income = start_income,
    usm_credit_year1  = round(usm_credit[1], 0),
    rsaa_credit_year1 = round(rsaa_credit[1], 0),
    own_contrib_total   = round(sum(contribution), 0),
    usm_gov_total       = round(sum(usm_credit), 0),
    rsaa_gov_total      = round(sum(rsaa_credit), 0),
    usm_balance_40yr    = round(tail(bal(usm_credit), 1), 0),
    rsaa_balance_40yr   = round(tail(bal(rsaa_credit), 1), 0)
  )
}

results <- bind_rows(lapply(start_incomes, run_worker))

out_dir <- file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "output", "tables", "rsaa_comparison")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
write.csv(results, file.path(out_dir, "single_filer_usm_vs_rsaa_lifetime.csv"), row.names = FALSE)

wb <- createWorkbook()
addWorksheet(wb, "Single filer USM vs RSAA"); writeData(wb, "Single filer USM vs RSAA", results)
notes <- data.frame(note = c(
  sprintf("Generated %s.", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "USM vs RSAA ONLY -- the enacted SECURE 2.0 Saver's Match is intentionally excluded.",
  sprintf("Single filer, age %d, %d years, %.0f%% contribution, %.0f%% return, %.0f%% wage growth.",
          START_AGE, YEARS_OF_SAVING, CONTRIB_RATE*100, ANNUAL_RETURN*100, WAGE_GROWTH*100),
  "Both eligibility bands indexed at wage growth (steady-state); USM $1,000 cap and RSAA 5%-of-M cap likewise.",
  sprintf("USM single: 200%% floor, 50%% at pivot $%s, 0 at endpoint $%s, $1,000 cap.",
          format(USM_PIVOT_2027, big.mark=","), format(USM_ENDPOINT_2027, big.mark=",")),
  sprintf("RSAA single: 4%% of income at the 3%% default, capped at 5%% of M ($%s), phased $75/$1,000 above M.",
          format(round(R$applicable_median_income_2027), big.mark=","))
))
addWorksheet(wb, "Notes"); writeData(wb, "Notes", notes)
saveWorkbook(wb, file.path(out_dir, "single_filer_usm_vs_rsaa_lifetime.xlsx"), overwrite = TRUE)

message("03e complete (USM vs RSAA, single filers).")
print(results, row.names = FALSE)
