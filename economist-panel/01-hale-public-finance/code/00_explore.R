# 00_explore.R — quick structure check (Hale panel folder)
suppressMessages({library(arrow); library(dplyr)})

d <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
cat("--- simulation_results columns ---\n")
print(sapply(d, class))
cat("\nparticipating_dc_flag:\n"); print(table(d$participating_dc_flag, useNA = "ifany"))
cat("\nhas_existing_dc_flag:\n"); print(table(d$has_existing_dc_flag, useNA = "ifany"))
cat("\neligible_flag:\n"); print(table(d$eligible_flag, useNA = "ifany"))
cat("\nroute_chr:\n"); print(table(d$route_chr, useNA = "ifany"))

s <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
cat("\n--- scenario_results ---\n"); print(as.data.frame(s))

m <- read_parquet("data/processed/sipp_modeled.parquet")
cat("\n--- sipp_modeled columns ---\n")
print(names(m))
cat("\nin_universe:\n"); print(table(m$in_universe, useNA = "ifany"))
cat("\nis_anymatch_m100:\n"); print(table(m$is_anymatch_m100, useNA = "ifany"))

suppressMessages(library(readxl))
x <- read_excel("output/tables/main/sm_jct_replication_scenarios.xlsx")
cat("\n--- sm_jct_replication_scenarios ---\n"); print(as.data.frame(x))
