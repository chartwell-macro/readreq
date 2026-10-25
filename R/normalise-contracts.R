#' Normalise REQ period status suffixes
#'
#' @param x Published period labels.
#' @return A data frame containing the stripped period, status and source.
#' @examples
#' req_status(c("2025-26s", "2026-27f", "2029-30z"))
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
#' @param x Original cell values.
#' @return A character vector of controlled missing reasons, with `NA` for
#'   present numeric values.
#' @examples
#' req_missing_reason(c("", "na", "n/a", "c", "..", "12"))
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
