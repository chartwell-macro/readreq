#' Classify REQ period status suffixes
#'
#' `req_status()` detects and strips a trailing `s`, `f`, or `z`
#' case-insensitively, but only a lowercase published suffix maps to
#' `estimate`, `forecast`, or `projection`. It trims leading and trailing
#' whitespace and does not infer calendar, financial-year, quarter, or month
#' semantics. Missing labels and labels without lowercase status evidence
#' remain `published-unclassified`.
#'
#' @param x A character-like vector of published period labels.  Values are
#'   coerced with `as.character()`; missing and zero-length input are allowed.
#' @return A base `data.frame` with one row per element of `x` and these
#'   character columns, in order: `period` (the trimmed label with a detected
#'   suffix removed), `period_status` (one of `estimate`, `forecast`,
#'   `projection`, or `published-unclassified`), and `status_source` (either
#'   `suffix` or `unclassified`).  The result has the standard `data.frame`
#'   class and row names only. A detected uppercase suffix is stripped and
#'   recorded with `status_source = "suffix"`, but its `period_status` remains
#'   `published-unclassified` because the controlled mapping is lowercase-only.
#' @details The function is deterministic and has no network, cache, or file
#'   side effects.  It emits no warnings for ordinary character-like input.
#'   It does not validate that a period label has a particular date format.
#' @seealso [req_missing_reason()], [req_observation_schema()]
#' @examples
#' req_status(c("2025-26s", "2026-27f", "2026-27F", "2029-30z"))
#' @export
req_status <- function(x) {
  x <- as.character(x)
  trimmed <- trimws(x)
  suffix <- tolower(sub(".*?([sfz])\\s*$", "\\1", trimmed, perl = TRUE))
  has_suffix <- grepl("[sfz]\\s*$", trimmed, ignore.case = TRUE)
  status <- rep("published-unclassified", length(trimmed))
  status[has_suffix & suffix == "s"] <- "estimate"
  status[has_suffix & suffix == "f"] <- "forecast"
  status[has_suffix & suffix == "z"] <- "projection"
  period <- trimmed
  period[has_suffix] <- trimws(sub("[sfz]\\s*$", "", period[has_suffix],
    ignore.case = TRUE
  ))
  data.frame(
    period = period,
    period_status = status,
    status_source = ifelse(has_suffix, "suffix", "unclassified"),
    stringsAsFactors = FALSE
  )
}

#' Classify REQ missing-value markers
#'
#' `req_missing_reason()` maps source cell tokens to readreq's controlled
#' missingness vocabulary before numeric parsing.  It preserves the distinction
#' between a blank, a provider-reported missing value, a confidential value,
#' and a suppressed value; a numeric-looking token is treated as a present
#' value and therefore returns `NA`.
#'
#' @param x A vector of original source cell values.  Values are coerced with
#'   `as.character()` and compared after trimming whitespace and converting to
#'   lower case; `NA` input is classified as `blank`.
#' @return An unnamed character vector with the same length as `x`.  It uses
#'   `blank` for `NA` or empty cells, `provider_na` for `na` or `#n/a`,
#'   `not_applicable` for `n/a`, `not applicable`, or `nil`, `unavailable` for
#'   `not available`, `unavailable`, or `n.av.`, `confidential` for
#'   `confidential` or `c`, and `suppressed` for `suppressed`, `..`, an em
#'   dash, or `-`.  Numeric-looking values return `NA_character_` because
#'   they are present observations.  The result has no custom class or
#'   attributes.
#' @details The function is deterministic and has no network, cache, or file
#'   side effects.  An unexplained non-empty, non-numeric token raises a
#'   `req_validation_error` containing the first offending raw value; no
#'   partial result is returned.  Ordinary inputs do not produce warnings.
#' @seealso [req_observation_schema()], [req_status()]
#' @examples
#' req_missing_reason(c(NA_character_, "", "na", "n/a", "c", "..", "12"))
#' @export
req_missing_reason <- function(x) {
  raw <- as.character(x)
  raw[is.na(x)] <- NA_character_
  token <- tolower(trimws(raw))
  result <- rep(NA_character_, length(raw))
  result[is.na(raw) | token == ""] <- "blank"
  result[token %in% c("na", "#n/a")] <- "provider_na"
  result[token %in% c("n/a", "not applicable", "nil")] <- "not_applicable"
  result[token %in% c("not available", "unavailable", "n.av.")] <- "unavailable"
  result[token %in% c("confidential", "c")] <- "confidential"
  result[token %in% c("suppressed", "..", "\u2014", "-")] <- "suppressed"
  unresolved <- is.na(result) & is.na(suppressWarnings(as.numeric(token)))
  if (any(unresolved)) {
    req_abort(
      "req_validation_error",
      "Unexplained non-empty value in a numeric region.",
      raw_value = raw[which(unresolved)[1]],
      remediation = "Add an explicit source marker or repair the parser."
    )
  }
  result
}
