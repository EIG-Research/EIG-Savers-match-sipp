# weighted_stats.R -- shared weighted-quantile helper.
#
# Ported from the Household-income-and-composition repo
# (`code/utils_weighted_stats.R`) so that the ASEC anchor computed here is
# numerically comparable to the INCWAGE series produced there. Do not duplicate
# this function inside individual stage scripts.
#
# WHY A SECOND ESTIMATOR EXISTS IN THIS REPO. `04_02_compute_pivots.R` uses
# Hmisc::wtd.quantile() for its SIPP diagnostics. Hmisc and the estimator below
# do not agree exactly: Hmisc's default is a weighted empirical CDF, while this
# one places each observation at the midpoint of its own weight interval and
# interpolates between those plotting positions. On large samples the two agree
# closely, but on a heaped distribution (wage income piles on round numbers) they
# can differ by a few hundred dollars. Because the anchor propagates directly
# into the eligibility frontier, `01d_asec_income_medians.R` computes BOTH and
# reports the gap rather than letting the choice of estimator silently move the
# policy threshold.

# Deterministic weighted quantile. Observations are sorted by value, and each
# observation is placed at the midpoint of its own weight interval on the
# cumulative weight scale. Values between those points are linearly
# interpolated. No random tie-breaking is involved.
weighted_quantile <- function(x, w, probs) {
  keep_lgl <- !is.na(x) & !is.na(w) & w > 0

  if (!any(keep_lgl)) {
    return(rep(NA_real_, length(probs)))
  }

  x <- x[keep_lgl]
  w <- w[keep_lgl]

  order_int <- order(x)
  x <- x[order_int]
  w <- w[order_int]

  cumulative_weight_num <- cumsum(w)
  total_weight_num <- cumulative_weight_num[length(cumulative_weight_num)]
  plotting_position_num <- (cumulative_weight_num - 0.5 * w) / total_weight_num

  vapply(
    probs,
    function(p) {
      if (p <= plotting_position_num[1]) {
        return(x[1])
      }

      if (p >= plotting_position_num[length(plotting_position_num)]) {
        return(x[length(x)])
      }

      stats::approx(
        x = plotting_position_num,
        y = x,
        xout = p,
        ties = "ordered"
      )$y
    },
    FUN.VALUE = numeric(1)
  )
}
