# 05a_cost_comparison_figures -- Memo figures for Saver's Match cost memo
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - What does the current-law vs. doubled-threshold cost comparison look like?
#
# DESCRIPTION:
# Builds the two memo figures via ggplot2 using the EIG style tokens.
# Replaces the deprecated Python builder at code/python_port/build_sm_chart.py.
#
#   Figure 1: sm_cost_comparison.png
#     Five-scenario bar chart anchored on the JCT FY2028 score.
#       JCT FY2028 (enacted)              -- official anchor
#       CL DC-only auto-enroll 80%        -- closest to enacted at industry std take-up
#       CL DC-only full participation     -- DC-only upper bound
#       CL universal full participation   -- baseline used elsewhere in memo
#       Doubled universal full participation -- counterfactual
#
#   Figure 2: sm_robustness_grouped.png
#     Grouped bars by participation rate (5.7%, 80%, 100%) showing universal
#     access cost under current-law vs. doubled thresholds.
#
# Inputs:
#   output/tables/main/sm_jct_replication_scenarios.xlsx (produced by 03a)
#   Infrastructure/style/themes/r/eig_tokens.R
#   Infrastructure/style/themes/r/eig_theme.R
#
# Outputs:
#   output/figures/main/sm_cost_comparison.png
#   output/figures/main/sm_robustness_grouped.png
#   output/data/figure_data/sm_cost_comparison_data.csv
#   output/data/figure_data/sm_robustness_grouped_data.csv
#
# 2026-04-26 MIGRATION: numbers consume 03a output, which uses Option B income
# aggregation + U1 spouse-pair income (build_modeled_sipp_frame_v2).

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                              Load Packages                                  ###
###################################################################################
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(readr)
  library(scales)
  library(openxlsx)
})

###################################################################################
###                              Project Paths                                  ###
###################################################################################
# Resolve project root using the same approach as 02a.
project_root <- NA_character_
env_root_chr <- Sys.getenv("EIG_PROJECT_ROOT", unset = NA_character_)
if (!is.na(env_root_chr) && nzchar(env_root_chr) &&
    dir.exists(file.path(env_root_chr, "Infrastructure"))) {
  project_root <- normalizePath(env_root_chr)
}
if (is.na(project_root)) {
  candidate_chr <- normalizePath(getwd())
  while (!dir.exists(file.path(candidate_chr, "Infrastructure")) &&
         candidate_chr != dirname(candidate_chr)) {
    candidate_chr <- dirname(candidate_chr)
  }
  if (dir.exists(file.path(candidate_chr, "Infrastructure"))) {
    project_root <- candidate_chr
  }
}
if (is.na(project_root)) {
  stop(
    "Could not locate repo root. Set EIG_PROJECT_ROOT or setwd() to repo.",
    call. = FALSE
  )
}
message("Using project_root: ", project_root)

path_input_xlsx_chr <- file.path(
  project_root, "output", "tables", "main", "sm_jct_replication_scenarios.xlsx"
)
path_output_fig_main_chr <- file.path(project_root, "output", "figures", "main")
path_output_fig_data_chr <- file.path(project_root, "output", "data", "figure_data")
if (!dir.exists(path_output_fig_main_chr)) {
  dir.create(path_output_fig_main_chr, recursive = TRUE)
}
if (!dir.exists(path_output_fig_data_chr)) {
  dir.create(path_output_fig_data_chr, recursive = TRUE)
}

###################################################################################
###                       Load EIG Tokens and Theme                             ###
###################################################################################
eig_tokens_path_chr <- file.path(
  project_root, "Infrastructure", "style", "themes", "r", "eig_tokens.R"
)
eig_theme_path_chr <- file.path(
  project_root, "Infrastructure", "style", "themes", "r", "eig_theme.R"
)
# Source the tokens file into the calling environment so EIG_COLORS,
# EIG_DISCRETE, and EIG_FONT_* are available as globals for the script.
source(eig_tokens_path_chr)
# Source the theme file so eig_theme_ggplot(), eig_assert_fonts(),
# eig_load_tokens(), eig_scale_fill(), etc. are defined.
source(eig_theme_path_chr)

# eig_theme_ggplot() and eig_assert_fonts() default to looking up tokens at
# the relative path "themes/r/eig_tokens.R", which does not resolve from
# the project root (the canonical file lives under Infrastructure/style/
# themes/r/eig_tokens.R). Build the tokens environment explicitly via
# eig_load_tokens() with the absolute path and pass it to every theme call.
eig_tokens_env <- eig_load_tokens(path = eig_tokens_path_chr)

# Allow font fallback so the script does not error on machines without
# Source Serif Pro / Open Sans installed (Windows R sessions are common
# without these fonts).
fonts_ok_lgl <- tryCatch({
  eig_assert_fonts(tokens = eig_tokens_env, allow_fallback = TRUE)
  TRUE
}, error = function(e) {
  message("Font check failed (proceeding with system defaults): ",
          conditionMessage(e))
  FALSE
})

# Bind the canonical EIG token list as scalars for legibility downstream.
eig_teal_900_hex_chr <- EIG_COLORS[["eig_teal_900"]]    # primary brand dark
eig_blue_800_hex_chr <- EIG_COLORS[["eig_blue_800"]]    # current-law analytic
eig_green_700_hex_chr <- EIG_COLORS[["eig_green_700"]]  # doubled counterfactual
eig_gold_600_hex_chr <- EIG_COLORS[["eig_gold_600"]]    # JCT score (distinct from blue/green)
eig_black_hex_chr <- EIG_COLORS[["eig_black"]]
eig_white_hex_chr <- EIG_COLORS[["eig_white"]]
eig_muted_hex_chr <- "#5A6A7A"

###################################################################################
###                      Load Cost-Scenario Data from 03a                       ###
###################################################################################
# 03a writes "All Scenario Results" as the first sheet of the xlsx. Read it and
# restrict to the columns needed for the figures. If the file is missing, error
# fast with a pointer to the upstream script.

if (!file.exists(path_input_xlsx_chr)) {
  stop(
    "Six-scenario xlsx not found at: ", path_input_xlsx_chr, ". ",
    "Run code/03_cost_simulation/03a_jct_replication.R first.",
    call. = FALSE
  )
}

# 03a writes the "All Scenario Results" sheet with display column names that
# contain spaces and parentheses ("Scenario", "Eligible (M)", "Annual Cost ($M)",
# "JCT FY2028 ($M)"). openxlsx::read.xlsx silently replaces spaces with dots in
# the headers regardless of the check.names argument, so on read these become
# "Eligible.(M)", "Annual.Cost.($M)", etc. The transmute() below references the
# munged names exactly as openxlsx returns them.
scenarios_raw_tbl <- tryCatch(
  openxlsx::read.xlsx(
    path_input_xlsx_chr,
    sheet = "All Scenario Results",
    check.names = FALSE
  ),
  error = function(e) {
    stop(
      "Failed to read 'All Scenario Results' from ", path_input_xlsx_chr, ": ",
      conditionMessage(e),
      ". Verify 03a wrote the workbook with that sheet name.",
      call. = FALSE
    )
  }
)

# Defensive scale check: cost must be in millions (typical range $100-$50,000)
# and eligible counts in millions (typical range 5-100).
scenarios_tbl <- scenarios_raw_tbl |>
  dplyr::transmute(
    scenario_chr     = `Scenario`,
    eligible_M_num   = `Eligible.(M)`,
    cost_M_num       = `Annual.Cost.($M)`,
    cost_B_num       = `Annual.Cost.($M)` / 1000
  )

if (any(scenarios_tbl$cost_M_num > 100000, na.rm = TRUE) ||
    any(scenarios_tbl$cost_M_num < 0, na.rm = TRUE)) {
  stop(
    "Scenario annual_cost_M values out of expected range. ",
    "Inspect ", path_input_xlsx_chr, " for unit-scale issues.",
    call. = FALSE
  )
}
if (any(scenarios_tbl$eligible_M_num > 200, na.rm = TRUE) ||
    any(scenarios_tbl$eligible_M_num < 0, na.rm = TRUE)) {
  stop(
    "Scenario eligible_count_M values out of expected range. ",
    "Inspect ", path_input_xlsx_chr, " for unit-scale issues.",
    call. = FALSE
  )
}

# JCT FY2028 anchor: the first fiscal year with negative revenue under
# JCX-21-22 (effective date tyba 12/31/26). 03a writes this as the
# "JCT FY2028 ($M)" column, which openxlsx::read.xlsx returns as
# "JCT.FY2028.($M)" (see header-munging note above).
jct_fy2028_M_num <- unique(scenarios_raw_tbl[["JCT.FY2028.($M)"]])[1L]
if (!is.finite(jct_fy2028_M_num)) {
  stop("JCT anchor scalar not found in xlsx; check 03a output.", call. = FALSE)
}

message("Loaded ", nrow(scenarios_tbl), " analytic scenarios from 03a.")

###################################################################################
###                       Build Figure 1: Five-Scenario Bars                    ###
###################################################################################
# Five bars in display order:
#   1) JCT FY2028 score (enacted)        - gold
#   2) CL DC-only auto-enroll 80%        - blue
#   3) CL DC-only full participation     - blue
#   4) CL universal full participation   - blue (baseline)
#   5) Doubled universal full participation - green

# Helper lookup -- pull a row by scenario name.
get_cost <- function(name_chr) {
  row_idx_int <- which(scenarios_tbl$scenario_chr == name_chr)
  if (length(row_idx_int) != 1L) {
    stop("Scenario not found in xlsx: ", name_chr, call. = FALSE)
  }
  scenarios_tbl[row_idx_int, ]
}

cl_dc_auto_row <- get_cost("auto_enroll")
cl_dc_full_row <- get_cost("full_participation_dc")
# Renamed 2026-05-08 per spec 2026-05-08_four-multiplier-contrast.md:
# universal_access -> universal_m100; universal_doubled -> universal_m200.
cl_univ_row <- get_cost("universal_m100")
doubled_univ_row <- get_cost("universal_m200")

# DC-only eligible count is the same across DC-only scenarios (8.88M post-Option B).
dc_elig_M_num <- cl_dc_full_row$eligible_M_num

fig1_tbl <- dplyr::tibble(
  panel_order_int = 1:5,
  label_chr = c(
    "JCT FY2028 score\n(current-law, enacted)",
    "Current law, DC-only,\nauto-enroll (80%)",
    "Current law, DC-only,\nfull participation",
    "Current law, universal,\nfull participation",
    "Doubled thresholds, universal,\nfull participation"
  ),
  eligible_M_num = c(
    dc_elig_M_num,
    cl_dc_auto_row$eligible_M_num,
    cl_dc_full_row$eligible_M_num,
    cl_univ_row$eligible_M_num,
    doubled_univ_row$eligible_M_num
  ),
  cost_M_num = c(
    jct_fy2028_M_num,
    cl_dc_auto_row$cost_M_num,
    cl_dc_full_row$cost_M_num,
    cl_univ_row$cost_M_num,
    doubled_univ_row$cost_M_num
  ),
  group_chr = c("jct", "cl", "cl", "cl", "2x")
) |>
  dplyr::mutate(
    cost_B_num = cost_M_num / 1000,
    annotation_chr = sprintf("$%.1fB\n%.1fM eligible",
                             cost_B_num, eligible_M_num),
    label_factor = factor(label_chr, levels = label_chr)
  )

fig1_palette_chr <- c(
  "jct" = eig_gold_600_hex_chr,
  "cl"  = eig_blue_800_hex_chr,
  "2x"  = eig_green_700_hex_chr
)

fig1_legend_levels_chr <- c(
  "jct" = "Official JCT provision score (fiscal year)",
  "cl"  = "Current-law analytic scenarios",
  "2x"  = "Doubled-threshold counterfactual"
)

fig1_data_legend_tbl <- fig1_tbl |>
  dplyr::mutate(group_label_chr = factor(
    fig1_legend_levels_chr[group_chr],
    levels = unname(fig1_legend_levels_chr)
  ))

fig1_caption_chr <- paste0(
  "Source: EIG simulation on SIPP 2024 microdata projected to tax year 2027; ",
  "JCT JCX-21-22 for the enacted-program score.\n",
  "Note: Costs are annual. Eligible population is worker-level and weighted by SIPP final person weights."
)

fig1_plot <- ggplot2::ggplot(
  fig1_data_legend_tbl,
  ggplot2::aes(x = label_factor, y = cost_B_num, fill = group_label_chr)
) +
  ggplot2::geom_col(width = 0.62, color = eig_black_hex_chr, linewidth = 0.3) +
  ggplot2::geom_text(
    ggplot2::aes(label = annotation_chr),
    vjust = -0.2,
    size = 3.0,
    color = eig_black_hex_chr,
    lineheight = 0.95
  ) +
  ggplot2::scale_fill_manual(
    values = setNames(unname(fig1_palette_chr), unname(fig1_legend_levels_chr)),
    name = NULL
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::label_dollar(suffix = "B"),
    expand = ggplot2::expansion(mult = c(0, 0.18))
  ) +
  ggplot2::labs(
    title = "Figure 1. Saver's Match one-year cost under alternative designs",
    subtitle = "Annual TY2027 cost in USD (billions); workers eligible above each bar",
    x = NULL,
    y = "Annual cost (USD, billions)",
    caption = fig1_caption_chr
  ) +
  eig_theme_ggplot(tokens = eig_tokens_env, base_size = 10) +
  ggplot2::theme(
    legend.position = "top",
    legend.justification = "left",
    legend.box.margin = ggplot2::margin(0, 0, 0, -10),
    axis.text.x = ggplot2::element_text(size = 9, color = eig_black_hex_chr),
    axis.text.y = ggplot2::element_text(size = 9),
    plot.caption = ggplot2::element_text(
      size = 8, color = eig_muted_hex_chr, hjust = 0, lineheight = 1.15
    ),
    plot.subtitle = ggplot2::element_text(
      size = 10, color = eig_muted_hex_chr, face = "plain"
    )
  )

# Save figure and the underlying data
fig1_out_chr <- file.path(path_output_fig_main_chr,
                          "sm_cost_comparison.png")
ggplot2::ggsave(
  filename = fig1_out_chr,
  plot = fig1_plot,
  width = 9.5,
  height = 5.6,
  dpi = 300,
  bg = "white"
)
message("Saved figure: ", fig1_out_chr)

fig1_csv_chr <- file.path(path_output_fig_data_chr,
                          "sm_cost_comparison_data.csv")
readr::write_csv(
  fig1_tbl |>
    dplyr::select(panel_order_int, label_chr, group_chr,
                  eligible_M_num, cost_M_num, cost_B_num),
  fig1_csv_chr
)
message("Saved data:   ", fig1_csv_chr)

###################################################################################
###            Build Figure 2: Grouped Bars by Participation Rate                ###
###################################################################################
# Six bars in three groups (CL universal vs 2X universal under three
# participation assumptions: 5.7% floor, 80% auto-enroll, 100% full).

cl_no_auto_row <- get_cost("no_auto")          # CL DC-only at 5.7%; we want CL universal at 5.7%
# 03a does not publish a CL universal at 5.7% scenario by default. The
# universal_m100 scenario is full-participation only. To approximate the
# 5.7% universal point we scale universal_m100 cost by 5.7% (the IRS
# Saver's Credit utilization rate), keeping the universal eligible
# population fixed. This mirrors what the prior Python figure script did.
# (Renamed from universal_access 2026-05-08; see spec
# 2026-05-08_four-multiplier-contrast.md.)
takeup_no_auto_num <- 0.057
takeup_auto_enroll_num <- 0.80

cl_univ_5pct_cost_M_num <- cl_univ_row$cost_M_num * takeup_no_auto_num
cl_univ_80pct_cost_M_num <- cl_univ_row$cost_M_num * takeup_auto_enroll_num
doubled_univ_5pct_cost_M_num <- doubled_univ_row$cost_M_num * takeup_no_auto_num
doubled_univ_80pct_cost_M_num <- doubled_univ_row$cost_M_num * takeup_auto_enroll_num

fig2_tbl <- dplyr::tibble(
  participation_chr = rep(c(
    "No auto-enrollment\n(5.7% takeup)",
    "Auto-enrollment\n(80%)",
    "Full participation\n(upper bound)"
  ), each = 2L),
  design_chr = rep(c("Current-law thresholds", "Doubled thresholds"), times = 3L),
  cost_M_num = c(
    cl_univ_5pct_cost_M_num,    doubled_univ_5pct_cost_M_num,
    cl_univ_80pct_cost_M_num,   doubled_univ_80pct_cost_M_num,
    cl_univ_row$cost_M_num,     doubled_univ_row$cost_M_num
  )
) |>
  dplyr::mutate(
    cost_B_num = cost_M_num / 1000,
    annotation_chr = sprintf("$%.1fB", cost_B_num),
    participation_factor = factor(
      participation_chr,
      levels = c(
        "No auto-enrollment\n(5.7% takeup)",
        "Auto-enrollment\n(80%)",
        "Full participation\n(upper bound)"
      )
    ),
    design_factor = factor(
      design_chr,
      levels = c("Current-law thresholds", "Doubled thresholds")
    )
  )

fig2_caption_chr <- paste0(
  "Source: EIG simulation on SIPP 2024 microdata projected to tax year 2027. ",
  "Current-law thresholds per SECURE 2.0 \u00a7103. Doubled-threshold counterfactual: ",
  "2x current-law filer AGI thresholds across all filing statuses, $1,000 cap retained.\n",
  "Note: The 5.7% and 80% bars scale the full-participation universal-access ",
  "cost by the IRS Saver's Credit utilization rate (5.7%) and the Vanguard ",
  "How-America-Saves auto-enrollment standard (80%) respectively, holding the ",
  "income-eligible universal population fixed."
)

fig2_plot <- ggplot2::ggplot(
  fig2_tbl,
  ggplot2::aes(
    x = participation_factor,
    y = cost_B_num,
    fill = design_factor
  )
) +
  ggplot2::geom_col(
    position = ggplot2::position_dodge(width = 0.78),
    width = 0.66,
    color = eig_black_hex_chr,
    linewidth = 0.3
  ) +
  ggplot2::geom_text(
    ggplot2::aes(label = annotation_chr),
    position = ggplot2::position_dodge(width = 0.78),
    vjust = -0.4,
    size = 3.1,
    color = eig_black_hex_chr
  ) +
  ggplot2::scale_fill_manual(
    values = c(
      "Current-law thresholds" = eig_blue_800_hex_chr,
      "Doubled thresholds"     = eig_green_700_hex_chr
    ),
    name = NULL
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::label_dollar(suffix = "B"),
    expand = ggplot2::expansion(mult = c(0, 0.15))
  ) +
  ggplot2::labs(
    title = "Figure 2. Annual Saver's Match cost under universal access, by participation",
    subtitle = "Current-law versus doubled-threshold designs at three take-up rates",
    x = NULL,
    y = "Annual cost (USD, billions)",
    caption = fig2_caption_chr
  ) +
  eig_theme_ggplot(tokens = eig_tokens_env, base_size = 10) +
  ggplot2::theme(
    legend.position = "top",
    legend.justification = "left",
    legend.box.margin = ggplot2::margin(0, 0, 0, -10),
    axis.text.x = ggplot2::element_text(size = 9, color = eig_black_hex_chr),
    axis.text.y = ggplot2::element_text(size = 9),
    plot.caption = ggplot2::element_text(
      size = 8, color = eig_muted_hex_chr, hjust = 0, lineheight = 1.15
    ),
    plot.subtitle = ggplot2::element_text(
      size = 10, color = eig_muted_hex_chr, face = "plain"
    )  )

fig2_out_chr <- file.path(path_output_fig_main_chr,
                          "sm_robustness_grouped.png")
ggplot2::ggsave(
  filename = fig2_out_chr,
  plot = fig2_plot,
  width = 9.0,
  height = 5.0,
  dpi = 300,
  bg = "white"
)
message("Saved figure: ", fig2_out_chr)

fig2_csv_chr <- file.path(path_output_fig_data_chr,
                          "sm_robustness_grouped_data.csv")
readr::write_csv(
  fig2_tbl |>
    dplyr::select(participation_chr, design_chr, cost_M_num, cost_B_num),
  fig2_csv_chr
)
message("Saved data:   ", fig2_csv_chr)

message("05a_cost_comparison_figures.R complete.")
