# Measure cold parse and aggregate process-tree RSS for safe worker defaults.

args <- commandArgs(trailingOnly = TRUE)
historical <- if (length(args)) args[[1]] else "/tmp/readreq_june2026_historical.xlsx"
stopifnot(file.exists(historical))
for (file in list.files("R", full.names = TRUE)) source(file)
meta <- list(release_id = "req-2026-06", release_date = as.Date("2026-06-30"))

tree_rss <- function(pid) {
  root <- tryCatch(ps::ps_handle(pid), error = function(e) NULL)
  if (is.null(root)) return(0)
  handles <- c(list(root), ps::ps_children(root, recursive = TRUE))
  sum(vapply(handles, function(handle) {
    tryCatch(unname(ps::ps_memory_info(handle)[["rss"]]), error = function(e) 0)
  }, numeric(1)))
}

run <- function(workers) {
  gc()
  started <- proc.time()[["elapsed"]]
  job <- parallel::mcparallel({
    Sys.sleep(0.5)
    options(readreq.workers = workers)
    req_parse_workbook(historical, "historical", meta)
  })
  Sys.sleep(0.1)
  baseline <- tree_rss(job$pid)
  peak <- baseline
  repeat {
    peak <- max(peak, tree_rss(job$pid))
    collected <- parallel::mccollect(job, wait = FALSE)
    if (!is.null(collected)) break
    Sys.sleep(0.05)
  }
  data.frame(
    workers = workers,
    cold_seconds = proc.time()[["elapsed"]] - started - 0.5,
    peak_rss_delta_mib = max(0, peak - baseline) / 1024^2,
    rows = nrow(collected[[1]]),
    stringsAsFactors = FALSE
  )
}

report <- do.call(rbind, lapply(c(1L, 2L), run))
print(report, row.names = FALSE)
evidence_dir <- "dev-docs/evidence/legacy-validation"
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  report,
  file.path(evidence_dir, "worker-tradeoff.csv"),
  row.names = FALSE
)
