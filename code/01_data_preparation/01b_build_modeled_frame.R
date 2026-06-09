# 01b_build_modeled_frame.R -- build the ONE canonical modeled SIPP frame.
# Author: Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - Construct the single person-level (December reference-month) modeled frame that
#                     every downstream stage (02 eligibility, 03 cost, 04 hybrid) reads, so the income
#                     concept, thresholds, eligibility, and access flags are defined exactly once.
#
# Reads:  data/raw/pu2024_expanded.csv  (58-col SIPP extract from 01_sipp_subset_from_dta.R)
# Writes: data/processed/sipp_modeled.parquet, data/processed/sipp_modeled.rds
#         data/processed/params.json  (single source of truth, for non-R consumers)

rm(list = ls())
suppressMessages({
  library(dplyr); library(readr); library(arrow); library(Hmisc)
})

# Bootstrap: paths + params + helpers + build_modeled_frame()
source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "00_setup", "00_config.R"))

expanded_csv <- file.path(path_data_raw, "pu2024_expanded.csv")
if (!file.exists(expanded_csv)) {
  stop("Missing ", expanded_csv, ". Run code/01_data_preparation/01_sipp_subset_from_dta.R first.",
       call. = FALSE)
}

message("01b: reading SIPP extract ...")
raw <- readr::read_csv(expanded_csv, show_col_types = FALSE)

message("01b: building canonical modeled frame ...")
frame <- build_modeled_frame(raw, params = sm_params(), seed = cfg$seed)

out_parquet <- file.path(path_data_processed, "sipp_modeled.parquet")
out_rds     <- file.path(path_data_processed, "sipp_modeled.rds")
arrow::write_parquet(frame, out_parquet, compression = "snappy")
saveRDS(frame, out_rds)

# Emit the canonical parameter set alongside the frame.
write_sm_params_json(file.path(path_data_processed, "params.json"))

message(sprintf("01b: wrote %s (%d rows x %d cols).", basename(out_parquet), nrow(frame), ncol(frame)))
