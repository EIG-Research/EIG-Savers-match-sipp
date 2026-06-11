# =====================================================================
# 03_federal_concentration.R — How big a federal asset manager are we
#                              building? (Calloway, panelist 05)
#
# Computes the share of workers defaulted into the FEDERAL universal
# account (route_chr) and the implied annual contribution flow routed
# through a Treasury-administered vehicle, then compares that flow to
# actual Thrift Savings Plan contributions (TSP financial statements,
# CY2023: participant $31.1B + employer $13.6B = $44.7B total).
#
# Run from the repository root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/05-calloway-libertarian/code/03_federal_concentration.R
# =====================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

out_tab <- "economist-panel/05-calloway-libertarian/tables"
out_fig <- "economist-panel/05-calloway-libertarian/figures"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

# Validate that the default contribution is 3 percent of earnings
stopifnot(max(abs(sim$default_contrib_num - 0.03 * sim$earnings_num)) < 1e-6)

TAKEUP <- 0.5978   # headline SIPP-observed conditional participation rate

# ---------------------------------------------------------------
# 1. Routing: who is defaulted into the federal account?
# ---------------------------------------------------------------
routing <- sim %>%
  group_by(route_chr) %>%
  summarise(
    universe_M          = sum(WPFINWGT) / 1e6,
    eligible_M          = sum(WPFINWGT[eligible_flag]) / 1e6,
    contrib_flow_full_B = sum(default_contrib_num * WPFINWGT) / 1e9,
    match_flow_full_B   = sum(match_per_worker_num * WPFINWGT * eligible_flag) / 1e9,
    .groups = "drop"
  ) %>%
  mutate(
    universe_share_pct  = 100 * universe_M / sum(universe_M),
    eligible_share_pct  = 100 * eligible_M / sum(eligible_M),
    contrib_flow_headline_B = contrib_flow_full_B * TAKEUP,
    match_flow_headline_B   = match_flow_full_B * TAKEUP
  )

print(as.data.frame(routing), digits = 4)

fed <- routing %>% filter(route_chr == "universal_account")
cat(sprintf("\nFederal universal account: %.1fM of %.1fM universe workers (%.1f%%)\n",
            fed$universe_M, sum(routing$universe_M), fed$universe_share_pct))
cat(sprintf("  Eligible workers routed federal: %.2fM (%.1f%% of the 46.07M eligible)\n",
            fed$eligible_M, fed$eligible_share_pct))
cat(sprintf("  Default-contribution flow, full participation:  $%.1fB/yr\n",
            fed$contrib_flow_full_B))
cat(sprintf("  Default-contribution flow, headline take-up:    $%.1fB/yr\n",
            fed$contrib_flow_headline_B))
cat(sprintf("  Federal match deposits routed federal (full):    $%.1fB/yr\n",
            fed$match_flow_full_B))
cat(sprintf("  Total federal-account inflow, full participation: $%.1fB/yr\n",
            fed$contrib_flow_full_B + fed$match_flow_full_B))
cat(sprintf("  Total federal-account inflow, headline take-up:   $%.1fB/yr\n",
            fed$contrib_flow_headline_B + fed$match_flow_headline_B))

# ---------------------------------------------------------------
# 2. Comparison to the actual TSP
#    TSP Financial Statements (FRTIB, audited), CY2023:
#      participant contributions $31.150B, employer $13.564B,
#      total $44.714B; ~7.0M participants; net assets $856.9B (Dec 2023).
#    (sources/tsp-fs-dec2023.pdf, Statements of Changes in Net Assets)
# ---------------------------------------------------------------
TSP_PARTICIPANT_B <- 31.150
TSP_EMPLOYER_B    <- 13.564
TSP_TOTAL_B       <- 44.714
TSP_PARTICIPANTS_M <- 7.0

comparison <- tibble(
  vehicle = c("TSP (actual, CY2023)",
              "Federal universal account (headline take-up, 59.8%)",
              "Federal universal account (full participation)"),
  participants_M = c(TSP_PARTICIPANTS_M,
                     fed$universe_M * TAKEUP,
                     fed$universe_M),
  worker_contrib_B = c(TSP_PARTICIPANT_B,
                       fed$contrib_flow_headline_B,
                       fed$contrib_flow_full_B),
  govt_or_employer_B = c(TSP_EMPLOYER_B,
                         fed$match_flow_headline_B,
                         fed$match_flow_full_B),
  total_inflow_B = c(TSP_TOTAL_B,
                     fed$contrib_flow_headline_B + fed$match_flow_headline_B,
                     fed$contrib_flow_full_B + fed$match_flow_full_B)
) %>%
  mutate(pct_of_tsp_inflow = 100 * total_inflow_B / TSP_TOTAL_B)

write.csv(bind_rows(routing %>% mutate(vehicle = paste0("route: ", route_chr)) %>%
                      select(vehicle, everything(), -route_chr) %>%
                      mutate(across(where(is.numeric), ~round(.x, 2))),
                    ), file.path(out_tab, "federal_routing.csv"), row.names = FALSE)
write.csv(comparison, file.path(out_tab, "federal_flow_vs_tsp.csv"), row.names = FALSE)
print(as.data.frame(comparison), digits = 4)

# ---------------------------------------------------------------
# 3. Figure 3 — stacked inflow comparison
# ---------------------------------------------------------------
plot_df <- comparison %>%
  select(vehicle, Worker = worker_contrib_B, `Government / employer` = govt_or_employer_B) %>%
  pivot_longer(-vehicle, names_to = "source", values_to = "flow_B") %>%
  mutate(vehicle = factor(vehicle, levels = rev(comparison$vehicle)))

totals <- comparison %>% mutate(vehicle = factor(vehicle, levels = rev(comparison$vehicle)))

fig3 <- ggplot(plot_df, aes(x = flow_B, y = vehicle, fill = source)) +
  geom_col(width = 0.6) +
  geom_text(data = totals,
            aes(x = total_inflow_B, y = vehicle,
                label = sprintf("$%.1fB  (%.0f%% of TSP)", total_inflow_B, pct_of_tsp_inflow)),
            inherit.aes = FALSE, hjust = -0.05, size = 3.5) +
  scale_fill_manual(values = c("Worker" = "#2166ac", "Government / employer" = "#b2182b")) +
  scale_x_continuous(labels = label_dollar(suffix = "B"), limits = c(0, 195),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(
    title = "A second TSP, twice over: inflows to the proposed\nfederal universal account",
    subtitle = paste0("Annual contribution + match flow routed through the Treasury-administered universal\n",
                      "account (57.3M default-routed workers) vs. actual TSP contributions (CY2023, audited)."),
    x = "Annual contribution inflow", y = NULL, fill = "Source of dollars",
    caption = paste0("Source: Author's calculations from simulation_results.parquet (EIG repo; route_chr = universal_account; 3% default contribution);\n",
                     "TSP: Thrift Savings Fund Financial Statements, Dec. 31, 2023 (FRTIB) — participant $31.1B, employer $13.6B, total $44.7B.")
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        plot.caption = element_text(size = 8, color = "grey40", hjust = 0),
        panel.grid.major.y = element_blank(),
        legend.position = "bottom")

ggsave(file.path(out_fig, "fig3_federal_flow_vs_tsp.png"), fig3,
       width = 10, height = 5.5, dpi = 200)
cat("Wrote", file.path(out_fig, "fig3_federal_flow_vs_tsp.png"), "\n")
