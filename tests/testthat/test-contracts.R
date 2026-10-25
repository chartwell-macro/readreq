test_that("status suffixes are explicit and date position is not inferred", {
  got <- req_status(c(
    "2025-26s", "2026-27F", "2030-31z", "2031-32S", "2032-33Z", "2023-24"
  ))
  expect_equal(
    got$period_status,
    c(
      "estimate", "published-unclassified", "projection",
      "published-unclassified", "published-unclassified",
      "published-unclassified"
    )
  )
  expect_equal(
    got$period,
    c("2025-26", "2026-27", "2030-31", "2031-32", "2032-33", "2023-24")
  )
  expect_equal(
    got$status_source,
    c(rep("suffix", 5L), "unclassified")
  )
})

test_that("missing markers preserve reasons and never become zero", {
  got <- req_missing_reason(c(NA, "", "na", "n/a", "not available", "c", "..", "12"))
  expect_equal(
    got,
    c(
      "blank", "blank", "provider_na", "not_applicable", "unavailable",
      "confidential", "suppressed", NA_character_
    )
  )
  expect_error(req_missing_reason("unexpected text"), class = "req_validation_error")
})

test_that("unit footnote suffixes do not contaminate semantic units", {
  expect_identical(req_normalise_unit("kt LCE a"), "kt LCE")
  expect_identical(req_normalise_unit("LCE kt ea"), "LCE kt")
  expect_identical(req_normalise_unit("US$/t b"), "US$/t")
})

test_that("manifest and observation contracts contain frozen fields", {
  expect_true(all(c(
    "release_id", "release_date", "support_status", "unsupported_reason",
    "discovered_at", "discovery_version"
  ) %in% req_release_manifest_schema()$field))
  expect_true(all(c(
    "sha256", "bytes", "local_path", "validation_status"
  ) %in% req_raw_asset_manifest_schema()$field))
  expect_true(all(c(
    "dataset", "source_dataset", "raw_value", "missing_reason", "series_id",
    "observation_key", "section", "frequency"
  ) %in% req_observation_schema()$field))
})

test_that("catalogue freezes current data and control sheet slots", {
  catalog <- req_source_catalog()
  expect_equal(sum(catalog$source_dataset == "forecast"), 24)
  expect_equal(sum(catalog$source_dataset == "historical"), 48)
  expect_identical(anyDuplicated(catalog$table_id), 0L)
  expect_true(all(catalog$admission_status == "supported"))
  expect_equal(
    catalog$source_label[catalog$source_dataset == "historical"],
    c(
      "Contents", "Data directory", "About", "Controls",
      "1", "2(1)", "2(2)",
      as.character(3:6), "7(1)", "7(2)", as.character(8:23),
      "24(1)", "24(2)", as.character(25:31), "33", "32", "35",
      "34", as.character(36:41)
    )
  )
})

test_that("vintage operation signatures are separate and aligned", {
  common <- c("data", "releases", "series")
  expect_equal(names(formals(req_history_revision)), common)
  expect_equal(names(formals(req_forecast_revision)), common)
  expect_equal(
    names(formals(req_forecast_error)),
    c(common, "realisation")
  )
  expect_error(req_history_revision(data.frame()), class = "req_validation_error")
})

test_that("condition catalogue contains every authoritative class", {
  expected <- c(
    "req_release_discovery_error", "req_release_gap_warning",
    "req_asset_missing_error", "req_download_error",
    "req_asset_format_error", "req_workbook_schema_error",
    "req_sheet_parse_error", "req_period_parse_error",
    "req_unit_conflict_error", "req_stitch_conflict_error",
    "req_validation_error"
  )
  expect_setequal(readreq:::req_condition_catalog()$class, expected)
})
