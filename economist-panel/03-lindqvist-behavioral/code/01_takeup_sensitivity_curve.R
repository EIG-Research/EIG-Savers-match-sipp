# 01_takeup_sensitivity_curve.R
# Panelist 03 (Lindqvist, behavioral). Cost-vs-take-up curve for the universal-account
# Saver's Match hybrid, with literature-grounded participation markers.
#
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/03-lindqvist-behavioral/code/01_takeup_sensitivity_curve.R
#
# Headline construction (verified against data/processed/universal_sm_hybrid/scenario_results.parquet):
#   - Workers with an OBSERVED DC participation status (participating_dc_flag non-NA;
#     15.99M weighted eligible) keep their row-level flag -> fixed cost component $5.01B.
#   - Workers with NO observed DC status (NA flag; the newly auto-enrolled margin,
#     30.07M weighted, spanning both routes) participate at the SIPP-observed
#     conditional rate p = 0.5979 -> $9.94B. Total = $14.95B headline.
# The cost is therefore closed-form linear in p on the auto-enrolled margin.

suppressPackageStartupMessages({
  library(arrow); library(dplyr); library(tidyr); library(ggplot2); library(scales)
})

out_fig <- "economist-panel/03-lindqvist-behavioral/figures"
out_tab <- "economist-panel/03-lindqvist-behavioral/tables"

sim <- read_parquet("data/processed/universal_sm_hybrid/simulation_results.parquet")
el  <- sim %>% filter(eligible_flag)

# --- components -------------------------------------------------------------
obs    <- el %>% filter(!is.na(participating_dc_flag))
margin <- el %>% filter(is.na(participating_dc_flag))          # newly auto-enrolled margin

cost_obs_fixed   <- sum(obs$WPFINWGT * obs$match_per_worker_num * obs$participating_dc_flag) / 1e9
cost_margin_full <- sum(margin$WPFINWGT * margin$match_per_worker_num) / 1e9
cost_full        <- sum(el$WPFINWGT * el$match_per_worker_num) / 1e9
n_margin_M       <- sum(margin$WPFINWGT) / 1e6
n_obs_M          <- sum(obs$WPFINWGT) / 1e6
n_obs_part_M     <- sum(obs$WPFINWGT * obs$participating_dc_flag) / 1e6

# SIPP-observed conditional DC participation rate (the headline p)
p_headline <- weighted.mean(obs$participating_dc_flag, obs$WPFINWGT)

# strict route-based variant requested in the charge: p applied to the entire
# universal-account route; employer-plan route inherits observed flags
# (employer-route workers with no observed status get p as in the headline).
univ <- el %>% filter(route_chr == "universal_account")
empl <- el %>% filter(route_chr == "employer_plan")
cost_univ_full     <- sum(univ$WPFINWGT * univ$match_per_worker_num) / 1e9
cost_empl_obs      <- sum(empl$WPFINWGT * empl$match_per_worker_num *
                            coalesce(as.numeric(empl$participating_dc_flag), p_headline)) / 1e9

cat(sprintf("Eligible: %.2fM | observed-status: %.2fM (%.2fM participating) | auto-enrolled margin: %.2fM\n",
            sum(el$WPFINWGT)/1e6, n_obs_M, n_obs_part_M, n_margin_M))
cat(sprintf("Fixed observed cost: $%.2fB | margin full cost: $%.2fB | full participation: $%.2fB\n",
            cost_obs_fixed, cost_margin_full, cost_full))
cat(sprintf("Headline p (SIPP conditional): %.4f -> headline cost $%.2fB (repo: $14.946B)\n",
            p_headline, cost_obs_fixed + p_headline * cost_margin_full))
cat(sprintf("Route-based variant at p=%.4f: $%.2fB\n",
            p_headline, p_headline * cost_univ_full + cost_empl_obs))

# --- curves -----------------------------------------------------------------
grid <- tibble(p = seq(0, 1, by = 0.01)) %>%
  mutate(
    cost_margin_B      = cost_obs_fixed + p * cost_margin_full,   # headline construction
    cost_uniform_B     = p * cost_full,                            # uniform participation
    cost_route_based_B = p * cost_univ_full + cost_empl_obs,       # strict route-based
    participants_margin_M  = n_obs_part_M + p * n_margin_M,
    participants_uniform_M = p * sum(el$WPFINWGT) / 1e6
  )

write.csv(grid %>% filter(p %in% seq(0.2, 1, 0.05)) %>% mutate(across(-p, ~round(.x, 2))),
          file.path(out_tab, "takeup_cost_curve.csv"), row.names = FALSE)

# --- literature markers (verified 2026-06-10; see sources/sources.md) -------
markers <- tibble(
  p = c(0.86, 0.641, 0.343, 0.14, 0.057),
  label = c(
    "Madrian-Shea (2001): auto-enrollment, 86%",
    "CalSavers auto-IRA: 64% stay in (35.9% opt out, Jul 2024)",
    "OregonSaves: 34% with positive balance (Chalmers et al. 2021)",
    "Duflo et al. (2006): 14% take-up, 50% match, H&R Block",
    "Saver's Credit: 5.7% of all returns claim (CRS 2025)"
  )
) %>%
  mutate(cost_margin_B = cost_obs_fixed + p * cost_margin_full)

write.csv(markers %>% mutate(cost_margin_B = round(cost_margin_B, 2)),
          file.path(out_tab, "literature_markers.csv"), row.names = FALSE)
print(as.data.frame(markers))

# --- figure 1 ---------------------------------------------------------------
curve_long <- grid %>%
  select(p, `Headline construction: p applied to 30.1M auto-enrolled margin` = cost_margin_B,
         `Uniform: p applied to all 46.1M eligible workers` = cost_uniform_B) %>%
  pivot_longer(-p, names_to = "construction", values_to = "cost")

headline_pt <- tibble(p = p_headline, cost = cost_obs_fixed + p_headline * cost_margin_full)

markers <- markers %>%
  arrange(desc(p)) %>%
  mutate(num = row_number(),
         key = sprintf("[%d]  %s  →  $%.1fB", num, label, cost_margin_B))

key_text <- paste(markers$key, collapse = "\n")

fig1 <- ggplot(curve_long, aes(p, cost, color = construction, linetype = construction)) +
  geom_line(linewidth = 1.1) +
  geom_point(data = markers, aes(p, cost_margin_B), inherit.aes = FALSE,
             size = 3.2, color = "#1a1a1a") +
  geom_text(data = markers, aes(p, cost_margin_B, label = num), inherit.aes = FALSE,
            hjust = 0.5, nudge_y = -1.15, size = 3.2, fontface = "bold", color = "#1a1a1a") +
  geom_point(data = headline_pt, aes(p, cost), inherit.aes = FALSE,
             shape = 21, size = 4, fill = "#d6452c", color = "white", stroke = 1) +
  geom_text(data = headline_pt, aes(p, cost),
            label = "Repo headline:\np = 0.598, $14.9B", inherit.aes = FALSE,
            hjust = 0.5, nudge_y = 2.4, size = 3.1,
            fontface = "bold", color = "#d6452c", lineheight = 0.95) +
  annotate("text", x = 0.015, y = 26.3, label = key_text, hjust = 0, vjust = 1,
           size = 2.95, color = "#1a1a1a", lineheight = 1.25) +
  scale_x_continuous(labels = percent_format(accuracy = 1), breaks = seq(0, 1, 0.1),
                     limits = c(0, 1.02), expand = c(0, 0)) +
  scale_y_continuous(labels = dollar_format(suffix = "B"), breaks = seq(0, 25, 5),
                     limits = c(0, 27)) +
  scale_color_manual(values = c("#2b6a99", "#8a8a8a")) +
  scale_linetype_manual(values = c("solid", "22")) +
  labs(
    title = "Figure 1. Annual federal cost of the hybrid by participation rate,\nwith literature-grounded take-up benchmarks",
    subtitle = "Markers placed on the headline-construction curve at participation rates observed in the behavioral literature",
    x = "Participation rate p among newly auto-enrolled workers",
    y = "Annual federal match cost",
    caption = paste0("Source: Author's computation from data/processed/universal_sm_hybrid/simulation_results.parquet (SIPP 2024 projected to TY2027);\n",
                     "Madrian and Shea, 2001; Chalmers et al., 2021; Duflo et al., 2006; CalSavers program data via ASPPA, 2024; CRS IF11159, 2025."),
    color = NULL, linetype = NULL
  ) +
  theme_minimal(base_size = 11) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position = "bottom",
    legend.direction = "vertical",
    plot.title = element_text(face = "bold"),
    plot.caption = element_text(size = 7, hjust = 0, color = "grey35")
  )

ggsave(file.path(out_fig, "fig1_takeup_sensitivity_curve.png"), fig1,
       width = 10, height = 6.5, dpi = 200)
cat("Saved fig1.\n")
