#!/usr/bin/env Rscript

# Regenerate the README and Getting Started chart from the exact March 2024,
# March 2025 and June 2026 official forecast workbooks plus the June 2026
# historical workbook. This maintainer script may download the sources into
# readreq's user cache; documentation rendering itself stays offline.

if (!identical(tolower(Sys.getenv("READREQ_LIVE_DOCS")), "true")) {
  stop(
    "Set READREQ_LIVE_DOCS=true to regenerate the official-data chart",
    call. = FALSE
  )
}

if (!requireNamespace("pkgload", quietly = TRUE) ||
    !requireNamespace("ggplot2", quietly = TRUE)) {
  stop("pkgload and ggplot2 are required to regenerate the chart", call. = FALSE)
}

pkgload::load_all(".", quiet = TRUE)

chart_cache <- Sys.getenv("READREQ_DOCS_CACHE", unset = req_cache_dir())
vintage_ids <- c("req-2024-03", "req-2025-03", "req-2026-06")
vintage_labels <- setNames(
  c("REQ March 2024", "REQ March 2025", "REQ June 2026"),
  vintage_ids
)

history <- read_req_history(
  "req-2026-06",
  tables = "history_commodity_iron_ore_steel",
  commodities = "iron_ore_steel",
  concepts = "exports_quantity_iron_ore_b_total_iron_ore",
  geography = "Australia",
  frequency = "quarterly",
  view = "canonical",
  cache_dir = chart_cache
)

expected_source_hashes <- c(
  "req-2024-03" =
    "27a759024b426c95bf37adc800d4524260d7bd3e56a9883c0328b6c4c0f7cbb5",
  "req-2025-03" =
    "5ae27bcedae6f58f39c2b4cda175dcf01a29667b8522d57f50dda6f48880d2c6",
  "req-2026-06" =
    "011d09f15d401830845bf9abf13b3bd2e0baf4bc95ea647bdd03246fe83b01fa",
  "req-2026-06-history" =
    "d78ba67562f90fd42a137910ed4839aa259a29290ea609b406abe94455ccfc77"
)
stopifnot(
  nrow(history) == 145L,
  identical(unique(history$unit), "kt"),
  identical(
    unique(history$sha256),
    unname(expected_source_hashes[["req-2026-06-history"]])
  )
)

history <- history[
  !is.na(history$value), c("period_start", "period", "value")
]
history$value <- history$value / 1000
history$series <- "Historical"

forecast_rows <- c(
  "req-2024-03" = 22L,
  "req-2025-03" = 25L,
  "req-2026-06" = 25L
)
forecasts <- do.call(rbind, lapply(vintage_ids, function(id) {
  x <- read_req_forecasts(
    id,
    sheets = "forecast_quarterly_export_volumes",
    commodities = "iron_ore",
    concepts = "export_volume",
    geography = "Australia",
    view = "canonical",
    cache_dir = chart_cache
  )
  stopifnot(
    nrow(x) == forecast_rows[[id]],
    identical(unique(x$unit), "Mt"),
    identical(unique(x$sha256), unname(expected_source_hashes[[id]]))
  )
  x <- x[
    !is.na(x$value) & x$period_status %in% c("forecast", "projection"),
    c("period_start", "period", "value")
  ]
  x$series <- vintage_labels[[id]]
  x
}))

chart_data <- rbind(history, forecasts)
chart_data <- chart_data[
  order(chart_data$series, chart_data$period_start), , drop = FALSE
]
chart_data$series <- factor(
  chart_data$series, levels = c("Historical", unname(vintage_labels))
)
stopifnot(
  nrow(history) == 145L,
  identical(range(history$period), c("1990-Q1", "2026-Q1")),
  nrow(forecasts) == 68L,
  identical(
    as.integer(table(forecasts$series)[unname(vintage_labels)]),
    c(22L, 24L, 22L)
  )
)

chart <- ggplot2::ggplot(
  chart_data,
  ggplot2::aes(
    x = period_start, y = value, colour = series, group = series
  )
) +
  ggplot2::geom_line() +
  ggplot2::labs(
    title = "Australian iron ore export volumes",
    subtitle = "Quarterly history and REQ forecast vintages",
    x = "Quarter",
    y = "Million tonnes",
    colour = "Series",
    caption = "Sources: DISR REQ; ABS Cat. No. 5368.0"
  ) +
  ggplot2::theme_minimal(base_size = 13) +
  ggplot2::theme(
    plot.margin = ggplot2::margin(t = 5.5, r = 28, b = 5.5, l = 5.5)
  )

ggplot2::ggsave(
  filename = file.path("man", "figures", "time-series-chart-1.png"),
  plot = chart,
  width = 7.2,
  height = 4.2,
  units = "in",
  dpi = 144,
  bg = "white"
)
