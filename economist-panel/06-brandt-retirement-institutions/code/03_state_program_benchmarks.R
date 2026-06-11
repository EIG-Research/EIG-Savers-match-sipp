# ============================================================================
# 03_state_program_benchmarks.R
# Panelist 06 (Brandt): state auto-IRA scale benchmarks vs. the proposal's
# universal-account population, plus ramp-time arithmetic.
#
# The SIPP extract has no state geography, so this table combines externally
# sourced program figures (downloaded to sources/, manifest in
# sources/sources.md) with repo-computed populations.
#
# External figures used (access date 2026-06-11):
#  - CalSavers (calsavers.com/home/about.html): 629,000+ funded accounts,
#    $1.6B+ assets, 281,000+ registered employers, as of 3/31/2026.
#    Program launched statewide July 2019.
#  - OregonSaves (OPB, 12/23/2025): ~180,000 accounts, ~$430M assets;
#    pilot launched July 2017.
#  - Illinois Secure Choice (ASPPA, May 2026): 170,151 enrolled savers,
#    >$339M assets; 167,328 funded accounts at year-end 2025; launched 2018.
#  - Pew (Feb 2026): all 15 active state auto-IRA programs combined:
#    >1 million savers, >$2.5B assets.
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/06-brandt-retirement-institutions/code/03_state_program_benchmarks.R
#
# Output: tables/state_auto_ira_benchmarks.csv
# ============================================================================

suppressMessages({
  library(arrow)
  library(dplyr)
})

out_tab <- "economist-panel/06-brandt-retirement-institutions/tables"

d <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
ua_total_m <- sum(d$WPFINWGT[d$route_chr == "universal_account"]) / 1e6
ua_elig_m  <- sum(d$WPFINWGT[d$route_chr == "universal_account" & d$eligible_flag]) / 1e6

bench <- tibble::tribble(
  ~program, ~launch_year, ~years_operating_to_2026, ~funded_accounts, ~assets_usd_m, ~avg_balance_usd,
  "CalSavers (CA)",              2019, 6.8, 629000, 1600, round(1600e6 / 629000),
  "OregonSaves (OR)",            2017, 8.5, 180000,  430, round(430e6 / 180000),
  "Illinois Secure Choice (IL)", 2018, 7.5, 167328,  339, round(339e6 / 167328),
  "All 15 state auto-IRAs (Pew, Feb 2026)", NA, NA, 1000000, 2500, 2500
) %>%
  mutate(
    proposal_universal_account_m = round(ua_total_m, 1),
    multiple_of_program = round(ua_total_m * 1e6 / funded_accounts, 0)
  )

write.csv(bench, file.path(out_tab, "state_auto_ira_benchmarks.csv"), row.names = FALSE)
cat("Wrote state_auto_ira_benchmarks.csv\n")
print(as.data.frame(bench))

cat(sprintf("\nProposal universal-account route: %.1fM total defaulters (%.1fM match-eligible).\n",
            ua_total_m, ua_elig_m))
cat(sprintf("That is %.0fx the combined funded accounts of ALL state auto-IRA programs (1.0M)\n",
            ua_total_m * 1e6 / 1e6 / 1.0))
cat(sprintf("and %.0fx CalSavers, the largest program, which needed ~7 years to reach 629k accounts.\n",
            ua_total_m * 1e6 / 629000))
cat("Done.\n")
