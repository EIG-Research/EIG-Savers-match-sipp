# 04_reassessment_checks.R — Brandt re-review: recompute first-round operational
# counts on the CURRENT (IRS-anchored) pivots. Run from repo root.
# Output: economist-panel/06-brandt-retirement-institutions/tables/reassessment_checks.csv

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr)
})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
scn <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")

cat("=== pivot_table (verify current pivots) ===\n")
print(as.data.frame(piv))
cat("\n=== scenario_results ===\n")
print(as.data.frame(scn))

w <- sim$WPFINWGT
M <- function(x) sum(w[x], na.rm = TRUE) / 1e6

elig <- sim$eligible_flag
fed  <- grepl("universal|federal", sim$route_chr, ignore.case = TRUE)
cat("\nroute_chr values:", paste(unique(sim$route_chr), collapse = " | "), "\n")

res <- list()
res$universe_M                 <- M(rep(TRUE, nrow(sim)))
res$eligible_M                 <- M(elig)
res$fed_route_total_M          <- M(fed)                       # accounts the federal RK must service
res$fed_route_eligible_M       <- M(fed & elig)
res$fed_route_noneligible_M    <- M(fed & !elig)
res$fed_selfemp_M              <- M(fed & sim$self_employed_flag)
res$fed_selfemp_eligible_M     <- M(fed & sim$self_employed_flag & elig)
res$emp_route_M                <- M(!fed)
res$emp_route_eligible_M       <- M(!fed & elig)

# Sub-cap eligibles (match < $1,000) — the old reconciliation population
subcap <- elig & sim$match_per_worker_num < 999.995
res$subcap_eligible_M          <- M(subcap)
res$capbound_eligible_M        <- M(elig & sim$match_per_worker_num >= 999.995)

# Cliff-adjacent: within $2,000 of the zero-match endpoint, by filing group
ep <- piv %>% select(matches("filing|group"), matches("endpoint|pivot"))
cat("\npivot table cols:", paste(names(piv), collapse = ", "), "\n")
# generic join on filing group
fg_col <- names(piv)[grepl("filing|group", names(piv), ignore.case = TRUE)][1]
ep_col <- names(piv)[grepl("endpoint", names(piv), ignore.case = TRUE)][1]
piv_j <- piv %>% select(all_of(c(fg_col, ep_col))) %>%
  rename(filing_group_chr = !!fg_col, endpoint = !!ep_col)
sim2 <- sim %>% left_join(piv_j, by = "filing_group_chr")
cliff <- sim2$eligible_flag & (sim2$endpoint - sim2$magi_num) <= 2000 & (sim2$endpoint - sim2$magi_num) >= 0
res$cliff_within2k_M <- sum(sim2$WPFINWGT[cliff], na.rm = TRUE)/1e6

# Small-dollar economics on the federal route (universe defaulters)
fed_df <- sim %>% filter(fed)
wq <- function(x, wt, p) { o <- order(x); x <- x[o]; wt <- wt[o]
  cw <- cumsum(wt)/sum(wt); x[which(cw >= p)[1]] }
res$fed_median_contrib   <- wq(fed_df$default_contrib_num, fed_df$WPFINWGT, 0.5)
sh <- function(thr) sum(fed_df$WPFINWGT[fed_df$default_contrib_num < thr], na.rm=TRUE) /
                    sum(fed_df$WPFINWGT, na.rm=TRUE) * 100
res$fed_share_under_250  <- sh(250)
res$fed_share_under_500  <- sh(500)
res$fed_share_under_1000 <- sh(1000)
# first-year fee revenue at a 0.15% cap on average balance ~ contrib/2
res$fee_rev_median_firstyear <- res$fed_median_contrib * 0.0015 / 2
# breakeven balance for $20/account at 15bp
res$breakeven_balance <- 20 / 0.0015

# New-entrant proxy for the D7 no-prior-year-return edge case: eligible workers age 18-21
for (a in c(21, 24)) {
  res[[paste0("eligible_age18_", a, "_M")]] <- M(elig & sim$TAGE <= a)
  res[[paste0("fed_eligible_age18_", a, "_M")]] <- M(elig & fed & sim$TAGE <= a)
}

out <- tibble(metric = names(res), value = unlist(res))
print(as.data.frame(out), digits = 6)
write.csv(out, "economist-panel/06-brandt-retirement-institutions/tables/reassessment_checks.csv", row.names = FALSE)
cat("\nWritten: tables/reassessment_checks.csv\n")
