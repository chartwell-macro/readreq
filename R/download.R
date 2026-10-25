.req_sha256_file <- function(path) {
  tolower(digest::digest(path, algo = "sha256", file = TRUE, serialize = FALSE))
}

.req_content_type <- function(x) {
  if (is.null(x) || !length(x) || is.na(x) || !nzchar(x)) {
    return(NA_character_)
  }
  tolower(trimws(strsplit(x, ";", fixed = TRUE)[[1L]][[1L]]))
}

.req_detect_format <- function(path, content_type = NA_character_) {
  bytes <- readBin(path, what = "raw", n = 512L)
  content_type <- .req_content_type(content_type)
  if (identical(content_type, "text/html")) {
    return("html")
  }
  if (length(bytes) >= 5L &&
      identical(rawToChar(bytes[seq_len(5L)]), "%PDF-")) {
    return("pdf")
  }
  xlsx_signature <- as.raw(c(0x50, 0x4b, 0x03, 0x04))
  if (length(bytes) >= 4L && identical(bytes[seq_len(4L)], xlsx_signature)) {
    return("xlsx")
  }
  xls_signature <- as.raw(c(0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1))
  if (length(bytes) >= 8L && identical(bytes[seq_len(8L)], xls_signature)) {
    return("xls")
  }
  text_bytes <- bytes[seq_len(min(length(bytes), 128L))]
  text <- if (length(text_bytes)) {
    tolower(trimws(rawToChar(text_bytes[text_bytes != as.raw(0)])))
  } else {
    ""
  }
  if (startsWith(text, "<!doctype html") || startsWith(text, "<html")) {
    return("html")
  }
  "unknown"
}

.req_validate_asset_file <- function(
    path,
    asset_type,
    content_type = NA_character_,
    verify_workbook = TRUE,
    release_id = NA_character_) {
  size <- unname(file.info(path)$size)
  if (is.na(size) || size <= 8) {
    req_abort(
      "req_asset_format_error",
      paste0("Downloaded ", asset_type, " asset is empty or truncated."),
      product = "resources_energy_quarterly",
      release_id = release_id,
      asset_type = asset_type,
      remediation = "Retry the download and inspect the official asset link."
    )
  }
  format <- .req_detect_format(path, content_type)
  expected <- if (identical(asset_type, "report")) {
    "pdf"
  } else {
    c("xlsx", "xls")
  }
  if (!format %in% expected) {
    req_abort(
      "req_asset_format_error",
      paste0(
        "Downloaded ", asset_type, " asset has ", format,
        " content; expected ", paste(expected, collapse = " or "), "."
      ),
      product = "resources_energy_quarterly",
      release_id = release_id,
      asset_type = asset_type,
      remediation = "Check for an HTML error response or changed official download."
    )
  }

  if (isTRUE(verify_workbook) && format %in% c("xlsx", "xls")) {
    tryCatch(
      readxl::excel_sheets(path),
      error = function(e) {
        req_abort(
          "req_asset_format_error",
          paste0("Downloaded ", asset_type, " workbook is not readable."),
          product = "resources_energy_quarterly",
          release_id = release_id,
          asset_type = asset_type,
          remediation = "Retry the download or inspect the official workbook.",
          parent = e
        )
      }
    )
  }
  format
}

.req_source_filename <- function(url, content_disposition = NA_character_) {
  if (!is.na(content_disposition) && nzchar(content_disposition)) {
    match <- regexec(
      "(?i)filename\\*?=(?:UTF-8''|[\"']?)([^\"';]+)",
      content_disposition,
      perl = TRUE
    )
    pieces <- regmatches(content_disposition, match)[[1L]]
    if (length(pieces) == 2L) {
      return(utils::URLdecode(trimws(pieces[[2L]])))
    }
  }
  path <- sub("[?#].*$", "", url)
  utils::URLdecode(basename(path))
}

.req_asset_manifest_file <- function(cache_dir, release_id, sha256) {
  .req_cache_path(
    cache_dir,
    "raw",
    release_id,
    sha256,
    "asset-manifest.json"
  )
}

.req_restore_asset_manifest <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  x$retrieved_at <- as.POSIXct(x$retrieved_at, tz = "UTC")
  x$bytes <- as.numeric(x$bytes)
  x <- x[, req_raw_asset_manifest_schema()$field, drop = FALSE]
  rownames(x) <- NULL
  x
}

.req_cached_asset_manifests <- function(cache_dir, release_id) {
  release_dir <- .req_cache_path(cache_dir, "raw", release_id)
  if (!dir.exists(release_dir)) {
    return(NULL)
  }
  files <- list.files(
    release_dir,
    pattern = "^asset-manifest\\.json$",
    recursive = TRUE,
    full.names = TRUE
  )
  if (!length(files)) {
    return(NULL)
  }
  rows <- lapply(files, function(path) {
    .req_restore_asset_manifest(.req_read_json(path))
  })
  rows <- Filter(Negate(is.null), rows)
  if (!length(rows)) {
    return(NULL)
  }
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  result
}

.req_cached_exact_bundle <- function(
    cache_dir, release_id, assets, verify_workbook = TRUE) {
  manifests <- .req_cached_asset_manifests(cache_dir, release_id)
  if (is.null(manifests)) return(NULL)
  manifests <- manifests[
    manifests$validation_status == "valid" &
      manifests$asset_type %in% assets,
    , drop = FALSE
  ]
  if (!all(assets %in% manifests$asset_type)) return(NULL)
  rows <- lapply(assets, function(asset) {
    candidates <- manifests[manifests$asset_type == asset, , drop = FALSE]
    candidates <- candidates[
      order(candidates$retrieved_at, decreasing = TRUE),
      , drop = FALSE
    ]
    .req_validate_cached_asset(
      candidates[1L, , drop = FALSE],
      verify_workbook = verify_workbook
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.req_validate_cached_asset <- function(row, verify_workbook = TRUE) {
  path <- row$local_path[[1L]]
  if (!file.exists(path)) {
    req_abort(
      "req_validation_error",
      paste0("Cached raw asset is missing: ", path),
      product = row$product[[1L]],
      release_id = row$release_id[[1L]],
      asset_type = row$asset_type[[1L]],
      remediation = "Remove only the named asset manifest and retrieve it again."
    )
  }
  hash <- .req_sha256_file(path)
  hash_path <- basename(dirname(path))
  if (!identical(hash, row$sha256[[1L]]) ||
      !identical(hash_path, row$sha256[[1L]])) {
    req_abort(
      "req_validation_error",
      "Cached raw asset hash does not match its immutable content-addressed path.",
      product = row$product[[1L]],
      release_id = row$release_id[[1L]],
      asset_type = row$asset_type[[1L]],
      remediation = "Quarantine the named cache path and retrieve the asset again."
    )
  }
  .req_validate_asset_file(
    path,
    row$asset_type[[1L]],
    row$content_type[[1L]],
    verify_workbook = verify_workbook,
    release_id = row$release_id[[1L]]
  )
  row
}

.req_find_cached_asset <- function(
    cache_dir,
    release_id,
    asset_type,
    source_url,
    verify_workbook = TRUE) {
  manifests <- .req_cached_asset_manifests(cache_dir, release_id)
  if (is.null(manifests)) {
    return(NULL)
  }
  candidates <- manifests[
    manifests$asset_type == asset_type &
      manifests$source_url == source_url &
      manifests$validation_status == "valid",
    ,
    drop = FALSE
  ]
  if (!nrow(candidates)) {
    return(NULL)
  }
  candidates <- candidates[
    order(candidates$retrieved_at, decreasing = TRUE),
    ,
    drop = FALSE
  ]
  .req_validate_cached_asset(
    candidates[1L, , drop = FALSE],
    verify_workbook = verify_workbook
  )
}

.req_download_to_temp <- function(url, path, release_id, asset_type) {
  tryCatch(
    {
      response <- .req_transport(url, mode = "file", path = path)
      if (!is.null(response$status_code) &&
          !is.na(response$status_code) &&
          response$status_code >= 400L) {
        stop("HTTP status ", response$status_code, call. = FALSE)
      }
      response
    },
    error = function(e) {
      if (inherits(e, "req_download_error")) {
        stop(e)
      }
      req_abort(
        "req_download_error",
        paste0("Could not download ", asset_type, " asset for ", release_id, "."),
        product = "resources_energy_quarterly",
        release_id = release_id,
        asset_type = asset_type,
        remediation = "Check connectivity or retrieve an already cached exact release.",
        parent = e
      )
    }
  )
}

.req_download_asset <- function(
    release,
    asset_type,
    cache_dir,
    refresh = FALSE,
    verify = TRUE) {
  url_field <- paste0(asset_type, "_url")
  source_url <- release[[url_field]][[1L]]
  release_id <- release$release_id[[1L]]
  if (is.null(source_url) || is.na(source_url) || !nzchar(source_url)) {
    req_abort(
      "req_asset_missing_error",
      paste0("Release ", release_id, " has no ", asset_type, " asset."),
      product = "resources_energy_quarterly",
      release_id = release_id,
      asset_type = asset_type,
      remediation = "Inspect the official release landing page."
    )
  }

  if (!isTRUE(refresh)) {
    cached <- .req_find_cached_asset(
      cache_dir,
      release_id,
      asset_type,
      source_url,
      verify_workbook = verify
    )
    if (!is.null(cached)) {
      return(cached)
    }
  }

  lock <- .req_cache_path(
    cache_dir,
    "raw",
    release_id,
    ".locks",
    paste0(asset_type, ".lock")
  )
  .req_with_lock(lock, {
    if (!isTRUE(refresh)) {
      cached <- .req_find_cached_asset(
        cache_dir,
        release_id,
        asset_type,
        source_url,
        verify_workbook = verify
      )
      if (!is.null(cached)) {
        return(cached)
      }
    }

    tmp_dir <- .req_cache_path(cache_dir, "raw", release_id, ".tmp")
    .req_dir_create(tmp_dir)
    tmp <- tempfile(pattern = paste0(asset_type, "-"), tmpdir = tmp_dir)
    on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
    response <- .req_download_to_temp(
      source_url,
      tmp,
      release_id,
      asset_type
    )
    format <- .req_validate_asset_file(
      tmp,
      asset_type,
      response$content_type,
      verify_workbook = verify,
      release_id = release_id
    )
    sha256 <- .req_sha256_file(tmp)
    target_dir <- .req_cache_path(cache_dir, "raw", release_id, sha256)
    .req_dir_create(target_dir)
    target <- file.path(target_dir, paste0(asset_type, ".", format))

    if (file.exists(target)) {
      existing_hash <- .req_sha256_file(target)
      if (!identical(existing_hash, sha256)) {
        req_abort(
          "req_validation_error",
          "Immutable raw target already exists with different bytes.",
          product = "resources_energy_quarterly",
          release_id = release_id,
          asset_type = asset_type,
          remediation = "Quarantine the conflicting content-addressed path."
        )
      }
      unlink(tmp)
    } else if (!file.rename(tmp, target)) {
      req_abort(
        "req_download_error",
        paste0("Atomic promotion failed for ", asset_type, " asset."),
        product = "resources_energy_quarterly",
        release_id = release_id,
        asset_type = asset_type,
        remediation = "Use a cache directory on one writable filesystem."
      )
    }
    target <- normalizePath(target, winslash = "/", mustWork = TRUE)
    bytes <- as.numeric(file.info(target)$size)
    retrieved_at <- as.POSIXct(Sys.time(), tz = "UTC")
    manifest <- data.frame(
      product = "resources_energy_quarterly",
      release_id = release_id,
      asset_type = asset_type,
      source_url = source_url,
      source_filename = .req_source_filename(
        source_url,
        response$content_disposition
      ),
      detected_format = format,
      content_type = .req_or(response$content_type, NA_character_),
      retrieved_at = retrieved_at,
      etag = .req_or(response$etag, NA_character_),
      last_modified = .req_or(response$last_modified, NA_character_),
      sha256 = sha256,
      bytes = bytes,
      local_path = target,
      validation_status = "valid",
      unsupported_reason = NA_character_,
      stringsAsFactors = FALSE
    )
    manifest <- manifest[
      ,
      req_raw_asset_manifest_schema()$field,
      drop = FALSE
    ]

    manifest_file <- .req_asset_manifest_file(
      cache_dir,
      release_id,
      sha256
    )
    if (file.exists(manifest_file)) {
      existing <- .req_restore_asset_manifest(.req_read_json(manifest_file))
      same_identity <- nrow(existing) == 1L &&
        identical(existing$sha256[[1L]], sha256) &&
        identical(existing$asset_type[[1L]], asset_type) &&
        identical(existing$source_url[[1L]], source_url)
      if (!same_identity) {
        req_abort(
          "req_validation_error",
          "Immutable raw manifest conflicts with the downloaded asset.",
          product = "resources_energy_quarterly",
          release_id = release_id,
          asset_type = asset_type,
          remediation = "Quarantine the conflicting content-addressed path."
        )
      }
      return(.req_validate_cached_asset(existing, verify_workbook = verify))
    }
    .req_write_json_atomic(manifest, manifest_file)
    manifest
  })
}

.req_resolve_release <- function(release, releases) {
  if (is.data.frame(release)) {
    if (nrow(release) != 1L) {
      req_abort(
        "req_validation_error",
        "A release manifest supplied to download_req_release must have one row.",
        product = "resources_energy_quarterly",
        remediation = "Supply one exact release row or a release ID."
      )
    }
    return(release)
  }
  if (!is.character(release) || length(release) != 1L || is.na(release)) {
    req_abort(
      "req_validation_error",
      "release must be 'latest', an exact release ID, or one manifest row.",
      product = "resources_energy_quarterly",
      remediation = "Use list_req_releases() to choose an exact release."
    )
  }
  if (identical(release, "latest")) {
    if (!nrow(releases)) {
      req_abort(
        "req_release_discovery_error",
        "No official REQ releases are available.",
        product = "resources_energy_quarterly",
        remediation = "Refresh release discovery."
      )
    }
    return(releases[which.max(releases$release_date), , drop = FALSE])
  }
  index <- match(release, releases$release_id)
  if (is.na(index)) {
    req_abort(
      "req_release_discovery_error",
      paste0("Release is not listed on the official index: ", release),
      product = "resources_energy_quarterly",
      release_id = release,
      remediation = "Use list_req_releases() and do not manufacture quarterly editions."
    )
  }
  releases[index, , drop = FALSE]
}

#' Download an exact Resources and Energy Quarterly release bundle
#'
#' @param release `"latest"` or an exact `req-YYYY-MM` release ID.
#' @param assets Asset roles to download. `NULL` downloads every published
#'   companion asset for the selected edition.
#' @param cache_dir Cache root.
#' @param refresh Re-fetch assets while preserving existing hashes.
#' @param verify Validate workbook readability in addition to file signatures.
#' @return A raw-asset manifest.
#' @examples
#' \dontrun{
#' download_req_release("req-2017-03")
#' }
#' @export
download_req_release <- function(
    release = "latest",
    assets = NULL,
    cache_dir = req_cache_dir(),
    refresh = FALSE,
    verify = TRUE) {
  allowed <- c(
    "forecast", "historical", "report", "statistical", "commodity",
    "historical_statistical", "historical_commodity"
  )
  if (!is.null(assets) &&
      (!is.character(assets) || !length(assets) ||
        anyNA(assets) || any(!assets %in% allowed))) {
    req_abort(
      "req_validation_error",
      "assets contains an unknown REQ companion role.",
      product = "resources_energy_quarterly",
      remediation = "Choose one or more documented asset roles."
    )
  }
  releases <- if (is.data.frame(release)) {
    release
  } else {
    list_req_releases(refresh = refresh, cache_dir = cache_dir)
  }
  resolved <- .req_resolve_release(release, releases)
  if (is.null(assets)) {
    assets <- unlist(resolved$asset_roles[[1L]], use.names = FALSE)
  }
  assets <- unique(as.character(assets))
  exact_id <- is.character(release) && length(release) == 1L &&
    !is.na(release) && grepl("^req-[0-9]{4}-(03|06|09|12)$", release)
  if (exact_id && !isTRUE(refresh)) {
    cached <- .req_cached_exact_bundle(
      cache_dir, release, assets, verify_workbook = verify
    )
    if (!is.null(cached)) {
      .req_validate_raw_release(cached, verify_files = verify)
      return(cached)
    }
  }
  rows <- lapply(assets, function(asset_type) {
    .req_download_asset(
      resolved,
      asset_type,
      cache_dir,
      refresh = refresh,
      verify = verify
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  .req_validate_raw_release(result, verify_files = verify)
  result
}

.req_validate_raw_release <- function(manifest, verify_files = TRUE) {
  fields <- req_raw_asset_manifest_schema()$field
  if (!is.data.frame(manifest) || !all(fields %in% names(manifest))) {
    req_abort(
      "req_validation_error",
      "Raw release manifest does not satisfy the frozen schema.",
      product = "resources_energy_quarterly",
      remediation = "Use the manifest returned by download_req_release()."
    )
  }
  if (anyDuplicated(manifest$asset_type)) {
    req_abort(
      "req_validation_error",
      "Raw release manifest contains duplicate asset roles.",
      product = "resources_energy_quarterly",
      release_id = manifest$release_id[[1L]],
      remediation = "Select one immutable snapshot per asset role."
    )
  }
  if (length(unique(manifest$release_id)) != 1L ||
      any(!grepl("^[a-f0-9]{64}$", manifest$sha256)) ||
      any(manifest$validation_status != "valid")) {
    req_abort(
      "req_validation_error",
      "Raw release manifest contains an invalid release, hash, or status.",
      product = "resources_energy_quarterly",
      release_id = manifest$release_id[[1L]],
      remediation = "Retrieve the exact release again and inspect its validation status."
    )
  }
  if (isTRUE(verify_files)) {
    invisible(lapply(seq_len(nrow(manifest)), function(i) {
      .req_validate_cached_asset(
        manifest[i, , drop = FALSE],
        verify_workbook = TRUE
      )
    }))
  }
  invisible(TRUE)
}
