req_early_period_blocks <- function(mat) {
  rows <- lapply(seq_len(nrow(mat)), function(row_index) {
    columns <- req_period_candidates(mat[row_index, ])
    if (length(columns) < 2L) return(NULL)
    clusters <- req_split_period_clusters(columns, mat[row_index, columns])
    clusters <- clusters[vapply(clusters, length, integer(1)) >= 2L]
    lapply(clusters, function(period_cols) {
      raw <- req_clean_text(mat[row_index, period_cols])
      suffix_row <- row_index + 1L
      consumes_suffix <- FALSE
      if (suffix_row <= nrow(mat)) {
        suffix <- req_clean_text(mat[suffix_row, period_cols])
        fy_suffix <- grepl("^[\u2013-][0-9]{2}$", suffix)
        if (sum(fy_suffix, na.rm = TRUE) >= 2L) {
          raw[fy_suffix] <- paste0(
            sub("\\.0+$", "", raw[fy_suffix]),
            suffix[fy_suffix]
          )
          consumes_suffix <- TRUE
        }
      }
      list(
        row = row_index,
        period_cols = period_cols,
        raw_periods = raw,
        consumes_suffix = consumes_suffix
      )
    })
  })
  blocks <- unlist(rows, recursive = FALSE)
  quarter_pattern <- "^(Mar|Jun|Sep|Dec)$"
  for (row_index in seq_len(nrow(mat))) {
    quarter_cols <- which(grepl(
      quarter_pattern, req_clean_text(mat[row_index, ]),
      ignore.case = TRUE
    ))
    if (length(quarter_cols) < 2L) next
    possible_group_rows <- seq.int(max(1L, row_index - 3L), row_index - 1L)
    group_scores <- vapply(possible_group_rows, function(candidate) {
      sum(grepl(
        "^(18|19|20)[0-9]{2}[\u2013-][0-9]{2}$",
        req_clean_text(mat[candidate, ]),
        ignore.case = TRUE
      ))
    }, integer(1))
    if (!length(group_scores) || max(group_scores) < 1L) next
    group_row <- possible_group_rows[[which.max(group_scores)]]
    group_cols <- which(grepl(
      "^(18|19|20)[0-9]{2}[\u2013-][0-9]{2}$",
      req_clean_text(mat[group_row, ]),
      ignore.case = TRUE
    ))
    group_labels <- req_clean_text(mat[group_row, group_cols])
    used_group_indexes <- unique(vapply(quarter_cols, function(column) {
      max(which(group_cols <= column))
    }, integer(1)))
    raw <- vapply(seq_along(quarter_cols), function(index) {
      column <- quarter_cols[[index]]
      group_index <- max(which(group_cols <= column))
      fy <- group_labels[[group_index]]
      start_year <- as.integer(substr(fy, 1L, 4L))
      month <- tools::toTitleCase(tolower(
        req_clean_text(mat[row_index, column])
      ))
      year <- if (month %in% c("Sep", "Dec")) start_year else start_year + 1L
      paste(month, year, sep = "-")
    }, character(1))
    blocks <- c(blocks, list(list(
      row = row_index,
      period_cols = quarter_cols,
      raw_periods = raw,
      consumes_suffix = FALSE,
      group_row = group_row,
      used_group_cols = group_cols[used_group_indexes]
    )))
  }
  if (!length(blocks)) return(blocks)
  quarter_blocks <- blocks[
    vapply(blocks, function(block) !is.null(block$group_row), logical(1))
  ]
  if (length(quarter_blocks)) {
    for (index in seq_along(blocks)) {
      block <- blocks[[index]]
      if (!is.null(block$group_row)) next
      used <- unique(unlist(lapply(quarter_blocks, function(quarter) {
        if (identical(quarter$group_row, block$row)) {
          quarter$used_group_cols
        } else {
          integer()
        }
      })))
      if (!length(used)) next
      keep_cols <- !block$period_cols %in% used
      block$period_cols <- block$period_cols[keep_cols]
      block$raw_periods <- block$raw_periods[keep_cols]
      blocks[[index]] <- block
    }
    blocks <- blocks[vapply(
      blocks, function(block) length(block$period_cols) >= 2L, logical(1)
    )]
  }
  block_order <- order(
    vapply(blocks, `[[`, integer(1), "row"),
    vapply(blocks, function(block) min(block$period_cols), integer(1))
  )
  blocks <- blocks[block_order]
  if (length(blocks) > 1L) {
    keep <- rep(TRUE, length(blocks))
    normalised_periods <- lapply(blocks, function(block) {
      req_period(block$raw_periods)$period
    })
    for (later in seq.int(2L, length(blocks))) {
      if (!isTRUE(blocks[[later]]$consumes_suffix)) next
      for (earlier in rev(seq_len(later - 1L))) {
        if (blocks[[later]]$row - blocks[[earlier]]$row > 4L) break
        same_columns <- identical(
          blocks[[earlier]]$period_cols,
          blocks[[later]]$period_cols
        )
        same_periods <- identical(
          normalised_periods[[earlier]],
          normalised_periods[[later]]
        )
        if (same_columns && same_periods) {
          keep[[earlier]] <- FALSE
          break
        }
      }
    }
    blocks <- blocks[keep]
  }
  keep <- rep(TRUE, length(blocks))
  for (index in seq_along(blocks)) {
    if (index == 1L) next
    prior <- blocks[[index - 1L]]
    current <- blocks[[index]]
    if (current$row <= prior$row + 1L &&
        all(current$period_cols %in% prior$period_cols)) {
      keep[[index]] <- FALSE
    }
  }
  blocks[keep]
}

req_early_periods <- function(block, mat, release_meta, historical) {
  raw <- block$raw_periods
  status_cols <- block$period_cols + 1L
  valid <- status_cols <= ncol(mat)
  status <- rep("", length(raw))
  status[valid] <- tolower(req_clean_text(
    mat[block$row, status_cols[valid]]
  ))
  status[is.na(status)] <- ""
  suffix <- status %in% c("s", "f", "z")
  raw[suffix] <- paste(raw[suffix], status[suffix])
  assumption <- status == "a" | grepl("\\s+a$", raw, ignore.case = TRUE)
  assumption[is.na(assumption)] <- FALSE
  if (any(assumption)) {
    raw[assumption] <- sub("\\s+a$", "", raw[assumption], ignore.case = TRUE)
    years <- suppressWarnings(as.integer(substr(raw[assumption], 1L, 4L)))
    release_year <- as.integer(format(release_meta$release_date, "%Y"))
    derived <- ifelse(years > release_year, "f", "s")
    raw[assumption] <- paste(raw[assumption], derived)
  }
  periods <- req_period(raw)
  if (historical) {
    unclassified <- periods$period_status == "published-unclassified"
    periods$period_status[unclassified] <- "historical"
    periods$status_source[unclassified] <- "asset-role"
  }
  periods
}

req_early_label_unit <- function(mat, row_index, first_period_col) {
  if (first_period_col <= 1L) {
    return(list(
      label = "", label_col = NA_integer_, unit = "not_applicable"
    ))
  }
  left <- req_clean_text(mat[row_index, seq_len(first_period_col - 1L)])
  text <- !is.na(left) & nzchar(left) &
    is.na(suppressWarnings(as.numeric(left))) &
    !req_is_period_label(left) &
    !grepl("return to|notes?:|sources?:|tableend|pagend",
      left, ignore.case = TRUE
    )
  units <- text & vapply(left, req_unit_like, logical(1))
  labels <- text & !units
  list(
    label = if (any(labels)) utils::tail(left[labels], 1L) else "",
    label_col = if (any(labels)) utils::tail(which(labels), 1L) else NA_integer_,
    unit = if (any(units)) utils::tail(left[units], 1L) else "not_applicable"
  )
}

req_early_geography <- function(label) {
  clean <- req_clean_text(sub("\\s+[a-z]{1,3}$", "", label, ignore.case = TRUE))
  aliases <- c(
    "Aust." = "Australia",
    "Australia" = "Australia",
    "New South Wales" = "New South Wales",
    "Victoria" = "Victoria",
    "Queensland" = "Queensland",
    "South Australia" = "South Australia",
    "Western Australia" = "Western Australia",
    "Tasmania" = "Tasmania",
    "Northern Territory" = "Northern Territory",
    "Australian Capital Territory" = "Australian Capital Territory"
  )
  match <- aliases[tolower(names(aliases)) == tolower(clean)]
  if (!length(match)) return(NULL)
  list(
    geography = unname(match[[1L]]),
    geography_type = if (identical(unname(match[[1L]]), "Australia")) {
      "country"
    } else {
      "state_or_territory"
    }
  )
}

req_parse_early_price_sheet <- function(
    path, mapping_row, release_meta, asset_meta) {
  sheet <- mapping_row$source_sheet[[1L]]
  table_id <- mapping_row$table_id[[1L]]
  mat <- req_read_matrix(path, sheet)
  unit_scores <- vapply(seq_len(nrow(mat)), function(row_index) {
    sum(vapply(req_clean_text(mat[row_index, ]), req_unit_like, logical(1)))
  }, integer(1))
  unit_rows <- which(unit_scores >= 2L)
  if (!length(unit_rows)) {
    req_abort(
      "req_workbook_schema_error",
      "Early REQ price table has no audited unit row.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = "Inspect the vertical price-table header."
    )
  }
  date_col <- min(which(apply(mat, 2L, function(column) {
    any(grepl(
      "^(18|19|20)[0-9]{2}[\u2013-][0-9]{2}$",
      req_clean_text(column)
    ))
  })))
  if (!length(date_col)) {
    req_abort(
      "req_workbook_schema_error",
      "Early REQ price-table date or series columns were not recognised.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = "Inspect the vertical price-table structure."
    )
  }
  rows <- list()
  diagnostics <- list()
  row_index_out <- 0L
  series_cache <- new.env(hash = TRUE, parent = emptyenv())
  claimed <- matrix(FALSE, nrow(mat), ncol(mat))
  prior_data_end <- 0L
  month_pattern <- paste0(
    "^(January|February|March|April|May|June|July|August|",
    "September|October|November|December)$"
  )
  for (panel_index in seq_along(unit_rows)) {
    unit_row <- unit_rows[[panel_index]]
    series_cols <- which(vapply(
      req_clean_text(mat[unit_row, ]),
      req_unit_like,
      logical(1)
    ))
    prior_dates <- which(seq_len(unit_row - 1L) > prior_data_end & grepl(
      paste0(
        "^(18|19|20)[0-9]{2}([\u2013-][0-9]{2})?$|",
        month_pattern
      ),
      req_clean_text(mat[seq_len(unit_row - 1L), date_col]),
      ignore.case = TRUE
    ))
    label_start <- if (length(prior_dates)) {
      max(prior_dates) + 1L
    } else {
      max(1L, unit_row - 6L)
    }
    label_rows <- seq.int(label_start, unit_row - 1L)
    labels <- vapply(series_cols, function(column) {
      values <- req_clean_text(mat[label_rows, column])
      values <- values[
        !is.na(values) & nzchar(values) &
          is.na(suppressWarnings(as.numeric(values)))
      ]
      paste(unique(values), collapse = " ")
    }, character(1))
    units <- req_normalise_unit(mat[unit_row, series_cols])
    claimed[seq.int(prior_data_end + 1L, unit_row), ] <- TRUE
    data_end <- if (panel_index < length(unit_rows)) {
      unit_rows[[panel_index + 1L]] - 1L
    } else {
      nrow(mat)
    }
    current_year <- NA_integer_
    last_data <- unit_row
    for (row_index in seq.int(unit_row + 1L, data_end)) {
      date_label <- req_clean_text(mat[row_index, date_col])
      if (is.na(date_label) || !nzchar(date_label)) next
      if (grepl("^(18|19|20)[0-9]{2}$", date_label)) {
        current_year <- as.integer(date_label)
        claimed[row_index, date_col] <- TRUE
        last_data <- row_index
        next
      }
      period_label <- if (grepl(
        "^(18|19|20)[0-9]{2}[\u2013-][0-9]{2}$", date_label
      )) {
        date_label
      } else if (grepl(
        month_pattern, date_label, ignore.case = TRUE
      ) && !is.na(current_year)) {
        paste(date_label, current_year)
      } else {
        next
      }
      frequency_hint <- if (grepl("^[A-Za-z]", period_label)) {
        "monthly"
      } else {
        NULL
      }
      period <- req_period(period_label, frequency_hint = frequency_hint)
      values <- req_clean_text(mat[row_index, series_cols])
      present <- !is.na(values) & nzchar(values)
      if (!any(present)) next
      parsed <- req_parse_numeric_tokens(
        values[present], sheet, table_id, row_index, series_cols[present]
      )
      claimed[row_index, c(date_col, series_cols)] <- TRUE
      last_data <- row_index
      for (position in which(present)) {
        parsed_position <- match(position, which(present))
        label <- labels[[position]]
        unit <- units[[position]]
        row <- list(
          product = "resources_energy_quarterly",
          release_id = release_meta$release_id,
          release_date = release_meta$release_date,
          dataset = "resources_energy_quarterly",
          source_dataset = "historical",
          source_asset = asset_meta$source_dataset,
          source_sheet = sheet,
          table_id = table_id,
          table_title = req_table_title(mat, sheet),
          record_role = "canonical",
          geography_type = "country",
          geography = "Australia",
          commodity = req_slug(label),
          concept = "benchmark_price",
          period = period$period,
          period_start = period$period_start,
          period_end = period$period_end,
          period_basis = period$period_basis,
          period_status = "historical",
          status_source = "asset-role",
          price_basis = req_price_basis(label, label, unit),
          currency = req_currency(unit),
          unit = unit,
          value = parsed$value[[parsed_position]],
          raw_value = values[[position]],
          missing_reason = parsed$missing_reason[[parsed_position]],
          footnote_codes = I(list(character())),
          source_note = req_sheet_note_metadata(mat)$note,
          series_id = "",
          observation_key = "",
          retrieved_at = asset_meta$retrieved_at,
          sha256 = asset_meta$sha256,
          parser_version = .req_parser_version,
          section = "Australia",
          frequency = period$frequency
        )
        row$series_id <- req_semantic_id_cached(row, series_cache)
        row$observation_key <- paste(row$series_id, row$period, sep = "::")
        row_index_out <- row_index_out + 1L
        rows[[row_index_out]] <- row
      }
      diagnostics[[length(diagnostics) + 1L]] <- data.frame(
        source_sheet = sheet, table_id = table_id, row = row_index,
        period_cells = sum(present), parsed_cells = sum(present),
        control_cells = 0L, stringsAsFactors = FALSE
      )
    }
    prior_data_end <- last_data
  }
  if (!length(rows)) {
    req_abort(
      "req_sheet_parse_error",
      "Early REQ price table yielded no observations.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = "Inspect the audited annual/monthly date rows."
    )
  }
  claimed[, seq_len(date_col)] <- TRUE
  tokens <- req_clean_text(mat)
  dim(tokens) <- dim(mat)
  numeric <- !is.na(suppressWarnings(as.numeric(tokens)))
  unknown <- which(numeric & !claimed, arr.ind = TRUE)
  if (nrow(unknown)) {
    cell <- unknown[1L, ]
    req_abort(
      "req_sheet_parse_error",
      "Early REQ price-table numeric cell is outside the audited grid.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = paste0(
        "Inspect workbook row ", cell[[1L]], ", column ", cell[[2L]], "."
      )
    )
  }
  list(
    data = req_observation_frame(rows),
    diagnostics = do.call(rbind, diagnostics)
  )
}

req_parse_early_cross_section <- function(
    path, mapping_row, release_meta, asset_meta) {
  sheet <- mapping_row$source_sheet[[1L]]
  table_id <- mapping_row$table_id[[1L]]
  mat <- req_read_matrix(path, sheet)
  unit_row_scores <- vapply(seq_len(nrow(mat)), function(row_index) {
    sum(vapply(req_clean_text(mat[row_index, ]), req_unit_like, logical(1)))
  }, integer(1))
  unit_row <- which.max(unit_row_scores)
  value_cols <- which(vapply(
    req_clean_text(mat[unit_row, ]), req_unit_like, logical(1)
  ))
  header_rows <- seq.int(max(1L, unit_row - 4L), unit_row - 1L)
  geography <- vapply(value_cols, function(column) {
    values <- req_clean_text(mat[header_rows, column])
    values <- values[!is.na(values) & nzchar(values)]
    if (length(values)) values[[1L]] else ""
  }, character(1))
  if (length(value_cols) < 2L || any(!nzchar(geography))) {
    req_abort(
      "req_workbook_schema_error",
      "Early REQ cross-section headers were not recognised.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = "Inspect the geography and unit rows."
    )
  }
  period_rows <- which(grepl(
    paste0(
      "^(March|June|September|December) quarter (18|19|20)[0-9]{2}",
      "|^(18|19|20)[0-9]{2}[\u2013-][0-9]{2}"
    ),
    req_clean_text(mat[, 1L]),
    ignore.case = TRUE
  ))
  if (length(period_rows) != 1L) {
    req_abort(
      "req_workbook_schema_error",
      "Early REQ cross-section has no unique period identity.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = "Inspect the published period label."
    )
  }
  period_raw <- req_clean_text(mat[period_rows, 1L])
  preliminary <- grepl("\\s+p\\s*$", period_raw, ignore.case = TRUE)
  period_raw <- sub("\\s+p\\s*$", "", period_raw, ignore.case = TRUE)
  period_raw <- sub(
    "^(March|June|September|December) quarter ",
    "\\1-",
    period_raw,
    ignore.case = TRUE
  )
  period_raw <- sub("^March-", "Mar-", period_raw, ignore.case = TRUE)
  period_raw <- sub("^June-", "Jun-", period_raw, ignore.case = TRUE)
  period_raw <- sub("^September-", "Sep-", period_raw, ignore.case = TRUE)
  period_raw <- sub("^December-", "Dec-", period_raw, ignore.case = TRUE)
  period <- req_period(period_raw)
  units <- req_normalise_unit(mat[unit_row, value_cols])
  claimed <- matrix(FALSE, nrow(mat), ncol(mat))
  claimed[seq_len(period_rows), ] <- TRUE
  claimed[, seq_len(min(value_cols) - 1L)] <- TRUE
  claimed[seq.int(period_rows + 1L, nrow(mat)), value_cols] <- TRUE
  code_cols <- value_cols - 2L
  code_cols <- code_cols[code_cols > 0L]
  claimed[, code_cols] <- TRUE
  rows <- list()
  diagnostics <- list()
  output_index <- 0L
  heading <- ""
  heading_col <- NA_integer_
  last_label <- ""
  previous_label_col <- NA_integer_
  series_cache <- new.env(hash = TRUE, parent = emptyenv())
  for (row_index in seq.int(period_rows + 1L, nrow(mat))) {
    values <- req_clean_text(mat[row_index, value_cols])
    present <- !is.na(values) & nzchar(values)
    left <- req_clean_text(mat[row_index, seq_len(min(value_cols) - 1L)])
    labels <- left[
      !is.na(left) & nzchar(left) &
        !vapply(left, req_unit_like, logical(1)) &
        !grepl("notes?:|sources?:", left, ignore.case = TRUE)
    ]
    label <- if (length(labels)) utils::tail(labels, 1L) else ""
    label_col <- if (length(labels)) {
      utils::tail(which(
        !is.na(left) & nzchar(left) &
          !vapply(left, req_unit_like, logical(1)) &
          !grepl("notes?:|sources?:", left, ignore.case = TRUE)
      ), 1L)
    } else {
      NA_integer_
    }
    if (!any(present)) {
      if (nzchar(label)) {
        heading <- label
        heading_col <- label_col
        previous_label_col <- NA_integer_
      }
      next
    }
    if (!nzchar(label)) label <- last_label
    if (!nzchar(label)) {
      req_abort(
        "req_sheet_parse_error",
        "Early REQ cross-section value has no row label.",
        source_sheet = sheet,
        table_id = table_id,
        remediation = paste0("Inspect workbook row ", row_index, ".")
      )
    }
    last_label <- label
    if (nzchar(heading) && !is.na(label_col) && !is.na(heading_col) &&
        label_col <= heading_col &&
        !(grepl("^Total$", label, ignore.case = TRUE) &&
          !is.na(previous_label_col) && previous_label_col > heading_col)) {
      heading <- ""
      heading_col <- NA_integer_
    }
    parsed <- req_parse_numeric_tokens(
      values[present], sheet, table_id, row_index, value_cols[present]
    )
    for (position in which(present)) {
      parsed_position <- match(position, which(present))
      concept <- req_slug(paste(
        c(if (nzchar(heading)) heading else NULL, label),
        collapse = " \u2014 "
      ))
      unit <- units[[position]]
      row <- list(
        product = "resources_energy_quarterly",
        release_id = release_meta$release_id,
        release_date = release_meta$release_date,
        dataset = "resources_energy_quarterly",
        source_dataset = "historical",
        source_asset = asset_meta$source_dataset,
        source_sheet = sheet,
        table_id = table_id,
        table_title = req_table_title(mat, sheet),
        record_role = "canonical",
        geography_type = if (geography[[position]] == "Aust.") {
          "country"
        } else {
          "state_or_territory"
        },
        geography = geography[[position]],
        commodity = "petroleum_products",
        concept = concept,
        period = period$period,
        period_start = period$period_start,
        period_end = period$period_end,
        period_basis = period$period_basis,
        period_status = if (preliminary) "estimate" else "historical",
        status_source = if (preliminary) "suffix" else "asset-role",
        price_basis = "not_applicable",
        currency = req_currency(unit),
        unit = unit,
        value = parsed$value[[parsed_position]],
        raw_value = values[[position]],
        missing_reason = parsed$missing_reason[[parsed_position]],
        footnote_codes = I(list(character())),
        source_note = req_sheet_note_metadata(mat)$note,
        series_id = "",
        observation_key = "",
        retrieved_at = asset_meta$retrieved_at,
        sha256 = asset_meta$sha256,
        parser_version = .req_parser_version,
        section = "Australia",
        frequency = period$frequency
      )
      row$series_id <- req_semantic_id_cached(row, series_cache)
      row$observation_key <- paste(row$series_id, row$period, sep = "::")
      output_index <- output_index + 1L
      rows[[output_index]] <- row
    }
    diagnostics[[length(diagnostics) + 1L]] <- data.frame(
      source_sheet = sheet, table_id = table_id, row = row_index,
      period_cells = sum(present), parsed_cells = sum(present),
      control_cells = 0L, stringsAsFactors = FALSE
    )
    previous_label_col <- label_col
  }
  tokens <- req_clean_text(mat)
  dim(tokens) <- dim(mat)
  numeric <- !is.na(suppressWarnings(as.numeric(tokens)))
  unknown <- which(numeric & !claimed, arr.ind = TRUE)
  if (nrow(unknown)) {
    cell <- unknown[1L, ]
    req_abort(
      "req_sheet_parse_error",
      "Early REQ cross-section numeric cell is outside the audited grid.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = paste0(
        "Inspect workbook row ", cell[[1L]], ", column ", cell[[2L]], "."
      )
    )
  }
  list(
    data = req_observation_frame(rows),
    diagnostics = do.call(rbind, diagnostics)
  )
}

req_parse_early_sheet <- function(
    path, mapping_row, release_meta, asset_meta) {
  sheet <- mapping_row$source_sheet[[1L]]
  table_id <- mapping_row$table_id[[1L]]
  family <- mapping_row$parser_family[[1L]]
  if (identical(family, "history_monthly")) {
    return(req_parse_early_price_sheet(
      path, mapping_row, release_meta, asset_meta
    ))
  }
  if (identical(family, "history_cross_section")) {
    return(req_parse_early_cross_section(
      path, mapping_row, release_meta, asset_meta
    ))
  }
  mat <- req_read_matrix(path, sheet)
  blocks <- req_early_period_blocks(mat)
  if (length(blocks) > 1L) {
    derived_block <- vapply(blocks, function(block) {
      marker_rows <- seq.int(max(1L, block$row - 3L), block$row + 1L)
      marker_rows <- marker_rows[marker_rows <= nrow(mat)]
      marker_cols <- seq.int(min(block$period_cols), max(block$period_cols))
      marker <- paste(
        req_clean_text(mat[marker_rows, marker_cols, drop = FALSE]),
        collapse = " "
      )
      grepl(
        "change from|previous year|annual change|growth rate|cagr",
        marker,
        ignore.case = TRUE
      )
    }, logical(1))
    blocks <- blocks[!derived_block]
  }
  if (!length(blocks)) {
    req_abort(
      "req_workbook_schema_error",
      "Early REQ data sheet has no recognised period grid.",
      source_sheet = sheet,
      table_id = table_id,
      remediation = "Audit the exact early-workbook structure."
    )
  }
  title <- req_table_title(mat, sheet)
  note_metadata <- req_sheet_note_metadata(mat)
  historical <- identical(asset_meta$logical_dataset, "historical")
  claimed <- matrix(FALSE, nrow(mat), ncol(mat))
  first_header <- min(vapply(blocks, `[[`, integer(1), "row"))
  if (first_header > 1L) claimed[seq_len(first_header - 1L), ] <- TRUE
  observations <- list()
  diagnostics <- list()
  series_cache <- new.env(hash = TRUE, parent = emptyenv())
  observation_index <- 0L
  block_rows <- vapply(blocks, `[[`, integer(1), "row")
  first_value_col <- min(unlist(lapply(blocks, `[[`, "period_cols")))

  for (block_index in seq_along(blocks)) {
    block <- blocks[[block_index]]
    adjacent_headers <- block_rows[
      block_rows >= block$row & block_rows <= block$row + 2L
    ]
    header_end <- max(c(
      block$row + as.integer(block$consumes_suffix),
      adjacent_headers
    ))
    next_rows <- block_rows[block_rows > header_end + 2L]
    end_row <- if (length(next_rows)) min(next_rows) - 1L else nrow(mat)
    data_start <- header_end + 1L
    periods <- req_early_periods(block, mat, release_meta, historical)
    local_unit_col <- min(block$period_cols) - 1L
    grid_marker_rows <- seq.int(max(1L, block$row - 4L), block$row)
    grid_marker_cols <- seq.int(
      max(1L, local_unit_col - 2L),
      max(block$period_cols)
    )
    grid_markers <- req_clean_text(
      mat[grid_marker_rows, grid_marker_cols, drop = FALSE]
    )
    grid_markers <- grid_markers[
      !is.na(grid_markers) & grepl(
        "^(Volume|Value|Quantity|Price|Production)$",
        grid_markers,
        ignore.case = TRUE
      )
    ]
    grid_heading <- if (length(grid_markers)) grid_markers[[1L]] else ""
    claimed[block$row, block$period_cols] <- TRUE
    if (block$consumes_suffix) {
      claimed[block$row + 1L, block$period_cols] <- TRUE
    }
    if (data_start <= end_row) {
      claimed[
        seq.int(data_start, end_row),
        block$period_cols
      ] <- TRUE
    }
    if (first_value_col > 1L) {
      claimed[
        seq.int(block$row, end_row),
        seq_len(first_value_col - 1L)
      ] <- TRUE
    }

    if (data_start > end_row) next
    last_label <- ""
    heading <- ""
    heading_col <- NA_integer_
    heading_row <- NA_integer_
    basis_heading <- ""
    section_heading <- ""
    previous_data_label <- ""
    value_parent_label <- ""
    unit_probe_rows <- seq.int(
      data_start,
      min(end_row, data_start + 2L)
    )
    unit_probe <- req_clean_text(
      mat[unit_probe_rows, block$period_cols, drop = FALSE]
    )
    unit_probe <- unit_probe[
      !is.na(unit_probe) & nzchar(unit_probe) &
        vapply(unit_probe, req_unit_like, logical(1))
    ]
    block_unit <- if (length(unit_probe)) {
      req_normalise_unit(names(sort(table(unit_probe), decreasing = TRUE))[[1L]])
    } else {
      "not_applicable"
    }
    for (row_index in seq.int(data_start, end_row)) {
      raw_values <- req_clean_text(mat[row_index, block$period_cols])
      data_like <- !is.na(raw_values) & nzchar(raw_values) & (
        !is.na(suppressWarnings(as.numeric(raw_values))) |
          tolower(raw_values) %in% c(
            "na", "#n/a", "n/a", "not applicable", "nil",
            "not available", "unavailable", "n.av.", "confidential",
            "c", "suppressed", "..", "\u2014", "-"
          )
      )
      semantic <- req_early_label_unit(
        mat, row_index, first_value_col
      )
      if (!any(data_like)) {
        if (nzchar(semantic$label)) {
          if (grepl(
            "^(.*Production|Sales|Exports?|Imports?|Prices?|Consumption|Stocks?|Trade)$",
            semantic$label,
            ignore.case = TRUE
          )) {
            section_heading <- semantic$label
            heading <- ""
            heading_col <- NA_integer_
            heading_row <- NA_integer_
            previous_data_label <- ""
          } else if (grepl(
            "current prices|chain volume|constant prices|volume measures",
            semantic$label,
            ignore.case = TRUE
          )) {
            basis_heading <- semantic$label
          } else if (!vapply(semantic$label, req_unit_like, logical(1))) {
            heading <- semantic$label
            heading_col <- semantic$label_col
            heading_row <- row_index
            previous_data_label <- ""
          }
        }
        next
      }
      label <- semantic$label
      supporting <- FALSE
      if (!nzchar(label)) {
        label <- last_label
        supporting <- TRUE
      }
      if (!nzchar(label)) {
        req_abort(
          "req_sheet_parse_error",
          "Early REQ period-grid value has no semantic row label.",
          source_sheet = sheet,
          table_id = table_id,
          remediation = paste0("Inspect workbook row ", row_index, ".")
        )
      }
      last_label <- label
      if (grepl(
        "^(.*Production|Sales|Exports?|Imports?|Prices?|Consumption|Stocks?|Trade)$",
        label,
        ignore.case = TRUE
      )) {
        section_heading <- label
        previous_data_label <- ""
      }
      if (nzchar(heading) && !is.na(semantic$label_col) &&
          !is.na(heading_col) && semantic$label_col <= heading_col &&
          !identical(heading, label) &&
          grepl("^Total\\b", previous_data_label, ignore.case = TRUE)) {
        heading <- ""
        heading_col <- NA_integer_
        heading_row <- NA_integer_
      }
      if (!grepl(
        "^[\u2013-]|^(nominal|real)\\s+value\\b",
        label,
        ignore.case = TRUE
      )) {
        value_parent_label <- label
      }
      parents <- c(
        if (nzchar(section_heading)) section_heading else character(),
        if (nzchar(grid_heading)) grid_heading else character(),
        if (nzchar(basis_heading)) basis_heading else character(),
        if (grepl("^[\u2013-]", label) && nzchar(previous_data_label)) {
          previous_data_label
        } else if (
          grepl("^(nominal|real)\\s+value\\b", label, ignore.case = TRUE) &&
            nzchar(value_parent_label)
        ) {
          value_parent_label
        } else {
          character()
        },
        if (nzchar(heading) && !identical(heading, label)) {
          heading
        } else {
          character()
        }
      )
      dims <- req_infer_dimensions(
        table_id, family, title, label, parents
      )
      geography <- req_early_geography(label)
      if (!is.null(geography)) {
        dims$geography <- geography$geography
        dims$geography_type <- geography$geography_type
      }
      dims$concept <- req_slug(paste(
        sub("^(history|forecast)_", "", table_id),
        paste(parents, collapse = " "),
        label,
        dims$concept
      ))
      parsed <- req_parse_numeric_tokens(
        raw_values[data_like], sheet, table_id, row_index,
        block$period_cols[data_like]
      )
      for (position in which(data_like)) {
        parsed_position <- match(position, which(data_like))
        unit <- req_normalise_unit(semantic$unit)
        if (local_unit_col >= 1L) {
          local_unit <- req_clean_text(mat[row_index, local_unit_col])
          if (!is.na(local_unit) && nzchar(local_unit) &&
              req_unit_like(local_unit)) {
            unit <- req_normalise_unit(local_unit)
          }
        }
        if (!nzchar(unit) || identical(unit, "not_applicable")) {
          unit <- block_unit
        }
        status <- periods$period_status[[position]]
        status_source <- periods$status_source[[position]]
        row <- list(
          product = "resources_energy_quarterly",
          release_id = release_meta$release_id,
          release_date = release_meta$release_date,
          dataset = "resources_energy_quarterly",
          source_dataset = asset_meta$logical_dataset,
          source_asset = asset_meta$source_dataset,
          source_sheet = sheet,
          table_id = table_id,
          table_title = title,
          record_role = if (supporting) "supporting" else "canonical",
          geography_type = dims$geography_type,
          geography = dims$geography,
          commodity = dims$commodity,
          concept = dims$concept,
          period = periods$period[[position]],
          period_start = periods$period_start[[position]],
          period_end = periods$period_end[[position]],
          period_basis = periods$period_basis[[position]],
          period_status = status,
          status_source = status_source,
          price_basis = req_price_basis(
            paste(c(parents, label), collapse = " \u2014 "),
            title, unit
          ),
          currency = req_currency(unit),
          unit = unit,
          value = parsed$value[[parsed_position]],
          raw_value = raw_values[[position]],
          missing_reason = parsed$missing_reason[[parsed_position]],
          footnote_codes = I(list(character())),
          source_note = note_metadata$note,
          series_id = "",
          observation_key = "",
          retrieved_at = asset_meta$retrieved_at,
          sha256 = asset_meta$sha256,
          parser_version = .req_parser_version,
          section = dims$section,
          frequency = periods$frequency[[position]]
        )
        row$series_id <- req_semantic_id_cached(row, series_cache)
        row$observation_key <- paste(row$series_id, row$period, sep = "::")
        observation_index <- observation_index + 1L
        observations[[observation_index]] <- row
      }
      diagnostics[[length(diagnostics) + 1L]] <- data.frame(
        source_sheet = sheet,
        table_id = table_id,
        row = row_index,
        period_cells = sum(data_like),
        parsed_cells = sum(data_like),
        control_cells = 0L,
        stringsAsFactors = FALSE
      )
      previous_data_label <- label
    }
  }

  marker_text <- apply(
    mat[seq_len(min(20L, nrow(mat))), , drop = FALSE],
    2L,
    function(column) paste(req_clean_text(column), collapse = " ")
  )
  derived <- which(grepl(
    "change|growth|cagr", marker_text, ignore.case = TRUE
  ))
  if (length(derived)) claimed[, derived] <- TRUE
  published_max <- max(unlist(lapply(blocks, `[[`, "period_cols")))
  if (published_max < ncol(mat)) {
    trailing <- seq.int(published_max + 1L, ncol(mat))
    spacer <- trailing[[1L]]
    spacer_values <- req_clean_text(mat[, spacer])
    spacer_blank <- all(
      is.na(spacer_values) | !nzchar(spacer_values) |
        tolower(spacer_values) %in% c("s", "f", "z", "p", "a")
    )
    if (spacer_blank && length(trailing) > 1L) {
      control_candidates <- trailing[-1L]
      if (any(derived %in% control_candidates)) {
        claimed[, control_candidates] <- TRUE
      } else {
        numeric_only <- vapply(control_candidates, function(column) {
          values <- req_clean_text(mat[, column])
          nonempty <- !is.na(values) & nzchar(values)
          all(!nonempty | !is.na(suppressWarnings(as.numeric(values))))
        }, logical(1))
        claimed[, control_candidates[numeric_only]] <- TRUE
      }
    }
  }
  data_tokens <- req_clean_text(mat)
  dim(data_tokens) <- dim(mat)
  data_like <- !is.na(suppressWarnings(as.numeric(data_tokens))) |
    tolower(data_tokens) %in% c(
      "na", "#n/a", "n/a", "not applicable", "nil", "not available",
      "unavailable", "n.av.", "confidential", "c", "suppressed", "..",
      "\u2014", "-"
    )
  unknown <- which(
    data_like & !claimed & row(mat) >= first_header,
    arr.ind = TRUE
  )
  if (nrow(unknown)) {
    cell <- unknown[1L, ]
    req_abort(
      "req_sheet_parse_error",
      paste0(
        "Early REQ data-like cell is outside an audited period/control block: ",
        mat[cell[[1L]], cell[[2L]]]
      ),
      source_sheet = sheet,
      table_id = table_id,
      remediation = paste0(
        "Inspect workbook row ", cell[[1L]], ", column ", cell[[2L]], "."
      )
    )
  }
  list(
    data = req_observation_frame(observations),
    diagnostics = if (length(diagnostics)) {
      do.call(rbind, diagnostics)
    } else {
      data.frame()
    }
  )
}

req_parse_early_workbook <- function(
    path, source_dataset, release_meta, retrieved_at, sha256, sheets) {
  mapping <- req_map_workbook(path, source_dataset)
  selected <- mapping$classification == "data_table"
  if (!identical(sheets, "all")) {
    requested <- as.character(sheets)
    selected <- selected & (
      mapping$table_id %in% requested |
        mapping$source_sheet %in% requested |
        req_slug(mapping$source_sheet) %in% req_slug(requested)
    )
  }
  if (!any(selected)) {
    req_abort(
      "req_sheet_parse_error",
      "No requested early-REQ sheet IDs or aliases were found.",
      asset_type = source_dataset,
      remediation = "Inspect the early workbook mapping."
    )
  }
  asset_meta <- list(
    source_dataset = source_dataset,
    logical_dataset = if (identical(
      source_dataset, "statistical"
    ) && identical(release_meta$release_id, "req-2011-09")) {
      "forecast"
    } else if (source_dataset %in%
        c("statistical", "historical_statistical", "historical_commodity")) {
      "historical"
    } else {
      "forecast"
    },
    retrieved_at = as.POSIXct(retrieved_at, tz = "UTC"),
    sha256 = sha256
  )
  parsed <- lapply(which(selected), function(index) {
    req_parse_early_sheet(
      path, mapping[index, , drop = FALSE], release_meta, asset_meta
    )
  })
  data <- data.table::rbindlist(
    lapply(parsed, `[[`, "data"), use.names = TRUE, fill = TRUE
  )
  data.table::setDF(data)
  diagnostics <- data.table::rbindlist(
    lapply(parsed, `[[`, "diagnostics"), use.names = TRUE, fill = TRUE
  )
  data.table::setDF(diagnostics)
  attr(data, "sheet_mapping") <- mapping
  attr(data, "parse_diagnostics") <- diagnostics
  data
}
