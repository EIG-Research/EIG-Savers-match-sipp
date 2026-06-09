# ============================================================
# DESCRIPTION:
# One-time re-export of pu2024.dta -> pu2024.csv using haven.
# The original CSV was missing EFSTATUS (tax filing status)
# despite it being in the Stata .do keep list. This script
# re-exports with the full variable set including EFSTATUS
# and TFTOTINC (family total income, if present in the .dta).
#
# Run this script once when raw data is refreshed or when
# the .dta is available but the CSV is missing/outdated.
#
# Input:  WORKSPACE/data/raw/pu2024.dta
# Output: WORKSPACE/data/raw/pu2024.csv  (overwrites)
# ============================================================

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", normalizePath(getwd())), "code", "00_setup", "00_config.R"))
library(haven)
library(dplyr)
library(readr)

dta_path <- file.path(path_data_raw, "pu2024.dta")
csv_path <- file.path(path_data_raw, "pu2024.csv")

if (!file.exists(dta_path)) {
  stop("pu2024.dta not found at: ", dta_path,
       "\nDownload from: https://www.census.gov/programs-surveys/sipp/data/datasets.html")
}

message("Reading pu2024.dta with haven (this may take several minutes for a 3GB file)...")

# Variables from Stata .do keep list, plus EFSTATUS (was in list but absent from CSV)
# and TFTOTINC (family total monthly income — useful for Saver's Match income-unit analysis)
vars_from_stata_do <- c(
  "SHHADID", "SPANEL", "SSUID", "SWAVE", "PNUM", "MONTHCODE", "WPFINWGT",
  "TAGE", "EEDUC", "ESEX", "ERACE", "TMETRO_INTV",
  "EJB1_JBORSE", "EJB1_CLWRK",
  "TPTOTINC",
  "EMJOB_401", "EMJOB_IRA", "EMJOB_PEN",
  "EOWN_THR401", "EOWN_IRAKEO", "EOWN_PENSION",
  "ESCNTYN_401", "EECNTYN_401", "EORIGIN",
  "TJB1_JOBHRS1", "ESCNTYN_PEN", "ESCNTYN_IRA", "EECNTYN_IRA",
  "TVAL_RET",
  "RSNAP_MNYN", "RPUBTYPE2", "RTANF_MNYN", "RSSI_MNYN",
  "RMESR", "RDIS", "RSNAP_YRYN", "TJB1_OCC", "TSNAP_AMT",
  "EFSTATUS"   # filing status — was in Stata keep list but missing from exported CSV
)

# TFTOTINC is the family total monthly income variable. It is the proper income
# unit for evaluating joint-filer (MFJ) income thresholds (e.g., Saver's Match).
# Read the .dta column names first to check availability before selecting.
message("Checking available columns in .dta...")
dta_cols <- colnames(read_dta(dta_path, n_max = 0))

tftotinc_available <- "TFTOTINC" %in% dta_cols
if (tftotinc_available) {
  message("TFTOTINC found — will include family total income in export.")
  vars_to_read <- c(vars_from_stata_do, "TFTOTINC")
} else {
  message("TFTOTINC not found in .dta — omitting. Will use SSUID-aggregated income as proxy.")
  vars_to_read <- vars_from_stata_do
}

# Confirm all requested vars exist; drop any not found with a warning
missing_vars <- setdiff(vars_to_read, dta_cols)
if (length(missing_vars) > 0) {
  warning("Variables not found in .dta and will be skipped: ",
          paste(missing_vars, collapse = ", "))
  vars_to_read <- intersect(vars_to_read, dta_cols)
}

message(sprintf("Reading %d variables from .dta...", length(vars_to_read)))
raw <- read_dta(dta_path, col_select = all_of(vars_to_read))

# Strip Stata labels so the CSV writes as plain numerics/strings
raw <- zap_labels(raw)
raw <- zap_label(raw)

message(sprintf("Rows read: %s | Columns: %d", scales::comma(nrow(raw)), ncol(raw)))

# Verify EFSTATUS made it in
if ("EFSTATUS" %in% colnames(raw)) {
  message("EFSTATUS present. Value distribution (all months):")
  print(table(raw$EFSTATUS, useNA = "always"))
} else {
  warning("EFSTATUS still missing after read — check .dta variable name.")
}

message("Writing pu2024.csv...")
write_csv(raw, csv_path)
message("Done. CSV written to: ", csv_path)
message(sprintf("File size: %.1f MB", file.size(csv_path) / 1024^2))
