minimal_vintage <- function(status, release_id, release_date, value) {
  row <- list(
    product = "resources_energy_quarterly",
    release_id = release_id,
    release_date = as.Date(release_date),
    dataset = "resources_energy_quarterly",
    source_dataset = if (status == "historical") "historical" else "forecast",
    source_asset = if (status == "historical") "historical" else "forecast",
    source_sheet = "Synthetic",
    table_id = "synthetic_value",
    table_title = "Synthetic value",
    record_role = "canonical",
    geography_type = "country",
    geography = "Australia",
    commodity = "resources_and_energy",
    concept = "export_value",
    period = "2025-26",
    period_start = as.Date("2025-07-01"),
    period_end = as.Date("2026-06-30"),
    period_basis = "australian_financial_year",
    period_status = status,
    status_source = if (status == "historical") "title" else "suffix",
    price_basis = "nominal",
    currency = "AUD",
    unit = "A$m",
    value = value,
    raw_value = as.character(value),
    missing_reason = NA_character_,
    footnote_codes = I(list(character())),
    source_note = NA_character_,
    series_id = "",
    observation_key = "",
    retrieved_at = as.POSIXct("2026-01-01", tz = "UTC"),
    sha256 = paste(rep(if (status == "historical") "b" else "a", 64), collapse = ""),
    parser_version = "1.0.0",
    section = "Australia",
    frequency = "annual"
  )
  row$series_id <- req_semantic_id(row)
  row$observation_key <- paste(row$series_id, row$period, sep = "::")
  req_observation_frame(list(row))
}

test_that("forecast revision and realisation operations stay separate", {
  f1 <- minimal_vintage("forecast", "req-2025-06", "2025-06-27", 380)
  f2 <- minimal_vintage("forecast", "req-2025-12", "2025-12-19", 383)
  e1 <- minimal_vintage("estimate", "req-2026-06", "2026-06-26", 405)
  h1 <- minimal_vintage("historical", "req-2026-09", "2026-09-25", 410)
  x <- rbind(f1, f2, e1, h1)

  revisions <- req_forecast_revision(x)
  expect_equal(nrow(revisions), 2L)
  expect_equal(revisions$absolute_change, c(3, 22))
  expect_equal(
    revisions$status_transition,
    c("forecast -> forecast", "forecast -> estimate")
  )
  expect_equal(revisions$revision_sequence, c(1L, 2L))
  expect_true(all(nzchar(revisions$selection_rule)))
  expect_true(all(is.finite(revisions$old_issue_to_target_months)))

  first <- req_forecast_error(x, realisation = "first")
  latest <- req_forecast_error(x, realisation = "latest_revised")
  expect_true(all(first$comparison == "forecast_error"))
  expect_true(all(latest$comparison == "latest_revised_error"))
  expect_true(all(first$new_value == 405))
  expect_true(all(latest$new_value == 410))
})

test_that("history revision is not forecast revision", {
  h1 <- minimal_vintage("historical", "req-2026-06", "2026-06-26", 405)
  h2 <- minimal_vintage("historical", "req-2026-09", "2026-09-25", 410)
  out <- req_history_revision(rbind(h1, h2))
  expect_equal(nrow(out), 1L)
  expect_equal(out$absolute_change, 5)
  expect_equal(out$status_transition, "historical -> historical")
})

test_that("current view flags unresolved collisions", {
  a <- minimal_vintage("historical", "req-2026-06", "2026-06-26", 405)
  b <- a
  b$value <- 410
  b$raw_value <- "410"
  b$source_sheet <- "Other presentation"
  out <- req_stitch_current(rbind(a, b))
  expect_true(all(out$record_role == "conflict"))
  expect_equal(nrow(attr(out, "conflicts")), 2L)
})

test_that("within-workbook canonical selection fails on ambiguous values", {
  a <- minimal_vintage("historical", "req-2026-06", "2026-06-26", 405)
  b <- a
  b$value <- 410
  b$raw_value <- "410"
  expect_error(
    req_within_workbook_view(rbind(a, b), "canonical"),
    class = "req_stitch_conflict_error"
  )
  reported <- req_within_workbook_view(rbind(a, b), "reported")
  expect_equal(nrow(reported), 2L)
})

test_that("reviewed supporting presentations preserve the canonical value", {
  a <- minimal_vintage("estimate", "req-2026-06", "2026-06-30", 1.9)
  b <- a
  b$value <- 1.9012233656007904
  b$raw_value <- "1.9012233656007904"
  b$record_role <- "supporting"

  canonical <- req_within_workbook_view(rbind(a, b), "canonical")
  expect_equal(nrow(canonical), 1L)
  expect_equal(canonical$value, 1.9)
  expect_equal(
    attr(canonical, "canonical_selection")$reason,
    "reviewed redundant source-unit presentation"
  )
})

test_that("status-independent current selection prefers completed history", {
  forecast <- minimal_vintage("forecast", "req-2026-06", "2026-06-26", 405)
  historical <- minimal_vintage("historical", "req-2026-06", "2026-06-26", 410)
  out <- req_stitch_current(rbind(forecast, historical))
  expect_equal(nrow(out), 1L)
  expect_identical(out$period_status, "historical")
  expect_identical(out$source_dataset, "historical")
  expect_equal(out$value, 410)
  expect_equal(nrow(attr(out, "conflicts")), 0L)
})
