# EIG plotting/table theme helpers for R.

eig_load_tokens <- function(path = "themes/r/eig_tokens.R") {
  if (!file.exists(path)) {
    stop("Token file not found: ", path, call. = FALSE)
  }
  env <- new.env(parent = baseenv())
  sys.source(path, envir = env)
  env
}

eig_assert_fonts <- function(tokens = NULL, allow_fallback = FALSE) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  if (requireNamespace("systemfonts", quietly = TRUE)) {
    available <- unique(systemfonts::system_fonts()$family)
  } else {
    fc <- suppressWarnings(system("fc-list : family", intern = TRUE))
    if (length(fc) == 0) {
      stop(
        "Unable to enumerate system fonts (install 'systemfonts' or provide fontconfig).",
        call. = FALSE
      )
    }
    parts <- trimws(unlist(strsplit(fc, ",")))
    available <- unique(parts[nchar(parts) > 0])
  }
  headline_primary <- tokens$EIG_FONT_HEADLINE_PRIMARY
  body_primary <- tokens$EIG_FONT_BODY_PRIMARY

  if (!allow_fallback) {
    missing <- c()
    # Treat Source Serif 4 as strict-equivalent for Source Serif Pro in modern installs.
    headline_ok <- headline_primary %in% available ||
      (identical(headline_primary, "Source Serif Pro") && "Source Serif 4" %in% available)
    if (!headline_ok) missing <- c(missing, headline_primary)
    # macOS variable-font installs may expose Open Sans as "OpenSans".
    body_ok <- body_primary %in% available ||
      (identical(body_primary, "Open Sans") && "OpenSans" %in% available)
    if (!body_ok) missing <- c(missing, body_primary)
    if (length(missing) > 0) {
      stop(
        "Missing required EIG primary fonts: ",
        paste(missing, collapse = ", "),
        ". Run scripts/fonts installers and restart session.",
        call. = FALSE
      )
    }
    return(invisible(TRUE))
  }

  headline_stack <- c(headline_primary, "Source Serif 4", "Source Serif 3", "Georgia", "Times New Roman")
  body_stack <- c(body_primary, "Arial", "Helvetica Neue", "Helvetica")
  if (!any(headline_stack %in% available)) stop("No valid headline font available.", call. = FALSE)
  if (!any(body_stack %in% available)) stop("No valid body font available.", call. = FALSE)
  invisible(TRUE)
}

eig_theme_ggplot <- function(tokens = NULL, base_size = 10) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required.", call. = FALSE)
  }

  ggplot2::theme_minimal(base_size = base_size, base_family = tokens$EIG_FONT_BODY_PRIMARY) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(
        family = tokens$EIG_FONT_HEADLINE_PRIMARY,
        face = "bold",
        size = base_size * 1.5,
        color = tokens$EIG_COLORS[["eig_black"]],
        hjust = 0
      ),
      plot.subtitle = ggplot2::element_text(
        family = tokens$EIG_FONT_BODY_PRIMARY,
        face = "bold",
        size = base_size * 1.1,
        color = tokens$EIG_COLORS[["eig_teal_900"]],
        hjust = 0
      ),
      axis.title = ggplot2::element_text(face = "bold", color = tokens$EIG_COLORS[["eig_black"]]),
      axis.text = ggplot2::element_text(color = tokens$EIG_COLORS[["eig_black"]]),
      legend.title = ggplot2::element_text(face = "bold"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      panel.grid.major.y = ggplot2::element_line(color = "#D9D9D9", linewidth = 0.3),
      plot.background = ggplot2::element_rect(fill = "white", color = NA),
      panel.background = ggplot2::element_rect(fill = "white", color = NA),
      plot.caption = ggplot2::element_text(size = base_size * 0.8, color = "#444444", hjust = 0)
    )
}

eig_scale_color <- function(tokens = NULL, ...) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required.", call. = FALSE)
  }
  ggplot2::scale_color_manual(values = tokens$EIG_DISCRETE, ...)
}

eig_scale_fill <- function(tokens = NULL, ...) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required.", call. = FALSE)
  }
  ggplot2::scale_fill_manual(values = tokens$EIG_DISCRETE, ...)
}

eig_scale_fill_seq <- function(which = c("eig_seq_blue_5", "eig_seq_red_5"), tokens = NULL, ...) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  if (!requireNamespace("ggplot2", quietly = TRUE)) {
    stop("Package 'ggplot2' is required.", call. = FALSE)
  }
  which <- match.arg(which)
  cols <- unname(unlist(tokens$EIG_SEQUENTIAL[[which]]))
  ggplot2::scale_fill_gradientn(colors = cols, ...)
}

eig_base_defaults <- function(tokens = NULL) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  old <- graphics::par(
    family = tokens$EIG_FONT_BODY_PRIMARY,
    bg = "white",
    fg = tokens$EIG_COLORS[["eig_black"]],
    col.axis = tokens$EIG_COLORS[["eig_black"]],
    col.lab = tokens$EIG_COLORS[["eig_black"]],
    las = 1,
    bty = "l"
  )
  invisible(old)
}

eig_plotly_layout <- function(tokens = NULL) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  list(
    font = list(family = tokens$EIG_FONT_BODY_PRIMARY, size = 11, color = tokens$EIG_COLORS[["eig_black"]]),
    title = list(font = list(family = tokens$EIG_FONT_HEADLINE_PRIMARY, size = 20, color = tokens$EIG_COLORS[["eig_black"]])),
    paper_bgcolor = tokens$EIG_COLORS[["eig_white"]],
    plot_bgcolor = tokens$EIG_COLORS[["eig_white"]],
    colorway = unname(unlist(tokens$EIG_DISCRETE)),
    xaxis = list(showgrid = FALSE, zeroline = FALSE),
    yaxis = list(showgrid = TRUE, gridcolor = "#D9D9D9", zeroline = FALSE)
  )
}

eig_style_gt <- function(gt_tbl, tokens = NULL) {
  if (is.null(tokens)) tokens <- eig_load_tokens()
  if (!requireNamespace("gt", quietly = TRUE)) {
    stop("Package 'gt' is required.", call. = FALSE)
  }

  gt_tbl |>
    gt::tab_options(
      table.border.top.width = gt::px(0),
      table.border.bottom.width = gt::px(0),
      heading.border.bottom.width = gt::px(0),
      column_labels.border.top.width = gt::px(0),
      column_labels.border.bottom.color = "#D9D9D9",
      table_body.hlines.color = "#E6E6E6",
      table_body.hlines.width = gt::px(1)
    ) |>
    gt::tab_style(
      style = list(
        gt::cell_fill(color = tokens$EIG_COLORS[["eig_teal_900"]]),
        gt::cell_text(color = "white", weight = "bold", font = tokens$EIG_FONT_BODY_PRIMARY)
      ),
      locations = gt::cells_column_labels(columns = gt::everything())
    )
}
