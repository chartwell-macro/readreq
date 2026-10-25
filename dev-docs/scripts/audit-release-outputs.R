#!/usr/bin/env Rscript

# Development-only, serialized certification of every package-supported REQ
# edition. Each row is written immediately so an interrupted run remains an
# auditable progress artifact.

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop(
    "Usage: audit-release-outputs.R <cache-dir> <output-csv>",
    call. = FALSE
  )
}

cache_dir <- normalizePath(args[[1L]], mustWork = FALSE)
output_path <- normalizePath(args[[2L]], mustWork = FALSE)
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(output_path), recursive = TRUE, showWarnings = FALSE)

pkgload::load_all(".", quiet = TRUE)

catalogue <- list_req_releases()
catalogue <- catalogue[order(catalogue$release_date), , drop = FALSE]

empty_result <- function(release_id, surface, roles) {
  data.frame(
    release_id = release_id,
    surface = surface,
    asset_roles = paste(roles, collapse = ";"),
    asset_hashes = NA_character_,
    rows = NA_integer_,
    series = NA_integer_,
    tables = NA_integer_,
    output_sha256 = NA_character_,
    validation_valid = FALSE,
    validation_conflicts = NA_integer_,
    validation_unresolved_duplicates = NA_integer_,
    error_class = NA_character_,
    error_message = NA_character_,
    audited_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors = FALSE
  )
}

results <- list()
for (index in seq_len(nrow(catalogue))) {
  release_id <- catalogue$release_id[[index]]
  roles <- unique(c(
    req_logical_asset_roles(release_id, "forecast", cache_dir, FALSE),
    req_logical_asset_roles(release_id, "historical", cache_dir, FALSE)
  ))
  surface <- if (identical(roles, "report")) {
    "key_macroeconomic_assumptions"
  } else {
    "structured_workbook_tables"
  }
  result <- empty_result(release_id, surface, roles)
  tryCatch({
    validation <- validate_req_release(
      release_id,
      cache_dir = cache_dir,
      refresh = FALSE
    )
    output <- read_req(
      release_id,
      data = "all",
      view = "reported",
      cache_dir = cache_dir,
      refresh = FALSE
    )
    stable_output <- output
    stable_output$retrieved_at <- as.POSIXct(
      rep(NA_character_, nrow(stable_output)),
      tz = "UTC"
    )
    hashes <- validation$hashes[
      order(validation$hashes$source_dataset),
      ,
      drop = FALSE
    ]
    result$asset_hashes <- paste(
      paste(hashes$source_dataset, hashes$sha256, sep = "="),
      collapse = ";"
    )
    result$rows <- nrow(output)
    result$series <- length(unique(output$series_id))
    result$tables <- length(unique(output$table_id))
    result$output_sha256 <- digest::digest(
      stable_output,
      algo = "sha256",
      serialize = TRUE
    )
    result$validation_valid <- isTRUE(validation$valid)
    result$validation_conflicts <- validation$conflict_count
    result$validation_unresolved_duplicates <-
      validation$unresolved_duplicate_observation_key_count
    if (!isTRUE(validation$valid)) {
      result$error_class <- "req_validation_error"
      result$error_message <- paste(
        validation$failure_reasons,
        collapse = ";"
      )
    }
  }, error = function(error) {
    result$error_class <<- paste(class(error), collapse = ";")
    result$error_message <<- conditionMessage(error)
  })
  results[[index]] <- result
  utils::write.csv(
    do.call(rbind, results),
    output_path,
    row.names = FALSE,
    na = ""
  )
  message(
    sprintf(
      "[%02d/%02d] %s valid=%s rows=%s error=%s",
      index,
      nrow(catalogue),
      release_id,
      result$validation_valid,
      ifelse(is.na(result$rows), "NA", result$rows),
      ifelse(is.na(result$error_message), "", result$error_message)
    )
  )
}

audit <- do.call(rbind, results)
if (!all(audit$validation_valid) ||
    any(is.na(audit$rows) | audit$rows <= 0L) ||
    any(!is.na(audit$error_message) & nzchar(audit$error_message))) {
  quit(status = 1L)
}
