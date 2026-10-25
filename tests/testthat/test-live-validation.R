test_that("opt-in official workbook regression goldens hold", {
  skip_if(tolower(Sys.getenv("READREQ_LIVE_TESTS")) != "true")
  june <- Sys.getenv(
    "READREQ_JUNE_2026_FORECAST",
    "/tmp/readreq_june2026_forecast.xlsx"
  )
  historical <- Sys.getenv(
    "READREQ_JUNE_2026_HISTORICAL",
    "/tmp/readreq_june2026_historical.xlsx"
  )
  december <- Sys.getenv(
    "READREQ_DEC_2025_FORECAST",
    "/tmp/readreq_dec2025_forecast.xlsx"
  )
  skip_if_not(all(file.exists(c(june, historical, december))))

  cache <- withr::local_tempdir()
  june_release <- list(
    forecast = june,
    release_id = "req-2026-06",
    release_date = as.Date("2026-07-03")
  )
  historical_release <- list(
    historical = historical,
    release_id = "req-2026-06",
    release_date = as.Date("2026-07-03")
  )
  december_release <- list(
    forecast = december,
    release_id = "req-2025-12",
    release_date = as.Date("2025-12-19")
  )
  j_reported <- read_req_forecasts(
    june_release, view = "reported", cache_dir = cache
  )
  j <- read_req_forecasts(
    june_release, view = "canonical", cache_dir = cache
  )
  d <- read_req_forecasts(december_release, cache_dir = cache)
  h_reported <- read_req_history(
    historical_release, view = "reported", cache_dir = cache
  )
  h <- read_req_history(
    historical_release, view = "canonical", cache_dir = cache
  )
  expect_equal(nrow(j_reported), nrow(j))
  expect_equal(nrow(h_reported), nrow(h))
  expect_false(any(duplicated(j$observation_key)))
  expect_false(any(duplicated(h$observation_key)))
  target <- function(x) {
    x[
      x$source_sheet == "Commodity sector" &
        x$commodity == "resources_and_energy" &
        x$period == "2025-26" &
        x$unit == "A$m" &
        x$price_basis == "nominal",
      ,
      drop = FALSE
    ]
  }
  expect_equal(target(d)$value, 382959.866395418, tolerance = 1e-9)
  expect_equal(target(j)$value, 404920.368456527, tolerance = 1e-9)
  expect_identical(target(j)$period_status, "estimate")
  expect_identical(target(j)$status_source, "landing-page")
  expect_match(target(j)$source_note, "estimated at around \\$405 billion")
  revision <- req_forecast_revision(rbind(target(d), target(j)))
  expect_equal(nrow(revision), 1L)
  expect_identical(revision$status_transition, "forecast -> estimate")
  expect_equal(revision$absolute_change, 21960.502061109, tolerance = 1e-9)
  expect_equal(revision$old_issue_date, as.Date("2025-12-19"))
  expect_equal(revision$new_issue_date, as.Date("2026-07-03"))

  aluminium <- h[
    h$table_id == "history_commodity_aluminium" &
      h$period == "1990-Q1" &
      h$concept %in% c(
        "production_smelter_and_refinery_alumina",
        "exports_quantity_alumina_bc",
        "prices_alumina"
      ),
    c("concept", "value"), drop = FALSE
  ]
  expect_equal(
    unname(setNames(aluminium$value, aluminium$concept)[c(
      "production_smelter_and_refinery_alumina",
      "exports_quantity_alumina_bc",
      "prices_alumina"
    )]),
    c(2753.228, 2099.76942, 400),
    tolerance = 1e-9
  )

  gemstones <- h[
    h$table_id == "history_commodity_gemstones" &
      h$period == "1990-Q1" &
      h$concept %in% c(
        "exports_quantity_diamonds_sorted_gem",
        "imports_quantity_diamonds_sorted_gem"
      ),
    c("concept", "value"), drop = FALSE
  ]
  expect_equal(
    unname(setNames(gemstones$value, gemstones$concept)[c(
      "exports_quantity_diamonds_sorted_gem",
      "imports_quantity_diamonds_sorted_gem"
    )]),
    c(254.743, 49.347),
    tolerance = 1e-9
  )

  uranium <- j[
    j$table_id == "forecast_uranium" &
      j$period == "2025" & j$geography == "Russia",
    c("concept", "value"), drop = FALSE
  ]
  expect_equal(
    unname(setNames(uranium$value, uranium$concept)[c(
      "world_production_russia", "world_consumption_russia"
    )]),
    c(3.06628442377136, 7.06880323728),
    tolerance = 1e-12
  )
  lce <- j[j$source_sheet == "Lithium" & j$unit == "kt LCE", , drop = FALSE]
  expect_equal(nrow(lce), 7L)
  expect_true(all(lengths(lce$footnote_codes) > 0L))
  expect_false(any(grepl("\\s+[a-z]{1,3}$", lce$unit)))
  expect_equal(length(readxl::excel_sheets(june)), 23L)
  expect_equal(length(readxl::excel_sheets(historical)), 47L)
  expect_identical(
    digest::digest(file = june, algo = "sha256"),
    "011d09f15d401830845bf9abf13b3bd2e0baf4bc95ea647bdd03246fe83b01fa"
  )
})
