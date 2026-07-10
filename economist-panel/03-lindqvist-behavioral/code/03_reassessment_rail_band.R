# 03_reassessment_rail_band.R
# Panelist 03 (Lindqvist, behavioral) -- RE-REVIEW supporting computation.
# Refresh the closed-form take-up curve and rail-specific scenario band on the
# CURRENT (IRS-anchored, 2026-06-11) base, replacing the first-round figures
# computed on the old 46.07M / $14.9B base.
#
# Rail definitions: SE rail = self_employed_flag TRUE; W-2 rail = everything else
# (FALSE = private-sector employees; NA = public-sector/other employees -- both
# have a payroll to deduct from; see 04_check_flags.R).
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/03-lindqvist-behavioral/code/03_reassessment_rail_band.R

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr)
})

out_tab <- "economist-panel/03-lindqvist-behavioral/tables"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
el  <- sim %>% filter(eligible_flag) %>%
  mutate(se = self_employed_flag %in% TRUE)

cost_full <- sum(el$WPFINWGT * el$match_per_worker_num)/1e9
cat(sprintf("Eligible (weighted): %.2fM | full-participation cost: $%.2fB | avg match: $%.0f\n",
            sum(el$WPFINWGT)/1e6, cost_full,
            sum(el$WPFINWGT * el$match_per_worker_num)/sum(el$WPFINWGT)))

# --- headline decomposition: observed-status vs auto-enrolled margin --------
obs    <- el %>% filter(!is.na(participating_dc_flag))
margin <- el %>% filter(is.na(participating_dc_flag))

cost_obs_fixed   <- sum(obs$WPFINWGT * obs$match_per_worker_num * obs$participating_dc_flag) / 1e9
cost_margin_full <- sum(margin$WPFINWGT * margin$match_per_worker_num) / 1e9
p_headline       <- weighted.mean(obs$participating_dc_flag, obs$WPFINWGT)

n_margin_M   <- sum(margin$WPFINWGT)/1e6
n_obs_M      <- sum(obs$WPFINWGT)/1e6
n_obs_part_M <- sum(obs$WPFINWGT * obs$participating_dc_flag)/1e6

cat(sprintf("Observed-status workers: %.2fM (%.2fM participating, p = %.4f) -> fixed $%.2fB\n",
            n_obs_M, n_obs_part_M, p_headline, cost_obs_fixed))
cat(sprintf("Auto-enrolled margin: %.2fM, full-participation $%.2fB\n", n_margin_M, cost_margin_full))
cat(sprintf("Closed form (headline construction): Cost(p) = $%.2fB + p x $%.2fB; marginal cost per take-up pt = $%.0fM\n",
            cost_obs_fixed, cost_margin_full, cost_margin_full*10))
cat(sprintf("Check headline at p = %.4f: $%.2fB (repo: $14.15B)\n",
            p_headline, cost_obs_fixed + p_headline * cost_margin_full))

# --- split the auto-enrolled margin by rail ----------------------------------
m_se <- margin %>% filter(se);  m_w2 <- margin %>% filter(!se)
c_se <- sum(m_se$WPFINWGT * m_se$match_per_worker_num)/1e9
c_w2 <- sum(m_w2$WPFINWGT * m_w2$match_per_worker_num)/1e9
n_se <- sum(m_se$WPFINWGT)/1e6
n_w2 <- sum(m_w2$WPFINWGT)/1e6
n_se_elig <- sum(el$WPFINWGT[el$se])/1e6

cat(sprintf("\nMargin split -- W-2 (incl. public sector): %.2fM ($%.2fB full) | self-employed: %.2fM ($%.2fB full)\n",
            n_w2, c_w2, n_se, c_se))
cat(sprintf("Self-employed eligibles total: %.2fM\n", n_se_elig))

# --- rail-specific scenarios, HEADLINE construction (observed savers keep behavior)
rail_cost <- function(p_w2, p_se) cost_obs_fixed + p_w2 * c_w2 + p_se * c_se
rail_part <- function(p_w2, p_se) n_obs_part_M + p_w2 * n_w2 + p_se * n_se

scenarios <- tribble(
  ~scenario,                                              ~p_w2, ~p_se,
  "Recommended central: W-2 80% / SE 20%",                 0.80,  0.20,
  "Upper: Madrian-Shea 86% / SE rails optimistic 30%",     0.86,  0.30,
  "Auto-IRA stay-in: W-2 64% / SE Duflo 14%",              0.64,  0.14,
  "Lower: OregonSaves-effective 34.3% / SE 5.7%",          0.343, 0.057,
  "Recommended W-2 80% / SE Duflo floor 14%",              0.80,  0.14
) %>%
  mutate(cost_B = round(rail_cost(p_w2, p_se), 2),
         participants_M = round(rail_part(p_w2, p_se), 2),
         implied_overall_takeup = round(participants_M / (sum(el$WPFINWGT)/1e6), 3))

write.csv(scenarios, file.path(out_tab, "reassessment_rail_scenarios.csv"), row.names = FALSE)
print(as.data.frame(scenarios))

# --- UNIFORM construction (the brief's 80% rung = 0.80 x full ceiling) -------
c_se_all <- sum(el$WPFINWGT[el$se]  * el$match_per_worker_num[el$se])/1e9
c_w2_all <- cost_full - c_se_all
cat(sprintf("\nUniform construction: all-eligible W-2 full $%.2fB | SE full $%.2fB\n", c_w2_all, c_se_all))
cat(sprintf("Brief central (uniform 80%% on everyone): $%.2fB (repo: $19.09B)\n", 0.80*cost_full))
cat(sprintf("Uniform-by-rail 80/20: $%.2fB | gap vs brief central: $%.2fB\n",
            0.80*c_w2_all + 0.20*c_se_all, 0.80*cost_full - (0.80*c_w2_all + 0.20*c_se_all)))

# --- Tier 2.3: six-month match-forfeiture bound ------------------------------
hl <- rail_cost(0.80, 0.20)
for (w in c(0.03, 0.05, 0.10)) {
  cat(sprintf("6-mo withdrawal propensity %.0f%%: rail-specific central $%.2fB -> $%.2fB (saves $%.2fB)\n",
              w*100, hl, hl*(1-w), hl*w))
}

# --- Tier 2.2: persistence factor applied to the auto-enrolled margin --------
for (f in c(0.59, 0.75, 0.85)) {
  cat(sprintf("Persistence factor %.2f on margin (from W-2 80%%/SE 20%%): $%.2fB\n",
              f, cost_obs_fixed + f*(0.80*c_w2 + 0.20*c_se)))
}
