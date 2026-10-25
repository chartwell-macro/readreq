req_normalise_unit <- function(x) {
  x <- req_clean_text(x)
  x[x == ""] <- "not_applicable"
  x <- sub(
    paste0(
      "^((LCE )?[kM]?t( LCE)?|['\u2019]000 ct|",
      "A?\\$[mb]|US\\$/[^ ]+)\\s+[a-z]{1,3}$"
    ),
    "\\1", x, ignore.case = TRUE
  )
  x <- gsub("^\\$", "A\\$", x)
  x <- gsub("MMBTU", "MMBtu", x, ignore.case = TRUE)
  x
}

req_currency <- function(unit) {
  out <- rep("not_applicable", length(unit))
  out[grepl("A\\$|AUD|\\$m", unit, ignore.case = TRUE)] <- "AUD"
  out[grepl("US\\$|USD|USc", unit, ignore.case = TRUE)] <- "USD"
  out
}

req_price_basis <- function(label, title, unit) {
  z <- tolower(paste(label, title, unit))
  if (grepl("\\breal\\b|chain volume|constant prices?", z)) return("real")
  if (grepl("unit value", z)) return("unit_value")
  if (grepl("\\bspot\\b", z)) return("spot")
  if (grepl("\\bcontract", z)) return("contract")
  if (grepl("benchmark", z)) return("benchmark")
  if (grepl("index", z)) return("index")
  if (grepl("price|value|\\$|currency", z)) return("nominal")
  "not_applicable"
}

req_semantic_id <- function(row, include_status = TRUE) {
  fields <- c(
    "product", "dataset", "section", "geography_type", "geography",
    "commodity", "concept", "frequency", "period_basis", "price_basis",
    "currency", "unit"
  )
  if (include_status) fields <- c(fields, "period_status")
  key <- paste(vapply(fields, function(nm) {
    z <- row[[nm]]
    if (!length(z) || is.na(z)) "" else as.character(z)
  }, character(1)), collapse = "\u001f")
  paste0("req_", substr(digest::digest(key, algo = "sha256", serialize = FALSE), 1, 24))
}

req_semantic_id_cached <- function(row, cache, include_status = TRUE) {
  fields <- c(
    "product", "dataset", "section", "geography_type", "geography",
    "commodity", "concept", "frequency", "period_basis", "price_basis",
    "currency", "unit"
  )
  if (include_status) fields <- c(fields, "period_status")
  key <- paste(vapply(fields, function(nm) {
    z <- row[[nm]]
    if (!length(z) || is.na(z)) "" else as.character(z)
  }, character(1)), collapse = "\u001f")
  if (exists(key, envir = cache, inherits = FALSE)) {
    return(get(key, envir = cache, inherits = FALSE))
  }
  value <- paste0(
    "req_",
    substr(digest::digest(key, algo = "sha256", serialize = FALSE), 1, 24)
  )
  assign(key, value, envir = cache)
  value
}

req_status_independent_key <- function(data) {
  fields <- c(
    "product", "dataset", "section", "geography_type", "geography",
    "commodity", "concept", "frequency", "period", "period_basis",
    "price_basis", "currency", "unit"
  )
  fields <- intersect(fields, names(data))
  do.call(paste, c(data[fields], sep = "\u001f"))
}

req_observation_frame <- function(rows) {
  schema <- req_observation_schema()
  if (!length(rows)) {
    out <- as.data.frame(stats::setNames(
      replicate(nrow(schema), character(), simplify = FALSE),
      schema$field
    ))
    out$value <- numeric()
    out$release_date <- out$period_start <- out$period_end <- as.Date(character())
    out$retrieved_at <- as.POSIXct(character(), tz = "UTC")
    out$footnote_codes <- I(list())
    return(out)
  }
  out <- data.table::rbindlist(rows, use.names = TRUE, fill = TRUE)
  data.table::setDF(out)
  out <- out[, schema$field, drop = FALSE]
  out$release_date <- as.Date(out$release_date)
  out$period_start <- as.Date(out$period_start)
  out$period_end <- as.Date(out$period_end)
  out$retrieved_at <- as.POSIXct(out$retrieved_at, tz = "UTC")
  out
}
