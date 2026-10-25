#' Return readreq source attribution and licence guidance
#'
#' `req_attribution()` returns the package's stable attribution metadata for
#' work that uses Resources and Energy Quarterly data.  The metadata keeps
#' source-data terms separate from the readreq package code: MIT, copyright
#' Chartwell Macro.
#'
#' The returned text records the terms used by this package; it is not a legal
#' determination for every edition or asset.  Check the terms attached to the
#' particular source release and the official Resources and Energy Quarterly
#' page (\url{https://www.industry.gov.au/publications/resources-and-energy-quarterly})
#' before redistributing source material.  The `exclusions` element records
#' source-stated exclusions, and does not claim that excluded material is
#' covered by CC BY 4.0.
#'
#' @return A named list with five elements, in order: `source`,
#'   `source_licence`, `exclusions`, `fixture_policy`, and
#'   `package_code_licence`.  All elements except `exclusions` are length-one
#'   character strings; `exclusions` is a character vector of source-stated
#'   exclusions.  The list has no custom class or attributes beyond its
#'   standard `names` attribute.
#' @seealso [req_source_catalog()], [read_req()]
#' @examples
#' attribution <- req_attribution()
#' attribution[c("source", "package_code_licence")]
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
