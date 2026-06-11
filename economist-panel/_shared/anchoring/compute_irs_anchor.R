# D1 re-anchoring: compute the IRS-anchored Single median AGI/MAGI and the resulting
# match schedule, and compare to the current SIPP-median-derived schedule.
#
# Decisions (DESIGN-DECISIONS.md D1, 2026-06-11):
#   - Anchor = IRS Single median MAGI (year before implementation); SOI AGI adjusted to MAGI.
#   - pivot = 0.6 * Single median; endpoint = 0.8 * Single median (75% at one-half median).
#   - HoH = 1.5 x Single pivot; MFJ = 2.0 x Single pivot (statutory ratios; marriage-neutral).
#   - $1,000 cap C-CPI-U indexed (not exercised here; level comparison only).
# Data vintage: latest available SOI by marital status = TY2023 (23in12ms.xls). At actual
# enactment, re-anchor to the then-current prior-year SOI; here TY2023 stands in.

suppressMessages({library(readxl); library(arrow); library(dplyr)})
options(scipen = 999)

f <- "data/raw/irs_soi/23in12ms.xls"
d <- suppressMessages(read_excel(f, sheet = 1, col_names = FALSE))

# AGI-size bins live in rows 10-28 (row 10 = no/negative AGI; 11-28 = positive bins).
# Marital-status column groups: each group's first column = Number of returns.
#   All returns col 2 | MFJ col 14 | MFS col 26 | HoH col 38 | Single col 50
rows <- 10:28
# lower/upper edges for each row (row 10 = deficit/zero, treated as (-Inf, 0])
lower <- c(-Inf, 1, 5e3, 10e3, 15e3, 20e3, 25e3, 30e3, 40e3, 50e3, 75e3, 100e3,
           200e3, 500e3, 1e6, 1.5e6, 2e6, 5e6, 10e6)
upper <- c(0, 5e3, 10e3, 15e3, 20e3, 25e3, 30e3, 40e3, 50e3, 75e3, 100e3, 200e3,
           500e3, 1e6, 1.5e6, 2e6, 5e6, 10e6, Inf)

num <- function(col) as.numeric(d[[col]][rows])
single  <- num(50)
mfs     <- num(26)
single_mfs <- single + mfs

# Weighted median by linear interpolation within the containing bin.
wmedian_bin <- function(counts, lo, hi) {
  # drop the deficit bin's negative lower for interpolation: treat its range as (0,0]->width 0
  total <- sum(counts, na.rm = TRUE)
  target <- total / 2
  cum <- cumsum(counts)
  k <- which(cum >= target)[1]
  lo_k <- if (is.infinite(lo[k])) 0 else lo[k]
  hi_k <- if (is.infinite(hi[k])) lo_k * 2 else hi[k]
  below <- if (k == 1) 0 else cum[k - 1]
  lo_k + (target - below) / counts[k] * (hi_k - lo_k)
}

med_single     <- wmedian_bin(single,     lower, upper)
med_single_mfs <- wmedian_bin(single_mfs, lower, upper)

cat("=== IRS SOI Table 1.2, TY2023 (nominal) ===\n")
cat(sprintf("Single returns total:        %s\n", format(round(sum(single)), big.mark=",")))
cat(sprintf("Single+MFS returns total:    %s\n", format(round(sum(single_mfs)), big.mark=",")))
cat(sprintf("Median AGI, Single only:     $%s\n", format(round(med_single), big.mark=",")))
cat(sprintf("Median AGI, Single + MFS:    $%s\n", format(round(med_single_mfs), big.mark=",")))
cat("(AGI->MAGI add-backs s911/931/933 are ~0 at the median; MAGI median ~= AGI median.)\n\n")

# Schedule geometry from a given Single-median anchor.
schedule <- function(M, label) {
  sp <- 0.6 * M; se <- 0.8 * M
  cat(sprintf("--- %s (Single median = $%s) ---\n", label, format(round(M), big.mark=",")))
  cat(sprintf("  Single pivot   $%s | endpoint $%s\n", format(round(sp), big.mark=","), format(round(se), big.mark=",")))
  cat(sprintf("  HoH    pivot   $%s | endpoint $%s\n", format(round(1.5*sp), big.mark=","), format(round(1.5*se), big.mark=",")))
  cat(sprintf("  MFJ    pivot   $%s | endpoint $%s\n", format(round(2.0*sp), big.mark=","), format(round(2.0*se), big.mark=",")))
  invisible(data.frame(label, single_median=M, single_pivot=sp, single_endpoint=se))
}

cat("=== Resulting match schedule (TY2023 nominal anchor) ===\n")
s1 <- schedule(med_single,     "IRS anchor: Single only")
s2 <- schedule(med_single_mfs, "IRS anchor: Single + MFS")

# Current model anchor (SIPP-derived, TY2027 dollars) for contrast.
piv <- read_parquet("data/processed/universal_sm_hybrid/pivot_table.parquet")
sipp_med <- piv$data_median_magi_num[piv$filing_group_chr == "single_mfs"]
cat("\n=== Current model anchor for contrast ===\n")
s3 <- schedule(sipp_med, "Current SIPP single_mfs median (TY2027$)")

# Project the IRS TY2023 anchor to TY2027 for a like-basis comparison.
# Repo uses 1.093 for SIPP-2024 -> TY2027 (~3%/yr over 3 yrs). 2023->2027 ~ 4 yrs.
g <- 1.093^(4/3)   # approx 4 years at the same annualized rate implied by 1.093 over 3 yrs
cat(sprintf("\n=== IRS Single+MFS anchor projected TY2023->TY2027 (x%.3f) ===\n", g))
s4 <- schedule(med_single_mfs * g, "IRS Single+MFS, projected to TY2027$")

out <- bind_rows(s1, s2, s3, s4)
dir.create("economist-panel/_shared/anchoring/out", showWarnings = FALSE, recursive = TRUE)
write.csv(out, "economist-panel/_shared/anchoring/out/anchor_comparison.csv", row.names = FALSE)
cat("\nWrote economist-panel/_shared/anchoring/out/anchor_comparison.csv\n")
