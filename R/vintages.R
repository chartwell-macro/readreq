req_vintage_data <- function(data, releases = NULL, series = NULL) {
  required <- c(
    "release_id", "release_date", "series_id", "observation_key",
    "period_status", "period", "period_basis", "price_basis", "currency",
    "unit", "geography", "value", "sha256", "period_start", "period_end",
    "status_source", "source_dataset", "source_sheet"
  )
  missing <- setdiff(required, names(data))
  if (length(missing)) {
    req_abort(
      "req_validation_error",
      paste0("Vintage data is missing required fields: ", paste(missing, collapse = ", ")),
      remediation = "Pass observations returned by readreq."
    )
  }
  if (!is.null(releases)) data <- data[data$release_id %in% releases, , drop = FALSE]
  if (!is.null(series)) data <- data[data$series_id %in% series, , drop = FALSE]
  data$release_date <- as.Date(data$release_date)
  data
}

req_comparison_key <- function(data) {
  req_status_independent_key(data)
}

req_assert_vintage_unique <- function(data) {
  key <- paste(data$release_id, req_comparison_key(data), sep = "\u001e")
  if (anyDuplicated(key)) {
    req_abort(
      "req_validation_error",
      "Vintage comparison join is non-unique within a release.",
      remediation = "Resolve source presentation duplicates before comparing vintages."
    )
  }
  invisible(data)
}

req_horizon_months <- function(issue_date, target_end) {
  round(as.numeric(as.Date(target_end) - as.Date(issue_date)) / 30.4375, 2)
}

req_pair_rows <- function(
    old, new, operation, selection_rule = NA_character_,
    revision_sequence = NA_integer_, old_sequence = NA_integer_,
    new_sequence = NA_integer_) {
  change <- new$value - old$value
  pct <- ifelse(is.na(old$value) | old$value == 0, NA_real_, change / abs(old$value) * 100)
  data.frame(
    comparison = operation,
    comparison_key = req_comparison_key(old),
    period = old$period,
    target_period = old$period,
    target_period_start = old$period_start,
    target_period_end = old$period_end,
    old_release_id = old$release_id,
    new_release_id = new$release_id,
    old_release_date = old$release_date,
    new_release_date = new$release_date,
    old_issue_date = old$release_date,
    new_issue_date = new$release_date,
    old_issue_to_target_months = req_horizon_months(
      old$release_date, old$period_end
    ),
    new_issue_to_target_months = req_horizon_months(
      new$release_date, new$period_end
    ),
    revision_sequence = revision_sequence,
    old_comparable_sequence = old_sequence,
    new_comparable_sequence = new_sequence,
    comparable_vintage_gap = if (
      is.na(old_sequence) || is.na(new_sequence)
    ) NA_integer_ else new_sequence - old_sequence,
    selection_rule = selection_rule,
    old_series_id = old$series_id,
    new_series_id = new$series_id,
    old_status = old$period_status,
    new_status = new$period_status,
    old_status_source = old$status_source,
    new_status_source = new$status_source,
    old_source_dataset = old$source_dataset,
    new_source_dataset = new$source_dataset,
    old_source_sheet = old$source_sheet,
    new_source_sheet = new$source_sheet,
    status_transition = paste(old$period_status, new$period_status, sep = " -> "),
    old_value = old$value,
    new_value = new$value,
    absolute_change = change,
    percentage_change = pct,
    unit = old$unit,
    currency = old$currency,
    price_basis = old$price_basis,
    period_basis = old$period_basis,
    old_sha256 = old$sha256,
    new_sha256 = new$sha256,
    stringsAsFactors = FALSE
  )
}

#' Compare historical observations across REQ vintages
#'
#' Compare observations whose status is already `"historical"` or
#' `"estimate"` across successive release vintages.  This operation is for
#' revisions to realised values; rows marked `"forecast"` or `"projection"`
#' are not included.
#'
#' @param data A data frame of observations, normally returned by
#'   [read_req()], [read_req_forecasts()], or [read_req_history()].  It must
#'   contain `release_id`, `release_date`, `series_id`, `observation_key`,
#'   `period_status`, `period`, `period_basis`, `price_basis`, `currency`,
#'   `unit`, `geography`, `value`, `sha256`, `period_start`, `period_end`,
#'   `status_source`, `source_dataset`, and `source_sheet`.  The comparison
#'   functions coerce `release_date` with [as.Date()]; the other columns are
#'   expected to retain the classes used by the observation schema.
#' @param releases An optional character vector of release IDs.  When
#'   supplied, observations whose `release_id` is not in this vector are
#'   removed before comparison.  Unknown IDs therefore produce an empty
#'   result rather than a download.
#' @param series An optional character vector of semantic `series_id` values.
#'   When supplied, observations whose `series_id` is not in this vector are
#'   removed before comparison.  This filter is applied before the
#'   status-independent comparison key is built.
#' @details
#'   A comparison key is formed from the available semantic dimensions in
#'   this order: `product`, `dataset`, `section`, `geography_type`,
#'   `geography`, `commodity`, `concept`, `frequency`, `period`,
#'   `period_basis`, `price_basis`, `currency`, and `unit`.  Missing
#'   dimensions are omitted.  `period_status`, `release_id`, and `series_id`
#'   are not part of this key; the `series` argument is the way to select a
#'   semantic series explicitly.  At most one row may occur for each
#'   release/key pair.  Duplicate rows raise a `req_validation_error`.
#'
#'   Within each key, rows are ordered by `release_date` and then
#'   `release_id`; the result contains one row for each adjacent pair.  Key
#'   groups are emitted in base R's `split()` ordering.  `revision_sequence`
#'   starts at one within each key group, while
#'   `old_comparable_sequence` and `new_comparable_sequence` identify the
#'   adjacent rows in that group's chronological order.  This function does
#'   not access the network or write a cache.
#' @return For a non-empty input, a base `data.frame` with one row per
#'   adjacent historical/estimate pair and these columns, in order:
#'   `comparison`, `comparison_key`, `period`, `target_period`,
#'   `target_period_start`, `target_period_end`, `old_release_id`,
#'   `new_release_id`, `old_release_date`, `new_release_date`,
#'   `old_issue_date`, `new_issue_date`, `old_issue_to_target_months`,
#'   `new_issue_to_target_months`, `revision_sequence`,
#'   `old_comparable_sequence`, `new_comparable_sequence`,
#'   `comparable_vintage_gap`, `selection_rule`, `old_series_id`,
#'   `new_series_id`, `old_status`, `new_status`, `old_status_source`,
#'   `new_status_source`, `old_source_dataset`, `new_source_dataset`,
#'   `old_source_sheet`, `new_source_sheet`, `status_transition`,
#'   `old_value`, `new_value`, `absolute_change`, `percentage_change`,
#'   `unit`, `currency`, `price_basis`, `period_basis`, `old_sha256`, and
#'   `new_sha256`.  In observation frames returned by readreq, release and
#'   issue date columns are `Date`, horizon and value/change columns are
#'   numeric, sequence and gap columns are integer, and labels/provenance are
#'   character; `target_period_start` and `target_period_end` retain their
#'   input classes.  `absolute_change` is `new_value - old_value`, and
#'   `percentage_change` is that change divided by `abs(old_value)` times
#'   100, or `NA` when the old value is missing or zero.  If no pair remains
#'   after filtering, the function returns `data.frame()` with zero rows and
#'   zero columns.
#' @seealso [req_forecast_revision()] for forecast-to-vintage changes,
#'   [req_forecast_error()] for forecast-to-realisation comparisons, and
#'   [compare_req_vintages()] for selecting a comparison family.
#' @examples
#' # This small in-memory frame is synthetic and exercises the public contract
#' # without downloading an official release.
#' make_vintage <- function(status, id, date, value) {
#'   data.frame(
#'     release_id = id, release_date = as.Date(date),
#'     series_id = "synthetic-series", observation_key = "synthetic-series::2025",
#'     period_status = status, period = "2025", period_basis = "calendar_year",
#'     price_basis = "nominal", currency = "AUD", unit = "units",
#'     geography = "synthetic", value = value,
#'     sha256 = paste0("sha-", id), period_start = as.Date("2025-01-01"),
#'     period_end = as.Date("2025-12-31"), status_source = "synthetic",
#'     source_dataset = "synthetic", source_sheet = "synthetic",
#'     stringsAsFactors = FALSE
#'   )
#' }
#' vintage_observations <- do.call(rbind, list(
#'   make_vintage("forecast", "fixture-a", "2024-06-01", 10),
#'   make_vintage("forecast", "fixture-b", "2024-12-01", 11),
#'   make_vintage("estimate", "fixture-c", "2025-06-01", 12),
#'   make_vintage("historical", "fixture-d", "2025-12-01", 13)
#' ))
#' req_history_revision(vintage_observations)
#' @export
req_history_revision <- function(data, releases = NULL, series = NULL) {
  x <- req_vintage_data(data, releases, series)
  x <- x[x$period_status %in% c("historical", "estimate"), , drop = FALSE]
  req_assert_vintage_unique(x)
  key <- req_comparison_key(x)
  groups <- split(seq_len(nrow(x)), key)
  out <- lapply(groups, function(i) {
    z <- x[i, , drop = FALSE]
    z <- z[order(z$release_date, z$release_id), , drop = FALSE]
    if (nrow(z) < 2L) return(NULL)
    do.call(rbind, lapply(seq_len(nrow(z) - 1L), function(j) {
      req_pair_rows(z[j, , drop = FALSE], z[j + 1L, , drop = FALSE],
        "history_revision",
        selection_rule = "consecutive comparable non-forecast vintages",
        revision_sequence = j, old_sequence = j, new_sequence = j + 1L
      )
    }))
  })
  out <- Filter(Negate(is.null), out)
  if (!length(out)) return(data.frame())
  do.call(rbind, out)
}

#' Compare forecasts across REQ vintages
#'
#' Compare each earlier `"forecast"` or `"projection"` observation with the
#' next later comparable vintage for the same status-independent key.  The
#' later row may itself be a forecast, projection, estimate, or historical
#' observation; use [req_forecast_error()] when the target must be a realised
#' observation.
#'
#' @inheritParams req_history_revision
#' @details
#'   Rows are ordered by `release_date` and then `release_id` within each
#'   comparison key.  Every forecast/projection row except the final row in a
#'   key group is paired with the immediately following row.  Thus a forecast
#'   can be compared with a later forecast as well as with a later estimate or
#'   historical observation.  `revision_sequence` starts at one for each key
#'   group; the comparable sequence columns refer to positions in the full
#'   chronological group.  Missing values are allowed, but pairs with a
#'   missing or zero old value have `NA` `percentage_change`.  No network or
#'   cache access occurs.  Missing required columns or duplicate rows within
#'   a release/key pair raise a `req_validation_error`, as documented for
#'   [req_history_revision()].
#' @return A non-empty base `data.frame` with one row per selected pair and
#'   the same columns, classes, ordering, change calculations, and empty
#'   result contract documented for [req_history_revision()].  The
#'   `comparison` column is `"forecast_revision"`, and `selection_rule`
#'   records the forecast/projection-to-next-vintage rule.  If no eligible
#'   pair remains, returns `data.frame()` with zero rows and zero columns.
#' @seealso [req_history_revision()] for realised-value revisions and
#'   [req_forecast_error()] for forecast errors.
#' @examples
#' # Use the same synthetic shape as the other vintage helpers; no network
#' # request is made by this function.
#' make_vintage <- function(status, id, date, value) {
#'   data.frame(
#'     release_id = id, release_date = as.Date(date),
#'     series_id = "synthetic-series", observation_key = "synthetic-series::2025",
#'     period_status = status, period = "2025", period_basis = "calendar_year",
#'     price_basis = "nominal", currency = "AUD", unit = "units",
#'     geography = "synthetic", value = value,
#'     sha256 = paste0("sha-", id), period_start = as.Date("2025-01-01"),
#'     period_end = as.Date("2025-12-31"), status_source = "synthetic",
#'     source_dataset = "synthetic", source_sheet = "synthetic",
#'     stringsAsFactors = FALSE
#'   )
#' }
#' vintage_observations <- do.call(rbind, list(
#'   make_vintage("forecast", "fixture-a", "2024-06-01", 10),
#'   make_vintage("forecast", "fixture-b", "2024-12-01", 11),
#'   make_vintage("estimate", "fixture-c", "2025-06-01", 12),
#'   make_vintage("historical", "fixture-d", "2025-12-01", 13)
#' ))
#' req_forecast_revision(vintage_observations)
#' @export
req_forecast_revision <- function(data, releases = NULL, series = NULL) {
  x <- req_vintage_data(data, releases, series)
  req_assert_vintage_unique(x)
  groups <- split(seq_len(nrow(x)), req_comparison_key(x))
  out <- lapply(groups, function(i) {
    z <- x[i, , drop = FALSE]
    z <- z[order(z$release_date, z$release_id), , drop = FALSE]
    if (nrow(z) < 2L) return(NULL)
    eligible <- which(
      seq_len(nrow(z)) < nrow(z) &
        z$period_status %in% c("forecast", "projection")
    )
    if (!length(eligible)) return(NULL)
    do.call(rbind, lapply(seq_along(eligible), function(sequence) {
      j <- eligible[[sequence]]
      req_pair_rows(z[j, , drop = FALSE], z[j + 1L, , drop = FALSE],
        "forecast_revision",
        selection_rule = paste0(
          "earlier forecast/projection to next later comparable vintage"
        ),
        revision_sequence = sequence,
        old_sequence = j, new_sequence = j + 1L
      )
    }))
  })
  out <- Filter(Negate(is.null), out)
  if (!length(out)) return(data.frame())
  do.call(rbind, out)
}

#' Compare REQ forecasts with realised observations
#'
#' Compare each `"forecast"` or `"projection"` observation with a later
#' `"estimate"` or `"historical"` observation for the same
#' status-independent key.  This makes it possible to measure either the
#' first available realisation or the latest revision of that realisation.
#'
#' @inheritParams req_history_revision
#' @param realisation A character choice of `"first"` or
#'   `"latest_revised"`.  `"first"` selects the earliest later release whose
#'   status is `"estimate"` or `"historical"`; `"latest_revised"` selects the
#'   latest such release.  Release dates must be strictly later than the
#'   forecast's release date.
#' @details
#'   Within each comparison key, rows are ordered by `release_date` and then
#'   `release_id`.  Each forecast/projection row is considered independently.
#'   The selected realisation must occur at a strictly later release date;
#'   another row with the same release date is not eligible.  Output rows are
#'   emitted by comparison-key order and then forecast chronology.  The
#'   `revision_sequence` counter is global across the emitted rows, whereas
#'   the comparable sequence columns identify positions in each key group.
#'   This function does not access the network or write a cache.  An invalid
#'   `realisation` raises the standard `match.arg()` error.  Missing required
#'   columns or duplicate rows within a release/key pair raise a
#'   `req_validation_error`.
#' @return For a non-empty result, a base `data.frame` with the same columns
#'   and classes as [req_history_revision()], except that `absolute_change`
#'   is renamed to `error` and `percentage_change` is renamed to
#'   `percentage_error`.  The `comparison` column is `"forecast_error"` for
#'   `realisation = "first"` and `"latest_revised_error"` for
#'   `realisation = "latest_revised"`; `error` is `new_value - old_value`.
#'   If no forecast has an eligible realisation, returns `data.frame()` with
#'   zero rows and zero columns.
#' @seealso [req_forecast_revision()] for forecast-to-vintage changes and
#'   [compare_req_vintages()] for selecting the family.
#' @examples
#' make_vintage <- function(status, id, date, value) {
#'   data.frame(
#'     release_id = id, release_date = as.Date(date),
#'     series_id = "synthetic-series", observation_key = "synthetic-series::2025",
#'     period_status = status, period = "2025", period_basis = "calendar_year",
#'     price_basis = "nominal", currency = "AUD", unit = "units",
#'     geography = "synthetic", value = value,
#'     sha256 = paste0("sha-", id), period_start = as.Date("2025-01-01"),
#'     period_end = as.Date("2025-12-31"), status_source = "synthetic",
#'     source_dataset = "synthetic", source_sheet = "synthetic",
#'     stringsAsFactors = FALSE
#'   )
#' }
#' vintage_observations <- do.call(rbind, list(
#'   make_vintage("forecast", "fixture-a", "2024-06-01", 10),
#'   make_vintage("forecast", "fixture-b", "2024-12-01", 11),
#'   make_vintage("estimate", "fixture-c", "2025-06-01", 12),
#'   make_vintage("historical", "fixture-d", "2025-12-01", 13)
#' ))
#' req_forecast_error(vintage_observations, realisation = "first")
#' req_forecast_error(vintage_observations, realisation = "latest_revised")
#' @export
req_forecast_error <- function(
    data, releases = NULL, series = NULL,
    realisation = c("first", "latest_revised")) {
  realisation <- match.arg(realisation)
  x <- req_vintage_data(data, releases, series)
  req_assert_vintage_unique(x)
  groups <- split(seq_len(nrow(x)), req_comparison_key(x))
  result <- list()
  k <- 0L
  for (i in groups) {
    z <- x[i, , drop = FALSE]
    z <- z[order(z$release_date, z$release_id), , drop = FALSE]
    forecasts <- which(z$period_status %in% c("forecast", "projection"))
    for (f in forecasts) {
      realised <- which(
        seq_len(nrow(z)) > f &
          z$release_date > z$release_date[[f]] &
          z$period_status %in% c("estimate", "historical")
      )
      if (!length(realised)) next
      r <- if (realisation == "first") min(realised) else max(realised)
      operation <- if (realisation == "first") {
        "forecast_error"
      } else {
        "latest_revised_error"
      }
      k <- k + 1L
      result[[k]] <- req_pair_rows(
        z[f, , drop = FALSE], z[r, , drop = FALSE], operation,
        selection_rule = if (realisation == "first") {
          "forecast/projection to first later estimate/historical observation"
        } else {
          "forecast/projection to latest later estimate/historical observation"
        },
        revision_sequence = k, old_sequence = f, new_sequence = r
      )
      names(result[[k]])[names(result[[k]]) == "absolute_change"] <- "error"
      names(result[[k]])[names(result[[k]]) == "percentage_change"] <- "percentage_error"
    }
  }
  if (!length(result)) return(data.frame())
  do.call(rbind, result)
}

#' Compare REQ vintages
#'
#' Dispatch to one vintage-comparison family, or to all three families in a
#' fixed order.  Supplying parsed observations keeps the operation offline;
#' omitting `data` loads each requested release with [read_req()] using the
#' current view.
#'
#' @param data An optional already parsed multi-vintage observation data
#'   frame.  It must satisfy the required-column contract documented for
#'   [req_history_revision()].  If supplied, no release is downloaded and
#'   `cache_dir` is not evaluated or used.
#' @param releases A character vector of release IDs.  When `data` is
#'   supplied, it filters that frame by `release_id`.  When `data` is `NULL`,
#'   it must contain at least two IDs; each is passed to [read_req()] with
#'   `view = "current"` and the results are combined before comparison.
#' @param series An optional character vector of semantic `series_id` values
#'   to pass to the selected comparison function.
#' @param comparison One of `"all"`, `"history_revision"`,
#'   `"forecast_revision"`, or `"forecast_error"`.  The default `"all"`
#'   returns every family in the order documented below.
#' @param cache_dir A cache root passed to [read_req()] when `data` is
#'   `NULL`.  Loading releases can read and write the normal readreq cache and
#'   can access the network according to [read_req()]'s rules.  It has no
#'   effect when `data` is supplied.
#' @details
#'   `comparison = "all"` returns a named list with exactly these names and
#'   order: `history_revision`, `forecast_revision`, `forecast_error`.  Each
#'   component follows the corresponding function's output contract,
#'   including its zero-row/zero-column empty result.  A single comparison
#'   returns that component directly as a data frame.  If `data` is `NULL` and
#'   fewer than two release IDs are supplied, a `req_validation_error` is
#'   raised.  Invalid `comparison` values raise the standard `match.arg()`
#'   error; errors from release discovery, transport, parsing, or validation
#'   are propagated from the selected reader.
#' @return A data frame for one comparison family, or (for `comparison =
#'   "all"`) a named list of three data frames in the order
#'   `history_revision`, `forecast_revision`, `forecast_error`.
#' @seealso [req_history_revision()], [req_forecast_revision()],
#'   [req_forecast_error()], and [read_req()].
#' @examples
#' # Parsed data can be dispatched without network access.  The frame is
#' # synthetic and contains no claim about an official release.
#' make_vintage <- function(status, id, date, value) {
#'   data.frame(
#'     release_id = id, release_date = as.Date(date),
#'     series_id = "synthetic-series", observation_key = "synthetic-series::2025",
#'     period_status = status, period = "2025", period_basis = "calendar_year",
#'     price_basis = "nominal", currency = "AUD", unit = "units",
#'     geography = "synthetic", value = value,
#'     sha256 = paste0("sha-", id), period_start = as.Date("2025-01-01"),
#'     period_end = as.Date("2025-12-31"), status_source = "synthetic",
#'     source_dataset = "synthetic", source_sheet = "synthetic",
#'     stringsAsFactors = FALSE
#'   )
#' }
#' vintage_observations <- do.call(rbind, list(
#'   make_vintage("forecast", "fixture-a", "2024-06-01", 10),
#'   make_vintage("forecast", "fixture-b", "2024-12-01", 11),
#'   make_vintage("estimate", "fixture-c", "2025-06-01", 12),
#'   make_vintage("historical", "fixture-d", "2025-12-01", 13)
#' ))
#' compare_req_vintages(vintage_observations, comparison = "all")
#' @export
compare_req_vintages <- function(
    data = NULL, releases = NULL, series = NULL,
    comparison = c(
      "all", "history_revision", "forecast_revision", "forecast_error"
    ),
    cache_dir = req_cache_dir()) {
  comparison <- match.arg(comparison)
  if (is.null(data)) {
    if (is.null(releases) || length(releases) < 2L) {
      req_abort(
        "req_validation_error",
        "At least two exact releases are required when data is not supplied.",
        remediation = "Supply releases or a combined observation data frame."
      )
    }
    data <- do.call(rbind, lapply(releases, read_req,
      view = "current", cache_dir = cache_dir
    ))
  }
  ops <- if (comparison == "all") {
    c("history_revision", "forecast_revision", "forecast_error")
  } else {
    comparison
  }
  out <- lapply(ops, function(op) {
    switch(op,
      history_revision = req_history_revision(data, releases, series),
      forecast_revision = req_forecast_revision(data, releases, series),
      forecast_error = req_forecast_error(data, releases, series)
    )
  })
  names(out) <- ops
  if (comparison == "all") out else out[[1]]
}
