# =====================================================================
# 02_reassessment_recalibration.R — Panelist 09 (Bridger), re-review round
#
# Recomputes the state-evidence calibration of 01_state_calibration.R on
# the CURRENT (2026-06-11, IRS-anchored) base: 44.47M eligible, $14.15B
# conservative headline at 59.0% conditional take-up.
#
# Adds the advisory numbers requested for the open Tier-2 items:
#   Tier 2.1 — recommended W-2 payroll-default participation rate
#   Tier 2.2 — recommended persistence factor for a matched, PORTABLE
#              federal account (vs. the employer-keyed state programs)
#
# Run from the repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/09-bridger-state-programs/code/02_reassessment_recalibration.R
#
# Inputs (read-only): data/processed/universal_sm_hybrid/simulation_results.parquet
#                     data/processed/universal_sm_hybrid/scenario_results.parquet
# Outputs: economist-panel/09-bridger-state-programs/tables/reassessment_scenarios.csv
# =====================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr)
})

tab_dir <- "economist-panel/09-bridger-state-programs/tables"

# ---------------------------------------------------------------------
# 0. State-program parameters (sources unchanged from round 1; see
#    tables/state_program_parameters.csv and sources/sources.md)
# ---------------------------------------------------------------------
p_chalmers_feas   <- 0.624   # OregonSaves feasible participation (Chalmers et al. 2021, Table 1)
p_quinby_lower    <- 0.48    # positive-balance lower bound (Quinby et al., cited Chalmers fn.12)
p_chalmers_global <- 0.343   # OregonSaves global participation

# Chalmers et al. (2021) Table 11: share of open OregonSaves accounts with
# any inflow in months 1-12, split by active vs. separated ("inactive")
# employment status at the originating employer.
chal_t11 <- data.frame(
  month        = 1:12,
  n_active     = c(57171,53695,49820,45146,39752,35525,32653,29645,26776,23444,19577,16508),
  pin_active   = c(99.9,84.2,78.2,72.8,69.1,66.7,63.9,61.8,59.5,56.8,55.3,56.0),
  n_inactive   = c(1872,3852,5512,7033,7807,8360,8667,8913,8845,8412,7755,7109),
  pin_inactive = c(99.8,48.4,27.9,20.5,13.9,11.3,9.7,8.5,8.6,8.3,7.3,7.2)
)
chal_t11 <- chal_t11 %>%
  mutate(inflow_all = (n_active*pin_active + n_inactive*pin_inactive) /
                      (n_active + n_inactive) / 100)

persistence_state  <- mean(chal_t11$inflow_all)          # ~0.594, employer-keyed program
persistence_active <- mean(chal_t11$pin_active) / 100    # active-employee-only counterfactual

cat(sprintf("Persistence, state program (all accounts):        %.3f\n", persistence_state))
cat(sprintf("Persistence, active-employee-only counterfactual: %.3f\n", persistence_active))
# Rationale: in OregonSaves the inflow share among SEPARATED workers collapses
# to 7-9% because contributions are keyed to the originating employer's payroll;
# a universal federal mandate + worker-level portable account re-establishes the
# deduction automatically at the next covered job, so the separated-worker
# collapse largely disappears. The active-only series (~0.69) is the portability
# counterfactual upper anchor; my recommended central is 0.70 (the match and the
# six-month vesting hold add a small retention margin on top), band 0.62-0.75
# with 0.62 = state-observed-plus-modest-portability-gain lower bound.
persistence_reco   <- 0.70

# Tier 2.1 recommendation: W-2 payroll-default participation.
# CalSavers effective opt-out 34.8% -> ~65% participating; OregonSaves feasible
# 62.4%; both are MATCH-FREE. A 100-200% match aimed at the modal stated
# opt-out reason ("can't afford to save", 38.6%) should add a few points.
# Central 65%, band 55-75. Self-employed (estimated-tax/1099/platform rails,
# no payroll default): central 25%, band 15-35 (no state evidence; anchored on
# pre-auto-enrollment voluntary IRA activity of ~8-22% with a match premium).
p_w2_reco <- 0.65
p_se_reco <- 0.25

# ---------------------------------------------------------------------
# 1. Load current simulation results; verify the new base
# ---------------------------------------------------------------------
sim  <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
elig <- sim %>% filter(eligible_flag)

elig_M <- sum(elig$WPFINWGT)/1e6
cat(sprintf("\nEligible (current base): %.2fM (canonical: 44.47M)\n", elig_M))
stopifnot(abs(elig_M - 44.47) < 0.1)

scen_repo <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
print(as.data.frame(scen_repo))

# Headline structure: row-level observed participation for workers with an
# existing DC account; uniform conditional rate for everyone else.
rowlev   <- elig %>% filter(has_existing_dc_flag %in% TRUE) %>%
            mutate(p_obs = ifelse(is.na(participating_dc_flag), FALSE, participating_dc_flag))
unif_emp <- elig %>% filter(!(has_existing_dc_flag %in% TRUE), route_chr == "employer_plan")
unif_uni <- elig %>% filter(!(has_existing_dc_flag %in% TRUE), route_chr == "universal_account")

# Recover the uniform conditional rate from the published headline if present;
# fall back to SIPP-observed conditional among DC-access workers.
cost_rowlev <- sum(rowlev$WPFINWGT * rowlev$match_per_worker_num * rowlev$p_obs)
part_rowlev <- sum(rowlev$WPFINWGT * rowlev$p_obs)
full_emp    <- sum(unif_emp$WPFINWGT * unif_emp$match_per_worker_num)
full_uni    <- sum(unif_uni$WPFINWGT * unif_uni$match_per_worker_num)
w_emp       <- sum(unif_emp$WPFINWGT)
w_uni       <- sum(unif_uni$WPFINWGT)

p_repo <- 0.590  # current conservative headline conditional rate (data guide)
headline <- (cost_rowlev + p_repo * (full_emp + full_uni)) / 1e9
cat(sprintf("\nReproduced conservative headline at p=%.3f: $%.3fB (published $14.15B)\n",
            p_repo, headline))
cat(sprintf("  row-level (existing DC): %.2fM elig, %.2fM participants, $%.2fB\n",
            sum(rowlev$WPFINWGT)/1e6, part_rowlev/1e6, cost_rowlev/1e9))
cat(sprintf("  uniform employer route:  %.2fM, full-part $%.2fB\n", w_emp/1e6, full_emp/1e9))
cat(sprintf("  uniform universal route: %.2fM, full-part $%.2fB  <- state-calibration base\n",
            w_uni/1e6, full_uni/1e9))
cat(sprintf("  self-employed share of universal-route base: %.1f%%\n",
            100*sum(unif_uni$WPFINWGT*(unif_uni$self_employed_flag %in% TRUE))/w_uni))

# Sanity: also report the 80% and 100% rungs as the pipeline defines them
# (uniform rate applied universally).
for (p in c(0.80, 1.00)) {
  cat(sprintf("  uniform-everywhere rung p=%.2f: $%.2fB\n",
      p * sum(elig$WPFINWGT * elig$match_per_worker_num) / 1e9, p)[1])
}

# ---------------------------------------------------------------------
# 2. Scenario engine (universal-route-without-existing-DC is the
#    calibration base; row-level and employer-route held at repo treatment)
# ---------------------------------------------------------------------
scenario_cost <- function(p_w2, p_se = p_w2, adj_fun = identity) {
  contrib_adj <- adj_fun(unif_uni$default_contrib_num)
  match_adj   <- pmin(unif_uni$match_rate_frac_num * contrib_adj, 1000)
  is_se       <- unif_uni$self_employed_flag %in% TRUE
  p_vec       <- ifelse(is_se, p_se, p_w2)
  cost_uni    <- sum(unif_uni$WPFINWGT * match_adj * p_vec)
  part_uni    <- sum(unif_uni$WPFINWGT * p_vec)
  cost_fix    <- cost_rowlev + p_repo * full_emp
  part_fix    <- part_rowlev + p_repo * w_emp
  data.frame(participants_M = (part_uni + part_fix)/1e6,
             cost_B         = (cost_uni + cost_fix)/1e9)
}

scen <- bind_rows(
  cbind(scenario = "Current conservative headline (59.0% conditional)",
        scenario_cost(p_repo)),
  cbind(scenario = "State upper: 62.4% feasible participation",
        scenario_cost(p_chalmers_feas)),
  cbind(scenario = "State central: 48% positive-balance participation",
        scenario_cost(p_quinby_lower)),
  cbind(scenario = "State lower: 34.3% global participation",
        scenario_cost(p_chalmers_global)),
  cbind(scenario = "Persistence only, state-observed 0.594 (employer-keyed)",
        scenario_cost(p_repo, adj_fun = function(x) x * persistence_state)),
  cbind(scenario = "Persistence only, portable-account 0.70 (recommended)",
        scenario_cost(p_repo, adj_fun = function(x) x * persistence_reco)),
  cbind(scenario = "RECOMMENDED CENTRAL: W-2 65% / SE 25% x persistence 0.70",
        scenario_cost(p_w2_reco, p_se_reco, adj_fun = function(x) x * persistence_reco)),
  cbind(scenario = "Recommended lower: W-2 55% / SE 15% x persistence 0.62",
        scenario_cost(0.55, 0.15, adj_fun = function(x) x * 0.62)),
  cbind(scenario = "Recommended upper: W-2 75% / SE 35% x persistence 0.75",
        scenario_cost(0.75, 0.35, adj_fun = function(x) x * 0.75)),
  cbind(scenario = "80% everywhere x persistence 0.70 (stress on brief central)",
        scenario_cost(0.80, 0.80, adj_fun = function(x) x * persistence_reco))
)
scen <- scen %>% mutate(pct_of_headline = 100 * cost_B / headline)

cat("\n==================== RE-REVIEW SCENARIOS (current base) ====================\n")
for (i in seq_len(nrow(scen))) {
  cat(sprintf("%-62s %6.2fM  $%6.2fB  (%5.1f%%)\n",
              scen$scenario[i], scen$participants_M[i], scen$cost_B[i],
              scen$pct_of_headline[i]))
}

write.csv(scen %>% mutate(across(where(is.numeric), ~round(.x, 2))),
          file.path(tab_dir, "reassessment_scenarios.csv"), row.names = FALSE)

# ---------------------------------------------------------------------
# 3. Graduated 1/2/3%-by-FPL default vs flat 3% — state-evidence read
#    (FPL approximated: 100%/150% FPL single-person 2024 ~ $15,060/$22,590,
#     projected x1.093 -> $16,461/$24,691, against personal earnings.
#     This is the same default-household-size approximation D4 flags.)
# ---------------------------------------------------------------------
fpl100 <- 15060 * 1.093
fpl150 <- 22590 * 1.093
grad <- unif_uni %>%
  mutate(rate = case_when(earnings_num < fpl100 ~ 0.01,
                          earnings_num < fpl150 ~ 0.02,
                          TRUE ~ 0.03),
         contrib_g = rate * earnings_num,
         match_g   = pmin(match_rate_frac_num * contrib_g, 1000),
         match_f   = pmin(match_rate_frac_num * default_contrib_num, 1000))
gsum <- grad %>% summarise(
  share_below150 = sum(WPFINWGT * (rate < 0.03)) / sum(WPFINWGT),
  match_flat_B   = sum(WPFINWGT * match_f) / 1e9,
  match_grad_B   = sum(WPFINWGT * match_g) / 1e9,
  mean_match_flat_below150 = weighted.mean(match_f[rate < 0.03], WPFINWGT[rate < 0.03]),
  mean_match_grad_below150 = weighted.mean(match_g[rate < 0.03], WPFINWGT[rate < 0.03])
)
cat("\nGraduated-default diagnostic (universal-route base, full participation):\n")
print(as.data.frame(gsum), digits = 3)
cat("Done.\n")
