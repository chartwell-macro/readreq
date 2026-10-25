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

#' Read every REQ forecast table
#'
#' @param release Exact release ID, `"latest"`, a local workbook path, or a
#'   named local release bundle.
#' @param sheets `"all"`, semantic table IDs, or source sheet aliases.
#' @param commodities,concepts,geography Optional semantic filters.
#' @param view Source-faithful reported or within-workbook canonical view.
#' @param cache_dir Cache directory.
#' @param refresh Refresh source data.
#' @return A data frame satisfying [req_observation_schema()].
#' @examples
#' \dontrun{
#' read_req_forecasts("req-2017-03", view = "reported")
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

#' Read every REQ historical table
#'
#' @inheritParams read_req_forecasts
#' @param tables `"all"`, semantic table IDs, or source sheet aliases.
#' @param frequency Optional annual, quarterly, or monthly filter.
#' @return A data frame satisfying [req_observation_schema()].
#' @examples
#' \dontrun{
#' read_req_history("req-2017-03", frequency = "annual")
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
#' @param release Exact release ID, latest, or a named local bundle.
#' @param data Data assets to return.
#' @param view Current stitched or reported view.
#' @inheritParams read_req_forecasts
#' @return A data frame satisfying [req_observation_schema()].
#' @examples
#' \dontrun{
#' read_req("req-2017-03", view = "current")
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

#' REQ semantic series catalogue
#'
#' @inheritParams read_req
#' @return One row per semantic series with period coverage and provenance.
#' @examples
#' \dontrun{
#' req_series_catalog("req-2017-03")
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
