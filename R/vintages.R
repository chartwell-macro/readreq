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
#' @param data Parsed observations.
#' @param releases Optional releases.
#' @param series Optional semantic series.
#' @return A data frame of consecutive comparable revisions.
#' @examples
#' \dontrun{
#' observations <- read_req("req-2025-12")
#' req_history_revision(observations)
#' }
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
#' @inheritParams req_history_revision
#' @return A data frame of consecutive comparable forecast revisions.
#' @examples
#' \dontrun{
#' observations <- read_req("req-2025-12")
#' req_forecast_revision(observations)
#' }
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
#' @inheritParams req_history_revision
#' @param realisation Either the first realisation or latest revised value.
#' @return A data frame comparing forecasts with realised observations.
#' @examples
#' \dontrun{
#' observations <- read_req("req-2025-12")
#' req_forecast_error(observations, realisation = "first")
#' }
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
#' @param data Optional already parsed multi-vintage observations.
#' @param releases Release IDs to load or filter.
#' @param series Optional semantic series IDs.
#' @param comparison Comparison family.
#' @param cache_dir Cache directory.
#' @return A data frame containing the selected vintage comparisons.
#' @examples
#' \dontrun{
#' compare_req_vintages(
#'   releases = c("req-2025-12", "req-2026-06"),
#'   comparison = "forecast_revision"
#' )
#' }
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
