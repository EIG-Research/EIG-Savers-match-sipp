# 02b_filing_match_decomposition.R -- filing-status x match-status decomposition.
# Author: Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - How are SM-eligible workers distributed across filing status x match-status cells,
#                     for the full universe, for account holders, and for the access gap?
#
# Reads the ONE canonical modeled frame (data/processed/sipp_modeled.parquet). It no longer rebuilds
# the universe/income/thresholds inline (those came from 02a's mirrored copy before) -- it shares the
# exact same frame as 02a, so the two stages agree by construction and the old runtime reconciliation
# crutch is unnecessary (a light nesting assertion is kept).
#
# Match status (current law, m100), per worker in the universe:
#   "Full Match Below" = is_fullmatch_m100                       (income at/below the lower threshold)
#   "Phaseout Range"   = is_anymatch_m100 & !is_fullmatch_m100   (between lower and upper)
#   "No Match Above"   = in_universe & !is_anymatch_m100         (income at/above the upper threshold)
# Table 1 = full universe; Table 2 = account holders (has_dc_account); Table 3 = access gap (1 - 2).

rm(list = ls())
suppressMessages({ library(dplyr); library(arrow); library(openxlsx) })

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "00_setup", "00_config.R"))

frame_path <- file.path(path_data_processed, "sipp_modeled.parquet")
if (!file.exists(frame_path)) {
  stop("Missing ", frame_path, ". Run 01b_build_modeled_frame.R first.", call. = FALSE)
}
fr <- arrow::read_parquet(frame_path)

filing_labels <- c(single_mfs = "Single", hoh = "Head of Household", mfj = "Married Filing Jointly")
filing_order  <- c("Single", "Head of Household", "Married Filing Jointly")
match_order   <- c("Full Match Below", "Phaseout Range", "No Match Above")

fr <- fr |>
  filter(in_universe, !is.na(filing_group)) |>
  mutate(
    filing_label = filing_labels[filing_group],
    match_status = case_when(
      is_fullmatch_m100 ~ "Full Match Below",
      is_anymatch_m100  ~ "Phaseout Range",
      TRUE              ~ "No Match Above"
    )
  )

# --- Long + wide builders (one definition, reused for all three tables) ---
make_long <- function(df) {
  df |>
    group_by(filing_label, match_status) |>
    summarise(weighted_n = sum(weight, na.rm = TRUE), .groups = "drop") |>
    mutate(millions = round(weighted_n / 1e6, 2))
}
make_wide <- function(long_tbl) {
  m <- matrix(0, nrow = length(filing_order), ncol = length(match_order),
              dimnames = list(filing_order, match_order))
  for (i in seq_len(nrow(long_tbl))) {
    m[long_tbl$filing_label[i], long_tbl$match_status[i]] <- round(long_tbl$millions[i], 2)
  }
  wide <- as.data.frame(m, check.names = FALSE)
  wide$`Row total` <- round(rowSums(wide), 2)
  wide <- cbind(`Filing status` = rownames(wide), wide)
  col_tot <- c("Column total", as.list(round(colSums(wide[, -1, drop = FALSE]), 2)))
  wide <- rbind(wide, setNames(col_tot, names(wide)))
  rownames(wide) <- NULL
  wide
}
build_table <- function(df) list(long = make_long(df), wide = make_wide(make_long(df)))

t1 <- build_table(fr)                            # full universe
t2 <- build_table(filter(fr, has_dc_account))    # account holders
t3 <- build_table(filter(fr, !has_dc_account))   # access gap

# --- Write a workbook (Notes / Wide / Long) + rds/parquet per table ---
write_outputs <- function(tbl, stem, title_chr) {
  saveRDS(tbl$long, file.path(path_output, "tables", paste0(stem, ".rds")))
  arrow::write_parquet(tbl$long, file.path(path_output, "tables", paste0(stem, ".parquet")))
  wb <- createWorkbook()
  addWorksheet(wb, "Notes"); addWorksheet(wb, "Wide"); addWorksheet(wb, "Long")
  notes <- data.frame(
    field = c("Title", "Generated", "Universe", "Income projection", "Thresholds", "Units"),
    value = c(title_chr, format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
              "Age 18+, non-dependent, non-student, earned income, valid filing group",
              sprintf("TY2027 (x%.3f)", sm_params()$income_projection_factor),
              "Statutory 2027 (multiplier m100)", "Weighted millions of workers")
  )
  writeData(wb, "Notes", notes); writeData(wb, "Wide", tbl$wide); writeData(wb, "Long", tbl$long)
  saveWorkbook(wb, file.path(path_output, "tables", paste0(stem, ".xlsx")), overwrite = TRUE)
}

write_outputs(t1, "answers_eligibility_by_filing_match",
              "Workers in the SM-eligibility universe, by filing status x match status")
write_outputs(t2, "answers_eligibility_account_holders_by_filing_match",
              "Account holders in the SM-eligibility universe, by filing status x match status")
write_outputs(t3, "answers_eligibility_access_gap_by_filing_match",
              "Access gap (no qualifying account), by filing status x match status")

# --- Light consistency check: Full Match Below total (Table 1) == 02a Bucket 2 ---
fmb <- as.numeric(t1$wide$`Full Match Below`[t1$wide$`Filing status` == "Column total"])
buckets_path <- file.path(path_output, "tables", "savers_match_eligibility_buckets.rds")
if (file.exists(buckets_path)) {
  b2 <- readRDS(buckets_path)
  b2_overall <- b2$bucket2_millions[b2$group_chr == "Overall"]
  if (abs(fmb - b2_overall) > 0.05) {
    stop(sprintf("02b/02a mismatch: Full Match Below %.2fM vs 02a B2 %.2fM.", fmb, b2_overall), call. = FALSE)
  }
  message("02b: reconciliation OK (Full Match Below ", round(fmb, 2),
          "M == 02a B2 ", round(b2_overall, 2), "M).")
}

message("02b complete.")
print(t1$wide)
