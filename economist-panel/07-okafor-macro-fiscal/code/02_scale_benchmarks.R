# ------------------------------------------------------------------
# 02_scale_benchmarks.R  --  Dr. Sam Okafor (macro-fiscal panelist)
# Benchmarks the proposal's annual cost against the existing
# retirement tax-expenditure stack, the enacted Saver's Match, the
# EITC, and the April 2026 executive order; computes the marginal
# distributional shift in total federal retirement subsidies.
#
# Run from the repository root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/07-okafor-macro-fiscal/code/02_scale_benchmarks.R
#
# Benchmark sources (FY2027, individuals, $ billions):
#  - JCT, Estimates of Federal Tax Expenditures for Fiscal Years
#    2024-2028 (JCX-48-24), December 11, 2024 (downloaded to
#    sources/jct-tax-expenditures-jcx-48-24.pdf):
#      Defined contribution plans            323.1
#      Defined benefit plans                 172.6
#      Keogh plans (self-employed)            20.4
#      Traditional IRAs                       24.7
#      Roth IRAs                              25.7
#      EITC (revenue 7.9 + outlay 58.0)       65.9
#  - Enacted Saver's Match: JCX-21-22 sec. 103 line, FY2028 = $2.097B
#    (first fiscal year with outlays).
#  - EO / TrumpIRA.gov: ~$0 programmatic cost (information portal,
#    no accounts, no match parameter change; policy-context.md).
#  - Proposal rungs: scenario_results.parquet (TY2027 dollars).
#
# Distribution shift:
#  - CBO (via PGPF, "Tax Breaks on Retirement Savings: Who Benefits
#    and How Much Do They Cost?", 2025): top quintile received 63
#    percent of $201.6B of retirement tax expenditures in 2019
#    ($126.7B); bottom quintile 1 percent ($1.4B).
#  - Proposal incidence: pooled-universe decile shares recomputed
#    from simulation_results.parquet (full-participation weights,
#    same incidence applies to the headline because take-up is
#    applied uniformly within branch).
# ------------------------------------------------------------------

suppressMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

out_dir_tab <- "economist-panel/07-okafor-macro-fiscal/tables"
out_dir_fig <- "economist-panel/07-okafor-macro-fiscal/figures"

eig_teal  <- "#024140"; eig_blue <- "#194F8B"; eig_green <- "#19644D"
eig_gold  <- "#E1AD28"; eig_cyan <- "#176F96"; eig_grey  <- "grey60"

theme_eig <- function() {
  theme_minimal(base_size = 12) +
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.x = element_line(color = "grey85", linewidth = 0.3),
      plot.title         = element_text(face = "bold", size = 14),
      plot.subtitle      = element_text(size = 10.5, color = "grey25"),
      plot.caption       = element_text(size = 8.5, color = "grey35", hjust = 0),
      legend.position    = "none",
      axis.title         = element_text(size = 10.5)
    )
}

# ---- 1. Proposal rungs ----------------------------------------------
scen <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
headline_bn <- scen$annual_cost_M_num[scen$scenario_name_chr == "headline_sipp_observed_conditional"] / 1000
ceiling_bn  <- scen$annual_cost_M_num[scen$scenario_name_chr == "sens_full_participation_100pct"] / 1000

# ---- 2. Benchmark table (FY2027 unless noted) -----------------------
bench <- tribble(
  ~item,                                          ~cost_bn, ~group,
  "DC plans (401(k)/403(b)/457) tax expenditure",   323.1,  "Existing retirement tax expenditures (FY2027, JCT)",
  "DB plans tax expenditure",                        172.6,  "Existing retirement tax expenditures (FY2027, JCT)",
  "IRAs (traditional + Roth) tax expenditure",        50.4,  "Existing retirement tax expenditures (FY2027, JCT)",
  "Keogh / self-employed plans tax expenditure",      20.4,  "Existing retirement tax expenditures (FY2027, JCT)",
  "EITC (revenue + outlay)",                          65.9,  "Comparator programs",
  "Hybrid proposal, 100 percent ceiling",          ceiling_bn, "This proposal (TY2027)",
  "Hybrid proposal, headline take-up",            headline_bn, "This proposal (TY2027)",
  "Enacted Saver's Match (JCT, FY2028)",               2.097, "Comparator programs",
  "EO / TrumpIRA.gov (administrative only)",           0.0,   "Comparator programs"
)

retirement_te_total <- 323.1 + 172.6 + 50.4 + 20.4
cat(sprintf("Total retirement tax expenditure, FY2027 (JCX-48-24): $%.1fB\n", retirement_te_total))
cat(sprintf("Headline proposal as share of retirement TE: %.1f percent\n",
            100 * headline_bn / retirement_te_total))
cat(sprintf("Ceiling proposal as share of retirement TE: %.1f percent\n",
            100 * ceiling_bn / retirement_te_total))

# ---- 3. Proposal incidence from row-level simulation ----------------
sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

# Pooled-universe MAGI deciles (all 145.34M workers), weighted
sim <- sim %>%
  arrange(magi_num) %>%
  mutate(cw = cumsum(WPFINWGT) / sum(WPFINWGT),
         universe_decile = pmin(10, floor(cw * 10) + 1))

dec_shares <- sim %>%
  group_by(universe_decile) %>%
  summarise(match_bn = sum(match_per_worker_num * WPFINWGT) / 1e9, .groups = "drop") %>%
  mutate(share = match_bn / sum(match_bn))
cat("\nProposal match dollars by pooled-universe MAGI decile (full participation):\n")
print(as.data.frame(dec_shares))

share_bottom_quintile <- sum(dec_shares$share[dec_shares$universe_decile <= 2])
share_bottom_two_quintiles <- sum(dec_shares$share[dec_shares$universe_decile <= 4])
share_top_quintile <- sum(dec_shares$share[dec_shares$universe_decile >= 9])
cat(sprintf("\nProposal: bottom-quintile share %.1f percent; bottom-two-quintile share %.1f percent; top-quintile share %.1f percent\n",
            100 * share_bottom_quintile, 100 * share_bottom_two_quintiles, 100 * share_top_quintile))

# ---- 4. Marginal shift in the combined retirement-subsidy stack -----
# CBO 2019 distribution (PGPF 2025): top quintile 63 percent, bottom 1 percent.
# Apply those shares to the FY2027 JCT retirement TE total; add the proposal.
te_top_q    <- 0.63 * retirement_te_total
te_bottom_q <- 0.01 * retirement_te_total

shift <- tibble(
  stack = c("Current retirement tax expenditures (FY2027)",
            "Plus hybrid proposal, headline",
            "Plus hybrid proposal, ceiling"),
  total_bn        = c(retirement_te_total,
                      retirement_te_total + headline_bn,
                      retirement_te_total + ceiling_bn),
  top_quintile_bn = c(te_top_q,
                      te_top_q + share_top_quintile * headline_bn,
                      te_top_q + share_top_quintile * ceiling_bn),
  bottom_quintile_bn = c(te_bottom_q,
                         te_bottom_q + share_bottom_quintile * headline_bn,
                         te_bottom_q + share_bottom_quintile * ceiling_bn)
) %>%
  mutate(top_quintile_share    = top_quintile_bn / total_bn,
         bottom_quintile_share = bottom_quintile_bn / total_bn)
cat("\nMarginal distributional shift of the combined retirement-subsidy stack:\n")
print(as.data.frame(shift))

# ---- 5. Output table ------------------------------------------------
bench_out <- bench %>%
  mutate(cost_bn = round(cost_bn, 1)) %>%
  rename(`Program / tax expenditure` = item,
         `Annual cost ($B)` = cost_bn,
         `Group` = group)
write.csv(bench_out, file.path(out_dir_tab, "scale_benchmarks.csv"), row.names = FALSE)

shift_out <- shift %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))
write.csv(shift_out, file.path(out_dir_tab, "distribution_shift.csv"), row.names = FALSE)
cat("\nWrote tables/scale_benchmarks.csv and tables/distribution_shift.csv\n")

# ---- 6. Figure 2 ----------------------------------------------------
fig_df <- bench %>%
  mutate(item = factor(item, levels = rev(bench$item)),
         fill_col = case_when(
           grepl("Hybrid", item) ~ "proposal",
           grepl("Existing", group) ~ "te",
           TRUE ~ "comp"))

p2 <- ggplot(fig_df, aes(x = cost_bn, y = item, fill = fill_col)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = ifelse(cost_bn < 0.05, "~$0",
                               paste0("$", comma(round(cost_bn, 1)), "B"))),
            hjust = -0.08, size = 3.4, color = "grey15") +
  scale_fill_manual(values = c(te = eig_blue, proposal = eig_gold, comp = eig_green)) +
  scale_x_continuous(labels = label_dollar(suffix = "B"),
                     expand = expansion(mult = c(0, 0.14))) +
  labs(
    title    = "Figure 2. Proposal cost vs. the retirement subsidy stack",
    subtitle = paste0("Annual federal cost, $ billions. Tax expenditures are JCT FY2027 estimates\n",
                      "(individuals); the enacted Saver's Match is JCT's FY2028 estimate (first year\n",
                      "of outlays); proposal rungs are TY2027 dollars."),
    x = "Annual federal cost", y = NULL,
    caption = paste0("Source: JCT, JCX-48-24, 2024; JCT, JCX-21-22, 2022; author's calculations from\n",
                     "data/processed/universal_sm_hybrid/scenario_results.parquet. EO cost reflects its\n",
                     "information-portal design (no accounts, no match-parameter change).")
  ) +
  theme_eig() +
  theme(plot.title.position = "plot", plot.caption.position = "plot")

ggsave(file.path(out_dir_fig, "fig2_scale_benchmarks.png"), p2,
       width = 9.5, height = 6, dpi = 200)
cat("Wrote figures/fig2_scale_benchmarks.png\n")
