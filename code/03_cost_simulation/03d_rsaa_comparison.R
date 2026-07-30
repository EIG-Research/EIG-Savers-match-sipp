# 03d_rsaa_comparison.R -- Common-basis comparison: Universal Saver's Match (hybrid) vs. RSAA (S.1526).
# Author: Ben Glasner
# research title - Saver's Match: eligibility and cost analysis (SECURE 2.0 sec 103 / IRC sec 6433)
# research question - On one SIPP universe projected to TY2027, how do the Universal Saver's Match
#                     hybrid and the Retirement Savings for Americans Act (S.1526, §25F Government
#                     Match Tax Credit) compare on GENEROSITY, COST, and COVERAGE?
#
# Design: dedicated, self-contained module. Reads the canonical modeled frame
# (data/processed/sipp_modeled.parquet -- already the hybrid's exact universe/weights, TY2027 income)
# and the published hybrid outputs (data/processed/universal_sm_hybrid/). Computes RSAA fresh from the
# verified S.1526 §25F parameters in rsaa_params(). Does NOT modify the shared frame builder.
# Spec + verification: drafts/rsaa_comparison/00_comparison_design_spec.md.
#
# The "effect" (behavioral / wealth / crowd-out) dimension is intentionally OUT OF SCOPE
# (author decision 2026-07-13): a static SIPP model cannot produce it. Generosity/cost/coverage only.

rm(list = ls())
suppressMessages({ library(dplyr); library(arrow); library(openxlsx) })

source(file.path(Sys.getenv("EIG_PROJECT_ROOT", unset = getwd()), "code", "00_setup", "00_config.R"))

# ---------------------------------------------------------------------------
# 0) Inputs
# ---------------------------------------------------------------------------
frame_path <- file.path(path_data_processed, "sipp_modeled.parquet")
hybrid_dir <- file.path(path_data_processed, "universal_sm_hybrid")
if (!file.exists(frame_path)) stop("Missing ", frame_path, ". Run 01b first.", call. = FALSE)
if (!dir.exists(hybrid_dir))  stop("Missing ", hybrid_dir, ". Run the 04 hybrid pipeline first.", call. = FALSE)

fr <- arrow::read_parquet(frame_path)
R  <- rsaa_params()

hybrid_scn   <- arrow::read_parquet(file.path(hybrid_dir, "scenario_results.parquet"))
hybrid_pivot <- arrow::read_parquet(file.path(hybrid_dir, "pivot_table.parquet"))

out_tbl_dir <- file.path(path_output, "tables", "rsaa_comparison")
out_fig_dir <- file.path(path_output, "data", "figure_data")
dir.create(out_tbl_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_fig_dir, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# 1) Per-worker RSAA Government Match Tax Credit (§25F), at the 3% auto-default
# ---------------------------------------------------------------------------
# gross income proxy = individual TY2027 total personal income; phaseout amount by filing status.
M <- R$applicable_median_income_2027

phaseout_amt_for <- function(filing_status_chr) {
  m <- R$phaseout_mult[filing_status_chr]
  m <- ifelse(is.na(m), R$phaseout_mult[["Single"]], m)   # unknown -> treat as single/other
  as.numeric(m) * M
}

rsaa_credit_vec <- function(gross_income, filing_status_chr,
                            contribution_rate = R$default_contribution_rate) {
  gi <- pmax(gross_income, 0)
  phaseout_amt <- phaseout_amt_for(filing_status_chr)

  # §25F(a)-(b): 1% auto + tiered match on the contribution
  contribution <- contribution_rate * gi
  tier1 <- pmin(contribution, R$match_kink1 * gi)                                  # up to 3% of GI
  tier2 <- pmax(0, pmin(contribution, R$match_kink2 * gi) - R$match_kink1 * gi)    # 3%-5% of GI
  match <- R$match_rate_below_kink1 * tier1 + R$match_rate_between * tier2
  auto  <- R$auto_credit_rate * gi
  credit_before_cap <- auto + match

  # §25F(c): cap = 5% of phaseout amount, reduced $75 for each $1,000 "or portion thereof" of GI
  # over the phaseout amount -- a STEP function (any dollar into a new $1,000 band costs a full $75).
  credit_limit_base <- R$credit_limit_share * phaseout_amt
  step_per_1000 <- R$phaseout_slope * 1000   # = $75
  credit_limit <- pmax(0, credit_limit_base - step_per_1000 * ceiling(pmax(0, gi - phaseout_amt) / 1000))

  list(
    credit = pmin(credit_before_cap, credit_limit),
    credit_limit = credit_limit,
    phaseout_amt = phaseout_amt
  )
}

fr <- fr |>
  mutate(
    rsaa_gross_income = personal_income_2027,                    # individual, TY2027
    rsaa_qualifying   = in_universe & any_retirement_access == "No"
  )

rc <- rsaa_credit_vec(fr$rsaa_gross_income, fr$filing_status)
fr$rsaa_credit_limit <- rc$credit_limit
fr$rsaa_credit       <- ifelse(fr$rsaa_qualifying, rc$credit, 0)
# Eligible (§2(15) qualifying worker with a positive, non-phased-out credit limit)
fr$rsaa_eligible     <- fr$rsaa_qualifying & fr$rsaa_credit_limit > 0

# ---------------------------------------------------------------------------
# 2) RSAA coverage + cost at the same participation rungs as the hybrid
# ---------------------------------------------------------------------------
w <- fr$weight
rsaa_eligible_M <- sum(w[fr$rsaa_eligible]) / 1e6
# weight * per-worker credit is in dollars; /1e6 -> $M. Full-participation total.
rsaa_full_cost_M <- sum(w * fr$rsaa_credit) / 1e6                       # dollars -> $M
rsaa_avg_credit  <- sum(w * fr$rsaa_credit) / sum(w[fr$rsaa_eligible])  # $ per eligible worker

rungs <- c(sipp_observed_conditional = 0.59, auto_enroll_80pct = 0.80, full_participation_100pct = 1.00)
rsaa_ladder <- lapply(names(rungs), function(nm) {
  rate <- rungs[[nm]]
  data.frame(
    design = "RSAA (S.1526)",
    scenario = nm,
    eligible_M = round(rsaa_eligible_M, 2),
    participants_M = round(rsaa_eligible_M * rate, 2),
    takeup_rate = rate,
    avg_credit_per_participant = round(rsaa_avg_credit, 0),
    annual_cost_M = round(rsaa_full_cost_M * rate, 0),
    stringsAsFactors = FALSE
  )
}) |> bind_rows()

# Hybrid ladder from published outputs (map the three comparable rungs).
hy_pick <- function(scn) hybrid_scn[hybrid_scn$scenario_name_chr == scn, ]
hybrid_ladder <- bind_rows(
  transform(hy_pick("headline_sipp_observed_conditional"), scenario = "sipp_observed_conditional"),
  transform(hy_pick("sens_auto_enroll_80pct"),             scenario = "auto_enroll_80pct"),
  transform(hy_pick("sens_full_participation_100pct"),     scenario = "full_participation_100pct")
) |>
  transmute(
    design = "Universal Saver's Match (hybrid)",
    scenario,
    eligible_M = round(eligible_count_M_num, 2),
    participants_M = round(participant_count_M_num, 2),
    takeup_rate = round(takeup_rate_num, 2),
    avg_credit_per_participant = round(avg_match_per_person_num, 0),
    annual_cost_M = round(annual_cost_M_num, 0)
  )

ladder_tbl <- bind_rows(hybrid_ladder, rsaa_ladder) |>
  arrange(match(scenario, c("sipp_observed_conditional", "auto_enroll_80pct", "full_participation_100pct")),
          desc(design))

# ---------------------------------------------------------------------------
# 3) Coverage reconciliation (Workstream D): who each design covers, and overlap
# ---------------------------------------------------------------------------
hybrid_eligible_M <- hybrid_ladder$eligible_M[1]   # 44.47 (published)
# Recompute the hybrid-eligible flag presence on this frame for the overlap Venn.
# Hybrid covers all in-universe workers in the MAGI band regardless of access; RSAA covers
# only in-universe workers WITHOUT employer access. Use the frame's any-match m100 band as the
# statutory Saver's Match band proxy is NOT the hybrid band -- instead reconstruct the hybrid
# band from the pivot schedule so the Venn is exact.
piv <- setNames(as.list(hybrid_pivot$pivot_num), hybrid_pivot$filing_group_chr)
end <- setNames(as.list(hybrid_pivot$endpoint_num), hybrid_pivot$filing_group_chr)
fg_key <- fr$filing_group
hybrid_endpoint <- dplyr::case_when(
  fg_key == "single_mfs" ~ end[["single_mfs"]],
  fg_key == "mfj"        ~ end[["mfj"]],
  fg_key == "hoh"        ~ end[["hoh"]],
  TRUE ~ NA_real_
)
fr$hybrid_eligible <- fr$in_universe & !is.na(hybrid_endpoint) & fr$sm_income_2027 < hybrid_endpoint

access_missing_M <- sum(w[fr$in_universe & fr$any_retirement_access == "Missing"]) / 1e6
both_M    <- sum(w[fr$hybrid_eligible & fr$rsaa_eligible]) / 1e6
hy_only_M <- sum(w[fr$hybrid_eligible & !fr$rsaa_eligible]) / 1e6
rs_only_M <- sum(w[!fr$hybrid_eligible & fr$rsaa_eligible]) / 1e6

coverage_tbl <- data.frame(
  metric = c("Hybrid eligible (reconstructed on frame, M)",
             "Hybrid eligible (published, M)",
             "RSAA eligible (M)",
             "Covered by BOTH (M)",
             "Hybrid ONLY (M)",
             "RSAA ONLY (M)",
             "In-universe with Missing access (M)"),
  value = round(c(sum(w[fr$hybrid_eligible]) / 1e6, hybrid_eligible_M, rsaa_eligible_M,
                  both_M, hy_only_M, rs_only_M, access_missing_M), 2),
  stringsAsFactors = FALSE
)

# ---------------------------------------------------------------------------
# 4) Generosity schedule (Workstream C): per-worker credit vs income, at 3% contribution
# ---------------------------------------------------------------------------
# Analytic curves on an income grid, by filing status, holding contribution at 3% for BOTH designs,
# so the figure isolates the match/credit-formula difference.
hybrid_rate_single_curve <- function(income, pivot, endpoint) {
  # 200% at income 0 -> 50% at pivot (linear) -> 0% at endpoint (linear) -> 0 above.
  seg1 <- 2.00 - (2.00 - 0.50) * (income / pivot)                       # income in [0, pivot]
  seg2 <- 0.50 * (endpoint - income) / (endpoint - pivot)               # income in (pivot, endpoint]
  rate <- ifelse(income <= pivot, seg1, ifelse(income <= endpoint, seg2, 0))
  pmax(rate, 0)
}

grid <- seq(0, 180000, by = 500)
fs_map <- list(
  Single = list(fg = "single_mfs"),
  HoH    = list(fg = "hoh"),
  MFJ    = list(fg = "mfj")
)
gen_rows <- lapply(names(fs_map), function(fs) {
  fg <- fs_map[[fs]]$fg
  pivot    <- hybrid_pivot$pivot_num[hybrid_pivot$filing_group_chr == fg]
  endpoint <- hybrid_pivot$endpoint_num[hybrid_pivot$filing_group_chr == fg]
  hyb_rate <- hybrid_rate_single_curve(grid, pivot, endpoint)
  hyb_credit <- pmin(hyb_rate * R$default_contribution_rate * grid, 1000)   # $1,000/person cap
  rc_g <- rsaa_credit_vec(grid, rep(fs, length(grid)))
  data.frame(
    filing_status = fs,
    income = grid,
    hybrid_credit = round(hyb_credit, 2),
    rsaa_credit   = round(rc_g$credit, 2),
    hybrid_credit_share_income = round(ifelse(grid > 0, hyb_credit / grid, NA), 5),
    rsaa_credit_share_income   = round(ifelse(grid > 0, rc_g$credit / grid, NA), 5),
    stringsAsFactors = FALSE
  )
}) |> bind_rows()

# ---------------------------------------------------------------------------
# 5) Write outputs
# ---------------------------------------------------------------------------
write.csv(gen_rows, file.path(out_fig_dir, "rsaa_vs_hybrid_generosity.csv"), row.names = FALSE)
write.csv(ladder_tbl, file.path(out_tbl_dir, "rsaa_vs_hybrid_cost_coverage_ladder.csv"), row.names = FALSE)
write.csv(coverage_tbl, file.path(out_tbl_dir, "rsaa_vs_hybrid_coverage_reconciliation.csv"), row.names = FALSE)

params_sheet <- data.frame(
  parameter = c("applicable_median_income_2027 (M)", "M base (2024 CPS)", "income_projection_factor",
                "phaseout Single/HoH/MFJ", "endpoint Single", "endpoint HoH", "endpoint MFJ",
                "default_contribution_rate", "credit_limit_share", "phaseout_slope"),
  value = c(round(M, 0), R$median_income_base_2024, R$income_projection_factor,
            paste(round(c(1,1.5,2.0) * M, 0), collapse = " / "),
            round(M + R$credit_limit_share * M / R$phaseout_slope, 0),
            round(1.5*M + R$credit_limit_share * 1.5*M / R$phaseout_slope, 0),
            round(2.0*M + R$credit_limit_share * 2.0*M / R$phaseout_slope, 0),
            R$default_contribution_rate, R$credit_limit_share, R$phaseout_slope),
  stringsAsFactors = FALSE
)
notes_sheet <- data.frame(note = c(
  sprintf("Generated %s.", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "Common basis: canonical modeled frame data/processed/sipp_modeled.parquet (hybrid's universe/weights, TY2027).",
  "RSAA per S.1526 §25F, verified against bill text 2026-07-13; see drafts/rsaa_comparison/00_comparison_design_spec.md.",
  "Both designs held at a 3% auto-default contribution so the comparison isolates the match/credit formula.",
  "RSAA gross income = individual personal_income_2027; RSAA phaseout amount by filing status (M / 1.5M / 2.0M).",
  "RSAA eligible = in-universe qualifying worker (no employer access) with a positive (non-phased-out) credit limit.",
  "Hybrid figures are read from the published 04-hybrid outputs; hybrid band reconstructed from the pivot schedule for the Venn.",
  "Effect/behavioral dimension out of scope (author decision 2026-07-13); RSAA effect evidence (RAND/Morningstar) is on other models.",
  "Caveats: SIPP income is a proxy for gross income (~+/-15%); no crowd-out/labor-supply/admin costs; no replicate-weight SEs."
))

wb <- createWorkbook()
addWorksheet(wb, "Cost & Coverage Ladder"); writeData(wb, "Cost & Coverage Ladder", ladder_tbl)
addWorksheet(wb, "Coverage Reconciliation"); writeData(wb, "Coverage Reconciliation", coverage_tbl)
addWorksheet(wb, "RSAA Parameters");         writeData(wb, "RSAA Parameters", params_sheet)
addWorksheet(wb, "Notes");                   writeData(wb, "Notes", notes_sheet)
saveWorkbook(wb, file.path(out_tbl_dir, "rsaa_vs_hybrid_comparison.xlsx"), overwrite = TRUE)

# ---------------------------------------------------------------------------
# 6) Console summary + validation
# ---------------------------------------------------------------------------
stopifnot(
  rsaa_eligible_M > 0,
  all(fr$rsaa_credit >= 0),
  abs(R$phaseout_mult[["MFJ"]] - 2 * R$phaseout_mult[["Single"]]) < 1e-9,
  abs(R$phaseout_mult[["HoH"]] - 1.5 * R$phaseout_mult[["Single"]]) < 1e-9
)
message("03d complete.")
message(sprintf("  M (applicable median income, TY2027) = $%s", format(round(M), big.mark = ",")))
message(sprintf("  RSAA eligible = %.2fM; full-participation cost = $%.1fB; avg credit = $%s",
                rsaa_eligible_M, rsaa_full_cost_M / 1e3, format(round(rsaa_avg_credit), big.mark = ",")))
cat("\n=== Cost & Coverage ladder ===\n"); print(as.data.frame(ladder_tbl), row.names = FALSE)
cat("\n=== Coverage reconciliation ===\n"); print(coverage_tbl, row.names = FALSE)
