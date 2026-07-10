# Re-review spot-check: federal universal-account flow on the CURRENT (re-anchored) base.
# Dr. Jack Calloway, 2026-06-11. Read-only on data; writes nothing outside this folder.
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/05-calloway-libertarian/code/04_rereview_federal_flow.R

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

w <- function(x, wt) sum(x * wt, na.rm = TRUE)

# --- Validate against canonical numbers ---
universe_m <- sum(sim$WPFINWGT) / 1e6
elig_m     <- w(sim$eligible_flag, sim$WPFINWGT) / 1e6
cat(sprintf("Universe: %.2fM | Eligible: %.2fM (%.1f%%)\n",
            universe_m, elig_m, 100 * elig_m / universe_m))

ceiling_b <- w(ifelse(sim$eligible_flag == 1, sim$match_per_worker_num, 0), sim$WPFINWGT) / 1e9
cat(sprintf("Full-participation match ceiling: $%.2fB\n", ceiling_b))

# --- Routing: whole universe and eligible only ---
cat("\nRouting (whole 145M universe):\n")
sim %>%
  group_by(route_chr) %>%
  summarise(workers_m = sum(WPFINWGT) / 1e6,
            contrib_flow_b = sum(default_contrib_num * WPFINWGT) / 1e9) %>%
  mutate(share = workers_m / sum(workers_m)) %>%
  as.data.frame() %>% print()

cat("\nRouting (eligible only):\n")
sim %>%
  filter(eligible_flag == 1) %>%
  group_by(route_chr) %>%
  summarise(workers_m = sum(WPFINWGT) / 1e6,
            contrib_flow_b = sum(default_contrib_num * WPFINWGT) / 1e9,
            match_flow_b = sum(match_per_worker_num * WPFINWGT) / 1e9) %>%
  mutate(share = workers_m / sum(workers_m)) %>%
  as.data.frame() %>% print()

# --- Federal-account inflow scenarios (contributions + match deposits) ---
fed <- sim %>% filter(grepl("federal|universal", route_chr, ignore.case = TRUE))
fed_workers_m   <- sum(fed$WPFINWGT) / 1e6
fed_contrib_b   <- sum(fed$default_contrib_num * fed$WPFINWGT) / 1e9
fed_match_b     <- sum(ifelse(fed$eligible_flag == 1, fed$match_per_worker_num, 0) * fed$WPFINWGT) / 1e9

cat(sprintf("\nFederal-account branch: %.2fM workers defaulted (%.1f%% of universe)\n",
            fed_workers_m, 100 * fed_workers_m / universe_m))
cat(sprintf("Full participation: contributions $%.1fB + match $%.2fB = $%.1fB/yr inflow\n",
            fed_contrib_b, fed_match_b, fed_contrib_b + fed_match_b))
for (p in c(0.59, 0.80)) {
  cat(sprintf("At %.0f%% take-up: contributions $%.1fB + match $%.2fB = $%.1fB/yr inflow\n",
              100 * p, p * fed_contrib_b, p * fed_match_b, p * (fed_contrib_b + fed_match_b)))
}
cat("\nBenchmark: entire TSP CY2023 inflow = $44.7B (FRTIB audited financials).\n")
