# Exploratory v3: find the repo headline's exact row-level vs uniform grouping
suppressPackageStartupMessages({library(arrow); library(dplyr)})
sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
elig <- sim %>% filter(eligible_flag)

try_group <- function(flag, name) {
  g <- elig %>% mutate(grp = flag)
  a <- g %>% filter(grp %in% TRUE)
  b <- g %>% filter(!(grp %in% TRUE))
  pa <- a %>% mutate(p = ifelse(is.na(participating_dc_flag), FALSE, participating_dc_flag))
  cat(sprintf("%-40s A: %6.2fM elig, %6.2fM part, $%6.3fB | B: %6.2fM elig, $%6.3fB at .5979 | total $%6.3fB\n",
      name, sum(a$WPFINWGT)/1e6, sum(pa$WPFINWGT*pa$p)/1e6,
      sum(pa$WPFINWGT*pa$match_per_worker_num*pa$p)/1e9,
      sum(b$WPFINWGT)/1e6, 0.5979*sum(b$WPFINWGT*b$match_per_worker_num)/1e9,
      (sum(pa$WPFINWGT*pa$match_per_worker_num*pa$p) + 0.5979*sum(b$WPFINWGT*b$match_per_worker_num))/1e9))
}
try_group(elig$has_existing_dc_flag, "has_existing_dc_flag")
try_group(!is.na(elig$participating_dc_flag), "participating non-NA")
try_group(elig$has_existing_dc_flag %in% TRUE | elig$participating_dc_flag %in% TRUE, "has_dc OR participating")
try_group(elig$route_chr=="employer_plan" & elig$has_existing_dc_flag %in% TRUE, "employer & has_dc")
cat("\nhas_existing_dc_flag table:\n"); print(table(elig$has_existing_dc_flag, useNA="always"))
cat("weighted has_dc (M):", sum(elig$WPFINWGT[elig$has_existing_dc_flag %in% TRUE])/1e6, "\n")
cat("cross route x has_dc (weighted M):\n")
print(elig %>% group_by(route_chr, has_dc = has_existing_dc_flag) %>%
        summarise(M = sum(WPFINWGT)/1e6, .groups="drop"))
