# Exploration: column inventory and sanity checks (Calloway panel folder)
suppressPackageStartupMessages({library(arrow); library(dplyr)})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
cat("--- simulation_results columns ---\n"); print(names(sim))
cat("rows:", nrow(sim), "\n")
cat("route_chr values:\n"); print(sim %>% count(route_chr, wt = WPFINWGT/1e6))
cat("eligible weighted (M):", sum(sim$WPFINWGT[sim$eligible_flag])/1e6, "\n")
cat("universe weighted (M):", sum(sim$WPFINWGT)/1e6, "\n")
cat("full-participation cost ($B):", sum(sim$match_per_worker_num[sim$eligible_flag] * sim$WPFINWGT[sim$eligible_flag])/1e9, "\n")
# verify match formula
chk <- sim %>% filter(eligible_flag) %>%
  mutate(recomp = pmin(match_rate_frac_num * default_contrib_num, 1000),
         diff = abs(recomp - match_per_worker_num))
cat("max diff recomputed match vs stored:", max(chk$diff), "\n")

mod <- read_parquet("data/processed/sipp_modeled.parquet")
cat("\n--- sipp_modeled columns ---\n"); print(names(mod))

piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
cat("\n--- pivot_table ---\n"); print(as.data.frame(piv))

scen <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
cat("\n--- scenario_results ---\n"); print(as.data.frame(scen))
