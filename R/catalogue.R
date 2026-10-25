#' REQ semantic source catalogue
#'
#' @return The checked-in catalogue of forecast and historical sheet slots.
#' @examples
#' req_source_catalog()
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
