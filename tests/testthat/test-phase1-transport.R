phase1_fixture_dir <- function() {
  testthat::test_path("fixtures", "discovery")
}

phase1_fixture_text <- function(name) {
  paste(
    readLines(file.path(phase1_fixture_dir(), name), warn = FALSE),
    collapse = "\n"
  )
}

phase1_transport <- function(url, mode = c("text", "file"), path = NULL) {
  mode <- match.arg(mode)
  if (identical(mode, "text")) {
    name <- if (identical(
      url,
      "https://www.industry.gov.au/publications/resources-and-energy-quarterly"
    )) {
      "index.html"
    } else {
      paste0(basename(sub("[?#].*$", "", url)), ".html")
    }
    fixture <- file.path(phase1_fixture_dir(), name)
    if (!file.exists(fixture)) {
      stop("No fixture for URL: ", url, call. = FALSE)
    }
    return(list(
      body = phase1_fixture_text(name),
      content_type = "text/html; charset=UTF-8",
      status_code = 200L,
      final_url = url
    ))
  }

  if (grepl("forecast", url, ignore.case = TRUE)) {
    source <- system.file("extdata", "clippy.xlsx", package = "readxl")
    file.copy(source, path, overwrite = TRUE)
    content_type <- paste0(
      "application/vnd.openxmlformats-officedocument.",
      "spreadsheetml.sheet"
    )
  } else if (grepl("histor", url, ignore.case = TRUE)) {
    source <- system.file("extdata", "datasets.xlsx", package = "readxl")
    file.copy(source, path, overwrite = TRUE)
    content_type <- paste0(
      "application/vnd.openxmlformats-officedocument.",
      "spreadsheetml.sheet"
    )
  } else if (grepl("\\.pdf$", url, ignore.case = TRUE)) {
    writeBin(
      charToRaw("%PDF-1.7\nReduced synthetic transport fixture.\n%%EOF\n"),
      path
    )
    content_type <- "application/pdf"
  } else {
    stop("Unexpected asset URL: ", url, call. = FALSE)
  }
  list(
    content_type = content_type,
    etag = '"fixture-etag"',
    last_modified = "Fri, 03 Jul 2026 00:00:00 GMT",
    status_code = 200L,
    final_url = url
  )
}

test_that("official index parsing enumerates only actual linked releases", {
  index <- readreq:::.req_parse_release_index_html(
    phase1_fixture_text("index.html")
  )
  expect_equal(nrow(index), 9L)
  expect_setequal(index$release_id, c(
    "req-2024-03", "req-2024-06", "req-2024-09", "req-2024-12",
    "req-2025-03", "req-2025-06", "req-2025-09", "req-2025-12",
    "req-2026-06"
  ))
  expect_false("req-2026-03" %in% index$release_id)
  expect_true(all(grepl(
    "^https://www\\.industry\\.gov\\.au/publications/",
    index$landing_url
  )))

  legacy <- readreq:::.req_parse_release_index_html(
    phase1_fixture_text("index-legacy.html")
  )
  expect_equal(nrow(legacy), 12L)
  expect_setequal(
    legacy$release_id,
    unlist(lapply(2021:2023, function(year) {
      sprintf("req-%d-%s", year, c("03", "06", "09", "12"))
    }))
  )
  expect_true(any(grepl("/data-and-publications/", legacy$landing_url)))
})

test_that("landing pages authoritatively supply dates and asset roles", {
  march <- readreq:::.req_parse_release_page_html(
    phase1_fixture_text(
      "resources-and-energy-quarterly-march-2024.html"
    ),
    paste0(
      "https://www.industry.gov.au/publications/",
      "resources-and-energy-quarterly-march-2024"
    ),
    expected_release_id = "req-2024-03",
    discovered_at = as.POSIXct("2026-07-27 00:00:00", tz = "UTC")
  )
  expect_equal(march$release_date, as.Date("2024-03-28"))
  expect_equal(march$edition, "March")
  expect_equal(march$support_status, "supported")
  expect_equal(
    sort(march$asset_roles[[1L]]),
    c("forecast", "historical", "report")
  )
  expect_match(march$forecast_url, "forecast_tables_mar_2024\\.xlsx$")
  expect_match(march$historical_url, "historical_tables_mar_2024\\.xlsx$")

  partial <- readreq:::.req_parse_release_page_html(
    phase1_fixture_text("release-missing-historical.html"),
    paste0(
      "https://www.industry.gov.au/publications/",
      "resources-and-energy-quarterly-june-2026"
    ),
    expected_release_id = "req-2026-06"
  )
  expect_equal(partial$asset_status, "partial")
  expect_equal(partial$support_status, "unsupported")
  expect_equal(partial$unsupported_reason, "required_assets_missing")
  expect_match(partial$warning, "historical")
})

test_that("the static catalogue enumerates the complete audited history", {
  cache <- tempfile("readreq-phase1-discovery-")
  old <- options(readreq.transport = phase1_transport)
  on.exit(options(old), add = TRUE)

  releases <- readreq:::list_req_releases(cache_dir = cache)
  expect_equal(nrow(releases), 59L)
  expect_true(all(releases$support_status == "supported"))
  expect_equal(min(releases$release_date), as.Date("2011-09-20"))
  expect_equal(max(releases$release_date), as.Date("2026-07-03"))
  expect_false("req-2026-03" %in% releases$release_id)

  options(readreq.transport = function(...) {
    stop("network should not be used for the static catalogue", call. = FALSE)
  })
  repeated <- readreq:::list_req_releases(cache_dir = cache)
  expect_equal(repeated$release_id, releases$release_id)
  expect_s3_class(repeated$release_date, "Date")
  expect_s3_class(repeated$discovered_at, "POSIXct")
  expect_true(is.list(repeated$asset_roles))
})

test_that("exact retrieval is content-addressed, immutable, and idempotent", {
  cache <- tempfile("readreq-phase1-assets-")
  old <- options(readreq.transport = phase1_transport)
  on.exit(options(old), add = TRUE)

  releases <- readreq:::list_req_releases(cache_dir = cache)
  manifest <- readreq:::download_req_release(
    "req-2026-06",
    cache_dir = cache
  )
  expect_setequal(
    manifest$asset_type,
    c("forecast", "historical", "report")
  )
  expect_true(all(grepl("^[a-f0-9]{64}$", manifest$sha256)))
  expect_true(all(file.exists(manifest$local_path)))
  expect_true(all(vapply(seq_len(nrow(manifest)), function(i) {
    identical(
      basename(dirname(manifest$local_path[[i]])),
      manifest$sha256[[i]]
    )
  }, logical(1))))
  expect_true(readreq:::.req_validate_raw_release(manifest))

  options(readreq.transport = function(...) {
    stop("network should not be used for an exact cached release", call. = FALSE)
  })
  repeated <- readreq:::download_req_release(
    "latest",
    cache_dir = cache
  )
  expect_true(all(repeated$release_id == "req-2026-06"))
  expect_equal(repeated$sha256, manifest$sha256)
  expect_equal(repeated$local_path, manifest$local_path)

  options(readreq.transport = phase1_transport)
  latest <- releases[releases$release_id == "req-2026-06", , drop = FALSE]
  revised_transport <- function(
      url,
      mode = c("text", "file"),
      path = NULL) {
    mode <- match.arg(mode)
    if (identical(mode, "file") && grepl("\\.pdf$", url)) {
      writeBin(
        charToRaw("%PDF-1.7\nSecond immutable synthetic revision.\n%%EOF\n"),
        path
      )
      return(list(content_type = "application/pdf", status_code = 200L))
    }
    phase1_transport(url, mode, path)
  }
  options(readreq.transport = revised_transport)
  revised <- readreq:::.req_download_asset(
    latest,
    "report",
    cache,
    refresh = TRUE,
    verify = TRUE
  )
  old_report <- manifest[manifest$asset_type == "report", , drop = FALSE]
  expect_false(identical(revised$sha256, old_report$sha256))
  expect_true(file.exists(old_report$local_path))
  expect_true(file.exists(revised$local_path))
})

test_that("an exact complete raw bundle replays without discovery cache", {
  cache <- tempfile("readreq-phase1-exact-offline-")
  old <- options(readreq.transport = phase1_transport)
  on.exit(options(old), add = TRUE)
  original <- readreq:::download_req_release(
    "req-2026-06", cache_dir = cache
  )
  unlink(file.path(cache, "discovery"), recursive = TRUE)
  options(readreq.transport = function(...) {
    stop("network and discovery are poisoned", call. = FALSE)
  })
  replay <- readreq:::download_req_release(
    "req-2026-06", cache_dir = cache
  )
  expect_equal(replay$asset_type, original$asset_type)
  expect_equal(replay$sha256, original$sha256)
})

test_that("a partial exact cache never masquerades as a complete bundle", {
  cache <- tempfile("readreq-phase1-partial-offline-")
  old <- options(readreq.transport = phase1_transport)
  on.exit(options(old), add = TRUE)
  report <- readreq:::download_req_release(
    "req-2026-06", assets = "report", cache_dir = cache
  )
  unlink(file.path(cache, "discovery"), recursive = TRUE)
  options(readreq.transport = function(...) {
    stop("network and discovery are poisoned", call. = FALSE)
  })
  replay <- readreq:::download_req_release(
    "req-2026-06", assets = "report", cache_dir = cache
  )
  expect_equal(replay$sha256, report$sha256)
  expect_error(
    readreq:::download_req_release(
      "req-2026-06",
      assets = c("forecast", "historical", "report"),
      cache_dir = cache
    ),
    class = "req_download_error"
  )
})

test_that("HTML workbook payloads and transport failures are typed", {
  release <- readreq:::.req_parse_release_page_html(
    phase1_fixture_text(
      "resources-and-energy-quarterly-june-2026.html"
    ),
    paste0(
      "https://www.industry.gov.au/publications/",
      "resources-and-energy-quarterly-june-2026"
    ),
    expected_release_id = "req-2026-06"
  )
  cache <- tempfile("readreq-phase1-invalid-")
  old <- options(readreq.transport = function(
      url,
      mode = c("text", "file"),
      path = NULL) {
    writeBin(
      charToRaw("<!doctype html><html><body>error</body></html>"),
      path
    )
    list(content_type = "text/html", status_code = 200L)
  })
  on.exit(options(old), add = TRUE)

  expect_error(
    readreq:::.req_download_asset(
      release,
      "forecast",
      cache,
      verify = TRUE
    ),
    class = "req_asset_format_error"
  )
  expect_length(
    list.files(file.path(cache, "raw"), pattern = "asset-manifest.json",
      recursive = TRUE
    ),
    0L
  )

  options(readreq.transport = function(...) {
    stop("synthetic connection failure", call. = FALSE)
  })
  expect_error(
    readreq:::.req_download_asset(
      release,
      "report",
      tempfile("readreq-phase1-failure-"),
      verify = TRUE
    ),
    class = "req_download_error"
  )
})

test_that("missing release assets fail with the frozen typed condition", {
  partial <- readreq:::.req_parse_release_page_html(
    phase1_fixture_text("release-missing-historical.html"),
    paste0(
      "https://www.industry.gov.au/publications/",
      "resources-and-energy-quarterly-june-2026"
    ),
    expected_release_id = "req-2026-06"
  )
  expect_error(
    readreq:::.req_download_asset(
      partial,
      "historical",
      tempfile("readreq-phase1-missing-")
    ),
    class = "req_asset_missing_error"
  )
})

test_that("a supplied local asset path is retrieved fully offline", {
  release <- readreq:::.req_parse_release_page_html(
    phase1_fixture_text(
      "resources-and-energy-quarterly-june-2026.html"
    ),
    paste0(
      "https://www.industry.gov.au/publications/",
      "resources-and-energy-quarterly-june-2026"
    ),
    expected_release_id = "req-2026-06"
  )
  local_pdf <- tempfile(fileext = ".pdf")
  writeBin(
    charToRaw("%PDF-1.7\nSupplied local synthetic fixture.\n%%EOF\n"),
    local_pdf
  )
  release$report_url <- local_pdf
  old <- options(readreq.transport = NULL)
  on.exit(options(old), add = TRUE)

  manifest <- readreq:::download_req_release(
    release,
    assets = "report",
    cache_dir = tempfile("readreq-phase1-local-")
  )
  expect_equal(manifest$asset_type, "report")
  expect_equal(manifest$source_url, local_pdf)
  expect_true(file.exists(manifest$local_path))
})
