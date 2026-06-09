# 04_01_build_universe -- Universal Saver's Match hybrid: analysis universe.
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - Restrict the canonical modeled frame to the analysis universe (age 18+,
#                     non-dependent, non-student, earned income, valid filing group) and emit the
#                     December person frame consumed by 04_02-06.
#
# UNIVERSE: identical to the Saver's Match simulations (`in_universe` in the canonical frame, ALL classes
# of worker including government). The hypothetical universal-account hybrid is not restricted to
# private-sector + self-employed workers; the private/self-employed flags are carried only to drive the
# employer-plan vs. universal-account ROUTING in 04_03, not to filter the population.
#
# This sub-script READS the ONE canonical modeled frame (data/processed/sipp_modeled.parquet) rather
# than re-deriving Option-B income, the U1 spouse-pair join, and the access flags from raw SIPP. Income
# is on the TY2027 basis (decision D1, projected x1.093), so the hybrid shares the repo-wide dollar basis.
#
# Inputs:  data/processed/sipp_modeled.parquet (01b_build_modeled_frame.R)
# Outputs: data/processed/universal_sm_hybrid/universe_dec.{rds,parquet}
#          output/reports/universal_sm_hybrid/universe_funnel.csv

rm(list = ls())
suppressPackageStartupMessages({ library(dplyr); library(readr); library(arrow) })

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "00_setup", "00_config.R"))

path_data_processed_chr <- file.path(path_data_processed, "universal_sm_hybrid")
path_output_reports_chr <- file.path(path_output, "reports", "universal_sm_hybrid")
if (!dir.exists(path_data_processed_chr)) dir.create(path_data_processed_chr, recursive = TRUE)
if (!dir.exists(path_output_reports_chr)) dir.create(path_output_reports_chr, recursive = TRUE)

frame_path <- file.path(path_data_processed, "sipp_modeled.parquet")
if (!file.exists(frame_path)) stop("Missing ", frame_path, ". Run 01b_build_modeled_frame.R first.", call. = FALSE)
fr <- arrow::read_parquet(frame_path)

# --- Construction funnel (same Saver's Match universe; ends at valid filing group) ---
funnel <- function(label, mask) {
  data.frame(step_label_chr = label,
             unweighted_n_int = sum(mask, na.rm = TRUE),
             weighted_n_num = sum(fr$weight[mask], na.rm = TRUE))
}
m1 <- rep(TRUE, nrow(fr))
m2 <- m1 & fr$age >= 18L
m3 <- m2 & !fr$is_dependent
m4 <- m3 & !fr$is_student
m5 <- m4 & fr$has_earned_income
m6 <- m5 & !is.na(fr$filing_group)   # = in_universe; the Saver's Match analysis universe (all worker classes)
funnel_steps_tbl <- bind_rows(
  funnel("01_total_december_persons", m1), funnel("02_age_18_plus", m2),
  funnel("03_not_dependent", m3), funnel("04_not_full_time_student", m4),
  funnel("05_has_annual_earned_income", m5), funnel("06_valid_filing_group", m6)
)
funnel_steps_tbl$step_id_int <- seq_len(nrow(funnel_steps_tbl))
write_csv(funnel_steps_tbl, file.path(path_output_reports_chr, "universe_funnel.csv"))

# --- Materialize the analysis universe (= in_universe) with the column contract 04_02-06 read ---
# Income columns are TY2027-projected; access/worker-class flags come straight from the canonical frame.
# Worker-class flags are kept for ROUTING in 04_03 only (not as a population filter).
universe_tbl <- fr[which(m6), ] |>
  transmute(
    SSUID = ssuid, PNUM = pnum, WPFINWGT = weight, EFSTATUS = efstatus, TAGE = age,
    filing_group_chr = filing_group,
    magi_num = sm_income_2027,                 # TY2027 MAGI (was sm_magi_2024_num)
    earnings_num = earnings_2027,              # TY2027 personal earnings (was tpearn_annual_num)
    has_existing_dc_flag = has_dc_account,
    participating_dc_flag = is_participating_dc,
    any_retirement_access_v2_chr = any_retirement_access,
    private_sector_employee_flag = is_private_sector_employee,
    self_employed_flag = is_self_employed
  )

saveRDS(universe_tbl, file.path(path_data_processed_chr, "universe_dec.rds"))
write_parquet(universe_tbl, file.path(path_data_processed_chr, "universe_dec.parquet"), compression = "snappy")
message(sprintf("04_01 complete. Hybrid universe: %d rows, weighted %.2fM.",
                nrow(universe_tbl), sum(universe_tbl$WPFINWGT, na.rm = TRUE) / 1e6))

# ---------------------------------------------------------------------------
# Weighted summary-statistics + missingness diagnostic for the analysis universe.
# Documents the population the cost/incidence estimates rest on (overall and by
# filing group): counts, weighted income/age, and the missingness of the access
# and participation flags that drive routing and the headline behavioral rate.
# ---------------------------------------------------------------------------
wmean_num <- function(x, w) {
  ok <- !is.na(x) & !is.na(w)
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}
wmedian_num <- function(x, w) {
  ok <- !is.na(x) & !is.na(w) & w > 0
  if (!any(ok)) return(NA_real_)
  x <- x[ok]; w <- w[ok]; o <- order(x); x <- x[o]; w <- w[o]
  x[which(cumsum(w) >= 0.5 * sum(w))[1]]
}
summarise_universe <- function(d, label_chr) {
  data.frame(
    group_chr                = label_chr,
    n_unweighted_int         = nrow(d),
    weighted_M_num           = round(sum(d$WPFINWGT, na.rm = TRUE) / 1e6, 2),
    mean_magi_num            = round(wmean_num(d$magi_num, d$WPFINWGT)),
    median_magi_num          = round(wmedian_num(d$magi_num, d$WPFINWGT)),
    mean_earnings_num        = round(wmean_num(d$earnings_num, d$WPFINWGT)),
    mean_age_num             = round(wmean_num(d$TAGE, d$WPFINWGT), 1),
    pct_participating_dc_na  = round(100 * mean(is.na(d$participating_dc_flag)), 1),
    pct_access_missing       = round(100 * mean(d$any_retirement_access_v2_chr == "Missing", na.rm = TRUE), 1),
    pct_has_dc               = round(100 * mean(d$has_existing_dc_flag %in% TRUE), 1),
    stringsAsFactors         = FALSE
  )
}
summary_stats_tbl <- rbind(
  summarise_universe(universe_tbl, "All"),
  do.call(rbind, lapply(sort(unique(universe_tbl$filing_group_chr)), function(g)
    summarise_universe(universe_tbl[universe_tbl$filing_group_chr == g, ], g)))
)
write_csv(summary_stats_tbl,
          file.path(path_output_reports_chr, "universe_summary_stats.csv"))

ss_md_chr <- c(
  "# Hybrid Analysis Universe -- Summary Statistics",
  "",
  sprintf("Computed at: %s", as.character(Sys.time())),
  "",
  "Weighted summary of the analysis universe (age 18+, non-dependent, non-student, positive earned income, valid filing group; all worker classes). MAGI and earnings are TY2027-projected dollars. Missingness columns flag the share of rows with no determinable participation/access signal.",
  "",
  "| Group | N (unwt.) | Weighted (M) | Mean MAGI | Median MAGI | Mean earnings | Mean age | % participating-DC NA | % access missing | % holds DC |",
  "|---|---|---|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(summary_stats_tbl))) {
  r <- summary_stats_tbl[i, ]
  ss_md_chr <- c(ss_md_chr, sprintf(
    "| %s | %d | %.2f | $%s | $%s | $%s | %.1f | %.1f%% | %.1f%% | %.1f%% |",
    r$group_chr, r$n_unweighted_int, r$weighted_M_num,
    formatC(r$mean_magi_num, format = "d", big.mark = ","),
    formatC(r$median_magi_num, format = "d", big.mark = ","),
    formatC(r$mean_earnings_num, format = "d", big.mark = ","),
    r$mean_age_num, r$pct_participating_dc_na, r$pct_access_missing, r$pct_has_dc
  ))
}
writeLines(ss_md_chr, file.path(path_output_reports_chr, "universe_summary_stats.md"))
message("04_01: wrote universe_summary_stats.{csv,md}.")
