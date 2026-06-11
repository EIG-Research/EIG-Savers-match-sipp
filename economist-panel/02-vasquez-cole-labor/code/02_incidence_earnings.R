# 02_incidence_earnings.R -- Match-dollar incidence by PERSONAL EARNINGS decile
# Panelist 02 (Vasquez-Cole). Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/02-vasquez-cole-labor/code/02_incidence_earnings.R
#
# Earnings (not MAGI) is the lens for marginalized workers: secondary earners,
# part-time, and gig workers have low personal earnings even when household
# MAGI is higher. Compares, decile by decile of the full 145.34M universe:
#   (1) hybrid proposal match (match_per_worker_num, full participation)
#   (2) current-law SS6433 match WITH the de facto DC-account access gate
#       (sm_match_per_person x has_dc_account)
#   (3) current-law parameters with universal access (univ_sm_match_m100)
# All at full participation for a like-for-like structural comparison.

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

OUT_TAB <- "economist-panel/02-vasquez-cole-labor/tables"
OUT_FIG <- "economist-panel/02-vasquez-cole-labor/figures"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet") %>% filter(in_universe)

# ---- join hybrid simulation to the modeled current-law frame ----------------
stopifnot(nrow(sim) == nrow(mod))
df <- inner_join(
  sim %>% select(SSUID, PNUM, WPFINWGT, earnings_num, magi_num, eligible_flag,
                 match_per_worker_num, has_existing_dc_flag,
                 any_retirement_access_v2_chr),
  mod %>% select(ssuid, pnum, weight, earnings_2027, has_dc_account,
                 is_anymatch_m100, sm_match_per_person, univ_sm_match_m100),
  by = c("SSUID" = "ssuid", "PNUM" = "pnum")
)
stopifnot(nrow(df) == nrow(sim))
stopifnot(max(abs(df$WPFINWGT - df$weight)) < 1e-6)
stopifnot(max(abs(df$earnings_num - df$earnings_2027)) < 1e-3)
cat("Join check passed:", nrow(df), "rows; weights and earnings identical across frames.\n")

# Current law as it will operate: match flows only to workers who already hold
# a DC-type account (the access gate). sm_match_per_person already embeds the
# 50 percent rate, SOI-band contribution, and the MAGI phaseout factor.
df <- df %>%
  mutate(
    match_current_gated = if_else(has_dc_account %in% TRUE, sm_match_per_person, 0),
    match_current_univ  = univ_sm_match_m100,
    match_hybrid        = match_per_worker_num
  )

# ---- weighted earnings deciles of the FULL universe -------------------------
df <- df %>%
  arrange(earnings_num) %>%
  mutate(cw = cumsum(WPFINWGT) / sum(WPFINWGT),
         decile = pmin(10L, findInterval(cw, seq(0, 1, 0.1), left.open = TRUE)))

wq <- function(x, w, p) {
  o <- order(x); x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  vapply(p, function(pp) x[which(cw >= pp)[1]], numeric(1))
}

dec_tab <- df %>%
  group_by(decile) %>%
  summarise(
    workers_m            = sum(WPFINWGT) / 1e6,
    earn_med             = wq(earnings_num, WPFINWGT, 0.5),
    share_eligible_hybrid = sum(WPFINWGT[eligible_flag]) / sum(WPFINWGT),
    avg_match_hybrid     = sum(WPFINWGT * match_hybrid) / sum(WPFINWGT),
    avg_match_current    = sum(WPFINWGT * match_current_gated) / sum(WPFINWGT),
    avg_match_curr_univ  = sum(WPFINWGT * match_current_univ) / sum(WPFINWGT),
    dollars_hybrid_b     = sum(WPFINWGT * match_hybrid) / 1e9,
    dollars_current_b    = sum(WPFINWGT * match_current_gated) / 1e9,
    .groups = "drop"
  ) %>%
  mutate(
    share_dollars_hybrid  = dollars_hybrid_b / sum(dollars_hybrid_b),
    share_dollars_current = dollars_current_b / sum(dollars_current_b)
  )

cat("\n=== Incidence by personal-earnings decile (full 145.34M universe, full participation) ===\n")
print(as.data.frame(dec_tab), digits = 3)
write.csv(dec_tab, file.path(OUT_TAB, "table3_incidence_by_earnings_decile.csv"),
          row.names = FALSE)

# ---- bottom-quintile summary -------------------------------------------------
bq <- df %>% filter(decile <= 2)
top <- df %>% filter(decile > 2)
cat("\n=== Bottom earnings quintile (deciles 1-2) ===\n")
cat("Workers (M):", round(sum(bq$WPFINWGT)/1e6, 2), "\n")
cat("Median personal earnings (TY2027 $):", round(wq(bq$earnings_num, bq$WPFINWGT, 0.5)), "\n")
cat("Avg hybrid match per worker ($):", round(sum(bq$WPFINWGT*bq$match_hybrid)/sum(bq$WPFINWGT), 1), "\n")
cat("Avg current-law gated match per worker ($):", round(sum(bq$WPFINWGT*bq$match_current_gated)/sum(bq$WPFINWGT), 1), "\n")
cat("Avg current-law universal-access match ($):", round(sum(bq$WPFINWGT*bq$match_current_univ)/sum(bq$WPFINWGT), 1), "\n")
cat("Ratio hybrid / current-law gated:",
    round(sum(bq$WPFINWGT*bq$match_hybrid)/sum(bq$WPFINWGT*bq$match_current_gated), 2), "\n")
cat("Bottom-quintile share of hybrid dollars:",
    percent(sum(bq$WPFINWGT*bq$match_hybrid)/sum(df$WPFINWGT*df$match_hybrid), 0.1), "\n")
cat("Bottom-quintile share of current-law gated dollars:",
    percent(sum(bq$WPFINWGT*bq$match_current_gated)/sum(df$WPFINWGT*df$match_current_gated), 0.1), "\n")
cat("Bottom-quintile DC-account ownership rate:",
    percent(sum(bq$WPFINWGT[bq$has_dc_account %in% TRUE])/sum(bq$WPFINWGT), 0.1), "\n")
cat("Rest of distribution DC-account ownership rate:",
    percent(sum(top$WPFINWGT[top$has_dc_account %in% TRUE])/sum(top$WPFINWGT), 0.1), "\n")
cat("Bottom-quintile share in current-law MAGI band (is_anymatch_m100):",
    percent(sum(bq$WPFINWGT[bq$is_anymatch_m100 %in% TRUE])/sum(bq$WPFINWGT), 0.1), "\n")
cat("...of whom hold a DC account (the gate):",
    percent(sum(bq$WPFINWGT[bq$is_anymatch_m100 %in% TRUE & bq$has_dc_account %in% TRUE]) /
            sum(bq$WPFINWGT[bq$is_anymatch_m100 %in% TRUE]), 0.1), "\n")

bq_summary <- tibble(
  measure = c("Workers (M)", "Median personal earnings (TY2027 $)",
              "Avg match per worker, hybrid ($)",
              "Avg match per worker, current law gated ($)",
              "Avg match per worker, current-law params w/ universal access ($)",
              "Share of program dollars, hybrid",
              "Share of program dollars, current law gated",
              "DC-account ownership rate",
              "Share in current-law MAGI band",
              "Share of in-band workers holding a DC account"),
  value = c(round(sum(bq$WPFINWGT)/1e6, 2),
            round(wq(bq$earnings_num, bq$WPFINWGT, 0.5)),
            round(sum(bq$WPFINWGT*bq$match_hybrid)/sum(bq$WPFINWGT), 1),
            round(sum(bq$WPFINWGT*bq$match_current_gated)/sum(bq$WPFINWGT), 1),
            round(sum(bq$WPFINWGT*bq$match_current_univ)/sum(bq$WPFINWGT), 1),
            round(sum(bq$WPFINWGT*bq$match_hybrid)/sum(df$WPFINWGT*df$match_hybrid), 4),
            round(sum(bq$WPFINWGT*bq$match_current_gated)/sum(df$WPFINWGT*df$match_current_gated), 4),
            round(sum(bq$WPFINWGT[bq$has_dc_account %in% TRUE])/sum(bq$WPFINWGT), 4),
            round(sum(bq$WPFINWGT[bq$is_anymatch_m100 %in% TRUE])/sum(bq$WPFINWGT), 4),
            round(sum(bq$WPFINWGT[bq$is_anymatch_m100 %in% TRUE & bq$has_dc_account %in% TRUE]) /
                  sum(bq$WPFINWGT[bq$is_anymatch_m100 %in% TRUE]), 4))
)
write.csv(bq_summary, file.path(OUT_TAB, "table4_bottom_quintile_summary.csv"),
          row.names = FALSE)

# ---- Figure 1: average match per worker by earnings decile -------------------
plot_df <- dec_tab %>%
  select(decile, avg_match_hybrid, avg_match_current, avg_match_curr_univ) %>%
  pivot_longer(-decile, names_to = "regime", values_to = "avg_match") %>%
  mutate(regime = recode(regime,
    avg_match_hybrid    = "Hybrid proposal (200% floor + universal account)",
    avg_match_current   = "Current law §6433 (50% rate, DC-account gate)",
    avg_match_curr_univ = "Current-law parameters, access gate removed"
  ),
  regime = factor(regime, levels = c(
    "Hybrid proposal (200% floor + universal account)",
    "Current-law parameters, access gate removed",
    "Current law §6433 (50% rate, DC-account gate)"
  )))

p1 <- ggplot(plot_df, aes(x = factor(decile), y = avg_match, fill = regime)) +
  geom_col(position = position_dodge(width = 0.78), width = 0.72) +
  scale_fill_manual(values = c(
    "Hybrid proposal (200% floor + universal account)" = "#1d6a96",
    "Current-law parameters, access gate removed"      = "#8fb8d2",
    "Current law §6433 (50% rate, DC-account gate)" = "#d2553e"
  ), name = NULL) +
  scale_y_continuous(labels = label_dollar(), expand = expansion(mult = c(0, 0.05))) +
  labs(
    title = "Federal match dollars per worker, by personal-earnings decile",
    subtitle = "Average annual Saver's Match per worker across the full 145.34M-worker universe,\nfull participation, tax year 2027",
    x = "Personal-earnings decile (1 = lowest earners)",
    y = "Average federal match per worker",
    caption = "Source: Author's calculations from SIPP 2024 projected to TY2027 (EIG simulation frames\ndata/processed/universal_sm_hybrid/simulation_results.parquet and data/processed/sipp_modeled.parquet). Weighted by WPFINWGT.\nCurrent law gated = §6433 match payable only to workers already holding a DC-type account."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.caption = element_text(size = 8, hjust = 0, color = "grey35"),
    plot.title = element_text(face = "bold")
  ) +
  guides(fill = guide_legend(nrow = 3))

ggsave(file.path(OUT_FIG, "fig1_match_per_worker_by_earnings_decile.png"),
       p1, width = 9.5, height = 6.5, dpi = 200)
cat("\nSaved", file.path(OUT_FIG, "fig1_match_per_worker_by_earnings_decile.png"), "\n")
