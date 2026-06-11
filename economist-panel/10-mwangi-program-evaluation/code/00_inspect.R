# Quick inspection of data frames (panelist 10, Mwangi)
suppressPackageStartupMessages({library(arrow); library(dplyr)})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet")

cat("=== simulation_results columns ===\n")
print(names(sim))
cat("nrow:", nrow(sim), "\n\n")

cat("=== sipp_modeled columns ===\n")
print(names(mod))
cat("nrow:", nrow(mod), "\n\n")

cat("=== sipp_modeled key vars summary ===\n")
print(summary(mod %>% select(weight, sm_income_2027, earnings_2027, sm_match_per_person, univ_sm_match_m100)))
cat("\nin_universe table:\n"); print(table(mod$in_universe, useNA="ifany"))
cat("\nhas_dc_account table (in universe):\n"); print(table(mod$has_dc_account[mod$in_universe], useNA="ifany"))
cat("\nany_retirement_access table (in universe):\n"); print(table(mod$any_retirement_access[mod$in_universe], useNA="ifany"))
cat("\nis_participating_dc table (in universe):\n"); print(table(mod$is_participating_dc[mod$in_universe], useNA="ifany"))

cat("\nsim: any_retirement_access_v2_chr table:\n"); print(table(sim$any_retirement_access_v2_chr, useNA="ifany"))
cat("\nsim: has_existing_dc_flag:\n"); print(table(sim$has_existing_dc_flag, useNA="ifany"))
cat("\nsim route_chr:\n"); print(table(sim$route_chr, useNA="ifany"))

# weighted eligible counts checks
cat("\nWeighted universe (sim, M):", sum(sim$WPFINWGT)/1e6, "\n")
cat("Weighted eligible (sim, M):", sum(sim$WPFINWGT[sim$eligible_flag])/1e6, "\n")
cat("Weighted eligible current law m100 (mod, M):", sum(mod$weight[mod$in_universe & mod$is_anymatch_m100], na.rm=TRUE)/1e6, "\n")
cat("Full-part cost current law ($B):", sum(mod$weight*mod$sm_match_per_person, na.rm=TRUE)/1e9, "\n")
cat("Full-part cost univ m100 ($B):", sum(mod$weight*mod$univ_sm_match_m100, na.rm=TRUE)/1e9, "\n")
cat("Full-part cost hybrid ($B):", sum(sim$WPFINWGT*sim$match_per_worker_num)/1e9, "\n")

# scenario results
scen <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
print(as.data.frame(scen))
