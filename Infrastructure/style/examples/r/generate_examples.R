#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
if (length(file_arg) == 0) {
  stop("Cannot resolve script path.", call. = FALSE)
}

script_path <- sub("^--file=", "", file_arg[1])
script_path <- normalizePath(script_path, mustWork = FALSE)
repo_root <- normalizePath(file.path(dirname(script_path), "..", ".."), mustWork = FALSE)

source(file.path(repo_root, "themes", "r", "eig_theme.R"))
tokens <- eig_load_tokens(file.path(repo_root, "themes", "r", "eig_tokens.R"))
eig_assert_fonts(tokens, allow_fallback = TRUE)

out_dir <- file.path(repo_root, "examples", "outputs", "r")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

set.seed(42)
n <- 140
weight <- pmax(pmin(rnorm(n, mean = 3.1, sd = 0.65), 5.7), 1.5)
cyl <- sample(c(4, 6, 8), n, replace = TRUE, prob = c(0.4, 0.35, 0.25))
origin <- sample(c("Domestic", "Foreign"), n, replace = TRUE, prob = c(0.58, 0.42))
mpg <- 41.5 - 5.0 * weight - 0.75 * (cyl - 4) + rnorm(n, sd = 2.1)
df <- data.frame(weight = weight, mpg = mpg, cyl = factor(cyl), origin = factor(origin))

old_par <- eig_base_defaults(tokens)
png(file.path(out_dir, "base_scatter.png"), width = 1400, height = 900, res = 180)
plot(
  df$weight,
  df$mpg,
  pch = 16,
  col = tokens$EIG_COLORS[["eig_teal_900"]],
  xlab = "Weight",
  ylab = "MPG",
  main = "Fuel Economy by Vehicle Weight"
)
dev.off()
par(old_par)

if (requireNamespace("ggplot2", quietly = TRUE)) {
  p <- ggplot2::ggplot(df, ggplot2::aes(weight, mpg, color = cyl)) +
    ggplot2::geom_point(size = 2.1, alpha = 0.9) +
    eig_scale_color(tokens = tokens, name = "Cylinders") +
    ggplot2::labs(
      title = "Fuel Economy by Vehicle Weight",
      subtitle = "EIG token-driven ggplot example",
      caption = "Synthetic example data"
    ) +
    eig_theme_ggplot(tokens = tokens)

  ggplot2::ggsave(
    filename = file.path(out_dir, "ggplot_scatter.png"),
    plot = p,
    width = tokens$EIG_FIGURE_DEFAULT_WIDTH_IN,
    height = tokens$EIG_FIGURE_DEFAULT_HEIGHT_IN,
    dpi = 220
  )
}

if (requireNamespace("plotly", quietly = TRUE) && requireNamespace("htmlwidgets", quietly = TRUE)) {
  p_int <- plotly::plot_ly(
    data = df,
    x = ~weight,
    y = ~mpg,
    color = ~cyl,
    colors = unname(tokens$EIG_DISCRETE),
    type = "scatter",
    mode = "markers"
  )
  layout_cfg <- eig_plotly_layout(tokens = tokens)
  p_int <- plotly::layout(
    p_int,
    title = "Fuel Economy by Vehicle Weight (Interactive)",
    xaxis = modifyList(layout_cfg$xaxis, list(title = "Weight")),
    yaxis = modifyList(layout_cfg$yaxis, list(title = "MPG")),
    font = layout_cfg$font,
    paper_bgcolor = layout_cfg$paper_bgcolor,
    plot_bgcolor = layout_cfg$plot_bgcolor,
    colorway = layout_cfg$colorway
  )
  htmlwidgets::saveWidget(
    p_int,
    file = file.path(out_dir, "plotly_scatter.html"),
    selfcontained = FALSE
  )
}

if (requireNamespace("gt", quietly = TRUE)) {
  summary_tbl <- aggregate(cbind(mpg, weight) ~ cyl, data = df, FUN = mean)
  summary_tbl$mpg <- round(summary_tbl$mpg, 2)
  summary_tbl$weight <- round(summary_tbl$weight, 2)
  gt_tbl <- gt::gt(summary_tbl)
  gt_tbl <- eig_style_gt(gt_tbl, tokens = tokens)
  gt::gtsave(gt_tbl, filename = file.path(out_dir, "gt_table.html"))
}

cat("Wrote R example outputs to:", out_dir, "\n")
