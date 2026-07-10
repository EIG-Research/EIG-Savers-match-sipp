# 04_reassessment_checks.R — Okafor re-review spot checks (2026-06-11)
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/07-okafor-macro-fiscal/code/04_reassessment_checks.R
#
# 1. Verify the current canonical base (eligible count, cost ladder, route split)
#    from the regenerated row-level frame.
# 2. Audit the recomputed ten-year path arithmetic (_shared/anchoring/ten_year_path.md).
# 3. Quantify the fiscal-year deposit-lag effect the recomputed path omits.
# 4. Re-run the national-saving decomposition on the current base (D8 contest).

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

## ---- 1. Base verification -------------------------------------------------
elig <- sim %>% filter(eligible_flag)
cat("== Base verification ==\n")
cat(sprintf("Universe (M): %.2f\n", sum(sim$WPFINWGT) / 1e6))
cat(sprintf("Eligible (M): %.2f  (share %.1f%%)\n",
            sum(elig$WPFINWGT) / 1e6,
            100 * sum(elig$WPFINWGT) / sum(sim$WPFINWGT)))
full_cost <- sum(elig$WPFINWGT * elig$match_per_worker_num) / 1e9
cat(sprintf("Full-participation cost ($B): %.2f\n", full_cost))
cat(sprintf("80%% auto-enrollment ($B): %.2f\n", 0.80 * full_cost))
cat(sprintf("Avg match per eligible worker ($): %.0f\n",
            sum(elig$WPFINWGT * elig$match_per_worker_num) / sum(elig$WPFINWGT)))

route <- elig %>%
  group_by(route_chr) %>%
  summarise(
    eligible_m   = sum(WPFINWGT) / 1e6,
    full_cost_b  = sum(WPFINWGT * match_per_worker_num) / 1e9,
    contrib_b    = sum(WPFINWGT * default_contrib_num) / 1e9,
    .groups = "drop"
  )
cat("\nRoute split (full participation):\n")
print(as.data.frame(route))

## ---- 2. Ten-year path arithmetic audit ------------------------------------
cat("\n== Ten-year path audit (FY2027 base rungs, growth from FY2027) ==\n")
rungs <- c(conservative = 14.15, headline80 = 19.09, ceiling = 23.87)
tenyr <- function(base, g, n = 10) base * sum((1 + g)^(0:(n - 1)))
for (nm in names(rungs)) {
  b <- rungs[[nm]]
  cat(sprintf("%-12s flat: %6.1f | C-CPI-U 2.7%%: %6.1f (yr-10 annual %5.1f) | wage 3.9%%: %6.1f\n",
              nm, tenyr(b, 0), tenyr(b, 0.027), b * 1.027^9, tenyr(b, 0.039)))
}

## ---- 3. Fiscal-year deposit-lag variant -----------------------------------
# TY-t matches deposit at filing, i.e., in FY t+1 (JCT scored the enacted match
# with zero outlays before FY2028). A FY2027-FY2036 window then contains only
# TY2027-TY2035 = 9 tax years of cost.
cat("\n== FY deposit-lag variant: FY2027-36 window holds 9 tax years ==\n")
for (nm in names(rungs)) {
  b <- rungs[[nm]]
  full10 <- tenyr(b, 0.027)
  lag9   <- tenyr(b, 0.027, n = 9)
  cat(sprintf("%-12s 10 tax-years: %6.1f | in-window with FY lag: %6.1f | gap: %5.1f (%4.1f%%)\n",
              nm, full10, lag9, full10 - lag9, 100 * (full10 - lag9) / full10))
}

## ---- 4. National-saving decomposition on the current base (D8) ------------
# Chetty et al. (2014 QJE) logic from round one, re-based. 80% central case:
# match and policy-induced default contributions scale with the take-up rate.
cat("\n== National saving, 80% central case ==\n")
take_up <- 0.80
univ <- route %>% filter(grepl("univ|federal", route_chr, ignore.case = TRUE))
empl <- route %>% filter(!grepl("univ|federal", route_chr, ignore.case = TRUE))
match_univ  <- take_up * univ$full_cost_b
match_empl  <- take_up * empl$full_cost_b
contrib_univ <- take_up * univ$contrib_b   # policy-induced default flow, universal route
public_dissaving <- take_up * full_cost
cases <- data.frame(case = c("Low", "Central", "High"),
                    p_univ = c(0.75, 0.85, 0.95),
                    p_empl = c(0.30, 0.50, 0.70))
for (i in seq_len(nrow(cases))) {
  new_priv <- cases$p_univ[i] * (contrib_univ + match_univ) + cases$p_empl[i] * match_empl
  net <- new_priv - public_dissaving
  cat(sprintf("%-8s new private saving: %5.1f | public dissaving: %5.1f | net: %+5.1f (%+.2f per federal $)\n",
              cases$case[i], new_priv, public_dissaving, net, net / public_dissaving))
}
cat(sprintf("\nMemo: universal-route match $%.2fB, employer-route match $%.2fB, universal default contributions $%.2fB (all at %.0f%% take-up)\n",
            match_univ, match_empl, contrib_univ, 100 * take_up))
