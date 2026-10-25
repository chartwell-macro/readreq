req_about_text <- function(path) {
  sheets <- readxl::excel_sheets(path)
  about <- sheets[tolower(sheets) == "about"]
  if (!length(about)) return("")
  x <- readxl::read_excel(path, sheet = about[[1]], col_names = FALSE,
    .name_repair = "minimal"
  )
  paste(req_clean_text(unlist(x, use.names = FALSE)), collapse = " ")
}

req_internal_identity_warning <- function(path, release_id) {
  text <- req_about_text(path)
  expected <- sub("^req-", "", release_id)
  bits <- strsplit(expected, "-", fixed = TRUE)[[1]]
  if (length(bits) != 2L) return(NULL)
  month <- c(`03` = "March", `06` = "June", `09` = "September", `12` = "December")[[bits[[2]]]]
  identity <- paste(month, bits[[1]])
  if (nzchar(text) && !grepl(tolower(identity), tolower(text), fixed = TRUE)) {
    paste0("Internal About identity differs from official landing-page identity ", release_id, ".")
  } else {
    NULL
  }
}

req_validation_table <- function(x, field) {
  values <- x[[field]]
  values[is.na(values) | !nzchar(values)] <- "<missing>"
  if (!length(values)) {
    out <- data.frame(value = character(), count = integer())
    names(out)[[1]] <- field
    return(out)
  }
  out <- as.data.frame(table(values, useNA = "ifany"), stringsAsFactors = FALSE)
  names(out) <- c(field, "count")
  out[out$count > 0L, , drop = FALSE]
}

req_validation_cache_path <- function(cache_dir, release_id, hashes) {
  token <- digest::digest(
    paste(sort(paste(names(hashes), hashes, sep = "=")), collapse = "\u001f"),
    algo = "sha256", serialize = FALSE
  )
  file.path(
    cache_dir, "parsed", release_id, .req_parser_version,
    paste0("validation-", token, ".rds")
  )
}

req_validation_artifact <- function(parsed, mappings, warnings = character(),
                                    hashes = NULL, cache_path = NULL) {
  parsed <- lapply(parsed, req_within_workbook_view, view = "reported")
  data <- data.table::rbindlist(parsed, use.names = TRUE, fill = TRUE)
  data.table::setDF(data)
  mapping <- data.table::rbindlist(mappings, use.names = TRUE, fill = TRUE)
  data.table::setDF(mapping)
  diagnostics <- data.table::rbindlist(lapply(names(parsed), function(asset) {
    x <- parsed[[asset]]
    out <- attr(x, "parse_diagnostics")
    if (is.null(out)) return(data.frame())
    out$source_dataset <- asset
    out
  }), use.names = TRUE, fill = TRUE)
  data.table::setDF(diagnostics)
  if (!"period_cells" %in% names(diagnostics)) diagnostics$period_cells <- integer()
  if (!"parsed_cells" %in% names(diagnostics)) diagnostics$parsed_cells <- integer()
  if (!"control_cells" %in% names(diagnostics)) diagnostics$control_cells <- integer()
  diagnostics$unparsed_nonempty_cells <- pmax(
    0L,
    diagnostics$period_cells - diagnostics$parsed_cells -
      diagnostics$control_cells
  )
  unparsed <- diagnostics[
    diagnostics$unparsed_nonempty_cells > 0L, , drop = FALSE
  ]

  allowed_status <- c(
    "historical", "estimate", "forecast", "projection",
    "published-unclassified"
  )
  unknown_status <- req_validation_table(
    data[is.na(data$period_status) |
      !data$period_status %in% allowed_status, , drop = FALSE],
    "period_status"
  )
  unknown_unit <- req_validation_table(
    data[is.na(data$unit) | !nzchar(data$unit) |
      tolower(data$unit) %in% c("unknown", "unclassified"), , drop = FALSE],
    "unit"
  )
  unknown_currency <- req_validation_table(
    data[is.na(data$currency) | !nzchar(data$currency) |
      tolower(data$currency) %in% c("unknown", "unclassified"), , drop = FALSE],
    "currency"
  )

  duplicate_mask <- duplicated(data[c("release_id", "observation_key")]) |
    duplicated(data[c("release_id", "observation_key")], fromLast = TRUE)
  duplicates <- if (any(duplicate_mask)) {
    z <- data.table::as.data.table(data[duplicate_mask, , drop = FALSE])
    out <- z[, .(
      presentations = .N,
      distinct_values = data.table::uniqueN(paste(
        ifelse(is.na(value), "<missing>", format(value, digits = 17)),
        ifelse(is.na(missing_reason), "", missing_reason),
        sep = "\u001f"
      )),
      source_sheets = paste(sort(unique(source_sheet)), collapse = ";"),
      table_ids = paste(sort(unique(table_id)), collapse = ";"),
      resolved_by_policy = {
        reasons <- unique(ifelse(is.na(missing_reason), "", missing_reason))
        equivalent <- if (all(is.na(value))) {
          length(reasons) == 1L
        } else if (any(is.na(value)) || length(reasons) != 1L) {
          FALSE
        } else {
          diff(range(value)) <= 1e-10 * max(1, abs(value))
        }
        supporting_policy <- sum(record_role == "canonical") == 1L &&
          all(record_role %in% c("canonical", "supporting"))
        source_priority <- ifelse(
          period_status == "historical",
          source_dataset == "historical",
          source_dataset == "forecast"
        )
        source_priority_policy <- sum(source_priority) == 1L
        equivalent || supporting_policy || source_priority_policy
      }
    ), by = .(release_id, observation_key)]
    data.table::setDF(out)
    out
  } else {
    data.frame(
      release_id = character(), observation_key = character(),
      presentations = integer(), distinct_values = integer(),
      source_sheets = character(), table_ids = character(),
      resolved_by_policy = logical(),
      stringsAsFactors = FALSE
    )
  }

  current <- req_stitch_current(data)
  conflicts <- attr(current, "conflicts")
  if (is.null(conflicts)) conflicts <- data[FALSE, , drop = FALSE]

  period_ranges <- if (nrow(data)) {
    z <- data.table::as.data.table(data)
    out <- z[, .(
      first_period_start = min(period_start, na.rm = TRUE),
      last_period_end = max(period_end, na.rm = TRUE),
      first_period = period[which.min(period_start)][[1]],
      last_period = period[which.max(period_end)][[1]],
      observations = .N
    ), by = .(source_dataset, table_id, frequency)]
    data.table::setDF(out)
    out
  } else {
    data.frame()
  }
  series_counts <- if (nrow(data)) {
    z <- unique(data[c(
      "series_id", "source_dataset", "frequency", "period_status",
      "commodity", "concept"
    )])
    out <- stats::aggregate(
      list(series = rep(1L, nrow(z))),
      z[c(
        "source_dataset", "frequency", "period_status", "commodity", "concept"
      )],
      sum
    )
    out
  } else {
    data.frame()
  }

  structural <- list()
  for (asset in names(mappings)) {
    m <- mappings[[asset]]
    if (!nrow(m)) {
      structural[[length(structural) + 1L]] <- data.frame(
        source_dataset = asset, issue = "empty_mapping",
        detail = "The parser returned no audited table mapping.",
        stringsAsFactors = FALSE
      )
    }
    if (anyDuplicated(m$table_id)) {
      structural[[length(structural) + 1L]] <- data.frame(
        source_dataset = asset, issue = "duplicate_table_id",
        detail = paste(unique(m$table_id[duplicated(m$table_id)]), collapse = ";"),
        stringsAsFactors = FALSE
      )
    }
    bad_profile <- is.na(m$parser_family) | !nzchar(m$parser_family) |
      is.na(m$fingerprint) | !nzchar(m$fingerprint)
    if (any(bad_profile)) {
      structural[[length(structural) + 1L]] <- data.frame(
        source_dataset = asset, issue = "missing_structural_fingerprint",
        detail = paste(m$source_sheet[bad_profile], collapse = ";"),
        stringsAsFactors = FALSE
      )
    }
  }
  structural_breaks <- if (length(structural)) {
    do.call(rbind, structural)
  } else {
    data.frame(
      source_dataset = character(), issue = character(),
      detail = character(), stringsAsFactors = FALSE
    )
  }

  failure_reasons <- c(
    if (any(!duplicates$resolved_by_policy)) "duplicate_observation_keys",
    if (nrow(conflicts)) "current_view_conflicts",
    if (nrow(unparsed)) "unparsed_nonempty_cells",
    if (nrow(unknown_unit)) "unknown_units",
    if (nrow(unknown_currency)) "unknown_currencies",
    if (nrow(unknown_status)) "unknown_statuses",
    if (nrow(structural_breaks)) "structural_breaks"
  )
  valid <- !length(failure_reasons)
  report <- list(
    valid = valid,
    validation_status = if (valid) "valid" else "invalid",
    failure_reasons = failure_reasons,
    parser_version = .req_parser_version,
    release_id = unique(data$release_id),
    assets = names(parsed),
    actual_vs_recognised_sheets = mapping,
    sheet_mapping = mapping,
    parser_profiles = unique(mapping[c(
      "source_sheet", "table_id", "parser_family", "fingerprint", "markers"
    )]),
    row_counts = as.data.frame(table(data$source_dataset, data$table_id),
      stringsAsFactors = FALSE
    ),
    series_counts = series_counts,
    period_ranges = period_ranges,
    unknown_units = unknown_unit,
    unknown_currencies = unknown_currency,
    unknown_statuses = unknown_status,
    unparsed_nonempty_cells = unparsed,
    missing_markers = req_validation_table(data, "missing_reason"),
    duplicate_observation_keys = duplicates,
    duplicate_observation_key_count = nrow(duplicates),
    unresolved_duplicate_observation_key_count =
      sum(!duplicates$resolved_by_policy),
    conflicts = conflicts,
    conflict_count = nrow(conflicts),
    internal_metadata_discrepancies = warnings,
    structural_breaks = structural_breaks,
    hashes = if (is.null(hashes)) {
      unique(data[c("source_dataset", "sha256")])
    } else {
      hashes
    },
    source_parser_versions = unique(data[c(
      "source_dataset", "sha256", "parser_version"
    )]),
    parse_diagnostics = diagnostics,
    cache_path = cache_path
  )
  class(report) <- c("req_validation_report", "list")
  report
}

#' Validate an REQ release or local bundle
#'
#' Audits the selected Resources and Energy Quarterly (REQ) release for
#' structural, semantic, and provenance problems before downstream use. The
#' audit parses every selected data surface in the exact edition, checks sheet
#' mappings and parser fingerprints, counts recognised and unparsed cells,
#' checks units/currencies/statuses, and reports duplicate or conflicting
#' observation keys. It does not alter the source workbook or silently repair a
#' failed audit.
#'
#' `release` may be an exact `req-YYYY-MM` ID, `"latest"`, a readable local
#' workbook path, a one-row release-manifest data frame, or a named local
#' bundle. A bundle should name one or more recognised asset paths
#' (`forecast`, `historical`, `report`, `statistical`, `commodity`,
#' `historical_statistical`, or `historical_commodity`) and can include scalar
#' `release_id` and `release_date` metadata. For a single local path, the asset
#' role is inferred from its filename; a PDF is treated as a `report`.
#'
#' Exact IDs use the static catalogue; the default transport downloads missing
#' assets from the bundled HTTPS URLs unless a valid immutable raw/parsed cache
#' is available. A supplied manifest or `readreq.transport` hook can use a
#' controlled local or custom source. Local paths and a
#' complete cache make the audit deterministic and offline. Validation reports
#' are cached by release, source hashes, and parser version below `cache_dir`;
#' writes are atomic and caches are never pruned automatically. `refresh = TRUE`
#' refreshes/reparses source assets without deleting older raw snapshots. No
#' credentials are required.
#'
#' The two audited report fallbacks (`req-2011-12` and `req-2013-03`) invoke
#' Poppler's `pdftotext` executable when their PDFs are parsed. Install Poppler
#' and ensure `pdftotext` is on `PATH`, or supply the structured companion
#' workbook where one exists. Other changed or unsupported PDFs fail with a
#' structured parser condition rather than being guessed.
#'
#' @param release A length-one exact `req-YYYY-MM` release ID, `"latest"`, a
#'   readable local workbook path, a one-row release-manifest data frame, or a
#'   named local bundle. Bundle metadata is optional but explicit
#'   `release_id`/`release_date` values make local provenance reproducible.
#' @param cache_dir Root directory for raw, parsed, and validation caches. The
#'   default is [req_cache_dir()]. It must be writable when a cache artifact
#'   needs to be created.
#' @param refresh Logical scalar. If `TRUE`, refresh required official assets
#'   and rebuild the validation report; existing content-addressed raw files
#'   remain intact and no cache pruning occurs.
#' @return A named list with class `c("req_validation_report", "list")`. Its
#'   fields are `valid` (length-one logical), `validation_status` (`"valid"` or
#'   `"invalid"`), `failure_reasons` (character vector), `parser_version`
#'   (character scalar), `release_id` (character vector), `assets` (character
#'   vector), `actual_vs_recognised_sheets` and `sheet_mapping` (the same
#'   mapping data frame), `parser_profiles` (the recognised structural-profile
#'   data frame), `row_counts`, `series_counts`, and `period_ranges` (count and
#'   coverage data frames), `unknown_units`, `unknown_currencies`, and
#'   `unknown_statuses` (diagnostic data frames), `unparsed_nonempty_cells`
#'   (diagnostic data frame), `missing_markers` (a value/count data frame),
#'   `duplicate_observation_keys` (duplicate-key diagnostics),
#'   `duplicate_observation_key_count` and
#'   `unresolved_duplicate_observation_key_count` (integer-like counts),
#'   `conflicts` (current-view conflict rows), `conflict_count` (integer-like
#'   count), `internal_metadata_discrepancies` (character vector),
#'   `structural_breaks` (structural diagnostic data frame), `hashes` (a
#'   `source_dataset`/`sha256` data frame), `source_parser_versions` (a
#'   source/hash/parser-version data frame), `parse_diagnostics` (parser
#'   diagnostics), and `cache_path` (the validation RDS path under
#'   `cache_dir`). A
#'   report is valid exactly when `failure_reasons` is empty; a valid report
#'   can still contain informational missing-marker or metadata fields.
#' @section Conditions and side effects:
#' `req_release_discovery_error` identifies an unknown release or malformed
#' static catalogue; `req_asset_missing_error` identifies an edition with no
#' readable selected surface; `req_download_error` and
#' `req_asset_format_error` cover network/bytes failures; workbook parser
#' conditions include `req_workbook_schema_error`, `req_sheet_parse_error`,
#' `req_period_parse_error`, and `req_unit_conflict_error`; and
#' `req_validation_error` covers mixed release identities, cache integrity,
#' or permissions. A structural or semantic problem is normally represented
#' in an `invalid` report so callers can inspect diagnostics. The function
#' writes only under `cache_dir`, uses temporary files for report promotion,
#' and does not delete or automatically prune existing cache entries. Parsing
#' defaults to one worker; if `options(readreq.workers = n)` is used, keep
#' `n <= 2` for portable and CRAN-like runs.
#' @examples
#' forecast_file <- system.file(
#'   "extdata", "readreq-example-forecast.xlsx", package = "readreq"
#' )
#' if (nzchar(forecast_file)) {
#'   bundle <- list(
#'     forecast = forecast_file,
#'     release_id = "req-example",
#'     release_date = as.Date("2026-06-01")
#'   )
#'   validation_cache <- tempfile("readreq-example-validation-cache-")
#'   stopifnot(dir.create(validation_cache))
#'   audit <- validate_req_release(
#'     bundle,
#'     cache_dir = validation_cache
#'   )
#'   stopifnot(inherits(audit, "req_validation_report"))
#'   c(valid = audit$valid, status = audit$validation_status)
#' }
#' if (identical(Sys.getenv("READREQ_LIVE_EXAMPLES"), "true")) {
#'   live <- validate_req_release("req-2026-06")
#'   c(valid = live$valid, status = live$validation_status)
#' }
#' @export
validate_req_release <- function(
    release = "latest", cache_dir = req_cache_dir(), refresh = FALSE) {
  assets <- if (is.list(release) && !is.data.frame(release)) {
    intersect(
      c(
        "forecast", "historical", "report", "statistical", "commodity",
        "historical_statistical", "historical_commodity"
      ),
      names(release)
    )
  } else if (is.character(release) && length(release) == 1L && file.exists(release)) {
    name <- basename(release)
    if (grepl("\\.pdf$", name, ignore.case = TRUE)) {
      "report"
    } else if (grepl("historical.?commodity|hcommodity", name, ignore.case = TRUE)) {
      "historical_commodity"
    } else if (grepl("historical.?stat|hstats?", name, ignore.case = TRUE)) {
      "historical_statistical"
    } else if (grepl("commodity", name, ignore.case = TRUE)) {
      "commodity"
    } else if (grepl("stats?|statistical", name, ignore.case = TRUE)) {
      "statistical"
    } else if (grepl("histor", name, ignore.case = TRUE)) {
      "historical"
    } else {
      "forecast"
    }
  } else {
    unique(c(
      req_logical_asset_roles(
        release, "forecast", cache_dir, refresh = refresh
      ),
      req_logical_asset_roles(
        release, "historical", cache_dir, refresh = refresh
      )
    ))
  }
  if (!length(assets)) {
    req_abort(
      "req_asset_missing_error",
      "The selected REQ edition has no readable data assets.",
      remediation = "Inspect list_req_releases()$asset_roles."
    )
  }
  infos <- lapply(assets, function(asset) {
    req_asset_from_release(release, asset, cache_dir, refresh)
  })
  names(infos) <- assets
  release_ids <- unique(vapply(infos, function(info) {
    info$meta$release_id
  }, character(1)))
  if (length(release_ids) != 1L) {
    req_abort(
      "req_validation_error",
      "Validation assets do not share one release identity.",
      remediation = "Supply forecast and historical workbooks from one edition."
    )
  }
  asset_hashes <- vapply(infos, `[[`, character(1), "sha256")
  report_path <- req_validation_cache_path(
    cache_dir, release_ids[[1]], asset_hashes
  )
  if (!refresh && file.exists(report_path)) return(readRDS(report_path))

  parsed <- list()
  warnings <- character()
  mappings <- list()
  for (asset in assets) {
    info <- infos[[asset]]
    parsed[[asset]] <- req_read_asset(release, asset, "all", cache_dir, refresh)
    mappings[[asset]] <- attr(parsed[[asset]], "sheet_mapping")
    mappings[[asset]]$source_dataset <- asset
    if (!identical(asset, "report")) {
      w <- req_internal_identity_warning(info$path, info$meta$release_id)
      if (!is.null(w)) warnings <- c(warnings, w)
    }
  }
  report <- req_validation_artifact(
    parsed, mappings, warnings = warnings,
    hashes = data.frame(
      source_dataset = assets, sha256 = unname(asset_hashes),
      stringsAsFactors = FALSE
    ),
    cache_path = report_path
  )
  req_atomic_save_rds(report, report_path)
  report
}
