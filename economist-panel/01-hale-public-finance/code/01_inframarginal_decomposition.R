# =============================================================================
# 01_inframarginal_decomposition.R  (Hale, public finance panel)
#
# Analytical charge 1: inframarginal-windfall decomposition of the hybrid
# proposal's eligible population and full-participation match dollars, by
# existing DC participation status.
#
# Analytical charge 2: marginal-cost-of-expansion decomposition of the hybrid
# ceiling cost relative to the current-law Saver's Match (universal_m100
# baseline: 33.08M eligible / $9.19B / $278 avg).
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/01-hale-public-finance/code/01_inframarginal_decomposition.R
# =============================================================================

suppressMessages({
  library(arrow)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
})

OUT_TAB <- "economist-panel/01-hale-public-finance/tables"
OUT_FIG <- "economist-panel/01-hale-public-finance/figures"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
mod <- read_parquet("data/processed/sipp_modeled.parquet")

stopifnot(nrow(sim) == 14961)

# -----------------------------------------------------------------------------
# PART 1 — Inframarginal-windfall decomposition (hybrid eligible population)
# -----------------------------------------------------------------------------
# participating_dc_flag is NA when has_existing_dc_flag == FALSE (no account
# to participate in). Treat NA as not participating.

elig <- sim %>%
  filter(eligible_flag) %>%
  mutate(
    infra_group = case_when(
      participating_dc_flag %in% TRUE                      ~ "1_already_participating_dc",
      has_existing_dc_flag & !(participating_dc_flag %in% TRUE) ~ "2_has_dc_not_participating",
      TRUE                                                 ~ "3_no_dc_account"
    )
  )

infra_tab <- elig %>%
  group_by(infra_group) %>%
  summarise(
    workers_M       = sum(WPFINWGT) / 1e6,
    ceiling_cost_B  = sum(match_per_worker_num * WPFINWGT) / 1e9,
    avg_match_usd   = sum(match_per_worker_num * WPFINWGT) / sum(WPFINWGT),
    mean_magi_usd   = sum(magi_num * WPFINWGT) / sum(WPFINWGT),
    .groups = "drop"
  ) %>%
  mutate(
    share_workers = workers_M / sum(workers_M),
    share_dollars = ceiling_cost_B / sum(ceiling_cost_B)
  )

tot_workers_M <- sum(infra_tab$workers_M)
tot_cost_B    <- sum(infra_tab$ceiling_cost_B)

infra_part   <- infra_tab %>% filter(infra_group == "1_already_participating_dc")
newly_reached <- infra_tab %>% filter(infra_group != "1_already_participating_dc")
newly_M  <- sum(newly_reached$workers_M)
newly_B  <- sum(newly_reached$ceiling_cost_B)

cat("=== PART 1: Inframarginal decomposition (hybrid eligible, full participation) ===\n")
print(as.data.frame(infra_tab), digits = 4)
cat(sprintf("\nTotal eligible: %.2fM | ceiling cost: $%.2fB\n", tot_workers_M, tot_cost_B))
cat(sprintf("Already-participating (inframarginal): %.2fM (%.1f%% of eligible), $%.2fB (%.1f%% of ceiling)\n",
            infra_part$workers_M, 100*infra_part$share_workers,
            infra_part$ceiling_cost_B, 100*infra_part$share_dollars))
cat(sprintf("Newly reached (not currently participating): %.2fM, $%.2fB\n", newly_M, newly_B))
cat(sprintf("Ceiling cost per eligible worker overall: $%.0f\n", tot_cost_B*1e9 / (tot_workers_M*1e6)))
cat(sprintf("Ceiling cost per genuinely NEWLY REACHED worker: $%.0f\n", tot_cost_B*1e9 / (newly_M*1e6)))
cat(sprintf("  (i.e., total program dollars divided by newly reached savers)\n"))
cat(sprintf("Dollars landing on newly reached, per newly reached worker: $%.0f\n", newly_B*1e9/(newly_M*1e6)))

# -----------------------------------------------------------------------------
# PART 2 — Marginal cost of expansion vs current-law SS6433 (universal_m100)
# -----------------------------------------------------------------------------
# Join hybrid simulation rows to the modeled frame to get current-law
# eligibility (is_anymatch_m100) and current-law full-participation match
# (univ_sm_match_m100) for the same persons.

mu <- mod %>%
  filter(in_universe) %>%
  select(ssuid, pnum, weight, is_anymatch_m100, univ_sm_match_m100)

j <- sim %>%
  inner_join(mu, by = c("SSUID" = "ssuid", "PNUM" = "pnum"))

stopifnot(nrow(j) == nrow(sim))
stopifnot(all(abs(j$WPFINWGT - j$weight) < 1e-6))

# Sanity: replicate current-law baseline (universal_m100 row)
cl_elig_M <- sum(j$weight[j$is_anymatch_m100]) / 1e6
cl_cost_B <- sum(j$univ_sm_match_m100 * j$weight) / 1e9
cat(sprintf("\n=== PART 2: Marginal cost of expansion ===\n"))
cat(sprintf("Current-law (universal_m100) replication: %.2fM eligible, $%.2fB full participation, $%.0f avg\n",
            cl_elig_M, cl_cost_B, cl_cost_B*1e9/(cl_elig_M*1e6)))

# Overlap check: is hybrid eligibility a superset of current-law eligibility?
xt <- j %>%
  count(hybrid_eligible = eligible_flag, current_law_eligible = is_anymatch_m100,
        wt = weight, name = "w") %>%
  mutate(w_M = w / 1e6)
cat("\nEligibility cross-tab (millions):\n")
print(as.data.frame(xt %>% select(-w)), digits = 4)

lost <- j %>% filter(is_anymatch_m100, !eligible_flag)
cat(sprintf("Current-law eligible but hybrid-INeligible: %.3fM workers, $%.3fB current-law dollars\n",
            sum(lost$weight)/1e6, sum(lost$univ_sm_match_m100*lost$weight)/1e9))

# Decompose hybrid full-participation ceiling:
#   (CL)  current-law dollars to current-law eligibles (the $9.2B base)
#   (a)   rate increase for current-law eligibles = hybrid dollars to them - CL dollars to them
#   (b)   frontier expansion = hybrid dollars to newly eligible workers
decomp <- j %>%
  mutate(grp = case_when(
    eligible_flag & is_anymatch_m100  ~ "current_law_eligible",
    eligible_flag & !is_anymatch_m100 ~ "newly_eligible",
    !eligible_flag & is_anymatch_m100 ~ "dropped_from_current_law",
    TRUE                              ~ "never_eligible"
  )) %>%
  group_by(grp) %>%
  summarise(
    workers_M        = sum(weight)/1e6,
    hybrid_B         = sum(match_per_worker_num * weight)/1e9,
    current_law_B    = sum(univ_sm_match_m100 * weight)/1e9,
    .groups = "drop"
  ) %>%
  mutate(increment_B = hybrid_B - current_law_B)

cat("\nHybrid vs current-law full-participation dollars by group:\n")
print(as.data.frame(decomp), digits = 4)

cle  <- decomp %>% filter(grp == "current_law_eligible")
newg <- decomp %>% filter(grp == "newly_eligible")

rate_increase_B <- cle$hybrid_B - cle$current_law_B
frontier_B      <- newg$hybrid_B
incr_total_B    <- sum(j$match_per_worker_num * j$weight)/1e9 - cl_cost_B

cat(sprintf("\nHybrid ceiling: $%.2fB | current-law ceiling: $%.2fB | increment: $%.2fB\n",
            sum(j$match_per_worker_num*j$weight)/1e9, cl_cost_B, incr_total_B))
cat(sprintf("(a) Rate increase for current-law eligibles (pure transfer to already-covered): $%.2fB (%.1f%% of increment)\n",
            rate_increase_B, 100*rate_increase_B/incr_total_B))
cat(sprintf("(b) Frontier expansion to %.2fM newly eligible workers: $%.2fB (%.1f%% of increment)\n",
            newg$workers_M, frontier_B, 100*frontier_B/incr_total_B))
cat(sprintf("Incremental ceiling cost per incremental eligible worker: $%.0f\n",
            incr_total_B*1e9/((tot_workers_M - cl_elig_M)*1e6)))
cat(sprintf("Frontier dollars per newly eligible worker: $%.0f\n",
            frontier_B*1e9/(newg$workers_M*1e6)))

# Inframarginal status of NEWLY eligible workers (do new dollars reach new savers?)
new_infra <- j %>%
  filter(eligible_flag, !is_anymatch_m100) %>%
  mutate(already_participating = participating_dc_flag %in% TRUE) %>%
  group_by(already_participating) %>%
  summarise(workers_M = sum(weight)/1e6,
            hybrid_B = sum(match_per_worker_num*weight)/1e9, .groups = "drop")
cat("\nNewly eligible workers by current DC participation:\n")
print(as.data.frame(new_infra), digits = 4)

# Cross decomposition for figure 1: ceiling cost by (current-law status x participation)
cross <- j %>%
  filter(eligible_flag) %>%
  mutate(
    cl_status = ifelse(is_anymatch_m100, "Already eligible under current law", "Newly eligible under proposal"),
    part_status = ifelse(participating_dc_flag %in% TRUE,
                         "Already participating in a DC plan (inframarginal)",
                         "Not currently participating (newly reached)")
  ) %>%
  group_by(cl_status, part_status) %>%
  summarise(workers_M = sum(weight)/1e6,
            ceiling_B = sum(match_per_worker_num*weight)/1e9, .groups = "drop")
cat("\nCross decomposition (ceiling dollars):\n")
print(as.data.frame(cross), digits = 4)

# -----------------------------------------------------------------------------
# Write tables
# -----------------------------------------------------------------------------
infra_out <- infra_tab %>%
  mutate(infra_group = recode(infra_group,
    "1_already_participating_dc" = "Already participating in a DC plan (inframarginal)",
    "2_has_dc_not_participating" = "Has a DC account, not contributing",
    "3_no_dc_account"            = "No DC account (newly reached)"))
write.csv(infra_out, file.path(OUT_TAB, "inframarginal_decomposition.csv"), row.names = FALSE)

decomp_out <- tibble(
  component = c("Current-law Saver's Match dollars (universal_m100 baseline)",
                "(a) Rate increase for current-law-eligible workers (pure transfer)",
                "(b) Frontier expansion: dollars to newly eligible workers",
                "Hybrid full-participation ceiling (total)"),
  workers_M = c(cl_elig_M, cle$workers_M, newg$workers_M, tot_workers_M),
  dollars_B = c(cl_cost_B, rate_increase_B, frontier_B,
                sum(j$match_per_worker_num*j$weight)/1e9)
)
write.csv(decomp_out, file.path(OUT_TAB, "marginal_expansion_decomposition.csv"), row.names = FALSE)
write.csv(cross, file.path(OUT_TAB, "cross_decomposition_ceiling_cost.csv"), row.names = FALSE)

# -----------------------------------------------------------------------------
# Figure 1 — stacked bars: where the $24.9B ceiling goes, two lenses
# -----------------------------------------------------------------------------
src_cap <- "Source: Author's calculations from SIPP 2024 projected to TY2027 (EIG universal-hybrid simulation,\ndata/processed/universal_sm_hybrid/simulation_results.parquet and data/processed/sipp_modeled.parquet). Full-participation ceiling."

f1a <- infra_out %>%
  transmute(lens = "Lens 1: current saving behavior",
            seg = infra_group, dollars_B = ceiling_cost_B)
f1b <- tibble(
  lens = "Lens 2: current-law eligibility",
  seg = c("Current-law match dollars ($9.2B base)",
          "Rate increase for current-law eligibles",
          "Frontier expansion to newly eligible"),
  dollars_B = c(cle$current_law_B, rate_increase_B, frontier_B)
)
# Lens 2 omits the small amount lost by dropped current-law eligibles; the
# stacked total equals hybrid dollars to current-law eligibles + new eligibles.

f1 <- bind_rows(f1a, f1b) %>%
  group_by(lens) %>% mutate(share = dollars_B/sum(dollars_B)) %>% ungroup() %>%
  mutate(seg = factor(seg, levels = c(
    "Already participating in a DC plan (inframarginal)",
    "Has a DC account, not contributing",
    "No DC account (newly reached)",
    "Current-law match dollars ($9.2B base)",
    "Rate increase for current-law eligibles",
    "Frontier expansion to newly eligible")))

pal <- c("Already participating in a DC plan (inframarginal)" = "#9b2226",
         "Has a DC account, not contributing"                 = "#e09f3e",
         "No DC account (newly reached)"                      = "#335c67",
         "Current-law match dollars ($9.2B base)"             = "#6c757d",
         "Rate increase for current-law eligibles"            = "#bb3e03",
         "Frontier expansion to newly eligible"               = "#0a9396")

p1 <- ggplot(f1, aes(x = lens, y = dollars_B, fill = seg)) +
  geom_col(width = 0.55, color = "white", linewidth = 0.4) +
  geom_text(aes(label = sprintf("$%.1fB\n(%.0f%%)", dollars_B, 100*share)),
            position = position_stack(vjust = 0.5), color = "white",
            size = 3.4, fontface = "bold", lineheight = 0.95) +
  scale_y_continuous(labels = label_dollar(suffix = "B"), expand = expansion(mult = c(0, 0.05))) +
  scale_fill_manual(values = pal, name = NULL) +
  labs(title = "Where the $24.9 billion full-participation ceiling goes",
       subtitle = "Hybrid proposal match dollars decomposed by current saving behavior (left) and by current-law §6433 eligibility (right)",
       x = NULL, y = "Annual federal match dollars (full participation)",
       caption = src_cap) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
        legend.position = "right", plot.caption = element_text(size = 7.5, hjust = 0, color = "grey35"),
        plot.title = element_text(face = "bold"), plot.subtitle = element_text(size = 9.5))

ggsave(file.path(OUT_FIG, "fig1_ceiling_cost_decomposition.png"), p1,
       width = 10, height = 6.2, dpi = 200)

# -----------------------------------------------------------------------------
# Figure 2 — cost per worker vs cost per genuinely newly reached saver
# -----------------------------------------------------------------------------
cl_per_worker      <- cl_cost_B*1e9 / (cl_elig_M*1e6)
hyb_per_worker     <- tot_cost_B*1e9 / (tot_workers_M*1e6)
hyb_per_new        <- tot_cost_B*1e9 / (newly_M*1e6)
incr_per_incr_elig <- incr_total_B*1e9 / ((tot_workers_M - cl_elig_M)*1e6)

f2 <- tibble(
  metric = factor(c("Current law (§6433):\nceiling cost per eligible worker",
             "Hybrid proposal:\nceiling cost per eligible worker",
             "Hybrid proposal:\nincremental cost per incremental\neligible worker",
             "Hybrid proposal:\ntotal ceiling cost per worker NOT\nalready participating in a DC plan"),
             levels = c("Current law (§6433):\nceiling cost per eligible worker",
             "Hybrid proposal:\nceiling cost per eligible worker",
             "Hybrid proposal:\nincremental cost per incremental\neligible worker",
             "Hybrid proposal:\ntotal ceiling cost per worker NOT\nalready participating in a DC plan")),
  usd = c(cl_per_worker, hyb_per_worker, incr_per_incr_elig, hyb_per_new),
  kind = c("Average", "Average", "Marginal", "Per newly reached saver")
)

p2 <- ggplot(f2, aes(x = metric, y = usd, fill = kind)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = dollar(round(usd))), vjust = -0.45, size = 4, fontface = "bold") +
  scale_y_continuous(labels = label_dollar(), expand = expansion(mult = c(0, 0.12))) +
  scale_fill_manual(values = c("Average" = "#6c757d", "Marginal" = "#bb3e03",
                               "Per newly reached saver" = "#9b2226"), name = NULL) +
  labs(title = "Average vs. marginal cost of the match expansion",
       subtitle = "Full-participation basis. \"Newly reached\" = eligible workers not currently participating in a DC plan.",
       x = NULL, y = "Annual federal match dollars per worker",
       caption = src_cap) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.major.x = element_blank(), panel.grid.minor = element_blank(),
        legend.position = "none", plot.caption = element_text(size = 7.5, hjust = 0, color = "grey35"),
        plot.title = element_text(face = "bold"), plot.subtitle = element_text(size = 9.5),
        axis.text.x = element_text(size = 9))

ggsave(file.path(OUT_FIG, "fig2_cost_per_new_saver.png"), p2,
       width = 9, height = 6, dpi = 200)

cat("\nDone. Tables and figures written.\n")
