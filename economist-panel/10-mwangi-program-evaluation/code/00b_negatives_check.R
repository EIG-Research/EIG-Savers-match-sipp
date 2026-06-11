# Check negative match artifacts (negative incomes/earnings) in the universe
suppressPackageStartupMessages({library(arrow); library(dplyr)})
sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet") %>% filter(in_universe)

cat("sim: rows with match_per_worker_num < 0:", sum(sim$match_per_worker_num < 0),
    " weighted (M):", sum(sim$WPFINWGT[sim$match_per_worker_num < 0])/1e6,
    " dollars (B):", sum((sim$WPFINWGT*sim$match_per_worker_num)[sim$match_per_worker_num < 0])/1e9, "\n")
cat("sim raw total (B):", sum(sim$WPFINWGT*sim$match_per_worker_num)/1e9, "\n")
cat("mod: rows with univ_sm_match_m100 < 0:", sum(mod$univ_sm_match_m100 < 0, na.rm=TRUE),
    " dollars (B):", sum((mod$weight*mod$univ_sm_match_m100)[mod$univ_sm_match_m100 < 0], na.rm=TRUE)/1e9, "\n")
cat("mod raw total in-universe (B):", sum(mod$weight*mod$univ_sm_match_m100, na.rm=TRUE)/1e9, "\n")
cat("mod NAs in universe:", sum(is.na(mod$univ_sm_match_m100)), "\n")
cat("mod magi<0 rows:", sum(mod$sm_income_2027 < 0, na.rm=TRUE), "\n")
cat("sim magi<0 rows:", sum(sim$magi_num < 0), " weighted (M):", sum(sim$WPFINWGT[sim$magi_num < 0])/1e6, "\n")
