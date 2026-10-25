fixture_workbook <- function(name) {
  testthat::test_path("fixtures", "workbooks", name)
}

test_that("all forecast sheets classify and every parser path returns data", {
  path <- fixture_workbook("forecast-all-families.xlsx")
  meta <- list(release_id = "req-2026-06", release_date = as.Date("2026-06-30"))
  map <- req_map_workbook(path, "forecast")
  expect_equal(nrow(map), 23L)
  expect_equal(sum(map$classification == "data_table"), 21L)
  expect_equal(anyDuplicated(map$table_id), 0L)

  out <- req_parse_workbook(path, "forecast", meta)
  expect_equal(length(unique(out$source_sheet)), 21L)
  expect_setequal(unique(out$period_status), c(
    "published-unclassified", "estimate", "forecast", "projection"
  ))
  expect_true(any(is.na(out$value) & out$missing_reason == "provider_na"))
  expect_true(all(grepl("Third-party synthetic label", out$source_note)))
  expect_true(any(lengths(out$footnote_codes) > 0L))
  expect_false(any(is.na(out$series_id) | out$series_id == ""))
})

test_that("sheet order never selects parser semantics", {
  meta <- list(release_id = "req-2026-06", release_date = as.Date("2026-06-30"))
  regular <- req_parse_workbook(
    fixture_workbook("forecast-all-families.xlsx"), "forecast", meta
  )
  shuffled <- req_parse_workbook(
    fixture_workbook("forecast-shuffled.xlsx"), "forecast", meta
  )
  key <- c("table_id", "commodity", "concept", "period", "period_status", "value")
  regular <- regular[do.call(order, regular[key]), key]
  shuffled <- shuffled[do.call(order, shuffled[key]), key]
  rownames(regular) <- rownames(shuffled) <- NULL
  expect_equal(regular, shuffled)
})

test_that("numeric cells outside recognised blocks fail loudly", {
  meta <- list(release_id = "req-2026-06", release_date = as.Date("2026-06-30"))
  expect_error(
    req_parse_workbook(
      fixture_workbook("forecast-unmapped-numeric.xlsx"), "forecast", meta
    ),
    class = "req_sheet_parse_error",
    regexp = "outside every recognised data/control block"
  )
  expect_error(
    req_parse_workbook(
      fixture_workbook("forecast-unmapped-marker.xlsx"), "forecast", meta
    ),
    class = "req_sheet_parse_error",
    regexp = "outside every recognised data/control block"
  )
})

test_that("all historical sheets including split labels classify and parse", {
  path <- fixture_workbook("historical-all-families-wrong-about.xlsx")
  meta <- list(release_id = "req-2026-06", release_date = as.Date("2026-06-30"))
  map <- req_map_workbook(path, "historical")
  expect_equal(nrow(map), 47L)
  expect_equal(sum(map$classification == "data_table"), 44L)
  expect_true(all(c("2(1)", "2(2)", "7(1)", "7(2)", "24(1)", "24(2)") %in%
    map$source_sheet))

  out <- req_parse_workbook(path, "historical", meta)
  expect_equal(length(unique(out$source_sheet)), 44L)
  expect_true(all(c("annual", "monthly") %in% out$frequency))
  expect_true(any(out$table_id == "history_monthly_benchmark_prices"))
  expect_true(any(is.na(out$value) & out$missing_reason == "provider_na"))
  expect_true(all(grepl("Third-party synthetic label", out$source_note)))
})

test_that("landing-page identity wins over a wrong About sheet", {
  bundle <- list(
    historical = fixture_workbook("historical-all-families-wrong-about.xlsx"),
    release_id = "req-2026-06",
    release_date = as.Date("2026-06-30")
  )
  report <- validate_req_release(bundle, cache_dir = withr::local_tempdir())
  expect_identical(report$release_id, "req-2026-06")
  expect_match(report$internal_metadata_discrepancies, "differs")
  expect_true(report$valid)
  expect_identical(report$validation_status, "valid")
  expect_true(file.exists(report$cache_path))
  cached <- readRDS(report$cache_path)
  expect_s3_class(cached, "req_validation_report")
  expect_identical(cached$valid, report$valid)
})

test_that("public local-file readers remain offline", {
  cache <- withr::local_tempdir()
  forecast <- read_req_forecasts(
    fixture_workbook("forecast-all-families.xlsx"), cache_dir = cache
  )
  history <- read_req_history(
    fixture_workbook("historical-all-families-wrong-about.xlsx"),
    cache_dir = cache
  )
  expect_s3_class(forecast, "data.frame")
  expect_s3_class(history, "data.frame")
  expect_true(all(req_observation_schema()$field %in% names(forecast)))
})

test_that("reported and canonical workbook views have real semantics", {
  path <- fixture_workbook("forecast-all-families.xlsx")
  cache <- withr::local_tempdir()
  reported <- read_req_forecasts(path, view = "reported", cache_dir = cache)
  canonical <- read_req_forecasts(path, view = "canonical", cache_dir = cache)
  expect_gt(nrow(reported), nrow(canonical))
  expect_true(any(reported$record_role == "supporting"))
  expect_false(any(duplicated(canonical$observation_key)))
  expect_equal(
    sort(unique(reported$observation_key)),
    sort(canonical$observation_key)
  )
})

test_that("full month-name periods retain monthly semantics", {
  period <- req_period(
    c("January 1990", "February 1990", "March 1990"),
    frequency_hint = "monthly"
  )
  expect_equal(period$period, c("1990-01", "1990-02", "1990-03"))
  expect_equal(period$frequency, rep("monthly", 3L))
  expect_equal(period$period_basis, rep("month", 3L))
})

test_that("legacy helper suffixes are narrowly classified as controls", {
  expect_true(req_structural_period_control(
    c("\u201311", "\u201312", "\u201313", "\u201314"),
    label = "", unit = "", first_data_row = TRUE
  ))
  expect_false(req_structural_period_control(
    c("\u201311", "\u201312", "\u201313", "\u201314"),
    label = "Production", unit = "", first_data_row = TRUE
  ))
  expect_false(req_structural_period_control(
    c("\u201311", "\u201312", "\u201313", "\u201314"),
    label = "", unit = "", first_data_row = FALSE
  ))
  expect_false(req_structural_period_control(
    c("-11.3", "-12.4", "-13.5", "-14.6"),
    label = "", unit = "", first_data_row = TRUE
  ))
})

test_that("legacy page sentinels cannot become measures or observations", {
  expect_true(req_structural_period_control(
    rep("-1-", 7L), label = "", unit = "", first_data_row = FALSE
  ))
  expect_false(req_structural_period_control(
    rep("-1", 7L), label = "", unit = "", first_data_row = FALSE
  ))
  mat <- matrix("", nrow = 4L, ncol = 4L)
  mat[1, 3:4] <- "-1-"
  mat[2, 3:4] <- c("2017", "2018")
  mat[2, 2] <- "Unit"
  mat[3, 1:2] <- c("Production", "Mt")
  mat[3, 3:4] <- c("10", "11")
  blocks <- req_header_blocks(mat, "forecast_commodity")
  expect_equal(length(blocks), 1L)
  expect_identical(blocks[[1]]$measure, "")
})

test_that("XLSX control profiles are exact and workbook-metadata-backed", {
  workbook <- xml2::read_xml(paste0(
    "<workbook><definedNames>",
    "<definedName name=\"_xlnm.Print_Area\" localSheetId=\"0\">",
    "'Commodity sector'!$A$2:$I$4",
    "</definedName></definedNames></workbook>"
  ))
  worksheet <- xml2::read_xml(paste0(
    "<worksheet><sheetData>",
    "<row r=\"1\"/><row r=\"2\" hidden=\"1\"/>",
    "<row r=\"3\"/><row r=\"4\"/><row r=\"5\"/>",
    "</sheetData></worksheet>"
  ))
  layout <- req_xlsx_layout_rows(workbook, worksheet, sheet_index = 1L)
  expect_identical(layout$hidden_rows, 2L)
  expect_identical(layout$max_print_row, 4L)

  gold <- req_control_row_profile(
    "req-2020-09", "27", "history_commodity_gold",
    "ca704169327d662a45e28d19788f23557aefc159784ca823e468ba44aea2885b"
  )
  expect_identical(gold$rows, 46:47)
  expect_true(gold$requires_blank_context)
  expect_null(req_control_row_profile(
    "req-2020-09", "27", "history_commodity_gold",
    paste0("changed-", gold$fingerprint)
  ))
})

test_that("release gate rejects unparsed cells and unknown semantic values", {
  path <- fixture_workbook("forecast-all-families.xlsx")
  meta <- list(release_id = "req-2026-06", release_date = as.Date("2026-06-30"))
  parsed <- req_parse_workbook(path, "forecast", meta)
  diagnostics <- attr(parsed, "parse_diagnostics")
  diagnostics$period_cells[[1]] <- diagnostics$period_cells[[1]] + 1L
  parsed$unit[[1]] <- "unknown"
  duplicate <- parsed[1, , drop = FALSE]
  duplicate$value[[1]] <- duplicate$value[[1]] + 1
  duplicate$raw_value[[1]] <- as.character(duplicate$value[[1]])
  parsed <- rbind(parsed, duplicate)
  attr(parsed, "parse_diagnostics") <- diagnostics
  mapping <- attr(parsed, "sheet_mapping")
  if (is.null(mapping)) mapping <- req_map_workbook(path, "forecast")
  mapping$source_dataset <- "forecast"
  report <- req_validation_artifact(
    list(forecast = parsed), list(forecast = mapping)
  )
  expect_false(report$valid)
  expect_contains(report$failure_reasons, "unparsed_nonempty_cells")
  expect_contains(report$failure_reasons, "unknown_units")
  expect_contains(report$failure_reasons, "duplicate_observation_keys")
  expect_gt(nrow(report$unparsed_nonempty_cells), 0L)
  expect_gt(nrow(report$unknown_units), 0L)
})
