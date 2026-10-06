# 01c_pull_ipums_asec.R -- pull person-level CPS ASEC microdata from the IPUMS API.
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - Pull the CPS ASEC person-level variables needed to derive the median-income
#                     anchor for the respecified Universal Saver's Match phasedown.
#
# DESCRIPTION:
# Structure, caching logic, and error discrimination follow
# `code/07_pull_ipums_incwage_asec.R` in the Household-income-and-composition
# repo. Two deliberate departures:
#
#   1. SINGLE SAMPLE, NOT THE FULL SERIES. That repo pulls every ASEC sample from
#      1962 forward because it estimates a long time series. This project needs
#      one cross-section -- the most recent ASEC -- to set a policy threshold, so
#      the extract is one sample and returns in minutes rather than hours. Set
#      `asec_sample_year_int` below to pin a specific vintage.
#   2. FILESTAT AND INCTOT ARE ADDED. Neither appears in that repo's extract.
#      FILESTAT carries tax filer status (the unit the Saver's Match operates on)
#      and INCTOT carries total personal income.
#
# THE VINTAGE CONTRACT. The ASEC income year must equal the SIPP reference year so
# that eligibility is scored nominal-on-nominal with no projection (decision S3,
# 2026-08-04). ASEC survey year Y reports income for calendar year Y-1. The 2025
# SIPP covers reference period January-December 2024, so ASEC 2025 is the match.
# `01d_asec_income_medians.R` asserts this and stops on a mismatch.
#
# Inputs:  IPUMS CPS API (requires IPUMS_API_KEY in the R environment)
# Outputs: data/raw/ipums_cps_asec/ipums_cps_asec_person_level.csv.gz
#          data/raw/ipums_cps_asec/ipums_cps_asec_person_level.xml   (DDI codebook)
#          data/raw/ipums_cps_asec/ipums_cps_asec_extract_definition.json
#          data/raw/ipums_cps_asec/ipums_cps_asec_extract_metadata.json
#          data/raw/ipums_cps_asec/ipums_cps_asec_sample_audit.csv

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###########################
###   Load Packages     ###
###########################
required_packages_chr <- c("dplyr", "readr", "stringr", "ipumsr", "jsonlite", "glue")

for (pkg_chr in required_packages_chr) {
  if (!requireNamespace(pkg_chr, quietly = TRUE)) {
    stop("Missing package: ", pkg_chr, ". Install it before running.", call. = FALSE)
  }
  library(pkg_chr, character.only = TRUE)
}

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()),
                 "code", "00_setup", "00_config.R"))

message("Starting 01c_pull_ipums_asec.R")

#################################
### Set file and API details  ###
#################################
# The key is read from the environment and never echoed. Add it to ~/.Renviron as
#   IPUMS_API_KEY=your_key_here
# and restart R. Keys are issued at https://account.ipums.org/api_keys.
ipums_api_key_chr <- Sys.getenv("IPUMS_API_KEY")

if (!nzchar(ipums_api_key_chr)) {
  stop(
    "IPUMS_API_KEY is not available in the R environment.\n",
    "Add `IPUMS_API_KEY=your_key_here` to ~/.Renviron and restart R. ",
    "Request a key at https://account.ipums.org/api_keys.",
    call. = FALSE
  )
}

path_ipums_dir_chr <- file.path(path_data_raw, "ipums_cps_asec")
if (!dir.exists(path_ipums_dir_chr)) dir.create(path_ipums_dir_chr, recursive = TRUE)

raw_extract_csv_path_chr  <- file.path(path_ipums_dir_chr, "ipums_cps_asec_person_level.csv.gz")
raw_extract_xml_path_chr  <- file.path(path_ipums_dir_chr, "ipums_cps_asec_person_level.xml")
extract_json_path_chr     <- file.path(path_ipums_dir_chr, "ipums_cps_asec_extract_definition.json")
extract_metadata_path_chr <- file.path(path_ipums_dir_chr, "ipums_cps_asec_extract_metadata.json")
sample_audit_path_chr     <- file.path(path_ipums_dir_chr, "ipums_cps_asec_sample_audit.csv")

# NULL = use the most recent ASEC sample IPUMS offers. Set to an integer (e.g.
# 2025L) to pin a vintage for reproducibility once the anchor is published.
asec_sample_year_int <- NULL

###########################
### 1) Audit samples    ###
###########################
message("1) Auditing IPUMS CPS ASEC sample availability.")

sample_info_tbl <- tryCatch(
  ipumsr::get_sample_info("cps"),
  error = function(e) {
    stop("Unable to retrieve CPS sample metadata from IPUMS: ", conditionMessage(e),
         call. = FALSE)
  }
)

asec_samples_tbl <- sample_info_tbl |>
  dplyr::filter(
    stringr::str_detect(name, "^cps[0-9]{4}_03s$"),
    stringr::str_detect(description, "ASEC")
  ) |>
  dplyr::mutate(sample_year_int = as.integer(stringr::str_sub(name, 4L, 7L))) |>
  dplyr::arrange(sample_year_int)

if (nrow(asec_samples_tbl) == 0L) {
  stop("No ASEC samples were returned by the IPUMS CPS metadata query.", call. = FALSE)
}

readr::write_csv(asec_samples_tbl, sample_audit_path_chr)

latest_available_year_int <- max(asec_samples_tbl$sample_year_int)
target_year_int <- if (is.null(asec_sample_year_int)) {
  latest_available_year_int
} else {
  as.integer(asec_sample_year_int)
}

if (!target_year_int %in% asec_samples_tbl$sample_year_int) {
  stop("Requested ASEC sample year ", target_year_int, " is not offered by IPUMS. ",
       "Available: ", min(asec_samples_tbl$sample_year_int), "-",
       latest_available_year_int, ".", call. = FALSE)
}

target_sample_chr <- asec_samples_tbl$name[asec_samples_tbl$sample_year_int == target_year_int]
target_income_year_int <- target_year_int - 1L   # ASEC survey year Y reports income for Y-1

message(glue::glue(
  "IPUMS offers {nrow(asec_samples_tbl)} ASEC samples ",
  "({min(asec_samples_tbl$sample_year_int)}-{latest_available_year_int}). ",
  "Targeting {target_sample_chr} (ASEC {target_year_int}, income year {target_income_year_int})."
))

###########################
### 2) Define extract   ###
###########################
message("2) Building the extract definition.")

# Core variables carry the requested statistics. Supporting variables are pulled in
# the SAME submission so that a follow-up cut does not require a second extract --
# the same rationale the Household-income-and-composition pull documents.
#
#   INCTOT   total pre-tax personal income, all sources. NIU = 999999999;
#            missing = 999999998 (1962-1964 only). CAN BE NEGATIVE (business and
#            farm losses). Universe: persons age 15+ from ASEC 1980 onward.
#   INCWAGE  pre-tax wage and salary income. NIU = 99999999; missing = 99999998
#            (1962-1966 only). The IPUMS universe note records a break at ASEC
#            2019 (persons age 15+ through ASEC 2018; persons age 15+ WITH EARNINGS
#            LAST YEAR from ASEC 2019 onward). VERIFIED EMPIRICALLY on ASEC 2025
#            (2026-08-04): the break does NOT show up as NIU sentinels. Zero
#            records age 15+ carry the NIU code, and 45,877 non-earners carry
#            INCWAGE == 0. So the delivered data still behaves like an age-15+
#            universe with explicit zeros, and the "all values" versus
#            "positive only" distinction is large and real. See 01d.
#   FILESTAT federal income tax filing status, from the Census tax model (an
#            imputation, not a survey response). Available 1992 onward, ASEC only.
#            Codes: 1 Joint both under 65; 2 Joint one 65+; 3 Joint both 65+;
#            4 Head of household; 5 Single; 6 Nonfiler. THERE IS NO MFS CATEGORY.
#   MARST    marital status. Pulled ONLY so that an MFS proxy is available without
#            a second extract; FILESTAT cannot identify MFS. Not used in any
#            headline statistic.
#   CLASSWKR class of worker; lets the self-employed be identified, who by
#            construction have little or no INCWAGE.
core_variables_chr <- c(
  "YEAR",
  "SERIAL",
  "PERNUM",
  "ASECWT",
  "AGE",
  "SEX",
  "INCTOT",
  "INCWAGE",
  "FILESTAT"
)

supporting_variables_chr <- c(
  "MARST",
  "CLASSWKR"
)

full_variables_chr     <- c(core_variables_chr, supporting_variables_chr)
fallback_variables_chr <- core_variables_chr

build_extract_definition <- function(variables_chr) {
  ipumsr::define_extract_micro(
    collection = "cps",
    description = glue::glue(
      "Saver's Match anchor: personal income and wage medians by filer status, ASEC {target_year_int}"
    ),
    samples = target_sample_chr,
    variables = variables_chr,
    data_format = "csv",
    data_structure = "rectangular",
    rectangular_on = "P"
  )
}

###########################
### 3) Pull the extract ###
###########################
message("3) Submitting and downloading the extract when needed.")

# The cache is only reusable when it covers BOTH the target sample and every
# requested variable. Checking file existence alone would serve a stale extract
# after IPUMS releases a new ASEC year; checking the sample alone would silently
# drop newly requested variables.
cached_extract_is_current_lgl <- FALSE

if (file.exists(raw_extract_csv_path_chr) && file.exists(raw_extract_xml_path_chr)) {
  cached_metadata_lst <- tryCatch(
    jsonlite::read_json(extract_metadata_path_chr, simplifyVector = TRUE),
    error = function(e) NULL
  )

  if (is.null(cached_metadata_lst)) {
    warning("Cached extract coverage could not be verified (metadata unreadable). ",
            "Keeping the cached files; delete them to force a fresh pull.",
            call. = FALSE)
    cached_extract_is_current_lgl <- TRUE
  } else {
    cached_year_int      <- as.integer(cached_metadata_lst$asec_survey_year)
    cached_variables_chr <- as.character(cached_metadata_lst$variables)
    missing_variables_chr <- setdiff(full_variables_chr, cached_variables_chr)
    year_current_lgl <- !is.na(cached_year_int) && cached_year_int == target_year_int

    if (year_current_lgl && length(missing_variables_chr) == 0L) {
      cached_extract_is_current_lgl <- TRUE
    } else if (!year_current_lgl) {
      message(glue::glue(
        "Cached extract is ASEC {cached_year_int} but ASEC {target_year_int} is targeted. Submitting a new extract."
      ))
    } else {
      message(glue::glue(
        "Cached extract is missing requested variable(s): ",
        "{paste(missing_variables_chr, collapse = ', ')}. Submitting a new extract."
      ))
    }
  }
}

if (cached_extract_is_current_lgl) {
  message("Canonical ASEC extract already covers the target sample and variables. Skipping submission.")
} else {
  variables_used_chr <- full_variables_chr

  submitted_extract <- tryCatch(
    ipumsr::submit_extract(build_extract_definition(full_variables_chr)),
    error = function(e) {
      error_message_chr <- conditionMessage(e)

      # Fall back ONLY on a variable rejection. A network timeout, an expired key,
      # or a 5xx must stop the run: retrying those with a reduced list would ship
      # an extract silently missing MARST and CLASSWKR, and could queue a
      # duplicate extract.
      if (!grepl("mnemonic|variable|not available|invalid", error_message_chr,
                 ignore.case = TRUE)) {
        stop("IPUMS extract submission failed and the error is not a variable rejection: ",
             error_message_chr, call. = FALSE)
      }

      warning("Full-variable submission rejected (", error_message_chr,
              "). Retrying with the core variable list.", call. = FALSE)
      NULL
    }
  )

  if (is.null(submitted_extract)) {
    variables_used_chr <- fallback_variables_chr
    submitted_extract <- tryCatch(
      ipumsr::submit_extract(build_extract_definition(fallback_variables_chr)),
      error = function(e) {
        stop("IPUMS extract submission failed: ", conditionMessage(e), call. = FALSE)
      }
    )
  }

  ipumsr::save_extract_as_json(
    build_extract_definition(variables_used_chr),
    extract_json_path_chr,
    overwrite = TRUE
  )

  message(glue::glue(
    "Submitted IPUMS CPS extract {submitted_extract$number} with {length(variables_used_chr)} variables."
  ))

  downloadable_extract <- tryCatch(
    ipumsr::wait_for_extract(
      submitted_extract,
      initial_delay_seconds = 15,
      max_delay_seconds = 60,
      timeout_seconds = 3600,
      verbose = TRUE
    ),
    error = function(e) {
      stop("IPUMS extract processing did not complete: ", conditionMessage(e),
           call. = FALSE)
    }
  )

  tryCatch(
    ipumsr::download_extract(downloadable_extract,
                             download_dir = path_ipums_dir_chr,
                             overwrite = TRUE),
    error = function(e) {
      stop("IPUMS extract download failed: ", conditionMessage(e), call. = FALSE)
    }
  )

  downloaded_csv_path_chr <- file.path(
    path_ipums_dir_chr, sprintf("cps_%05d.csv.gz", as.integer(downloadable_extract$number))
  )
  downloaded_xml_path_chr <- file.path(
    path_ipums_dir_chr, sprintf("cps_%05d.xml", as.integer(downloadable_extract$number))
  )

  if (!file.exists(downloaded_csv_path_chr) || !file.exists(downloaded_xml_path_chr)) {
    stop("Expected downloaded IPUMS extract files are not present in ",
         path_ipums_dir_chr, ".", call. = FALSE)
  }

  file.rename(downloaded_csv_path_chr, raw_extract_csv_path_chr)
  file.rename(downloaded_xml_path_chr, raw_extract_xml_path_chr)

  jsonlite::write_json(
    list(
      extract_number   = as.integer(downloadable_extract$number),
      submitted_at     = as.character(Sys.time()),
      asec_sample      = target_sample_chr,
      asec_survey_year = target_year_int,
      asec_income_year = target_income_year_int,
      variables        = variables_used_chr
    ),
    path = extract_metadata_path_chr,
    auto_unbox = TRUE,
    pretty = TRUE
  )
}

###########################
### 4) Validate pull    ###
###########################
message("4) Validating the canonical raw extract.")

if (!file.exists(raw_extract_csv_path_chr) ||
    file.info(raw_extract_csv_path_chr)$size <= 0) {
  stop("Canonical raw CSV extract is missing or empty after the pull step.", call. = FALSE)
}
if (!file.exists(raw_extract_xml_path_chr) ||
    file.info(raw_extract_xml_path_chr)$size <= 0) {
  stop("Canonical raw DDI extract is missing or empty after the pull step.", call. = FALSE)
}

ddi_check <- ipumsr::read_ipums_ddi(raw_extract_xml_path_chr)
ddi_variables_chr <- ipumsr::ipums_var_info(ddi_check)$var_name

# Every variable a downstream statistic depends on must be present. Failing here
# is far cheaper than discovering an all-NA column after the medians are computed.
required_downstream_chr <- c("ASECWT", "AGE", "INCTOT", "INCWAGE", "FILESTAT")
missing_downstream_chr  <- setdiff(required_downstream_chr, ddi_variables_chr)

if (length(missing_downstream_chr) > 0L) {
  stop("Downloaded DDI is missing required variable(s): ",
       paste(missing_downstream_chr, collapse = ", "), ".", call. = FALSE)
}

message("Downloaded extract variables: ", paste(ddi_variables_chr, collapse = ", "), ".")
message("Finished 01c_pull_ipums_asec.R")
