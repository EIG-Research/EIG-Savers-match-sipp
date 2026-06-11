# Exploration 2: current-law match mechanics (Dr. Grace Liu)
suppressMessages({library(arrow); library(dplyr)})

m <- read_parquet("data/processed/sipp_modeled.parquet")
u <- m %>% filter(in_universe)

cat("univ_contrib_for_sm summary:\n"); print(summary(u$univ_contrib_for_sm))

cat("\nsample of anymatch rows:\n")
x <- u %>% filter(is_anymatch_m100) %>%
  select(sm_income_2027, earnings_2027, filing_group, sm_factor_m100, contrib_for_sm,
         sm_match_per_person, univ_contrib_for_sm, univ_sm_match_m100,
         is_eligible_dc_m100, has_dc_account, contrib_rate_draw)
print(head(as.data.frame(x), 12))

cat("\ncheck: univ match = 0.5*factor*univ_contrib capped 1000?\n")
chk <- with(x, pmin(0.5 * sm_factor_m100 * univ_contrib_for_sm, 1000))
cat("max abs diff:", max(abs(chk - x$univ_sm_match_m100)), "\n")

cat("\ncheck: sm_match = 0.5*factor*contrib capped 1000?\n")
chk2 <- with(x, pmin(0.5 * sm_factor_m100 * contrib_for_sm, 1000))
cat("max abs diff:", max(abs(chk2 - x$sm_match_per_person)), "\n")

cat("\ndistinct contrib_rate_draw:\n"); print(u %>% count(contrib_rate_draw))

cat("\ncontrib_for_sm as share of earnings (anymatch rows):\n")
print(u %>% filter(is_anymatch_m100) %>%
        mutate(r = contrib_for_sm / earnings_2027) %>%
        summarise(min = min(r), med = median(r), max = max(r)))

cat("\nis sm_match_per_person nonzero only when has_dc_account / eligible_dc?\n")
print(u %>% group_by(is_anymatch_m100, is_eligible_dc_m100) %>%
        summarise(n = n(), pos_match = sum(sm_match_per_person > 0),
                  pos_univ = sum(univ_sm_match_m100 > 0), .groups = "drop"))

cat("\nuniv_contrib_for_sm vs earnings ratio:\n")
print(u %>% filter(is_anymatch_m100) %>%
        mutate(r = univ_contrib_for_sm / earnings_2027) %>% count(round(r, 3)) %>% head(10))
