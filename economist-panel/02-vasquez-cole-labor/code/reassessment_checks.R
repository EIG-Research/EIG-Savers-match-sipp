# Re-review spot-checks on the IRS-anchored (current) design — Vásquez-Cole
# Refreshes the first-round distributional numbers on the new pivots.
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/02-vasquez-cole-labor/code/reassessment_checks.R

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

w_m <- function(w) sum(w) / 1e6

## 0. Sanity: eligible count and routing on the current run -------------------
elig <- sim %>% filter(eligible_flag)
cat("Universe (M):", round(w_m(sim$WPFINWGT), 2), "\n")
cat("Eligible (M):", round(w_m(elig$WPFINWGT), 2),
    "| share:", round(100 * sum(elig$WPFINWGT) / sum(sim$WPFINWGT), 1), "%\n")
print(elig %>% group_by(route_chr) %>%
        summarise(workers_M = round(w_m(WPFINWGT), 2),
                  full_part_cost_B = round(sum(WPFINWGT * match_per_worker_num) / 1e9, 2),
                  .groups = "drop"))
cat("Self-employed eligible (M):",
    round(w_m(elig$WPFINWGT[which(elig$self_employed_flag)]), 2), "\n\n")

## 1. Access typology among eligible (truly excluded block) -------------------
wq <- function(x, w, p) {
  o <- order(x); x <- x[o]; w <- w[o]
  cw <- cumsum(w) / sum(w)
  x[which(cw >= p)[1]]
}
typ <- elig %>%
  mutate(access_type = case_when(
    has_existing_dc_flag ~ "1. Has DC account",
    any_retirement_access_v2_chr == "Yes" ~ "2. No account, has access",
    any_retirement_access_v2_chr == "No"  ~ "3. Truly excluded (no acct, no access)",
    TRUE ~ "4. No account, access unknown"))
tot_dollars <- sum(elig$WPFINWGT * elig$match_per_worker_num)
typ_tab <- typ %>% group_by(access_type) %>%
  summarise(workers_M = round(w_m(WPFINWGT), 2),
            share_elig = round(100 * sum(WPFINWGT) / sum(elig$WPFINWGT), 1),
            med_earn = round(wq(earnings_num, WPFINWGT, .5)),
            dollars_B = round(sum(WPFINWGT * match_per_worker_num) / 1e9, 2),
            share_dollars = round(100 * sum(WPFINWGT * match_per_worker_num) / tot_dollars, 1),
            .groups = "drop")
print(typ_tab)
cat("\n")

## 2. Match per worker by personal-earnings decile of ELIGIBLE workers --------
ed_breaks <- sapply(seq(.1, .9, .1), function(p) wq(elig$earnings_num, elig$WPFINWGT, p))
elig_d <- elig %>%
  mutate(earn_dec = findInterval(earnings_num, ed_breaks) + 1)
dec_tab <- elig_d %>% group_by(earn_dec) %>%
  summarise(workers_M = round(w_m(WPFINWGT), 2),
            med_earn = round(wq(earnings_num, WPFINWGT, .5)),
            mean_match = round(sum(WPFINWGT * match_per_worker_num) / sum(WPFINWGT)),
            .groups = "drop")
cat("Eligible-worker personal-earnings deciles (full participation):\n")
print(as.data.frame(dec_tab))
cat("\n")

## 3. Secondary-earner exclusion: eligibility in bottom UNIVERSE earnings decile
ud_breaks <- sapply(seq(.1, .9, .1), function(p) wq(sim$earnings_num, sim$WPFINWGT, p))
sim_d <- sim %>% mutate(earn_dec = findInterval(earnings_num, ud_breaks) + 1)
d1 <- sim_d %>% filter(earn_dec == 1)
cat("Universe decile 1 (personal earnings): median earnings",
    round(wq(d1$earnings_num, d1$WPFINWGT, .5)), "\n")
cat("  Share eligible:", round(100 * sum(d1$WPFINWGT[d1$eligible_flag]) / sum(d1$WPFINWGT), 1), "%\n")
d1_inel <- d1 %>% filter(!eligible_flag)
cat("  Ineligible decile-1 workers (M):", round(w_m(d1_inel$WPFINWGT), 2),
    "| their median household MAGI:", round(wq(d1_inel$magi_num, d1_inel$WPFINWGT, .5)), "\n")
cat("  Share of ineligible decile-1 who are MFJ:",
    round(100 * sum(d1_inel$WPFINWGT[d1_inel$filing_group_chr == "mfj"]) / sum(d1_inel$WPFINWGT), 1), "%\n\n")

## 4. Bottom universe earnings quintile: hybrid mean match per worker ---------
q_breaks <- sapply(seq(.2, .8, .2), function(p) wq(sim$earnings_num, sim$WPFINWGT, p))
sim_q <- sim %>% mutate(earn_q = findInterval(earnings_num, q_breaks) + 1)
q1 <- sim_q %>% filter(earn_q == 1)
cat("Universe bottom earnings quintile: workers (M):", round(w_m(q1$WPFINWGT), 2),
    "| median earnings:", round(wq(q1$earnings_num, q1$WPFINWGT, .5)), "\n")
cat("  Hybrid mean match per worker (all Q1 workers, full part.): $",
    round(sum(q1$WPFINWGT * q1$match_per_worker_num) / sum(q1$WPFINWGT)), "\n\n")

## 5. Current-law contrast on the same earnings quintile ----------------------
cl <- read_parquet("data/processed/sipp_modeled.parquet") %>% filter(in_universe)
clq_breaks <- sapply(seq(.2, .8, .2), function(p) wq(cl$earnings_2027, cl$weight, p))
cl_q1 <- cl %>% mutate(earn_q = findInterval(earnings_2027, clq_breaks) + 1) %>% filter(earn_q == 1)
cat("Current-law (1.00x, full part., no gate) mean match per worker, bottom quintile: $",
    round(sum(cl_q1$weight * cl_q1$sm_match_per_person, na.rm = TRUE) / sum(cl_q1$weight)), "\n")
cat("Current-law gated on existing DC account, bottom quintile: $",
    round(sum(cl_q1$weight * cl_q1$sm_match_per_person * as.numeric(cl_q1$has_dc_account %in% TRUE),
              na.rm = TRUE) / sum(cl_q1$weight)), "\n")
