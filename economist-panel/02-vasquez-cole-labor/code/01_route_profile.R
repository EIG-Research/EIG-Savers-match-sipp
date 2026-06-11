# 01_route_profile.R -- Who gains first-time access under the hybrid?
# Panelist 02 (Vasquez-Cole). Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/02-vasquez-cole-labor/code/01_route_profile.R
#
# Profiles eligible workers by routing channel (employer plan vs. federal
# universal account), quantifies the "truly excluded" population (no existing
# DC account AND no workplace retirement access), and computes the share of
# full-participation match dollars reaching them.

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

OUT_TAB <- "economist-panel/02-vasquez-cole-labor/tables"
OUT_FIG <- "economist-panel/02-vasquez-cole-labor/figures"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

# ---- weighted quantile helper -----------------------------------------------
wq <- function(x, w, p) {
  ok <- !is.na(x) & !is.na(w)
  x <- x[ok]; w <- w[ok]
  o <- order(x); x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  vapply(p, function(pp) x[which(cw >= pp)[1]], numeric(1))
}

elig <- sim %>% filter(eligible_flag)

# ---- 1. Route profile among the 46.07M eligible workers ---------------------
route_profile <- elig %>%
  group_by(route_chr) %>%
  summarise(
    workers_m        = sum(WPFINWGT) / 1e6,
    earn_p25         = wq(earnings_num, WPFINWGT, 0.25),
    earn_med         = wq(earnings_num, WPFINWGT, 0.50),
    earn_p75         = wq(earnings_num, WPFINWGT, 0.75),
    magi_p25         = wq(magi_num, WPFINWGT, 0.25),
    magi_med         = wq(magi_num, WPFINWGT, 0.50),
    magi_p75         = wq(magi_num, WPFINWGT, 0.75),
    self_emp_share   = sum(WPFINWGT[self_employed_flag %in% TRUE]) / sum(WPFINWGT),
    age_mean         = sum(WPFINWGT * TAGE) / sum(WPFINWGT),
    age_med          = wq(TAGE, WPFINWGT, 0.50),
    share_age_18_29  = sum(WPFINWGT[TAGE <= 29]) / sum(WPFINWGT),
    share_age_30_44  = sum(WPFINWGT[TAGE >= 30 & TAGE <= 44]) / sum(WPFINWGT),
    share_age_45_59  = sum(WPFINWGT[TAGE >= 45 & TAGE <= 59]) / sum(WPFINWGT),
    share_age_60p    = sum(WPFINWGT[TAGE >= 60]) / sum(WPFINWGT),
    mean_match_rate_pp = sum(WPFINWGT * match_rate_pp_num) / sum(WPFINWGT),
    avg_match_fp     = sum(WPFINWGT * match_per_worker_num) / sum(WPFINWGT),
    match_dollars_b  = sum(WPFINWGT * match_per_worker_num) / 1e9,
    .groups = "drop"
  ) %>%
  mutate(share_of_eligible = workers_m / sum(workers_m))

cat("=== Route profile (eligible workers) ===\n")
print(as.data.frame(route_profile), digits = 4)
write.csv(route_profile, file.path(OUT_TAB, "table1_route_profile.csv"), row.names = FALSE)

# ---- 2. Access typology: who gains FIRST-TIME access ------------------------
# Categories among eligible workers:
#   A. Holds an existing DC account
#   B. No DC account, but workplace access = Yes  (access unused)
#   C. No DC account, workplace access = No       (truly excluded)
#   D. No DC account, workplace access = Missing
elig <- elig %>%
  mutate(access_cat = case_when(
    has_existing_dc_flag ~ "A. Has existing DC account",
    any_retirement_access_v2_chr == "Yes" ~ "B. No account, has workplace access",
    any_retirement_access_v2_chr == "No"  ~ "C. Truly excluded: no account, no access",
    TRUE ~ "D. No account, access unknown"
  ))

total_match_b <- sum(elig$WPFINWGT * elig$match_per_worker_num) / 1e9

access_tab <- elig %>%
  group_by(access_cat) %>%
  summarise(
    workers_m       = sum(WPFINWGT) / 1e6,
    earn_med        = wq(earnings_num, WPFINWGT, 0.50),
    magi_med        = wq(magi_num, WPFINWGT, 0.50),
    self_emp_share  = sum(WPFINWGT[self_employed_flag %in% TRUE]) / sum(WPFINWGT),
    age_med         = wq(TAGE, WPFINWGT, 0.50),
    avg_match_fp    = sum(WPFINWGT * match_per_worker_num) / sum(WPFINWGT),
    match_dollars_b = sum(WPFINWGT * match_per_worker_num) / 1e9,
    .groups = "drop"
  ) %>%
  mutate(
    share_of_eligible    = workers_m / sum(workers_m),
    share_of_match_dollars = match_dollars_b / total_match_b
  )

cat("\n=== Access typology among eligible workers ===\n")
print(as.data.frame(access_tab), digits = 4)
cat("\nTotal full-participation match dollars (eligible), $B:", round(total_match_b, 2), "\n")
write.csv(access_tab, file.path(OUT_TAB, "table2_access_typology.csv"), row.names = FALSE)

# Truly excluded, strict and broad
strict <- elig %>% filter(access_cat == "C. Truly excluded: no account, no access")
broad  <- elig %>% filter(access_cat %in% c("C. Truly excluded: no account, no access",
                                            "D. No account, access unknown"))
cat("\nTruly excluded (strict: no DC, access==No):",
    round(sum(strict$WPFINWGT)/1e6, 2), "M;",
    "match $B:", round(sum(strict$WPFINWGT*strict$match_per_worker_num)/1e9, 2),
    "; share of match dollars:",
    percent(sum(strict$WPFINWGT*strict$match_per_worker_num)/1e9/total_match_b, 0.1), "\n")
cat("Truly excluded (broad: incl. access Missing):",
    round(sum(broad$WPFINWGT)/1e6, 2), "M;",
    "match $B:", round(sum(broad$WPFINWGT*broad$match_per_worker_num)/1e9, 2),
    "; share of match dollars:",
    percent(sum(broad$WPFINWGT*broad$match_per_worker_num)/1e9/total_match_b, 0.1), "\n")

# Universe-level context: truly excluded across the whole 145.34M universe
sim2 <- sim %>%
  mutate(truly_excluded = !has_existing_dc_flag & any_retirement_access_v2_chr == "No")
cat("\nUniverse truly excluded (no DC, access==No):",
    round(sum(sim2$WPFINWGT[sim2$truly_excluded])/1e6, 2), "M of",
    round(sum(sim2$WPFINWGT)/1e6, 2), "M universe\n")
cat("Eligible & truly excluded as share of all truly excluded:",
    percent(sum(strict$WPFINWGT) / sum(sim2$WPFINWGT[sim2$truly_excluded]), 0.1), "\n")

# ---- 3. Figure: eligible workers by earnings quintile x access status -------
# Earnings quintiles defined over the FULL 145.34M universe (personal earnings)
uni <- sim %>% arrange(earnings_num) %>%
  mutate(cw = cumsum(WPFINWGT) / sum(WPFINWGT),
         quintile = pmin(5L, findInterval(cw, seq(0, 1, 0.2), left.open = TRUE) ))
qcuts <- uni %>% group_by(quintile) %>% summarise(qmax = max(earnings_num))
cat("\nUniverse earnings quintile upper bounds (TY2027 $):\n"); print(qcuts)

elig_q <- uni %>%
  filter(eligible_flag) %>%
  mutate(access_cat = case_when(
    has_existing_dc_flag ~ "Has existing DC account",
    any_retirement_access_v2_chr == "Yes" ~ "No account, has workplace access",
    any_retirement_access_v2_chr == "No"  ~ "Truly excluded: no account, no access",
    TRUE ~ "No account, access unknown"
  )) %>%
  group_by(quintile, access_cat) %>%
  summarise(workers_m = sum(WPFINWGT)/1e6, .groups = "drop")

elig_q$access_cat <- factor(elig_q$access_cat, levels = c(
  "Has existing DC account",
  "No account, has workplace access",
  "No account, access unknown",
  "Truly excluded: no account, no access"
))

p2 <- ggplot(elig_q, aes(x = factor(quintile), y = workers_m, fill = access_cat)) +
  geom_col(width = 0.72) +
  scale_fill_manual(values = c(
    "Has existing DC account" = "#8c9bab",
    "No account, has workplace access" = "#5b8bb2",
    "No account, access unknown" = "#c9c2b8",
    "Truly excluded: no account, no access" = "#d2553e"
  ), name = NULL) +
  scale_y_continuous(labels = label_number(suffix = "M"), expand = expansion(mult = c(0, 0.05))) +
  labs(
    title = "Who gains first-time access under the hybrid proposal",
    subtitle = "Eligible workers (46.07M) by personal-earnings quintile of the 145.34M-worker universe\nand existing retirement access, tax year 2027",
    x = "Personal-earnings quintile of the full worker universe (1 = lowest)",
    y = "Eligible workers (millions)",
    caption = "Source: Author's calculations from SIPP 2024 projected to TY2027 (EIG universal-account/Saver's Match hybrid\nsimulation, data/processed/universal_sm_hybrid/simulation_results.parquet). Weighted by WPFINWGT."
  ) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    plot.caption = element_text(size = 8, hjust = 0, color = "grey35"),
    plot.title = element_text(face = "bold")
  ) +
  guides(fill = guide_legend(nrow = 2))

ggsave(file.path(OUT_FIG, "fig2_first_time_access_by_quintile.png"),
       p2, width = 9, height = 6.2, dpi = 200)
cat("\nSaved", file.path(OUT_FIG, "fig2_first_time_access_by_quintile.png"), "\n")
