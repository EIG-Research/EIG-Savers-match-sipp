# 00_explore.R — quick inspection of the simulation frame (Lindqvist panel work)
# Run from repo root: & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/03-lindqvist-behavioral/code/00_explore.R
suppressPackageStartupMessages({
  library(arrow); library(dplyr)
})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
cat("rows:", nrow(sim), "\n")
print(names(sim))
print(head(as.data.frame(sim), 3))
cat("\nroute_chr values:\n"); print(table(sim$route_chr, useNA = "ifany"))
cat("\neligible_flag:\n"); print(table(sim$eligible_flag, useNA = "ifany"))
cat("\nparticipating_dc_flag among eligible by route:\n")
sim %>% filter(eligible_flag) %>% count(route_chr, participating_dc_flag, wt = WPFINWGT) %>% print()

# headline reproduction check
elig <- sim %>% filter(eligible_flag)
full_cost <- sum(elig$WPFINWGT * elig$match_per_worker_num) / 1e9
cat("\nFull participation cost ($B):", full_cost, "\n")

# headline: universal route participates at SIPP-observed conditional rate; employer route inherits observed flag
p_cond <- elig %>% summarise(p = weighted.mean(participating_dc_flag[has_existing_dc_flag], WPFINWGT[has_existing_dc_flag]))
cat("conditional participation among has_existing_dc (eligible):", p_cond$p, "\n")
p_cond_all <- sim %>% filter(has_existing_dc_flag) %>% summarise(p = weighted.mean(participating_dc_flag, WPFINWGT))
cat("conditional participation among has_existing_dc (universe):", p_cond_all$p, "\n")

scen <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
print(as.data.frame(scen))
