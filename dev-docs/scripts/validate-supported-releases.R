# Opt-in full validation of every audited supported official REQ release.
#
# Official assets remain in the external cache argument and are never copied
# into the package. Only hashes, mappings and aggregate validation counts are
# written under dev-docs/evidence/legacy-validation.

args <- commandArgs(trailingOnly = TRUE)
cache_dir <- if (length(args)) args[[1]] else "/tmp/readreq-supported-cache"
for (file in list.files("R", full.names = TRUE)) source(file)
options(readreq.workers = 1L)

releases <- suppressWarnings(list_req_releases(
  refresh = TRUE, supported_only = TRUE, cache_dir = cache_dir
))
stopifnot(nrow(releases) == 9L, !"req-2026-03" %in% releases$release_id)

summary_rows <- list()
mapping_rows <- list()
count_rows <- list()
for (i in seq_len(nrow(releases))) {
  release <- releases[i, , drop = FALSE]
  id <- release$release_id[[1]]
  message("Validating ", id)
  result <- tryCatch({
    manifest <- download_req_release(
      release, assets = c("forecast", "historical", "report"),
      cache_dir = cache_dir, verify = TRUE
    )
    parsed <- list()
    maps <- list()
    for (asset in c("forecast", "historical")) {
      row <- manifest[manifest$asset_type == asset, , drop = FALSE]
      parsed[[asset]] <- req_parse_workbook(
        row$local_path[[1]], asset,
        list(release_id = id, release_date = release$release_date[[1]]),
        retrieved_at = row$retrieved_at[[1]], sha256 = row$sha256[[1]]
      )
      maps[[asset]] <- attr(parsed[[asset]], "sheet_mapping")
      maps[[asset]]$release_id <- id
      maps[[asset]]$source_dataset <- asset
      count <- aggregate(
        list(observations = rep(1L, nrow(parsed[[asset]]))),
        parsed[[asset]][c("table_id")], sum
      )
      count$series <- vapply(count$table_id, function(table_id) {
        length(unique(parsed[[asset]]$series_id[
          parsed[[asset]]$table_id == table_id
        ]))
      }, integer(1))
      count$release_id <- id
      count$source_dataset <- asset
      count_rows[[length(count_rows) + 1L]] <- count
    }
    all_data <- rbind(parsed$forecast, parsed$historical)
    current <- req_stitch_current(all_data)
    conflicts <- attr(current, "conflicts")
    validation <- req_validation_artifact(parsed, maps)
    hashes <- setNames(manifest$sha256, manifest$asset_type)
    bytes <- setNames(manifest$bytes, manifest$asset_type)
    mapping_rows[[length(mapping_rows) + 1L]] <- do.call(rbind, maps)
    data.frame(
      release_id = id,
      release_date = as.character(release$release_date[[1]]),
      edition = release$edition[[1]],
      support_status = release$support_status[[1]],
      landing_url = release$landing_url[[1]],
      forecast_sha256 = hashes[["forecast"]],
      historical_sha256 = hashes[["historical"]],
      report_sha256 = hashes[["report"]],
      forecast_bytes = bytes[["forecast"]],
      historical_bytes = bytes[["historical"]],
      report_bytes = bytes[["report"]],
      forecast_sheets = length(readxl::excel_sheets(
        manifest$local_path[manifest$asset_type == "forecast"]
      )),
      historical_sheets = length(readxl::excel_sheets(
        manifest$local_path[manifest$asset_type == "historical"]
      )),
      forecast_rows = nrow(parsed$forecast),
      historical_rows = nrow(parsed$historical),
      forecast_series = length(unique(parsed$forecast$series_id)),
      historical_series = length(unique(parsed$historical$series_id)),
      current_conflict_rows = nrow(conflicts),
      duplicate_observation_keys =
        validation$duplicate_observation_key_count,
      unresolved_duplicate_observation_keys =
        validation$unresolved_duplicate_observation_key_count,
      unknown_units = nrow(validation$unknown_units),
      unknown_currencies = nrow(validation$unknown_currencies),
      unknown_statuses = nrow(validation$unknown_statuses),
      unparsed_nonempty_cells =
        sum(validation$unparsed_nonempty_cells$unparsed_nonempty_cells),
      structural_breaks = nrow(validation$structural_breaks),
      validation_status = validation$validation_status,
      error = if (validation$valid) {
        NA_character_
      } else {
        paste(validation$failure_reasons, collapse = ";")
      },
      stringsAsFactors = FALSE
    )
  }, error = function(e) {
    data.frame(
      release_id = id,
      release_date = as.character(release$release_date[[1]]),
      edition = release$edition[[1]],
      support_status = release$support_status[[1]],
      landing_url = release$landing_url[[1]],
      forecast_sha256 = NA_character_,
      historical_sha256 = NA_character_,
      report_sha256 = NA_character_,
      forecast_bytes = NA_real_,
      historical_bytes = NA_real_,
      report_bytes = NA_real_,
      forecast_sheets = NA_integer_,
      historical_sheets = NA_integer_,
      forecast_rows = NA_integer_,
      historical_rows = NA_integer_,
      forecast_series = NA_integer_,
      historical_series = NA_integer_,
      current_conflict_rows = NA_integer_,
      duplicate_observation_keys = NA_integer_,
      unresolved_duplicate_observation_keys = NA_integer_,
      unknown_units = NA_integer_,
      unknown_currencies = NA_integer_,
      unknown_statuses = NA_integer_,
      unparsed_nonempty_cells = NA_integer_,
      structural_breaks = NA_integer_,
      validation_status = "failed",
      error = conditionMessage(e),
      stringsAsFactors = FALSE
    )
  })
  summary_rows[[length(summary_rows) + 1L]] <- result
}

summary <- do.call(rbind, summary_rows)
mappings <- if (length(mapping_rows)) do.call(rbind, mapping_rows) else data.frame()
counts <- if (length(count_rows)) do.call(rbind, count_rows) else data.frame()
evidence_dir <- "dev-docs/evidence/legacy-validation"
dir.create(evidence_dir, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(
  summary,
  file.path(evidence_dir, "supported-release-validation.csv"),
  row.names = FALSE
)
utils::write.csv(
  mappings,
  file.path(evidence_dir, "supported-release-sheet-mapping.csv"),
  row.names = FALSE
)
utils::write.csv(
  counts,
  file.path(evidence_dir, "supported-release-table-counts.csv"),
  row.names = FALSE
)
print(summary, row.names = FALSE)
