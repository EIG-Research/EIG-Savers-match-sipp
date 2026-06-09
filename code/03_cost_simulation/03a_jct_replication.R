# 03a_jct_replication.R -- Saver's Match cost: JCT replication + four-multiplier counterfactuals.
# Author: Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - What is the one-year Saver's Match cost under current law (1.00x) and expanded
#                     AGI-threshold designs (1.25x / 1.50x / 2.00x), across participation assumptions,
#                     benchmarked against the JCT (JCX-21-22) score?
#
# Thin stage: reads the ONE canonical modeled frame (data/processed/sipp_modeled.parquet) -- which
# already carries projected income, eligibility per multiplier, account access, and per-person match
# dollars -- and runs the participation scenarios via the shared run_scenario() engine. All policy
# constants come from sm_params(). No income/threshold/eligibility/contribution math is re-derived here.

rm(list = ls())
suppressMessages({ library(dplyr); library(arrow); library(openxlsx) })

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "00_setup", "00_config.R"))

frame_path <- file.path(path_data_processed, "sipp_modeled.parquet")
if (!file.exists(frame_path)) {
  stop("Missing ", frame_path, ". Run 01b_build_modeled_frame.R first.", call. = FALSE)
}
fr <- arrow::read_parquet(frame_path)
P  <- sm_params()

# --- Eight headline scenarios ---------------------------------------------------
# JCT baseline (existing DC-account holders, band contributions, current-law thresholds):
run <- function(...) run_scenario(fr, ..., seed = cfg$seed)
results_tbl <- bind_rows(
  run("no_auto",               "is_eligible_dc_m100", "sm_match_per_person", participation_rate = P$takeup_no_auto),
  run("sipp_conditional",      "is_eligible_dc_m100", "sm_match_per_person", use_observed = TRUE),
  run("auto_enroll",           "is_eligible_dc_m100", "sm_match_per_person", participation_rate = P$takeup_auto_enroll),
  run("full_participation_dc", "is_eligible_dc_m100", "sm_match_per_person", participation_rate = 1.0,
      scenario_group = "policy_counterfactual"),
  # Universal access, full participation, by AGI-threshold multiplier:
  run("universal_m100", "is_anymatch_m100", "univ_sm_match_m100", participation_rate = 1.0, scenario_group = "policy_counterfactual"),
  run("universal_m125", "is_anymatch_m125", "univ_sm_match_m125", participation_rate = 1.0, scenario_group = "policy_counterfactual"),
  run("universal_m150", "is_anymatch_m150", "univ_sm_match_m150", participation_rate = 1.0, scenario_group = "policy_counterfactual"),
  run("universal_m200", "is_anymatch_m200", "univ_sm_match_m200", participation_rate = 1.0, scenario_group = "policy_counterfactual")
)

# --- JCT reconciliation columns ---
jct_fy2028 <- P$jct_annual_M[["FY2028"]]
results_tbl <- results_tbl |>
  mutate(
    jct_fy2028_M        = jct_fy2028,
    pct_of_jct_fy2028   = round(annual_cost_M / jct_fy2028 * 100, 1),
    gap_vs_jct_fy2028_M = round(annual_cost_M - jct_fy2028, 0)
  )

# --- Write the workbook. "All Scenario Results" sheet header names are the
#     contract consumed by 05a_cost_comparison_figures.R; keep them stable. ---
all_scenarios <- results_tbl |>
  transmute(
    Scenario = scenario,
    Group = scenario_group,
    `Eligible (M)` = eligible_count_M,
    `Participants (M)` = participant_count_M,
    `Take-up Rate` = takeup_rate,
    `Avg Match/Person ($)` = avg_match_per_person,
    `Annual Cost ($M)` = annual_cost_M,
    `JCT FY2028 ($M)` = jct_fy2028_M,
    `% of JCT FY2028` = pct_of_jct_fy2028,
    `Gap vs JCT FY2028 ($M)` = gap_vs_jct_fy2028_M
  )

params_sheet <- data.frame(
  parameter = c("income_projection_factor", "match_rate_max", "contribution_cap",
                "takeup_no_auto", "takeup_auto_enroll", "jct_fy2028_M",
                "threshold_lower_Single", "threshold_upper_Single"),
  value = c(P$income_projection_factor, P$match_rate_max, P$contribution_cap,
            P$takeup_no_auto, P$takeup_auto_enroll, jct_fy2028,
            P$threshold_lower[["Single"]], P$threshold_upper[["Single"]])
)
notes_sheet <- data.frame(note = c(
  sprintf("Generated %s.", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "Source: canonical modeled frame data/processed/sipp_modeled.parquet (01b_build_modeled_frame.R).",
  sprintf("Income projected SIPP 2024 -> TY2027 (x%.3f); statutory 2027 thresholds.", P$income_projection_factor),
  "JCT baseline scenarios: existing DC-account holders, SOI-band contributions, current-law thresholds.",
  "Universal scenarios: full participation; non-account workers contribute via the 15/60/25 rate split.",
  "Match per person = SM factor x 0.50 x min(contribution_2027, $2,000)."
))

wb <- createWorkbook()
addWorksheet(wb, "All Scenario Results"); writeData(wb, "All Scenario Results", all_scenarios)
addWorksheet(wb, "Parameters");           writeData(wb, "Parameters", params_sheet)
addWorksheet(wb, "Methodology Notes");    writeData(wb, "Methodology Notes", notes_sheet)
saveWorkbook(wb, file.path(path_output_tbl_main, "sm_jct_replication_scenarios.xlsx"), overwrite = TRUE)

message("03a complete. Universal-access full-participation cost by multiplier ($M): ",
        paste(sprintf("%s=%.0f", results_tbl$scenario[5:8], results_tbl$annual_cost_M[5:8]), collapse = "  "))
print(as.data.frame(all_scenarios), row.names = FALSE)
