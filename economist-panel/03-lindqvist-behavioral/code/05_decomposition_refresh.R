# 05_decomposition_refresh.R -- refresh the access-vs-generosity decomposition
# (first-round 02_default_vs_match_decomposition.R) on the current IRS-anchored base.
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/03-lindqvist-behavioral/code/05_decomposition_refresh.R
suppressPackageStartupMessages({ library(arrow); library(dplyr) })

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
el  <- sim %>% filter(eligible_flag) %>%
  mutate(match_flat50 = pmin(0.5 * default_contrib_num, 1000))

obs    <- el %>% filter(!is.na(participating_dc_flag))
margin <- el %>% filter(is.na(participating_dc_flag))
p <- weighted.mean(obs$participating_dc_flag, obs$WPFINWGT)

obs_flat50    <- sum(obs$WPFINWGT * obs$match_flat50 * obs$participating_dc_flag)/1e9
margin_flat50 <- p * sum(margin$WPFINWGT * margin$match_flat50)/1e9
obs_actual    <- sum(obs$WPFINWGT * obs$match_per_worker_num * obs$participating_dc_flag)/1e9
margin_actual <- p * sum(margin$WPFINWGT * margin$match_per_worker_num)/1e9
headline      <- obs_actual + margin_actual
generosity    <- headline - (obs_flat50 + margin_flat50)

cat(sprintf("Headline (p=%.4f): $%.2fB\n", p, headline))
cat(sprintf("Flat-50%% to observed savers (inframarginal): $%.2fB (%.0f%%)\n",
            obs_flat50, 100*obs_flat50/headline))
cat(sprintf("Cost of access (margin at flat 50%%): $%.2fB (%.0f%%)\n",
            margin_flat50, 100*margin_flat50/headline))
cat(sprintf("Cost of generosity (schedule above flat 50%%): $%.2fB (%.0f%%)\n",
            generosity, 100*generosity/headline))
