# 03b_robustness_sweep.R -- Saver's Match cost robustness sweep.
# Author: Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - How does the one-year Saver's Match cost vary across AGI-threshold multiplier,
#                     account-access scope, participation rate, and the contribution-split assumption?
#
# Thin stage: reads the ONE canonical modeled frame and runs the shared run_scenario() engine over a
# scenario grid. No frame re-derivation, no inline scenario loop, no separate 03a checkpoint -- it reads
# the same data/processed/sipp_modeled.parquet as 03a, so the two cannot drift.
#
# Grid: 4 multipliers (m100/m125/m150/m200) x 2 access (DC-only / universal) x 2 take-up
#       (auto 80% / full 100%) = 16 rows on the JCT 15/60/25 split, plus 4 universal/full rows on the
#       alternative 15/25/60 split = 20 scenarios.

rm(list = ls())
suppressMessages({ library(dplyr); library(tidyr); library(arrow); library(openxlsx); library(jsonlite) })

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "00_setup", "00_config.R"))

frame_path <- file.path(path_data_processed, "sipp_modeled.parquet")
if (!file.exists(frame_path)) stop("Missing ", frame_path, ". Run 01b_build_modeled_frame.R first.", call. = FALSE)
fr <- arrow::read_parquet(frame_path)
P  <- sm_params()

mult <- names(P$multipliers)

# --- Build the scenario grid -----------------------------------------------------
jct_grid <- tidyr::expand_grid(
  multiplier = mult,
  access     = c("dc_only", "universal"),
  takeup     = c(0.80, 1.00)
) |>
  mutate(
    split        = "jct_15_60_25",
    eligible_col = if_else(access == "dc_only", paste0("is_eligible_dc_", multiplier),
                                                paste0("is_anymatch_", multiplier)),
    match_col    = paste0("univ_sm_match_", multiplier)
  )
alt_grid <- tibble::tibble(
  multiplier = mult, access = "universal", takeup = 1.00, split = "alt_15_25_60",
  eligible_col = paste0("is_anymatch_", multiplier),
  match_col    = paste0("univ_sm_match_", multiplier, "_alt")
)
grid <- bind_rows(jct_grid, alt_grid)
stopifnot(nrow(grid) == 20L)

# --- Run every scenario through the shared engine --------------------------------
rows <- lapply(seq_len(nrow(grid)), function(i) {
  g <- grid[i, ]
  nm <- sprintf("%s_%s_%s_%s", g$multiplier, g$access,
                ifelse(g$takeup >= 1, "full", "auto80"), g$split)
  out <- run_scenario(fr, nm, g$eligible_col, g$match_col,
                      participation_rate = g$takeup, scenario_group = "robustness", seed = cfg$seed)
  cbind(g[, c("multiplier", "access", "takeup", "split")], out)
})
res <- bind_rows(rows)

# --- Deltas vs the m100 universal-full JCT-split anchor + % of JCT ----------------
jct_fy2028 <- P$jct_annual_M[["FY2028"]]
anchor_cost <- res$annual_cost_M[res$multiplier == "m100" & res$access == "universal" &
                                 res$takeup == 1.00 & res$split == "jct_15_60_25"]
res <- res |>
  mutate(
    delta_cost_vs_m100_universal_full_M = round(annual_cost_M - anchor_cost, 0),
    pct_of_jct_fy2028 = round(annual_cost_M / jct_fy2028 * 100, 1)
  )

# --- Write outputs ---------------------------------------------------------------
wb <- createWorkbook()
addWorksheet(wb, "Robustness"); writeData(wb, "Robustness", as.data.frame(res))
notes <- data.frame(note = c(
  sprintf("Generated %s.", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "Source: canonical modeled frame data/processed/sipp_modeled.parquet (01b_build_modeled_frame.R).",
  sprintf("Income projected to TY2027 (x%.3f); match = factor x %.2f x min(contribution, $%d).",
          P$income_projection_factor, P$match_rate_max, P$contribution_cap),
  "dc_only access = existing DC-account holders; universal = all in-universe workers.",
  "jct_15_60_25 vs alt_15_25_60 = contribution-rate split for workers without an existing plan."
))
addWorksheet(wb, "Methodology Notes"); writeData(wb, "Methodology Notes", notes)
saveWorkbook(wb, file.path(path_output_tbl_main, "sm_robustness_scenarios.xlsx"), overwrite = TRUE)

jsonlite::write_json(res, file.path(path_output_intermediate, "sm_robustness_snapshot.json"),
                     pretty = TRUE, auto_unbox = TRUE, dataframe = "rows")

# --- Cross-check: the m{100..200} universal-full JCT rows must equal 03a's universal scenarios ---
uni_full <- res |> filter(access == "universal", takeup == 1.00, split == "jct_15_60_25") |>
  arrange(match(multiplier, mult))
message("03b: universal-full cost by multiplier ($M): ",
        paste(sprintf("%s=%.0f", uni_full$multiplier, uni_full$annual_cost_M), collapse = "  "),
        "  (must equal 03a: 9192 / 16114 / 24267 / 41067)")
message("03b complete. ", nrow(res), " scenarios written.")
