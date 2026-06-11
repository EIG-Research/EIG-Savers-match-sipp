# Quick exploration (not part of final outputs)
suppressPackageStartupMessages({library(arrow); library(dplyr)})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet")

cat("--- simulation_results columns ---\n")
print(names(sim))
cat("\n--- sipp_modeled columns ---\n")
print(names(mod))

cat("\n--- sim head ---\n")
print(head(as.data.frame(sim), 3))

cat("\n--- modeled: in_universe counts ---\n")
print(mod %>% count(in_universe))

cat("\n--- modeled: access var values ---\n")
print(mod %>% filter(in_universe) %>% count(any_retirement_access))
print(mod %>% filter(in_universe) %>% count(has_dc_account))
print(mod %>% filter(in_universe) %>% count(is_participating_dc))

cat("\n--- modeled: weighted counts among in_universe ---\n")
print(mod %>% filter(in_universe) %>%
        summarise(n = n(),
                  w_m = sum(weight)/1e6,
                  has_dc = sum(weight * (has_dc_account %in% c(TRUE, "Yes", 1)), na.rm=TRUE)/1e6,
                  access = sum(weight * (any_retirement_access %in% c(TRUE, "Yes", 1)), na.rm=TRUE)/1e6,
                  part = sum(weight * (is_participating_dc %in% c(TRUE, "Yes", 1)), na.rm=TRUE)/1e6))

cat("\n--- modeled: univ_sm_match_m100 summary among in_universe ---\n")
print(summary(mod$univ_sm_match_m100[mod$in_universe]))
cat("\n--- sm_match_per_person summary ---\n")
print(summary(mod$sm_match_per_person[mod$in_universe]))

cat("\n--- class of access vars ---\n")
print(str(mod %>% select(any_of(c("has_dc_account","any_retirement_access","is_participating_dc","sm_income_2027","earnings_2027","sm_match_per_person","univ_sm_match_m100","is_anymatch_m100","is_eligible_dc_m100")))))

cat("\n--- scenario results ---\n")
print(as.data.frame(read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")))
