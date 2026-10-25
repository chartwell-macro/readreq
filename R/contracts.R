req_schema <- function(fields, types, required = rep(TRUE, length(fields))) {
  stopifnot(length(fields) == length(types), length(types) == length(required))
  data.frame(
    field = fields,
    type = types,
    required = required,
    stringsAsFactors = FALSE
  )
}

#' Release manifest schema
#'
#' @return A data frame describing the frozen release-manifest fields.
#' @examples
#' req_release_manifest_schema()
#' @export
req_release_manifest_schema <- function() {
  req_schema(
    c(
      "product", "release_id", "release_date", "release_date_precision",
      "edition", "cadence", "landing_url", "landing_source",
      "asset_roles", "asset_status", "support_status", "unsupported_reason",
      "discovered_at", "discovery_version", "warning", "forecast_url",
      "historical_url", "report_url", "statistical_url", "commodity_url",
      "historical_statistical_url", "historical_commodity_url", "support_note"
    ),
    c(
      "character", "character", "Date", "character", "character",
      "character", "character", "character", "list<character>",
      "character", "character", "character", "POSIXct<UTC>", "character",
      "character", "character", "character", "character", "character",
      "character", "character", "character", "character"
    ),
    c(
      rep(TRUE, 11L), FALSE, TRUE, TRUE, FALSE,
      rep(FALSE, 7L), TRUE
    )
  )
}

#' Raw asset manifest schema
#'
#' @return A data frame describing the frozen raw-asset-manifest fields.
#' @examples
#' req_raw_asset_manifest_schema()
#' @export
req_raw_asset_manifest_schema <- function() {
  req_schema(
    c(
      "product", "release_id", "asset_type", "source_url",
      "source_filename", "detected_format", "content_type", "retrieved_at",
      "etag", "last_modified", "sha256", "bytes", "local_path",
      "validation_status", "unsupported_reason"
    ),
    c(
      "character", "character", "character", "character", "character",
      "character", "character", "POSIXct<UTC>", "character", "character",
      "character", "integer64", "character", "character", "character"
    ),
    c(rep(TRUE, 8), FALSE, FALSE, rep(TRUE, 4), FALSE)
  )
}

#' Observation schema
#'
#' @return A data frame describing the shared core plus readreq extensions.
#' @examples
#' req_observation_schema()
#' @export
req_observation_schema <- function() {
  req_schema(
    c(
      "product", "release_id", "release_date", "dataset", "source_dataset",
      "source_asset", "source_sheet", "table_id", "table_title", "record_role",
      "geography_type", "geography", "commodity", "concept", "period",
      "period_start", "period_end", "period_basis", "period_status",
      "status_source", "price_basis", "currency", "unit", "value", "raw_value",
      "missing_reason", "footnote_codes", "source_note", "series_id",
      "observation_key", "retrieved_at", "sha256", "parser_version",
      "section", "frequency"
    ),
    c(
      "character", "character", "Date", "character", "character",
      "character", "character", "character", "character", "character",
      "character", "character", "character", "character", "character",
      "Date", "Date", "character", "character", "character", "character",
      "character", "character", "double", "character", "character",
      "list<character>", "character", "character", "character",
      "POSIXct<UTC>", "character", "character", "character", "character"
    )
  )
}

req_cache_contract <- function() {
  list(
    raw_path = "raw/<product>/<release_id>/<sha256>/<asset>",
    immutable_raw = TRUE,
    atomic_promotion = TRUE,
    discovery_refresh_deletes_raw = FALSE,
    parsed_key = c(
      "product", "release_id", "sha256", "parser_version", "view"
    ),
    automatic_pruning = FALSE
  )
}
