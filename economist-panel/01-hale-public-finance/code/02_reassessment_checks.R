# Re-review spot checks — Hale (public finance)
# Recomputes the first-round inframarginal / marginal-expansion decomposition
# on the CURRENT (IRS-anchored) base: 44.47M eligible, $23.87B ceiling.
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/01-hale-public-finance/code/02_reassessment_checks.R

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
})

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

bn <- function(x) round(x / 1e9, 2)
mm <- function(x) round(x / 1e6, 2)

# --- 1. Verify the canonical base -------------------------------------------
elig <- sim %>% filter(eligible_flag)
cat("Universe (M):", mm(sum(sim$WPFINWGT)), "\n")
cat("Eligible (M):", mm(sum(elig$WPFINWGT)), "\n")
ceiling_cost <- sum(elig$WPFINWGT * elig$match_per_worker_num)
cat("Full-participation ceiling ($B):", bn(ceiling_cost), "\n")
cat("Avg match per eligible ($):", round(ceiling_cost / sum(elig$WPFINWGT)), "\n")

# --- 2. Inframarginal slices (current design) --------------------------------
part <- elig %>% filter(participating_dc_flag)
acct_only <- elig %>% filter(has_existing_dc_flag & !participating_dc_flag)
cat("\nAlready participating in DC (M):", mm(sum(part$WPFINWGT)),
    "| share of eligible:", round(100 * sum(part$WPFINWGT) / sum(elig$WPFINWGT), 1), "%\n")
cat("Ceiling $ to already-participating ($B):", bn(sum(part$WPFINWGT * part$match_per_worker_num)),
    "| share:", round(100 * sum(part$WPFINWGT * part$match_per_worker_num) / ceiling_cost, 1), "%\n")
cat("DC account but not contributing (M):", mm(sum(acct_only$WPFINWGT)), "\n")
cat("Ceiling $ to account-holders-not-contributing ($B):",
    bn(sum(acct_only$WPFINWGT * acct_only$match_per_worker_num)), "\n")
cat("Mean MAGI, already-participating eligibles ($):",
    round(weighted.mean(part$magi_num, part$WPFINWGT)), "\n")
cat("Mean MAGI, eligibles w/ no DC account ($):",
    round(weighted.mean(elig$magi_num[!elig$has_existing_dc_flag],
                        elig$WPFINWGT[!elig$has_existing_dc_flag])), "\n")

# --- 3. Marginal-expansion decomposition vs current law ----------------------
# Current-law (TY2027) phaseout endpoints: Single/MFS $35,500; HoH $53,250; MFJ $71,000.
cl_upper <- c(single_mfs = 35500, hoh = 53250, mfj = 71000)
sim <- sim %>% mutate(cl_eligible = magi_num < cl_upper[filing_group_chr])
cat("\nCurrent-law eligible in universe (M):", mm(sum(sim$WPFINWGT[sim$cl_eligible])),
    " (canonical contrast: 33.08M)\n")

hyb_to_cl <- sim %>% filter(eligible_flag & cl_eligible)
hyb_to_new <- sim %>% filter(eligible_flag & !cl_eligible)
cl_baseline <- 9.19e9  # universal_m100 full-participation, canonical table

dollars_cl  <- sum(hyb_to_cl$WPFINWGT * hyb_to_cl$match_per_worker_num)
dollars_new <- sum(hyb_to_new$WPFINWGT * hyb_to_new$match_per_worker_num)
increment   <- ceiling_cost - cl_baseline

cat("Hybrid ceiling $ to current-law-eligible workers ($B):", bn(dollars_cl), "\n")
cat("  of which rate increase over the $9.19B baseline ($B):", bn(dollars_cl - cl_baseline), "\n")
cat("Hybrid ceiling $ to newly eligible (frontier) workers ($B):", bn(dollars_new), "\n")
cat("Newly eligible workers (M):", mm(sum(hyb_to_new$WPFINWGT)), "\n")
cat("Total increment over current law ($B):", bn(increment), "\n")
cat("Rate-increase share of increment (%):",
    round(100 * (dollars_cl - cl_baseline) / increment, 1), "\n")
cat("Frontier share of increment (%):", round(100 * dollars_new / increment, 1), "\n")
cat("Cost per newly eligible worker ($):",
    round(increment / sum(hyb_to_new$WPFINWGT)), "\n")

# Frontier inframarginality
new_part <- hyb_to_new %>% filter(participating_dc_flag)
cat("Newly eligible already in a DC plan (M):", mm(sum(new_part$WPFINWGT)),
    "| their ceiling $ ($B):", bn(sum(new_part$WPFINWGT * new_part$match_per_worker_num)), "\n")

# --- 4. Phaseout slope on the new pivots -------------------------------------
# 150pp from floor 200 to 50 at pivot; same slope to zero at 4/3 pivot.
slope_pp_per_1k <- 150 / 32235 * 1000
cat("\nSingle phaseout slope (pp of match rate per $1,000 MAGI):", round(slope_pp_per_1k, 2), "\n")
