# =============================================================================
# 01_constituency_map.R — Constituency mapping for the universal-account /
# Saver's Match hybrid (Liu, political-economy panel, 08).
#
# Inputs : data/processed/universal_sm_hybrid/simulation_results.parquet
# Outputs: economist-panel/08-liu-political-economy/tables/constituency_by_filing_route.csv
#          economist-panel/08-liu-political-economy/tables/losers_map.csv
#          economist-panel/08-liu-political-economy/figures/fig1_constituency_map.png
#          economist-panel/08-liu-political-economy/figures/fig3_match_rate_comparison.png
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/08-liu-political-economy/code/01_constituency_map.R
# =============================================================================

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

out_tab <- "economist-panel/08-liu-political-economy/tables"
out_fig <- "economist-panel/08-liu-political-economy/figures"

d <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

fg_lab <- c(single_mfs = "Single / MFS", hoh = "Head of household",
            mfj = "Married filing jointly")
rt_lab <- c(employer_plan = "Employer plan", universal_account = "Federal universal account")

el <- d %>%
  filter(eligible_flag) %>%
  mutate(filing_group = factor(fg_lab[filing_group_chr], levels = fg_lab),
         route        = factor(rt_lab[route_chr], levels = rt_lab),
         self_emp     = self_employed_flag %in% TRUE)  # NA treated as not self-employed

# -----------------------------------------------------------------------------
# 1. Constituency table: filing group x route (weighted, full participation $)
# -----------------------------------------------------------------------------
cell <- el %>%
  group_by(filing_group, route) %>%
  summarise(
    eligible_millions      = sum(WPFINWGT) / 1e6,
    match_dollars_bn_full  = sum(WPFINWGT * match_per_worker_num) / 1e9,
    mean_match_rate_pp     = weighted.mean(match_rate_pp_num, WPFINWGT),
    mean_magi              = weighted.mean(magi_num, WPFINWGT),
    self_employed_millions = sum(WPFINWGT[self_emp]) / 1e6,
    .groups = "drop")

tot_fg <- el %>%
  group_by(filing_group) %>%
  summarise(route = factor("All routes"),
            eligible_millions      = sum(WPFINWGT) / 1e6,
            match_dollars_bn_full  = sum(WPFINWGT * match_per_worker_num) / 1e9,
            mean_match_rate_pp     = weighted.mean(match_rate_pp_num, WPFINWGT),
            mean_magi              = weighted.mean(magi_num, WPFINWGT),
            self_employed_millions = sum(WPFINWGT[self_emp]) / 1e6,
            .groups = "drop")

tot_all <- el %>%
  summarise(filing_group = factor("All filing groups"), route = factor("All routes"),
            eligible_millions      = sum(WPFINWGT) / 1e6,
            match_dollars_bn_full  = sum(WPFINWGT * match_per_worker_num) / 1e9,
            mean_match_rate_pp     = weighted.mean(match_rate_pp_num, WPFINWGT),
            mean_magi              = weighted.mean(magi_num, WPFINWGT),
            self_employed_millions = sum(WPFINWGT[self_emp]) / 1e6)

constituency <- bind_rows(cell, tot_fg, tot_all) %>%
  mutate(share_of_eligible_pct = 100 * eligible_millions / tot_all$eligible_millions,
         share_of_dollars_pct  = 100 * match_dollars_bn_full / tot_all$match_dollars_bn_full,
         across(where(is.numeric), ~ round(.x, 2)))

write.csv(constituency, file.path(out_tab, "constituency_by_filing_route.csv"),
          row.names = FALSE)
cat("== Constituency table ==\n"); print(as.data.frame(constituency))

# Self-employment summary
cat("\nEligible self-employed (M):",
    round(sum(el$WPFINWGT[el$self_emp]) / 1e6, 2), "\n")

# -----------------------------------------------------------------------------
# 2. Losers map: hybrid vs. current-law (TY2027) Saver's Match rate, inside
#    current-law eligibility bands.
#    Current law (per CRS IF11159 / IRS Notice 2024-65): 50 percent match,
#    phasing linearly to zero over MAGI $20,500-$35,500 (single/MFS),
#    $30,750-$53,250 (HoH), $41,000-$71,000 (MFJ).
# -----------------------------------------------------------------------------
thr <- tibble(filing_group_chr = c("single_mfs", "hoh", "mfj"),
              cl_lower = c(20500, 30750, 41000),
              cl_upper = c(35500, 53250, 71000))

cl <- d %>%
  inner_join(thr, by = "filing_group_chr") %>%
  mutate(
    cl_rate = case_when(
      magi_num <= cl_lower ~ 0.5,
      magi_num <  cl_upper ~ 0.5 * (cl_upper - magi_num) / (cl_upper - cl_lower),
      TRUE                 ~ 0),
    cl_eligible = magi_num < cl_upper,
    # match dollars at an identical $2,000 contribution under each regime
    cl_match_at_2000  = pmin(cl_rate * 2000, 1000),
    hyb_match_at_2000 = pmin(match_rate_frac_num * 2000, 1000),
    region_below50    = cl_eligible & match_rate_frac_num < 0.5,   # charge definition
    strict_rate_loser = cl_eligible & match_rate_frac_num < cl_rate,
    strict_dollar_loser = cl_eligible & hyb_match_at_2000 < cl_match_at_2000)

losers <- cl %>%
  mutate(filing_group = factor(fg_lab[filing_group_chr], levels = fg_lab)) %>%
  group_by(filing_group) %>%
  summarise(
    current_law_eligible_millions = sum(WPFINWGT[cl_eligible]) / 1e6,
    region_hybrid_below50_millions = sum(WPFINWGT[region_below50]) / 1e6,
    mean_hybrid_rate_in_region_pp = ifelse(any(region_below50),
      weighted.mean(100 * match_rate_frac_num[region_below50], WPFINWGT[region_below50]), NA),
    mean_currentlaw_rate_in_region_pp = ifelse(any(region_below50),
      weighted.mean(100 * cl_rate[region_below50], WPFINWGT[region_below50]), NA),
    strict_rate_losers_millions   = sum(WPFINWGT[strict_rate_loser]) / 1e6,
    strict_dollar_losers_millions = sum(WPFINWGT[strict_dollar_loser]) / 1e6,
    .groups = "drop")

losers_tot <- cl %>%
  summarise(filing_group = factor("All filing groups"),
            current_law_eligible_millions = sum(WPFINWGT[cl_eligible]) / 1e6,
            region_hybrid_below50_millions = sum(WPFINWGT[region_below50]) / 1e6,
            mean_hybrid_rate_in_region_pp =
              weighted.mean(100 * match_rate_frac_num[region_below50], WPFINWGT[region_below50]),
            mean_currentlaw_rate_in_region_pp =
              weighted.mean(100 * cl_rate[region_below50], WPFINWGT[region_below50]),
            strict_rate_losers_millions   = sum(WPFINWGT[strict_rate_loser]) / 1e6,
            strict_dollar_losers_millions = sum(WPFINWGT[strict_dollar_loser]) / 1e6)

losers_out <- bind_rows(losers, losers_tot) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))
write.csv(losers_out, file.path(out_tab, "losers_map.csv"), row.names = FALSE)
cat("\n== Losers map ==\n"); print(as.data.frame(losers_out))

# -----------------------------------------------------------------------------
# 3. Figure 1: the beneficiary coalition, by filing group and route
# -----------------------------------------------------------------------------
fig1_dat <- cell %>%
  select(filing_group, route, eligible_millions, match_dollars_bn_full) %>%
  pivot_longer(c(eligible_millions, match_dollars_bn_full),
               names_to = "metric", values_to = "value") %>%
  mutate(metric = factor(metric,
                         levels = c("eligible_millions", "match_dollars_bn_full"),
                         labels = c("Eligible workers (millions)",
                                    "Match dollars, full participation ($ billions)")))

p1 <- ggplot(fig1_dat, aes(x = filing_group, y = value, fill = route)) +
  geom_col(width = 0.62) +
  geom_text(aes(label = comma(value, accuracy = 0.1)),
            position = position_stack(vjust = 0.5), color = "white",
            size = 3.4, fontface = "bold") +
  facet_wrap(~ metric, scales = "free_y") +
  scale_fill_manual(values = c("Employer plan" = "#2c526b",
                               "Federal universal account" = "#d08c2e")) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.06))) +
  labs(title = "The hybrid's beneficiary coalition: organized vs. unorganized constituencies",
       subtitle = "46.1M eligible workers and $24.9B in full-participation match dollars, by filing group and routing channel.\nThe federal universal account routes a majority of both workers and dollars to a constituency with no current institutional representative.",
       x = NULL, y = NULL, fill = "Routing channel",
       caption = "Source: Author's calculations from data/processed/universal_sm_hybrid/simulation_results.parquet (SIPP 2024 projected to TY2027, WPFINWGT weights).") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(size = 9.5, color = "grey25"),
        plot.caption = element_text(size = 7.5, color = "grey40", hjust = 0),
        panel.grid.major.x = element_blank(),
        panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))

ggsave(file.path(out_fig, "fig1_constituency_map.png"), p1,
       width = 10, height = 6, dpi = 200)

# -----------------------------------------------------------------------------
# 4. Figure 3: hybrid vs. current-law match-rate schedule (the empty losers map)
# -----------------------------------------------------------------------------
piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
print(as.data.frame(piv))
# Build schedules from pivots: 200 pct at zero MAGI, linear through 50 pct at
# pivot, zero at 4/3 of pivot.
piv_use <- piv %>%
  transmute(filing_group_chr, pivot = pivot_num, endpoint = endpoint_num)

grid <- thr %>%
  inner_join(piv_use, by = "filing_group_chr") %>%
  rowwise() %>%
  do({
    row <- .
    magi <- seq(0, 100000, by = 250)
    hyb  <- pmax(0, 2.0 - (1.5 / row$pivot) * magi)
    hyb[magi > row$endpoint] <- 0
    clr  <- ifelse(magi <= row$cl_lower, 0.5,
            ifelse(magi <  row$cl_upper,
                   0.5 * (row$cl_upper - magi) / (row$cl_upper - row$cl_lower), 0))
    data.frame(filing_group_chr = row$filing_group_chr, magi = magi,
               `Hybrid proposal` = 100 * hyb, `Current law (section 6433)` = 100 * clr,
               check.names = FALSE)
  }) %>%
  ungroup() %>%
  pivot_longer(c(`Hybrid proposal`, `Current law (section 6433)`),
               names_to = "schedule", values_to = "rate_pp") %>%
  mutate(filing_group = factor(fg_lab[filing_group_chr], levels = fg_lab))

band <- thr %>%
  inner_join(piv_use, by = "filing_group_chr") %>%
  mutate(filing_group = factor(fg_lab[filing_group_chr], levels = fg_lab))

p3 <- ggplot(grid, aes(magi, rate_pp, color = schedule)) +
  geom_rect(data = band, inherit.aes = FALSE,
            aes(xmin = pivot, xmax = cl_upper, ymin = -Inf, ymax = Inf),
            fill = "grey80", alpha = 0.35) +
  geom_line(linewidth = 1.0) +
  facet_wrap(~ filing_group, nrow = 1) +
  scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "K")) +
  scale_y_continuous(labels = label_number(suffix = " pct")) +
  scale_color_manual(values = c("Hybrid proposal" = "#b3402a",
                                "Current law (section 6433)" = "#2c526b")) +
  labs(title = "The losers' map is empty: hybrid match rate vs. current law, by MAGI",
       subtitle = "Shaded band: MAGI region where the hybrid rate falls below 50 percent while current-law eligibility persists.\nEven there, the hybrid schedule sits strictly above the current-law phased rate - no currently eligible worker faces a rate cut.",
       x = "Modified AGI (TY2027 dollars)", y = "Federal match rate",
       color = NULL,
       caption = "Source: Author's calculations. Hybrid schedule from data/processed/universal_sm_hybrid/pivot_table.parquet; current-law schedule per IRS Notice 2024-65 TY2027 thresholds.") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(size = 9.5, color = "grey25"),
        plot.caption = element_text(size = 7.5, color = "grey40", hjust = 0),
        panel.grid.minor = element_blank(),
        strip.text = element_text(face = "bold"))

ggsave(file.path(out_fig, "fig3_match_rate_comparison.png"), p3,
       width = 10, height = 4.8, dpi = 200)

cat("\nDone: 01_constituency_map.R\n")
