# =============================================================================
# 03_stakeholder_table.R — Stakeholder position matrix (Liu, panel 08).
# Documented positions are sourced; "Predicted" entries are the author's
# inference and are flagged as such in the table itself.
#
# Output: economist-panel/08-liu-political-economy/tables/stakeholder_positions.csv
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/08-liu-political-economy/code/03_stakeholder_table.R
# =============================================================================

suppressPackageStartupMessages(library(dplyr))

out_tab <- "economist-panel/08-liu-political-economy/tables"

stakeholders <- tribble(
  ~stakeholder, ~sec6433_implementation, ~rsaa, ~april_2026_eo, ~predicted_hybrid_position, ~key_sources,

  "ICI (mutual fund industry)",
  "Supportive in principle; wants implementation through existing private accounts",
  "No formal position located; opposes 'a government-run one-size-fits-all approach' (Feb 2026 SOTU statement)",
  "Welcomed: 'This model works... let's work together to build on the foundation already in place'",
  "PREDICTED: oppose the federal universal account; support match expansion routed to private IRAs/401(k)s",
  "401(k) Specialist SOTU roundup (Feb 2026, panel sources/); 401(k) Specialist EO roundup (May 2026, _shared/sources/)",

  "ERIC (large plan sponsors)",
  "Engaged; urges Treasury to prioritize simplicity in SECURE 2.0 rulemaking",
  "Not documented",
  "No statement located in EO roundups",
  "PREDICTED: wary of any payroll-routing or notice obligations on large employers; neutral on the match schedule itself",
  "eric.org press releases on SECURE 2.0 rulemaking (2024-2025)",

  "ARA / ASPPA (plan professionals)",
  "Actively pushing IRS to implement (IRSAC 2026 recommendations); wants plans free to refuse match deposits",
  "Opposed: federal account with subsidized match would lead small employers to drop 401(k)s",
  "Supportive: 'strongly support automatic enrollment of uncovered workers and expansion of the Saver's Match' (Graff)",
  "PREDICTED: oppose the federal account as RSAA redux; persuadable on the match redesign if employer-plan routing is primary",
  "ASPPA IRSAC article (Jan 2026); ASPPA RSAA article (May 2025); 401(k) Specialist EO roundup (all _shared/sources/)",

  "AARP",
  "Supportive of saver incentives (background)",
  "Endorsed: 'would help more families across the country save for retirement' (Sweeney, 2025)",
  "No statement located in EO roundups",
  "PREDICTED: support the hybrid; strongest organized mass-membership ally",
  "Hickenlooper press release (May 2025, _shared/sources/)",

  "State auto-IRA programs (NAGDCA)",
  "Supportive; state programs are candidate match destinations",
  "Historically cautious on federal preemption (inference)",
  "Applauded TrumpIRA.gov announcement, citing Pew's 56M uncovered workers",
  "PREDICTED: support conditional on the substitution clause (state auto-IRA may stand in for the federal account); oppose if preempted",
  "401(k) Specialist EO roundup (May 2026, _shared/sources/); Georgetown CRI data ($3.2B assets, May 2026, panel sources/)",

  "Recordkeepers (Fidelity, Vanguard, Empower)",
  "Supportive; building Saver's Match deposit rails is the live operational question",
  "Not documented as firms; trade groups opposed",
  "Empower CEO: initiative 'can help bring millions into the system'",
  "PREDICTED: support the employer-plan routing (19.4M eligible members stay in their systems); oppose the federal account as a TSP-like competitor for 26.7M workers",
  "401(k) Specialist EO roundup (May 2026, _shared/sources/)",

  "Payroll processors (ADP, Paychex)",
  "Not documented",
  "Not documented",
  "Not documented",
  "PREDICTED: support; universal auto-enrollment creates mandatory demand for payroll integration services across every small employer",
  "Author's inference from state auto-IRA implementation experience",

  "Fintech IRA providers (robo-advisors)",
  "Not documented",
  "Chamber of Progress endorsed RSAA: 'gives workers the flexibility they want'",
  "Marketplace listing under a 0.15 percent fee cap favors low-cost index/robo providers (structural read)",
  "PREDICTED: split - support the EO marketplace; the hybrid's federal account would absorb their target market of unserved savers",
  "Hickenlooper press release (May 2025, _shared/sources/); EO Sec. 2 criteria (_shared/sources/)",

  "Unions / left retirement-policy coalition",
  "Supportive (background)",
  "Ghilarducci-aligned academics back federal accounts; union positions not documented",
  "Ghilarducci: 'the underlying move is exactly right... largest potential expansion of retirement coverage since Social Security'",
  "PREDICTED: support the hybrid, but press to pair it with Social Security financing - the Ghilarducci condition",
  "401(k) Specialist EO roundup (May 2026, _shared/sources/)",

  "NFIB (small business)",
  "Not documented on sec. 6433 itself",
  "Not documented; opposes adjacent auto-IRA employer mandates",
  "Not documented",
  "PREDICTED: oppose the auto-enrollment employer obligation (87 percent of MI members opposed the state analog, Mar 2026); Pew counterpoint - 75 percent of NFIB-member respondents support state programs",
  "NFIB Michigan testimony (Mar 2026, panel sources/); Pew small-business survey (Mar 2026, panel sources/)"
)

write.csv(stakeholders, file.path(out_tab, "stakeholder_positions.csv"),
          row.names = FALSE)
cat("Wrote", nrow(stakeholders), "stakeholder rows.\n")
