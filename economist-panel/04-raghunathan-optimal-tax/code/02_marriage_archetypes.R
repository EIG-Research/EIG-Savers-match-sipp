# ----------------------------------------------------------------------------
# 02_marriage_archetypes.R -- Marriage treatment of the hybrid Saver's Match
# Panelist: Raghunathan (optimal tax). Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/04-raghunathan-optimal-tax/code/02_marriage_archetypes.R
#
# Constructs archetype couples under the rules: the match RATE is set by joint
# MAGI on the MFJ schedule; the contribution base is 3 percent of PERSONAL
# earnings; the $1,000 cap applies per individual. Compares each married couple
# with the same two people cohabiting and filing single. Also computes the
# current-law section 6433 analog (50% flat rate, linear phaseout, $2,000
# qualified-contribution cap, per-individual $1,000 credit cap).
# Assumes MAGI = own earnings for singles; joint MAGI = sum of earnings.
# ----------------------------------------------------------------------------

suppressMessages({
  library(arrow)
  library(dplyr)
})

out_dir_tab <- "economist-panel/04-raghunathan-optimal-tax/tables"

pivot_tbl <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
pivots <- setNames(pivot_tbl$pivot_num, pivot_tbl$filing_group_chr)

contrib_rate <- 0.03

hybrid_rate <- function(magi, group) {
  p <- pivots[[group]]
  pmin(200, pmax(0, 200 - (150 / p) * magi)) / 100
}

hybrid_match_person <- function(earn, magi, group) {
  pmin(1000, hybrid_rate(magi, group) * contrib_rate * earn)
}

# Current-law section 6433 (TY2027): linear 50% -> 0 over the band, qualified
# contribution capped at $2,000, credit capped at $1,000 per person.
cl_bands <- list(single_mfs = c(20500, 35500), mfj = c(41000, 71000))
cl_rate <- function(magi, group) {
  b <- cl_bands[[group]]
  pmax(0, pmin(0.50, 0.50 * (b[2] - magi) / (b[2] - b[1])))
}
cl_match_person <- function(earn, magi, group) {
  pmin(1000, cl_rate(magi, group) * pmin(2000, contrib_rate * earn))
}

archetypes <- tibble::tribble(
  ~label,                                  ~e1,    ~e2,
  "Equal earners, $20k + $20k",            20000,  20000,
  "Equal earners, $35k + $35k",            35000,  35000,
  "Unequal earners, $30k + $10k",          30000,  10000,
  "Unequal earners, $34k + $10k",          34000,  10000,
  "Single earner, $40k + $0",              40000,      0,
  "Single earner, $60k + $0",              60000,      0
)

marriage_tbl <- archetypes %>%
  rowwise() %>%
  mutate(
    joint_magi = e1 + e2,
    # Hybrid: married (MFJ rate off joint MAGI, per-person cap)
    hyb_married_rate_pct = 100 * hybrid_rate(joint_magi, "mfj"),
    hyb_married = hybrid_match_person(e1, joint_magi, "mfj") +
                  hybrid_match_person(e2, joint_magi, "mfj"),
    # Hybrid: two cohabiting single filers (own MAGI)
    hyb_singles = hybrid_match_person(e1, e1, "single_mfs") +
                  hybrid_match_person(e2, e2, "single_mfs"),
    hyb_marriage_delta = hyb_married - hyb_singles,
    # Current law section 6433
    cl_married = cl_match_person(e1, joint_magi, "mfj") +
                 cl_match_person(e2, joint_magi, "mfj"),
    cl_singles = cl_match_person(e1, e1, "single_mfs") +
                 cl_match_person(e2, e2, "single_mfs"),
    cl_marriage_delta = cl_married - cl_singles
  ) %>%
  ungroup() %>%
  mutate(across(where(is.numeric), ~ round(.x, 0)))

write.csv(marriage_tbl, file.path(out_dir_tab, "marriage_archetypes.csv"),
          row.names = FALSE)
cat("--- Marriage archetypes (annual federal match dollars, 3% default contributions) ---\n")
print(as.data.frame(marriage_tbl), width = 200)

# Analytical note check: MFJ slope is exactly half the Single slope, so
# rate_mfj(2x) = rate_single(x); equal-earner couples are exactly neutral
# whenever no cap binds on either side.
stopifnot(abs(hybrid_rate(40000, "mfj") - hybrid_rate(20000, "single_mfs")) < 1e-9)
cat("\nCheck passed: rate_mfj(2x) == rate_single(x) (pivot ratio is exactly 2.0).\n")
