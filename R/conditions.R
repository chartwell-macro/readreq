.req_condition_classes <- c(
  "req_release_discovery_error",
  "req_release_gap_warning",
  "req_asset_missing_error",
  "req_download_error",
  "req_asset_format_error",
  "req_workbook_schema_error",
  "req_sheet_parse_error",
  "req_period_parse_error",
  "req_unit_conflict_error",
  "req_stitch_conflict_error",
  "req_validation_error"
)

req_condition <- function(subclass, message, ..., warning = FALSE) {
  if (!subclass %in% .req_condition_classes) {
    stop("Unknown readreq condition subclass: ", subclass, call. = FALSE)
  }
  parent <- if (isTRUE(warning)) "req_warning" else "req_error"
  base <- if (isTRUE(warning)) "warning" else "error"
  structure(
    c(list(message = message, call = NULL), list(...)),
    class = c(subclass, parent, base, "condition")
  )
}

req_abort <- function(subclass, message, ...) {
  stop(req_condition(subclass, message, ...))
}

req_warn <- function(subclass, message, ...) {
  warning(req_condition(subclass, message, ..., warning = TRUE))
}

req_condition_catalog <- function() {
  data.frame(
    class = .req_condition_classes,
    kind = ifelse(grepl("_warning$", .req_condition_classes),
      "warning", "error"
    ),
    stringsAsFactors = FALSE
  )
}
