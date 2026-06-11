# ============================================================================
# 01_admin_load_map.R
# Panelist 06 (Brandt, retirement institutions): administrative load map and
# small-dollar account economics for the universal-account / Saver's Match
# hybrid proposal.
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/06-brandt-retirement-institutions/code/01_admin_load_map.R
#
# Inputs:  data/processed/universal_sm_hybrid/simulation_results.parquet
# Outputs: economist-panel/06-brandt-retirement-institutions/tables/admin_load_map.csv
#          economist-panel/06-brandt-retirement-institutions/tables/small_dollar_economics.csv
#          economist-panel/06-brandt-retirement-institutions/figures/fig1_admin_load_map.png
#          economist-panel/06-brandt-retirement-institutions/figures/fig2_small_dollar_economics.png
#
# Weights: WPFINWGT (SIPP final person weights); /1e6 = millions of workers.
# ============================================================================

suppressMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

out_tab <- "economist-panel/06-brandt-retirement-institutions/tables"
out_fig <- "economist-panel/06-brandt-retirement-institutions/figures"

d <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

# Self-employed flag carries NAs (unknown class of worker, 17.2M weighted).
# For the rail decomposition we treat NA as "not identified as self-employed"
# (i.e., presumed W-2 / payroll-reachable) and report the NA mass separately.
d <- d %>%
  mutate(
    se = !is.na(self_employed_flag) & self_employed_flag,
    se_na = is.na(self_employed_flag)
  )

wsum <- function(df) sum(df$WPFINWGT) / 1e6

# ---------------------------------------------------------------------------
# 1. Administrative load map: who has to handle whom
# ---------------------------------------------------------------------------
seg <- list(
  list("Federal universal account - W-2 workers (payroll rail exists)",
       d %>% filter(route_chr == "universal_account", !se)),
  list("Federal universal account - self-employed (NO payroll rail)",
       d %>% filter(route_chr == "universal_account", se)),
  list("Employer plans (must accept federal match deposits)",
       d %>% filter(route_chr == "employer_plan"))
)

load_map <- bind_rows(lapply(seg, function(s) {
  df <- s[[2]]
  tibble(
    segment            = s[[1]],
    total_workers_m    = wsum(df),
    match_eligible_m   = wsum(df %>% filter(eligible_flag)),
    not_eligible_m     = wsum(df %>% filter(!eligible_flag)),
    mean_magi_eligible = weighted.mean(df$magi_num[df$eligible_flag],
                                       df$WPFINWGT[df$eligible_flag]),
    median_default_contrib = {
      x <- df %>% arrange(default_contrib_num)
      cw <- cumsum(x$WPFINWGT) / sum(x$WPFINWGT)
      x$default_contrib_num[which(cw >= 0.5)[1]]
    }
  )
}))

# Memo rows
memo <- tibble(
  segment = c("MEMO: universal-account route, class of worker unknown (NA flag, counted above as W-2)",
              "MEMO: full auto-enrollment universe (all rows)",
              "MEMO: hybrid match-eligible workers (46.07M target)"),
  total_workers_m = c(wsum(d %>% filter(route_chr == "universal_account", se_na)),
                      wsum(d),
                      wsum(d %>% filter(eligible_flag))),
  match_eligible_m = c(wsum(d %>% filter(route_chr == "universal_account", se_na, eligible_flag)),
                       wsum(d %>% filter(eligible_flag)),
                       wsum(d %>% filter(eligible_flag))),
  not_eligible_m = NA, mean_magi_eligible = NA, median_default_contrib = NA
)

load_map_out <- bind_rows(load_map, memo) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))

write.csv(load_map_out, file.path(out_tab, "admin_load_map.csv"), row.names = FALSE)
cat("Wrote admin_load_map.csv\n")
print(as.data.frame(load_map_out))

# ---------------------------------------------------------------------------
# 2. Small-dollar account economics (universal-account route only)
# ---------------------------------------------------------------------------
ua <- d %>% filter(route_chr == "universal_account")

sh <- function(cond) sum(ua$WPFINWGT[cond]) / sum(ua$WPFINWGT)

# External cost benchmarks (see assessment.md and sources/sources.md):
#  - CRR (Aubry, 2024): third-party administrator per-account recordkeeping
#    cost ~$20/yr; modeled program fees $24/yr flat + asset-based.
#  - TSP (FRTIB, 2024): 2023 gross administrative expenses $502M, net $429M,
#    net admin expense ratio 4.8 bp on ~$780B average net assets; ~7.0M
#    participants (GAO-24-106319) -> ~$72 gross / ~$61 net per participant-year.
tpa_cost_per_acct  <- 20      # CRR per-account TPA recordkeeping cost, $/yr
tsp_gross_per_part <- 502e6 / 7.0e6
tsp_net_per_part   <- 429e6 / 7.0e6
eo_fee_cap         <- 0.0015  # EO TrumpIRA.gov net expense ratio cap (0.15%)

# First-year fee revenue at the EO fee cap, approximating the average balance
# during year 1 as half the annual contribution flow.
ua <- ua %>% mutate(fee_rev_y1 = (default_contrib_num / 2) * eo_fee_cap)

breakeven_balance <- tpa_cost_per_acct / eo_fee_cap  # balance where 0.15% covers $20

small_dollar <- tibble(
  metric = c(
    "Universal-account defaulters, total (M)",
    "Share with default contribution < $250/yr",
    "Share with default contribution < $500/yr",
    "Share with default contribution < $1,000/yr",
    "Weighted median default contribution ($/yr)",
    "Weighted median first-year fee revenue at 0.15% cap ($)",
    "Share with first-year fee revenue < $20 TPA cost (at 0.15% cap)",
    "Account balance needed for 0.15% fee to cover $20/acct cost ($)",
    "Benchmark: CRR per-account TPA cost ($/yr)",
    "Benchmark: TSP gross admin cost per participant 2023 ($/yr)",
    "Benchmark: TSP net admin cost per participant 2023 ($/yr)",
    "Benchmark: CalSavers avg funded-account balance 3/31/2026 ($)",
    "Benchmark: OregonSaves avg account balance Dec 2025 ($)",
    "Benchmark: Illinois Secure Choice avg funded balance Dec 2025 ($)"
  ),
  value = c(
    round(wsum(ua), 2),
    round(sh(ua$default_contrib_num < 250), 4),
    round(sh(ua$default_contrib_num < 500), 4),
    round(sh(ua$default_contrib_num < 1000), 4),
    round({x <- ua %>% arrange(default_contrib_num)
           cw <- cumsum(x$WPFINWGT)/sum(x$WPFINWGT)
           x$default_contrib_num[which(cw >= .5)[1]]}, 0),
    round({x <- ua %>% arrange(fee_rev_y1)
           cw <- cumsum(x$WPFINWGT)/sum(x$WPFINWGT)
           x$fee_rev_y1[which(cw >= .5)[1]]}, 2),
    round(sh(ua$fee_rev_y1 < tpa_cost_per_acct), 4),
    round(breakeven_balance, 0),
    tpa_cost_per_acct,
    round(tsp_gross_per_part, 0),
    round(tsp_net_per_part, 0),
    round(1.6e9 / 629000, 0),   # CalSavers: $1.6B+ / 629k+ funded accounts
    3000,                        # OPB (Dec 2025): avg OregonSaves balance ~$3,000
    1861                         # ASPPA (Jan 2026): IL avg funded balance $1,861.08
  )
)

write.csv(small_dollar, file.path(out_tab, "small_dollar_economics.csv"), row.names = FALSE)
cat("\nWrote small_dollar_economics.csv\n")
print(as.data.frame(small_dollar))

# ---------------------------------------------------------------------------
# Figure 1: administrative load map
# ---------------------------------------------------------------------------
fig1_dat <- load_map %>%
  select(segment, match_eligible_m, not_eligible_m) %>%
  pivot_longer(-segment, names_to = "elig", values_to = "millions") %>%
  mutate(
    segment = factor(segment, levels = rev(c(
      "Employer plans (must accept federal match deposits)",
      "Federal universal account - W-2 workers (payroll rail exists)",
      "Federal universal account - self-employed (NO payroll rail)"
    ))),
    elig = ifelse(elig == "match_eligible_m",
                  "Match-eligible (needs MAGI reconciliation)",
                  "Not match-eligible (account only)")
  )

p1 <- ggplot(fig1_dat, aes(x = millions, y = segment, fill = elig)) +
  geom_col(width = 0.62) +
  geom_text(aes(label = sprintf("%.1fM", millions)),
            position = position_stack(vjust = 0.5),
            color = "white", size = 3.4, fontface = "bold") +
  scale_fill_manual(values = c("Match-eligible (needs MAGI reconciliation)" = "#164C87",
                               "Not match-eligible (account only)" = "#F97D1E")) +
  scale_x_continuous(labels = label_number(suffix = "M"), expand = expansion(mult = c(0, .05))) +
  scale_y_discrete(labels = function(x) gsub(" - ", "\n", x)) +
  labs(
    title = "Figure 1. Every institution inherits a population it has never served",
    subtitle = "Auto-enrollment universe (145.3M workers) by account destination and federal match eligibility, TY2027",
    x = "Workers (millions, WPFINWGT-weighted)", y = NULL,
    fill = NULL,
    caption = "Source: Author's calculations from EIG universal-hybrid simulation (SIPP 2024 projected to TY2027), simulation_results.parquet, 2026.\nSelf-employed = SIPP EJB1_JBORSE class; workers with unknown class (17.2M) counted in the W-2 bar."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "top",
    plot.title = element_text(face = "bold", size = 13),
    plot.caption = element_text(size = 7.5, color = "grey30", hjust = 0),
    plot.title.position = "plot"
  )

ggsave(file.path(out_fig, "fig1_admin_load_map.png"), p1,
       width = 9.5, height = 5.4, dpi = 200)
cat("\nWrote fig1_admin_load_map.png\n")

# ---------------------------------------------------------------------------
# Figure 2: small-dollar account economics (weighted CDF of contributions)
# ---------------------------------------------------------------------------
cdf_dat <- ua %>%
  arrange(default_contrib_num) %>%
  mutate(cumshare = cumsum(WPFINWGT) / sum(WPFINWGT)) %>%
  filter(default_contrib_num <= 8000)

share_lt_500 <- sh(ua$default_contrib_num < 500)

p2 <- ggplot(cdf_dat, aes(x = default_contrib_num, y = cumshare)) +
  geom_line(linewidth = 1.1, color = "#164C87") +
  geom_vline(xintercept = 500, linetype = "dashed", color = "#D34917") +
  annotate("text", x = 560, y = 0.06, hjust = 0, size = 3.4, color = "#D34917",
           label = sprintf("$500/yr: %.0f%% of defaulters below", 100 * share_lt_500)) +
  geom_vline(xintercept = 2000, linetype = "dotted", color = "grey40") +
  annotate("text", x = 2060, y = 0.92, hjust = 0, size = 3.2, color = "grey30",
           label = "Current-law $2,000\ncontribution base") +
  annotate("text", x = 4300, y = 0.35, hjust = 0, size = 3.3, color = "grey20",
           label = paste0("Per-account economics:\n",
                          "0.15% fee on a $500 first-year flow earns < $1\n",
                          "vs ~$20/yr TPA recordkeeping cost (CRR 2024);\n",
                          "fee covers cost only above a $13,333 balance.\n",
                          "CalSavers average balance after 7 years: ~$2,540")) +
  scale_x_continuous(labels = label_dollar(), breaks = seq(0, 8000, 1000)) +
  scale_y_continuous(labels = label_percent(), breaks = seq(0, 1, .2)) +
  labs(
    title = "Figure 2. The universal account is a small-dollar account problem at federal scale",
    subtitle = "Weighted CDF of the 3 percent default annual contribution, 57.3M universal-account defaulters, TY2027",
    x = "Default annual contribution (3 percent of earnings, TY2027 dollars)",
    y = "Cumulative share of universal-account defaulters",
    caption = "Source: Author's calculations from EIG universal-hybrid simulation (SIPP 2024 projected to TY2027), 2026; CRR (Aubry), 2024; CalSavers, 2026.\nX-axis truncated at $8,000; 95.6 percent of defaulters shown."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    plot.title = element_text(face = "bold", size = 13),
    plot.caption = element_text(size = 7.5, color = "grey30", hjust = 0),
    plot.title.position = "plot"
  )

ggsave(file.path(out_fig, "fig2_small_dollar_economics.png"), p2,
       width = 9.5, height = 5.8, dpi = 200)
cat("Wrote fig2_small_dollar_economics.png\n")

# Console check of x-axis truncation share
cat("Share of UA defaulters with contrib <= 8000:", sh(ua$default_contrib_num <= 8000), "\n")
cat("Done.\n")
