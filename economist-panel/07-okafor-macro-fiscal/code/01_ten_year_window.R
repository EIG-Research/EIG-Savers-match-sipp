# ------------------------------------------------------------------
# 01_ten_year_window.R  --  Dr. Sam Okafor (macro-fiscal panelist)
# FY2027-FY2036 outlay projection for the universal-account /
# Saver's Match hybrid under the three scenario rungs, compared with
# the JCT score of the enacted Saver's Match (SECURE 2.0 sec. 103,
# JCX-21-22).
#
# Run from the repository root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/07-okafor-macro-fiscal/code/01_ten_year_window.R
#
# Assumptions (stated, sourced):
#  - Scenario rungs (TY2027 dollars) from
#    data/processed/universal_sm_hybrid/scenario_results.parquet:
#    headline $14.946B (59.8 percent take-up), 80 percent $19.938B,
#    100 percent ceiling $24.923B.
#  - Nominal wage growth g = 3.9 percent per year. CBO's February 2026
#    Budget and Economic Outlook implies nominal GDP growth of about
#    3.9 percent per year over FY2026-FY2036 (revenues $5.6T at 17.5
#    percent of GDP in 2026 vs. $8.3T at 17.8 percent in 2036 implies
#    (46.6/32.0)^(1/10)-1 = 3.8 percent; the spending side implies 3.9
#    percent) with a roughly stable wage share (42.3 percent of GDP in
#    2026, 42.0 in 2027). Because the proposal's pivots are re-anchored
#    to the median of the wage distribution, the eligible share of
#    workers is constant and program cost scales with the wage bill.
#  - Phase-in ramp: 70 / 90 / 100 percent of steady-state scenario
#    participation in TY2027 / TY2028 / TY2029+ (account provisioning,
#    payroll onboarding, slower self-employed channel).
#  - Fiscal-year timing: the match for tax year t is deposited after
#    the return is filed, i.e., in fiscal year t+1 (sec. 6433 pays "as
#    soon as practicable" after filing; first deposits in 2028 for
#    TY2027). FY2027 outlays are therefore zero and the FY2027-2036
#    window captures tax years 2027-2035.
#  - Enacted sec. 103 comparator: JCX-21-22 line "3. Saver's Match"
#    (effective tyba 12/31/26): FY2028 -2,097; FY2029 -1,907; FY2030
#    -1,819; FY2031 -1,807; FY2032 -1,687; FY2023-32 total -9,318
#    ($ millions). FY2033-36 extended at the observed -5.3 percent/yr
#    nominal decline (fixed thresholds CPI-indexed off static 2027
#    levels and an unindexed $2,000 contribution base erode the
#    program against nominal wage growth) -- marked as panelist
#    extrapolation, not JCT.
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

# EIG style tokens
eig_teal   <- "#024140"
eig_blue   <- "#194F8B"
eig_green  <- "#19644D"
eig_gold   <- "#E1AD28"
eig_cyan   <- "#176F96"
eig_black  <- "#000000"

theme_eig <- function() {
  theme_minimal(base_size = 12) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
      panel.grid.major.y = element_line(color = "grey85", linewidth = 0.3),
      plot.title         = element_text(face = "bold", size = 14),
      plot.subtitle      = element_text(size = 10.5, color = "grey25"),
      plot.caption       = element_text(size = 8.5, color = "grey35", hjust = 0),
      legend.position    = "top",
      legend.title       = element_blank(),
      axis.title         = element_text(size = 10.5)
    )
}

# ---- 1. Scenario rungs from the repo pipeline (read-only) ----------
scen <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")

rungs <- scen %>%
  filter(scenario_name_chr %in% c("headline_sipp_observed_conditional",
                                  "sens_auto_enroll_80pct",
                                  "sens_full_participation_100pct")) %>%
  transmute(
    scenario = recode(scenario_name_chr,
      headline_sipp_observed_conditional = "Headline (59.8 percent take-up)",
      sens_auto_enroll_80pct             = "80 percent auto-enrollment",
      sens_full_participation_100pct     = "100 percent ceiling"),
    ty2027_cost_bn = annual_cost_M_num / 1000
  )

stopifnot(nrow(rungs) == 3)
cat("Scenario rungs (TY2027 $B):\n"); print(rungs)

# ---- 2. Ten-year projection ----------------------------------------
g    <- 0.039                       # nominal wage growth (CBO Feb 2026 consistent)
ramp <- c(`2027` = 0.70, `2028` = 0.90)  # phase-in of steady-state participation

tax_years <- 2027:2035              # TY t pays out in FY t+1; FY2027-36 window
proj <- expand_grid(rungs, tax_year = tax_years) %>%
  mutate(
    ramp_factor  = ifelse(as.character(tax_year) %in% names(ramp),
                          ramp[as.character(tax_year)], 1),
    ty_cost_bn   = ty2027_cost_bn * (1 + g)^(tax_year - 2027) * ramp_factor,
    fiscal_year  = tax_year + 1
  )

# Add the empty FY2027 row for completeness of the budget window
fy_grid <- expand_grid(scenario = rungs$scenario, fiscal_year = 2027:2036) %>%
  left_join(proj %>% select(scenario, fiscal_year, ty_cost_bn),
            by = c("scenario", "fiscal_year")) %>%
  mutate(outlay_bn = replace_na(ty_cost_bn, 0)) %>%
  select(scenario, fiscal_year, outlay_bn)

ten_year <- fy_grid %>%
  group_by(scenario) %>%
  summarise(cum_fy2027_36_bn = sum(outlay_bn), .groups = "drop")
cat("\nCumulative FY2027-2036 outlays ($B):\n"); print(ten_year)

# ---- 3. Enacted sec. 103 comparator (JCX-21-22) ---------------------
jct_103 <- tibble(
  fiscal_year = 2028:2032,
  outlay_bn   = c(2.097, 1.907, 1.819, 1.807, 1.687),  # JCX-21-22, sec. 103 line
  source      = "JCT score (JCX-21-22)"
)
# Observed nominal decline within the scored years
decl <- (jct_103$outlay_bn[5] / jct_103$outlay_bn[1])^(1/4) - 1
cat(sprintf("\nJCT sec.103 implied nominal trend: %.1f percent/yr\n", 100 * decl))

jct_ext <- tibble(
  fiscal_year = 2033:2036,
  outlay_bn   = jct_103$outlay_bn[5] * (1 + decl)^(1:4),
  source      = "Panelist extrapolation of JCT trend"
)
jct_all <- bind_rows(jct_103, jct_ext)
jct_window_total <- sum(jct_all$outlay_bn[jct_all$fiscal_year >= 2027])
cat(sprintf("Enacted sec.103, FY2027-36 (JCT + extrapolation): $%.1fB\n", jct_window_total))
cat(sprintf("Enacted sec.103, JCT-scored FY2023-32 total: $%.3fB\n", sum(jct_103$outlay_bn)))

# ---- 4. Output table ------------------------------------------------
tab <- fy_grid %>%
  pivot_wider(names_from = scenario, values_from = outlay_bn) %>%
  left_join(jct_all %>% transmute(fiscal_year,
                                  `Enacted sec. 6433 (JCT + extrapolation)` = outlay_bn),
            by = "fiscal_year") %>%
  mutate(`Enacted sec. 6433 (JCT + extrapolation)` =
           replace_na(`Enacted sec. 6433 (JCT + extrapolation)`, 0)) %>%
  arrange(fiscal_year)

totals <- tab %>%
  summarise(across(-fiscal_year, sum)) %>%
  mutate(fiscal_year = NA_integer_) %>%
  select(names(tab))

tab_out <- bind_rows(tab, totals) %>%
  mutate(fiscal_year = ifelse(is.na(fiscal_year), "FY2027-36 total",
                              as.character(fiscal_year))) %>%
  rename(`Fiscal year` = fiscal_year) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))

write.csv(tab_out, file.path(out_dir_tab, "ten_year_projection.csv"),
          row.names = FALSE)
cat("\nWrote tables/ten_year_projection.csv\n"); print(as.data.frame(tab_out))

# ---- 5. Figure 1 ----------------------------------------------------
plot_df <- bind_rows(
  fy_grid %>% mutate(series = scenario, style = "Proposal rung"),
  jct_all %>% transmute(fiscal_year, outlay_bn,
                        series = "Enacted Saver's Match (sec. 6433)",
                        style  = source)
) %>%
  mutate(series = factor(series, levels = c(
    "100 percent ceiling", "80 percent auto-enrollment",
    "Headline (59.8 percent take-up)", "Enacted Saver's Match (sec. 6433)")))

p1 <- ggplot() +
  geom_line(data = plot_df %>% filter(style != "Panelist extrapolation of JCT trend"),
            aes(fiscal_year, outlay_bn, color = series), linewidth = 1.1) +
  geom_line(data = bind_rows(
              jct_all %>% filter(fiscal_year >= 2032) %>%
                mutate(series = "Enacted Saver's Match (sec. 6433)")),
            aes(fiscal_year, outlay_bn, color = series),
            linewidth = 1.1, linetype = "dotted") +
  geom_point(data = plot_df, aes(fiscal_year, outlay_bn, color = series), size = 1.8) +
  annotate("text", x = 2033.6, y = 3.2, size = 3, color = eig_black, hjust = 0,
           label = "Dotted: JCT trend\nextrapolated beyond FY2032") +
  scale_color_manual(values = c(
    "100 percent ceiling"                = eig_gold,
    "80 percent auto-enrollment"         = eig_cyan,
    "Headline (59.8 percent take-up)"    = eig_teal,
    "Enacted Saver's Match (sec. 6433)"  = eig_blue)) +
  scale_x_continuous(breaks = 2027:2036) +
  scale_y_continuous(labels = label_dollar(suffix = "B"), limits = c(0, NA)) +
  labs(
    title    = "Figure 1. Ten-year outlay paths: hybrid proposal vs. the enacted Saver's Match",
    subtitle = paste0("Federal fiscal-year outlays, FY2027-FY2036. Proposal rungs grow with the wage bill (3.9 percent/yr,\n",
                      "median-indexed pivots hold the eligible share constant); the enacted sec. 6433 declines in nominal terms\n",
                      "(CPI-indexed thresholds and an unindexed $2,000 base). Tax-year costs pay out in the following fiscal year."),
    x = "Fiscal year", y = "Outlays",
    caption = paste0("Source: Author's calculations from data/processed/universal_sm_hybrid/scenario_results.parquet; JCT, JCX-21-22, 2022;\n",
                     "CBO, The Budget and Economic Outlook: 2026 to 2036, February 2026. Phase-in: 70/90/100 percent of steady-state participation in TY2027/28/29.")
  ) +
  theme_eig() +
  guides(color = guide_legend(nrow = 2))

ggsave(file.path(out_dir_fig, "fig1_ten_year_cost_paths.png"), p1,
       width = 9, height = 6, dpi = 200)
cat("Wrote figures/fig1_ten_year_cost_paths.png\n")

# Headline multiples for the brief
cat(sprintf("\nHeadline 10-yr / enacted sec.103 10-yr: %.1fx\n",
            ten_year$cum_fy2027_36_bn[ten_year$scenario == "Headline (59.8 percent take-up)"] /
              jct_window_total))
