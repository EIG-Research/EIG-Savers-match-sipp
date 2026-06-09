# 02a_eligibility_buckets.R -- Saver's Match three-bucket eligible-population estimates.
# Author: Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - How large is the Saver's Match eligible population (any-match / full-match /
#                     full-match-with-account), overall and by filing status and age band, projected
#                     to TY2027?
#
# This stage reads the ONE canonical modeled frame (data/processed/sipp_modeled.parquet, built by
# 01b_build_modeled_frame.R). It no longer re-derives the income concept, thresholds, or eligibility
# inline -- those are defined once in code/_shared/build_frame.R + params.R. Bucket definitions
# (current law = multiplier m100):
#   bucket1 (any-match)            = is_anymatch_m100               (income below the upper threshold)
#   bucket2 (full-match)           = is_fullmatch_m100              (income at/below the lower threshold)
#   bucket3 (full-match + account) = is_fullmatch_with_account_m100
#   bucket1_any_and_owns           = is_anymatch_with_account_m100
#   universe                       = in_universe (age 18+, non-dependent, non-student, earned income,
#                                    valid filing group)
#
# Income is projected to TY2027 (x1.093) per decision D1 (2026-06-08), so these counts equal the cost
# stage's eligible population by construction.

rm(list = ls())
suppressMessages({ library(dplyr); library(arrow); library(readr) })

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "00_setup", "00_config.R"))

frame_path <- file.path(path_data_processed, "sipp_modeled.parquet")
if (!file.exists(frame_path)) {
  stop("Missing ", frame_path, ". Run code/01_data_preparation/01b_build_modeled_frame.R first.",
       call. = FALSE)
}
fr <- arrow::read_parquet(frame_path)

# --- Bucket flags (current law, m100) + age band ---
fr <- fr |>
  mutate(
    bucket1_any_match     = is_anymatch_m100,
    bucket2_full_match    = is_fullmatch_m100,
    bucket3_full_and_owns = is_fullmatch_with_account_m100,
    bucket1_any_and_owns  = is_anymatch_with_account_m100,
    age_band = case_when(
      age >= 18 & age <= 29 ~ "18-29",
      age >= 30 & age <= 49 ~ "30-49",
      age >= 50 & age <= 64 ~ "50-64",
      age >= 65             ~ "65+",
      TRUE ~ NA_character_
    )
  )

# --- One summarizer used for every grouping (no duplicated count logic) ---
summarise_buckets <- function(df, group_chr, subgroup_chr) {
  tibble::tibble(
    group_chr = group_chr,
    subgroup_chr = subgroup_chr,
    bucket1_weighted_n              = sum(df$weight * df$bucket1_any_match,     na.rm = TRUE),
    bucket2_weighted_n              = sum(df$weight * df$bucket2_full_match,    na.rm = TRUE),
    bucket3_weighted_n              = sum(df$weight * df$bucket3_full_and_owns, na.rm = TRUE),
    bucket1_any_and_owns_weighted_n = sum(df$weight * df$bucket1_any_and_owns, na.rm = TRUE),
    universe_weighted_n             = sum(df$weight * df$in_universe,           na.rm = TRUE)
  )
}

build_bucket_table <- function(df) {
  overall <- summarise_buckets(df, "Overall", "All")
  by_filing <- df |>
    filter(!is.na(filing_group)) |>
    group_split(filing_group) |>
    lapply(function(g) summarise_buckets(g, "Filing status", g$filing_group[1])) |>
    bind_rows()
  by_age <- df |>
    filter(!is.na(age_band)) |>
    group_split(age_band) |>
    lapply(function(g) summarise_buckets(g, "Age band", g$age_band[1])) |>
    bind_rows()
  bind_rows(overall, by_filing, by_age) |>
    mutate(
      bucket1_millions = round(bucket1_weighted_n / 1e6, 2),
      bucket2_millions = round(bucket2_weighted_n / 1e6, 2),
      bucket3_millions = round(bucket3_weighted_n / 1e6, 2),
      bucket1_any_and_owns_millions = round(bucket1_any_and_owns_weighted_n / 1e6, 2),
      universe_millions = round(universe_weighted_n / 1e6, 2)
    )
}

# --- Worker basis: each adult counted once ---
buckets_worker <- build_bucket_table(fr)

# --- Filer basis: collapse each resolved MFJ couple to one filer (lower PNUM of the pair) ---
fr_filer <- fr |>
  filter(filing_group != "mfj" | is.na(spouse_pnum) | pnum < spouse_pnum)
buckets_filer <- build_bucket_table(fr_filer)

# --- Sanity: nesting B1 >= B2 >= B3 on the Overall row ---
ov <- buckets_worker[buckets_worker$group_chr == "Overall", ]
stopifnot(ov$bucket1_weighted_n >= ov$bucket2_weighted_n,
          ov$bucket2_weighted_n >= ov$bucket3_weighted_n)

# --- Save ---
saveRDS(buckets_worker, file.path(path_output, "tables", "savers_match_eligibility_buckets.rds"))
arrow::write_parquet(buckets_worker, file.path(path_output, "tables", "savers_match_eligibility_buckets.parquet"))
saveRDS(buckets_filer, file.path(path_output, "tables", "savers_match_eligibility_buckets_filerbasis.rds"))
arrow::write_parquet(buckets_filer, file.path(path_output, "tables", "savers_match_eligibility_buckets_filerbasis.parquet"))

# --- Plain-English memo report ---
report_path <- file.path(path_output, "reports", "savers_match_eligibility_buckets.md")
ov_m <- buckets_worker[buckets_worker$group_chr == "Overall", ]
report_lines <- c(
  "# Saver's Match eligibility buckets (TY2027)",
  "",
  sprintf("_Generated %s. Income projected to TY2027 (x%.3f); statutory 2027 thresholds._",
          format(Sys.time(), "%Y-%m-%d"), sm_params()$income_projection_factor),
  "",
  sprintf("- **Universe:** %.2f million workers (age 18+, non-dependent, non-student, with earned income).", ov_m$universe_millions),
  sprintf("- **Bucket 1 (any-match eligible):** %.2f million.", ov_m$bucket1_millions),
  sprintf("- **Bucket 2 (full-match eligible):** %.2f million.", ov_m$bucket2_millions),
  sprintf("- **Bucket 3 (full-match eligible with a qualifying account):** %.2f million.", ov_m$bucket3_millions),
  sprintf("- **Access gap (any-match eligible without a qualifying account):** %.2f million.",
          round(ov_m$bucket1_millions - ov_m$bucket1_any_and_owns_millions, 2)),
  "",
  "Counts are weighted (SIPP 2024 Wave 1 person weights) and equal the cost stage's eligible",
  "population at current-law thresholds (multiplier m100) by construction."
)
writeLines(report_lines, report_path)

message("02a complete. Overall: B1=", round(ov_m$bucket1_millions,2), "M  B2=",
        round(ov_m$bucket2_millions,2), "M  B3=", round(ov_m$bucket3_millions,2), "M.")
