# =============================================================================
# 02_timeline.R — Policy timeline: Saver's Credit (2001) to the EO portal
# deadline (Jan 1, 2027), annotated with party control of the White House and
# the two chambers. (Liu, political-economy panel, 08.)
#
# Output: economist-panel/08-liu-political-economy/figures/fig2_policy_timeline.png
# Run from repo root:
#   & "C:\Program Files\R\R-4.4.3\bin\Rscript.exe" economist-panel/08-liu-political-economy/code/02_timeline.R
# =============================================================================

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })

out_fig <- "economist-panel/08-liu-political-economy/figures"

events <- tribble(
  ~date,        ~label,                                                      ~y,   ~label_x,
  "2001-06-07", "Saver's Credit enacted\n(EGTRRA, 2001)",                     1.8, "2002-06-01",
  "2022-12-29", "SECURE 2.0 / sec. 6433\nSaver's Match enacted\n(P.L. 117-328)", 2.5, "2020-03-01",
  "2022-12-08", "RSAA introduced\n(117th, S.5271)",                          -1.5, "2019-09-01",
  "2023-10-19", "RSAA reintroduced\n(118th, S.3102/H.R.6065)",               -2.6, "2022-06-01",
  "2024-09-05", "IRS Notice 2024-65\n(sec. 6433 comment request)",            1.2, "2021-10-01",
  "2025-04-30", "RSAA reintroduced\n(119th, S.1526/H.R.2696)",               -1.5, "2024-09-01",
  "2026-02-03", "State of the Union:\nfederal match proposal",                2.6, "2024-06-01",
  "2026-04-30", "Executive order:\nTrumpIRA.gov established",                 1.6, "2027-09-01",
  "2026-06-05", "TrumpIRA.gov\npre-launch teaser",                           -2.6, "2026-10-01",
  "2027-01-01", "sec. 6433 effective (TY2027);\nEO portal deadline",          2.6, "2028-09-01"
) %>% mutate(date = as.Date(date), label_x = as.Date(label_x))

# Party control bands (White House / Senate / House), simplified to the
# periods spanned by the timeline. Senate 2001-02 switched mid-year (50-50,
# then Democratic control from June 2001); labeled "split".
control <- tribble(
  ~start,        ~end,          ~wh,  ~sen,    ~hse,
  "2001-01-20",  "2003-01-03",  "R",  "split", "R",
  "2003-01-03",  "2007-01-03",  "R",  "R",     "R",
  "2007-01-03",  "2009-01-20",  "R",  "D",     "D",
  "2009-01-20",  "2011-01-03",  "D",  "D",     "D",
  "2011-01-03",  "2015-01-03",  "D",  "D",     "R",
  "2015-01-03",  "2017-01-20",  "D",  "R",     "R",
  "2017-01-20",  "2019-01-03",  "R",  "R",     "R",
  "2019-01-03",  "2021-01-20",  "R",  "R",     "D",
  "2021-01-20",  "2023-01-03",  "D",  "D",     "D",
  "2023-01-03",  "2025-01-20",  "D",  "D",     "R",
  "2025-01-20",  "2027-06-30",  "R",  "R",     "R"
) %>%
  mutate(start = as.Date(start), end = as.Date(end),
         trifecta = case_when(
           wh == "D" & sen == "D" & hse == "D" ~ "Unified Democratic",
           wh == "R" & sen == "R" & hse == "R" ~ "Unified Republican",
           TRUE                                ~ "Divided government"))

xlim <- as.Date(c("1999-06-01", "2030-09-01"))

p <- ggplot() +
  # party-control band along the bottom
  geom_rect(data = control,
            aes(xmin = pmax(start, xlim[1]), xmax = pmin(end, xlim[2]),
                ymin = -3.45, ymax = -3.05, fill = trifecta), alpha = 0.9) +
  scale_fill_manual(values = c("Unified Democratic" = "#3f6fb5",
                               "Unified Republican" = "#c0392b",
                               "Divided government" = "grey72")) +
  # spine
  geom_hline(yintercept = 0, color = "grey30", linewidth = 0.6) +
  # event stems and points (stems lean toward the label position)
  geom_segment(data = events,
               aes(x = date, xend = label_x, y = 0, yend = y * 0.82),
               color = "grey55", linewidth = 0.4) +
  geom_point(data = events, aes(x = date, y = 0), size = 2.6,
             color = "#2c526b") +
  geom_label(data = events, aes(x = label_x, y = y, label = label),
             size = 2.8, lineheight = 0.95,
             fill = "white", color = "grey15") +
  scale_x_date(limits = xlim, date_breaks = "2 years", date_labels = "%Y",
               expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_continuous(limits = c(-3.6, 3.0)) +
  labs(title = "A quarter-century from Saver's Credit to TrumpIRA.gov: the legislative and executive track",
       subtitle = "Both enactments (2001 EGTRRA, 2022 SECURE 2.0) cleared under unified government as small pieces of bipartisan omnibus vehicles;\nthe RSAA's three introductions (2022, 2023, 2025) all died without committee action. Bottom band: party control (White House + both chambers).",
       x = NULL, y = NULL,
       caption = "Sources: Congress.gov bill histories; CRS IF11159 (2025); IRS Notice 2024-65; White House EO of April 30, 2026; TrumpIRA.gov capture of June 10, 2026 (economist-panel/_shared/sources/).") +
  guides(fill = guide_legend(title = NULL)) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom",
        axis.text.y = element_blank(),
        panel.grid.major.y = element_blank(),
        panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", size = 12.5),
        plot.subtitle = element_text(size = 9, color = "grey25"),
        plot.caption = element_text(size = 7.2, color = "grey40", hjust = 0))

ggsave(file.path(out_fig, "fig2_policy_timeline.png"), p,
       width = 10, height = 6, dpi = 200)
cat("Done: 02_timeline.R\n")
