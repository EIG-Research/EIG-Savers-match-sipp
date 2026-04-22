# 01_sipp_subset_from_dta -- Build expanded SIPP 2024 raw extract from pu2024.dta
# Author - Ben Glasner
# research title - RSAA vs. Saver's Match Distributional Comparison
# research question - Produce a SIPP 2024 raw extract that carries every variable
#                    needed downstream, including Saver's Match eligibility proxies
#                    (earnings, enrollment, dependency) that the legacy
#                    Stata-based extract did not retain.
#
# Why this script exists:
#   The canonical raw extract at data/raw/pu2024.csv was produced by the legacy
#   Stata do-file "1 SIPP subset.do". That do-file kept only 40 variables. The
#   Saver's Match eligibility work (03g_savers_match_eligibility_buckets.R)
#   needs TPEARN, RENROLL, EEDENROLL, EEDGRADE, EEDFTPT, and ERELRPE in addition to those
#   40 variables. This script is an R-native replacement for the Stata do-file:
#   it reads pu2024.dta directly via haven::read_dta() and writes a richer
#   extract to pu2024_expanded.csv (and a parquet sibling). It leaves the
#   original pu2024.csv untouched so downstream scripts that still point at
#   the 40-column extract keep working until they are migrated.
#
# Input:   data/raw/pu2024.dta           (Stata .dta from Census SIPP 2024 Wave 1)
# Output:  data/raw/pu2024_expanded.csv  (45 variables; long-form person-month)
#          data/raw/pu2024_expanded.parquet

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###########################################
###            Load packages            ###
###########################################
library(haven)
library(dplyr)
library(readr)
library(arrow)

###########################################
###       Project root resolution        ###
###########################################
# Three-tier fallback (mirrors 03g_savers_match_eligibility_buckets.R). The
# script must find PROJECT.md regardless of where the user's working directory
# was when they called source(). Tiers are tried in order of explicitness.

config_path_chr <- NA_character_

# Tier 1: EIG_PROJECT_ROOT environment variable
env_root_chr <- Sys.getenv("EIG_PROJECT_ROOT", unset = "")
if (nzchar(env_root_chr) && file.exists(file.path(env_root_chr, "PROJECT.md"))) {
  config_path_chr <- file.path(env_root_chr, "code", "00_setup", "00_config.R")
}

# Tier 2: walk up the directory tree starting from getwd() looking for PROJECT.md
if (is.na(config_path_chr)) {
  cur_chr <- normalizePath(getwd(), winslash = "/", mustWork = FALSE)
  for (i in seq_len(10L)) {
    if (file.exists(file.path(cur_chr, "PROJECT.md"))) {
      config_path_chr <- file.path(cur_chr, "code", "00_setup", "00_config.R")
      break
    }
    parent_chr <- normalizePath(file.path(cur_chr, ".."), winslash = "/", mustWork = FALSE)
    if (identical(parent_chr, cur_chr)) break
    cur_chr <- parent_chr
  }
}

# Tier 3: walk up from the path of this script itself (available when source()-d)
if (is.na(config_path_chr)) {
  frames_list <- sys.frames()
  sourced_path_chr <- NA_character_
  for (i in rev(seq_along(frames_list))) {
    ofile_candidate <- frames_list[[i]]$ofile
    if (!is.null(ofile_candidate) &&
        is.character(ofile_candidate) &&
        nzchar(ofile_candidate)) {
      sourced_path_chr <- ofile_candidate
      break
    }
  }
  if (!is.na(sourced_path_chr)) {
    cur_chr <- dirname(normalizePath(sourced_path_chr, winslash = "/", mustWork = FALSE))
    for (i in seq_len(10L)) {
      if (file.exists(file.path(cur_chr, "PROJECT.md"))) {
        config_path_chr <- file.path(cur_chr, "code", "00_setup", "00_config.R")
        break
      }
      parent_chr <- normalizePath(file.path(cur_chr, ".."), winslash = "/", mustWork = FALSE)
      if (identical(parent_chr, cur_chr)) break
      cur_chr <- parent_chr
    }
  }
}

if (is.na(config_path_chr) || !file.exists(config_path_chr)) {
  stop(
    "Could not locate code/00_setup/00_config.R. ",
    "Set EIG_PROJECT_ROOT or run from within the repo tree.",
    call. = FALSE
  )
}

source(config_path_chr)
message("Using project_root: ", path_project)

###########################################
###        Input and output paths        ###
###########################################
sipp_dta_path_chr       <- file.path(path_data_raw, "pu2024.dta")
output_csv_path_chr     <- file.path(path_data_raw, "pu2024_expanded.csv")
output_parquet_path_chr <- file.path(path_data_raw, "pu2024_expanded.parquet")

if (!file.exists(sipp_dta_path_chr)) {
  stop(
    "SIPP 2024 Stata file not found at: ", sipp_dta_path_chr, ". ",
    "Unzip data/raw/pu2024_dta.zip or re-download pu2024.dta from Census.",
    call. = FALSE
  )
}

###########################################
###    Target variable specification     ###
###########################################
# 1) The 40 variables already present in pu2024.csv (legacy Stata extract).
#    Order is preserved for downstream back-compat with 01a_data_ingest.R.
existing_vars_chr <- c(
  "SSUID", "SHHADID", "SPANEL", "SWAVE", "PNUM",
  "ESEX", "EORIGIN", "ERACE", "EEDUC",
  "EOWN_IRAKEO", "EOWN_THR401", "EOWN_PENSION",
  "EMJOB_IRA", "EMJOB_401", "EMJOB_PEN",
  "ESCNTYN_IRA", "ESCNTYN_401", "EFSTATUS",
  "RSNAP_YRYN", "RDIS",
  "EECNTYN_IRA", "EECNTYN_401", "ESCNTYN_PEN",
  "MONTHCODE", "WPFINWGT",
  "EJB1_JBORSE", "EJB1_CLWRK",
  "RMESR", "RSNAP_MNYN", "RTANF_MNYN", "RSSI_MNYN", "RPUBTYPE2",
  "TMETRO_INTV", "TJB1_OCC", "TJB1_JOBHRS1",
  "TAGE", "TSNAP_AMT", "TVAL_RET", "TPTOTINC", "TFTOTINC"
)

# 2) Additional variables needed by 03g_savers_match_eligibility_buckets.R.
#    Names verified against the pu2024.dta header (5,203 variables) on 2026-04-18
#    using a Python-based column inspection. Earlier drafts had RENROLD/EENRLEV/
#    RFTPTX, none of which exist in SIPP 2024 Wave 1; the corrected names below
#    use the R-prefix recode (RENROLL) plus the ED-module enrollment items.
#    EPNSPOUSE / APNSPOUSE added on 2026-04-19 to enable the U1 joint-income
#    correction: summing TFTOTINC across spouses for the MFJ filer branch,
#    rather than assuming the reference person's TFTOTINC already equals the
#    couple's joint income (see Infrastructure/plans/2026-04-19_savers-match-
#    methodology-upgrade.md, revision block).
new_vars_chr <- c(
  "TPEARN",     # Total monthly personal earnings; drives has_earned_income_flag and MFS own-earnings test.
  "RENROLL",    # Person-level enrollment recode during the reference period; primary student flag.
  "EEDENROLL",  # Monthly "currently enrolled in school" item; cross-check for RENROLL.
  "EEDGRADE",   # Grade level of enrollment (e.g. high school, undergrad, graduate); refines the student flag.
  "EEDFTPT",    # Full-time vs. part-time student status; needed for the §25B "full-time student" trigger.
  "ERELRPE",    # Person's relationship to reference person; dependency proxy for the "can-be-claimed-as-dependent" exclusion.
  "EPENSNYN",   # Screen: whether the main employer or business had any retirement plan for anyone in the company/organization.
  "EINCPENS",   # Inclusion: whether the respondent was included in the retirement plan(s) offered by the main employer or business.
  "EPNSPOUSE",  # Person number of spouse within the same SSUID; lets U1 join spouses and sum TFTOTINC for the MFJ branch.
  "APNSPOUSE"   # Status flag for EPNSPOUSE (imputation / allocation indicator); kept alongside the pointer per Census convention.
)

target_vars_chr <- c(existing_vars_chr, new_vars_chr)

###########################################
###   1) Validate variable availability  ###
###########################################
# Read a 0-row header from the .dta to enumerate columns without loading the
# full ~2GB file. Fail fast (and informatively) before the expensive read if
# any target variable is misnamed or absent from this SIPP wave.

message("Inspecting variable list in: ", sipp_dta_path_chr)
sipp_header_df <- read_dta(sipp_dta_path_chr, n_max = 0L)
available_vars_chr <- names(sipp_header_df)

missing_vars_chr <- setdiff(target_vars_chr, available_vars_chr)
if (length(missing_vars_chr) > 0L) {
  stop(
    "The following target variables are not present in pu2024.dta: ",
    paste(missing_vars_chr, collapse = ", "),
    ". Consult the SIPP 2024 Wave 1 Data Dictionary for the correct names ",
    "(e.g. the Census PUF codebook).",
    call. = FALSE
  )
}
message(
  "All ", length(target_vars_chr), " target variables found in .dta header ",
  "(", length(existing_vars_chr), " legacy + ", length(new_vars_chr), " new)."
)

###########################################
###   2) Read selected columns from .dta ###
###########################################
# haven::read_dta accepts a tidyselect-style col_select argument. Reading only
# the 45 target columns keeps memory well below the full-file footprint.

message(
  "Reading ", length(target_vars_chr), " columns from pu2024.dta. ",
  "This typically takes 1-3 minutes on a laptop."
)

read_start_time <- Sys.time()
sipp_full_df <- read_dta(
  sipp_dta_path_chr,
  col_select = all_of(target_vars_chr)
)
read_elapsed_num <- round(as.numeric(difftime(Sys.time(), read_start_time, units = "secs")), 1)

message(
  "Read complete: ", nrow(sipp_full_df), " rows x ",
  ncol(sipp_full_df), " cols in ", read_elapsed_num, " s."
)

# Belt-and-suspenders: re-confirm the column set survived col_select as expected.
stopifnot(setequal(names(sipp_full_df), target_vars_chr))

# Preserve the same column order as existing_vars_chr then new_vars_chr.
sipp_full_df <- sipp_full_df[, target_vars_chr]

###########################################
###  3) Strip haven labelled/format meta ###
###########################################
# Stata numeric columns round-tripped through haven carry the `haven_labelled`
# S3 class. Downstream readr / dplyr / arrow code prefers plain numeric. The
# underlying numeric values are preserved by zap_labels(); only the label
# metadata is dropped.

message("Zapping haven labelled metadata and Stata display formats.")
sipp_flat_df <- sipp_full_df |>
  zap_labels() |>
  zap_formats()

###########################################
###    4) Write CSV and parquet outputs  ###
###########################################
# CSV preserves feature parity with legacy pu2024.csv; parquet is the
# preferred downstream read format (columnar + snappy-compressed).

message("Writing CSV to: ", output_csv_path_chr)
write_csv(sipp_flat_df, output_csv_path_chr)

message("Writing parquet to: ", output_parquet_path_chr)
write_parquet(sipp_flat_df, output_parquet_path_chr, compression = "snappy")

###########################################
###       5) Verification summary        ###
###########################################
# Spot-check the new variables so problems surface immediately rather than
# 20 minutes later inside 03g. Report weighted and unweighted non-missing
# counts on the December reference month for each new variable.

dec_mask_flag <- sipp_flat_df$MONTHCODE == 12L
dec_n_int <- sum(dec_mask_flag)

message("Verification -- December-only subset (MONTHCODE == 12):")
message(sprintf("  Total person-month rows (any MONTHCODE): %d", nrow(sipp_flat_df)))
message(sprintf("  December person-month rows:              %d", dec_n_int))

for (v in new_vars_chr) {
  col_vec <- sipp_flat_df[[v]][dec_mask_flag]
  n_nonmiss_int <- sum(!is.na(col_vec))
  n_missing_int <- dec_n_int - n_nonmiss_int
  message(sprintf(
    "  %-8s  non-missing = %8d  |  missing = %8d  |  pct missing = %5.1f%%",
    v, n_nonmiss_int, n_missing_int, 100 * n_missing_int / dec_n_int
  ))
}

csv_size_mb_num     <- round(file.info(output_csv_path_chr)$size / (1024^2), 1)
parquet_size_mb_num <- round(file.info(output_parquet_path_chr)$size / (1024^2), 1)
message(sprintf(
  "Output sizes: CSV = %.1f MB | parquet = %.1f MB (compression = snappy)",
  csv_size_mb_num, parquet_size_mb_num
))

message("01_sipp_subset_from_dta.R complete.")
