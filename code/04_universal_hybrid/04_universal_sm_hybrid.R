# 04_universal_sm_hybrid -- thin master orchestrator for the RSAA + Saver's Match hybrid simulation
# Author - Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - End-to-end simulation: build the analysis universe, compute per-filing-group
#                     MAGI pivots, apply the piecewise-linear match-rate schedule, run behavioral
#                     scenarios, and emit tables and figures.
#
# DESCRIPTION:
# Sources the six 04_0[1-6]_*.R sub-scripts in dependency order. Each sub-script
# runs in a fresh environment so global state does not leak between stages. The
# master file is invoked once from code/run_all.R via a single RUN_03I flag.
#
# Sub-scripts (each independently runnable for development):
#   04_01_build_universe.R       -- universe + funnel
#   04_02_compute_pivots.R       -- median MAGI -> pivot table
#   04_03_simulate_match.R       -- match rate schedule + scenarios
#   04_04_build_tables.R         -- xlsx outputs
#   04_05_build_figures.R        -- ggplot figures via EIG tokens
#   04_06_phaseout_lenses.R      -- three-lens phaseout figures (Single)
#
# Spec:  Infrastructure/specs/2026-05-27_universal-account-savers-match-hybrid.md
# Plan:  Infrastructure/plans/2026-05-27_universal-sm-hybrid-implementation.md

rm(list = ls())
options(scipen = 999)
set.seed(42L)

###################################################################################
###                            Project Root Resolution                          ###
###################################################################################
project_root <- NA_character_
env_root_chr <- Sys.getenv("EIG_PROJECT_ROOT", unset = NA_character_)
if (!is.na(env_root_chr) && nzchar(env_root_chr) &&
    dir.exists(file.path(env_root_chr, "Infrastructure"))) {
  project_root <- normalizePath(env_root_chr)
}
if (is.na(project_root)) {
  candidate_chr <- normalizePath(getwd())
  while (!dir.exists(file.path(candidate_chr, "Infrastructure")) &&
         candidate_chr != dirname(candidate_chr)) {
    candidate_chr <- dirname(candidate_chr)
  }
  if (dir.exists(file.path(candidate_chr, "Infrastructure"))) {
    project_root <- candidate_chr
  }
}
if (is.na(project_root)) {
  frames_list <- sys.frames()
  sourced_path_chr <- NA_character_
  for (i in rev(seq_along(frames_list))) {
    ofile_candidate <- frames_list[[i]]$ofile
    if (!is.null(ofile_candidate) && is.character(ofile_candidate) &&
        nzchar(ofile_candidate)) {
      sourced_path_chr <- ofile_candidate
      break
    }
  }
  if (!is.na(sourced_path_chr)) {
    candidate_chr <- normalizePath(dirname(sourced_path_chr))
    while (!dir.exists(file.path(candidate_chr, "Infrastructure")) &&
           candidate_chr != dirname(candidate_chr)) {
      candidate_chr <- dirname(candidate_chr)
    }
    if (dir.exists(file.path(candidate_chr, "Infrastructure"))) {
      project_root <- candidate_chr
    }
  }
}
if (is.na(project_root)) {
  stop("Could not locate repo root. Set EIG_PROJECT_ROOT or setwd().", call. = FALSE)
}
message("Using project_root: ", project_root)

###################################################################################
###                              Sub-Script Paths                               ###
###################################################################################
sub_dir_chr <- file.path(project_root, "code", "04_universal_hybrid",
                         "04_universal_sm_hybrid")

sub_scripts_chr <- c(
  file.path(sub_dir_chr, "04_01_build_universe.R"),
  file.path(sub_dir_chr, "04_02_compute_pivots.R"),
  file.path(sub_dir_chr, "04_03_simulate_match.R"),
  file.path(sub_dir_chr, "04_04_build_tables.R"),
  file.path(sub_dir_chr, "04_05_build_figures.R"),
  file.path(sub_dir_chr, "04_06_phaseout_lenses.R")
)

for (s in sub_scripts_chr) {
  if (!file.exists(s)) {
    stop("Sub-script missing: ", s,
         ". Confirm code/04_universal_hybrid/04_universal_sm_hybrid/ is intact.",
         call. = FALSE)
  }
}

###################################################################################
###                       Source Each Sub-Script in Order                       ###
###################################################################################
master_start_time <- Sys.time()
for (s in sub_scripts_chr) {
  label_chr <- basename(s)
  message("")
  message("==============================================================")
  message("[04 master] Sourcing: ", label_chr)
  message("==============================================================")
  stage_start_time <- Sys.time()
  env_one <- new.env(parent = globalenv())
  sys.source(s, envir = env_one)
  stage_elapsed_num <- round(as.numeric(difftime(Sys.time(), stage_start_time, units = "secs")), 1)
  message(sprintf("[04 master] %s finished in %.1f s.", label_chr, stage_elapsed_num))
}
master_elapsed_num <- round(as.numeric(difftime(Sys.time(), master_start_time, units = "secs")), 1)

message("")
message("==============================================================")
message(sprintf("[04 master] All six sub-scripts complete in %.1f s.",
                master_elapsed_num))
message("==============================================================")
