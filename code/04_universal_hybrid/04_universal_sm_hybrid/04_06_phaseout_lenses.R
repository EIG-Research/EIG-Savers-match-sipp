# 04_06_phaseout_lenses -- Three visual lenses on the hybrid Saver's Match phaseout
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - The hybrid schedule holds the $1,000 cap constant across the eligibility band
#                     but the match rate falls continuously with MAGI. Even where the cap
#                     looks flat in dollar terms, the worker faces a phaseout in the form
#                     of a rising required contribution. This script characterizes that
#                     phaseout through three lenses, for a Single filer:
#                       (1) the match rate by MAGI -- the subsidy rate phaseout itself
#                       (2) the dollar contribution required to reach the $1,000 cap,
#                           with the 3 percent auto-enrollment default overlaid
#                       (3) the required contribution as a share of earnings -- the
#                           U-shaped reachability of the cap under default behavior
#
# DESCRIPTION:
# All three lenses are deterministic functions of the schedule in
# code/_shared/calibration_cells.R (compute_match_rate()). The script does not
# touch the SIPP universe; it operates on a fine MAGI grid for a Single
# filer using the pivot table emitted by 04_02_compute_pivots.R.
#
# Inputs:
#   data/processed/universal_sm_hybrid/pivot_table.rds
#   Infrastructure/style/themes/r/eig_tokens.R
#   Infrastructure/style/themes/r/eig_theme.R
#   code/_shared/calibration_cells.R  (for compute_match_rate)
# Outputs:
#   output/data/figure_data/universal_sm_hybrid_phaseout_lenses.csv
#   data/processed/universal_sm_hybrid/phaseout_lenses.parquet
#   data/processed/universal_sm_hybrid/phaseout_lenses.rds
#   output/figures/universal_sm_hybrid/lens_01_match_rate.png
#   output/figures/universal_sm_hybrid/lens_02_required_contribution.png
#   output/figures/universal_sm_hybrid/lens_03_required_share_of_earnings.png
#   output/reports/universal_sm_hybrid/phaseout_lenses_anchors.md

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

###################################################################################
###                         Configuration and Paths                             ###
###################################################################################
path_data_processed_chr  <- file.path(project_root, "data", "processed", "universal_sm_hybrid")
path_output_figs_chr     <- file.path(project_root, "output", "figures", "universal_sm_hybrid")
path_output_reports_chr  <- file.path(project_root, "output", "reports", "universal_sm_hybrid")
path_output_fig_data_chr <- file.path(project_root, "output", "data", "figure_data")
for (p in c(path_data_processed_chr, path_output_figs_chr,
            path_output_reports_chr, path_output_fig_data_chr)) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE)
}

# Single-filer focus and schedule parameters fed in from the pivot artifact.
filing_group_focus_chr <- "single_mfs"
filing_group_label_chr <- "Single / MFS"
default_contrib_rate_num <- 0.03   # The 04 auto-enrollment default
match_cap_num            <- 1000   # Per-individual federal credit cap

# Current-law Saver's Match parameters (Single filer), used for the contrast
# overlays in Figures 4-6. A 50% rate up to the lower threshold phasing to 0 at
# the upper threshold, with a $2,000 matchable-contribution cap -> $1,000 max
# credit. Because the credit caps at 0.50 * $2,000, the $1,000 cap is reachable
# only at/below the lower threshold (where the full $2,000 contribution is matched
# at 50%); above it, even $2,000 yields < $1,000.
cur_low_num         <- sm_calibration_constants()$sm_lower[["Single"]]   # 20,500
cur_high_num        <- sm_calibration_constants()$sm_upper[["Single"]]   # 35,500
cur_rate_max_num    <- sm_calibration_constants()$sm_match_rate_max      # 0.50
cur_contrib_cap_num <- sm_calibration_constants()$sm_contrib_cap         # 2,000
cur_credit_cap_num  <- cur_rate_max_num * cur_contrib_cap_num              # 1,000

# Income grid covers the entire eligibility band plus a margin past the endpoint
# so the figures show where the policy has bite and where it does not. Under the
# 75%@two-thirds-median IRS-anchored design the Single endpoint is (4/3) x pivot =
# 1.067 x the IRS Single median (~$43K), so the grid runs well past that.
grid_min_num  <- 1000L              # avoid divide-by-zero in share-of-earnings
grid_max_num  <- 80000L             # well past the Single endpoint ((4/3) x pivot)
grid_step_num <- 100L               # smooth curves

# Parameter assertions guard against silently wrong outputs.
stopifnot(
  is.numeric(default_contrib_rate_num) && default_contrib_rate_num > 0 &&
    default_contrib_rate_num < 1,
  is.numeric(match_cap_num) && match_cap_num > 0,
  grid_max_num > grid_min_num,
  grid_step_num > 0
)

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

# Palette pulls from the EIG primary 2022 tokens. Series color is the green used
# elsewhere in the 04 pipeline; the auto-enrollment default reference and the
# anchor callouts use the gold token for contrast without clashing with the
# rest of the chart family.
color_series_chr   <- eig_tokens_env$EIG_COLORS[["eig_green_700"]]   # #19644D
color_default_chr  <- eig_tokens_env$EIG_COLORS[["eig_gold_600"]]    # #E1AD28
color_anchor_chr   <- eig_tokens_env$EIG_COLORS[["eig_teal_900"]]    # #024140
color_reference_chr <- "#666666"                                      # neutral gray
color_band_chr     <- eig_tokens_env$EIG_COLORS[["eig_cream_100"]]   # #FEECD6
color_text_chr     <- eig_tokens_env$EIG_COLORS[["eig_black"]]
# Role aliases used across the contrast figures (4-6): gold = current-law policy
# series; gray = the behavioral 3% default reference.
color_curlaw_chr      <- color_default_chr
color_default_ref_chr <- color_reference_chr

###################################################################################
###                       1) Load Pivot and Set Anchors                         ###
###################################################################################
pivot_obj_list    <- readRDS(file.path(path_data_processed_chr, "pivot_table.rds"))
sm_pivot_2024_num <- pivot_obj_list$pivot_vec_num
stopifnot(filing_group_focus_chr %in% names(sm_pivot_2024_num))

pivot_single_num   <- sm_pivot_2024_num[[filing_group_focus_chr]]
stopifnot(pivot_single_num > 0)

# Derive the schedule shape directly from compute_match_rate() rather than
# re-hardcoding the floor/slope/endpoint here. This is the single source of
# truth: if calibration_cells.R::compute_match_rate() changes, these values
# track it automatically (the 2026-06-08 redesign from a 300%/-250 schedule to
# the 200%-floor single straight line motivated this hardening).
#   floor  = rate at MAGI 0          (200 under the current schedule)
#   slope  = (rate@pivot - floor) / pivot   (-150/pivot; rate@pivot is 50)
#   endpoint = MAGI where the line hits 0  = pivot - rate@pivot/slope = (4/3)*pivot
eval_rate_fn <- function(magi_num) {
  compute_match_rate(
    magi_num         = magi_num,
    filing_group_chr = rep(filing_group_focus_chr, length(magi_num)),
    pivot_table      = sm_pivot_2024_num
  )
}
floor_pp_num            <- eval_rate_fn(0)
rate_at_pivot_pp_num    <- eval_rate_fn(pivot_single_num)
slope_pp_per_dollar_num <- (rate_at_pivot_pp_num - floor_pp_num) / pivot_single_num
endpoint_single_num     <- pivot_single_num - rate_at_pivot_pp_num / slope_pp_per_dollar_num
stopifnot(floor_pp_num > 0, slope_pp_per_dollar_num < 0, endpoint_single_num > pivot_single_num)

# Invert the (single straight-line) schedule: solve floor + slope * M = R for M.
#   M = (R - floor) / slope
# Used to locate anchor points where the schedule equals a given rate. Replaces
# the old closed form M = pivot * (300 - R) / 250, which was tied to the 300%
# schedule. Note: under the 200% floor, rate = 200 only at M = 0, so the only
# interior cap-relevant anchor is rate = 100% (at M = (2/3) * pivot).
magi_at_rate_fn_chr <- "M = (R - floor) / slope"
magi_at_rate <- function(R) (R - floor_pp_num) / slope_pp_per_dollar_num
magi_at_rate_100_num <- magi_at_rate(100)   # rate = 100% (= (2/3) * pivot under 200% floor)

###################################################################################
###                       2) Build the Single-Filer Lens Grid                   ###
###################################################################################
magi_grid_num <- seq(grid_min_num, grid_max_num, by = grid_step_num)

match_rate_pp_num <- compute_match_rate(
  magi_num         = magi_grid_num,
  filing_group_chr = rep(filing_group_focus_chr, length(magi_grid_num)),
  pivot_table      = sm_pivot_2024_num
)
match_rate_frac_num <- match_rate_pp_num / 100

# Required contribution to reach the $1,000 cap = cap / rate. When rate is
# at or near zero (at the endpoint and above), the cap is unreachable; we
# mark that with NA so the figure shows a gap rather than a spurious near-
# infinity caused by floating-point residuals around the endpoint.
rate_floor_for_invert_num <- 1e-9
required_contribution_num <- ifelse(
  match_rate_frac_num > rate_floor_for_invert_num,
  match_cap_num / match_rate_frac_num,
  NA_real_
)

# The 3 percent default contribution at this MAGI level (treating MAGI as
# earnings for the Single-filer wage-only case).
default_contribution_num <- default_contrib_rate_num * magi_grid_num

# Required contribution as a share of earnings -- the U-shape.
required_share_num <- required_contribution_num / magi_grid_num

# Match dollar received at the 3 percent default (capped at $1,000). Useful
# as context but not the focal series in any of the three lens figures.
match_at_default_num <- pmin(
  match_cap_num,
  match_rate_frac_num * default_contribution_num
)

cap_binds_at_default_flag <- match_rate_frac_num * default_contribution_num >= match_cap_num

lens_tbl <- dplyr::tibble(
  filing_group_chr           = filing_group_focus_chr,
  magi_num                   = magi_grid_num,
  earnings_num               = magi_grid_num,
  match_rate_pp_num          = match_rate_pp_num,
  required_contribution_num  = required_contribution_num,
  default_contribution_num   = default_contribution_num,
  required_share_num         = required_share_num,
  match_at_default_num       = match_at_default_num,
  cap_binds_at_default_flag  = cap_binds_at_default_flag
)

###################################################################################
###                  3) Save Figure-Data Checkpoints                            ###
###################################################################################
lens_csv_path_chr     <- file.path(path_output_fig_data_chr, "universal_sm_hybrid_phaseout_lenses.csv")
lens_parquet_path_chr <- file.path(path_data_processed_chr, "phaseout_lenses.parquet")
lens_rds_path_chr     <- file.path(path_data_processed_chr, "phaseout_lenses.rds")

write_csv(lens_tbl, lens_csv_path_chr)
arrow::write_parquet(lens_tbl, lens_parquet_path_chr, compression = "snappy")
saveRDS(lens_tbl, lens_rds_path_chr)
message("Wrote: ", lens_csv_path_chr)
message("Wrote: ", lens_parquet_path_chr)
message("Wrote: ", lens_rds_path_chr)

###################################################################################
###                  4) Compute Anchor Values for Direct Labeling               ###
###################################################################################
# Anchor MAGI levels at which each figure carries a direct on-chart label.
# Computed off the same schedule the figure curves draw from (via magi_at_rate),
# so they track any change to compute_match_rate(). Under the 200% floor, rate =
# 200% occurs only at M = 0, so the interior anchors are rate = 100% and the
# pivot (50%); the endpoint (0%) closes the band.
anchor_levels_num <- c(
  0,                                    # rate = floor (200% under current schedule)
  magi_at_rate_100_num,                 # rate = 100% (= (2/3) * pivot under 200% floor)
  pivot_single_num,                     # rate = 50%  (pivot)
  endpoint_single_num                   # rate = 0%   (endpoint = (4/3) * pivot)
)
anchor_label_chr <- c("$0 MAGI", "Rate = 100%", "Pivot", "Endpoint")

anchor_rate_pp_num <- compute_match_rate(
  magi_num         = anchor_levels_num,
  filing_group_chr = rep(filing_group_focus_chr, length(anchor_levels_num)),
  pivot_table      = sm_pivot_2024_num
)
anchor_rate_frac_num <- anchor_rate_pp_num / 100
anchor_required_num <- ifelse(anchor_rate_frac_num > rate_floor_for_invert_num,
                              match_cap_num / anchor_rate_frac_num,
                              NA_real_)
anchor_share_num <- ifelse(anchor_levels_num > 0,
                           anchor_required_num / anchor_levels_num,
                           NA_real_)

# Self-check: confirm the anchor rates land where their labels claim.
stopifnot(
  abs(anchor_rate_pp_num[1] - floor_pp_num) < 1e-6,   # floor (200%) at $0
  abs(anchor_rate_pp_num[2] - 100) < 1e-6,
  abs(anchor_rate_pp_num[3] -  50) < 1e-6,
  abs(anchor_rate_pp_num[4] -   0) < 1e-6
)

anchor_tbl <- dplyr::tibble(
  anchor_label_chr,
  magi_num           = anchor_levels_num,
  match_rate_pp_num  = anchor_rate_pp_num,
  required_contribution_num = anchor_required_num,
  required_share_num = anchor_share_num
)

###################################################################################
###                  5) Tufte-Minded Theme on Top of EIG Defaults               ###
###################################################################################
# Self-contained theme to avoid the font-pinning in eig_theme_ggplot(). The
# helper there hardcodes base_family = "Open Sans" which raises 'invalid font
# type' on R installations without that font registered to the graphics
# device. The 04_05 figures sidestep this by not calling eig_theme_ggplot();
# we follow the same pattern here so the script is portable. EIG palette
# tokens still drive the colors; the theme only opts out of the font pin.
# Tufte layer: horizontal-only light gridlines, no panel border, x-axis line
# as a range frame, no y ticks, direct labels in place of legends.
eig_tufte_theme <- ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    text               = ggplot2::element_text(color = color_text_chr),
    panel.grid.minor   = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    panel.grid.major.y = ggplot2::element_line(color = "#EAEAEA", linewidth = 0.25),
    panel.border       = ggplot2::element_blank(),
    panel.background   = ggplot2::element_rect(fill = "white", color = NA),
    plot.background    = ggplot2::element_rect(fill = "white", color = NA),
    axis.line.x        = ggplot2::element_line(color = color_text_chr, linewidth = 0.4),
    axis.line.y        = ggplot2::element_blank(),
    axis.ticks.x       = ggplot2::element_line(color = color_text_chr, linewidth = 0.3),
    axis.ticks.y       = ggplot2::element_blank(),
    axis.title.x       = ggplot2::element_text(face = "bold", color = color_text_chr,
                                                margin = ggplot2::margin(t = 8)),
    axis.title.y       = ggplot2::element_text(face = "bold", color = color_text_chr,
                                                margin = ggplot2::margin(r = 8)),
    axis.text          = ggplot2::element_text(color = color_text_chr),
    plot.title         = ggplot2::element_text(face = "bold", hjust = 0, size = 13,
                                                color = color_text_chr,
                                                margin = ggplot2::margin(b = 4)),
    plot.subtitle      = ggplot2::element_text(hjust = 0, size = 10,
                                                color = "#444444",
                                                margin = ggplot2::margin(b = 10)),
    plot.caption       = ggplot2::element_text(hjust = 0, size = 8,
                                                color = "#666666",
                                                margin = ggplot2::margin(t = 10)),
    plot.caption.position = "plot",
    legend.position    = "none",
    plot.margin        = ggplot2::margin(12, 18, 10, 12)
  )

# Set after the theme so geom_text annotations can use the same generic family.
font_body_chr <- ""   # empty string -> grDevices default sans
font_head_chr <- ""

# Common figure dimensions. Aspect favors a wider panel than the EIG default
# 6.5 x 3.5 so direct labels fit without crowding. Pushed from 7.5 to 8.5 in
# after the first visual inspection showed right-edge clipping of the
# endpoint label and the source caption on Figure 1.
fig_width_in_num  <- 8.5
fig_height_in_num <- 4.8

# Helper data subsets used by figure 2 and figure 3 to cap the y-axis at a
# readable ceiling. Both lenses go to infinity at the endpoint; truncation is
# explicit, with an annotation noting the unreachable region.
required_contribution_ceiling_num <- 4000   # dollars
required_share_ceiling_num        <- 0.15   # 15 percent

###################################################################################
###             6) Figure 1: The Subsidy Rate Phaseout                          ###
###################################################################################
# Line data: end the curve exactly at the endpoint (where the rate hits 0)
# rather than running flat past it. Append the precise endpoint so the line
# lands on (endpoint, 0).
fig1_line_tbl <- lens_tbl |>
  dplyr::filter(magi_num <= endpoint_single_num) |>
  dplyr::select(magi_num, match_rate_pp_num)
fig1_line_tbl <- dplyr::bind_rows(
  dplyr::tibble(magi_num = 0, match_rate_pp_num = floor_pp_num),
  fig1_line_tbl,
  dplyr::tibble(magi_num = endpoint_single_num, match_rate_pp_num = 0)
) |>
  dplyr::arrange(magi_num)

# Current-law Saver's Match rate overlay (Single filer), for contrast: a flat 50%
# up to the lower threshold, phasing linearly to 0 at the upper threshold. Same
# gold dashed treatment as Figure 1.
fig1_curlaw_tbl <- dplyr::tibble(magi_num = seq(0, cur_high_num, by = 250)) |>
  dplyr::mutate(
    cur_rate_pp_num = 50 * pmax(0, pmin(1, (cur_high_num - magi_num) /
                                           (cur_high_num - cur_low_num)))
  )

# The design anchor: 75% at two-thirds the IRS Single median MAGI. With the 200%
# floor this is the point magi_at_rate(75) = (5/6) * pivot, which equals 2/3 the
# IRS Single median by construction (pivot = 0.8 x median). Headline callout.
anchor75_magi_num    <- magi_at_rate(75)
anchor75_rate_pp_num <- 75

# Dots at $0, the 75%-at-two-thirds-median design anchor, and the endpoint. The
# endpoint keeps its dot but carries NO text label -- the line visibly collapses
# to 0 there.
fig1_points_tbl <- dplyr::tibble(
  magi_num          = c(0, anchor75_magi_num, endpoint_single_num),
  match_rate_pp_num = c(floor_pp_num, anchor75_rate_pp_num, 0)
)

# Text callouts on the $0 floor and the 75% design anchor:
#   - "200% match at zero MAGI" sits just below and to the right of the line.
#   - "75% match at two-thirds the Single median MAGI" sits directly above the dot.
# Nudges are a first pass; tuned on the render-inspect loop.
fig1_labels_tbl <- dplyr::tibble(
  magi_num          = c(0, anchor75_magi_num),
  match_rate_pp_num = c(floor_pp_num, anchor75_rate_pp_num),
  label_full_chr    = c(paste0(round(floor_pp_num), "% match\nat zero MAGI"),
                        "75% match at\ntwo-thirds the Single median MAGI"),
  nudge_x_num       = c(4000, 0),
  nudge_y_num       = c(-28, 22),
  hjust_num         = c(0, 0.5)
)

# Single vertical reference at the 75% design anchor; the endpoint is marked by
# its dot on the zero baseline, so no second guide is needed.
fig1_refs_tbl <- dplyr::tibble(
  x_num     = anchor75_magi_num,
  y_top_num = anchor75_rate_pp_num
)

fig1_gg <- ggplot2::ggplot(fig1_line_tbl, ggplot2::aes(x = magi_num, y = match_rate_pp_num)) +
  ggplot2::geom_segment(
    data = fig1_refs_tbl,
    ggplot2::aes(x = x_num, xend = x_num, y = 0, yend = y_top_num),
    color = color_reference_chr, linetype = "dotted", linewidth = 0.3,
    inherit.aes = FALSE
  ) +
  # Current-law Saver's Match rate (gold dashed), drawn beneath the green
  # Expanded Policy line so the latter reads on top.
  ggplot2::geom_line(
    data = fig1_curlaw_tbl,
    ggplot2::aes(x = magi_num, y = cur_rate_pp_num),
    color = color_default_chr, linetype = "dashed", linewidth = 0.9,
    inherit.aes = FALSE
  ) +
  ggplot2::geom_line(color = color_series_chr, linewidth = 1.0) +
  ggplot2::geom_point(
    data = fig1_points_tbl,
    ggplot2::aes(x = magi_num, y = match_rate_pp_num),
    color = color_anchor_chr, size = 2.2, inherit.aes = FALSE
  ) +
  # geom_label with a white fill masks the line behind each callout so neither
  # label visually intersects the descending curve. label.size = 0 drops the box
  # border so the mask reads as clean negative space.
  ggplot2::geom_label(
    data = fig1_labels_tbl,
    ggplot2::aes(x = magi_num + nudge_x_num,
                 y = match_rate_pp_num + nudge_y_num,
                 label = label_full_chr,
                 hjust = hjust_num),
    family = font_body_chr, size = 3.2, color = color_text_chr,
    fill = "white", label.size = 0,
    label.padding = ggplot2::unit(0.1, "lines"),
    lineheight = 0.9, inherit.aes = FALSE
  ) +
  # Direct series labels distinguishing the two schedules.
  ggplot2::annotate(
    "text", x = 16000, y = 155,
    label = "Expanded Policy",
    color = color_series_chr, family = font_body_chr,
    fontface = "bold", size = 3.2, hjust = 0
  ) +
  ggplot2::annotate(
    "text", x = 6000, y = 64,
    label = "Saver's Match\n(current law)",
    color = color_default_chr, family = font_body_chr,
    fontface = "bold", size = 3.2, hjust = 0, lineheight = 0.9
  ) +
  ggplot2::scale_x_continuous(
    labels = scales::label_dollar(scale = 1, accuracy = 1, big.mark = ","),
    breaks = c(0, 10000, 20000, 30000, 40000),
    expand = ggplot2::expansion(mult = c(0.01, 0.02))
  ) +
  ggplot2::scale_y_continuous(
    labels = function(x) paste0(x, "%"),
    breaks = c(0, 50, 100, 150, 200),
    expand = ggplot2::expansion(mult = c(0.02, 0.05))
  ) +
  ggplot2::labs(
    title    = paste0("Figure 4. The match rate falls from ", round(floor_pp_num),
                      "% at zero MAGI to 0% at $",
                      formatC(round(endpoint_single_num), format = "d", big.mark = ",")),
    subtitle = paste0("Expanded Policy vs. current-law Saver's Match, ", filing_group_label_chr,
                      " filer, TY2027 dollars"),
    x        = "Modified adjusted gross income (MAGI)",
    y        = "Federal match rate",
    caption  = "Source: Author's calculation. Pivot anchored to the IRS all-single-filer median AGI (SOI Table 1.2); 75% rate at two-thirds the median."
  ) +
  eig_tufte_theme

fig1_png_path_chr <- file.path(path_output_figs_chr, "lens_01_match_rate.png")
ggplot2::ggsave(fig1_png_path_chr, fig1_gg,
                width = fig_width_in_num, height = fig_height_in_num,
                dpi = 300, units = "in")
message("Wrote: ", fig1_png_path_chr)

###################################################################################
###             7) Figure 2: Required Contribution to Reach the $1,000 Cap      ###
###################################################################################
fig2_data_tbl <- lens_tbl |>
  dplyr::filter(magi_num <= endpoint_single_num) |>
  dplyr::mutate(
    # NA above the ceiling so the line cleanly leaves the panel rather than
    # flat-lining at the y-axis ceiling -- the flat-line variant misleads
    # readers into thinking the required contribution stops climbing.
    required_contribution_plot_num = dplyr::if_else(
      required_contribution_num <= required_contribution_ceiling_num,
      required_contribution_num, NA_real_),
    truncated_flag = required_contribution_num > required_contribution_ceiling_num
  )

# Shade the region where the 3 percent default contribution alone reaches the
# cap -- this is the band where workers do not have to opt up to capture the
# full $1,000 match. The boundary is found from cap_binds_at_default_flag.
# The default-suffices band can be empty under the 200% floor: the 3% default
# reaches the $1,000 cap only where rate_frac * 0.03 * MAGI >= 1000, whose peak
# over MAGI equals 0.02 * pivot, so the band is non-empty iff the Single pivot is
# at least ~$50,000. Guard against an empty band so the geom_rect / annotations
# degrade gracefully instead of erroring on Inf/-Inf summaries.
default_band_rows_tbl <- lens_tbl |>
  dplyr::filter(cap_binds_at_default_flag)
band_exists_lgl <- nrow(default_band_rows_tbl) > 0L
default_band_tbl <- if (band_exists_lgl) {
  dplyr::summarise(
    default_band_rows_tbl,
    band_lo_num = min(magi_num, na.rm = TRUE),
    band_hi_num = max(magi_num, na.rm = TRUE)
  )
} else {
  dplyr::tibble(band_lo_num = NA_real_, band_hi_num = NA_real_)
}
if (!band_exists_lgl) {
  warning("No MAGI level lets the 3% default contribution reach the $1,000 cap ",
          "(requires Single pivot >= ~$50,000 under the 200% floor; current pivot $",
          formatC(round(pivot_single_num), format = "d", big.mark = ","),
          "). Band shading and band annotations are omitted from Figures 2 and 3.",
          call. = FALSE)
}

# Two anchor callouts on the Expanded Policy curve: the $500 entry at $0 and the
# $2,000 contribution at the pivot. (The $20,205 point is dropped to make room
# for the current-law contrast and the end-of-range marker.)
fig2_anchors_tbl <- anchor_tbl |>
  dplyr::filter(anchor_label_chr %in% c("$0 MAGI", "Pivot")) |>
  dplyr::mutate(
    label_full_chr = dplyr::case_when(
      anchor_label_chr == "$0 MAGI" ~ paste0("$",
                                             formatC(round(required_contribution_num), format = "d", big.mark = ","),
                                             " unlocks the cap\nat zero MAGI"),
      anchor_label_chr == "Pivot"   ~ paste0("$",
                                             formatC(round(required_contribution_num), format = "d", big.mark = ","),
                                             " contribution\nat the pivot"),
      TRUE                           ~ anchor_label_chr
    ),
    plot_y_num  = pmin(required_contribution_num, required_contribution_ceiling_num),
    nudge_x_num = c( 2500, -2500)[seq_len(dplyr::n())],
    nudge_y_num = c(  450,   650)[seq_len(dplyr::n())],
    hjust_num   = c(    0,     1)[seq_len(dplyr::n())]
  )

# Current-law contrast: to reach its $1,000 cap a worker must contribute the full
# $2,000 matchable maximum, and only up to the lower threshold ($20,500) -- above
# it the cap is unreachable, so the line terminates. A flat gold segment plus a
# terminal dot conveys both facts.
fig2_curlaw_tbl <- dplyr::tibble(
  magi_num            = c(0, cur_low_num),
  cur_req_contrib_num = cur_contrib_cap_num
)
fig2_curlaw_end_tbl <- dplyr::tibble(
  magi_num            = cur_low_num,
  cur_req_contrib_num = cur_contrib_cap_num
)

fig2_gg <- ggplot2::ggplot(fig2_data_tbl, ggplot2::aes(x = magi_num)) +
  # Shaded band: where the 3% default alone reaches the cap (omitted if empty).
  (if (band_exists_lgl) ggplot2::geom_rect(
    data = default_band_tbl,
    ggplot2::aes(xmin = band_lo_num, xmax = band_hi_num,
                 ymin = 0, ymax = required_contribution_ceiling_num),
    fill = color_band_chr, alpha = 0.6, inherit.aes = FALSE
  ) else NULL) +
  # End of the Expanded Policy match range: a vertical guide at the endpoint,
  # where the required contribution diverges (cap unreachable above).
  ggplot2::geom_vline(xintercept = endpoint_single_num,
                      color = color_reference_chr, linetype = "dotted", linewidth = 0.4) +
  # Current-law Saver's Match required contribution: a flat $2,000 (the full
  # matchable maximum), reachable only up to $20,500; terminal dot marks the end.
  ggplot2::geom_line(
    data = fig2_curlaw_tbl,
    ggplot2::aes(x = magi_num, y = cur_req_contrib_num),
    color = color_curlaw_chr, linewidth = 1.0, linetype = "dashed", inherit.aes = FALSE
  ) +
  ggplot2::geom_point(
    data = fig2_curlaw_end_tbl,
    ggplot2::aes(x = magi_num, y = cur_req_contrib_num),
    color = color_curlaw_chr, size = 2.2, inherit.aes = FALSE
  ) +
  # The 3% behavioral default contribution line (neutral gray; gold is reserved
  # for the current-law policy series).
  ggplot2::geom_line(
    ggplot2::aes(y = default_contribution_num),
    color = color_default_ref_chr, linewidth = 0.8, linetype = "dashed"
  ) +
  # The required contribution curve (Expanded Policy).
  ggplot2::geom_line(
    ggplot2::aes(y = required_contribution_plot_num),
    color = color_series_chr, linewidth = 1.0
  ) +
  ggplot2::geom_point(
    data = fig2_anchors_tbl,
    ggplot2::aes(x = magi_num, y = plot_y_num),
    color = color_anchor_chr, size = 2.2, inherit.aes = FALSE
  ) +
  ggplot2::geom_text(
    data = fig2_anchors_tbl,
    ggplot2::aes(x = magi_num + nudge_x_num,
                 y = plot_y_num + nudge_y_num,
                 label = label_full_chr,
                 hjust = hjust_num),
    family = font_body_chr, size = 3.2, color = color_text_chr,
    lineheight = 0.9, inherit.aes = FALSE
  ) +
  # Direct labels for the two series. The series-curve label sits near the
  # right edge; the default-contribution label is placed clearly above the
  # dashed line so it is not visually fused with the reference itself.
  ggplot2::annotate(
    "text", x = 27000, y = 3600,
    label = "Required to reach $1,000 cap",
    color = color_series_chr, family = font_body_chr,
    fontface = "bold", size = 3.2, hjust = 1
  ) +
  ggplot2::annotate(
    "text", x = 2500, y = 2350,
    label = paste0("Saver's Match: flat $",
                   formatC(cur_contrib_cap_num, format = "d", big.mark = ","),
                   ",\nonly up to $", formatC(cur_low_num, format = "d", big.mark = ",")),
    color = color_curlaw_chr, family = font_body_chr,
    fontface = "bold", size = 3.2, hjust = 0, lineheight = 0.9
  ) +
  ggplot2::annotate(
    "text", x = 38000, y = 1350,
    label = "3% auto-enrollment default",
    color = color_default_ref_chr, family = font_body_chr,
    fontface = "bold", size = 3.2, hjust = 1
  ) +
  ggplot2::annotate(
    "text", x = endpoint_single_num - 400, y = 450,
    label = paste0("Expanded Policy match ends at $",
                   formatC(round(endpoint_single_num), format = "d", big.mark = ",")),
    color = color_text_chr, family = font_body_chr,
    size = 3.0, hjust = 1
  ) +
  ggplot2::scale_x_continuous(
    labels = scales::label_dollar(scale = 1, accuracy = 1, big.mark = ","),
    breaks = c(0, 10000, 20000, 30000, 40000),
    limits = c(0, endpoint_single_num + 500),
    expand = ggplot2::expansion(mult = c(0.01, 0.01))
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::label_dollar(scale = 1, accuracy = 1, big.mark = ","),
    breaks = c(0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000),
    limits = c(0, required_contribution_ceiling_num),
    expand = ggplot2::expansion(mult = c(0, 0.02))
  ) +
  ggplot2::labs(
    title    = "Figure 5. The contribution required to reach the $1,000 cap rises with income",
    subtitle = paste0("Worker out-of-pocket required to receive the full federal match, ",
                      filing_group_label_chr, " filer"),
    x        = "Modified adjusted gross income (MAGI)",
    y        = "Worker contribution",
    caption  = paste0("Source: Author's calculation. Required contribution = $1,000 / match rate. ",
                      "The 3 percent default contribution treats MAGI as earnings. Above $",
                      formatC(round(endpoint_single_num), format = "d", big.mark = ","),
                      " MAGI the cap is unreachable.")
  ) +
  eig_tufte_theme

fig2_png_path_chr <- file.path(path_output_figs_chr, "lens_02_required_contribution.png")
ggplot2::ggsave(fig2_png_path_chr, fig2_gg,
                width = fig_width_in_num, height = fig_height_in_num,
                dpi = 300, units = "in")
message("Wrote: ", fig2_png_path_chr)

###################################################################################
###             8) Figure 3: Required Contribution as Share of Earnings         ###
###################################################################################
fig3_data_tbl <- lens_tbl |>
  dplyr::filter(magi_num <= endpoint_single_num,
                magi_num >= 4000) |>           # below $4K share spikes hyperbolically
  dplyr::mutate(
    required_share_plot_num = dplyr::if_else(
      required_share_num <= required_share_ceiling_num,
      required_share_num, NA_real_),
    truncated_flag = required_share_num > required_share_ceiling_num
  )

# Current-law Saver's Match required-share overlay (Single filer), same $1,000
# cap. Current law pairs a 50% rate with a $2,000 matchable-contribution cap, so
# the $1,000 max credit is reachable ONLY where SM_FACTOR = 1 (MAGI <= the lower
# threshold); above it, even the full $2,000 contribution yields < $1,000, so the
# cap is unreachable (NA) and the line terminates. This contrasts the proposal's
# wide reachability band against current law's narrow one. (Current-law constants
# are defined once in the config block above.)
fig3_curlaw_tbl <- fig3_data_tbl |>
  dplyr::mutate(
    cur_sm_factor_num   = pmax(0, pmin(1, (cur_high_num - magi_num) /
                                          (cur_high_num - cur_low_num))),
    cur_eff_rate_num    = cur_rate_max_num * cur_sm_factor_num,
    cur_req_contrib_num = dplyr::if_else(cur_eff_rate_num > 0,
                                         cur_credit_cap_num / cur_eff_rate_num, NA_real_),
    cur_reachable_lgl   = is.finite(cur_req_contrib_num) &
                            cur_req_contrib_num <= cur_contrib_cap_num,
    cur_required_share_num = dplyr::if_else(cur_reachable_lgl,
                                            cur_req_contrib_num / magi_num, NA_real_),
    cur_required_share_plot_num = dplyr::if_else(
      !is.na(cur_required_share_num) &
        cur_required_share_num <= required_share_ceiling_num,
      cur_required_share_num, NA_real_)
  )

# Single callout at the U-curve minimum (the lowest required share). The label
# also carries the key insight relative to the 3% default: under this design the
# minimum sits above 3%, so the default alone never reaches the cap. (If a future
# anchor pushed the minimum to/under 3%, the wording flips automatically.)
fig3_anchors_tbl <- anchor_tbl |>
  dplyr::filter(anchor_label_chr == "Rate = 100%") |>
  dplyr::mutate(
    label_full_chr = paste0("Lowest required share: ",
                            sprintf("%.1f%%", 100 * required_share_num),
                            " at $", formatC(round(magi_num), format = "d", big.mark = ","),
                            dplyr::if_else(
                              required_share_num <= default_contrib_rate_num,
                              "\n(the 3% default just reaches the cap here)",
                              "\n(above the 3% default at every income)")),
    plot_y_num  = pmin(required_share_num, required_share_ceiling_num),
    nudge_x_num = 0,
    nudge_y_num = 0.024
  )

# Shaded band where the default 3 percent alone suffices -- same as figure 2.
fig3_band_tbl <- default_band_tbl

fig3_gg <- ggplot2::ggplot(fig3_data_tbl, ggplot2::aes(x = magi_num,
                                                       y = required_share_plot_num)) +
  (if (band_exists_lgl) ggplot2::geom_rect(
    data = fig3_band_tbl,
    ggplot2::aes(xmin = band_lo_num, xmax = band_hi_num,
                 ymin = 0, ymax = required_share_ceiling_num),
    fill = color_band_chr, alpha = 0.6, inherit.aes = FALSE
  ) else NULL) +
  # End of the Expanded Policy reachable range: a vertical guide at the endpoint,
  # where the match rate hits 0 and the required share diverges (cap unreachable).
  ggplot2::geom_vline(xintercept = endpoint_single_num,
                      color = color_reference_chr, linetype = "dotted", linewidth = 0.4) +
  # Current-law Saver's Match required-share line (solid gold), drawn beneath the
  # focal Expanded Policy curve so the latter reads on top.
  ggplot2::geom_line(
    data = fig3_curlaw_tbl,
    ggplot2::aes(x = magi_num, y = cur_required_share_plot_num),
    color = color_curlaw_chr, linewidth = 1.0, inherit.aes = FALSE
  ) +
  # Terminal dot where current law's cap reachability ends (the $20,500 lower
  # threshold); above it no contribution can reach the $1,000 cap.
  ggplot2::geom_point(
    data = dplyr::tibble(magi_num  = cur_low_num,
                         share_num = cur_contrib_cap_num / cur_low_num),
    ggplot2::aes(x = magi_num, y = share_num),
    color = color_curlaw_chr, size = 2.2, inherit.aes = FALSE
  ) +
  # Horizontal reference at the 3% behavioral default (neutral gray so it does
  # not compete with the gold current-law policy line).
  ggplot2::geom_hline(
    yintercept = default_contrib_rate_num,
    color = color_default_ref_chr, linetype = "dashed", linewidth = 0.6
  ) +
  ggplot2::geom_line(color = color_series_chr, linewidth = 1.0) +
  ggplot2::geom_point(
    data = fig3_anchors_tbl,
    ggplot2::aes(x = magi_num, y = plot_y_num),
    color = color_anchor_chr, size = 2.2, inherit.aes = FALSE
  ) +
  ggplot2::geom_text(
    data = fig3_anchors_tbl,
    ggplot2::aes(x = magi_num + nudge_x_num,
                 y = plot_y_num + nudge_y_num,
                 label = label_full_chr),
    family = font_body_chr, size = 3.2, color = color_text_chr,
    hjust = 0.5, lineheight = 0.9, inherit.aes = FALSE
  ) +
  # geom_label (not annotate, which silently ignores label.size) with a white
  # fill masks the descending left arm of the U where it brushes the "3%
  # auto-enrollment default" direct label. label.size = 0 drops the border; the
  # small padding keeps the box clear of the dashed gold reference line at 3
  # percent below it.
  ggplot2::geom_label(
    data = dplyr::tibble(x_num = 6000, y_num = default_contrib_rate_num + 0.025),
    ggplot2::aes(x = x_num, y = y_num),
    label = "3% auto-enrollment default",
    color = color_default_ref_chr, family = font_body_chr,
    fontface = "bold", size = 3.2, hjust = 0,
    fill = "white", label.size = 0,
    label.padding = ggplot2::unit(0.1, "lines"),
    inherit.aes = FALSE
  ) +
  # Direct series labels distinguishing the two policy curves. Positions are a
  # first pass; tuned on the render-inspect loop.
  # Direct series labels, placed to avoid each other and the curves:
  #   - "Expanded Policy" on the green curve's steep right arm (upper right).
  #   - "Current-law Saver's Match" above its short gold segment (upper left).
  ggplot2::annotate(
    "text", x = 33000, y = 0.140,
    label = "Expanded Policy",
    color = color_series_chr, family = font_body_chr,
    fontface = "bold", size = 3.2, hjust = 1
  ) +
  ggplot2::annotate(
    "text", x = 7000, y = 0.138,
    label = paste0("Current-law Saver's Match\n(cap reachable only below $",
                   formatC(cur_low_num, format = "d", big.mark = ","), ")"),
    color = color_curlaw_chr, family = font_body_chr,
    fontface = "bold", size = 3.0, hjust = 0, lineheight = 0.9
  ) +
  ggplot2::annotate(
    "text", x = endpoint_single_num - 600, y = 0.052,
    label = paste0("Cap out of reach\nabove $",
                   formatC(round(endpoint_single_num), format = "d", big.mark = ",")),
    color = color_text_chr, family = font_body_chr,
    size = 3.0, hjust = 1, lineheight = 0.9
  ) +
  (if (band_exists_lgl) ggplot2::annotate(
    "text", x = (fig3_band_tbl$band_lo_num + fig3_band_tbl$band_hi_num) / 2,
    y = 0.012,
    label = "Default alone\nreaches the cap",
    color = "#7A5A1A", family = font_body_chr, size = 2.9, hjust = 0.5,
    lineheight = 0.9
  ) else NULL) +
  ggplot2::scale_x_continuous(
    labels = scales::label_dollar(scale = 1, accuracy = 1, big.mark = ","),
    breaks = c(0, 10000, 20000, 30000, 40000),
    limits = c(0, endpoint_single_num + 500),
    expand = ggplot2::expansion(mult = c(0.01, 0.01))
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::label_percent(accuracy = 1),
    breaks = seq(0, 0.15, by = 0.03),
    limits = c(0, required_share_ceiling_num),
    expand = ggplot2::expansion(mult = c(0, 0.02))
  ) +
  ggplot2::labs(
    title    = "Figure 6. The Expanded Policy keeps the cap reachable far past current law",
    subtitle = paste0("Required contribution as a share of earnings to reach the $1,000 cap, ",
                      filing_group_label_chr, " filer"),
    x        = "Modified adjusted gross income (MAGI), treated as earnings",
    y        = "Required contribution share",
    caption  = paste0("Source: Author's calculation. Required share = ($1,000 / match rate) / earnings. ",
                      "Gold line: current-law Saver's Match (50% rate, $2,000 matchable-contribution cap), ",
                      "under which the $1,000 cap is reachable only below the $",
                      formatC(cur_low_num, format = "d", big.mark = ","),
                      " threshold. Above the pivot the Expanded Policy required share rises rapidly; above $",
                      formatC(round(endpoint_single_num), format = "d", big.mark = ","),
                      " MAGI its cap is unreachable at any contribution.")
  ) +
  eig_tufte_theme

fig3_png_path_chr <- file.path(path_output_figs_chr, "lens_03_required_share_of_earnings.png")
ggplot2::ggsave(fig3_png_path_chr, fig3_gg,
                width = fig_width_in_num, height = fig_height_in_num,
                dpi = 300, units = "in")
message("Wrote: ", fig3_png_path_chr)

###################################################################################
###             9) Anchors Diagnostic Markdown                                  ###
###################################################################################
anchors_md_path_chr <- file.path(path_output_reports_chr, "phaseout_lenses_anchors.md")

anchor_lines_chr <- sprintf(
  "| %s | $%s | %.0f%% | %s | %s |",
  anchor_tbl$anchor_label_chr,
  formatC(round(anchor_tbl$magi_num), format = "d", big.mark = ","),
  anchor_tbl$match_rate_pp_num,
  ifelse(is.na(anchor_tbl$required_contribution_num),
         "Unreachable",
         paste0("$", formatC(round(anchor_tbl$required_contribution_num),
                              format = "d", big.mark = ","))),
  ifelse(is.na(anchor_tbl$required_share_num) |
           anchor_tbl$magi_num == 0,
         "n/a",
         sprintf("%.1f%%", 100 * anchor_tbl$required_share_num))
)

anchors_md_chr <- c(
  "# Phaseout Lens Anchors -- Single Filer",
  "",
  paste0("Generated by `04_06_phaseout_lenses.R` at ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), "."),
  "",
  "The hybrid schedule preserves the $1,000 federal match cap across the eligibility band, but the worker's path to that cap changes continuously with income. This file records the anchor values that the three lens figures call out directly on the panels.",
  "",
  "## Anchors",
  "",
  "| Anchor | MAGI | Match rate | Contribution to reach cap | Required share of earnings |",
  "|---|---|---|---|---|",
  anchor_lines_chr,
  "",
  "## Schedule parameters",
  "",
  paste0("- Pivot (Single): $", formatC(round(pivot_single_num), format = "d", big.mark = ",")),
  paste0("- Endpoint (Single): $", formatC(round(endpoint_single_num), format = "d", big.mark = ",")),
  paste0("- Slope: ", sprintf("%.5f", slope_pp_per_dollar_num),
         " percentage points per dollar of MAGI"),
  paste0("- Floor match rate: ", round(floor_pp_num), " percent at zero MAGI"),
  paste0("- Per-individual cap: $", formatC(match_cap_num, format = "d", big.mark = ",")),
  paste0("- Auto-enrollment default contribution: ",
         sprintf("%.1f%%", 100 * default_contrib_rate_num), " of earnings"),
  "",
  "## Reading the three figures",
  "",
  "Figure 1 plots the match rate -- the subsidy rate phaseout itself, which is what the behavioral literature keys off.",
  "",
  "Figure 2 plots the dollar contribution required to capture the full $1,000 cap, with the 3 percent auto-enrollment default overlaid. Where the default contribution line exceeds the required contribution curve, the cap is reached automatically. Outside that band, the worker must opt up.",
  "",
  "Figure 3 plots the required contribution as a share of earnings. The curve is U-shaped: high at the bottom of the eligibility band (where earnings are too small to support even a small contribution), low in the middle band (where the 3 percent default just unlocks the cap), and rising sharply above the pivot until the cap becomes unreachable at the endpoint.",
  ""
)

writeLines(anchors_md_chr, anchors_md_path_chr)
message("Wrote: ", anchors_md_path_chr)

message("04_06_phaseout_lenses.R complete.")
