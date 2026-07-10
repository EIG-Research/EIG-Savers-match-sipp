# ----------------------------------------------------------------------------
# 04_rereview_checks.R -- Re-review spot-checks on the IRS-anchored schedule
# Panelist: Raghunathan (optimal tax). Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/04-raghunathan-optimal-tax/code/04_rereview_checks.R
#
# (1) Verify the new pivots and the exact 2.0x / 1.5x ratios (marriage neutrality).
# (2) Refresh the EMTR-exposure split (cap binds vs. positive adder) on the new
#     pivots, incl. near-endpoint mass. Adder = 150 * contribution / pivot pp,
#     zero where the $1,000 cap binds; 3 percent default contribution.
# (3) Plateau geometry on the earnings = MAGI diagonal: peak unbounded match by
#     filing group and the MFJ cap-binding window.
# (4) Marriage archetypes on the new schedule (verify spec's worked numbers).
# ----------------------------------------------------------------------------

suppressMessages({
  library(arrow)
  library(dplyr)
})

out_dir_tab <- "economist-panel/04-raghunathan-optimal-tax/tables"

# --- (1) Pivot verification ---------------------------------------------------
pivot_tbl <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
cat("--- pivot_table.parquet ---\n")
print(as.data.frame(pivot_tbl))
pivots <- setNames(pivot_tbl$pivot_num, pivot_tbl$filing_group_chr)
cat(sprintf("\nMFJ / Single pivot ratio: %.10f\n", pivots[["mfj"]] / pivots[["single_mfs"]]))
cat(sprintf("HoH / Single pivot ratio: %.10f\n", pivots[["hoh"]] / pivots[["single_mfs"]]))
cat(sprintf("Slope (pp per $1,000): Single %.3f / HoH %.3f / MFJ %.3f\n",
            150000 / pivots[["single_mfs"]], 150000 / pivots[["hoh"]],
            150000 / pivots[["mfj"]]))

# --- (2) EMTR exposure on the new pivots ---------------------------------------
sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
elig_total <- sum(sim$WPFINWGT[sim$eligible_flag], na.rm = TRUE) / 1e6
cat(sprintf("\nEligible workers (weighted): %.2f million (canonical: 44.47M)\n", elig_total))

work <- sim %>%
  filter(eligible_flag) %>%
  mutate(
    pivot_num = case_when(
      filing_group_chr == "single_mfs" ~ pivots[["single_mfs"]],
      filing_group_chr == "mfj"        ~ pivots[["mfj"]],
      filing_group_chr == "hoh"        ~ pivots[["hoh"]]
    ),
    unbounded_match = match_rate_frac_num * default_contrib_num,
    cap_binds = unbounded_match >= 1000,
    emtr_pp = if_else(cap_binds, 0, 150 * default_contrib_num / pivot_num)
  )

split_tbl <- work %>%
  mutate(exposure = if_else(cap_binds, "Cap binds: zero adder", "Positive adder")) %>%
  group_by(exposure) %>%
  summarise(
    workers_m    = sum(WPFINWGT) / 1e6,
    earnings_b   = sum(WPFINWGT * earnings_num) / 1e9,
    mean_emtr_pp = weighted.mean(emtr_pp, WPFINWGT),
    .groups = "drop"
  ) %>%
  mutate(share_of_eligible = workers_m / sum(workers_m))
cat("\n--- Exposure split (new pivots) ---\n")
print(as.data.frame(split_tbl))

by_group <- work %>%
  group_by(filing_group_chr) %>%
  summarise(
    eligible_m        = sum(WPFINWGT) / 1e6,
    capped_m          = sum(WPFINWGT[cap_binds]) / 1e6,
    capped_share      = capped_m / eligible_m,
    mean_emtr_exposed = weighted.mean(emtr_pp[!cap_binds], WPFINWGT[!cap_binds]),
    p90_emtr_exposed  = {
      x <- emtr_pp[!cap_binds]; w <- WPFINWGT[!cap_binds]
      o <- order(x); cw <- cumsum(w[o]) / sum(w[o]); x[o][which(cw >= 0.9)[1]]
    },
    .groups = "drop"
  )
cat("\n--- By filing group ---\n")
print(as.data.frame(by_group))

near_endpoint <- work %>%
  mutate(endpoint = pivot_num * 4 / 3) %>%
  filter(!cap_binds, magi_num >= endpoint - 5000) %>%
  summarise(workers_m = sum(WPFINWGT) / 1e6,
            mean_emtr = weighted.mean(emtr_pp, WPFINWGT))
cat(sprintf("\nExposed within $5,000 of endpoint: %.2f M, mean adder %.2f pp\n",
            near_endpoint$workers_m, near_endpoint$mean_emtr))

write.csv(bind_rows(
  split_tbl %>% mutate(level = "All eligible") %>% rename(group = exposure),
  by_group %>% transmute(level = "By filing group", group = filing_group_chr,
                         workers_m = eligible_m, earnings_b = NA_real_,
                         mean_emtr_pp = mean_emtr_exposed,
                         share_of_eligible = capped_share)
) %>% mutate(across(where(is.numeric), ~ round(.x, 3))),
file.path(out_dir_tab, "rereview_emtr_exposure_new_pivots.csv"), row.names = FALSE)

# --- (3) Plateau geometry on the diagonal --------------------------------------
cat("\n--- Diagonal (earnings = MAGI) peak unbounded match, 3% default ---\n")
for (g in names(pivots)) {
  p <- pivots[[g]]
  # unbounded(m) = 0.03 * m * (2 - 1.5 m / p), maximized at m = 2p/3, peak = 0.02p
  peak <- 0.02 * p
  cat(sprintf("%-10s pivot $%s  peak unbounded match $%.0f %s\n",
              g, format(round(p), big.mark = ","), peak,
              if (peak >= 1000) "(cap binds in a window)" else "(cap never binds)"))
  if (peak >= 1000) {
    # roots of 0.045 m^2 / p - 0.06 m + 1000 = 0
    a <- 0.045 / p; b <- -0.06; cc <- 1000
    r <- sort((-b + c(-1, 1) * sqrt(b^2 - 4 * a * cc)) / (2 * a))
    cat(sprintf("           cap-binding window: $%s to $%s of joint MAGI\n",
                format(round(r[1]), big.mark = ","),
                format(round(r[2]), big.mark = ",")))
  }
}

# --- (4) Marriage archetypes on the new schedule --------------------------------
contrib_rate <- 0.03
hybrid_rate <- function(magi, group) {
  p <- pivots[[group]]
  pmin(200, pmax(0, 200 - (150 / p) * magi)) / 100
}
hybrid_match_person <- function(earn, magi, group) {
  pmin(1000, hybrid_rate(magi, group) * contrib_rate * earn)
}
archetypes <- tibble::tribble(
  ~label,                         ~e1,   ~e2,
  "Equal earners, $20k + $20k",   20000, 20000,
  "Unequal earners, $30k + $10k", 30000, 10000,
  "Single earner, $40k + $0",     40000,     0,
  "Single earner, $60k + $0",     60000,     0
)
marriage_tbl <- archetypes %>%
  rowwise() %>%
  mutate(
    joint_magi  = e1 + e2,
    mfj_rate    = 100 * hybrid_rate(joint_magi, "mfj"),
    married     = hybrid_match_person(e1, joint_magi, "mfj") +
                  hybrid_match_person(e2, joint_magi, "mfj"),
    cohabiting  = hybrid_match_person(e1, e1, "single_mfs") +
                  hybrid_match_person(e2, e2, "single_mfs"),
    delta       = married - cohabiting
  ) %>%
  ungroup() %>%
  mutate(across(where(is.numeric), ~ round(.x, 0)))
cat("\n--- Marriage archetypes (new pivots) ---\n")
print(as.data.frame(marriage_tbl), width = 200)
write.csv(marriage_tbl, file.path(out_dir_tab, "rereview_marriage_archetypes_new_pivots.csv"),
          row.names = FALSE)

stopifnot(abs(hybrid_rate(40000, "mfj") - hybrid_rate(20000, "single_mfs")) < 1e-9)
cat("\nNeutrality check passed: rate_mfj(2x) == rate_single(x) on the new pivots.\n")
