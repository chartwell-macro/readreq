test_that("packaged example workbooks are installed and preserve the schema", {
  forecast_path <- system.file(
    "extdata", "readreq-example-forecast.xlsx", package = "readreq"
  )
  history_path <- system.file(
    "extdata", "readreq-example-history.xlsx", package = "readreq"
  )
  expect_true(nzchar(forecast_path))
  expect_true(nzchar(history_path))
  expect_true(file.exists(forecast_path))
  expect_true(file.exists(history_path))

  cache <- withr::local_tempdir()
  forecast <- read_req_forecasts(forecast_path, cache_dir = cache)
  history <- read_req_history(history_path, cache_dir = cache)
  schema <- req_observation_schema()

  for (result in list(forecast, history)) {
    expect_identical(class(result), "data.frame")
    expect_identical(names(result), schema$field)
    expect_equal(ncol(result), 35L)
    for (i in seq_len(nrow(schema))) {
      field <- schema$field[[i]]
      type <- schema$type[[i]]
      value <- result[[field]]
      if (identical(type, "character")) {
        expect_true(is.character(value), info = field)
      } else if (identical(type, "double")) {
        expect_true(is.double(value), info = field)
      } else if (identical(type, "Date")) {
        expect_identical(class(value), "Date", info = field)
      } else if (identical(type, "POSIXct<UTC>")) {
        expect_true(inherits(value, "POSIXct"), info = field)
        expect_identical(attr(value, "tzone"), "UTC", info = field)
      } else if (identical(type, "list<character>")) {
        expect_true(is.list(value), info = field)
        expect_true(inherits(value, "AsIs"), info = field)
      } else {
        fail(paste("Unhandled schema type:", type))
      }
    }
    expect_true(is.data.frame(attr(result, "canonical_selection")))
    expect_identical(
      names(attr(result, "canonical_selection")),
      c("observation_key", "presentations", "policy_version", "reason")
    )
  }

  expect_gt(nrow(forecast), 0L)
  expect_gt(nrow(history), 0L)
  expect_identical(unique(forecast$release_id), "req-local")
  expect_identical(unique(history$release_id), "req-local")
  expect_identical(unique(forecast$release_date), as.Date("1970-01-01"))
  expect_identical(unique(history$release_date), as.Date("1970-01-01"))
  expect_true(!is.null(attr(forecast, "canonical_selection")))
  expect_true(!is.null(attr(history, "canonical_selection")))
})
