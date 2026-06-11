# Inspect simulation_results.parquet structure (read-only)
library(arrow)
library(dplyr)

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
cat("Rows:", nrow(sim), "\n")
str(as.data.frame(sim[1:3, ]))
cat("\nroute_chr values:\n")
print(sim %>% count(route_chr, wt = WPFINWGT / 1e6))
cat("\neligible_flag by route:\n")
print(sim %>% filter(eligible_flag) %>% count(route_chr, wt = WPFINWGT / 1e6))
cat("\nHeadline replication check:\n")
hl <- sim %>%
  filter(eligible_flag) %>%
  mutate(part = ifelse(route_chr == "employer_plan", as.numeric(participating_dc_flag), 0.598)) %>%
  summarise(
    eligible_m = sum(WPFINWGT) / 1e6,
    participants_m = sum(WPFINWGT * part) / 1e6,
    cost_bn = sum(WPFINWGT * part * match_per_worker_num) / 1e9
  )
print(hl)
cat("\nScenario ladder:\n")
print(as.data.frame(read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")))
cat("\ndefault_contrib_num distribution among eligible:\n")
el <- sim %>% filter(eligible_flag)
print(quantile(el$default_contrib_num, probs = c(.1, .25, .5, .75, .9)))
cat("\nWeighted median default contribution (eligible, universal route):\n")
u <- el %>% filter(route_chr != "employer_plan") %>% arrange(default_contrib_num) %>%
  mutate(cw = cumsum(WPFINWGT) / sum(WPFINWGT))
print(u$default_contrib_num[which(u$cw >= 0.5)[1]])
cat("\nparticipating_dc_flag class:", class(sim$participating_dc_flag), "\n")
print(table(sim$participating_dc_flag))
