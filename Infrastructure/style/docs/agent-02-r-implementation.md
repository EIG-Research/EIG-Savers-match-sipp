# Agent 02: R Specialist (First Pass)

## Scope
Translate `docs/agent-01-design-spec.md` into reusable R style code for:
- Base R plots
- `ggplot2`
- `plotly`
- Tables (`gt`, optional `flextable`)

## 1) Setup and Font Installation Prompts
```r
# Package install prompt
install.packages(c(
  "ggplot2", "plotly", "scales", "showtext", "sysfonts",
  "gt", "flextable", "dplyr"
))
```

```r
# Font download/install prompt (portable from within R)
# Downloads Google-hosted fonts for use in charts.
sysfonts::font_add_google("Open Sans", "Open Sans")
sysfonts::font_add_google("Source Serif Pro", "Source Serif Pro")
showtext::showtext_auto()
```

## 2) Design Tokens
```r
EIG_COLORS <- c(
  eig_teal_900 = "#024140",
  eig_green_700 = "#19644D",
  eig_green_500 = "#5E9C86",
  eig_blue_800 = "#194F8B",
  eig_blue_200 = "#B3D6DD",
  eig_cream_100 = "#FEECD6",
  eig_purple_800 = "#39274F",
  eig_gold_600 = "#E1AD28",
  eig_cyan_700 = "#176F96",
  eig_tan_500 = "#D6936F",
  eig_tan_300 = "#F0B799",
  eig_black = "#000000",
  eig_white = "#FFFFFF"
)

EIG_DISCRETE <- c(
  EIG_COLORS["eig_teal_900"],
  EIG_COLORS["eig_blue_800"],
  EIG_COLORS["eig_green_500"],
  EIG_COLORS["eig_gold_600"],
  EIG_COLORS["eig_purple_800"],
  EIG_COLORS["eig_cyan_700"],
  EIG_COLORS["eig_tan_500"]
)

EIG_SEQ_BLUE <- c("#164C87", "#236BB7", "#419EF1", "#79C5FD", "#C1DCFD")
EIG_SEQ_RED  <- c("#97310E", "#D34917", "#F97D1E", "#FBA94F", "#FDD7A8")

EIG_LEGACY <- list(
  dci_quintile = c(
    distressed = "#97310E",
    at_risk = "#F97D1E",
    mid_tier = "#9FD2C0",
    comfortable = "#419EF1",
    prosperous = "#164C87"
  ),
  educ_attainment = c(
    no_hs_diploma = "#F97D1E",
    hs_diploma = "#FDD7A8",
    some_college = "#C1DCFD",
    bachelors_plus = "#164C87"
  )
)
```

## 3) ggplot2 Theme
```r
library(ggplot2)

theme_eig <- function(base_size = 10) {
  theme_minimal(base_size = base_size, base_family = "Open Sans") +
    theme(
      plot.title = element_text(
        family = "Source Serif Pro", face = "semibold",
        size = base_size * 1.5, color = EIG_COLORS["eig_black"], hjust = 0
      ),
      plot.subtitle = element_text(
        family = "Open Sans", face = "semibold",
        size = base_size * 1.1, color = EIG_COLORS["eig_teal_900"], hjust = 0
      ),
      axis.title = element_text(face = "semibold", color = EIG_COLORS["eig_black"]),
      axis.text = element_text(color = EIG_COLORS["eig_black"]),
      legend.title = element_text(face = "semibold"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.major.y = element_line(color = "#D9D9D9", linewidth = 0.3),
      plot.background = element_rect(fill = "white", color = NA),
      panel.background = element_rect(fill = "white", color = NA),
      plot.caption = element_text(size = base_size * 0.8, color = "#444444", hjust = 0)
    )
}

scale_color_eig <- function(...) scale_color_manual(values = EIG_DISCRETE, ...)
scale_fill_eig <- function(...) scale_fill_manual(values = EIG_DISCRETE, ...)
scale_fill_eig_seq_blue <- function(...) scale_fill_gradientn(colors = EIG_SEQ_BLUE, ...)
scale_fill_eig_seq_red <- function(...) scale_fill_gradientn(colors = EIG_SEQ_RED, ...)
```

### Example (`ggplot2`)
```r
ggplot(mtcars, aes(wt, mpg, color = factor(cyl))) +
  geom_point(size = 2.8, alpha = 0.9) +
  scale_color_eig(name = "Cylinders") +
  labs(
    title = "Fuel Economy by Vehicle Weight",
    subtitle = "Demonstration of EIG ggplot theme",
    caption = "Source: mtcars"
  ) +
  theme_eig()
```

## 4) Base R Defaults
```r
eig_base_defaults <- function() {
  op <- par(
    family = "Open Sans",
    bg = "white",
    fg = EIG_COLORS["eig_black"],
    col.axis = EIG_COLORS["eig_black"],
    col.lab = EIG_COLORS["eig_black"],
    las = 1,
    bty = "l"
  )
  invisible(op)
}
```

### Example (Base R)
```r
old_par <- eig_base_defaults()
plot(
  mtcars$wt, mtcars$mpg,
  pch = 16, col = EIG_COLORS["eig_teal_900"],
  main = "Fuel Economy by Vehicle Weight",
  xlab = "Weight", ylab = "MPG"
)
par(old_par)
```

## 5) Plotly Theme
```r
library(plotly)

eig_plotly_layout <- list(
  font = list(family = "Open Sans", size = 11, color = EIG_COLORS["eig_black"]),
  title = list(font = list(family = "Source Serif Pro", size = 20, color = EIG_COLORS["eig_black"])),
  paper_bgcolor = "white",
  plot_bgcolor = "white",
  colorway = unname(EIG_DISCRETE),
  xaxis = list(showgrid = FALSE, zeroline = FALSE),
  yaxis = list(showgrid = TRUE, gridcolor = "#D9D9D9", zeroline = FALSE)
)
```

### Example (`plotly`)
```r
plot_ly(
  mtcars, x = ~wt, y = ~mpg,
  color = ~factor(cyl),
  colors = EIG_DISCRETE,
  type = "scatter", mode = "markers"
) |>
  layout(
    title = list(text = "Fuel Economy by Vehicle Weight"),
    xaxis = list(title = "Weight"),
    yaxis = list(title = "MPG"),
    font = eig_plotly_layout$font,
    paper_bgcolor = eig_plotly_layout$paper_bgcolor,
    plot_bgcolor = eig_plotly_layout$plot_bgcolor,
    colorway = eig_plotly_layout$colorway
  )
```

## 6) Table Theme (`gt`)
```r
library(gt)

eig_gt <- function(gt_tbl) {
  gt_tbl |>
    tab_options(
      table.border.top.width = px(0),
      table.border.bottom.width = px(0),
      heading.border.bottom.width = px(0),
      column_labels.border.top.width = px(0),
      column_labels.border.bottom.color = "#D9D9D9",
      table_body.hlines.color = "#E6E6E6",
      table_body.hlines.width = px(1)
    ) |>
    tab_style(
      style = list(
        cell_fill(color = EIG_COLORS["eig_teal_900"]),
        cell_text(color = "white", weight = "bold", font = "Open Sans")
      ),
      locations = cells_column_labels(columns = everything())
    ) |>
    opt_table_font(font = list(google_font("Open Sans"), default_fonts()))
}
```

### Example (`gt`)
```r
mtcars |>
  head(8) |>
  gt() |>
  fmt_number(columns = where(is.numeric), decimals = 1) |>
  eig_gt()
```

## 7) Coverage Checklist
- Base R: yes
- `ggplot2`: yes
- `plotly`: yes
- Tables: `gt` first-class, `flextable` optional extension
- Legacy semantic palettes for specialized data stories: included

## 8) Datawrapper Publishing Bridge (R Pipelines)
For Datawrapper-specific implementation requirements, follow:
`docs/datawrapper-integration.md`
Repo link: [docs/datawrapper-integration.md](datawrapper-integration.md)

Minimum pattern:
```r
library(jsonlite)

token_doc <- read_json(
  "tokens/eig-style-tokens.v1.json",
  simplifyVector = TRUE
)
brand_map <- stats::setNames(token_doc$colors$brand$hex, token_doc$colors$brand$id)

eig_line_colors <- c(
  brand_map[["eig_teal_900"]],
  brand_map[["eig_blue_800"]],
  brand_map[["eig_green_500"]],
  brand_map[["eig_gold_600"]]
)

line_config <- Map(
  f = function(label, color_hex) list(name = label, color = color_hex, width = 2),
  label = c("Gen Z", "Millennials", "Gen X", "Boomers"),
  color_hex = eig_line_colors
)

DatawRappr::dw_data_to_chart(x = chart_df, chart_id = chart_id)
DatawRappr::dw_edit_chart(chart_id = chart_id, visualize = list(lines = line_config))
```

Governance requirements:
1. Publish manifests are required for all Datawrapper pipelines, including `palette_mode` and token version.
2. If legacy palettes are used, add required metadata and validate with:
`python3 scripts/compliance/check_legacy_metadata.py <metadata_json_path>`
3. CI must validate publish manifests with:
`python3 scripts/compliance/check_datawrapper_manifest.py <manifest_path>`
