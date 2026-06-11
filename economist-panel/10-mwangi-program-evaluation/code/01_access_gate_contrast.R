# =============================================================================
# 01_access_gate_contrast.R  (Panelist 10 — Mwangi, program evaluation)
#
# Charge 1: Bottom-decile treatment contrast.
# Worker-level federal match offer by MAGI bin under three regimes:
#   (A) Current-law §6433 IF access were universal (univ_sm_match_m100)
#   (B) Current-law §6433 as it will actually operate: access-gated —
#       zero match for workers without a DC account (no deposit destination)
#   (C) The hybrid proposal (match_per_worker_num)
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/10-mwangi-program-evaluation/code/01_access_gate_contrast.R
# =============================================================================
suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

fig_dir <- "economist-panel/10-mwangi-program-evaluation/figures"
tab_dir <- "economist-panel/10-mwangi-program-evaluation/tables"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet") %>% filter(in_universe)

# --- Merge the two frames on person identifiers -------------------------------
df <- sim %>%
  inner_join(
    mod %>% select(ssuid, pnum, has_dc_account, any_retirement_access,
                   is_participating_dc, univ_sm_match_m100, sm_income_2027),
    by = c("SSUID" = "ssuid", "PNUM" = "pnum")
  )
stopifnot(nrow(df) == nrow(sim))  # 1:1 merge of the 14,961-row universe

# Sanity: MAGI proxies agree across frames
stopifnot(max(abs(df$magi_num - df$sm_income_2027), na.rm = TRUE) < 1)

# --- Three regimes (clip negative-income artifacts at zero) -------------------
df <- df %>%
  mutate(
    match_A_univlaw = pmax(univ_sm_match_m100, 0),                     # current law, access fixed
    match_B_gated   = if_else(has_dc_account, pmax(univ_sm_match_m100, 0), 0), # current law as operative
    match_C_hybrid  = pmax(match_per_worker_num, 0)                    # hybrid proposal
  )

# --- Headline access-gap statistics -------------------------------------------
cat("Universe (M):", round(sum(df$WPFINWGT)/1e6, 2), "\n")
cat("Share of universe with DC account:",
    round(weighted.mean(df$has_dc_account, df$WPFINWGT), 3), "\n")

# Aggregate full-participation offers ($B) -- computed BEFORE any re-sorting
cat("\nFull-participation aggregate offers ($B):\n")
cat("  A univ current law:", round(sum(df$WPFINWGT*df$match_A_univlaw)/1e9, 2), "\n")
cat("  B access-gated:    ", round(sum(df$WPFINWGT*df$match_B_gated)/1e9, 2), "\n")
cat("  C hybrid:          ", round(sum(df$WPFINWGT*df$match_C_hybrid)/1e9, 2), "\n")

elig <- df %>% filter(eligible_flag)
cat("Hybrid-eligible (M):", round(sum(elig$WPFINWGT)/1e6, 2), "\n")
cat("Hybrid-eligible WITHOUT a DC account (M):",
    round(sum(elig$WPFINWGT[!elig$has_dc_account])/1e6, 2), "\n")
cat("Share of hybrid-eligible without DC account:",
    round(sum(elig$WPFINWGT[!elig$has_dc_account])/sum(elig$WPFINWGT), 3), "\n")

# Bottom decile of the full universe by MAGI
df <- df %>% arrange(magi_num) %>%
  mutate(cumw = cumsum(WPFINWGT)/sum(WPFINWGT),
         universe_decile = pmin(10, floor(cumw*10) + 1))
d1 <- df %>% filter(universe_decile == 1)
cat("\n--- Bottom universe decile (by MAGI) ---\n")
cat("Decile-1 MAGI ceiling: $", round(max(d1$magi_num)), "\n")
cat("Decile-1 share with DC account:", round(sum(d1$WPFINWGT[d1$has_dc_account])/sum(d1$WPFINWGT), 3), "\n")
cat("Decile-1 mean match, regime A (univ current law): $",
    round(weighted.mean(d1$match_A_univlaw, d1$WPFINWGT), 0), "\n")
cat("Decile-1 mean match, regime B (access-gated):     $",
    round(weighted.mean(d1$match_B_gated, d1$WPFINWGT), 0), "\n")
cat("Decile-1 mean match, regime C (hybrid):           $",
    round(weighted.mean(d1$match_C_hybrid, d1$WPFINWGT), 0), "\n")

# --- $5K MAGI bins to $100K ---------------------------------------------------
bins <- df %>%
  filter(magi_num < 100000) %>%
  mutate(bin = floor(pmax(magi_num, 0)/5000)*5000) %>%
  group_by(bin) %>%
  summarise(
    workers_M           = sum(WPFINWGT)/1e6,
    share_with_dc       = weighted.mean(has_dc_account, WPFINWGT),
    `Current law, universal access` = weighted.mean(match_A_univlaw, WPFINWGT),
    `Current law, access-gated (as enacted)` = weighted.mean(match_B_gated, WPFINWGT),
    `Hybrid proposal` = weighted.mean(match_C_hybrid, WPFINWGT),
    .groups = "drop"
  )

write.csv(bins, file.path(tab_dir, "match_by_magi_bin_three_regimes.csv"), row.names = FALSE)

long <- bins %>%
  pivot_longer(cols = c(`Current law, universal access`,
                        `Current law, access-gated (as enacted)`,
                        `Hybrid proposal`),
               names_to = "regime", values_to = "mean_match") %>%
  mutate(regime = factor(regime, levels = c(
    "Hybrid proposal",
    "Current law, universal access",
    "Current law, access-gated (as enacted)")))

p1 <- ggplot(long, aes(x = bin + 2500, y = mean_match, color = regime)) +
  geom_step(aes(x = bin), linewidth = 1.1, direction = "hv") +
  scale_color_manual(values = c(
    "Hybrid proposal" = "#1a654d",
    "Current law, universal access" = "#2b6cb0",
    "Current law, access-gated (as enacted)" = "#c0392b")) +
  scale_x_continuous(labels = dollar_format(scale = 1/1000, suffix = "K"),
                     breaks = seq(0, 100000, 20000)) +
  scale_y_continuous(labels = dollar_format()) +
  labs(
    title = "The access gate, not the match rate, zeroes out the bottom",
    subtitle = "Mean federal Saver's Match offer per worker by MAGI bin ($5K bins), full participation, TY2027.\nRed line: §6433 as enacted — workers without a DC account have nowhere to receive the deposit.",
    x = "Modified adjusted gross income (TY2027 dollars)",
    y = "Mean match offer per worker",
    color = NULL,
    caption = "Source: Author's calculations from SIPP 2024 projected to TY2027 (EIG simulation frames:\nsipp_modeled.parquet, simulation_results.parquet); weights WPFINWGT. Panelist 10 (Mwangi)."
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", legend.direction = "vertical",
        panel.grid.minor = element_blank(),
        panel.grid.major.x = element_blank(),
        plot.title = element_text(face = "bold"))

ggsave(file.path(fig_dir, "fig1_access_gate_three_regimes.png"), p1,
       width = 9, height = 6.5, dpi = 200)
cat("\nWrote fig1 and match_by_magi_bin_three_regimes.csv\n")

# Bottom-of-distribution table for the assessment text
bot <- bins %>% filter(bin < 25000) %>%
  mutate(across(c(share_with_dc), ~round(., 3)),
         across(c(`Current law, universal access`,
                  `Current law, access-gated (as enacted)`,
                  `Hybrid proposal`), ~round(., 0)))
print(as.data.frame(bot))
