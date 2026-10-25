#' REQ attribution guidance
#'
#' @return A named list separating source-data and package-code terms.
#' @examples
#' req_attribution()
#' @export
req_attribution <- function() {
  list(
    source = "Australian Government Department of Industry, Science and Resources, Resources and Energy Quarterly.",
    source_licence = "CC BY 4.0, subject to source-stated exclusions.",
    exclusions = c(
      "Commonwealth Coat of Arms",
      "trade marks",
      "third-party material"
    ),
    fixture_policy = "Reduced/derived synthetic structurally faithful fixtures only.",
    package_code_licence = "MIT"
  )
}
