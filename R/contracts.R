req_schema <- function(fields, types, required = rep(TRUE, length(fields))) {
  stopifnot(length(fields) == length(types), length(types) == length(required))
  data.frame(
    field = fields,
    type = types,
    required = required,
    stringsAsFactors = FALSE
  )
}

#' Describe the release-manifest contract
#'
#' `req_release_manifest_schema()` exposes the field-level contract used by
#' release discovery and validation.  Use the returned `field` column to
#' select or order release-manifest data before passing it to downstream
#' helpers; the function returns metadata, not release records.
#'
#' @return A base `data.frame` with 23 rows and the columns `field`, `type`,
#'   and `required` in that order.  All three columns are ordinary vectors:
#'   `field` and `type` are character, and `required` is logical.  The fields
#'   are ordered as `product`, `release_id`, `release_date`,
#'   `release_date_precision`, `edition`, `cadence`, `landing_url`,
#'   `landing_source`, `asset_roles`, `asset_status`, `support_status`,
#'   `unsupported_reason`, `discovered_at`, `discovery_version`, `warning`,
#'   `forecast_url`, `historical_url`, `report_url`, `statistical_url`,
#'   `commodity_url`, `historical_statistical_url`,
#'   `historical_commodity_url`, and `support_note`.  The `type` descriptors
#'   identify dates as `Date`, discovery timestamps as `POSIXct<UTC>`, and
#'   `asset_roles` as `list<character>`; they describe fields in a manifest,
#'   not classes of this schema's columns.  `required` is `TRUE` for
#'   `product` through `support_status`, `discovered_at`,
#'   `discovery_version`, and `support_note`; it is `FALSE` for
#'   `unsupported_reason`, `warning`, and all asset URL fields.  The result
#'   has the standard `data.frame` class and row names only.
#' @seealso [req_raw_asset_manifest_schema()], [req_release_manifest_schema()],
#'   [list_req_releases()]
#' @examples
#' manifest_schema <- req_release_manifest_schema()
#' utils::head(manifest_schema[manifest_schema$required, c("field", "type")], 3L)
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

#' Describe the raw-asset manifest contract
#'
#' `req_raw_asset_manifest_schema()` exposes the field-level contract for the
#' immutable raw assets recorded by download and validation helpers.  It
#' returns metadata only; it does not download, inspect, or cache an asset.
#'
#' @return A base `data.frame` with 15 rows and the columns `field`, `type`,
#'   and `required` in that order.  `field` and `type` are character vectors
#'   and `required` is logical.  The fields are ordered as `product`,
#'   `release_id`, `asset_type`, `source_url`, `source_filename`,
#'   `detected_format`, `content_type`, `retrieved_at`, `etag`,
#'   `last_modified`, `sha256`, `bytes`, `local_path`, `validation_status`,
#'   and `unsupported_reason`.  The `type` descriptors identify
#'   `retrieved_at` as `POSIXct<UTC>` and `bytes` as `integer64`.  These are
#'   schema descriptors, not classes on this result (and the `integer64`
#'   label does not require a `bit64` dependency or promise a `bit64` class on
#'   a runtime manifest).
#'   `required` is `TRUE` for the first eight fields and for `sha256`, `bytes`,
#'   `local_path`, and `validation_status`; it is `FALSE` for `etag`,
#'   `last_modified`, and `unsupported_reason`.  The result has the standard
#'   `data.frame` class and row names only.
#' @seealso [req_release_manifest_schema()], [download_req_release()],
#'   [validate_req_release()]
#' @examples
#' asset_schema <- req_raw_asset_manifest_schema()
#' asset_schema[asset_schema$field %in% c("source_url", "sha256", "bytes"), ]
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

#' Describe the observation contract
#'
#' `req_observation_schema()` exposes the shared observation contract returned
#' by the workbook readers.  The schema includes source provenance, period and
#' status semantics, value and missingness fields, and the stable identifiers
#' used for series and observations.
#'
#' @return A base `data.frame` with 35 rows and the columns `field`, `type`,
#'   and `required` in that order.  `field` and `type` are character vectors;
#'   `required` is logical and is `TRUE` for every row.  The fields are ordered
#'   as `product`, `release_id`, `release_date`, `dataset`, `source_dataset`,
#'   `source_asset`, `source_sheet`, `table_id`, `table_title`, `record_role`,
#'   `geography_type`, `geography`, `commodity`, `concept`, `period`,
#'   `period_start`, `period_end`, `period_basis`, `period_status`,
#'   `status_source`, `price_basis`, `currency`, `unit`, `value`, `raw_value`,
#'   `missing_reason`, `footnote_codes`, `source_note`, `series_id`,
#'   `observation_key`, `retrieved_at`, `sha256`, `parser_version`, `section`,
#'   and `frequency`.  The `type` descriptors identify `release_date`,
#'   `period_start`, and `period_end` as `Date`, `retrieved_at` as
#'   `POSIXct<UTC>`, `value` as `double`, and `footnote_codes` as
#'   `list<character>`; they describe observation fields, not classes of this
#'   schema's columns.  The result has the standard `data.frame` class and row
#'   names only.
#' @seealso [read_req()], [req_series_catalog()],
#'   [req_release_manifest_schema()]
#' @examples
#' observation_schema <- req_observation_schema()
#' observation_schema[observation_schema$field %in%
#'   c("period", "value", "missing_reason", "observation_key"), ]
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
