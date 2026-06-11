# ----------------------------------------------------------------------------
# 01_emtr_profile.R -- Implicit EMTR profile of the hybrid Saver's Match
# Panelist: Raghunathan (optimal tax). Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/04-raghunathan-optimal-tax/code/01_emtr_profile.R
#
# Derives the implicit marginal tax rate the redesigned match schedule imposes
# through benefit phase-out (-d(benefit)/d(MAGI), contribution held fixed) for
# a worker contributing the 3 percent default, along the earnings = MAGI
# diagonal, by filing group. Compares against the current-law section 6433
# linear phaseout for a $2,000 contributor and for the same 3 percent
# contributor. Pivots and slopes are read from the repo's pivot table.
# ----------------------------------------------------------------------------

suppressMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

out_dir_fig <- "economist-panel/04-raghunathan-optimal-tax/figures"
out_dir_tab <- "economist-panel/04-raghunathan-optimal-tax/tables"

pivot_tbl <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")

# Named pivot vector, hybrid schedule: rate(M) = clamp(200 - (150/P) * M, 0, 200)
pivots <- setNames(pivot_tbl$pivot_num, pivot_tbl$filing_group_chr)

# Current-law section 6433 TY2027 phaseout ranges (linear 50% -> 0%):
cl_ranges <- tibble(
  filing_group_chr = c("single_mfs", "hoh", "mfj"),
  cl_lo = c(20500, 30750, 41000),
  cl_hi = c(35500, 53250, 71000)
)

group_labels <- c(
  single_mfs = "Single / MFS",
  hoh        = "Head of household",
  mfj        = "Married filing jointly (single earner)"
)

contrib_rate <- 0.03

# --- Build the diagonal grid (earnings = MAGI) -------------------------------
grid <- pivot_tbl %>%
  select(filing_group_chr, pivot_num, endpoint_num) %>%
  rowwise() %>%
  mutate(grid = list(seq(0, ceiling(endpoint_num * 1.15 / 250) * 250, by = 250))) %>%
  unnest(grid) %>%
  ungroup() %>%
  rename(magi = grid) %>%
  mutate(
    earnings   = magi,
    contrib    = contrib_rate * earnings,
    rate_pp    = pmin(200, pmax(0, 200 - (150 / pivot_num) * magi)),
    unbounded  = rate_pp / 100 * contrib,
    benefit    = pmin(1000, unbounded),
    cap_binds  = unbounded >= 1000,
    # Phaseout EMTR adder: -d(benefit)/d(MAGI), contribution held fixed.
    # Zero where the cap binds or the rate is zero; else 150 * c / P (in pp).
    emtr_phaseout_pp = if_else(cap_binds | rate_pp <= 0, 0, 150 * contrib / pivot_num),
    # Net total derivative along the diagonal (marginal contribution subsidy
    # minus phaseout): positive value = net subsidy at the margin.
    net_subsidy_pp = if_else(cap_binds | rate_pp <= 0, 0,
                             100 * (contrib_rate * rate_pp / 100) - emtr_phaseout_pp)
  )

# --- Current-law comparison lines on the same grid ---------------------------
grid <- grid %>%
  left_join(cl_ranges, by = "filing_group_chr") %>%
  mutate(
    cl_rate_frac = case_when(
      magi <= cl_lo ~ 0.50,
      magi >= cl_hi ~ 0,
      TRUE ~ 0.50 * (cl_hi - magi) / (cl_hi - cl_lo)
    ),
    # $2,000 contributor under current law: EMTR = 0.5*2000/(hi-lo) inside band
    cl_emtr_2000_pp = if_else(magi > cl_lo & magi < cl_hi,
                              100 * 0.50 * 2000 / (cl_hi - cl_lo), 0),
    # 3 percent default contributor under current law (contribution capped at $2,000)
    cl_contrib = pmin(2000, contrib_rate * earnings),
    cl_emtr_default_pp = if_else(magi > cl_lo & magi < cl_hi,
                                 100 * 0.50 * cl_contrib / (cl_hi - cl_lo), 0)
  )

# --- Summary table by filing group -------------------------------------------
emtr_summary <- grid %>%
  group_by(filing_group_chr) %>%
  summarise(
    pivot_magi              = first(pivot_num),
    endpoint_magi           = first(endpoint_num),
    rate_slope_pp_per_1000  = 150 / first(pivot_num) * 1000,
    cap_binds_anywhere      = any(cap_binds),
    cap_region_lo           = if (any(cap_binds)) min(magi[cap_binds]) else NA_real_,
    cap_region_hi           = if (any(cap_binds)) max(magi[cap_binds]) else NA_real_,
    emtr_at_pivot_pp        = emtr_phaseout_pp[which.min(abs(magi - first(pivot_num)))],
    peak_emtr_pp            = max(emtr_phaseout_pp),
    peak_emtr_magi          = magi[which.max(emtr_phaseout_pp)],
    cl_emtr_2000_pp         = max(cl_emtr_2000_pp),
    cl_band_lo              = first(cl_lo),
    cl_band_hi              = first(cl_hi),
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 2)))

write.csv(emtr_summary, file.path(out_dir_tab, "emtr_profile_summary.csv"),
          row.names = FALSE)
cat("--- EMTR profile summary (3 percent default contributor, earnings = MAGI) ---\n")
print(as.data.frame(emtr_summary))

# Spot checks against the analytical form
stopifnot(
  abs(grid$emtr_phaseout_pp[grid$filing_group_chr == "single_mfs" &
                              grid$magi == 43750] - 150 * 0.03 * 43750 / pivots["single_mfs"]) < 1e-8
)

# --- Figure 1: EMTR profile by filing group ----------------------------------
plot_df <- grid %>%
  mutate(group_lab = factor(group_labels[filing_group_chr], levels = group_labels))

cap_shade <- plot_df %>%
  filter(cap_binds) %>%
  group_by(group_lab) %>%
  summarise(xmin = min(magi), xmax = max(magi), .groups = "drop")

fig1 <- ggplot(plot_df, aes(x = magi)) +
  geom_rect(data = cap_shade,
            aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf),
            inherit.aes = FALSE, fill = "#f6e8c3", alpha = 0.6) +
  geom_line(aes(y = cl_emtr_2000_pp,
                colour = "Current law §6433, $2,000 contributor"),
            linewidth = 0.7, linetype = "22") +
  geom_line(aes(y = cl_emtr_default_pp,
                colour = "Current law §6433, 3% default contributor"),
            linewidth = 0.7, linetype = "42") +
  geom_line(aes(y = emtr_phaseout_pp,
                colour = "Hybrid proposal, 3% default contributor"),
            linewidth = 1.1) +
  facet_wrap(~ group_lab, ncol = 1, scales = "free_x") +
  scale_colour_manual(NULL, values = c(
    "Hybrid proposal, 3% default contributor"          = "#1b6e8c",
    "Current law §6433, $2,000 contributor"       = "#c23b22",
    "Current law §6433, 3% default contributor"   = "#8c8c8c"
  )) +
  scale_x_continuous(labels = label_dollar(scale = 1e-3, suffix = "k")) +
  scale_y_continuous(labels = label_number(suffix = " pp")) +
  labs(
    title = "Implicit marginal tax rate from Saver's Match benefit phase-out",
    subtitle = paste0(
      "−d(match)/d(MAGI), contribution held at the 3 percent default, earnings = MAGI diagonal.\n",
      "Shaded band: $1,000 cap binds, so the phase-out adds zero EMTR (MFJ single-earner case only)."),
    x = "Modified adjusted gross income (TY2027 dollars)",
    y = "Implicit EMTR adder (percentage points)",
    caption = paste0("Source: author's calculations from data/processed/universal_sm_hybrid/pivot_table.parquet;\n",
                     "schedule per compute_match_rate() (200% floor, 50% at pivot, zero at 4/3 × pivot). ",
                     "§6433 bands per IRS Notice 2024-65.")
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    strip.text = element_text(face = "bold", hjust = 0)
  )

ggsave(file.path(out_dir_fig, "fig1_emtr_profile_by_filing_group.png"),
       fig1, width = 8.5, height = 9, dpi = 200)
cat("Wrote fig1_emtr_profile_by_filing_group.png\n")

# Key single-point numbers for the assessment text
cat(sprintf("\nSingle filer at endpoint ($%s): EMTR = %.2f pp\n",
            comma(round(pivots["single_mfs"] * 4 / 3)),
            150 * 0.03 * (pivots["single_mfs"] * 4 / 3) / pivots["single_mfs"]))
cat(sprintf("Single filer at pivot ($%s): EMTR = %.2f pp\n",
            comma(round(pivots["single_mfs"])), 150 * 0.03))
cat(sprintf("Max unbounded match, Single diagonal 3%% default: $%.0f at MAGI $%s\n",
            max(grid$unbounded[grid$filing_group_chr == "single_mfs"]),
            comma(grid$magi[grid$filing_group_chr == "single_mfs"][
              which.max(grid$unbounded[grid$filing_group_chr == "single_mfs"])])))
cat(sprintf("Max unbounded match, HoH diagonal 3%% default: $%.0f\n",
            max(grid$unbounded[grid$filing_group_chr == "hoh"])))
mfj_cap <- grid %>% filter(filing_group_chr == "mfj", cap_binds)
cat(sprintf("MFJ single-earner cap plateau: $%s to $%s\n",
            comma(min(mfj_cap$magi)), comma(max(mfj_cap$magi))))
