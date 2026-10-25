.req_index_url <- paste0(
  "https://www.industry.gov.au/publications/",
  "resources-and-energy-quarterly"
)
.req_discovery_version <- "2-static-catalogue"
.req_month_number <- c(
  march = "03", june = "06", september = "09", december = "12"
)

.req_release_catalogue_internal <- function() {
  path <- system.file("catalogue", "release-catalog.csv", package = "readreq")
  if (!nzchar(path)) {
    path <- file.path("inst", "catalogue", "release-catalog.csv")
  }
  catalogue <- utils::read.csv(
    path,
    stringsAsFactors = FALSE,
    na.strings = "",
    check.names = FALSE
  )
  expected_ids <- c(
    "req-2011-09", "req-2011-12",
    unlist(lapply(2012:2025, function(year) {
      paste0("req-", year, "-", c("03", "06", "09", "12"))
    }), use.names = FALSE),
    "req-2026-06"
  )
  if (!identical(catalogue$release_id, expected_ids) ||
      anyDuplicated(catalogue$release_id) ||
      !"req-2011-09" %in% catalogue$release_id ||
      "req-2026-03" %in% catalogue$release_id) {
    req_abort(
      "req_release_discovery_error",
      "The checked-in REQ release catalogue is incomplete or non-canonical.",
      product = "resources_energy_quarterly",
      remediation = "Rebuild the catalogue from the official archive inventory."
    )
  }
  catalogue
}

.req_static_release_manifest <- function() {
  catalogue <- .req_release_catalogue_internal()
  url_fields <- c(
    forecast = "forecast_url",
    historical = "historical_url",
    report = "report_url",
    statistical = "statistical_url",
    commodity = "commodity_url",
    historical_statistical = "historical_statistical_url",
    historical_commodity = "historical_commodity_url"
  )
  roles <- lapply(seq_len(nrow(catalogue)), function(index) {
    names(url_fields)[vapply(url_fields, function(field) {
      value <- catalogue[[field]][[index]]
      !is.na(value) && nzchar(value)
    }, logical(1))]
  })
  result <- data.frame(
    product = "resources_energy_quarterly",
    release_id = catalogue$release_id,
    release_date = as.Date(catalogue$release_date),
    release_date_precision = catalogue$release_date_precision,
    edition = catalogue$edition,
    cadence = catalogue$cadence,
    landing_url = catalogue$landing_url,
    landing_source = catalogue$landing_source,
    asset_status = "complete",
    support_status = catalogue$support_status,
    unsupported_reason = NA_character_,
    discovered_at = as.POSIXct("2026-07-27 00:00:00", tz = "UTC"),
    discovery_version = .req_discovery_version,
    warning = NA_character_,
    forecast_url = catalogue$forecast_url,
    historical_url = catalogue$historical_url,
    report_url = catalogue$report_url,
    statistical_url = catalogue$statistical_url,
    commodity_url = catalogue$commodity_url,
    historical_statistical_url = catalogue$historical_statistical_url,
    historical_commodity_url = catalogue$historical_commodity_url,
    support_note = catalogue$support_note,
    stringsAsFactors = FALSE
  )
  result$asset_roles <- I(roles)
  result <- result[, req_release_manifest_schema()$field, drop = FALSE]
  result <- result[
    order(result$release_date, result$release_id, decreasing = TRUE),
    ,
    drop = FALSE
  ]
  rownames(result) <- NULL
  result
}

.req_supported_release_ids <- .req_release_catalogue_internal()$release_id

.req_normalise_space <- function(x) {
  trimws(gsub("[[:space:]\u00a0]+", " ", x))
}

.req_release_identity <- function(...) {
  candidate <- .req_normalise_space(paste(..., collapse = " "))
  match <- regexec(
    "(?i)(march|june|september|december)[^0-9]{0,12}(20[0-9]{2})",
    candidate,
    perl = TRUE
  )
  pieces <- regmatches(candidate, match)[[1L]]
  if (length(pieces) != 3L) {
    return(NULL)
  }
  edition <- tools::toTitleCase(tolower(pieces[[2L]]))
  year <- pieces[[3L]]
  month <- unname(.req_month_number[[tolower(pieces[[2L]])]])
  list(
    release_id = paste("req", year, month, sep = "-"),
    edition = edition,
    year = as.integer(year),
    month = as.integer(month)
  )
}

.req_official_url <- function(url) {
  is.character(url) &&
    length(url) == 1L &&
    grepl(
      "^https://(www\\.)?industry\\.gov\\.au/",
      url,
      ignore.case = TRUE,
      perl = TRUE
    )
}

.req_absolute_url <- function(url, base_url) {
  xml2::url_absolute(url, base_url)
}

.req_read_html <- function(html, context, release_id = NA_character_) {
  tryCatch(
    xml2::read_html(html),
    error = function(e) {
      req_abort(
        "req_release_discovery_error",
        paste0("Could not parse ", context, " HTML."),
        product = "resources_energy_quarterly",
        release_id = release_id,
        remediation = "Retry discovery or inspect the official page markup.",
        parent = e
      )
    }
  )
}

.req_parse_official_date <- function(x, release_id) {
  value <- tolower(.req_normalise_space(x))
  date_match <- regexec(
    "^([0-9]{1,2}) (january|february|march|april|may|june|july|august|september|october|november|december) (20[0-9]{2})$",
    value,
    perl = TRUE
  )
  pieces <- regmatches(value, date_match)[[1L]]
  if (length(pieces) != 4L) {
    req_abort(
      "req_release_discovery_error",
      paste0("Official publication date is missing or unrecognised for ", release_id, "."),
      product = "resources_energy_quarterly",
      release_id = release_id,
      remediation = "Inspect the landing page Date published field."
    )
  }
  month <- match(
    pieces[[3L]],
    tolower(month.name)
  )
  as.Date(sprintf(
    "%s-%02d-%02d",
    pieces[[4L]],
    month,
    as.integer(pieces[[2L]])
  ))
}

.req_parse_release_index_html <- function(
    html,
    index_url = .req_index_url) {
  doc <- .req_read_html(html, "release index")
  anchors <- xml2::xml_find_all(doc, ".//a[@href]")
  hrefs <- xml2::xml_attr(anchors, "href")
  labels <- .req_normalise_space(xml2::xml_text(anchors))

  rows <- lapply(seq_along(hrefs), function(i) {
    identity <- .req_release_identity(labels[[i]], hrefs[[i]])
    if (is.null(identity)) {
      return(NULL)
    }
    landing_url <- .req_absolute_url(hrefs[[i]], index_url)
    if (!.req_official_url(landing_url) ||
        !grepl(
          "/(data-and-)?publications/resources-and-energy-quarterly-",
          landing_url,
          perl = TRUE
        )) {
      return(NULL)
    }
    data.frame(
      release_id = identity$release_id,
      edition = identity$edition,
      landing_url = landing_url,
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)

  if (!length(rows)) {
    req_abort(
      "req_release_discovery_error",
      "The official REQ index did not contain any recognisable release links.",
      product = "resources_energy_quarterly",
      remediation = "Inspect the official index for a markup or URL change."
    )
  }
  result <- do.call(rbind, rows)

  duplicates <- split(result$landing_url, result$release_id)
  conflicts <- names(Filter(function(x) length(unique(x)) > 1L, duplicates))
  if (length(conflicts)) {
    req_abort(
      "req_release_discovery_error",
      paste0(
        "The official index maps one release identity to multiple pages: ",
        paste(conflicts, collapse = ", "),
        "."
      ),
      product = "resources_energy_quarterly",
      release_id = conflicts[[1L]],
      remediation = "Inspect the duplicate official index links."
    )
  }

  result <- result[!duplicated(result$release_id), , drop = FALSE]
  result <- result[order(result$release_id, decreasing = TRUE), , drop = FALSE]
  rownames(result) <- NULL
  result
}

.req_asset_role <- function(label, href) {
  value <- tolower(.req_normalise_space(paste(label, href)))
  path <- tolower(sub("[?#].*$", "", href))
  if (grepl("\\.pdf$", path, perl = TRUE)) {
    filename <- utils::URLdecode(basename(path))
    if (grepl(
      "(march|june|september|december)[_-](20[0-9]{2})\\.pdf$",
      filename,
      perl = TRUE
    )) {
      return("report")
    }
    return(NA_character_)
  }
  if (!grepl("\\.xls(x|m|b)?$", path, perl = TRUE)) {
    return(NA_character_)
  }
  forecast <- grepl("forecast", value, fixed = TRUE)
  historical <- grepl("histor", value, fixed = TRUE)
  if (forecast && !historical) {
    return("forecast")
  }
  if (historical && !forecast) {
    return("historical")
  }
  NA_character_
}

.req_parse_release_page_html <- function(
    html,
    landing_url,
    expected_release_id = NULL,
    discovered_at = Sys.time()) {
  doc <- .req_read_html(
    html,
    "release landing page",
    .req_or(expected_release_id, NA_character_)
  )
  title_node <- xml2::xml_find_first(doc, ".//meta[@property='og:title']")
  title <- xml2::xml_attr(title_node, "content")
  if (is.na(title) || !nzchar(title)) {
    title <- .req_normalise_space(
      xml2::xml_text(xml2::xml_find_first(doc, ".//h1"))
    )
  }
  canonical <- xml2::xml_attr(
    xml2::xml_find_first(doc, ".//link[@rel='canonical']"),
    "href"
  )
  if (is.na(canonical) || !nzchar(canonical)) {
    canonical <- landing_url
  }
  canonical <- .req_absolute_url(canonical, landing_url)
  if (!.req_official_url(canonical)) {
    req_abort(
      "req_release_discovery_error",
      "Release landing-page canonical URL is not an official industry.gov.au URL.",
      product = "resources_energy_quarterly",
      release_id = .req_or(expected_release_id, NA_character_),
      remediation = "Inspect the official landing-page canonical metadata."
    )
  }

  identity <- .req_release_identity(title, canonical)
  if (is.null(identity)) {
    req_abort(
      "req_release_discovery_error",
      "Release identity could not be derived from official landing-page metadata.",
      product = "resources_energy_quarterly",
      release_id = .req_or(expected_release_id, NA_character_),
      remediation = "Inspect the landing-page title and canonical URL."
    )
  }
  if (!is.null(expected_release_id) &&
      !identical(identity$release_id, expected_release_id)) {
    req_abort(
      "req_release_discovery_error",
      paste0(
        "Landing-page identity ", identity$release_id,
        " conflicts with index identity ", expected_release_id, "."
      ),
      product = "resources_energy_quarterly",
      release_id = expected_release_id,
      remediation = "Inspect the official index and landing-page metadata."
    )
  }

  date_node <- xml2::xml_find_first(
    doc,
    paste0(
      ".//*[contains(concat(' ', normalize-space(@class), ' '),",
      " ' field--name-field-date ')]",
      "//*[contains(concat(' ', normalize-space(@class), ' '),",
      " ' field__item ')]"
    )
  )
  release_date <- .req_parse_official_date(
    xml2::xml_text(date_node),
    identity$release_id
  )

  anchors <- xml2::xml_find_all(doc, ".//a[@href]")
  hrefs <- xml2::xml_attr(anchors, "href")
  labels <- .req_normalise_space(xml2::xml_text(anchors))
  roles <- vapply(
    seq_along(hrefs),
    function(i) .req_asset_role(labels[[i]], hrefs[[i]]),
    character(1)
  )
  keep <- !is.na(roles)
  assets <- data.frame(
    role = roles[keep],
    url = vapply(
      hrefs[keep],
      .req_absolute_url,
      character(1),
      base_url = canonical
    ),
    stringsAsFactors = FALSE
  )
  assets <- assets[!duplicated(assets), , drop = FALSE]
  if (nrow(assets) && any(!vapply(assets$url, .req_official_url, logical(1)))) {
    req_abort(
      "req_release_discovery_error",
      "A release asset points outside the official industry.gov.au domain.",
      product = "resources_energy_quarterly",
      release_id = identity$release_id,
      remediation = "Inspect the release-page download links."
    )
  }

  role_url <- function(role) {
    values <- unique(assets$url[assets$role == role])
    if (length(values) > 1L) {
      req_abort(
        "req_release_discovery_error",
        paste0("Multiple distinct ", role, " assets were found."),
        product = "resources_energy_quarterly",
        release_id = identity$release_id,
        asset_type = role,
        remediation = "Inspect duplicate release-page download links."
      )
    }
    if (length(values)) values[[1L]] else NA_character_
  }
  forecast_url <- role_url("forecast")
  historical_url <- role_url("historical")
  report_url <- role_url("report")
  present <- c(
    forecast = !is.na(forecast_url),
    historical = !is.na(historical_url),
    report = !is.na(report_url)
  )
  asset_status <- if (all(present)) {
    "complete"
  } else if (any(present)) {
    "partial"
  } else {
    "invalid"
  }
  warning_text <- if (!all(present)) {
    paste0(
      "Missing required asset roles: ",
      paste(names(present)[!present], collapse = ", "),
      "."
    )
  } else {
    NA_character_
  }
  supported_release <- identity$release_id %in% .req_supported_release_ids
  support_status <- if (supported_release && identical(asset_status, "complete")) {
    "supported"
  } else if (supported_release) {
    "unsupported"
  } else {
    "discovered-unverified"
  }
  unsupported_reason <- if (identical(support_status, "supported")) {
    NA_character_
  } else if (supported_release) {
    "required_assets_missing"
  } else {
    "release_not_fixture_verified"
  }

  result <- data.frame(
    product = "resources_energy_quarterly",
    release_id = identity$release_id,
    release_date = release_date,
    release_date_precision = "day",
    edition = identity$edition,
    cadence = "quarterly",
    landing_url = canonical,
    landing_source = "Department of Industry, Science and Resources",
    asset_status = asset_status,
    support_status = support_status,
    unsupported_reason = unsupported_reason,
    discovered_at = as.POSIXct(discovered_at, tz = "UTC"),
    discovery_version = .req_discovery_version,
    warning = warning_text,
    forecast_url = forecast_url,
    historical_url = historical_url,
    report_url = report_url,
    statistical_url = NA_character_,
    commodity_url = NA_character_,
    historical_statistical_url = NA_character_,
    historical_commodity_url = NA_character_,
    support_note = if (identical(support_status, "supported")) {
      "audited structured companion data"
    } else {
      NA_character_
    },
    stringsAsFactors = FALSE
  )
  result$asset_roles <- I(list(names(present)[present]))
  result <- result[, req_release_manifest_schema()$field, drop = FALSE]
  result
}

.req_fetch_discovery_html <- function(url, release_id = NA_character_) {
  tryCatch(
    .req_transport(url, mode = "text")$body,
    error = function(e) {
      if (inherits(e, "req_release_discovery_error")) {
        stop(e)
      }
      req_abort(
        "req_release_discovery_error",
        paste0("Could not retrieve official discovery HTML: ", url),
        product = "resources_energy_quarterly",
        release_id = release_id,
        remediation = "Check connectivity or use a populated discovery cache.",
        parent = e
      )
    }
  )
}

.req_discover_releases <- function(index_url = .req_index_url) {
  discovered_at <- as.POSIXct(Sys.time(), tz = "UTC")
  index <- .req_parse_release_index_html(
    .req_fetch_discovery_html(index_url),
    index_url = index_url
  )
  rows <- lapply(seq_len(nrow(index)), function(i) {
    page <- .req_fetch_discovery_html(
      index$landing_url[[i]],
      index$release_id[[i]]
    )
    .req_parse_release_page_html(
      page,
      landing_url = index$landing_url[[i]],
      expected_release_id = index$release_id[[i]],
      discovered_at = discovered_at
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL

  march_2026_gap <- "req-2026-06" %in% result$release_id &&
    "req-2025-12" %in% result$release_id &&
    !"req-2026-03" %in% result$release_id
  if (march_2026_gap) {
    gap_message <- paste0(
      "The official index lists June 2026 after December 2025 but no ",
      "March 2026 release; no edition was manufactured."
    )
    row <- match("req-2026-06", result$release_id)
    result$warning[[row]] <- gap_message
    req_warn(
      "req_release_gap_warning",
      gap_message,
      product = "resources_energy_quarterly",
      release_id = "req-2026-03",
      remediation = "Treat the official index as authoritative."
    )
  }

  result <- result[
    order(result$release_date, result$release_id, decreasing = TRUE),
    ,
    drop = FALSE
  ]
  rownames(result) <- NULL
  result
}

.req_release_manifest_cache_file <- function(cache_dir) {
  .req_cache_path(cache_dir, "discovery", "releases.json")
}

.req_restore_release_manifest <- function(x) {
  if (is.null(x)) {
    return(NULL)
  }
  x <- as.data.frame(x, stringsAsFactors = FALSE)
  x$release_date <- as.Date(x$release_date)
  x$discovered_at <- as.POSIXct(x$discovered_at, tz = "UTC")
  if (!is.list(x$asset_roles)) {
    x$asset_roles <- as.list(x$asset_roles)
  }
  x <- x[, req_release_manifest_schema()$field, drop = FALSE]
  rownames(x) <- NULL
  x
}

#' List official Resources and Energy Quarterly releases
#'
#' Returns the checked-in, official-source-audited release catalogue spanning
#' every actual edition from September 2011 through June 2026.
#'
#' @param refresh Re-read the installed catalogue.
#' @param supported_only Return only supported releases.
#' @param cache_dir Cache root.
#' @return A release-manifest data frame.
#' @examples
#' releases <- list_req_releases()
#' releases[c("release_id", "edition", "asset_status")]
#' @export
list_req_releases <- function(
    refresh = FALSE,
    supported_only = FALSE,
    cache_dir = req_cache_dir()) {
  stopifnot(
    is.logical(refresh), length(refresh) == 1L, !is.na(refresh),
    is.logical(supported_only), length(supported_only) == 1L,
    !is.na(supported_only)
  )
  result <- .req_static_release_manifest()

  if (isTRUE(supported_only)) {
    result <- result[result$support_status == "supported", , drop = FALSE]
    rownames(result) <- NULL
  }
  result
}
