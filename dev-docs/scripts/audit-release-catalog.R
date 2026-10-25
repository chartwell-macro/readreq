#!/usr/bin/env Rscript

# Development-only byte audit for the package-owned release catalogue. The
# script uses a small HTTP range request and records the returned file
# signature, avoiding full report downloads while still detecting HTML error
# bodies and broken replay URLs.

catalogue_path <- commandArgs(trailingOnly = TRUE)
if (length(catalogue_path) != 1L) {
  stop("Usage: audit-release-catalog.R <release-catalog.csv>", call. = FALSE)
}

catalogue <- utils::read.csv(
  catalogue_path,
  na.strings = "",
  stringsAsFactors = FALSE
)
asset_columns <- c(
  "forecast_url",
  "historical_url",
  "report_url",
  "statistical_url",
  "commodity_url",
  "historical_statistical_url",
  "historical_commodity_url"
)

assets <- do.call(rbind, lapply(asset_columns, function(column) {
  keep <- !is.na(catalogue[[column]]) & nzchar(catalogue[[column]])
  data.frame(
    release_id = catalogue$release_id[keep],
    role = sub("_url$", "", column),
    url = catalogue[[column]][keep],
    stringsAsFactors = FALSE
  )
}))

audit_one <- function(i) {
  destination <- tempfile("readreq-byte-audit-")
  on.exit(unlink(destination), add = TRUE)
  curl_output <- tryCatch(
    system2(
      "curl",
      c(
        "-L", "-sS", "--retry", "2", "--max-time", "90",
        "--range", "0-15",
        "-w", shQuote("%{http_code}|%{size_download}|%{content_type}"),
        "-o", shQuote(destination),
        shQuote(assets$url[[i]])
      ),
      stdout = TRUE,
      stderr = TRUE
    ),
    error = function(error) paste0("curl-error|", conditionMessage(error))
  )
  bytes <- if (file.exists(destination)) {
    readBin(destination, what = "raw", n = 16L)
  } else {
    raw()
  }
  signature <- paste(sprintf("%02x", as.integer(bytes)), collapse = "")
  expected <- if (identical(assets$role[[i]], "report")) {
    "25504446"
  } else {
    c("504b0304", "d0cf11e0")
  }
  ok <- any(startsWith(signature, expected))
  data.frame(
    release_id = assets$release_id[[i]],
    role = assets$role[[i]],
    ok = ok,
    signature = signature,
    response = paste(curl_output, collapse = " "),
    url = assets$url[[i]],
    stringsAsFactors = FALSE
  )
}

result <- do.call(
  rbind,
  parallel::mclapply(seq_len(nrow(assets)), audit_one, mc.cores = 8L)
)
utils::write.csv(result, stdout(), row.names = FALSE)
if (!all(result$ok)) {
  quit(status = 1L)
}
