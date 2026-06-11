# =====================================================================
# 01_state_calibration.R  —  Panelist 09 (Bridger, state auto-IRA lens)
#
# Re-prices the universal-account route of the hybrid proposal under
# parameters observed in state auto-IRA programs (OregonSaves, CalSavers).
# Run from the repository root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/09-bridger-state-programs/code/01_state_calibration.R
#
# Inputs (read-only):
#   data/processed/universal_sm_hybrid/simulation_results.parquet
#   data/processed/universal_sm_hybrid/scenario_results.parquet
# Outputs (written only inside economist-panel/09-bridger-state-programs/):
#   tables/state_program_parameters.csv
#   tables/state_calibrated_scenarios.csv
#   tables/compliance_ramp_scenario.csv
#   figures/fig1_state_calibrated_cost_ladder.png
#   figures/fig2_contribution_adequacy.png
#   figures/fig3_compliance_ramp.png
#
# External parameters are taken from documents downloaded into
# economist-panel/09-bridger-state-programs/sources/ (see sources.md):
#   [CHAL]  Chalmers, Mitchell, Reuter, Zhong (2021), MRDRC WP 2021-425
#   [CALS]  CalSavers Participation & Funding Snapshot, 8/31/2025
#   [ORSA]  OregonSaves 2024 Annual Report (dashboard as of 12/31/2024)
#   [CSEB]  CalSavers Board Executive Director's Report, March 6, 2025
# =====================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

out_dir  <- "economist-panel/09-bridger-state-programs"
fig_dir  <- file.path(out_dir, "figures")
tab_dir  <- file.path(out_dir, "tables")

# EIG 2022 primary palette (Infrastructure/style/tokens/eig-style-tokens.v1.json)
eig_teal   <- "#024140"; eig_green  <- "#19644D"; eig_green5 <- "#5E9C86"
eig_blue   <- "#194F8B"; eig_gold   <- "#E1AD28"; eig_cyan   <- "#176F96"
eig_purple <- "#39274F"

eig_theme <- theme_minimal(base_size = 13) +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor   = element_blank(),
        plot.title = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 11, color = "grey25"),
        plot.caption = element_text(size = 8.5, color = "grey35", hjust = 0))

# ---------------------------------------------------------------------
# 0. State-program parameters (every number sourced; see sources.md)
# ---------------------------------------------------------------------

# Participation rates
p_repo            <- 0.5979   # repo headline uniform take-up (scenario_results.parquet)
p_chalmers_feas   <- 0.624    # [CHAL] feasible participation rate, April 2020 (Table 1)
p_quinby_lower    <- 0.48     # Quinby et al. (2020) positive-balance lower bound, cited in [CHAL] fn.12
p_chalmers_global <- 0.343    # [CHAL] global participation rate, April 2020 (Table 1)

# Contribution levels (conditional on contributing in the last 30 days)
cals_median_mo  <- 148        # [CALS] median monthly contribution, 8/31/2025
cals_mean_mo    <- 194        # [CALS] average monthly contribution, 8/31/2025
cals_avg_rate   <- 0.0523     # [CALS] average contribution rate, 8/31/2025
orsa_median_mo  <- 141        # [ORSA] median monthly contribution, 12/31/2024
orsa_mean_mo    <- 185        # [ORSA] average monthly contribution, 12/31/2024
orsa_avg_rate   <- 0.066      # [ORSA] average savings rate (funded accounts), 12/31/2024

# Rate-adjusted state contribution dollars: what the observed state median/mean
# contributor would put in at the proposal's flat 3 percent default instead of
# the ~5.23 percent average rate actually observed in CalSavers.
cals_median_mo_3pct <- cals_median_mo * 0.03 / cals_avg_rate   # ~ $84.9/mo
cals_mean_mo_3pct   <- cals_mean_mo   * 0.03 / cals_avg_rate   # ~ $111.3/mo
cap_annual_median   <- 12 * cals_median_mo_3pct                # ~ $1,019/yr
cap_annual_mean     <- 12 * cals_mean_mo_3pct                  # ~ $1,336/yr

# Contribution persistence over the first 12 months in OregonSaves:
# share of open accounts with any inflow, by month since first contribution,
# combining active and inactive employees ([CHAL] Table 11).
chal_t11 <- data.frame(
  month       = 1:12,
  n_active    = c(57171,53695,49820,45146,39752,35525,32653,29645,26776,23444,19577,16508),
  pin_active  = c(99.9,84.2,78.2,72.8,69.1,66.7,63.9,61.8,59.5,56.8,55.3,56.0),
  n_inactive  = c(1872,3852,5512,7033,7807,8360,8667,8913,8845,8412,7755,7109),
  pin_inactive= c(99.8,48.4,27.9,20.5,13.9,11.3,9.7,8.5,8.6,8.3,7.3,7.2)
)
chal_t11 <- chal_t11 %>%
  mutate(inflow_share = (n_active*pin_active + n_inactive*pin_inactive) /
                        (n_active + n_inactive) / 100)
persistence_y1 <- mean(chal_t11$inflow_share)
cat(sprintf("OregonSaves first-12-month contribution persistence factor: %.3f\n", persistence_y1))

# Employer-mandate compliance ramp (employee-coverage shares of the W-2
# universal-account route). Scenario anchors:
#  - mature share 0.853 = CalSavers prior-wave employer response rate after
#    3-5 years past deadline plus FTB penalty enforcement ([CALS] wave table)
#  - by ~2.5 years after the first compulsory deadlines, ~80 percent of
#    *registered* employees were at employers that had processed payroll,
#    but registration itself was far from complete ([CHAL] Sec. III);
#    CalSavers Wave 2023/2024 cohorts cleared penalty status only after
#    FTB mailings in late 2024 ([CSEB]).
# Year-1/2/3 shares below are scenario assumptions anchored on those facts.
ramp <- data.frame(
  year  = c("Year 1", "Year 2", "Year 3", "Mature (5+ yrs)"),
  share = c(0.30, 0.55, 0.75, 0.853)
)

# Withdrawal / leakage context (used in prose and the parameters table)
cals_withdrawal_rate <- 0.2459          # [CALS] full-withdrawal accounts / payroll contributing accounts
cals_withdrawn_cum   <- 446.9/1594.7    # [CALS] cumulative withdrawals / cumulative contributions
orsa_withdrawn_cum   <- 160.2/445.4     # [ORSA] cumulative withdrawals / contributions
orsa_withdrawn_2024  <- 49.0/108.4      # [ORSA] 2024 distributions / 2024 contributions

# ---------------------------------------------------------------------
# 1. Load simulation results and reproduce the repo headline
# ---------------------------------------------------------------------
# The repo headline splits the 46.07M eligible workers into:
#   (i)  row-level group: has_existing_dc_flag == TRUE (15.99M) -> observed
#        participating_dc_flag row by row;
#   (ii) uniform group: everyone else (30.07M) -> uniform 59.79 percent.
# This reproduces the published $14.95B exactly (verified below).
# State calibration is applied to the universal-account workers WITHOUT an
# existing DC account (22.01M of the 26.65M universal route) — exactly the
# population state auto-IRAs serve (only ~10 percent of OregonSaves-targeted
# workers had their own plan; Chalmers et al. 2021). The row-level group and
# the 8.06M employer-route workers without existing accounts are held at the
# repo treatment in every scenario.
sim  <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
elig <- sim %>% filter(eligible_flag)

stopifnot(abs(sum(elig$WPFINWGT)/1e6 - 46.07) < 0.05)

rowlev   <- elig %>% filter(has_existing_dc_flag %in% TRUE) %>%
            mutate(p_obs = ifelse(is.na(participating_dc_flag), FALSE, participating_dc_flag))
unif_emp <- elig %>% filter(!(has_existing_dc_flag %in% TRUE), route_chr == "employer_plan")
unif_uni <- elig %>% filter(!(has_existing_dc_flag %in% TRUE), route_chr == "universal_account")

cost_rowlev <- sum(rowlev$WPFINWGT * rowlev$match_per_worker_num * rowlev$p_obs)
part_rowlev <- sum(rowlev$WPFINWGT * rowlev$p_obs)
fullcost_unif_emp <- sum(unif_emp$WPFINWGT * unif_emp$match_per_worker_num)
fullcost_unif_uni <- sum(unif_uni$WPFINWGT * unif_uni$match_per_worker_num)
w_unif_emp <- sum(unif_emp$WPFINWGT)
w_unif_uni <- sum(unif_uni$WPFINWGT)

headline_repro <- (cost_rowlev + p_repo * (fullcost_unif_emp + fullcost_unif_uni)) / 1e9
cat(sprintf("Reproduced repo headline: $%.3fB (published: $14.946B)\n", headline_repro))
cat(sprintf("  row-level group (existing DC): %.2fM eligible, %.2fM participants, $%.2fB\n",
            sum(rowlev$WPFINWGT)/1e6, part_rowlev/1e6, cost_rowlev/1e9))
cat(sprintf("  uniform group, employer route: %.2fM | universal route (calibration base): %.2fM, full-part cost $%.2fB\n",
            w_unif_emp/1e6, w_unif_uni/1e6, fullcost_unif_uni/1e9))

# Helper: total annual cost and participants under
#   p_u      : uniform participation rate for universal-account workers
#              without an existing DC account (state-calibration base)
#   adj_fun  : function transforming those workers' annual contributions
#   ramp_w2  : coverage multiplier applied to the W-2 (non-self-employed)
#              part of that base (employer-compliance ramp)
scenario_cost <- function(p_u, adj_fun = identity, ramp_w2 = 1) {
  contrib_adj <- adj_fun(unif_uni$default_contrib_num)
  match_adj   <- pmin(unif_uni$match_rate_frac_num * contrib_adj, 1000)
  cover       <- ifelse(unif_uni$self_employed_flag %in% TRUE, 1, ramp_w2)
  cost_uni    <- p_u * sum(unif_uni$WPFINWGT * match_adj * cover)
  part_uni    <- p_u * sum(unif_uni$WPFINWGT * cover)
  # held fixed in all scenarios: row-level group + employer-route uniform group
  cost_fix    <- cost_rowlev + p_repo * fullcost_unif_emp
  part_fix    <- part_rowlev + p_repo * w_unif_emp
  data.frame(participants_M = (part_uni + part_fix)/1e6,
             cost_B         = (cost_uni + cost_fix)/1e9)
}

# ---------------------------------------------------------------------
# 2. Scenario ladder
# ---------------------------------------------------------------------
scen <- bind_rows(
  cbind(scenario = "Repo headline (SIPP conditional, 59.8%)",
        family = "Baseline", scenario_cost(p_repo)),
  cbind(scenario = "State upper: OregonSaves feasible participation (62.4%)",
        family = "A. Participation", scenario_cost(p_chalmers_feas)),
  cbind(scenario = "State central: positive-balance participation (48%)",
        family = "A. Participation", scenario_cost(p_quinby_lower)),
  cbind(scenario = "State lower: OregonSaves global participation (34.3%)",
        family = "A. Participation", scenario_cost(p_chalmers_global)),
  cbind(scenario = "Contribution persistence: 59.4% of default dollars arrive",
        family = "B. Contributions", scenario_cost(p_repo, adj_fun = function(x) x * persistence_y1)),
  cbind(scenario = "Contributions capped at state median dollars ($1,019/yr)",
        family = "B. Contributions", scenario_cost(p_repo, adj_fun = function(x) pmin(x, cap_annual_median))),
  cbind(scenario = "Contributions capped at state mean dollars ($1,336/yr)",
        family = "B. Contributions", scenario_cost(p_repo, adj_fun = function(x) pmin(x, cap_annual_mean))),
  cbind(scenario = "State-evidence-calibrated central (48% x persistence)",
        family = "C. Combined", scenario_cost(p_quinby_lower, adj_fun = function(x) x * persistence_y1)),
  cbind(scenario = "State-evidence-calibrated lower (34.3% x persistence x median cap)",
        family = "C. Combined", scenario_cost(p_chalmers_global,
                       adj_fun = function(x) pmin(x, cap_annual_median) * persistence_y1))
)
scen <- scen %>% mutate(pct_of_headline = 100 * cost_B / headline_repro)
print(scen, digits = 4)
write.csv(scen %>% mutate(across(where(is.numeric), ~round(.x, 2))),
          file.path(tab_dir, "state_calibrated_scenarios.csv"), row.names = FALSE)

# ---------------------------------------------------------------------
# 3. Employer-compliance ramp applied to the combined central scenario
# ---------------------------------------------------------------------
ramp_out <- ramp %>%
  rowwise() %>%
  mutate(res = list(scenario_cost(p_quinby_lower,
                                  adj_fun = function(x) x * persistence_y1,
                                  ramp_w2 = share))) %>%
  unnest(res) %>%
  mutate(pct_of_headline = 100 * cost_B / headline_repro)
print(ramp_out, digits = 4)
write.csv(ramp_out %>% mutate(across(where(is.numeric), ~round(.x, 2))),
          file.path(tab_dir, "compliance_ramp_scenario.csv"), row.names = FALSE)

# ---------------------------------------------------------------------
# 4. Parameters table (provenance for every external number)
# ---------------------------------------------------------------------
params <- tribble(
  ~parameter, ~value, ~program_asof, ~source,
  "Effective opt-out rate", "34.82%", "CalSavers, 8/31/2025", "CalSavers Participation & Funding Snapshot (sources/calsavers-participation-snapshot-aug-2025.pdf)",
  "Opt-out rate (0-30 days, since inception)", "27.0%", "OregonSaves, 12/31/2024", "OregonSaves 2024 Annual Report (sources/oregonsaves-annual-report-2024.pdf)",
  "Feasible participation rate", "62.4%", "OregonSaves, Apr 2020", "Chalmers-Mitchell-Reuter-Zhong, MRDRC WP 2021-425, Table 1 (sources/chalmers-mitchell-reuter-zhong-oregonsaves-mrdrc-wp425.pdf)",
  "Global participation rate (positive balance)", "34.3%", "OregonSaves, Apr 2020", "Chalmers et al. (2021), Table 1",
  "Positive-balance participation, lower bound", "48%", "OregonSaves, Sep 2018-Sep 2019", "Quinby, Munnell, Hou, Belbase & Sanzenbacher (2020), cited in Chalmers et al. (2021) fn. 12",
  "Median / mean monthly contribution", "$148 / $194", "CalSavers, 8/31/2025", "CalSavers Snapshot 8/31/2025",
  "Median / mean monthly contribution", "$141 / $185", "OregonSaves, 12/31/2024", "OregonSaves 2024 Annual Report",
  "Average contribution rate", "5.23%", "CalSavers, 8/31/2025", "CalSavers Snapshot 8/31/2025",
  "Average savings rate (funded accounts)", "6.6%", "OregonSaves, 12/31/2024", "OregonSaves 2024 Annual Report",
  "Default contribution rate (with auto-escalation)", "5%, +1pp/yr to 10%", "OregonSaves", "Chalmers et al. (2021), Sec. II",
  "Probability of 12 consecutive monthly contributions", "30%", "OregonSaves, Apr 2020", "Chalmers et al. (2021), Fig. 2A",
  "First-year contribution persistence factor (computed)", sprintf("%.1f%%", 100*persistence_y1), "OregonSaves, Apr 2020", "Computed from Chalmers et al. (2021), Table 11 (this script)",
  "Annual job turnover in covered firms", "38.2%", "OregonSaves, Apr 2020", "Chalmers et al. (2021), Table 2",
  "Accounts with full withdrawal / payroll contributing accounts", "24.59%", "CalSavers, 8/31/2025", "CalSavers Snapshot 8/31/2025",
  "Cumulative withdrawals / cumulative contributions", sprintf("%.0f%%", 100*cals_withdrawn_cum), "CalSavers, 8/31/2025", "CalSavers Snapshot 8/31/2025",
  "Cumulative withdrawals / cumulative contributions", sprintf("%.0f%%", 100*orsa_withdrawn_cum), "OregonSaves, 12/31/2024", "OregonSaves 2024 Annual Report",
  "2024 distributions / 2024 contributions", sprintf("%.0f%%", 100*orsa_withdrawn_2024), "OregonSaves, CY2024", "OregonSaves 2024 Annual Report",
  "Average funded account balance", "$2,490 / $2,475", "CalSavers 8/2025 / OregonSaves 12/2024", "Program snapshots above",
  "Employer response rate, waves past deadline 3+ years", "85.3%", "CalSavers, 8/31/2025", "CalSavers Snapshot 8/31/2025 (wave table)",
  "Employer response rate incl. Wave 4 (1-4 employees)", "34.9%", "CalSavers, 8/31/2025", "CalSavers Snapshot 8/31/2025 (wave table)",
  "Post-deadline employers at full payroll facilitation", "18% (60,931 of 331,879)", "CalSavers, 8/31/2025", "CalSavers Snapshot 8/31/2025 (Chart 7)",
  "Employers referred to FTB; penalty compliance", "9,949 Wave-2023 notices; ~24% complied", "CalSavers, Oct-Dec 2024", "CalSavers Board ED Report 3/6/2025 (sources/calsavers-board-enforcement-update-2025-03.pdf)",
  "Registered employers actively submitting payroll (past 3 mo.)", "8,293 of 31,723", "OregonSaves, 12/31/2024", "OregonSaves 2024 Annual Report",
  "All state auto-IRA programs: assets / funded accounts", "$3.03B / 1.2M+", "All programs, 4/30/2026", "Georgetown CRI via PLANSPONSOR 5/15/2026 (sources/plansponsor-state-assets-3b-2026.html)"
)
write.csv(params, file.path(tab_dir, "state_program_parameters.csv"), row.names = FALSE)

# ---------------------------------------------------------------------
# 5. Figures
# ---------------------------------------------------------------------

# Figure 1: cost ladder
fig1_df <- bind_rows(
  scen %>% select(scenario, family, cost_B),
  ramp_out %>% filter(year == "Year 1") %>%
    transmute(scenario = "Year-1 employer compliance (30% W-2 coverage)",
              family = "D. Compliance ramp", cost_B)
) %>%
  mutate(scenario = factor(scenario, levels = rev(scenario)))

fam_cols <- c("Baseline" = eig_teal, "A. Participation" = eig_blue,
              "B. Contributions" = eig_green5, "C. Combined" = eig_gold,
              "D. Compliance ramp" = eig_purple)

f1 <- ggplot(fig1_df, aes(x = cost_B, y = scenario, fill = family)) +
  geom_col(width = 0.72) +
  geom_vline(xintercept = headline_repro, linetype = "dashed", color = eig_teal) +
  geom_text(aes(label = sprintf("$%.1fB", cost_B)), hjust = -0.12, size = 3.4, color = "grey15") +
  scale_fill_manual(values = fam_cols, name = NULL) +
  scale_x_continuous(labels = label_dollar(suffix = "B"), limits = c(0, 18),
                     expand = expansion(mult = c(0, 0.02))) +
  scale_y_discrete(labels = label_wrap(38)) +
  labs(title = "Figure 1. State-evidence calibration of the universal-account route",
       subtitle = "Annual federal Saver's Match cost under participation, contribution, and compliance parameters\nobserved in OregonSaves and CalSavers; employer-plan route held at repo treatment",
       x = "Annual federal match cost", y = NULL,
       caption = paste0("Source: Author's calculations from data/processed/universal_sm_hybrid/simulation_results.parquet (SIPP 2024 projected to TY2027);\n",
                        "Chalmers, Mitchell, Reuter & Zhong (2021) MRDRC WP 2021-425; CalSavers Snapshot 8/31/2025; OregonSaves 2024 Annual Report.\n",
                        "Dashed line: repository headline ($14.9B).")) +
  eig_theme + theme(legend.position = "bottom")
ggsave(file.path(fig_dir, "fig1_state_calibrated_cost_ladder.png"), f1,
       width = 10, height = 6.5, dpi = 200)

# Figure 2: contribution adequacy — 3% default dollars vs observed state contributions
uni_plot <- unif_uni %>%
  mutate(monthly_contrib = default_contrib_num / 12) %>%
  filter(monthly_contrib <= 400)

f2 <- ggplot(uni_plot, aes(x = monthly_contrib, weight = WPFINWGT)) +
  geom_histogram(binwidth = 10, boundary = 0, fill = eig_blue, color = "white", linewidth = 0.2,
                 aes(y = after_stat(count)/1e6)) +
  geom_vline(xintercept = cals_median_mo, color = eig_gold, linewidth = 0.9) +
  geom_vline(xintercept = orsa_median_mo, color = eig_green, linewidth = 0.9) +
  geom_vline(xintercept = cals_median_mo_3pct, color = eig_gold, linetype = "dashed", linewidth = 0.9) +
  annotate("text", x = cals_median_mo + 4, y = 6.4, hjust = 0, size = 3.3, color = eig_gold,
           label = "CalSavers median, $148/mo (5.23% avg rate)") +
  annotate("text", x = orsa_median_mo + 4, y = 7.1, hjust = 0, size = 3.3, color = eig_green,
           label = "OregonSaves median, $141/mo (6.6% avg rate)") +
  annotate("text", x = cals_median_mo_3pct + 4, y = 7.8, hjust = 0, size = 3.3, color = eig_gold,
           label = "CalSavers median re-scaled to a 3% default, $85/mo") +
  scale_x_continuous(labels = label_dollar(), breaks = seq(0, 400, 50)) +
  labs(title = "Figure 2. The proposal's assumed contributions vs. observed state auto-IRA dollars",
       subtitle = "Weighted distribution of the 3 percent default monthly contribution among the 22.0M eligible universal-account\nworkers without an existing DC account (truncated at $400/mo), against observed state median monthly contributions",
       x = "Assumed monthly contribution at the 3 percent default (TY2027 dollars)",
       y = "Workers (millions)",
       caption = paste0("Source: Author's calculations from data/processed/universal_sm_hybrid/simulation_results.parquet; CalSavers Participation & Funding\n",
                        "Snapshot 8/31/2025; OregonSaves 2024 Annual Report. State medians are conditional on a contribution in the prior 30 days.")) +
  eig_theme
ggsave(file.path(fig_dir, "fig2_contribution_adequacy.png"), f2,
       width = 10, height = 6, dpi = 200)

# Figure 3: compliance ramp
ramp_plot <- ramp_out %>%
  mutate(year = factor(year, levels = year))
f3 <- ggplot(ramp_plot, aes(x = year, y = cost_B, group = 1)) +
  geom_col(fill = eig_cyan, width = 0.6) +
  geom_hline(yintercept = headline_repro, linetype = "dashed", color = eig_teal) +
  geom_text(aes(label = sprintf("$%.1fB\n(%.0f%% W-2 coverage)", cost_B, 100*share)),
            vjust = -0.35, size = 3.5, color = "grey15", lineheight = 0.95) +
  annotate("text", x = 0.62, y = headline_repro + 0.45, hjust = 0, size = 3.3, color = eig_teal,
           label = "Repo headline: $14.9B") +
  scale_y_continuous(labels = label_dollar(suffix = "B"), limits = c(0, 16.5),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(title = "Figure 3. A CalSavers-style employer compliance ramp delays the spending path",
       subtitle = "State-evidence-calibrated central scenario (48% participation, OregonSaves contribution persistence),\nwith W-2 universal-account coverage phased in at CalSavers-anchored employer compliance shares",
       x = NULL, y = "Annual federal match cost",
       caption = paste0("Source: Author's calculations. Ramp anchors: CalSavers employer response rate of 85.3% for waves 3+ years past deadline and 34.9%\n",
                        "including Wave 4 (Snapshot 8/31/2025); FTB penalty enforcement beginning Oct 2023 (CalSavers Board ED Report 3/6/2025);\n",
                        "OregonSaves: half of registered employers had not processed payroll ~2.5 years in (Chalmers et al. 2021). Year-1/2/3 shares are scenario assumptions.")) +
  eig_theme
ggsave(file.path(fig_dir, "fig3_compliance_ramp.png"), f3,
       width = 10, height = 6, dpi = 200)

# ---------------------------------------------------------------------
# 6. Console summary for the assessment
# ---------------------------------------------------------------------
cat("\n==================== SUMMARY ====================\n")
cat(sprintf("State-calibration base (universal route, no existing DC): %.2fM eligible (%.1f%% of 46.07M); full-part cost $%.2fB\n",
            w_unif_uni/1e6, 100*w_unif_uni/sum(elig$WPFINWGT), fullcost_unif_uni/1e9))
cat(sprintf("Self-employed share of calibration base: %.1f%%\n",
            100*sum(unif_uni$WPFINWGT*(unif_uni$self_employed_flag %in% TRUE))/w_unif_uni))
cat(sprintf("Mean monthly 3%% default contribution (calibration base): $%.0f; weighted median annual $%.0f\n",
            weighted.mean(unif_uni$default_contrib_num/12, unif_uni$WPFINWGT),
            with(unif_uni[order(unif_uni$default_contrib_num),], default_contrib_num[which(cumsum(WPFINWGT)/sum(WPFINWGT) >= .5)[1]])))
cat(sprintf("Persistence factor (computed): %.3f\n", persistence_y1))
cat(sprintf("Rate-adjusted state contribution caps: median $%.0f/yr, mean $%.0f/yr\n",
            cap_annual_median, cap_annual_mean))
for (i in seq_len(nrow(scen))) {
  cat(sprintf("%-70s  %6.2fM  $%6.2fB  (%5.1f%% of headline)\n",
              scen$scenario[i], scen$participants_M[i], scen$cost_B[i], scen$pct_of_headline[i]))
}
cat("\nCompliance ramp (combined central):\n")
for (i in seq_len(nrow(ramp_out))) {
  cat(sprintf("%-18s coverage %4.0f%%  $%5.2fB (%5.1f%% of headline)\n",
              ramp_out$year[i], 100*ramp_out$share[i], ramp_out$cost_B[i], ramp_out$pct_of_headline[i]))
}
cat("Done.\n")
