# =====================================================================
# 01_indexing_ratchet.R  —  The indexing ratchet (Calloway, panelist 05)
#
# Demonstrates quantitatively that:
#  (a) the hybrid's median-anchored pivots hold the eligible SHARE of
#      workers roughly constant forever (a self-perpetuating program),
#  (b) the enacted Saver's Match (§6433), with nominal-fixed-then-CPI
#      thresholds, erodes toward zero coverage as wages outgrow the
#      thresholds (a self-sunsetting program),
#  (c) under re-anchoring, the hybrid's nominal full-participation cost
#      also creeps upward as wage growth pushes 3%-default contributions
#      against the fixed $1,000 cap.
#
# Run from the repository root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/05-calloway-libertarian/code/01_indexing_ratchet.R
# =====================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

out_tab <- "economist-panel/05-calloway-libertarian/tables"
out_fig <- "economist-panel/05-calloway-libertarian/figures"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet")

# ---------------------------------------------------------------
# 0. Reconstruct and validate the hybrid match-rate schedule
#    rate_pp(magi) = max(0, 200 - (150/pivot) * magi); zero at 4/3 pivot
# ---------------------------------------------------------------
FLOOR_PP <- 200; PIVOT_PP <- 50
pivot_lkp <- setNames(piv$pivot_num, piv$filing_group_chr)

# Rate is bounded above at the floor (negative-MAGI rows are held at the
# 200 percent floor in the pipeline) and below at zero.
hybrid_rate_pp <- function(magi, fg, pivots, floor_pp = FLOOR_PP) {
  p <- pivots[fg]
  pmin(floor_pp, pmax(0, floor_pp - ((floor_pp - PIVOT_PP) / p) * magi))
}

chk <- sim %>%
  mutate(rate_chk = hybrid_rate_pp(magi_num, filing_group_chr, pivot_lkp)) %>%
  summarise(max_abs_diff = max(abs(rate_chk - match_rate_pp_num)),
            elig_mismatch = sum((rate_chk > 0) != eligible_flag))
cat("Schedule validation — max |rate diff| (pp):", chk$max_abs_diff,
    "| eligibility mismatches:", chk$elig_mismatch, "\n")
stopifnot(chk$max_abs_diff < 1e-6, chk$elig_mismatch == 0)

# Helper: hybrid eligibility/cost for incomes scaled by g, with pivots
# either FIXED at the 2027-anchored values or RE-ANCHORED (scaled by g —
# exact under proportional income growth, since the weighted-median
# anchor scales one-for-one with incomes).
hybrid_stats <- function(g_income, g_pivot, cap = 1000, contrib_rate = 0.03) {
  magi  <- sim$magi_num * g_income
  earn  <- sim$earnings_num * g_income
  pivots <- pivot_lkp * g_pivot
  rate  <- hybrid_rate_pp(magi, sim$filing_group_chr, pivots) / 100
  elig  <- rate > 0
  match <- pmin(rate * contrib_rate * earn, cap)
  tibble(
    eligible_M   = sum(sim$WPFINWGT[elig]) / 1e6,
    share_pct    = 100 * sum(sim$WPFINWGT[elig]) / sum(sim$WPFINWGT),
    full_cost_B  = sum(match[elig] * sim$WPFINWGT[elig]) / 1e9,
    avg_match    = sum(match[elig] * sim$WPFINWGT[elig]) / sum(sim$WPFINWGT[elig]),
    capped_pct   = 100 * sum(sim$WPFINWGT[elig & match >= cap - 1e-9]) /
                         sum(sim$WPFINWGT[elig])
  )
}

# Sanity: baseline reproduces the published 46.07M / $24.9B
base <- hybrid_stats(1, 1)
cat(sprintf("Hybrid baseline check: %.2fM eligible (%.1f%%), $%.2fB full participation\n",
            base$eligible_M, base$share_pct, base$full_cost_B))

# ---------------------------------------------------------------
# 1. Current-law §6433 eligibility (income-eligible for any match,
#    universal-access counterfactual) on the same 145.34M universe
# ---------------------------------------------------------------
uni <- mod %>% filter(in_universe)
cat(sprintf("sipp_modeled universe: %.2fM weighted\n", sum(uni$weight) / 1e6))

cl_share <- function(income) {
  elig <- income < uni$threshold_upper_m100
  c(eligible_M = sum(uni$weight[elig]) / 1e6,
    share_pct  = 100 * sum(uni$weight[elig]) / sum(uni$weight))
}

cl_2027 <- cl_share(uni$sm_income_2027)   # TY2027 incomes vs TY2027 thresholds
cl_2024 <- cl_share(uni$sm_income_2024)   # 2024 incomes vs the same thresholds
cat(sprintf("Current law, 2024 incomes vs 2027 thresholds: %.2fM (%.1f%%)\n",
            cl_2024["eligible_M"], cl_2024["share_pct"]))
cat(sprintf("Current law, 2027 incomes vs 2027 thresholds: %.2fM (%.1f%%)\n",
            cl_2027["eligible_M"], cl_2027["share_pct"]))
cat(sprintf("Erosion per 9.3%% of wage growth (~3 years): %.2fM workers (%.1f pp of the universe)\n",
            cl_2024["eligible_M"] - cl_2027["eligible_M"],
            cl_2024["share_pct"] - cl_2027["share_pct"]))

# Hybrid mirror image: 2024 incomes against 2027-anchored pivots vs re-anchored
hyb_fixedpiv  <- hybrid_stats(1 / 1.093, 1)          # incomes deflated, pivots fixed
hyb_reanchor  <- hybrid_stats(1 / 1.093, 1 / 1.093)  # pivots re-anchored
cat(sprintf("Hybrid, 2024 incomes vs 2027-anchored pivots: %.2fM (%.1f%%)\n",
            hyb_fixedpiv$eligible_M, hyb_fixedpiv$share_pct))
cat(sprintf("Hybrid, 2024 incomes vs re-anchored pivots:   %.2fM (%.1f%%)\n",
            hyb_reanchor$eligible_M, hyb_reanchor$share_pct))

# ---------------------------------------------------------------
# 2. Long-run erosion paths, TY2027–TY2051 (eight 3-year SIPP waves)
#    Wage growth: 1.093 per 3-year wave (the repo's own projection factor,
#    ~3.0%/yr nominal). Current-law thresholds are CPI-indexed from 2028
#    (§6433(h)(1)); we assume wages outpace CPI by 1.0 pp/yr (≈ SSA-style
#    long-run real wage differential), i.e., relative erosion of
#    1.01^3 ≈ 3.03% per wave. A frozen-nominal path (no indexing at all)
#    is shown for reference — it is the 2024→2027 statutory reality,
#    since the thresholds are static until TY2028.
# ---------------------------------------------------------------
g_wave_nominal <- 1.093          # nominal wage growth per 3-year wave
g_wave_real    <- 1.01^3         # wage growth net of CPI indexing, per wave
waves <- 0:8                     # TY2027 ... TY2051

paths <- bind_rows(lapply(waves, function(k) {
  hyb <- hybrid_stats(g_wave_nominal^k, g_wave_nominal^k)  # re-anchored
  tibble(
    wave = k, year = 2027 + 3 * k,
    hybrid_median_anchored_share = hyb$share_pct,
    hybrid_full_cost_B           = hyb$full_cost_B,
    hybrid_capped_pct            = hyb$capped_pct,
    currentlaw_cpi_indexed_share = cl_share(uni$sm_income_2027 * g_wave_real^k)["share_pct"],
    currentlaw_frozen_share      = cl_share(uni$sm_income_2027 * g_wave_nominal^k)["share_pct"]
  )
}))

write.csv(paths, file.path(out_tab, "indexing_ratchet_paths.csv"), row.names = FALSE)
print(as.data.frame(paths), digits = 4)

# ---------------------------------------------------------------
# 3. Figure 1 — the self-perpetuating vs self-sunsetting contrast
# ---------------------------------------------------------------
plot_df <- paths %>%
  select(year, hybrid_median_anchored_share, currentlaw_cpi_indexed_share,
         currentlaw_frozen_share) %>%
  pivot_longer(-year, names_to = "series", values_to = "share") %>%
  mutate(series = factor(series,
    levels = c("hybrid_median_anchored_share", "currentlaw_cpi_indexed_share",
               "currentlaw_frozen_share"),
    labels = c("Hybrid proposal: pivots re-anchored to median MAGI each wave",
               "Current law (§6433): CPI-indexed thresholds, wages +1 pp/yr over CPI",
               "Current law (§6433): thresholds frozen in nominal terms")))

fig1 <- ggplot(plot_df, aes(year, share, color = series, linetype = series)) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 1.8) +
  scale_color_manual(values = c("#b2182b", "#2166ac", "#92c5de")) +
  scale_linetype_manual(values = c("solid", "solid", "dashed")) +
  scale_y_continuous(labels = label_number(suffix = "%"), limits = c(0, 36),
                     breaks = seq(0, 35, 5)) +
  scale_x_continuous(breaks = seq(2027, 2051, 6)) +
  labs(
    title = "A program that never sunsets: median-indexed eligibility vs. fixed thresholds",
    subtitle = paste0("Share of the 145.3M-worker universe eligible for any Saver's Match, TY2027–2051.\n",
                      "Median-anchored pivots lock in ~32% of workers forever; current-law thresholds erode toward zero."),
    x = "Tax year", y = "Eligible share of the worker universe",
    color = NULL, linetype = NULL,
    caption = paste0("Source: Author's calculations from SIPP 2024 (EIG repo, simulation_results.parquet & sipp_modeled.parquet).\n",
                     "Wage growth 1.093 per 3-year wave (repo projection factor); CPI-indexed path assumes wages outpace CPI by 1 pp/yr.")
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", legend.direction = "vertical",
        plot.title = element_text(face = "bold"),
        plot.caption = element_text(size = 8, color = "grey40", hjust = 0))

ggsave(file.path(out_fig, "fig1_indexing_ratchet.png"), fig1,
       width = 9, height = 6, dpi = 200)
cat("Wrote", file.path(out_fig, "fig1_indexing_ratchet.png"), "\n")
