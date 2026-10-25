public_api_fixture <- function(name) {
  testthat::test_path("fixtures", "workbooks", name)
}

test_that("attribution guidance has a stable public contract", {
  expect_identical(
    req_attribution(),
    list(
      source = paste(
        "Australian Government Department of Industry, Science and Resources,",
        "Resources and Energy Quarterly."
      ),
      source_licence = "CC BY 4.0, subject to source-stated exclusions.",
      exclusions = c(
        "Commonwealth Coat of Arms",
        "trade marks",
        "third-party material"
      ),
      fixture_policy =
        "Reduced/derived synthetic structurally faithful fixtures only.",
      package_code_licence = "MIT"
    )
  )
})

test_that("the default cache path is scalar and side-effect free", {
  path <- req_cache_dir()
  existed <- dir.exists(path)

  expect_type(path, "character")
  expect_length(path, 1L)
  expect_true(nzchar(path))
  expect_identical(path, tools::R_user_dir("readreq", "cache"))
  expect_identical(dir.exists(path), existed)
  expect_identical(req_cache_dir(), path)
})

test_that("release catalogue is static, ordered, and schema-aligned offline", {
  old <- options(readreq.transport = function(...) {
    stop("network should not be used by the static catalogue", call. = FALSE)
  })
  on.exit(options(old), add = TRUE)

  cache <- withr::local_tempdir()
  releases <- list_req_releases(cache_dir = cache)
  refreshed <- list_req_releases(
    refresh = TRUE,
    supported_only = FALSE,
    cache_dir = cache
  )
  supported <- list_req_releases(supported_only = TRUE, cache_dir = cache)

  expect_identical(names(releases), req_release_manifest_schema()$field)
  expect_equal(nrow(releases), 59L)
  expect_equal(releases$release_id, refreshed$release_id)
  expect_equal(releases$release_date, refreshed$release_date)
  expect_equal(releases$asset_roles, refreshed$asset_roles)
  expect_true(all(order(releases$release_date, decreasing = TRUE) ==
    seq_len(nrow(releases))))
  expect_true(all(releases$support_status == "supported"))
  expect_equal(supported$release_id, releases$release_id)
  expect_true(is.character(releases$product))
  expect_true(is.character(releases$release_id))
  expect_s3_class(releases$release_date, "Date")
  expect_true(is.character(releases$edition))
  expect_true(is.character(releases$landing_url))
  expect_true(is.list(releases$asset_roles))
  expect_true(is.character(releases$asset_status))
  expect_true(is.character(releases$support_status))
  expect_s3_class(releases$discovered_at, "POSIXct")
  expect_true(all(vapply(releases$asset_roles, is.character, logical(1))))
})

test_that("read_req preserves the observation contract and current semantics", {
  bundle <- list(
    forecast = public_api_fixture("forecast-all-families.xlsx"),
    historical = public_api_fixture("historical-all-families-wrong-about.xlsx"),
    release_id = "req-local",
    release_date = as.Date("1970-01-01")
  )
  cache <- withr::local_tempdir()
  old <- options(readreq.transport = function(...) {
    stop("network should not be used by a local release bundle", call. = FALSE)
  })
  on.exit(options(old), add = TRUE)

  reported <- read_req(bundle, view = "reported", cache_dir = cache)
  current <- read_req(bundle, view = "current", cache_dir = cache)
  cached_current <- read_req(bundle, view = "current", cache_dir = cache)
  fields <- req_observation_schema()$field

  expect_s3_class(reported, "data.frame")
  expect_s3_class(current, "data.frame")
  expect_identical(names(reported), fields)
  expect_identical(names(current), fields)
  expect_equal(length(fields), 35L)
  for (field in c("product", "release_id", "dataset", "source_dataset",
                  "source_asset", "source_sheet", "table_id", "table_title",
                  "record_role", "geography_type", "geography", "commodity",
                  "concept", "period", "period_basis", "period_status",
                  "status_source", "price_basis", "currency", "unit", "raw_value",
                  "missing_reason", "source_note", "series_id", "observation_key",
                  "sha256", "parser_version", "section", "frequency")) {
    expect_type(reported[[field]], "character")
  }
  expect_type(reported$value, "double")
  expect_s3_class(reported$release_date, "Date")
  expect_s3_class(reported$period_start, "Date")
  expect_s3_class(reported$period_end, "Date")
  expect_s3_class(reported$retrieved_at, "POSIXct")
  expect_true(is.list(reported$footnote_codes))
  expect_true(is.data.frame(attr(reported, "canonical_selection")))
  expect_true(is.data.frame(attr(current, "canonical_selection")))
  expect_true(is.data.frame(attr(current, "conflicts")))
  expect_equal(nrow(attr(current, "conflicts")), 0L)
  expect_gt(nrow(reported), nrow(current))
  expect_true(any(reported$record_role == "supporting"))
  expect_identical(anyDuplicated(current$observation_key), 0L)
  expect_true(all(current$record_role == "canonical"))
  expect_identical(cached_current, current)
})

test_that("series catalogue is stable and cache-replayable for a local bundle", {
  bundle <- list(
    forecast = public_api_fixture("forecast-all-families.xlsx"),
    historical = public_api_fixture("historical-all-families-wrong-about.xlsx"),
    release_id = "req-local",
    release_date = as.Date("1970-01-01")
  )
  cache <- withr::local_tempdir()
  first <- req_series_catalog(bundle, cache_dir = cache)
  second <- req_series_catalog(bundle, cache_dir = cache)

  expect_identical(
    names(first),
    c(
      "series_id", "commodity", "concept", "geography", "frequency",
      "period_basis", "period_status", "price_basis", "currency", "unit",
      "first_period", "last_period", "observations", "source_datasets"
    )
  )
  expect_s3_class(first, "data.frame")
  expect_gt(nrow(first), 0L)
  expect_identical(anyDuplicated(first$series_id), 0L)
  expect_true(all(order(first$commodity, first$concept, first$series_id) ==
    seq_len(nrow(first))))
  expect_type(first$series_id, "character")
  expect_type(first$commodity, "character")
  expect_type(first$concept, "character")
  expect_type(first$geography, "character")
  expect_type(first$frequency, "character")
  expect_type(first$period_basis, "character")
  expect_type(first$period_status, "character")
  expect_type(first$price_basis, "character")
  expect_type(first$currency, "character")
  expect_type(first$unit, "character")
  expect_type(first$first_period, "character")
  expect_type(first$last_period, "character")
  expect_type(first$observations, "integer")
  expect_type(first$source_datasets, "character")
  expect_identical(second, first)
})

public_api_vintage <- function(status, release_id, release_date, value) {
  data.frame(
    product = "synthetic_product",
    release_id = release_id,
    release_date = as.Date(release_date),
    dataset = "synthetic_dataset",
    section = "Synthetic",
    geography_type = "country",
    geography = "Synthetic",
    commodity = "synthetic_commodity",
    concept = "synthetic_concept",
    frequency = "annual",
    period = "2025",
    period_basis = "calendar_year",
    period_status = status,
    status_source = "synthetic",
    price_basis = "nominal",
    currency = "AUD",
    unit = "units",
    value = as.numeric(value),
    series_id = "synthetic-series",
    observation_key = "synthetic-series::2025",
    period_start = as.Date("2025-01-01"),
    period_end = as.Date("2025-12-31"),
    sha256 = paste0("sha-", release_id),
    source_dataset = "synthetic",
    source_sheet = "synthetic",
    stringsAsFactors = FALSE
  )
}

test_that("vintage wrapper returns named families and single-family frames", {
  observations <- do.call(rbind, list(
    public_api_vintage("forecast", "fixture-a", "2024-06-01", 10),
    public_api_vintage("forecast", "fixture-b", "2024-12-01", 11),
    public_api_vintage("estimate", "fixture-c", "2025-06-01", 12),
    public_api_vintage("historical", "fixture-d", "2025-12-01", 13)
  ))

  all_comparisons <- compare_req_vintages(
    data = observations,
    comparison = "all"
  )
  forecast_only <- compare_req_vintages(
    data = observations,
    comparison = "forecast_revision"
  )
  history_only <- compare_req_vintages(
    data = observations,
    comparison = "history_revision"
  )

  expect_named(
    all_comparisons,
    c("history_revision", "forecast_revision", "forecast_error")
  )
  expect_true(all(vapply(all_comparisons, is.data.frame, logical(1))))
  expect_identical(
    all_comparisons$history_revision$comparison,
    "history_revision"
  )
  expect_identical(
    all_comparisons$forecast_revision$comparison,
    rep("forecast_revision", 2L)
  )
  expect_identical(
    all_comparisons$forecast_error$comparison,
    rep("forecast_error", 2L)
  )
  expect_s3_class(forecast_only, "data.frame")
  expect_identical(forecast_only, all_comparisons$forecast_revision)
  expect_s3_class(history_only, "data.frame")
  expect_identical(history_only, all_comparisons$history_revision)
})

test_that("vintage wrapper rejects insufficient releases without data", {
  expect_error(
    compare_req_vintages(
      releases = "fixture-a",
      comparison = "forecast_revision"
    ),
    class = "req_validation_error"
  )
  expect_error(
    compare_req_vintages(
      data = data.frame(),
      comparison = "not-a-comparison"
    ),
    regexp = "one of"
  )
})
