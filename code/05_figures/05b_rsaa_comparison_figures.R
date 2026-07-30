# 05b_rsaa_comparison_figures -- Generosity comparison: Universal Saver's Match (hybrid) vs RSAA.
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - How does per-worker generosity of the hybrid compare with RSAA (S.1526) across
#                     the income distribution, holding contribution at the 3% auto-default?
#
# Inputs:
#   output/data/figure_data/rsaa_vs_hybrid_generosity.csv   (produced by 03d_rsaa_comparison.R)
#   output/tables/rsaa_comparison/rsaa_vs_hybrid_cost_coverage_ladder.csv
#   Infrastructure/style/themes/r/eig_tokens.R + eig_theme.R
# Outputs:
#   output/figures/main/rsaa_vs_hybrid_generosity.png       (per-worker credit vs income, by filing status)
#   output/figures/main/rsaa_vs_hybrid_cost_ladder.png      (annual cost by participation rung)

rm(list = ls())
options(scipen = 999)
set.seed(42L)

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(ggplot2); library(readr); library(scales)
})

# --- project root (mirror 05a) ---
project_root <- Sys.getenv("EIG_PROJECT_ROOT", unset = NA_character_)
if (is.na(project_root) || !nzchar(project_root) || !dir.exists(file.path(project_root, "Infrastructure"))) {
  cur <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  while (!file.exists(file.path(cur, "PROJECT.md")) && dirname(cur) != cur) cur <- dirname(cur)
  project_root <- cur
}
project_root <- normalizePath(project_root, winslash = "/", mustWork = TRUE)

eig_tokens_path_chr <- file.path(project_root, "Infrastructure", "style", "themes", "r", "eig_tokens.R")
eig_theme_path_chr  <- file.path(project_root, "Infrastructure", "style", "themes", "r", "eig_theme.R")
source(eig_tokens_path_chr)
source(eig_theme_path_chr)
eig_tokens_env <- eig_load_tokens(path = eig_tokens_path_chr)
fonts_ok <- tryCatch({ eig_assert_fonts(tokens = eig_tokens_env, allow_fallback = TRUE); TRUE },
                     error = function(e) FALSE)

hybrid_hex <- EIG_COLORS[["eig_blue_800"]]   # Universal Saver's Match (hybrid)
rsaa_hex   <- EIG_COLORS[["eig_gold_600"]]   # RSAA (S.1526)
black_hex  <- EIG_COLORS[["eig_black"]]

fig_dir <- file.path(project_root, "output", "figures", "main")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# Figure 1: per-worker credit vs income, faceted by filing status
# ---------------------------------------------------------------------------
gen <- read_csv(file.path(project_root, "output", "data", "figure_data", "rsaa_vs_hybrid_generosity.csv"),
                show_col_types = FALSE)
# Headline generosity figure is restricted to SINGLE filers, where the individual income
# concept coincides for both designs. (For HoH/MFJ the x-axis would conflate two income
# concepts: RSAA §25F keys the credit to INDIVIDUAL gross income even for joint filers, while
# the hybrid keys to JOINT MAGI. Those filing-status differences are captured in the aggregate
# cost/coverage tables, not this schedule figure. The full-status curve data is in the CSV.)
gen_single <- gen |>
  filter(filing_status == "Single") |>
  select(income, hybrid_credit, rsaa_credit) |>
  pivot_longer(c(hybrid_credit, rsaa_credit), names_to = "design", values_to = "credit") |>
  mutate(design = recode(design,
                         hybrid_credit = "Universal Saver's Match (hybrid)",
                         rsaa_credit   = "RSAA (S.1526)"))

p1 <- ggplot(gen_single, aes(income, credit, color = design)) +
  geom_line(linewidth = 1.1) +
  scale_color_manual(values = c("Universal Saver's Match (hybrid)" = hybrid_hex,
                                "RSAA (S.1526)" = rsaa_hex), name = NULL) +
  scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "k"),
                     breaks = seq(0, 90000, 15000), limits = c(0, 90000)) +
  scale_y_continuous(labels = label_dollar()) +
  labs(
    title = "Figure 1. For a single filer, RSAA pays more above about $14,000",
    subtitle = "Annual federal credit per single worker at a 3 percent contribution (TY2027 dollars)",
    x = "Worker income", y = "Federal credit per worker",
    caption = paste0("Source: EIG analysis of SIPP 2024 projected to TY2027.\n",
                     "Hybrid: MAGI-linear match (200% floor), $1,000 cap. RSAA: S.1526 §25F, capped at 5% of the phaseout amount.")
  ) +
  eig_theme_ggplot(tokens = eig_tokens_env, base_size = 11) +
  theme(legend.position = "top",
        plot.caption = element_text(size = 7, color = black_hex, hjust = 0),
        plot.subtitle = element_text(size = 10))

ggsave(file.path(fig_dir, "rsaa_vs_hybrid_generosity.png"), p1,
       width = 9, height = 5, dpi = 300, bg = "white")

# ---------------------------------------------------------------------------
# Figure 2: annual cost by participation rung
# ---------------------------------------------------------------------------
lad <- read_csv(file.path(project_root, "output", "tables", "rsaa_comparison",
                          "rsaa_vs_hybrid_cost_coverage_ladder.csv"), show_col_types = FALSE)
lad <- lad |>
  mutate(
    rung = recode(scenario,
                  sipp_observed_conditional = "SIPP-observed (~59%)",
                  auto_enroll_80pct = "Auto-enroll (80%)",
                  full_participation_100pct = "Full (100%)"),
    rung = factor(rung, levels = c("SIPP-observed (~59%)", "Auto-enroll (80%)", "Full (100%)")),
    cost_B = annual_cost_M / 1e3
  )

p2 <- ggplot(lad, aes(rung, cost_B, fill = design)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.62) +
  geom_text(aes(label = label_dollar(accuracy = 0.1, suffix = "B")(cost_B)),
            position = position_dodge(width = 0.7), vjust = -0.4, size = 3) +
  scale_fill_manual(values = c("Universal Saver's Match (hybrid)" = hybrid_hex,
                               "RSAA (S.1526)" = rsaa_hex), name = NULL) +
  scale_y_continuous(labels = label_dollar(suffix = "B"), expand = expansion(mult = c(0, 0.12))) +
  labs(
    title = "Figure 2. On the same SIPP universe, RSAA costs roughly 2.7 times the hybrid",
    subtitle = "Annual federal outlay, TY2027, by participation assumption (3% contribution held fixed for both)",
    x = NULL, y = "Annual cost",
    caption = "Source: EIG analysis of SIPP 2024 projected to TY2027. Hybrid figures from the 04 hybrid pipeline; RSAA from 03d."
  ) +
  eig_theme_ggplot(tokens = eig_tokens_env, base_size = 10) +
  theme(legend.position = "top",
        plot.caption = element_text(size = 7, color = black_hex),
        plot.subtitle = element_text(size = 9))

ggsave(file.path(fig_dir, "rsaa_vs_hybrid_cost_ladder.png"), p2,
       width = 8, height = 5, dpi = 300, bg = "white")

message("05b complete. Fonts ok: ", fonts_ok)
message("  Wrote rsaa_vs_hybrid_generosity.png and rsaa_vs_hybrid_cost_ladder.png to ", fig_dir)
