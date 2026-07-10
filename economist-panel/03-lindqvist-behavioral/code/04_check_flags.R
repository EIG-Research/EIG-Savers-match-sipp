# quick diagnostic of flag NAs on the auto-enrolled margin
suppressPackageStartupMessages({ library(arrow); library(dplyr) })
sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
el  <- sim %>% filter(eligible_flag)
margin <- el %>% filter(is.na(participating_dc_flag))

cat("self_employed_flag on margin:\n")
margin %>% group_by(self_employed_flag) %>%
  summarise(nM = sum(WPFINWGT)/1e6, costB = sum(WPFINWGT*match_per_worker_num)/1e9) %>%
  as.data.frame() %>% print()

cat("\nroute_chr x self_employed_flag on margin:\n")
margin %>% group_by(route_chr, self_employed_flag) %>%
  summarise(nM = sum(WPFINWGT)/1e6, costB = sum(WPFINWGT*match_per_worker_num)/1e9,
            .groups = "drop") %>% as.data.frame() %>% print()

cat("\nself_employed_flag on all eligible:\n")
el %>% group_by(self_employed_flag) %>%
  summarise(nM = sum(WPFINWGT)/1e6) %>% as.data.frame() %>% print()

cat("\nprivate_sector_employee_flag x self_employed_flag (eligible):\n")
el %>% group_by(private_sector_employee_flag, self_employed_flag) %>%
  summarise(nM = sum(WPFINWGT)/1e6, .groups="drop") %>% as.data.frame() %>% print()
