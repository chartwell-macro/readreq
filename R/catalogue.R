#' List the checked-in REQ source catalogue
#'
#' `req_source_catalog()` reads the installed, machine-readable catalogue of
#' forecast and historical sheet or table slots.  It is the release-independent
#' semantic catalogue used to discover stable `table_id` values and parser
#' families; it is not a live listing and does not contact an official website.
#' The catalogue is packaged with readreq, so this function has no network,
#' cache, or other file-writing side effects.
#'
#' @return A base `data.frame` with one row per catalogued source slot and
#'   these eight columns, in order: `source_dataset` (character), `ordinal`
#'   (integer), `source_label` (character), `table_id` (character),
#'   `classification` (character), `parser_family` (character),
#'   `admission_status` (character), and `unsupported_reason` (logical in the
#'   current catalogue because every value is missing).  Blank
#'   `unsupported_reason` cells are returned as `NA` by `utils::read.csv()`;
#'   because the function preserves `read.csv()` type inference, that column
#'   becomes character if a future catalogue contains a non-empty reason.
#'   `table_id` values are unique in the checked-in catalogue.  The result has
#'   the standard `data.frame` class and row names only.
#'   A missing installed catalogue raises a `req_validation_error`.
#' @seealso [req_series_catalog()], [req_observation_schema()],
#'   [list_req_releases()]
#' @examples
#' catalogue <- req_source_catalog()
#' utils::head(
#'   catalogue[catalogue$admission_status == "supported",
#'     c("source_dataset", "table_id", "parser_family")],
#'   3L
#' )
#' @export
req_source_catalog <- function() {
  path <- system.file("catalogue", "source-catalog.csv", package = "readreq")
  if (!nzchar(path)) {
    req_abort(
      "req_validation_error",
      "Installed source catalogue is missing.",
      remediation = "Reinstall readreq from a complete source tree."
    )
  }
  utils::read.csv(path, stringsAsFactors = FALSE, na.strings = "")
}
