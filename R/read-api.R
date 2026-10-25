req_local_release_meta <- function(release, release_id = NULL, release_date = NULL) {
  if (!is.null(release_id) && !is.null(release_date)) {
    return(list(release_id = release_id, release_date = as.Date(release_date)))
  }
  text <- tolower(paste(unlist(release), collapse = " "))
  months <- c(
    march = "03", mar = "03", june = "06", jun = "06",
    september = "09", sep = "09", december = "12", dec = "12"
  )
  month <- names(months)[vapply(names(months), function(m) {
    grepl(m, text, fixed = TRUE)
  }, logical(1))]
  year <- regmatches(text, regexpr("20[0-9]{2}", text))
  if (!length(month) || !nzchar(year)) {
    return(list(
      release_id = release_id %||% "req-local",
      release_date = as.Date(release_date %||% "1970-01-01")
    ))
  }
  mm <- months[[month[[1]]]]
  list(
    release_id = paste0("req-", year, "-", mm),
    release_date = as.Date(sprintf("%s-%s-01", year, mm))
  )
}

`%||%` <- function(x, y) if (is.null(x) || !length(x) || is.na(x)) y else x

req_atomic_save_rds <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile("readreq-rds-", tmpdir = dirname(path))
  on.exit(unlink(tmp), add = TRUE)
  saveRDS(x, tmp, version = 3)
  if (!file.rename(tmp, path) && !file.exists(path)) {
    req_abort(
      "req_validation_error",
      "Could not atomically promote a parsed-cache artifact.",
      remediation = "Check cache-directory permissions and available space."
    )
  }
  invisible(path)
}

req_asset_from_release <- function(release, asset, cache_dir, refresh) {
  if (is.character(release) && length(release) == 1L && file.exists(release)) {
    return(list(
      path = normalizePath(release, mustWork = TRUE),
      meta = req_local_release_meta(release),
      retrieved_at = file.info(release)$mtime,
      sha256 = digest::digest(file = release, algo = "sha256")
    ))
  }
  if (is.list(release) && !is.data.frame(release) && !is.null(release[[asset]])) {
    path <- release[[asset]]
    if (!file.exists(path)) {
      req_abort(
        "req_asset_missing_error",
        paste0("Supplied local ", asset, " asset does not exist."),
        asset_type = asset,
        remediation = "Supply a readable local workbook path."
      )
    }
    return(list(
      path = normalizePath(path, mustWork = TRUE),
      meta = req_local_release_meta(
        release, release$release_id, release$release_date
      ),
      retrieved_at = file.info(path)$mtime,
      sha256 = digest::digest(file = path, algo = "sha256")
    ))
  }
  manifest <- download_req_release(
    release = release, assets = asset, cache_dir = cache_dir,
    refresh = refresh, verify = TRUE
  )
  row <- manifest[manifest$asset_type == asset, , drop = FALSE]
  if (nrow(row) != 1L || !file.exists(row$local_path[[1]])) {
    req_abort(
      "req_asset_missing_error",
      paste0("Downloaded release manifest has no usable ", asset, " asset."),
      asset_type = asset,
      remediation = "Refresh official discovery and retry the exact release."
    )
  }
  releases <- list_req_releases(cache_dir = cache_dir)
  rel <- releases[releases$release_id == row$release_id[[1]], , drop = FALSE]
  list(
    path = row$local_path[[1]],
    meta = list(
      release_id = row$release_id[[1]],
      release_date = as.Date(rel$release_date[[1]])
    ),
    retrieved_at = row$retrieved_at[[1]],
    sha256 = row$sha256[[1]]
  )
}

req_filter_observations <- function(x, commodities = NULL, concepts = NULL,
                                    geography = NULL, frequency = NULL) {
  keep <- rep(TRUE, nrow(x))
  if (!is.null(commodities)) keep <- keep & x$commodity %in% req_slug(commodities)
  if (!is.null(concepts)) {
    keep <- keep & (x$concept %in% req_slug(concepts) | x$concept %in% concepts)
  }
  if (!is.null(geography)) keep <- keep & x$geography %in% geography
  if (!is.null(frequency)) keep <- keep & x$frequency %in% frequency
  x[keep, , drop = FALSE]
}

req_within_workbook_view <- function(x, view = c("canonical", "reported")) {
  view <- match.arg(view)
  if (!nrow(x)) return(x)

  keys <- x$observation_key
  duplicated_key <- duplicated(keys) | duplicated(keys, fromLast = TRUE)
  x$record_role[
    is.na(x$record_role) |
      !x$record_role %in% c("canonical", "supporting")
  ] <- "canonical"
  if (!any(duplicated_key)) return(x)

  candidates <- data.table::as.data.table(x[duplicated_key, , drop = FALSE])
  candidates[, `.req_row` := which(duplicated_key)]
  candidates[, `.req_token` := paste(
    ifelse(is.na(value), "<missing>", format(value, digits = 17)),
    ifelse(is.na(missing_reason), "", missing_reason),
    sep = "\u001f"
  )]
  resolution <- candidates[, .(
    resolved = {
      reasons <- unique(ifelse(is.na(missing_reason), "", missing_reason))
      equivalent <- if (all(is.na(value))) {
        length(reasons) == 1L
      } else if (any(is.na(value)) || length(reasons) != 1L) {
        FALSE
      } else {
        spread <- diff(range(value))
        spread <= 1e-10 * max(1, abs(value))
      }
      supporting_policy <- sum(record_role == "canonical") == 1L &&
        all(record_role %in% c("canonical", "supporting"))
      equivalent || supporting_policy
    },
    reason = {
      if (sum(record_role == "canonical") == 1L &&
          all(record_role %in% c("canonical", "supporting")) &&
          any(record_role == "supporting")) {
        "reviewed redundant source-unit presentation"
      } else {
        "identical within-workbook presentation"
      }
    }
  ), by = observation_key]
  ambiguous <- resolution[resolved == FALSE]
  if (nrow(ambiguous)) {
    if (view == "reported") {
      attr(x, "canonical_conflicts") <- as.data.frame(ambiguous)
      return(x)
    }
    req_abort(
      "req_stitch_conflict_error",
      paste0(
        "Within-workbook canonical selection found ",
        nrow(ambiguous),
        " observation key(s) with conflicting published values."
      ),
      series_id = x$series_id[
        match(ambiguous$observation_key[[1]], x$observation_key)
      ],
      remediation = paste0(
        "Use view = 'reported' to inspect every presentation, then add a ",
        "reviewed precedence rule or correct the semantic mapping."
      )
    )
  }

  data.table::setorder(
    candidates, observation_key, record_role, table_id, source_sheet,
    raw_value, .req_row
  )
  supporting <- candidates[, .req_row[-1L], by = observation_key][["V1"]]
  x$record_role[supporting] <- "supporting"
  selection <- data.frame(
    observation_key = resolution$observation_key,
    presentations = candidates[, .N, by = observation_key][["N"]],
    policy_version = "1",
    reason = resolution$reason,
    stringsAsFactors = FALSE
  )
  attr(x, "canonical_selection") <- selection
  if (view == "reported") return(x)
  out <- x[x$record_role == "canonical", , drop = FALSE]
  attr(out, "canonical_selection") <- selection
  rownames(out) <- NULL
  out
}

req_read_asset <- function(release, asset, selection, cache_dir, refresh) {
  info <- req_asset_from_release(release, asset, cache_dir, refresh)
  cache_name <- if (identical(selection, "all")) {
    paste0(asset, ".rds")
  } else {
    selection_key <- digest::digest(
      paste(sort(unique(as.character(selection))), collapse = "\u001f"),
      algo = "sha256", serialize = FALSE
    )
    paste0(asset, "-selection-", selection_key, ".rds")
  }
  cache_file <- file.path(
    cache_dir, "parsed", info$meta$release_id, .req_parser_version,
    info$sha256, cache_name
  )
  if (!refresh && file.exists(cache_file)) {
    return(readRDS(cache_file))
  }
  out <- if (identical(asset, "report")) {
    req_parse_report_table(
      info$path, info$meta,
      retrieved_at = info$retrieved_at, sha256 = info$sha256,
      sheets = selection
    )
  } else {
    req_parse_workbook(
      info$path, asset, info$meta,
      retrieved_at = info$retrieved_at, sha256 = info$sha256,
      sheets = selection
    )
  }
  req_atomic_save_rds(out, cache_file)
  out
}

req_release_row_for_read <- function(release, cache_dir, refresh = FALSE) {
  if (is.data.frame(release)) return(release)
  if (!is.character(release) || length(release) != 1L ||
      is.na(release) || file.exists(release)) {
    return(NULL)
  }
  releases <- list_req_releases(
    refresh = refresh,
    cache_dir = cache_dir
  )
  .req_resolve_release(release, releases)
}

req_release_data_roles <- function(release_row, logical_dataset) {
  available <- unlist(release_row$asset_roles[[1L]], use.names = FALSE)
  release_id <- release_row$release_id[[1L]]
  roles <- if (identical(logical_dataset, "forecast")) {
    c(
      intersect("forecast", available),
      intersect("commodity", available),
      if (identical(release_id, "req-2011-09")) {
        intersect("statistical", available)
      } else {
        character()
      }
    )
  } else {
    c(
      intersect("historical", available),
      if (!identical(release_id, "req-2011-09")) {
        intersect("statistical", available)
      } else {
        character()
      },
      intersect("historical_statistical", available),
      intersect("historical_commodity", available)
    )
  }
  if (!length(roles) && identical(logical_dataset, "forecast") &&
      "report" %in% available &&
      release_id %in% names(.req_report_fallback_hashes)) {
    roles <- "report"
  }
  unique(roles)
}

req_logical_asset_roles <- function(
    release, logical_dataset, cache_dir, refresh = FALSE) {
  if (is.character(release) && length(release) == 1L && file.exists(release)) {
    return(logical_dataset)
  }
  if (is.list(release) && !is.data.frame(release)) {
    release_id <- release$release_id %||% ""
    available <- names(release)[vapply(release, function(value) {
      is.character(value) && length(value) == 1L && file.exists(value)
    }, logical(1))]
    if (logical_dataset %in% available) return(logical_dataset)
    if (identical(logical_dataset, "forecast")) {
      roles <- intersect(
        c("forecast", "commodity", "statistical"),
        available
      )
      if (!length(roles) && "report" %in% available) roles <- "report"
    } else {
      roles <- intersect(
        c(
          "historical", "statistical",
          "historical_statistical", "historical_commodity"
        ),
        available
      )
      if (identical(release_id, "req-2011-09")) {
        roles <- setdiff(roles, "statistical")
      }
    }
    return(roles)
  }
  release_row <- req_release_row_for_read(release, cache_dir, refresh)
  req_release_data_roles(release_row, logical_dataset)
}

req_read_logical_assets <- function(
    release, logical_dataset, selection, cache_dir, refresh) {
  roles <- req_logical_asset_roles(
    release, logical_dataset, cache_dir, refresh
  )
  if (!length(roles)) {
    req_abort(
      "req_asset_missing_error",
      paste0(
        "The selected edition has no published ", logical_dataset,
        " data surface."
      ),
      asset_type = logical_dataset,
      remediation = "Use read_req(data = 'all') or inspect asset_roles."
    )
  }
  pieces <- lapply(roles, function(role) {
    req_read_asset(release, role, selection, cache_dir, refresh)
  })
  out <- data.table::rbindlist(pieces, use.names = TRUE, fill = TRUE)
  data.table::setDF(out)
  out
}

req_current_cache_descriptor <- function(
    release, data, cache_dir, refresh = FALSE) {
  assets <- unique(c(
    if (data %in% c("all", "forecast")) {
      req_logical_asset_roles(release, "forecast", cache_dir, refresh)
    } else {
      character()
    },
    if (data %in% c("all", "history")) {
      req_logical_asset_roles(release, "historical", cache_dir, refresh)
    } else {
      character()
    }
  ))
  if (!length(assets)) {
    req_abort(
      "req_asset_missing_error",
      "The selected REQ edition has no readable data assets.",
      remediation = "Inspect the edition's asset_roles."
    )
  }
  infos <- lapply(assets, function(asset) {
    req_asset_from_release(release, asset, cache_dir, refresh)
  })
  names(infos) <- assets
  release_ids <- unique(vapply(
    infos, function(info) info$meta$release_id, character(1)
  ))
  if (length(release_ids) != 1L) {
    req_abort(
      "req_validation_error",
      "Current-view assets do not belong to one release identity.",
      remediation = "Supply forecast and historical assets from one exact release."
    )
  }
  hashes <- vapply(infos, `[[`, character(1), "sha256")
  token <- digest::digest(
    paste(
      c(
        paste0("parser=", .req_parser_version),
        paste0("policy=", .req_current_policy_version),
        paste0("data=", data),
        paste(names(hashes), hashes, sep = "=")
      ),
      collapse = "\u001f"
    ),
    algo = "sha256", serialize = FALSE
  )
  list(
    release_id = release_ids[[1]],
    path = file.path(
      cache_dir, "parsed", release_ids[[1]], .req_parser_version,
      "current", paste0(token, ".rds")
    )
  )
}

#' Read REQ forecast observations
#'
#' Reads the forecast tables admitted for one Resources and Energy Quarterly
#' (REQ) edition and normalises them to the package's observation contract. An
#' exact catalogue ID such as `"req-2026-06"` is reproducible; `"latest"`
#' follows the latest edition in the checked-in catalogue. For deterministic
#' offline work, `release` can instead be a path to a local workbook or a
#' named local bundle containing a `forecast` path and, optionally, scalar
#' `release_id` and `release_date` metadata. Local paths are never uploaded.
#'
#' The default `view = "canonical"` resolves equivalent duplicates and reviewed
#' canonical/supporting presentations within a workbook and records the
#' selection policy. `view = "reported"` preserves every parsed source
#' presentation for audit and reconciliation. Unresolved duplicate values
#' raise `req_stitch_conflict_error` in canonical view; use reported view to
#' inspect every presentation.
#'
#' For a catalogue release ID, the package's default transport downloads the
#' bundled HTTPS asset URL when the requested raw asset is not already cached.
#' Local bundles and a caller-supplied `readreq.transport` hook can use other
#' controlled sources. No credentials are read or sent by the package. Parsed results are
#' cached below `cache_dir` using the source hash and parser version; cache
#' files are written atomically, are not pruned automatically, and can grow
#' until the user removes them explicitly. `refresh = TRUE` revalidates or
#' retrieves source data and rebuilds the parsed artifact without deleting
#' older immutable raw snapshots.
#'
#' @param release A length-one exact `req-YYYY-MM` release ID, `"latest"`, a
#'   one-row release manifest for a catalogued release, a readable local
#'   workbook path, or a named local bundle. A supplied manifest is used as
#'   supplied and can identify a local or custom asset URL. A bundle should
#'   contain `forecast`; optional `release_id` and `release_date` values make
#'   provenance explicit. If omitted for a local path, metadata is inferred
#'   from its name when possible and otherwise uses `req-local` and
#'   `1970-01-01`.
#' @param sheets Either `"all"` (the default), or a character vector of
#'   semantic table IDs, source sheet names, or their slugged forms. An error
#'   is raised if no requested table is found.
#' @param commodities Optional character vector of commodity labels. Matching
#'   uses the package's normalised labels; `NULL` keeps all commodities.
#' @param concepts Optional character vector of concept labels. Matching is
#'   tolerant of normalised labels and also accepts an exact stored label;
#'   `NULL` keeps all concepts.
#' @param geography Optional character vector matched to the stored semantic
#'   geography labels; `NULL` keeps all geographies.
#' @param view Either `"canonical"` (the default) or `"reported"`. The
#'   canonical view keeps one row per resolved within-workbook
#'   `observation_key`; the reported view keeps all presentations.
#' @param cache_dir Root directory for raw and parsed caches. The default is
#'   [req_cache_dir()]. It must be writable when a download or parse is needed.
#' @param refresh Logical scalar. If `TRUE`, do not reuse a parsed artifact
#'   and refresh the required official asset; existing content-addressed raw
#'   snapshots remain untouched.
#' @return A base `data.frame` with the fields returned by
#'   [req_observation_schema()], in this order:
#'   `product`, `release_id`, `release_date`, `dataset`, `source_dataset`,
#'   `source_asset`, `source_sheet`, `table_id`, `table_title`, `record_role`,
#'   `geography_type`, `geography`, `commodity`, `concept`, `period`,
#'   `period_start`, `period_end`, `period_basis`, `period_status`,
#'   `status_source`, `price_basis`, `currency`, `unit`, `value`, `raw_value`,
#'   `missing_reason`, `footnote_codes`, `source_note`, `series_id`,
#'   `observation_key`, `retrieved_at`, `sha256`, `parser_version`, `section`,
#'   and `frequency`. Character fields retain their source-normalised values;
#'   `release_date`, `period_start`, and `period_end` are `Date`, `value` is a
#'   numeric vector, `retrieved_at` is UTC `POSIXct`, and `footnote_codes` is a
#'   list-column of character vectors. In a resolved duplicate view,
#'   `canonical_selection` is a data frame with `observation_key`,
#'   `presentations`, `policy_version`, and `reason`; a reported view with
#'   unresolved duplicate values may instead carry `canonical_conflicts`.
#'   Row order follows parser/source order and the requested filters; it is not
#'   a promise of sorting by period.
#' @section Conditions and side effects:
#' Errors use readreq condition classes such as
#' `req_release_discovery_error`, `req_asset_missing_error`,
#' `req_download_error`, `req_asset_format_error`, `req_workbook_schema_error`,
#' `req_sheet_parse_error`, `req_period_parse_error`,
#' `req_unit_conflict_error`, `req_stitch_conflict_error`, and
#' `req_validation_error`. They identify unavailable or changed official
#' assets, malformed workbooks, semantic ambiguity, or cache/permission
#' failures. The default catalogue transport uses HTTPS with a bounded
#' timeout/retry policy; live availability is not required when an exact
#' immutable cache or local workbook is supplied. Parsing can use more than
#' one process only when the user sets `options(readreq.workers = n)`; the
#' default is one worker and no more than two workers should be configured in
#' constrained or CRAN-like environments. The two audited report fallbacks
#' (`req-2011-12` and `req-2013-03`) additionally require Poppler's
#' `pdftotext` executable on `PATH` when no structured workbook is available.
#' @examples
#' forecast_file <- system.file(
#'   "extdata", "readreq-example-forecast.xlsx", package = "readreq"
#' )
#' if (nzchar(forecast_file)) {
#'   forecast_cache <- tempfile("readreq-example-forecast-cache-")
#'   stopifnot(dir.create(forecast_cache))
#'   forecast <- read_req_forecasts(
#'     forecast_file,
#'     view = "canonical",
#'     cache_dir = forecast_cache
#'   )
#'   stopifnot(is.data.frame(forecast))
#'   forecast[c("release_id", "commodity", "period", "value")][1:3, ,
#'     drop = FALSE]
#' }
#' if (identical(Sys.getenv("READREQ_LIVE_EXAMPLES"), "true")) {
#'   live <- read_req_forecasts("req-2026-06", view = "reported")
#'   utils::head(live[c("series_id", "period", "value")])
#' }
#' @export
read_req_forecasts <- function(
    release = "latest", sheets = "all", commodities = NULL, concepts = NULL,
    geography = NULL, view = c("canonical", "reported"),
    cache_dir = req_cache_dir(), refresh = FALSE) {
  view <- match.arg(view)
  x <- req_read_logical_assets(
    release, "forecast", sheets, cache_dir, refresh
  )
  x <- req_within_workbook_view(x, view)
  req_filter_observations(x, commodities, concepts, geography)
}

#' Read REQ historical observations
#'
#' Reads the historical tables admitted for one REQ edition and returns the
#' same observation contract as [read_req_forecasts()]. The release forms,
#' cache behaviour, canonical/reported views, filters, condition classes, and
#' local-bundle metadata rules are the same as for the forecast reader. A
#' frequency filter is applied after parsing, so it never changes the source
#' `series_id` or period semantics.
#'
#' @param release A length-one exact `req-YYYY-MM` release ID, `"latest"`, a
#'   one-row release manifest for a catalogued release, a readable local
#'   workbook path, or a named local bundle. A supplied manifest is used as
#'   supplied and can identify a local or custom asset URL. A bundle should
#'   contain `historical`; optional `release_id` and `release_date` values make
#'   provenance explicit. If omitted for a local path, metadata is inferred
#'   from its name when possible and otherwise uses `req-local` and
#'   `1970-01-01`.
#' @param tables Either `"all"` (the default), or a character vector of
#'   semantic table IDs, source sheet names, or their slugged forms. An error
#'   is raised if no requested table is found.
#' @param commodities Optional character vector of commodity labels. Matching
#'   uses the package's normalised labels; `NULL` keeps all commodities.
#' @param concepts Optional character vector of concept labels. Matching is
#'   tolerant of normalised labels and also accepts an exact stored label;
#'   `NULL` keeps all concepts.
#' @param geography Optional character vector matched to the stored semantic
#'   geography labels; `NULL` keeps all geographies.
#' @param view Either `"canonical"` (the default) or `"reported"`. The
#'   canonical view keeps one row per resolved within-workbook
#'   `observation_key`; the reported view keeps all presentations.
#' @param cache_dir Root directory for raw and parsed caches. The default is
#'   [req_cache_dir()]. It must be writable when a download or parse is needed.
#' @param refresh Logical scalar. If `TRUE`, do not reuse a parsed artifact
#'   and refresh the required official asset; existing content-addressed raw
#'   snapshots remain untouched.
#' @param frequency Optional character vector containing one or more of
#'   `"annual"`, `"quarterly"`, and `"monthly"`; `NULL` keeps all recognised
#'   frequencies.
#' @return A base `data.frame` with the same 35 fields, types, row-order
#'   contract, and possible `canonical_selection`/`canonical_conflicts`
#'   attributes described for [read_req_forecasts()]. Historical rows retain
#'   their source `period_status`, `period_basis`, and `frequency`; missing
#'   values are represented by the documented `missing_reason` vocabulary.
#' @examples
#' history_file <- system.file(
#'   "extdata", "readreq-example-history.xlsx", package = "readreq"
#' )
#' if (nzchar(history_file)) {
#'   history_cache <- tempfile("readreq-example-history-cache-")
#'   stopifnot(dir.create(history_cache))
#'   history <- read_req_history(
#'     history_file,
#'     tables = "history_monthly_benchmark_prices",
#'     commodities = "synthetic_benchmark",
#'     concepts = "benchmark_price",
#'     geography = "Australia",
#'     frequency = "monthly",
#'     cache_dir = history_cache
#'   )
#'   stopifnot(is.data.frame(history))
#'   history[c("release_id", "period", "frequency", "value")][1:3, ,
#'     drop = FALSE]
#' }
#' if (identical(Sys.getenv("READREQ_LIVE_EXAMPLES"), "true")) {
#'   live <- read_req_history("req-2026-06", frequency = "monthly")
#'   utils::head(live[c("series_id", "period", "value")])
#' }
#' @export
read_req_history <- function(
    release = "latest", tables = "all", commodities = NULL, concepts = NULL,
    geography = NULL, frequency = NULL,
    view = c("canonical", "reported"),
    cache_dir = req_cache_dir(), refresh = FALSE) {
  view <- match.arg(view)
  x <- req_read_logical_assets(
    release, "historical", tables, cache_dir, refresh
  )
  x <- req_within_workbook_view(x, view)
  req_filter_observations(x, commodities, concepts, geography, frequency)
}

#' Read a coherent REQ release
#'
#' Reads the selected forecast and/or historical data surfaces for one REQ
#' edition and, by default, applies the package's versioned current-view
#' precedence policy. Use `view = "reported"` to retain source rows before
#' that cross-asset reconciliation. For reproducible offline examples, pass a
#' named local bundle with `forecast` and/or `historical` workbook paths plus
#' explicit `release_id` and `release_date` metadata.
#'
#' The `current` view ranks period status, source and record role and keeps
#' unresolved equal-priority disagreements as rows with `record_role =
#' "conflict"`; inspect the `conflicts` attribute before publishing derived
#' values. The `reported` view simply combines the requested asset surfaces and
#' does not apply that cross-asset policy.
#'
#' For catalogue release IDs, the default transport fetches the bundled HTTPS
#' asset URLs only when neither the raw nor parsed cache can satisfy the
#' request. A named local bundle or caller-supplied `readreq.transport` hook
#' can use another controlled source. No credentials are read or sent by the
#' package. Parsed/current
#' artifacts are keyed by source hashes, parser/policy versions and data
#' scope, written atomically, and never pruned automatically.
#' The legacy report fallbacks for `req-2011-12` and `req-2013-03` require
#' Poppler's `pdftotext` executable when a structured workbook is unavailable.
#'
#' @param release A length-one exact `req-YYYY-MM` release ID, `"latest"`, a
#'   one-row release manifest for a catalogued release, a readable local
#'   workbook path, or a named local bundle. A supplied manifest is used as
#'   supplied and can identify local or custom asset URLs. A bundle should
#'   contain one or both of `forecast` and `historical` paths and can contain
#'   scalar `release_id` and `release_date` metadata. With the default
#'   `data = "all"`, a single workbook path is attempted as both logical
#'   surfaces; select `data = "forecast"` or `"history"` when it represents
#'   only one surface.
#' @param data Which surfaces to read: one of `"all"` (the default),
#'   `"history"`, or `"forecast"`.
#' @param view Either `"current"` (the default, policy-resolved) or
#'   `"reported"` (source-faithful combined rows).
#' @param cache_dir Root directory for raw, parsed, and current-view caches;
#'   defaults to [req_cache_dir()]. It must be writable when work is not fully
#'   cached.
#' @param refresh Logical scalar. If `TRUE`, refresh required official assets
#'   and rebuild derived artifacts; existing immutable raw snapshots are not
#'   deleted.
#' @return A base `data.frame` with the 35 fields and scalar column types
#'   described for [read_req_forecasts()]. In a `current` result, `record_role`
#'   can additionally be `"conflict"` and the result carries a `conflicts`
#'   data frame (possibly zero rows) describing unresolved keys. The reported
#'   result preserves the combined source rows in asset/read order. Date and
#'   time columns, list-column footnotes, hashes, and semantic keys retain the
#'   observation contract; row names are reset after combining.
#' @section Conditions and side effects:
#' Errors include `req_release_discovery_error` when an exact ID is not in the
#' audited catalogue, `req_asset_missing_error` when the selected surface is
#' unavailable, `req_download_error`/`req_asset_format_error` for transport or
#' bytes that cannot be verified, and `req_validation_error` for mixed release
#' identities or cache failures. Workbook and semantic parser conditions from
#' the asset readers are propagated. The default parser worker count is one;
#' users who set `options(readreq.workers = n)` should keep `n <= 2` for
#' portable, resource-bounded runs. Cache directories can grow without
#' automatic pruning.
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
#'   current_cache <- tempfile("readreq-example-current-cache-")
#'   stopifnot(dir.create(current_cache))
#'   combined <- read_req(
#'     bundle,
#'     data = "forecast",
#'     view = "current",
#'     cache_dir = current_cache
#'   )
#'   stopifnot(is.data.frame(combined))
#'   utils::head(combined[c("dataset", "period", "period_status", "value")])
#' }
#' if (identical(Sys.getenv("READREQ_LIVE_EXAMPLES"), "true")) {
#'   live <- read_req("req-2026-06", data = "all", view = "current")
#'   utils::head(live[c("series_id", "period", "value")])
#' }
#' @export
read_req <- function(
    release = "latest", data = c("all", "history", "forecast"),
    view = c("current", "reported"), cache_dir = req_cache_dir(),
    refresh = FALSE) {
  data <- match.arg(data)
  view <- match.arg(view)
  current_cache <- NULL
  if (view == "current") {
    current_cache <- req_current_cache_descriptor(
      release, data, cache_dir, refresh
    )
    if (!refresh && file.exists(current_cache$path)) {
      return(readRDS(current_cache$path))
    }
  }
  pieces <- list()
  forecast_roles <- if (data %in% c("all", "forecast")) {
    req_logical_asset_roles(release, "forecast", cache_dir, refresh)
  } else {
    character()
  }
  history_roles <- if (data %in% c("all", "history")) {
    req_logical_asset_roles(release, "historical", cache_dir, refresh)
  } else {
    character()
  }
  if (length(forecast_roles)) {
    pieces$forecast <- read_req_forecasts(
      release, view = "reported", cache_dir = cache_dir, refresh = refresh
    )
  }
  if (length(history_roles)) {
    pieces$history <- read_req_history(
      release, view = "reported", cache_dir = cache_dir, refresh = refresh
    )
  }
  if (!length(pieces)) {
    req_abort(
      "req_asset_missing_error",
      "The selected REQ edition has no readable data surface.",
      remediation = "Inspect list_req_releases()$asset_roles."
    )
  }
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  if (view == "current") {
    out <- req_stitch_current(out)
    req_atomic_save_rds(out, current_cache$path)
  }
  out
}

#' Summarise semantic REQ series
#'
#' Builds a compact catalogue with one row per semantic `series_id` in the
#' requested forecast, historical, or combined data surfaces. The catalogue
#' is derived from the reported observation view, so it preserves source
#' provenance while avoiding one row per period. For an exact release, the
#' same source hash, parser version, and data scope identify a reusable cached
#' catalogue; a local bundle makes the operation deterministic and offline.
#'
#' @inheritParams read_req
#' @return A base `data.frame` ordered by `commodity`, `concept`, then
#'   `series_id`, with these columns: `series_id`, `commodity`, `concept`,
#'   `geography`, `frequency`, `period_basis`, `period_status`, `price_basis`,
#'   `currency`, `unit`, `first_period`, `last_period`, `observations`, and
#'   `source_datasets`. All fields except `observations` are character;
#'   `observations` is an integer-like count. Each row covers all observations
#'   for one series in the selected scope, and `first_period`/`last_period`
#'   are the source period labels rather than converted dates.
#' @section Conditions and side effects:
#' This function reads or downloads the same assets as [read_req()] and can
#' signal its release, transport, format, parser, or cache condition classes.
#' The result is written atomically below `cache_dir` and is not automatically
#' pruned. No credentials are required; a complete local/raw cache avoids the
#' network. The default parser worker count is one and should not be raised
#' above two in portable or CRAN-like environments.
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
#'   series_cache <- tempfile("readreq-example-series-cache-")
#'   stopifnot(dir.create(series_cache))
#'   series <- req_series_catalog(
#'     bundle,
#'     data = "forecast",
#'     cache_dir = series_cache
#'   )
#'   stopifnot(is.data.frame(series))
#'   utils::head(series[c("series_id", "commodity", "first_period", "last_period")])
#' }
#' if (identical(Sys.getenv("READREQ_LIVE_EXAMPLES"), "true")) {
#'   live <- req_series_catalog("req-2026-06", data = "forecast")
#'   utils::head(live[c("series_id", "commodity", "observations")])
#' }
#' @export
req_series_catalog <- function(
    release = "latest", data = c("all", "history", "forecast"),
    cache_dir = req_cache_dir()) {
  data <- match.arg(data)
  descriptor <- req_current_cache_descriptor(
    release, data, cache_dir, refresh = FALSE
  )
  catalogue_path <- file.path(
    cache_dir, "parsed", descriptor$release_id, .req_parser_version,
    "catalogue", basename(descriptor$path)
  )
  if (file.exists(catalogue_path)) return(readRDS(catalogue_path))
  x <- read_req(release, data = data, view = "reported", cache_dir = cache_dir)
  by <- split(seq_len(nrow(x)), x$series_id)
  rows <- lapply(by, function(i) {
    z <- x[i, , drop = FALSE]
    data.frame(
      series_id = z$series_id[[1]],
      commodity = z$commodity[[1]],
      concept = z$concept[[1]],
      geography = z$geography[[1]],
      frequency = z$frequency[[1]],
      period_basis = z$period_basis[[1]],
      period_status = z$period_status[[1]],
      price_basis = z$price_basis[[1]],
      currency = z$currency[[1]],
      unit = z$unit[[1]],
      first_period = z$period[[which.min(z$period_start)]],
      last_period = z$period[[which.max(z$period_end)]],
      observations = nrow(z),
      source_datasets = paste(sort(unique(z$source_dataset)), collapse = ";"),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out <- out[order(out$commodity, out$concept, out$series_id), , drop = FALSE]
  req_atomic_save_rds(out, catalogue_path)
  out
}
