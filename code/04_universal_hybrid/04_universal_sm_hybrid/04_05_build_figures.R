# 04_05_build_figures -- Match-rate curve and distributional incidence charts
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - How does the hybrid match-rate schedule compare visually to the current-law
#                     50-percent-flat-with-phaseout schedule, and how does the match dollar fall
#                     across income deciles?
#
# DESCRIPTION:
# Build the hybrid figures using EIG style tokens (loaded the same way as 04a):
#   1. match_rate_by_magi.png        -- hybrid schedule by filing group + current-law overlay
#   2. incidence_by_decile.png       -- share of match dollars by MAGI decile
#   3. universe_funnel.png           -- weighted N at each universe filter step
#   4. universe_magi_distribution.png -- weighted MAGI distribution (diagnostic)
#   5. incidence_seed_vs_match.png   -- federal dollars by decile: match vs. $100 seed
#   6. seed_variant_schedules.png    -- seed amount by MAGI: flat vs. phased variants
#
# Inputs:
#   data/processed/universal_sm_hybrid/pivot_table.rds
#   data/processed/universal_sm_hybrid/simulation_results.parquet
#   output/reports/universal_sm_hybrid/universe_funnel.csv
#   Infrastructure/style/themes/r/eig_tokens.R
#   Infrastructure/style/themes/r/eig_theme.R
# Outputs:
#   output/figures/universal_sm_hybrid/match_rate_by_magi.png
#   output/figures/universal_sm_hybrid/incidence_by_decile.png
#   output/figures/universal_sm_hybrid/universe_funnel.png
#   output/figures/universal_sm_hybrid/universe_magi_distribution.png
#   output/figures/universal_sm_hybrid/incidence_seed_vs_match.png
#   output/figures/universal_sm_hybrid/seed_variant_schedules.png

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                              Load Packages                                  ###
###################################################################################
suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(arrow)
  library(ggplot2)
  library(scales)
})

###################################################################################
###                            Project Root Resolution                          ###
###################################################################################
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
  frames_list <- sys.frames()
  sourced_path_chr <- NA_character_
  for (i in rev(seq_along(frames_list))) {
    ofile_candidate <- frames_list[[i]]$ofile
    if (!is.null(ofile_candidate) && is.character(ofile_candidate) &&
        nzchar(ofile_candidate)) {
      sourced_path_chr <- ofile_candidate
      break
    }
  }
  if (!is.na(sourced_path_chr)) {
    candidate_chr <- normalizePath(dirname(sourced_path_chr))
    while (!dir.exists(file.path(candidate_chr, "Infrastructure")) &&
           candidate_chr != dirname(candidate_chr)) {
      candidate_chr <- dirname(candidate_chr)
    }
    if (dir.exists(file.path(candidate_chr, "Infrastructure"))) {
      project_root <- candidate_chr
    }
  }
}
if (is.na(project_root)) {
  stop("Could not locate repo root. Set EIG_PROJECT_ROOT or setwd().", call. = FALSE)
}
message("Using project_root: ", project_root)

source(file.path(project_root, "code", "_shared", "calibration_cells.R"))
source(file.path(project_root, "code", "_shared", "params.R"))

###################################################################################
###                         Configuration and Paths                             ###
###################################################################################
path_data_processed_chr  <- file.path(project_root, "data", "processed", "universal_sm_hybrid")
path_output_figs_chr     <- file.path(project_root, "output", "figures", "universal_sm_hybrid")
path_output_reports_chr  <- file.path(project_root, "output", "reports", "universal_sm_hybrid")
path_output_fig_data_chr <- file.path(project_root, "output", "data", "figure_data")
if (!dir.exists(path_output_figs_chr))     dir.create(path_output_figs_chr,     recursive = TRUE)
if (!dir.exists(path_output_fig_data_chr)) dir.create(path_output_fig_data_chr, recursive = TRUE)

###################################################################################
###                       Load EIG Tokens and Theme                             ###
###################################################################################
eig_tokens_path_chr <- file.path(project_root, "Infrastructure", "style", "themes", "r", "eig_tokens.R")
eig_theme_path_chr  <- file.path(project_root, "Infrastructure", "style", "themes", "r", "eig_theme.R")
source(eig_tokens_path_chr)
source(eig_theme_path_chr)
eig_tokens_env <- eig_load_tokens(path = eig_tokens_path_chr)
fonts_ok_lgl <- tryCatch({
  eig_assert_fonts(tokens = eig_tokens_env, allow_fallback = TRUE)
  TRUE
}, error = function(e) {
  message("EIG font assertion failed; falling back to system fonts. Error: ", conditionMessage(e))
  FALSE
})

# Pull series colors from the EIG token palette rather than hard-coding hex, so
# the figures track the canonical palette if it is updated (matches 04_06's pattern).
eig_green_700_chr <- eig_tokens_env$EIG_COLORS[["eig_green_700"]]   # #19644D
eig_gold_600_chr  <- eig_tokens_env$EIG_COLORS[["eig_gold_600"]]    # #E1AD28
eig_teal_900_chr  <- eig_tokens_env$EIG_COLORS[["eig_teal_900"]]
eig_cyan_700_chr  <- eig_tokens_env$EIG_COLORS[["eig_cyan_700"]]

###################################################################################
###                       1) Load Pivots and Simulation                         ###
###################################################################################
pivot_obj_list    <- readRDS(file.path(path_data_processed_chr, "pivot_table.rds"))
sm_pivot_2024_num <- pivot_obj_list$pivot_vec_num
simulation_tbl    <- read_parquet(file.path(path_data_processed_chr, "simulation_results.parquet"))

# Schedule parameters the pivots were derived under (set in 04_02; see
# 04_03 for the same guard). The figures draw the schedule and its endpoints
# from these so they track any change to the max match rate automatically.
schedule_params_list <- pivot_obj_list$schedule_params_list
if (is.null(schedule_params_list) ||
    is.null(schedule_params_list$max_rate_pp_num) ||
    is.null(schedule_params_list$pivot_rate_pp_num)) {
  stop("pivot_table.rds has no schedule_params_list (pre-parameterization vintage). ",
       "Rerun 04_02_compute_pivots.R to regenerate it.", call. = FALSE)
}
max_rate_pp_num     <- schedule_params_list$max_rate_pp_num
pivot_rate_pp_num   <- schedule_params_list$pivot_rate_pp_num
# Endpoint multiple of the pivot: R_max / (R_max - R_p); 4/3 at the defaults.
endpoint_factor_num <- max_rate_pp_num / (max_rate_pp_num - pivot_rate_pp_num)

###################################################################################
###             2) Figure 1: Match-Rate-by-MAGI Schedule                        ###
###################################################################################
# Grid runs to $90K -- just past the widest phase-down (MFJ endpoint ~$86K
# under the 75%@two-thirds-median IRS-anchored design), so the x-axis ends where
# the match rate has reached 0 for every filing group without trailing dead space.
magi_grid_num <- seq(0, 90000, by = 500)

schedule_rows_list <- list()
for (g in names(sm_pivot_2024_num)) {
  hybrid_rate_pp_num <- compute_match_rate(
    magi_num          = magi_grid_num,
    filing_group_chr  = rep(g, length(magi_grid_num)),
    pivot_table       = sm_pivot_2024_num,
    max_rate_pp_num   = max_rate_pp_num,
    pivot_rate_pp_num = pivot_rate_pp_num
  )
  schedule_rows_list[[g]] <- data.frame(
    filing_group_chr  = g,
    magi_num          = magi_grid_num,
    schedule_chr      = "Expanded Policy",
    match_rate_pp_num = hybrid_rate_pp_num,
    stringsAsFactors  = FALSE
  )
}

# Current-law schedule overlay (constant 50% below sm_lower, linear phaseout
# to 0 at sm_upper). Use the existing sm_lower / sm_upper constants.
sm_constants <- sm_calibration_constants()
sm_lower_num <- sm_constants$sm_lower
sm_upper_num <- sm_constants$sm_upper

filing_to_constant_chr <- c(single_mfs = "Single", mfj = "MFJ", hoh = "HoH")
for (g in names(sm_pivot_2024_num)) {
  key_chr  <- filing_to_constant_chr[g]
  low_num  <- sm_lower_num[[key_chr]]
  high_num <- sm_upper_num[[key_chr]]
  cur_law_rate_pp_num <- dplyr::case_when(
    magi_grid_num <= low_num                 ~ 50,
    magi_grid_num > low_num &
      magi_grid_num < high_num               ~ 50 * (high_num - magi_grid_num) / (high_num - low_num),
    TRUE                                      ~ 0
  )
  schedule_rows_list[[paste0("cur_law_", g)]] <- data.frame(
    filing_group_chr  = g,
    magi_num          = magi_grid_num,
    schedule_chr      = "Saver's Match",
    match_rate_pp_num = cur_law_rate_pp_num,
    stringsAsFactors  = FALSE
  )
}

schedule_tbl <- dplyr::bind_rows(schedule_rows_list)

schedule_csv_path_chr <- file.path(path_output_fig_data_chr, "universal_sm_hybrid_match_rate_schedule.csv")
write_csv(schedule_tbl, schedule_csv_path_chr)

filing_group_labels_chr <- c(single_mfs = "Single / MFS", mfj = "MFJ", hoh = "HoH")
schedule_tbl <- schedule_tbl |>
  dplyr::mutate(
    filing_group_label_chr = factor(
      filing_group_labels_chr[filing_group_chr],
      # Facet order left -> right: Single, HoH, MFJ.
      levels = c("Single / MFS", "HoH", "MFJ")
    ),
    # Order the legend with the focal series (Expanded Policy) first.
    schedule_chr = factor(schedule_chr, levels = c("Expanded Policy", "Saver's Match"))
  )

fig1_gg <- ggplot2::ggplot(schedule_tbl, ggplot2::aes(
  x = magi_num, y = match_rate_pp_num,
  color = schedule_chr, linetype = schedule_chr
)) +
  ggplot2::geom_line(linewidth = 1.0) +
  ggplot2::facet_wrap(~ filing_group_label_chr, ncol = 3L) +
  ggplot2::scale_color_manual(values = c("Expanded Policy" = eig_green_700_chr,
                                          "Saver's Match"   = eig_gold_600_chr)) +
  ggplot2::scale_linetype_manual(values = c("Expanded Policy" = "solid",
                                             "Saver's Match"   = "dashed")) +
  ggplot2::scale_x_continuous(labels = scales::dollar_format(),
                              limits = c(0, 90000)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%"),
                               breaks = seq(0, max_rate_pp_num, by = 50)) +
  ggplot2::labs(
    x = "MAGI (TY2027 dollars)",
    y = "Match rate (%)",
    color = NULL, linetype = NULL,
    title = "Figure 1. Match rate by MAGI: Expanded Policy vs. current Saver's Match",
    subtitle = sprintf(paste0("Expanded Policy: a single straight line per filing group — %d%% at $0 MAGI, ",
                              "declining to 0%% at %.2f × pivot; Single rate is %d%% at two-thirds the IRS single-filer median"),
                       round(max_rate_pp_num, 0L), endpoint_factor_num,
                       round(schedule_params_list$anchor_rate_pp_num, 0L)),
    caption = "Source: Author's analysis of SIPP 2024 Wave 1."
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    legend.position    = "bottom",
    panel.grid.minor   = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    plot.title         = ggplot2::element_text(face = "bold"),
    plot.subtitle      = ggplot2::element_text(size = 9, color = "#444444")
  )

fig1_png_path_chr <- file.path(path_output_figs_chr, "match_rate_by_magi.png")
ggplot2::ggsave(fig1_png_path_chr, fig1_gg,
                width = 10, height = 5, dpi = 300, units = "in")
message("Wrote: ", fig1_png_path_chr)

###################################################################################
###             3) Figure 2: Distributional Incidence by Decile                 ###
###################################################################################
# Deciles are defined over the FULL analysis universe (eligible + ineligible),
# not the eligible sub-population, so this figure shares one denominator with the
# brief's "share to the lowest-earning deciles" statistic and with 04_04's
# pooled_universe_deciles sheet. Ineligible workers carry a $0 match (zero-filled),
# so the high deciles read as ~0 -- which is the policy-reach story the brief tells.
universe_inc_tbl <- simulation_tbl |>
  dplyr::filter(!is.na(magi_num)) |>
  dplyr::arrange(magi_num) |>
  dplyr::mutate(
    cum_wgt_num     = cumsum(WPFINWGT),
    total_wgt_num   = sum(WPFINWGT, na.rm = TRUE),
    magi_pct_num    = cum_wgt_num / total_wgt_num,
    magi_decile_int = pmin(10L, floor(magi_pct_num * 10) + 1L),
    match_dollars_zerofill_num = dplyr::if_else(is.na(match_per_worker_num), 0, match_per_worker_num)
  )

incidence_tbl <- universe_inc_tbl |>
  dplyr::group_by(magi_decile_int) |>
  dplyr::summarise(
    total_match_dollars_M_num = sum(match_dollars_zerofill_num * WPFINWGT, na.rm = TRUE) / 1e6,
    .groups = "drop"
  ) |>
  dplyr::mutate(share_num = total_match_dollars_M_num / sum(total_match_dollars_M_num))

incidence_csv_path_chr <- file.path(path_output_fig_data_chr, "universal_sm_hybrid_incidence_by_decile.csv")
write_csv(incidence_tbl, incidence_csv_path_chr)

fig2_gg <- ggplot2::ggplot(incidence_tbl,
                            ggplot2::aes(x = factor(magi_decile_int),
                                         y = share_num)) +
  ggplot2::geom_col(fill = eig_green_700_chr) +
  ggplot2::scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  ggplot2::labs(
    x = "Income decile across the full workforce (1 = lowest, 10 = highest)",
    y = "Share of full-participation match dollars",
    title = "Figure 2. Distributional incidence of the hybrid Saver's Match",
    subtitle = "Deciles defined over the entire analysis universe; ineligible workers carry a $0 match",
    caption = "Source: Author's analysis of SIPP 2024 Wave 1."
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    panel.grid.minor   = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    plot.title         = ggplot2::element_text(face = "bold")
  )

fig2_png_path_chr <- file.path(path_output_figs_chr, "incidence_by_decile.png")
ggplot2::ggsave(fig2_png_path_chr, fig2_gg,
                width = 8, height = 5, dpi = 300, units = "in")
message("Wrote: ", fig2_png_path_chr)

###################################################################################
###   3b) Figure 5: Federal Dollars by Decile -- Match vs. Automatic $100 Seed  ###
###################################################################################
# Same full-universe deciles as Figure 2. The seed ($100 to every eligible
# worker, paid regardless of participation) is stacked on the full-participation
# match dollars, so each bar decomposes total federal dollars into the two
# instruments. The seed's flat per-person structure makes it relatively most
# important exactly where match dollars are smallest.
seed_match_decile_tbl <- universe_inc_tbl |>
  dplyr::group_by(magi_decile_int) |>
  dplyr::summarise(
    match_dollars_B_num = sum(match_dollars_zerofill_num * WPFINWGT, na.rm = TRUE) / 1e9,
    seed_dollars_B_num  = sum(seed_per_worker_num * WPFINWGT, na.rm = TRUE) / 1e9,
    .groups = "drop"
  )

seed_match_csv_path_chr <- file.path(path_output_fig_data_chr,
                                     "universal_sm_hybrid_incidence_seed_vs_match.csv")
write_csv(seed_match_decile_tbl, seed_match_csv_path_chr)

seed_match_long_tbl <- seed_match_decile_tbl |>
  tidyr::pivot_longer(cols = c(match_dollars_B_num, seed_dollars_B_num),
                      names_to = "component_chr", values_to = "dollars_B_num") |>
  dplyr::mutate(
    component_lbl_chr = factor(
      dplyr::if_else(component_chr == "match_dollars_B_num",
                     "Match dollars", "Automatic $100 seed"),
      # Stack order: seed on top of match.
      levels = c("Automatic $100 seed", "Match dollars")
    )
  )

fig5_gg <- ggplot2::ggplot(seed_match_long_tbl,
                           ggplot2::aes(x = factor(magi_decile_int),
                                        y = dollars_B_num,
                                        fill = component_lbl_chr)) +
  ggplot2::geom_col(position = "stack") +
  ggplot2::scale_fill_manual(values = c("Match dollars"       = eig_green_700_chr,
                                        "Automatic $100 seed" = eig_gold_600_chr)) +
  ggplot2::scale_y_continuous(labels = scales::dollar_format(suffix = "B", accuracy = 0.5)) +
  ggplot2::labs(
    x = "Income decile across the full workforce (1 = lowest, 10 = highest)",
    y = "Federal dollars (billions, TY2027)",
    fill = NULL,
    title = "Figure 5. Federal dollars by income decile: match vs. automatic $100 seed",
    subtitle = "Full-participation match dollars plus a $100 automatic contribution to every eligible worker, contributing or not",
    caption = "Source: Author's analysis of SIPP 2024 Wave 1."
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    legend.position    = "bottom",
    panel.grid.minor   = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    plot.title         = ggplot2::element_text(face = "bold"),
    plot.subtitle      = ggplot2::element_text(size = 9, color = "#444444")
  )

fig5_png_path_chr <- file.path(path_output_figs_chr, "incidence_seed_vs_match.png")
ggplot2::ggsave(fig5_png_path_chr, fig5_gg,
                width = 8, height = 5, dpi = 300, units = "in")
message("Wrote: ", fig5_png_path_chr)

###################################################################################
###     3c) Figure 6: Seed Amount by MAGI -- Flat vs. Phased Variants           ###
###################################################################################
# Single-filer geometry of the four seed designs (see 04_03 Section 4b / params.R).
# The flat design has a cliff at the endpoint; the three phased variants remove
# it in different ways.
seed_amount_num     <- sm_params()$auto_seed_amount
seed_ext_mult_num   <- sm_params()$seed_extended_endpoint_mult
single_pivot_num    <- sm_pivot_2024_num[["single_mfs"]]
single_endpoint_num <- endpoint_factor_num * single_pivot_num
seed_grid_num       <- seq(0, ceiling(seed_ext_mult_num * single_endpoint_num / 1000) * 1000,
                           by = 250)

seed_variant_lines_tbl <- dplyr::bind_rows(
  data.frame(
    variant_chr = "Flat $100 (headline)",
    magi_num    = seed_grid_num,
    seed_num    = ifelse(seed_grid_num < single_endpoint_num, seed_amount_num, 0)
  ),
  data.frame(
    variant_chr = "Pro-rata with match rate",
    magi_num    = seed_grid_num,
    seed_num    = seed_amount_num *
      compute_match_rate(
        magi_num          = seed_grid_num,
        filing_group_chr  = rep("single_mfs", length(seed_grid_num)),
        pivot_table       = sm_pivot_2024_num,
        max_rate_pp_num   = max_rate_pp_num,
        pivot_rate_pp_num = pivot_rate_pp_num
      ) / max_rate_pp_num
  ),
  data.frame(
    variant_chr = "Flat, then taper",
    magi_num    = seed_grid_num,
    seed_num    = ifelse(
      seed_grid_num <= single_pivot_num, seed_amount_num,
      pmax(0, seed_amount_num * (single_endpoint_num - seed_grid_num) /
                (single_endpoint_num - single_pivot_num))
    )
  ),
  data.frame(
    variant_chr = "Extended taper",
    magi_num    = seed_grid_num,
    seed_num    = ifelse(
      seed_grid_num < single_endpoint_num, seed_amount_num,
      pmax(0, seed_amount_num * (seed_ext_mult_num * single_endpoint_num - seed_grid_num) /
                ((seed_ext_mult_num - 1) * single_endpoint_num))
    )
  )
)

seed_variant_levels_chr <- c("Flat $100 (headline)", "Pro-rata with match rate",
                             "Flat, then taper", "Extended taper")
seed_variant_lines_tbl$variant_chr <- factor(seed_variant_lines_tbl$variant_chr,
                                             levels = seed_variant_levels_chr)

seed_variant_csv_path_chr <- file.path(path_output_fig_data_chr,
                                       "universal_sm_hybrid_seed_variant_schedules.csv")
write_csv(seed_variant_lines_tbl, seed_variant_csv_path_chr)

seed_variant_colors_chr <- c(
  "Flat $100 (headline)"     = eig_teal_900_chr,
  "Pro-rata with match rate" = eig_gold_600_chr,
  "Flat, then taper"         = eig_green_700_chr,
  "Extended taper"           = eig_cyan_700_chr
)

# The flat design is dashed because it coincides with the extended taper across
# the whole eligible band (and with flat-then-taper below the pivot) -- a solid
# line would be completely hidden underneath the variants drawn after it.
seed_variant_linetypes_chr <- c(
  "Flat $100 (headline)"     = "dashed",
  "Pro-rata with match rate" = "solid",
  "Flat, then taper"         = "solid",
  "Extended taper"           = "solid"
)

fig6_gg <- ggplot2::ggplot(seed_variant_lines_tbl,
                           ggplot2::aes(x = magi_num, y = seed_num,
                                        color = variant_chr, linetype = variant_chr)) +
  ggplot2::geom_line(linewidth = 1.0) +
  ggplot2::scale_color_manual(values = seed_variant_colors_chr) +
  ggplot2::scale_linetype_manual(values = seed_variant_linetypes_chr) +
  ggplot2::scale_x_continuous(labels = scales::dollar_format()) +
  ggplot2::scale_y_continuous(labels = scales::dollar_format(),
                              limits = c(0, seed_amount_num * 1.08)) +
  ggplot2::labs(
    x = "MAGI (TY2027 dollars), single filer",
    y = "Annual seed contribution",
    color = NULL, linetype = NULL,
    title = "Figure 6. Seed designs compared: flat vs. phased variants",
    subtitle = sprintf(paste0("Single filer. Pivot $%s; match endpoint $%s; the extended ",
                              "taper reaches $0 at %.2f x the endpoint"),
                       formatC(round(single_pivot_num), format = "d", big.mark = ","),
                       formatC(round(single_endpoint_num), format = "d", big.mark = ","),
                       seed_ext_mult_num),
    caption = "Source: Author's analysis of SIPP 2024 Wave 1."
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    legend.position    = "bottom",
    panel.grid.minor   = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    plot.title         = ggplot2::element_text(face = "bold"),
    plot.subtitle      = ggplot2::element_text(size = 9, color = "#444444")
  )

fig6_png_path_chr <- file.path(path_output_figs_chr, "seed_variant_schedules.png")
ggplot2::ggsave(fig6_png_path_chr, fig6_gg,
                width = 8, height = 5, dpi = 300, units = "in")
message("Wrote: ", fig6_png_path_chr)

###################################################################################
###                  4) Figure 3: Universe Funnel                               ###
###################################################################################
funnel_csv_path_chr <- file.path(path_output_reports_chr, "universe_funnel.csv")
if (!file.exists(funnel_csv_path_chr)) {
  warning("Universe funnel CSV not found at: ", funnel_csv_path_chr,
          ". Skipping Figure 3.", call. = FALSE)
} else {
  funnel_tbl <- read_csv(funnel_csv_path_chr, show_col_types = FALSE) |>
    dplyr::mutate(step_label_chr = factor(step_label_chr,
                                           levels = rev(step_label_chr)))

  fig3_gg <- ggplot2::ggplot(funnel_tbl,
                              ggplot2::aes(x = step_label_chr,
                                           y = weighted_n_num / 1e6)) +
    ggplot2::geom_col(fill = eig_green_700_chr) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(labels = scales::comma_format(accuracy = 1)) +
    ggplot2::labs(
      x = NULL,
      y = "Weighted workers (millions)",
      title = "Figure 3. Universe construction funnel",
      caption = "Source: Author's analysis of SIPP 2024 Wave 1, December reference month."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor   = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_blank(),
      plot.title         = ggplot2::element_text(face = "bold")
    )

  fig3_png_path_chr <- file.path(path_output_figs_chr, "universe_funnel.png")
  ggplot2::ggsave(fig3_png_path_chr, fig3_gg,
                  width = 8, height = 5, dpi = 300, units = "in")
  message("Wrote: ", fig3_png_path_chr)

  funnel_data_csv_path_chr <- file.path(path_output_fig_data_chr,
                                         "universal_sm_hybrid_universe_funnel.csv")
  write_csv(funnel_tbl, funnel_data_csv_path_chr)
}

###################################################################################
###             5) Figure 4: MAGI Distribution of the Universe                  ###
###################################################################################
# Weighted MAGI distribution of the analysis universe, split by eligibility, with
# each filing group's zero-match endpoint marked. Gives a distributional view of
# the MAGI driver and shows where the eligibility band sits in the income
# distribution. (Diagnostic figure; not embedded in the two-page brief.)
endpoints_num  <- endpoint_factor_num * sm_pivot_2024_num  # Single/MFJ/HoH endpoints = R_max/(R_max - R_p) x pivot; (4/3) x at the defaults
dist_x_max_num <- 150000
dist_tbl <- simulation_tbl |>
  dplyr::filter(!is.na(magi_num), magi_num >= 0, magi_num <= dist_x_max_num) |>
  dplyr::mutate(eligible_lbl_chr = dplyr::if_else(eligible_flag %in% TRUE,
                                                  "Eligible (positive match)", "No match"))
endpoint_lines_tbl <- dplyr::tibble(
  endpoint_num = as.numeric(endpoints_num),
  label_chr    = c(single_mfs = "Single", mfj = "MFJ", hoh = "HoH")[names(endpoints_num)]
)
fig4_gg <- ggplot2::ggplot(dist_tbl,
                           ggplot2::aes(x = magi_num, weight = WPFINWGT, fill = eligible_lbl_chr)) +
  ggplot2::geom_histogram(binwidth = 5000, boundary = 0, color = "white", linewidth = 0.1) +
  ggplot2::geom_vline(data = endpoint_lines_tbl, ggplot2::aes(xintercept = endpoint_num),
                      linetype = "dashed", color = "#444444", linewidth = 0.4, inherit.aes = FALSE) +
  ggplot2::scale_fill_manual(values = c("Eligible (positive match)" = eig_green_700_chr,
                                        "No match" = "#C9C9C9")) +
  ggplot2::scale_x_continuous(labels = scales::dollar_format(), limits = c(0, dist_x_max_num)) +
  ggplot2::scale_y_continuous(labels = function(y) paste0(round(y / 1e6, 1), "M")) +
  ggplot2::labs(
    x = "MAGI (TY2027 dollars)", y = "Weighted workers", fill = NULL,
    title = "Figure 4. MAGI distribution of the analysis universe",
    subtitle = "Dashed lines mark each filing group's zero-match endpoint",
    caption = "Source: Author's analysis of SIPP 2024 Wave 1."
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    legend.position    = "bottom",
    panel.grid.minor   = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    plot.title         = ggplot2::element_text(face = "bold")
  )
fig4_png_path_chr <- file.path(path_output_figs_chr, "universe_magi_distribution.png")
ggplot2::ggsave(fig4_png_path_chr, fig4_gg, width = 8, height = 5, dpi = 300, units = "in")
message("Wrote: ", fig4_png_path_chr)

magi_dist_data_tbl <- dist_tbl |>
  dplyr::mutate(magi_bin_num = floor(magi_num / 5000) * 5000) |>
  dplyr::group_by(magi_bin_num, eligible_lbl_chr) |>
  dplyr::summarise(weighted_n_num = sum(WPFINWGT, na.rm = TRUE), .groups = "drop")
write_csv(magi_dist_data_tbl,
          file.path(path_output_fig_data_chr, "universal_sm_hybrid_universe_magi_distribution.csv"))

message("04_05_build_figures.R complete.")
