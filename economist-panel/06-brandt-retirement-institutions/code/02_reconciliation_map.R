# ============================================================================
# 02_reconciliation_map.R
# Panelist 06 (Brandt): match-delivery reconciliation mechanics.
#
# The hybrid match is min(rate(MAGI) x contribution, $1,000) per individual.
# Contributions flow through payroll all year; the match rate is a linear
# function of MAGI that is only known at tax filing. This script sizes the
# populations that need each administrative process:
#   - cap-binding workers (match = $1,000): buffered against marginal MAGI news
#   - sub-cap workers: every dollar of MAGI revision moves the match
#   - near-endpoint workers: modest MAGI surprises zero out the match entirely
#   - self-employed: no payroll rail, contributions only verifiable at filing
#   - all participants: section 6433(d)(2) distribution-recapture testing
#     (3-year lookback), which the simulation does not model.
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/06-brandt-retirement-institutions/code/02_reconciliation_map.R
#
# Outputs: tables/reconciliation_process_map.csv
#          figures/fig3_reconciliation_exposure.png
# ============================================================================

suppressMessages({
  library(arrow)
  library(dplyr)
  library(ggplot2)
  library(scales)
})

out_tab <- "economist-panel/06-brandt-retirement-institutions/tables"
out_fig <- "economist-panel/06-brandt-retirement-institutions/figures"

d <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
cat("Pivot table:\n"); print(as.data.frame(piv))

# Identify pivot/endpoint columns robustly
pivot_col    <- names(piv)[grepl("pivot", names(piv), ignore.case = TRUE) & sapply(piv, is.numeric)][1]
endpoint_col <- names(piv)[grepl("end",   names(piv), ignore.case = TRUE) & sapply(piv, is.numeric)][1]
group_col    <- names(piv)[sapply(piv, is.character)][1]
stopifnot(!is.na(pivot_col), !is.na(endpoint_col), !is.na(group_col))

piv_small <- piv %>%
  select(filing_group_chr = all_of(group_col),
         pivot = all_of(pivot_col),
         endpoint = all_of(endpoint_col))

d <- d %>% left_join(piv_small, by = "filing_group_chr")
stopifnot(!any(is.na(d$pivot)))

wM <- function(cond) sum(d$WPFINWGT[cond], na.rm = TRUE) / 1e6

elig <- d$eligible_flag
se   <- !is.na(d$self_employed_flag) & d$self_employed_flag

# Match schedule: rate_frac = 2.0 - (1.5 / pivot) * MAGI, floored at 0.
# Slope of the match-rate (fraction) in MAGI: -1.5/pivot per dollar.
# For sub-cap workers, d(match)/d(MAGI) = -(1.5/pivot) * contribution.
d <- d %>%
  mutate(
    cap_binding   = eligible_flag & match_per_worker_num >= 999.999,
    sub_cap       = eligible_flag & match_per_worker_num > 0 & match_per_worker_num < 999.999,
    dmatch_per_1k = ifelse(sub_cap, (1.5 / pivot) * default_contrib_num * 1000, NA_real_),
    near_endpoint = eligible_flag & (endpoint - magi_num) <= 2000
  )

# Weighted quantiles of |d(match)| per +$1,000 MAGI revision among sub-cap eligibles
wq <- function(x, w, p) {
  o <- order(x); x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  sapply(p, function(pp) x[which(cw >= pp)[1]])
}
sc <- d %>% filter(sub_cap)
qs <- wq(sc$dmatch_per_1k, sc$WPFINWGT, c(.25, .5, .75, .9))
cat(sprintf("\n|d match| per $1,000 MAGI revision, sub-cap eligibles: p25=$%.0f p50=$%.0f p75=$%.0f p90=$%.0f\n",
            qs[1], qs[2], qs[3], qs[4]))

# ---------------------------------------------------------------------------
# Reconciliation process map table
# ---------------------------------------------------------------------------
recon <- tibble::tribble(
  ~population, ~workers_m, ~administrative_process_required,
  "All match-eligible workers (rate strictly in (0,200))",
  wM(elig & d$match_rate_pp_num > 0 & d$match_rate_pp_num < 200),
  "Year-end MAGI determination at tax filing; match computed after return processed; Treasury deposit 'as soon as practicable' (one-year lag behind contributions)",

  "Sub-cap eligibles (match < $1,000; match moves dollar-for-dollar with MAGI realization)",
  wM(d$sub_cap),
  paste0("Full true-up: every dollar of difference between payroll-period income and filed MAGI changes the match; median exposure $",
         round(qs[2], 0), " per $1,000 MAGI revision (p75 $", round(qs[3], 0), ")"),

  "Cap-binding eligibles (match = $1,000; locally insensitive to MAGI news)",
  wM(d$cap_binding),
  "No marginal true-up needed unless MAGI revision is large enough to unbind the cap; simplest cohort to administer",

  "Near-endpoint eligibles (MAGI within $2,000 of the zero-match endpoint)",
  wM(d$near_endpoint),
  "Cliff-adjacent: a modest MAGI surprise (bonus, second job, spouse earnings) zeroes the match; full clawback/denial processing after contributions were already deposited",

  "Self-employed eligibles in the universal account (no payroll rail)",
  wM(elig & se & d$route_chr == "universal_account"),
  "No employer withholding: contributions must flow via quarterly estimated-tax rails or annual reconciliation; income observed only at filing - both sides of min(rate x contrib, $1,000) unknown until April",

  "All participating eligibles: section 6433(d)(2) distribution recapture",
  wM(elig),
  "3-year lookback netting prior distributions against qualified contributions (simulation does not model this); requires cross-plan, cross-year information returns (1099-R matching) before any match is paid",

  "Non-eligible auto-enrolled defaulters (account servicing only, no match)",
  wM(!elig),
  "Account opening, payroll remittance, statements, opt-out processing - no match reconciliation, but full recordkeeping cost"
)

recon <- recon %>% mutate(workers_m = round(workers_m, 2))
write.csv(recon, file.path(out_tab, "reconciliation_process_map.csv"), row.names = FALSE)
cat("\nWrote reconciliation_process_map.csv\n")
print(as.data.frame(recon[, 1:2]))

# ---------------------------------------------------------------------------
# Figure 3: reconciliation exposure
# ---------------------------------------------------------------------------
fig3_dat <- sc %>%
  filter(dmatch_per_1k <= 300) %>%
  mutate(fg = recode(filing_group_chr,
                     single_mfs = "Single / MFS",
                     mfj = "Married filing jointly",
                     hoh = "Head of household"))

p3 <- ggplot(fig3_dat, aes(x = dmatch_per_1k, weight = WPFINWGT / 1e6, fill = fg)) +
  geom_histogram(binwidth = 10, boundary = 0, color = "white", linewidth = 0.2) +
  geom_vline(xintercept = qs[2], linetype = "dashed", color = "#D34917") +
  annotate("text", x = qs[2] + 6, y = Inf, vjust = 1.6, hjust = 0, size = 3.4,
           color = "#D34917",
           label = sprintf("Median: $%.0f of match moves\nper $1,000 of MAGI revision", qs[2])) +
  scale_fill_manual(values = c("Single / MFS" = "#164C87",
                               "Married filing jointly" = "#5E9C86",
                               "Head of household" = "#E1AD28")) +
  scale_x_continuous(labels = label_dollar(), breaks = seq(0, 120, 20)) +
  coord_cartesian(xlim = c(0, 125)) +
  scale_y_continuous(labels = label_number(suffix = "M")) +
  labs(
    title = "Figure 3. 40 million matches that cannot be finalized until the tax return arrives",
    subtitle = "Change in federal match per +$1,000 MAGI revision, 40.3M sub-cap match-eligible workers, TY2027",
    x = "Dollars of match gained or lost per $1,000 revision to filed MAGI",
    y = "Workers (millions, WPFINWGT-weighted)",
    fill = NULL,
    caption = "Source: Author's calculations from EIG universal-hybrid simulation (SIPP 2024 projected to TY2027), 2026.\nExposure = (1.5 / pivot) x default contribution x $1,000 for workers below the $1,000 cap. X-axis truncated at $125 (>99.8 percent of workers shown)."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.minor = element_blank(),
    panel.grid.major.x = element_blank(),
    legend.position = "top",
    plot.title = element_text(face = "bold", size = 13),
    plot.caption = element_text(size = 7.5, color = "grey30", hjust = 0),
    plot.title.position = "plot"
  )

ggsave(file.path(out_fig, "fig3_reconciliation_exposure.png"), p3,
       width = 9.5, height = 5.8, dpi = 200)
cat("Wrote fig3_reconciliation_exposure.png\n")

cat("Share of sub-cap workers shown (exposure <= $125):",
    sum(sc$WPFINWGT[sc$dmatch_per_1k <= 125]) / sum(sc$WPFINWGT), "\n")
cat("Done.\n")
