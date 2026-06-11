# ----------------------------------------------------------------------------
# 03_emtr_exposure.R -- Who actually faces the implicit EMTR?
# Panelist: Raghunathan (optimal tax). Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/04-raghunathan-optimal-tax/code/03_emtr_exposure.R
#
# Uses the row-level simulation universe to count weighted workers (and total
# earnings) inside the hybrid eligibility band who face a positive implicit
# EMTR from the match phase-out (cap not binding) versus zero marginal
# exposure (cap binding). Each eligible worker's phaseout EMTR adder is
# 150 * contribution / pivot percentage points (zero where the cap binds),
# using the worker's actual 3 percent default contribution and filing-group
# pivot. Weights: WPFINWGT (millions = /1e6; dollars in billions = /1e9).
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
pivots <- setNames(pivot_tbl$pivot_num, pivot_tbl$filing_group_chr)

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

# Reconcile against headline eligible count (46.07M)
elig_total <- sum(sim$WPFINWGT[sim$eligible_flag], na.rm = TRUE) / 1e6
cat(sprintf("Eligible workers (weighted): %.2f million (headline: 46.07M)\n", elig_total))

work <- sim %>%
  filter(eligible_flag) %>%
  mutate(
    pivot_num = case_when(
      filing_group_chr == "single_mfs" ~ pivots[["single_mfs"]],
      filing_group_chr == "mfj"        ~ pivots[["mfj"]],
      filing_group_chr == "hoh"        ~ pivots[["hoh"]]
    ),
    unbounded_match = match_rate_frac_num * default_contrib_num,
    cap_binds = unbounded_match >= 1000,
    emtr_pp = if_else(cap_binds, 0, 150 * default_contrib_num / pivot_num)
  )

# --- Headline split: zero-EMTR (cap binds) vs positive-EMTR ------------------
split_tbl <- work %>%
  mutate(exposure = if_else(cap_binds,
                            "Cap binds: zero implicit EMTR",
                            "Cap not binding: positive implicit EMTR")) %>%
  group_by(exposure) %>%
  summarise(
    workers_m    = sum(WPFINWGT) / 1e6,
    earnings_b   = sum(WPFINWGT * earnings_num) / 1e9,
    mean_emtr_pp = weighted.mean(emtr_pp, WPFINWGT),
    max_emtr_pp  = max(emtr_pp),
    .groups = "drop"
  ) %>%
  mutate(share_of_eligible = workers_m / sum(workers_m))

# --- By filing group, among the positive-EMTR exposed -------------------------
by_group <- work %>%
  group_by(filing_group_chr) %>%
  summarise(
    eligible_m        = sum(WPFINWGT) / 1e6,
    capped_m          = sum(WPFINWGT[cap_binds]) / 1e6,
    exposed_m         = sum(WPFINWGT[!cap_binds]) / 1e6,
    exposed_share     = exposed_m / eligible_m,
    exposed_earn_b    = sum(WPFINWGT[!cap_binds] * earnings_num[!cap_binds]) / 1e9,
    mean_emtr_exposed = weighted.mean(emtr_pp[!cap_binds], WPFINWGT[!cap_binds]),
    p90_emtr_exposed  = {
      x <- emtr_pp[!cap_binds]; w <- WPFINWGT[!cap_binds]
      o <- order(x); cw <- cumsum(w[o]) / sum(w[o]); x[o][which(cw >= 0.9)[1]]
    },
    .groups = "drop"
  )

exposure_tbl <- bind_rows(
  split_tbl %>% mutate(level = "All eligible") %>%
    rename(group = exposure),
  by_group %>%
    transmute(level = "By filing group (positive-EMTR exposed)",
              group = filing_group_chr,
              workers_m = exposed_m, earnings_b = exposed_earn_b,
              mean_emtr_pp = mean_emtr_exposed,
              max_emtr_pp = NA_real_,
              share_of_eligible = exposed_share)
) %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))

write.csv(exposure_tbl, file.path(out_dir_tab, "emtr_exposure_distribution.csv"),
          row.names = FALSE)
cat("\n--- EMTR exposure split among eligible workers ---\n")
print(as.data.frame(split_tbl))
cat("\n--- By filing group ---\n")
print(as.data.frame(by_group))

# --- EMTR band distribution among the exposed ---------------------------------
bands <- work %>%
  filter(!cap_binds) %>%
  mutate(band = cut(emtr_pp,
                    breaks = c(-0.001, 1, 2, 3, 4, 5, 6, Inf),
                    labels = c("0-1", "1-2", "2-3", "3-4", "4-5", "5-6", "6+"))) %>%
  group_by(band) %>%
  summarise(workers_m = sum(WPFINWGT) / 1e6, .groups = "drop")
cat("\n--- Distribution of EMTR adders among exposed workers (pp bands) ---\n")
print(as.data.frame(bands))

# Workers within $5,000 of their endpoint (where the adder peaks)
near_endpoint <- work %>%
  mutate(endpoint = pivot_num * 4 / 3) %>%
  filter(!cap_binds, magi_num >= endpoint - 5000) %>%
  summarise(workers_m = sum(WPFINWGT) / 1e6,
            mean_emtr = weighted.mean(emtr_pp, WPFINWGT))
cat(sprintf("\nExposed workers within $5,000 below their endpoint: %.2f million, mean adder %.2f pp\n",
            near_endpoint$workers_m, near_endpoint$mean_emtr))

# --- Figure 2: weighted distribution of the implicit EMTR adder ---------------
plot_df <- work %>%
  mutate(group_lab = recode(filing_group_chr,
                            single_mfs = "Single / MFS",
                            hoh = "Head of household",
                            mfj = "Married filing jointly"))

zero_lab <- sprintf("Zero-EMTR mass (cap binds):\n%.1fM workers (%.0f%% of eligible)",
                    split_tbl$workers_m[split_tbl$exposure == "Cap binds: zero implicit EMTR"],
                    100 * split_tbl$share_of_eligible[split_tbl$exposure == "Cap binds: zero implicit EMTR"])

fig2 <- ggplot() +
  geom_histogram(data = filter(plot_df, !cap_binds),
                 aes(x = emtr_pp, weight = WPFINWGT / 1e6, fill = group_lab),
                 breaks = seq(0, 6.25, by = 0.25), colour = "white", linewidth = 0.2) +
  geom_col(data = plot_df %>% filter(cap_binds) %>%
             summarise(workers = sum(WPFINWGT) / 1e6) %>%
             mutate(x = -0.45),
           aes(x = x, y = workers), width = 0.35, fill = "#b8b8b8") +
  annotate("text", x = -0.45, y = 4.4, label = zero_lab,
           size = 2.9, hjust = 0, lineheight = 1.0) +
  scale_fill_manual(NULL, values = c(
    "Single / MFS" = "#1b6e8c",
    "Head of household" = "#e0a526",
    "Married filing jointly" = "#7a4f9e"
  )) +
  scale_x_continuous(breaks = seq(0, 6, 1),
                     labels = label_number(suffix = " pp")) +
  labs(
    title = "Who faces the hybrid match phase-out? Weighted distribution of the implicit EMTR adder",
    subtitle = paste0("Eligible workers (46.1M), 3 percent default contribution. Gray bar at left: workers whose $1,000 cap binds,\n",
                      "for whom the phase-out adds zero marginal tax. Adder = 150 × contribution / pivot (pp per dollar of MAGI × 100)."),
    x = "Implicit EMTR adder from match phase-out (percentage points)",
    y = "Workers (millions per 0.25-pp bin)",
    caption = paste0("Source: author's calculations from data/processed/universal_sm_hybrid/simulation_results.parquet and pivot_table.parquet;\n",
                     "weights WPFINWGT (SIPP 2024 projected to TY2027).")
  ) +
  theme_minimal(base_size = 11) +
  theme(
    legend.position = "bottom",
    plot.title = element_text(face = "bold", size = 11.5),
    panel.grid.minor = element_blank()
  )

ggsave(file.path(out_dir_fig, "fig2_emtr_exposure_distribution.png"),
       fig2, width = 9.5, height = 6.5, dpi = 200)
cat("Wrote fig2_emtr_exposure_distribution.png\n")
