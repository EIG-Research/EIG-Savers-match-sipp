# =============================================================================
# 03_reassessment_recompute.R  (Panelist 10 — Mwangi, re-review)
#
# Re-review recomputation on the CURRENT (IRS-anchored) base:
#   1. Verify the current headline (44.47M eligible; 26.23M participants /
#      $14.15B) and derive the conditional participation rate actually used.
#   2. Recompute the first-round cost-per-marginal-new-saver table
#      (scenarios i-a, i-b, ii, iii) on the new base. First-round figures
#      ($294 / $831 per marginal saver; 17.98M new savers) were on the old
#      46.07M base and are superseded by this output.
#   3. RD / RKD design inputs for the S2 evaluation sketch: weighted worker
#      counts within bandwidths of each filing group's endpoint (RD) and
#      pivot kink (RKD).
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/10-mwangi-program-evaluation/code/03_reassessment_recompute.R
# =============================================================================
suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr)
})

tab_dir <- "economist-panel/10-mwangi-program-evaluation/tables"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet") %>% filter(in_universe)
scn <- read_parquet("data/processed/universal_sm_hybrid/scenario_results.parquet")
piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")

cat("--- scenario_results.parquet (current production run) ---\n")
print(as.data.frame(scn))
cat("\n--- pivot_table.parquet ---\n")
print(as.data.frame(piv))

df <- sim %>%
  inner_join(mod %>% select(ssuid, pnum, univ_sm_match_m100),
             by = c("SSUID" = "ssuid", "PNUM" = "pnum")) %>%
  filter(eligible_flag) %>%
  mutate(participating_dc_flag = participating_dc_flag %in% TRUE)

W_elig <- sum(df$WPFINWGT)
cat("\nHybrid-eligible (M):", round(W_elig/1e6, 2), "\n")

# Repo headline mechanics (04_03_simulate_match.R): workers WITHOUT an
# existing DC account get the uniform conditional rate; DC holders keep
# row-level observed participation.
no_dc  <- !df$has_existing_dc_flag
W_nodc <- sum(df$WPFINWGT[no_dc])
E_dc   <- sum(df$WPFINWGT[!no_dc & df$participating_dc_flag])

hyb_nodc_all <- sum((df$WPFINWGT * df$match_per_worker_num)[no_dc])
hyb_dc_part  <- sum((df$WPFINWGT * df$match_per_worker_num)[!no_dc & df$participating_dc_flag])
cl_nodc_all  <- sum((df$WPFINWGT * df$univ_sm_match_m100)[no_dc])
cl_dc_part   <- sum((df$WPFINWGT * df$univ_sm_match_m100)[!no_dc & df$participating_dc_flag])

# Derive the conditional rate from the production headline row so the
# replication is exact rather than hard-coded.
head_row <- scn %>% filter(scenario_name_chr == "headline_sipp_observed_conditional")
participants_target <- as.numeric(head_row$participant_count_M_num) * 1e6
P_COND <- (participants_target - E_dc) / W_nodc
cat("Derived conditional participation rate on the universal branch:",
    round(P_COND, 4), "\n")

participants_default <- P_COND * W_nodc + E_dc
cost_iii <- P_COND * hyb_nodc_all + hyb_dc_part
cost_ii  <- P_COND * cl_nodc_all  + cl_dc_part
new_savers_default <- P_COND * W_nodc

cat("Replication check — participants (M):", round(participants_default/1e6, 2),
    "| headline cost ($B):", round(cost_iii/1e9, 2), "(target: 14.15)\n")
cat("New savers under default mechanics (M):", round(new_savers_default/1e6, 2), "\n")
cat("Annual premium of (iii) over (ii), $B:", round((cost_iii - cost_ii)/1e9, 2), "\n")

# --- Opt-in scenarios (Duflo et al. 2006 calibration, as in round one) -------
T_CTRL <- 0.03; T_M50 <- 0.14
SLOPE  <- (T_M50 - T_CTRL) / 50
T_M200 <- min(1, T_CTRL + SLOPE * 200)

hyb_exist <- sum((df$WPFINWGT * df$match_per_worker_num)[df$participating_dc_flag])
hyb_nonp  <- sum((df$WPFINWGT * df$match_per_worker_num)[!df$participating_dc_flag])
N0_w      <- sum(df$WPFINWGT[!df$participating_dc_flag])

optin <- function(t) list(
  new   = (t - T_CTRL) * N0_w,
  cost  = hyb_exist + t * hyb_nonp,
  infra = hyb_exist + T_CTRL * hyb_nonp
)
ia <- optin(T_M50); ib <- optin(T_M200)

results <- tibble(
  scenario = c(
    "(i-a) Match-only, opt-in - take-up at largest tested match (50%): 14% gross",
    "(i-b) Match-only, opt-in - linear extrapolation to 200% match: 47% gross",
    "(ii) Default-only - universal account + auto-enrollment, current-law section 6433 match",
    "(iii) Proposal - universal account + auto-enrollment + hybrid match"
  ),
  eligible_M         = round(W_elig/1e6, 2),
  new_savers_M       = round(c(ia$new, ib$new, new_savers_default, new_savers_default)/1e6, 2),
  annual_cost_B      = round(c(ia$cost, ib$cost, cost_ii, cost_iii)/1e9, 2),
  cost_per_new_saver = round(c(ia$cost/ia$new, ib$cost/ib$new,
                               cost_ii/new_savers_default, cost_iii/new_savers_default), 0),
  share_dollars_inframarginal = round(c(
    ia$infra/ia$cost, ib$infra/ib$cost,
    cl_dc_part / cost_ii, hyb_dc_part / cost_iii), 2)
)
write.csv(results, file.path(tab_dir, "cost_per_marginal_new_saver_v2_current_base.csv"),
          row.names = FALSE)
cat("\n--- Cost per marginal new saver, CURRENT base ---\n")
print(as.data.frame(results))

# --- RD / RKD design inputs ---------------------------------------------------
# Weighted universe workers within +/- bandwidths of each filing group's
# endpoint (RD frontier) and pivot (RKD kink). SIPP sizes the population;
# the evaluation itself would run in Treasury/IRS administrative data.
uni <- sim %>%
  inner_join(piv %>% select(filing_group_chr,
                            pivot = pivot_num, endpoint = endpoint_num),
             by = "filing_group_chr")

bw_counts <- function(center_col, bw) {
  uni %>%
    mutate(dist = magi_num - .data[[center_col]]) %>%
    filter(abs(dist) <= bw) %>%
    group_by(filing_group_chr) %>%
    summarise(workers_M = round(sum(WPFINWGT)/1e6, 2),
              unweighted_n = n(), .groups = "drop") %>%
    mutate(center = center_col, bandwidth = bw)
}
rd_tab <- bind_rows(
  bw_counts("endpoint", 2500), bw_counts("endpoint", 5000),
  bw_counts("pivot",    2500), bw_counts("pivot",    5000)
)
write.csv(rd_tab, file.path(tab_dir, "rd_rkd_bandwidth_density.csv"), row.names = FALSE)
cat("\n--- Weighted workers near RD endpoints / RKD pivots ---\n")
print(as.data.frame(rd_tab))

cat("\nDone.\n")
