# Re-review spot checks (Liu, panelist 08) — run from repo root.
# 1) Re-run the constituency map (filing group x route) on the CURRENT model run.
# 2) Re-test the losers'-map property (zero strict rate/dollar losers among
#    current-law 6433 eligibles) on the NEW IRS-anchored pivots.
# 3) Count self-employed eligibles routed to the federal account.

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

elig <- sim %>% filter(eligible_flag)

cat("== Totals ==\n")
cat(sprintf("Eligible (M): %.2f\n", sum(elig$WPFINWGT) / 1e6))
cat(sprintf("Full-participation cost ($B): %.2f\n",
            sum(elig$WPFINWGT * elig$match_per_worker_num) / 1e9))

cat("\n== Routing ==\n")
elig %>%
  group_by(route_chr) %>%
  summarise(
    eligible_m   = sum(WPFINWGT) / 1e6,
    share        = sum(WPFINWGT) / sum(elig$WPFINWGT),
    dollars_b    = sum(WPFINWGT * match_per_worker_num) / 1e9,
    dollar_share = sum(WPFINWGT * match_per_worker_num) /
                   sum(elig$WPFINWGT * elig$match_per_worker_num),
    mean_rate_pp = weighted.mean(match_rate_pp_num, WPFINWGT),
    .groups = "drop"
  ) %>% as.data.frame() %>% print(digits = 4)

cat("\n== Constituency map: filing group x route ==\n")
cmap <- elig %>%
  group_by(filing_group_chr, route_chr) %>%
  summarise(
    eligible_m   = sum(WPFINWGT) / 1e6,
    share_elig   = sum(WPFINWGT) / sum(elig$WPFINWGT),
    dollars_b    = sum(WPFINWGT * match_per_worker_num) / 1e9,
    mean_rate_pp = weighted.mean(match_rate_pp_num, WPFINWGT),
    .groups = "drop"
  )
print(as.data.frame(cmap), digits = 4)
write.csv(cmap, "economist-panel/08-liu-political-economy/tables/constituency_by_filing_route_rereview.csv",
          row.names = FALSE)

cat("\n== Self-employed eligibles ==\n")
elig %>%
  group_by(self_employed_flag) %>%
  summarise(eligible_m = sum(WPFINWGT) / 1e6, .groups = "drop") %>%
  as.data.frame() %>% print(digits = 4)

# ---- Losers' map on new pivots --------------------------------------------
# Current-law TY2027 phaseouts (IRS Notice 2024-65): rate = 50% below lower,
# linear to 0 at upper.
cl <- tibble::tribble(
  ~filing_group_chr, ~cl_lower, ~cl_upper,
  "single_mfs", 20500, 35500,
  "hoh",        30750, 53250,
  "mfj",        41000, 71000
)

# New hybrid pivots (IRS-anchored): rate = 200 - 150 * magi / pivot, floored at 0.
piv <- tibble::tribble(
  ~filing_group_chr, ~pivot,
  "single_mfs", 32235,
  "hoh",        48353,
  "mfj",        64471
)

lm_chk <- sim %>%
  inner_join(cl,  by = "filing_group_chr") %>%
  inner_join(piv, by = "filing_group_chr") %>%
  mutate(
    cl_rate = case_when(
      magi_num <= cl_lower ~ 50,
      magi_num <  cl_upper ~ 50 * (cl_upper - magi_num) / (cl_upper - cl_lower),
      TRUE ~ 0
    ),
    hy_rate = pmax(0, 200 - 150 * magi_num / pivot),
    cl_dollar_2k = pmin(cl_rate / 100 * 2000, 1000),
    hy_dollar_2k = pmin(hy_rate / 100 * 2000, 1000)
  ) %>%
  filter(cl_rate > 0)   # current-law eligibles

cat("\n== Losers' map (current-law eligibles, new pivots) ==\n")
cat(sprintf("Current-law eligible (M): %.2f\n", sum(lm_chk$WPFINWGT) / 1e6))
cat(sprintf("Strict RATE losers (hybrid < current law), weighted M: %.4f\n",
            sum(lm_chk$WPFINWGT[lm_chk$hy_rate < lm_chk$cl_rate]) / 1e6))
cat(sprintf("Strict DOLLAR losers at $2,000 contribution, weighted M: %.4f\n",
            sum(lm_chk$WPFINWGT[lm_chk$hy_dollar_2k < lm_chk$cl_dollar_2k]) / 1e6))
below50 <- lm_chk %>% filter(hy_rate < 50)
cat(sprintf("Workers whose hybrid rate < 50pp headline (M): %.2f; their mean hybrid rate %.1f vs mean CL phased rate %.1f\n",
            sum(below50$WPFINWGT) / 1e6,
            weighted.mean(below50$hy_rate, below50$WPFINWGT),
            weighted.mean(below50$cl_rate, below50$WPFINWGT)))
cat(sprintf("Minimum (hybrid - CL) rate gap across CL eligibles: %.2f pp\n",
            min(lm_chk$hy_rate - lm_chk$cl_rate)))

# MFJ upper-band reach (the swing-suburban bloc): MFJ eligibles above $71,000
mfj_hi <- elig %>% filter(filing_group_chr == "mfj", magi_num > 71000)
cat(sprintf("\nMFJ eligibles with joint MAGI above current-law $71,000 cutoff (M): %.2f\n",
            sum(mfj_hi$WPFINWGT) / 1e6))
mfj_all <- elig %>% filter(filing_group_chr == "mfj")
cat(sprintf("All MFJ eligibles (M): %.2f; share of eligibles: %.1f%%\n",
            sum(mfj_all$WPFINWGT) / 1e6,
            100 * sum(mfj_all$WPFINWGT) / sum(elig$WPFINWGT)))
