.req_parser_version <- "2.1.3"

req_clean_text <- function(x) {
  x <- as.character(x)
  x <- gsub("\u00a0", " ", x, fixed = TRUE)
  x <- gsub("[\r\n\t]+", " ", x)
  trimws(gsub("\\s+", " ", x))
}

req_slug <- function(x) {
  x <- tolower(req_clean_text(x))
  x <- gsub("[\u2013\u2014]", "-", x)
  x <- gsub("[\u2018\u2019]", "'", x)
  x <- iconv(x, to = "ASCII//TRANSLIT")
  x <- gsub("[^a-z0-9]+", "_", x)
  gsub("^_+|_+$", "", x)
}

req_is_period_label <- function(x) {
  x <- req_clean_text(x)
  fy <- grepl("^(18|19|20)[0-9]{2}[\u2013-][0-9]{2}\\s*[sfz]?$", x,
    ignore.case = TRUE
  )
  year <- grepl("^(18|19|20)[0-9]{2}\\s*[sfz]?$", x, ignore.case = TRUE)
  quarter <- grepl(
    "^(Mar|Jun|Sep|Dec)[\u2013 -]?[0-9]{2,4}\\s*[sfz]?$|^[12][0-9]{3}[- ]?Q[1-4]\\s*[sfz]?$",
    x, ignore.case = TRUE
  )
  month <- grepl(
    paste0(
      "^(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|",
      "Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|",
      "Dec(ember)?)[\u2013 -]?[0-9]{2,4}\\s*[sfz]?$"
    ),
    x, ignore.case = TRUE
  )
  serial <- suppressWarnings(as.numeric(x))
  fy | year | quarter | month |
    (!is.na(serial) & serial >= 20000 & serial <= 60000)
}

req_period <- function(x, frequency_hint = NULL) {
  raw <- req_clean_text(x)
  status <- req_status(raw)
  value <- status$period
  value <- sub("^((18|19|20)[0-9]{2})\\.0+$", "\\1", value)
  numeric_year <- suppressWarnings(as.numeric(value))
  is_year <- !is.na(numeric_year) & numeric_year >= 1800 & numeric_year <= 2099 &
    abs(numeric_year - round(numeric_year)) < 1e-8
  value[is_year] <- sprintf("%d", as.integer(round(numeric_year[is_year])))
  # Non-status trailing letters in REQ headers are footnote codes. Status
  # letters s/f/z have already been handled above and must retain precedence.
  value <- trimws(sub("\\s+[a-erty]\\s*$", "", value, ignore.case = TRUE))
  n <- length(value)
  period <- rep(NA_character_, n)
  start <- end <- as.Date(rep(NA_character_, n))
  basis <- rep("explicit_other", n)
  frequency <- rep(if (is.null(frequency_hint)) NA_character_ else frequency_hint, n)

  for (i in seq_len(n)) {
    z <- value[[i]]
    if (grepl("^(18|19|20)[0-9]{2}[\u2013-][0-9]{2}$", z)) {
      y <- as.integer(substr(z, 1, 4))
      period[[i]] <- sprintf("%04d-%02d", y, (y + 1L) %% 100L)
      start[[i]] <- as.Date(sprintf("%04d-07-01", y))
      end[[i]] <- as.Date(sprintf("%04d-06-30", y + 1L))
      basis[[i]] <- "australian_financial_year"
      frequency[[i]] <- "annual"
    } else if (grepl("^(18|19|20)[0-9]{2}$", z)) {
      y <- as.integer(z)
      period[[i]] <- z
      start[[i]] <- as.Date(sprintf("%04d-01-01", y))
      end[[i]] <- as.Date(sprintf("%04d-12-31", y))
      basis[[i]] <- "calendar_year"
      frequency[[i]] <- "annual"
    } else if (identical(frequency_hint, "monthly") &&
        grepl(
          paste0(
            "^(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|",
            "Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|",
            "Dec(ember)?)[\u2013 -]?[0-9]{2,4}$"
          ),
          z, ignore.case = TRUE
        )) {
      bits <- strsplit(gsub("[\u2013 ]", "-", z), "-", fixed = TRUE)[[1]]
      mon <- match(
        tolower(substr(bits[[1]], 1, 3)),
        tolower(month.abb)
      )
      y <- as.integer(bits[[2]])
      if (y < 100L) y <- 2000L + y
      period[[i]] <- sprintf("%04d-%02d", y, mon)
      start[[i]] <- as.Date(sprintf("%04d-%02d-01", y, mon))
      end[[i]] <- as.Date(
        seq(start[[i]], by = "1 month", length.out = 2)[2] - 1
      )
      basis[[i]] <- "month"
      frequency[[i]] <- "monthly"
    } else if (grepl("^(Mar|Jun|Sep|Dec)[\u2013 -]?[0-9]{2,4}$", z,
      ignore.case = TRUE
    )) {
      bits <- strsplit(gsub("[\u2013 ]", "-", z), "-", fixed = TRUE)[[1]]
      mon <- match(tolower(substr(bits[[1]], 1, 3)),
        tolower(month.abb)
      )
      y <- as.integer(bits[[2]])
      if (y < 100L) y <- 2000L + y
      q <- ceiling(mon / 3)
      period[[i]] <- sprintf("%04d-Q%d", y, q)
      start_month <- (q - 1L) * 3L + 1L
      start[[i]] <- as.Date(sprintf("%04d-%02d-01", y, start_month))
      end[[i]] <- as.Date(seq(start[[i]], by = "3 months", length.out = 2)[2] - 1)
      basis[[i]] <- "calendar_quarter"
      frequency[[i]] <- "quarterly"
    } else if (grepl("^[12][0-9]{3}[- ]?Q[1-4]$", z, ignore.case = TRUE)) {
      y <- as.integer(substr(z, 1, 4))
      q <- as.integer(sub(".*Q", "", toupper(z)))
      period[[i]] <- sprintf("%04d-Q%d", y, q)
      start[[i]] <- as.Date(sprintf("%04d-%02d-01", y, (q - 1L) * 3L + 1L))
      end[[i]] <- as.Date(seq(start[[i]], by = "3 months", length.out = 2)[2] - 1)
      basis[[i]] <- "calendar_quarter"
      frequency[[i]] <- "quarterly"
    } else {
      serial <- suppressWarnings(as.numeric(z))
      if (!is.na(serial) && serial >= 20000 && serial <= 60000) {
        d <- as.Date(serial, origin = "1899-12-30")
        if (identical(frequency_hint, "monthly")) {
          period[[i]] <- format(d, "%Y-%m")
          start[[i]] <- as.Date(format(d, "%Y-%m-01"))
          end[[i]] <- as.Date(seq(start[[i]], by = "1 month", length.out = 2)[2] - 1)
          basis[[i]] <- "month"
          frequency[[i]] <- "monthly"
        } else {
          q <- ((as.integer(format(d, "%m")) - 1L) %/% 3L) + 1L
          period[[i]] <- sprintf("%s-Q%d", format(d, "%Y"), q)
          start[[i]] <- as.Date(sprintf("%s-%02d-01", format(d, "%Y"), (q - 1L) * 3L + 1L))
          end[[i]] <- as.Date(seq(start[[i]], by = "3 months", length.out = 2)[2] - 1)
          basis[[i]] <- "calendar_quarter"
          frequency[[i]] <- "quarterly"
        }
      } else {
        req_abort(
          "req_period_parse_error",
          paste0("Unrecognised REQ period label: ", raw[[i]]),
          remediation = "Add an explicit period profile for this published label."
        )
      }
    }
  }

  data.frame(
    period = period, period_start = start, period_end = end,
    period_basis = basis, frequency = frequency,
    period_status = status$period_status,
    status_source = status$status_source,
    stringsAsFactors = FALSE
  )
}
