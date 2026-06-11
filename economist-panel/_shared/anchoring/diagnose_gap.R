# Decompose the SIPP-vs-IRS single-filer median gap into concept (transfers) vs.
# population/annualization, to determine whether "realign the MAGI proxy" (netting
# transfers) materially closes it, or whether the gap is a population mismatch
# (SIPP worker universe vs. IRS all-single-filers).
suppressMessages({library(arrow); library(dplyr)})
options(scipen = 999)

fr <- read_parquet("data/processed/sipp_modeled.parquet")

w <- function(x, wt) {
  o <- order(x); x <- x[o]; wt <- wt[o]
  cw <- cumsum(wt) / sum(wt)
  x[which(cw >= 0.5)[1]]
}

# Single/MFS workers in the universe.
u <- fr |> filter(in_universe, filing_group == "single_mfs",
                  !is.na(sm_income_2027), !is.na(weight))

cat("=== Single/MFS workers in the simulation universe ===\n")
cat(sprintf("weighted N: %.2fM\n", sum(u$weight)/1e6))
cat(sprintf("median MAGI proxy (sm_income_2027, TY2027$):  $%s\n", format(round(w(u$sm_income_2027, u$weight)), big.mark=",")))
cat(sprintf("median personal income (TY2027$):             $%s\n", format(round(w(u$personal_income_2027, u$weight)), big.mark=",")))
cat(sprintf("median earnings (TY2027$):                    $%s\n", format(round(w(u$earnings_2027, u$weight)), big.mark=",")))
cat(sprintf("median MAGI proxy in 2024$ (/1.093):          $%s\n", format(round(w(u$sm_income_2027, u$weight)/1.093), big.mark=",")))

# How much of the MAGI proxy is non-earnings (transfers + asset/other income)?
u <- u |> mutate(nonearn = pmax(personal_income_2027 - earnings_2027, 0),
                 nonearn_share = ifelse(personal_income_2027>0, nonearn/personal_income_2027, NA))
cat(sprintf("\nmean non-earnings share of personal income: %.1f%%\n", 100*weighted.mean(u$nonearn_share, u$weight, na.rm=TRUE)))
cat(sprintf("median non-earnings $ (TY2027$):              $%s\n", format(round(w(u$nonearn, u$weight)), big.mark=",")))
cat("(For a worker universe, non-earnings income is the ceiling on what netting out\n transfers could remove; AGI also EXCLUDES only the non-taxable subset of it.)\n")

# Bracket: even if we removed ALL non-earnings income (an overcorrection, since AGI
# includes taxable interest/dividends/cap gains), the proxy median would fall to the
# earnings median. That earnings median is the LOWER bound of any concept realignment.
cat("\n=== Interpretation bracket for the single_mfs anchor (TY2027$) ===\n")
cat(sprintf("  Upper (current proxy = TPTOTINC):     $%s  -> pivot 0.6x = $%s\n",
            format(round(w(u$sm_income_2027,u$weight)),big.mark=","),
            format(round(0.6*w(u$sm_income_2027,u$weight)),big.mark=",")))
cat(sprintf("  Lower (earnings only, overcorrected): $%s  -> pivot 0.6x = $%s\n",
            format(round(w(u$earnings_2027,u$weight)),big.mark=","),
            format(round(0.6*w(u$earnings_2027,u$weight)),big.mark=",")))
cat(sprintf("  IRS all-single-filer median AGI, projected TY2027: ~$40,294 -> pivot 0.6x = $24,176\n"))
