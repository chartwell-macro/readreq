# Benchmark a complete official REQ release without writing source workbooks.
#
# Usage:
# Rscript dev-docs/scripts/benchmark-release.R /path/forecast.xlsx /path/historical.xlsx

args <- commandArgs(trailingOnly = TRUE)
forecast <- if (length(args) >= 1L) args[[1]] else "/tmp/readreq_june2026_forecast.xlsx"
historical <- if (length(args) >= 2L) args[[2]] else "/tmp/readreq_june2026_historical.xlsx"
cache_dir <- if (length(args) >= 3L) args[[3]] else "/tmp/readreq-supported-cache"
stopifnot(file.exists(forecast), file.exists(historical))

for (file in list.files("R", full.names = TRUE)) source(file)
options(readreq.workers = 1L)
meta <- list(release_id = "req-2026-06", release_date = as.Date("2026-06-30"))

tree_rss <- function(pid) {
  root <- tryCatch(ps::ps_handle(pid), error = function(e) NULL)
  if (is.null(root)) return(0)
  handles <- c(list(root), ps::ps_children(root, recursive = TRUE))
  sum(vapply(handles, function(handle) {
    tryCatch(unname(ps::ps_memory_info(handle)[["rss"]]), error = function(e) 0)
  }, numeric(1)))
}

cold <- numeric(3)
peak_delta <- numeric(3)
last <- NULL
for (i in seq_len(3L)) {
  last <- NULL
  gc()
  started <- proc.time()[["elapsed"]]
  job <- parallel::mcparallel({
    Sys.sleep(0.5)
    req_parse_workbook(historical, "historical", meta)
  })
  Sys.sleep(0.1)
  baseline <- tree_rss(job$pid)
  peak <- baseline
  repeat {
    peak <- max(peak, tree_rss(job$pid))
    collected <- parallel::mccollect(job, wait = FALSE)
    if (!is.null(collected)) {
      last <- collected[[1]]
      break
    }
    Sys.sleep(0.05)
  }
  cold[[i]] <- proc.time()[["elapsed"]] - started - 0.5
  peak_delta[[i]] <- max(0, peak - baseline) / 1024^2
}

cache_file <- tempfile(fileext = ".rds")
saveRDS(last, cache_file, version = 3)
warm <- numeric(3)
for (i in seq_len(3L)) {
  gc()
  warm[[i]] <- system.time(readRDS(cache_file))[["elapsed"]]
}
forecast_time <- numeric(3)
last_forecast <- NULL
for (i in seq_len(3L)) {
  forecast_time[[i]] <- system.time({
    last_forecast <- req_parse_workbook(forecast, "forecast", meta)
  })[["elapsed"]]
}

# Seed the package's real parsed-cache layout with the benchmarked exact
# release, then time the public warm paths. Raw assets and discovery metadata
# must already exist in cache_dir; no network is permitted by these calls.
forecast_hash <- digest::digest(file = forecast, algo = "sha256")
historical_hash <- digest::digest(file = historical, algo = "sha256")
req_atomic_save_rds(
  last_forecast,
  file.path(
    cache_dir, "parsed", meta$release_id, .req_parser_version,
    forecast_hash, "forecast.rds"
  )
)
req_atomic_save_rds(
  last,
  file.path(
    cache_dir, "parsed", meta$release_id, .req_parser_version,
    historical_hash, "historical.rds"
  )
)
invisible(read_req_forecasts(
  meta$release_id, sheets = "forecast_commodity_sector",
  cache_dir = cache_dir
))
single_sheet_time <- replicate(3L, system.time(
  read_req_forecasts(
    meta$release_id, sheets = "forecast_commodity_sector",
    cache_dir = cache_dir
  )
)[["elapsed"]])
listing_time <- replicate(3L, system.time(
  list_req_releases(cache_dir = cache_dir, supported_only = TRUE)
)[["elapsed"]])
invisible(read_req(meta$release_id, view = "current", cache_dir = cache_dir))
current_time <- replicate(3L, system.time(
  read_req(meta$release_id, view = "current", cache_dir = cache_dir)
)[["elapsed"]])
invisible(req_series_catalog(meta$release_id, cache_dir = cache_dir))
catalogue_time <- replicate(3L, system.time(
  req_series_catalog(meta$release_id, cache_dir = cache_dir)
)[["elapsed"]])

summary_row <- function(name, x, unit) {
  data.frame(
    benchmark = name, min = min(x), median = stats::median(x), max = max(x),
    unit = unit, stringsAsFactors = FALSE
  )
}
report <- rbind(
  summary_row("complete_historical_cold", cold, "seconds"),
  summary_row("complete_forecast_cold", forecast_time, "seconds"),
  summary_row("single_sheet_parsed_cache_restore", single_sheet_time, "seconds"),
  summary_row("warm_release_listing", listing_time, "seconds"),
  summary_row("current_view_from_parsed_cache", current_time, "seconds"),
  summary_row("series_catalog_from_parsed_cache", catalogue_time, "seconds"),
  summary_row("historical_parsed_cache_restore", warm, "seconds"),
  summary_row("historical_peak_rss_delta", peak_delta, "MiB")
)
print(report, row.names = FALSE)
cat("historical_rows:", nrow(last), "\n")
cat("historical_series:", length(unique(last$series_id)), "\n")
cat("historical_sheets:", length(unique(last$source_sheet)), "\n")

evidence_dir <- "dev-docs/evidence/legacy-validation"
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  report,
  file.path(evidence_dir, "benchmark-summary.csv"),
  row.names = FALSE
)
writeLines(c(
  paste("historical_rows:", nrow(last)),
  paste("historical_series:", length(unique(last$series_id))),
  paste("historical_data_sheets:", length(unique(last$source_sheet)))
), file.path(evidence_dir, "benchmark-counts.txt"))
