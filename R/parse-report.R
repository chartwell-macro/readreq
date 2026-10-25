.req_report_fallback_hashes <- c(
  `req-2011-12` =
    "1234c2f0eff7ea30f0eb85c3cde2d2068fb7df4534343a0e47f28885edb828ca",
  `req-2013-03` =
    "cc1d7d25a25848d398de5c0734d3e50aad32c5a8e657278a305f83e8570abfcf"
)

req_report_text <- function(path, release_id, sha256) {
  expected <- unname(.req_report_fallback_hashes[[release_id]])
  if (is.null(expected) || !identical(tolower(sha256), expected)) {
    req_abort(
      "req_asset_format_error",
      "Report bytes do not match an audited REQ table-fallback profile.",
      release_id = release_id,
      asset_type = "report",
      remediation = "Audit the exact PDF bytes before updating the fallback hash."
    )
  }
  executable <- Sys.which("pdftotext")
  if (!nzchar(executable)) {
    req_abort(
      "req_asset_format_error",
      "The audited report fallback requires the pdftotext executable.",
      release_id = release_id,
      asset_type = "report",
      remediation = "Install Poppler and retry the exact release."
    )
  }
  output <- tempfile("readreq-report-", fileext = ".txt")
  on.exit(unlink(output), add = TRUE)
  status <- suppressWarnings(system2(
    executable,
    c("-layout", shQuote(path), shQuote(output)),
    stdout = FALSE,
    stderr = FALSE
  ))
  if (!identical(status, 0L) || !file.exists(output)) {
    req_abort(
      "req_sheet_parse_error",
      "The audited REQ report could not be converted to layout-preserving text.",
      release_id = release_id,
      asset_type = "report",
      remediation = "Verify the PDF and Poppler installation."
    )
  }
  readLines(output, warn = FALSE, encoding = "UTF-8")
}

req_parse_report_table <- function(
    path, release_meta, retrieved_at = Sys.time(), sha256 = NULL,
    sheets = "all") {
  release_id <- release_meta$release_id
  if (!release_id %in% names(.req_report_fallback_hashes)) {
    req_abort(
      "req_sheet_parse_error",
      "This REQ report has no audited deterministic table fallback.",
      release_id = release_id,
      asset_type = "report",
      remediation = "Use a structured companion workbook or add an audited profile."
    )
  }
  if (!identical(sheets, "all") &&
      !any(as.character(sheets) %in%
        c("PDF Table 1", "forecast_world_macro", "Table 1"))) {
    req_abort(
      "req_sheet_parse_error",
      "The requested table is not in the audited report fallback.",
      release_id = release_id,
      asset_type = "report",
      remediation = "Select forecast_world_macro or PDF Table 1."
    )
  }
  if (is.null(sha256)) sha256 <- .req_sha256_file(path)
  lines <- req_report_text(path, release_id, sha256)
  anchor <- which(grepl(
    "^\\s*Table 1:\\s+.*(macroeconomic assumptions|Key macroeconomic)",
    lines,
    ignore.case = TRUE
  ))
  if (length(anchor) != 1L) {
    req_abort(
      "req_workbook_schema_error",
      "The audited report Table 1 anchor was not unique.",
      release_id = release_id,
      asset_type = "report",
      remediation = "Inspect the layout-preserving PDF text."
    )
  }
  header_candidates <- seq.int(anchor + 1L, min(length(lines), anchor + 10L))
  header_counts <- vapply(header_candidates, function(index) {
    matches <- gregexpr(
      "(18|19|20)[0-9]{2}(\\s+a)?",
      lines[[index]],
      perl = TRUE,
      ignore.case = TRUE
    )[[1L]]
    if (identical(matches[[1L]], -1L)) 0L else length(matches)
  }, integer(1))
  header_row <- header_candidates[[which.max(header_counts)]]
  if (max(header_counts) < 4L) {
    req_abort(
      "req_workbook_schema_error",
      "The audited report Table 1 period header was not recognised.",
      release_id = release_id,
      asset_type = "report",
      remediation = "Inspect the PDF table header."
    )
  }
  header_matches <- regmatches(
    lines[[header_row]],
    gregexpr(
      "(18|19|20)[0-9]{2}(\\s+a)?",
      lines[[header_row]],
      perl = TRUE,
      ignore.case = TRUE
    )
  )[[1L]]
  release_year <- as.integer(format(release_meta$release_date, "%Y"))
  period_labels <- vapply(header_matches, function(value) {
    year <- as.integer(substr(value, 1L, 4L))
    assumed <- grepl("\\s+a$", value, ignore.case = TRUE)
    if (assumed) {
      paste(year, if (year > release_year) "f" else "s")
    } else {
      as.character(year)
    }
  }, character(1))
  periods <- req_period(period_labels)
  source_end <- which(
    seq_along(lines) > header_row &
      grepl("^\\s*Sources?:", lines, ignore.case = TRUE)
  )
  end_row <- if (length(source_end)) min(source_end) - 1L else {
    min(length(lines), header_row + 90L)
  }
  rows <- list()
  output_index <- 0L
  series_cache <- new.env(hash = TRUE, parent = emptyenv())
  current_concept <- "economic growth"
  for (line_index in seq.int(header_row + 1L, end_row)) {
    line <- gsub("\u2212|\u2013|\u2014", "-", lines[[line_index]])
    heading <- trimws(line)
    if (grepl(
      "^(Economic growth|Industrial production|Inflation( rate)?|Interest rates?)",
      heading,
      ignore.case = TRUE
    )) {
      current_concept <- sub("\\s+[a-z]{1,3}$", "", heading, ignore.case = TRUE)
      next
    }
    unit_match <- regexpr("\\s+%\\s*(pa\\s+)?", line, perl = TRUE)
    if (unit_match[[1L]] < 1L) next
    label <- trimws(substr(line, 1L, unit_match[[1L]] - 1L))
    if (!nzchar(label) ||
        grepl("^(world|economic growth|industrial production|inflation|interest rate)$",
          label, ignore.case = TRUE
        )) {
      next
    }
    tail_start <- unit_match[[1L]] + attr(unit_match, "match.length")
    values_text <- substr(line, tail_start, nchar(line))
    values_text <- gsub("([+-])\\s+", "\\1", values_text, perl = TRUE)
    number_matches <- regmatches(
      values_text,
      gregexpr("[+-]?[0-9]+(?:\\.[0-9]+)?", values_text, perl = TRUE)
    )[[1L]]
    if (length(number_matches) != length(period_labels)) next
    values <- as.numeric(number_matches)
    semantic_label <- sub("\\s+[a-z]{1,3}$", "", label, ignore.case = TRUE)
    for (position in seq_along(values)) {
      row <- list(
        product = "resources_energy_quarterly",
        release_id = release_id,
        release_date = release_meta$release_date,
        dataset = "resources_energy_quarterly",
        source_dataset = "forecast",
        source_asset = "report",
        source_sheet = "PDF Table 1",
        table_id = "forecast_world_macro",
        table_title = "Key macroeconomic assumptions",
        record_role = "canonical",
        geography_type = "country",
        geography = semantic_label,
        commodity = "resources_and_energy",
        concept = req_slug(paste(current_concept, semantic_label)),
        period = periods$period[[position]],
        period_start = periods$period_start[[position]],
        period_end = periods$period_end[[position]],
        period_basis = periods$period_basis[[position]],
        period_status = periods$period_status[[position]],
        status_source = periods$status_source[[position]],
        price_basis = "not_applicable",
        currency = "not_applicable",
        unit = "%",
        value = values[[position]],
        raw_value = number_matches[[position]],
        missing_reason = NA_character_,
        footnote_codes = I(list(character())),
        source_note = paste0(
          "Deterministic extraction from the official ", release_id,
          " report, Table 1."
        ),
        series_id = "",
        observation_key = "",
        retrieved_at = as.POSIXct(retrieved_at, tz = "UTC"),
        sha256 = sha256,
        parser_version = .req_parser_version,
        section = if (grepl(
          "Australia", semantic_label, ignore.case = TRUE
        )) {
          "Australia"
        } else {
          "World"
        },
        frequency = periods$frequency[[position]]
      )
      row$series_id <- req_semantic_id_cached(row, series_cache)
      row$observation_key <- paste(row$series_id, row$period, sep = "::")
      output_index <- output_index + 1L
      rows[[output_index]] <- row
    }
  }
  minimum_rows <- if (identical(release_id, "req-2011-12")) 60L else 120L
  if (length(rows) < minimum_rows) {
    req_abort(
      "req_workbook_schema_error",
      sprintf(
        "Audited report Table 1 yielded %d cells; expected at least %d.",
        length(rows), minimum_rows
      ),
      release_id = release_id,
      asset_type = "report",
      remediation = "Inspect PDF text layout drift."
    )
  }
  data <- req_observation_frame(rows)
  mapping <- data.frame(
    source_sheet = "PDF Table 1",
    table_id = "forecast_world_macro",
    classification = "data_table",
    parser_family = "report_table_1",
    fingerprint = digest::digest(
      paste(lines[anchor:header_row], collapse = "\n"),
      algo = "sha256",
      serialize = FALSE
    ),
    markers = "report_identity;period_grid",
    stringsAsFactors = FALSE
  )
  diagnostics <- data.frame(
    source_sheet = "PDF Table 1",
    table_id = "forecast_world_macro",
    row = NA_integer_,
    period_cells = nrow(data),
    parsed_cells = nrow(data),
    control_cells = 0L,
    stringsAsFactors = FALSE
  )
  attr(data, "sheet_mapping") <- mapping
  attr(data, "parse_diagnostics") <- diagnostics
  data
}
