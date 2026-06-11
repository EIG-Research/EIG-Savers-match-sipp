# =====================================================================
# 02_ratchet_menu.R — Fiscal exposure beyond the proposal's own ceiling
#                     (Calloway, panelist 05)
#
# Re-prices one-line parameter changes from the row-level simulation
# frame: match = min(rate(MAGI) x 3% x earnings, cap). Each scenario is
# a single reconciliation-bill edit to a parameter the proposal itself
# has already moved once during drafting (the first draft used a 300%
# floor with pivots at the full Single median).
#
# Run from the repository root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/05-calloway-libertarian/code/02_ratchet_menu.R
# =====================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

out_tab <- "economist-panel/05-calloway-libertarian/tables"
out_fig <- "economist-panel/05-calloway-libertarian/figures"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")

pivot_base   <- setNames(piv[["pivot_num"]], piv[["filing_group_chr"]])
median_single <- piv[["data_median_magi_num"]][piv[["filing_group_chr"]] == "single_mfs"]
sm_ratio      <- setNames(piv[["sm_ratio_num"]], piv[["filing_group_chr"]])  # 1 / 2 / 1.5

# First-draft pivots: anchored at the FULL Single weighted-median MAGI
# (revision note in the proposal), scaled by the statutory ratios.
pivot_draft1 <- sm_ratio * median_single

rate_pp <- function(magi, fg, pivots, floor_pp) {
  p <- pivots[fg]
  pmin(floor_pp, pmax(0, floor_pp - ((floor_pp - 50) / p) * magi))
}

# Take-up: headline scenario is 59.78% (scenario_results.parquet). Applied
# uniformly here as an approximation to re-scale full-participation cost.
TAKEUP <- 0.5978

price <- function(label, change, floor_pp = 200, cap = 1000,
                  contrib_rate = 0.03, pivots = pivot_base) {
  r    <- rate_pp(sim$magi_num, sim$filing_group_chr, pivots, floor_pp) / 100
  elig <- r > 0
  m    <- pmin(r * contrib_rate * sim$earnings_num, cap)
  full <- sum(m[elig] * sim$WPFINWGT[elig]) / 1e9
  tibble(
    scenario        = label,
    one_line_change = change,
    floor_pct       = floor_pp,
    cap_usd         = cap,
    default_rate    = contrib_rate,
    pivot_single    = unname(pivots["single_mfs"]),
    eligible_M      = sum(sim$WPFINWGT[elig]) / 1e6,
    eligible_share_pct = 100 * sum(sim$WPFINWGT[elig]) / sum(sim$WPFINWGT),
    full_cost_B     = full,
    headline_cost_B = full * TAKEUP,
    avg_match_usd   = sum(m[elig] * sim$WPFINWGT[elig]) / sum(sim$WPFINWGT[elig])
  )
}

menu <- bind_rows(
  price("1. As proposed",                 "—"),
  price("2. Cap to $1,500",               "cap: 1000 -> 1500",  cap = 1500),
  price("3. Cap to $2,000",               "cap: 1000 -> 2000",  cap = 2000),
  price("4. Default contribution to 5%",  "default: 3% -> 5%",  contrib_rate = 0.05),
  price("5. Floor to 300% (pivots held)", "floor: 200% -> 300%", floor_pp = 300),
  price("6. First-draft design (300% floor,\npivots at full Single median)",
        "floor 300% + pivot anchor: 0.6x median -> 1.0x median",
        floor_pp = 300, pivots = pivot_draft1),
  price("7. First-draft design + $2,000 cap",
        "scenario 6 + cap: 1000 -> 2000",
        floor_pp = 300, pivots = pivot_draft1, cap = 2000)
) %>%
  mutate(multiple_of_baseline = full_cost_B / full_cost_B[1])

write.csv(menu, file.path(out_tab, "ratchet_menu.csv"), row.names = FALSE)
print(as.data.frame(menu %>% select(scenario, eligible_M, eligible_share_pct,
                                    full_cost_B, headline_cost_B,
                                    avg_match_usd, multiple_of_baseline)),
      digits = 4)

# ---------------------------------------------------------------
# Figure 2 — the ratchet menu
# ---------------------------------------------------------------
plot_df <- menu %>%
  mutate(scenario_short = c("As proposed\n($1,000 cap, 200% floor)",
                            "Cap to $1,500", "Cap to $2,000",
                            "Default contribution\n3% -> 5%",
                            "Floor to 300%\n(pivots held)",
                            "First-draft design\n(300% floor, median pivots)",
                            "First-draft design\n+ $2,000 cap"),
         scenario_short = factor(scenario_short, levels = rev(scenario_short)))

fig2 <- ggplot(plot_df, aes(x = full_cost_B, y = scenario_short)) +
  geom_col(fill = ifelse(plot_df$scenario == "1. As proposed", "#2166ac", "#b2182b"),
           width = 0.65) +
  geom_text(aes(label = sprintf("$%.1fB  (%.1fx)", full_cost_B, multiple_of_baseline)),
            hjust = -0.05, size = 3.4) +
  scale_x_continuous(labels = label_dollar(suffix = "B"), limits = c(0, 105),
                     expand = expansion(mult = c(0, 0.02))) +
  labs(
    title = "The ratchet menu: every parameter is one reconciliation bill away from doubling",
    subtitle = paste0("Full-participation annual federal cost of one-line parameter changes, re-priced row-by-row\n",
                      "from the 145.3M-worker SIPP universe. The proposal's own first draft is scenario 6."),
    x = "Full-participation annual federal cost (TY2027 dollars)", y = NULL,
    caption = paste0("Source: Author's calculations from simulation_results.parquet (EIG repo); match = min(rate(MAGI) x default x earnings, cap).\n",
                     "Baseline reproduces the proposal's $24.9B full-participation ceiling; headline take-up (59.8%) scales each bar proportionally.")
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 12.5),
        plot.caption = element_text(size = 8, color = "grey40", hjust = 0),
        panel.grid.major.y = element_blank())

ggsave(file.path(out_fig, "fig2_ratchet_menu.png"), fig2,
       width = 10, height = 6, dpi = 200)
cat("Wrote", file.path(out_fig, "fig2_ratchet_menu.png"), "\n")
