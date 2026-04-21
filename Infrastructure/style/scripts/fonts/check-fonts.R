#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
allow_fallback <- "--allow-fallback" %in% args

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  message("ERROR: Package 'jsonlite' is required for font checks.")
  quit(status = 2)
}

if (!requireNamespace("systemfonts", quietly = TRUE)) {
  message("WARNING: Package 'systemfonts' not found. Falling back to shell font discovery.")
}

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", cmd_args, value = TRUE)
if (length(file_arg) > 0) {
  script_path <- sub("^--file=", "", file_arg[1])
  script_path <- normalizePath(script_path, mustWork = FALSE)
  repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), mustWork = FALSE)
  token_path <- file.path(repo_root, "tokens", "eig-style-tokens.v1.json")
} else {
  token_path <- file.path(getwd(), "tokens", "eig-style-tokens.v1.json")
}

if (!file.exists(token_path)) {
  token_path <- file.path(getwd(), "tokens", "eig-style-tokens.v1.json")
}

if (!file.exists(token_path)) {
  message("ERROR: Token file not found: ", token_path)
  quit(status = 2)
}

tokens <- jsonlite::fromJSON(token_path, simplifyVector = TRUE)
if (requireNamespace("systemfonts", quietly = TRUE)) {
  available <- unique(systemfonts::system_fonts()$family)
} else {
  fc <- suppressWarnings(system("fc-list : family", intern = TRUE))
  if (length(fc) == 0) {
    message("ERROR: Unable to enumerate system fonts (no systemfonts and no fc-list).")
    quit(status = 2)
  }
  parts <- trimws(unlist(strsplit(fc, ",")))
  available <- unique(parts[nchar(parts) > 0])
}

headline_primary <- tokens$typography$headline$primary_family
body_primary <- tokens$typography$body$primary_family
headline_fallback <- unlist(tokens$typography$headline$fallback_stack)
body_fallback <- unlist(tokens$typography$body$fallback_stack)

if (!allow_fallback) {
  missing <- c()
  if (!(headline_primary %in% available)) missing <- c(missing, headline_primary)
  if (!(body_primary %in% available)) missing <- c(missing, body_primary)

  if (length(missing) > 0) {
    message("ERROR: Required primary fonts are missing:")
    for (m in missing) message("  - ", m)
    quit(status = 1)
  }
  message("PASS: Primary EIG fonts are installed.")
  quit(status = 0)
}

headline_ok <- (headline_primary %in% available) || any(headline_fallback %in% available)
body_ok <- (body_primary %in% available) || any(body_fallback %in% available)

if (!headline_ok || !body_ok) {
  message("ERROR: No valid font found for one or more required stacks.")
  message("  headline primary: ", headline_primary)
  message("  body primary: ", body_primary)
  quit(status = 1)
}

message("PASS: Required EIG font stacks are available (primary or fallback).")
quit(status = 0)
