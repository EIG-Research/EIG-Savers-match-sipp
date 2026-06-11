# =============================================================================
# 02_effect_size_benchmark.R  (Panelist 10 — Mwangi, program evaluation)
#
# Charge 2: Effect-size benchmarking against the experimental literature.
#
# Calibration anchors (verified against the downloaded papers, sources/):
#   * Duflo, Gale, Liebman, Orszag & Saez (2006, NBER w11680), H&R Block RCT:
#       IRA take-up: control 3%, 20% match 8%, 50% match 14%.
#       Implied linear slope 0-50pp: (14-3)/50 = 0.22 pp take-up per pp match.
#   * Madrian & Shea (2001, NBER w7682): auto-enrollment raised new-hire
#       401(k) participation ~37% -> ~86% (≈ +50 pp).
#   * Chetty et al. (2014, NBER w18565): 85% passive savers; $1 of subsidy
#       expenditure raises total saving by ~1 cent.
#   * Repo headline: SIPP-observed conditional DC participation = 59.8%.
#
# Scenarios (population: the 46.07M hybrid-eligible workers):
#   (i-a) Match-only, opt-in, take-up at the LARGEST experimentally tested
#         match (50%): gross take-up 14% of current non-savers (3% control).
#   (i-b) Match-only, opt-in, linear extrapolation of the Duflo dose-response
#         to a 200% match: 3 + 0.22*200 = 47% gross take-up. (Far outside
#         experimental support — upper bound, flagged as such.)
#   (ii)  Default-only: universal account + auto-enrollment, current-law
#         §6433 match parameters (univ_sm_match_m100). Repo headline
#         participation mechanics (59.8% on universal route, row-level
#         observed on employer route).
#   (iii) The proposal: same default mechanics, hybrid match schedule.
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/10-mwangi-program-evaluation/code/02_effect_size_benchmark.R
# =============================================================================
suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

fig_dir <- "economist-panel/10-mwangi-program-evaluation/figures"
tab_dir <- "economist-panel/10-mwangi-program-evaluation/tables"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet") %>% filter(in_universe)

df <- sim %>%
  inner_join(mod %>% select(ssuid, pnum, univ_sm_match_m100),
             by = c("SSUID" = "ssuid", "PNUM" = "pnum")) %>%
  filter(eligible_flag) %>%
  # participating_dc_flag is NA for workers without a DC account: not participating
  mutate(participating_dc_flag = participating_dc_flag %in% TRUE)

P_COND   <- 0.598   # repo SIPP-observed conditional participation
T_CTRL   <- 0.03    # Duflo et al. control take-up
T_M50    <- 0.14    # Duflo et al. 50% match take-up
SLOPE    <- (T_M50 - T_CTRL) / 50          # 0.22 pp per pp of match
T_M200   <- min(1, T_CTRL + SLOPE * 200)   # 0.47 linear extrapolation

E_w  <- sum(df$WPFINWGT[df$participating_dc_flag])        # existing savers
N0_w <- sum(df$WPFINWGT[!df$participating_dc_flag])       # current non-savers
cat("Hybrid-eligible (M):", round(sum(df$WPFINWGT)/1e6, 2),
    "| existing savers (M):", round(E_w/1e6, 2),
    "| current non-savers (M):", round(N0_w/1e6, 2), "\n")

# Match dollars by group ($B at full claiming)
hyb_exist <- sum((df$WPFINWGT * df$match_per_worker_num)[df$participating_dc_flag])
hyb_nonp  <- sum((df$WPFINWGT * df$match_per_worker_num)[!df$participating_dc_flag])
cl_exist  <- sum((df$WPFINWGT * df$univ_sm_match_m100)[df$participating_dc_flag])
cl_nonp   <- sum((df$WPFINWGT * df$univ_sm_match_m100)[!df$participating_dc_flag])

# Repo-faithful headline mechanics (04_03_simulate_match.R): split on
# has_existing_dc_flag. DC holders -> row-level observed participation;
# workers WITHOUT an existing DC account -> uniform 59.8% participation.
no_dc <- !df$has_existing_dc_flag
hyb_nodc_all  <- sum((df$WPFINWGT * df$match_per_worker_num)[no_dc])
hyb_dc_part   <- sum((df$WPFINWGT * df$match_per_worker_num)[!no_dc & df$participating_dc_flag])
cl_nodc_all   <- sum((df$WPFINWGT * df$univ_sm_match_m100)[no_dc])
cl_dc_part    <- sum((df$WPFINWGT * df$univ_sm_match_m100)[!no_dc & df$participating_dc_flag])
W_nodc        <- sum(df$WPFINWGT[no_dc])
E_dc          <- sum(df$WPFINWGT[!no_dc & df$participating_dc_flag])

# New savers under default mechanics: every account-less eligible worker who
# participates is by construction a new saver (no DC account today). The DC
# branch keeps row-level observed participation (no new savers there).
new_savers_default   <- P_COND * W_nodc
participants_default <- P_COND * W_nodc + E_dc
cost_iii <- P_COND * hyb_nodc_all + hyb_dc_part
cost_ii  <- P_COND * cl_nodc_all  + cl_dc_part
cat("Replication check — headline participants (M):", round(participants_default/1e6, 2),
    "(repo: 27.54) | headline cost ($B):", round(cost_iii/1e9, 2), "(repo: 14.95)\n")
cat("New savers under default mechanics (M):", round(new_savers_default/1e6, 2), "\n")

# Opt-in scenarios: existing savers all claim; non-savers opt in at take-up t.
optin <- function(t) {
  list(
    new      = (t - T_CTRL) * N0_w,
    cost     = hyb_exist + t * hyb_nonp,
    infra    = hyb_exist + T_CTRL * hyb_nonp
  )
}
ia <- optin(T_M50); ib <- optin(T_M200)

results <- tibble(
  scenario = c(
    "(i-a) Match-only, opt-in — take-up at largest tested match (50%): 14% gross",
    "(i-b) Match-only, opt-in — linear extrapolation to 200% match: 47% gross",
    "(ii) Default-only — universal account + auto-enrollment, current-law §6433 match",
    "(iii) Proposal — universal account + auto-enrollment + hybrid match"
  ),
  eligible_M            = round(sum(df$WPFINWGT)/1e6, 2),
  new_savers_M          = round(c(ia$new, ib$new, new_savers_default, new_savers_default)/1e6, 2),
  annual_cost_B         = round(c(ia$cost, ib$cost, cost_ii, cost_iii)/1e9, 2),
  cost_per_new_saver    = round(c(ia$cost/ia$new, ib$cost/ib$new,
                                  cost_ii/new_savers_default, cost_iii/new_savers_default), 0),
  # "Inframarginal" = dollars to workers already saving before the policy.
  # In (ii)/(iii) that is exactly the DC-branch row-level participants; every
  # universal-branch participant is a new saver (they have no DC account today).
  share_dollars_inframarginal = round(c(
    ia$infra/ia$cost, ib$infra/ib$cost,
    cl_dc_part / cost_ii,
    hyb_dc_part / cost_iii
  ), 2)
)

write.csv(results, file.path(tab_dir, "cost_per_marginal_new_saver.csv"), row.names = FALSE)
print(as.data.frame(results))

# =============================================================================
# Figure 2 — the dose-response evidence gap
# =============================================================================
duflo_pts <- tibble(
  match = c(0, 20, 50),
  takeup = c(3, 8, 14) )
extrap <- tibble(match = seq(0, 200, 5),
                 takeup = pmin(100, T_CTRL*100 + SLOPE*100*match/1))
extrap$takeup <- 3 + 0.22*extrap$match

p2 <- ggplot() +
  annotate("rect", xmin = 50, xmax = 200, ymin = -Inf, ymax = Inf,
           fill = "grey85", alpha = 0.5) +
  annotate("text", x = 125, y = 97, size = 3.4, color = "grey30",
           label = "No experimental evidence: no match above 50% has been tested at scale") +
  geom_line(data = extrap, aes(x = match, y = takeup, linetype = "Linear extrapolation of Duflo et al. slope"),
            color = "#2b6cb0", linewidth = 0.9) +
  geom_point(data = duflo_pts, aes(x = match, y = takeup), color = "#2b6cb0", size = 3.2) +
  geom_text(data = duflo_pts, aes(x = match, y = takeup,
            label = paste0(takeup, "%")), vjust = -1, color = "#2b6cb0", size = 3.4) +
  geom_hline(yintercept = 59.8, color = "#1a654d", linewidth = 0.9) +
  annotate("text", x = 6, y = 63, hjust = 0, color = "#1a654d", size = 3.6,
           label = "Auto-enrollment: SIPP-observed conditional participation, 59.8%") +
  geom_hline(yintercept = 86, color = "#1a654d", linewidth = 0.9, linetype = "dashed") +
  annotate("text", x = 6, y = 89.5, hjust = 0, color = "#1a654d", size = 3.6,
           label = "Auto-enrollment: Madrian & Shea (2001) new-hire participation, 86%") +
  annotate("point", x = 200, y = 47, shape = 21, fill = "white", color = "#2b6cb0", size = 3.5) +
  annotate("text", x = 196, y = 42, hjust = 1, color = "#2b6cb0", size = 3.5,
           label = "Implied opt-in take-up at a 200% match: ~47%\n(heroic linear extrapolation, 4x outside support)") +
  scale_linetype_manual(values = c("Linear extrapolation of Duflo et al. slope" = "dotted")) +
  scale_x_continuous(breaks = seq(0, 200, 25)) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20),
                     labels = function(x) paste0(x, "%")) +
  labs(
    title = "What match rates buy, and what defaults buy",
    subtitle = "Opt-in IRA take-up by match rate in the H&R Block experiment (points) vs. participation under\nautomatic enrollment (horizontal lines). The proposal's 200% match sits 4x beyond the tested range.",
    x = "Match rate (percent of contribution)",
    y = "Take-up / participation rate",
    linetype = NULL,
    caption = "Sources: Duflo, Gale, Liebman, Orszag & Saez (2006, NBER w11680), take-up 3/8/14% at 0/20/50% match;\nMadrian & Shea (2001, NBER w7682); SIPP-observed conditional participation from the repo simulation (59.8%).\nPanelist 10 (Mwangi)."
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold"))

ggsave(file.path(fig_dir, "fig2_dose_response_evidence_gap.png"), p2,
       width = 9.5, height = 6.5, dpi = 200)
cat("\nWrote fig2 and cost_per_marginal_new_saver.csv\n")
