# 00_config.R -- baseline project configuration
options(scipen = 999)
options(dplyr.summarise.inform = FALSE)

find_project_root <- function(start = getwd(), max_up = 10L) {
  cur <- normalizePath(start, winslash = "/", mustWork = FALSE)
  for (i in seq_len(max_up + 1L)) {
    # New structure: PROJECT.md at repo root
    if (file.exists(file.path(cur, "PROJECT.md"))) return(cur)
    parent <- normalizePath(file.path(cur, ".."), winslash = "/", mustWork = FALSE)
    if (identical(parent, cur)) break
    cur <- parent
  }
  NA_character_
}

path_project <- Sys.getenv("EIG_PROJECT_ROOT", unset = "")
if (!nzchar(path_project)) path_project <- find_project_root()
if (is.na(path_project) || !dir.exists(path_project)) {
  stop("Could not locate project root. Set EIG_PROJECT_ROOT or run from repo.", call. = FALSE)
}

path_project <- normalizePath(path_project, winslash = "/", mustWork = TRUE)
setwd(path_project)

path_code <- file.path(path_project, "code")
path_data <- file.path(path_project, "data")
path_data_raw <- file.path(path_data, "raw")
path_data_processed <- file.path(path_data, "processed")
path_output <- file.path(path_project, "output")
path_output_fig_main <- file.path(path_output, "figures", "main")
path_output_fig_appendix <- file.path(path_output, "figures", "appendix")
path_output_tbl_main <- file.path(path_output, "tables", "main")
path_output_tbl_appendix <- file.path(path_output, "tables", "appendix")
path_output_intermediate <- file.path(path_output, "data", "intermediate_results")

cfg <- list(
  project_name = "Saver's Match: eligibility and cost analysis",
  audience = "Policy brief",
  project_scope_tier = 2L,  # 1=Descriptive/Blog, 2=Analytical Brief, 3=Full Research Paper
  currency_base_year = 2024L,
  fig_width = 10,
  fig_height = 6,
  fig_dpi = 300,
  seed = 42
)

# Base directories required at all tiers
base_dirs <- c(path_data_raw, path_data_processed, path_output_fig_main, path_output_tbl_main)
for (d in base_dirs) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# Intermediate results directory (always created; stage contracts reference it at all tiers)
dir.create(path_output_intermediate, recursive = TRUE, showWarnings = FALSE)

# Appendix output directories (tier 3 only)
if (cfg$project_scope_tier >= 3L) {
  dir.create(path_output_fig_appendix, recursive = TRUE, showWarnings = FALSE)
  dir.create(path_output_tbl_appendix, recursive = TRUE, showWarnings = FALSE)
}

files <- list(
  run_manifest = file.path(path_output_intermediate, "run_manifest.json"),
  data_report = file.path(path_project, "Infrastructure", "quality_reports", "data_report.html")
)

set.seed(cfg$seed)

# ----------------------------------------------------------------------------
# Bootstrap the shared analytic core. Sourcing this config gives a stage the
# single source of truth (params), the helper library, the one canonical frame
# builder, and the scenario engine. Order matters: params -> helpers/v2 builder
# -> build_frame -> scenario_engine.
# ----------------------------------------------------------------------------
path_shared <- file.path(path_code, "_shared")
local({
  core_files <- c("params.R", "calibration_cells.R", "build_frame.R", "scenario_engine.R")
  for (f in core_files) {
    fp <- file.path(path_shared, f)
    if (file.exists(fp)) source(fp)
  }
})

message("Loaded config + shared core. Project root: ", path_project)
