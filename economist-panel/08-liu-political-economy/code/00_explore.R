# Exploration: structure of current-law match factor and join keys (Dr. Grace Liu)
suppressMessages({library(arrow); library(dplyr)})

m <- read_parquet("data/processed/sipp_modeled.parquet")
s <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

cat("--- thresholds by filing group (m100) ---\n")
print(m %>% filter(in_universe) %>% distinct(filing_group, threshold_lower_m100, threshold_upper_m100))

cat("--- sm_factor_m100 behavior for single filers, 15k-40k ---\n")
sing <- m %>% filter(in_universe, filing_group == "single_mfs",
                     sm_income_2027 > 15000, sm_income_2027 < 40000) %>%
  arrange(sm_income_2027) %>%
  select(sm_income_2027, sm_factor_m100, is_anymatch_m100, contrib_for_sm, sm_match_per_person)
print(as.data.frame(sing[unique(round(seq(1, nrow(sing), length.out = 25))), ]))

cat("--- distinct factor values ---\n")
print(m %>% filter(in_universe) %>% count(round(sm_factor_m100, 3)) %>% arrange(desc(n)) %>% head(10))

cat("--- join check ---\n")
j <- inner_join(s, m, by = c("SSUID" = "ssuid", "PNUM" = "pnum"))
cat("sim rows:", nrow(s), " joined:", nrow(j), "\n")
cat("weight equal? ", all.equal(j$WPFINWGT, j$weight), "\n")

cat("--- universe vs in_universe ---\n")
cat("modeled in_universe weighted (M):", sum(m$weight[m$in_universe]) / 1e6, "\n")
cat("sim universe weighted (M):", sum(s$WPFINWGT) / 1e6, "\n")
cat("hybrid eligible weighted (M):", sum(s$WPFINWGT[s$eligible_flag]) / 1e6, "\n")
cat("current-law anymatch weighted (M):", sum(m$weight[m$in_universe & m$is_anymatch_m100]) / 1e6, "\n")

cat("--- contrib_for_sm summary (current-law) ---\n")
print(summary(m$contrib_for_sm[m$in_universe]))
cat("--- route values ---\n")
print(s %>% count(route_chr))
print(s %>% filter(eligible_flag) %>% count(filing_group_chr))
