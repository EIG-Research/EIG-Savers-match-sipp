# ------------------------------------------------------------------
# 03_national_saving.R  --  Dr. Sam Okafor (macro-fiscal panelist)
# Back-of-envelope net national-saving effect of the deficit-financed
# match, using Chetty, Friedman, Leth-Petersen, Nielsen, and Olsen
# (2014, QJE) active/passive saver pass-through estimates applied to
# the proposal's two routing channels.
#
# Run from the repository root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/07-okafor-macro-fiscal/code/03_national_saving.R
#
# Accounting framework (annual, steady state, TY2027 dollars):
#   d(National saving) = d(Private saving) - Match outlays
#   (the match is a deficit-financed transfer: public saving falls
#   dollar-for-dollar with outlays, before debt-service compounding).
#
#   Universal-account route (newly auto-enrolled workers):
#     The 3 percent default contribution is a policy-induced flow.
#     Chetty et al. (2014) find ~85 percent of individuals are
#     passive savers for whom automatic contributions pass through
#     to total saving roughly one-for-one (their headline: each $1
#     of automatic contribution raises total saving by ~85-90 cents
#     in the population); active savers offset by shifting assets,
#     and each $1 of subsidy expenditure raises total saving by ~1
#     cent for subsidy-induced responses.
#     New private saving = pi_u x (induced contributions + match) +
#                          0.01 x (1 - pi_u) x (same flows)
#   Employer-plan route (workers already participating in a DC plan):
#     Contributions are pre-existing, not policy-induced; only the
#     match deposit is new money, and observed DC participants
#     contain a larger share of active savers who offset windfalls.
#     New private saving = pi_e x match + 0.01 x (1 - pi_e) x match
#
#   Passive-saver shares (low / central / high):
#     pi_u in {0.75, 0.85, 0.95}  (Chetty population share is 0.85;
#       newly defaulted low-income workers are plausibly more passive)
#     pi_e in {0.30, 0.50, 0.70}  (active savers are wealthier and
#       more financially sophisticated -- observed participants skew
#       active; bounds bracket the uncertainty)
#
# Flows by branch (headline scenario) from the repo pipeline:
#   - Match by branch from scenario_results.parquet rows
#     headline_dc_access_row_level (employer branch) and
#     headline_universal_account_uniform (universal branch).
#   - Induced contributions on the universal branch = full-
#     participation default contributions on that route (from
#     simulation_results.parquet) x the branch take-up rate (0.598).
# ------------------------------------------------------------------

suppressMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

out_dir_tab <- "economist-panel/07-okafor-macro-fiscal/tables"

# ---- 1. Flows by branch (headline scenario) -------------------------
scen <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
sim  <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

m_e <- scen$annual_cost_M_num[scen$scenario_name_chr == "headline_dc_access_row_level"] / 1000
m_u <- scen$annual_cost_M_num[scen$scenario_name_chr == "headline_universal_account_uniform"] / 1000
m_total <- scen$annual_cost_M_num[scen$scenario_name_chr == "headline_sipp_observed_conditional"] / 1000
takeup_u <- scen$takeup_rate_num[scen$scenario_name_chr == "headline_universal_account_uniform"]

stopifnot(abs(m_e + m_u - m_total) < 0.01)

contrib_u_full <- sim %>%
  filter(eligible_flag, route_chr == "universal_account") %>%
  summarise(bn = sum(default_contrib_num * WPFINWGT) / 1e9) %>%
  pull(bn)
c_u <- contrib_u_full * takeup_u   # induced contributions, headline take-up

cat(sprintf("Match, employer branch (headline):        $%.2fB\n", m_e))
cat(sprintf("Match, universal branch (headline):       $%.2fB\n", m_u))
cat(sprintf("Match, total (headline):                  $%.2fB\n", m_total))
cat(sprintf("Induced default contributions, universal: $%.2fB (= %.2f x %.3f)\n",
            c_u, contrib_u_full, takeup_u))

# ---- 2. Pass-through scenarios --------------------------------------
active_passthrough <- 0.01   # Chetty et al. (2014): ~1 cent per $1 for active/subsidy responses

cases <- tribble(
  ~case,     ~pi_u, ~pi_e,
  "Low",      0.75,  0.30,
  "Central",  0.85,  0.50,
  "High",     0.95,  0.70
) %>%
  mutate(
    universal_flows_bn = c_u + m_u,
    employer_flows_bn  = m_e,
    new_private_universal_bn = pi_u * universal_flows_bn +
                               active_passthrough * (1 - pi_u) * universal_flows_bn,
    new_private_employer_bn  = pi_e * employer_flows_bn +
                               active_passthrough * (1 - pi_e) * employer_flows_bn,
    new_private_total_bn = new_private_universal_bn + new_private_employer_bn,
    public_dissaving_bn  = -m_total,
    net_national_saving_bn = new_private_total_bn + public_dissaving_bn,
    net_private_per_federal_dollar = new_private_total_bn / m_total,
    net_national_per_federal_dollar = net_national_saving_bn / m_total
  )

cat("\nNet national-saving back-of-envelope (annual, TY2027 $B):\n")
print(as.data.frame(cases %>% mutate(across(where(is.numeric), ~ round(.x, 2)))))

# ---- 3. Assumptions + results table ---------------------------------
out <- cases %>%
  transmute(
    Case = case,
    `Passive share, universal route` = pi_u,
    `Passive share, employer route`  = pi_e,
    `Induced contributions, universal route ($B)` = round(c_u, 2),
    `Match, universal route ($B)` = round(m_u, 2),
    `Match, employer route ($B)`  = round(m_e, 2),
    `New private saving ($B)`     = round(new_private_total_bn, 2),
    `Public dissaving ($B)`       = round(public_dissaving_bn, 2),
    `Net national saving ($B)`    = round(net_national_saving_bn, 2),
    `New private saving per federal dollar` = round(net_private_per_federal_dollar, 2),
    `Net national saving per federal dollar` = round(net_national_per_federal_dollar, 2)
  )
write.csv(out, file.path(out_dir_tab, "national_saving_range.csv"), row.names = FALSE)
cat("\nWrote tables/national_saving_range.csv\n")

# ---- 4. Contrast: subsidy-only counterfactual -----------------------
# If the same $14.9B were delivered as a pure price subsidy with no
# default-contribution architecture (the Chetty 'subsidy' result:
# ~1 cent of new saving per $1 of expenditure among responders, who
# are mostly active savers), net national saving would be ~ -$14.8B.
subsidy_only <- -m_total + active_passthrough * m_total
cat(sprintf("Subsidy-only counterfactual (no defaults): net national saving ~ $%.1fB\n",
            subsidy_only))
