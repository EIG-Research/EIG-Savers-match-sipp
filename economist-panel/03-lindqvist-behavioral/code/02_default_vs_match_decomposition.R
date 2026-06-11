# 02_default_vs_match_decomposition.R
# Panelist 03 (Lindqvist, behavioral). Decompose the $14.9B headline cost into
# (a) the cost of ACCESS (auto-enrollment bringing in new savers, priced at a flat
#     50 percent current-law-style match) and
# (b) the cost of GENEROSITY (raising the match rate above 50 percent via the
#     200-percent-floor MAGI-linear schedule).
#
# Counterfactual flat-50 match per worker: min(0.5 * default_contrib_num, $1,000),
# same eligibility band, same $1,000 cap, same 3 percent default contribution.
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/03-lindqvist-behavioral/code/02_default_vs_match_decomposition.R

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

out_fig <- "economist-panel/03-lindqvist-behavioral/figures"
out_tab <- "economist-panel/03-lindqvist-behavioral/tables"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
el  <- sim %>% filter(eligible_flag)

obs <- el %>% filter(!is.na(participating_dc_flag))
p_headline <- weighted.mean(obs$participating_dc_flag, obs$WPFINWGT)

el <- el %>%
  mutate(
    match_flat50 = pmin(0.5 * default_contrib_num, 1000),
    # headline participation probability per row:
    # observed flag where available, conditional rate on the auto-enrolled margin
    part_prob = coalesce(as.numeric(participating_dc_flag), p_headline),
    # indicator: observed participant (saves with or without the new policy)
    obs_part  = coalesce(as.numeric(participating_dc_flag), 0)
  )

# --- building blocks ($B) ----------------------------------------------------
A_flat50_existing <- sum(el$WPFINWGT * el$match_flat50 * el$obs_part) / 1e9
B_flat50_headline <- sum(el$WPFINWGT * el$match_flat50 * el$part_prob) / 1e9
C_hybrid_headline <- sum(el$WPFINWGT * el$match_per_worker_num * el$part_prob) / 1e9

cost_access     <- B_flat50_headline - A_flat50_existing   # new savers at flat 50%
cost_generosity <- C_hybrid_headline - B_flat50_headline   # rate above 50% for all participants

decomp <- tibble(
  component = c(
    "A. Flat 50% match to observed savers (no new behavior)",
    "B. Cost of ACCESS: auto-enrolled margin at flat 50%",
    "C. Cost of GENEROSITY: match rate above 50% (200%-floor schedule)",
    "Headline total"
  ),
  cost_B = c(A_flat50_existing, cost_access, cost_generosity, C_hybrid_headline),
  share_of_headline = c(A_flat50_existing, cost_access, cost_generosity, C_hybrid_headline) / C_hybrid_headline
)
print(as.data.frame(decomp), digits = 3)
write.csv(decomp %>% mutate(cost_B = round(cost_B, 2), share_of_headline = round(share_of_headline, 3)),
          file.path(out_tab, "decomposition_table.csv"), row.names = FALSE)

# generosity split by route (who gets the above-50 increment)
gen_route <- el %>%
  group_by(route_chr) %>%
  summarise(
    eligible_M    = sum(WPFINWGT) / 1e6,
    generosity_B  = sum(WPFINWGT * (match_per_worker_num - match_flat50) * part_prob) / 1e9,
    access_B      = sum(WPFINWGT * match_flat50 * (part_prob - obs_part)) / 1e9,
    mean_rate_pp  = weighted.mean(match_rate_pp_num, WPFINWGT),
    .groups = "drop"
  )
print(as.data.frame(gen_route), digits = 3)
write.csv(gen_route %>% mutate(across(where(is.numeric), ~round(.x, 2))),
          file.path(out_tab, "decomposition_by_route.csv"), row.names = FALSE)

# --- behavioral parameter table (for assessment section 3) -------------------
univ_m <- el %>% filter(is.na(participating_dc_flag))
behav <- tibble(
  statistic = c(
    "SIPP conditional DC participation among eligible workers with an existing DC account (the headline p)",
    "SIPP conditional DC participation among ALL workers with an existing DC account (whole universe)",
    "Auto-enrolled margin, weighted persons (M)",
    "  of which: self-employed (M)",
    "  of which: W-2 workers (M)",
    "Self-employed share of auto-enrolled margin",
    "Self-employed eligible workers, total (M)",
    "Full-participation cost of auto-enrolled margin ($B)",
    "  of which: self-employed ($B)"
  ),
  value = c(
    round(p_headline, 4),
    round(weighted.mean(sim$participating_dc_flag[sim$has_existing_dc_flag],
                        sim$WPFINWGT[sim$has_existing_dc_flag], na.rm = TRUE), 4),
    round(sum(univ_m$WPFINWGT)/1e6, 2),
    round(sum(univ_m$WPFINWGT[univ_m$self_employed_flag %in% TRUE])/1e6, 2),
    round(sum(univ_m$WPFINWGT[!(univ_m$self_employed_flag %in% TRUE)])/1e6, 2),
    round(sum(univ_m$WPFINWGT[univ_m$self_employed_flag %in% TRUE]) / sum(univ_m$WPFINWGT), 4),
    round(sum(el$WPFINWGT[el$self_employed_flag %in% TRUE])/1e6, 2),
    round(sum(univ_m$WPFINWGT * univ_m$match_per_worker_num)/1e9, 2),
    round(sum(univ_m$WPFINWGT[univ_m$self_employed_flag %in% TRUE] *
              univ_m$match_per_worker_num[univ_m$self_employed_flag %in% TRUE])/1e9, 2)
  )
)
print(as.data.frame(behav))
write.csv(behav, file.path(out_tab, "behavioral_parameters.csv"), row.names = FALSE)

# --- literature-consistent take-up scenarios (rail-specific p) ---------------
# Split the auto-enrolled margin into W-2 workers (payroll rail exists) and
# self-employed workers (no payroll rail), and price rail-specific take-up:
#   optimistic  : W-2 at 86% (Madrian-Shea 2001 AE), self-employed at 14% (Duflo et al. 2006)
#   pessimistic : W-2 at 34.3% (OregonSaves positive-balance, Chalmers et al. 2021),
#                 self-employed at 5.7% (Saver's Credit claiming, CRS 2025)
margin_se  <- univ_m %>% filter(self_employed_flag %in% TRUE)
margin_w2  <- univ_m %>% filter(!(self_employed_flag %in% TRUE))
cost_obs_fixed   <- sum(el$WPFINWGT * el$match_per_worker_num * el$obs_part) / 1e9
cost_margin_w2_B <- sum(margin_w2$WPFINWGT * margin_w2$match_per_worker_num) / 1e9
cost_margin_se_B <- sum(margin_se$WPFINWGT * margin_se$match_per_worker_num) / 1e9

scen_lit <- tibble(
  scenario = c("Repo headline (uniform p = 0.598 on margin)",
               "Literature-consistent optimistic (W-2 86%, self-employed 14%)",
               "Literature-consistent pessimistic (W-2 34.3%, self-employed 5.7%)"),
  p_w2 = c(p_headline, 0.86, 0.343),
  p_se = c(p_headline, 0.14, 0.057),
  cost_B = c(
    cost_obs_fixed + p_headline * (cost_margin_w2_B + cost_margin_se_B),
    cost_obs_fixed + 0.86  * cost_margin_w2_B + 0.14  * cost_margin_se_B,
    cost_obs_fixed + 0.343 * cost_margin_w2_B + 0.057 * cost_margin_se_B
  )
) %>%
  mutate(participants_M = c(
    sum(obs$WPFINWGT * obs$participating_dc_flag)/1e6 + p_headline * sum(univ_m$WPFINWGT)/1e6,
    sum(obs$WPFINWGT * obs$participating_dc_flag)/1e6 + 0.86 * sum(margin_w2$WPFINWGT)/1e6 + 0.14 * sum(margin_se$WPFINWGT)/1e6,
    sum(obs$WPFINWGT * obs$participating_dc_flag)/1e6 + 0.343 * sum(margin_w2$WPFINWGT)/1e6 + 0.057 * sum(margin_se$WPFINWGT)/1e6
  ))
cat(sprintf("\nW-2 margin full cost: $%.2fB | self-employed margin full cost: $%.2fB\n",
            cost_margin_w2_B, cost_margin_se_B))
print(as.data.frame(scen_lit), digits = 4)
write.csv(scen_lit %>% mutate(across(where(is.numeric), ~round(.x, 3))),
          file.path(out_tab, "literature_scenarios.csv"), row.names = FALSE)

# self-employed-only sensitivity: replace 0.598 with 0.14 for self-employed margin
delta_se <- (p_headline - 0.14) * cost_margin_se_B
cat(sprintf("Self-employed-only correction (0.598 -> 0.14): -$%.2fB (%.1f%% of headline)\n",
            delta_se, 100 * delta_se / C_hybrid_headline))

# --- figure 2: access vs generosity -----------------------------------------
bars <- tibble(
  component = factor(
    c("Flat 50% match,\nobserved savers only\n(no behavioral change)",
      "+ Cost of access\n(auto-enrolled margin\nat flat 50%)",
      "+ Cost of generosity\n(match rate above 50%,\n200%-floor schedule)"),
    levels = c("Flat 50% match,\nobserved savers only\n(no behavioral change)",
               "+ Cost of access\n(auto-enrolled margin\nat flat 50%)",
               "+ Cost of generosity\n(match rate above 50%,\n200%-floor schedule)")
  ),
  cost = c(A_flat50_existing, cost_access, cost_generosity)
) %>%
  mutate(
    end   = cumsum(cost),
    start = end - cost,
    mid   = (start + end) / 2,
    lab   = sprintf("$%.1fB\n(%.0f%%)", cost, 100 * cost / C_hybrid_headline)
  )

fig2 <- ggplot(bars, aes(component)) +
  geom_rect(aes(xmin = as.numeric(component) - 0.32, xmax = as.numeric(component) + 0.32,
                ymin = start, ymax = end, fill = component)) +
  geom_segment(data = bars[-nrow(bars), ],
               aes(x = as.numeric(component) + 0.32, xend = as.numeric(component) + 0.68,
                   y = end, yend = end), linetype = "33", color = "grey45") +
  geom_text(aes(y = mid, label = lab), size = 3.4, fontface = "bold", color = "white") +
  geom_hline(yintercept = C_hybrid_headline, linetype = "22", color = "#d6452c") +
  annotate("text", x = 0.62, y = C_hybrid_headline + 0.55,
           label = sprintf("Headline cost: $%.1fB", C_hybrid_headline),
           hjust = 0, size = 3.4, fontface = "bold", color = "#d6452c") +
  scale_y_continuous(labels = dollar_format(suffix = "B"), limits = c(0, 16.5),
                     expand = c(0, 0)) +
  scale_fill_manual(values = c("#8a8a8a", "#2b6a99", "#e0a426"), guide = "none") +
  labs(
    title = "Figure 2. What the $14.9 billion buys: access versus generosity",
    subtitle = paste0("Waterfall decomposition of the headline cost at SIPP-observed conditional participation (p = ",
                      sprintf("%.3f", p_headline), ")"),
    x = NULL, y = "Annual federal match cost",
    caption = paste0("Source: Author's computation from data/processed/universal_sm_hybrid/simulation_results.parquet.\n",
                     "Counterfactual flat-50 match per worker = min(0.5 x 3% default contribution, $1,000), same eligibility band and cap as the proposal.")
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(size = 7, hjust = 0, color = "grey35")
  )

ggsave(file.path(out_fig, "fig2_access_vs_generosity.png"), fig2,
       width = 9, height = 6, dpi = 200)
cat("Saved fig2.\n")
