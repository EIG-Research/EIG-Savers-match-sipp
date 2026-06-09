# scenario_engine.R -- the ONE participation/cost scenario runner.
#
# run_scenario() assigns a participation flag to an eligible population and returns
# the weighted eligible count, participant count, take-up rate, average match, and
# annual cost. It is the single definition used by the cost stage (03a/03b); the
# former inline copies (03a, 03b loop, 04_03) are replaced by this.
#
# Participation modes:
#   use_observed   = TRUE  -> use the SIPP-observed participation flag (obs_col)
#   participation_rate >= 1 -> all eligibles participate
#   participation_rate <= 0 -> none
#   otherwise -> weighted-cumulative random selection so the realized weighted
#                take-up equals participation_rate (deterministic given the seed).
#
# Column names are the canonical frame's snake_case: weight = "weight",
# observed-participation flag = "is_participating_dc".

run_scenario <- function(df, scenario_name,
                         eligible_col, match_col,
                         participation_rate = NULL,
                         use_observed = FALSE,
                         scenario_group = "jct_baseline",
                         obs_col = "is_participating_dc",
                         weight_col = "weight",
                         seed = 42L) {

  set.seed(seed)

  eligible_flag <- df[[eligible_col]] %in% TRUE
  match_values  <- df[[match_col]]
  w             <- df[[weight_col]]

  if (use_observed) {
    obs <- df[[obs_col]]
    participant_flag <- eligible_flag & !is.na(obs) & obs == TRUE
  } else if (!is.null(participation_rate) && participation_rate >= 1.0) {
    participant_flag <- eligible_flag
  } else if (!is.null(participation_rate) && participation_rate <= 0.0) {
    participant_flag <- rep(FALSE, nrow(df))
  } else {
    # Weighted-cumulative random selection (realized weighted take-up = rate).
    u <- runif(nrow(df))
    elig_idx <- which(eligible_flag)
    participant_flag <- rep(FALSE, nrow(df))
    if (length(elig_idx) > 0L) {
      ordered_idx <- elig_idx[order(u[elig_idx])]
      cum_wgt     <- cumsum(w[ordered_idx])
      target      <- participation_rate * cum_wgt[length(cum_wgt)]
      cutoff      <- which(cum_wgt >= target)[1]
      if (is.na(cutoff)) cutoff <- length(ordered_idx)
      participant_flag[ordered_idx[seq_len(cutoff)]] <- TRUE
    }
  }

  total_eligible_wgt     <- sum(w[eligible_flag], na.rm = TRUE)
  total_participants_wgt <- sum(w[participant_flag], na.rm = TRUE)
  total_cost             <- sum(match_values[participant_flag] * w[participant_flag], na.rm = TRUE)
  avg_match <- if (total_participants_wgt > 0) total_cost / total_participants_wgt else NA_real_

  data.frame(
    scenario             = scenario_name,
    scenario_group       = scenario_group,
    eligible_count_M     = round(total_eligible_wgt / 1e6, 2),
    participant_count_M  = round(total_participants_wgt / 1e6, 2),
    takeup_rate          = if (total_eligible_wgt > 0) round(total_participants_wgt / total_eligible_wgt, 4) else NA_real_,
    avg_match_per_person = round(avg_match, 0),
    annual_cost_M        = round(total_cost / 1e6, 0),
    stringsAsFactors = FALSE
  )
}
