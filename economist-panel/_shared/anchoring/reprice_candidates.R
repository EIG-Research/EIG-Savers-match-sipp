# Re-price the hybrid under candidate IRS-anchored schedules, to resolve the
# half-median vs. full-median 75%-anchor question with actual numbers.
# Sandbox only — does not touch the pipeline.
suppressMessages({library(arrow); library(dplyr)})
options(scipen = 999)

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")

# compute_match_rate logic (replicated from calibration_cells.R): 200% floor at MAGI=0,
# slope -150/pivot, clamped [0,200]. Match per worker = min(rate/100 * contrib, cap).
match_rate <- function(magi, fg, piv) {
  p <- dplyr::case_when(fg=="single_mfs"~piv[["single_mfs"]], fg=="mfj"~piv[["mfj"]],
                        fg=="hoh"~piv[["hoh"]], TRUE~NA_real_)
  pmin(200, pmax(0, dplyr::if_else(is.na(magi)|is.na(p), NA_real_, 200 - (150/p)*magi)))
}

price <- function(label, single_pivot, cap = 1000) {
  piv <- c(single_mfs = single_pivot, mfj = 2.0*single_pivot, hoh = 1.5*single_pivot)
  r <- match_rate(sim$magi_num, sim$filing_group_chr, piv)
  mpw <- pmin((r/100) * sim$default_contrib_num, cap)
  elig <- !is.na(r) & r > 0
  data.frame(
    schedule = label,
    single_pivot = round(single_pivot),
    single_endpoint = round((4/3)*single_pivot),
    eligible_M = round(sum(sim$WPFINWGT[elig], na.rm=TRUE)/1e6, 2),
    full_particip_cost_B = round(sum((mpw*sim$WPFINWGT)[elig], na.rm=TRUE)/1e9, 2),
    avg_match = round(sum((mpw*sim$WPFINWGT)[elig],na.rm=TRUE)/sum(sim$WPFINWGT[elig],na.rm=TRUE))
  )
}

# Medians (TY2027$): IRS all-single-filer projected ~$40,294; current SIPP worker $54,799.
M_irs  <- 40294
M_sipp <- 54799

res <- bind_rows(
  price("CURRENT (SIPP worker median, 0.5x anchor): single pivot 0.6*54799", 0.6*M_sipp),
  price("IRS all-filer median, HALF-median anchor (0.6x M): endpoint just below s6433", 0.6*M_irs),
  price("IRS all-filer median, FULL-median anchor (1.2x M): what was requested",        1.2*M_irs),
  price("IRS all-filer median, 2/3-median anchor (0.8x M): CHOSEN [pivot 0.8*M]",        0.8*M_irs)
)
print(res, row.names = FALSE)
cat("\nEnacted s6433 single endpoint for reference: $35,500\n")
cat("Current model headline check (full-participation ceiling should be ~46.07M / ~$24.9B).\n")

dir.create("economist-panel/_shared/anchoring/out", showWarnings = FALSE, recursive = TRUE)
write.csv(res, "economist-panel/_shared/anchoring/out/reprice_candidates.csv", row.names = FALSE)
