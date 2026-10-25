req_xlsx_layout_rows <- function(workbook, worksheet, sheet_index) {
  hidden <- xml2::xml_find_all(
    worksheet,
    ".//*[local-name()='row'][@hidden='1' or @hidden='true']"
  )
  hidden_rows <- suppressWarnings(as.integer(xml2::xml_attr(hidden, "r")))
  hidden_rows <- hidden_rows[!is.na(hidden_rows)]

  print_names <- xml2::xml_find_all(
    workbook,
    ".//*[local-name()='definedName'][@name='_xlnm.Print_Area']"
  )
  local_index <- suppressWarnings(as.integer(
    xml2::xml_attr(print_names, "localSheetId")
  ))
  print_name <- print_names[local_index == sheet_index - 1L]
  max_print_row <- NA_integer_
  if (length(print_name) == 1L) {
    area <- xml2::xml_text(print_name)
    row_tokens <- regmatches(
      area,
      gregexpr("\\$[0-9]+", area, perl = TRUE)
    )[[1L]]
    if (length(row_tokens) && !identical(row_tokens, character(0))) {
      max_print_row <- max(as.integer(sub("^\\$", "", row_tokens)))
    }
  }
  list(
    hidden_rows = sort(unique(hidden_rows)),
    max_print_row = max_print_row
  )
}

req_xlsx_sheet_layout <- function(path, sheet) {
  empty <- list(hidden_rows = integer(), max_print_row = NA_integer_)
  if (!grepl("\\.xlsx$", path, ignore.case = TRUE)) return(empty)
  members <- tryCatch(
    utils::unzip(path, list = TRUE)$Name,
    error = function(error) character()
  )
  required <- c("xl/workbook.xml", "xl/_rels/workbook.xml.rels")
  if (!all(required %in% members)) return(empty)

  workbook <- xml2::read_xml(unz(path, "xl/workbook.xml"))
  sheets <- xml2::xml_find_all(
    workbook, ".//*[local-name()='sheet']"
  )
  sheet_index <- match(sheet, xml2::xml_attr(sheets, "name"))
  if (is.na(sheet_index)) return(empty)
  relationship_id <- xml2::xml_attr(sheets[[sheet_index]], "id")

  relationships <- xml2::read_xml(
    unz(path, "xl/_rels/workbook.xml.rels")
  )
  relationship <- xml2::xml_find_all(
    relationships, ".//*[local-name()='Relationship']"
  )
  relationship <- relationship[
    xml2::xml_attr(relationship, "Id") == relationship_id
  ]
  if (length(relationship) != 1L) return(empty)
  target <- xml2::xml_attr(relationship, "Target")
  worksheet_member <- if (startsWith(target, "/")) {
    sub("^/", "", target)
  } else {
    file.path("xl", target)
  }
  worksheet_member <- gsub("(^|/)\\./", "\\1", worksheet_member)
  if (!worksheet_member %in% members) return(empty)

  worksheet <- xml2::read_xml(unz(path, worksheet_member))
  req_xlsx_layout_rows(workbook, worksheet, sheet_index)
}

req_control_row_profile <- function(
    release_id, source_sheet, table_id, fingerprint) {
  profiles <- list(
    list(
      release_id = "req-2015-03",
      source_sheet = "Thermal coal",
      table_id = "forecast_thermal_coal",
      fingerprint =
        "93acea347ba4c6a8fa7b97771803812b8d2b578c7c0dc236cb8d5a49a5f73869",
      rows = 40L,
      evidence = "outside_print_area",
      requires_blank_context = TRUE
    ),
    list(
      release_id = "req-2015-06",
      source_sheet = "Commodity sector",
      table_id = "forecast_commodity_sector",
      fingerprint =
        "ee243798dac5b9687812eec3c243408931c4fdaa227a9c797b19c8dda8e1cc55",
      rows = 11:13,
      evidence = "hidden",
      requires_blank_context = FALSE
    ),
    list(
      release_id = "req-2016-06",
      source_sheet = "Commodity sector",
      table_id = "forecast_commodity_sector",
      fingerprint =
        "105610fed835f8e0802e6c05dd68cd02ab06dee8748dd3a851f2fafd7a01918f",
      rows = 13:15,
      evidence = "hidden",
      requires_blank_context = FALSE
    ),
    list(
      release_id = "req-2016-12",
      source_sheet = "Commodity sector",
      table_id = "forecast_commodity_sector",
      fingerprint =
        "d2dc9ad5034d5c02186240895f52e2aebe9473b13dde230d47365ec01d6e71c1",
      rows = 13:15,
      evidence = "hidden",
      requires_blank_context = FALSE
    ),
    list(
      release_id = "req-2020-09",
      source_sheet = "27",
      table_id = "history_commodity_gold",
      fingerprint =
        "ca704169327d662a45e28d19788f23557aefc159784ca823e468ba44aea2885b",
      rows = 46:47,
      evidence = "unlabelled_chart_helpers",
      requires_blank_context = TRUE
    )
  )
  matched <- Filter(function(profile) {
    identical(profile$release_id, release_id) &&
      identical(profile$source_sheet, source_sheet) &&
      identical(profile$table_id, table_id) &&
      identical(profile$fingerprint, fingerprint)
  }, profiles)
  if (!length(matched)) return(NULL)
  matched[[1L]]
}

req_verified_control_row_profile <- function(
    path, release_meta, mapping_row) {
  profile <- req_control_row_profile(
    release_meta$release_id,
    mapping_row$source_sheet[[1L]],
    mapping_row$table_id[[1L]],
    mapping_row$fingerprint[[1L]]
  )
  if (is.null(profile)) return(NULL)
  if (profile$evidence %in% c("hidden", "outside_print_area")) {
    layout <- req_xlsx_sheet_layout(path, profile$source_sheet)
    verified <- if (profile$evidence == "hidden") {
      all(profile$rows %in% layout$hidden_rows)
    } else {
      !is.na(layout$max_print_row) &&
        all(profile$rows > layout$max_print_row)
    }
    if (!verified) {
      req_abort(
        "req_workbook_schema_error",
        "A release-specific calculation-control profile no longer matches workbook metadata.",
        source_sheet = profile$source_sheet,
        table_id = profile$table_id,
        remediation = "Audit the exact workbook structure before parsing."
      )
    }
  }
  profile
}

req_read_matrix <- function(path, sheet) {
  x <- suppressWarnings(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE, trim_ws = FALSE,
    .name_repair = "minimal"
  ))
  if (!nrow(x) || !ncol(x)) {
    req_abort(
      "req_sheet_parse_error",
      paste0("Sheet '", sheet, "' is empty."),
      source_sheet = sheet,
      remediation = "Confirm the official workbook is readable and complete."
    )
  }
  m <- as.matrix(x)
  storage.mode(m) <- "character"
  apply(m, 2, req_clean_text)
}

req_period_candidates <- function(row) {
  z <- req_clean_text(row)
  z <- sub("^((18|19|20)[0-9]{2})\\.0+$", "\\1", z)
  numeric_year <- suppressWarnings(as.numeric(z))
  is_year <- !is.na(numeric_year) & numeric_year >= 1800 & numeric_year <= 2099 &
    abs(numeric_year - round(numeric_year)) < 1e-8
  z[is_year] <- sprintf("%d", as.integer(round(numeric_year[is_year])))
  explicit <- grepl(
    paste0(
      "^(18|19|20)[0-9]{2}([\u2013-][0-9]{2})?\\s*[a-z]?$|",
      "^(Mar|Jun|Sep|Dec)[\u2013 -]?[0-9]{2,4}\\s*[a-z]?$|",
      "^[12][0-9]{3}[- ]?Q[1-4]\\s*[a-z]?$"
    ),
    z, ignore.case = TRUE
  )
  explicit_idx <- which(explicit)
  if (length(explicit_idx) >= 2L) {
    plain_year <- grepl("^(18|19|20)[0-9]{2}$", z[explicit_idx])
    if (all(plain_year)) {
      years <- as.integer(z[explicit_idx])
      if (any(diff(years) <= 0L | diff(years) > 10L)) explicit[] <- FALSE
    }
  }
  serial <- suppressWarnings(as.numeric(z))
  serial_ok <- !is.na(serial) & serial >= 20000 & serial <= 60000 &
    abs(serial - round(serial)) < 1e-8
  serial_idx <- which(serial_ok)
  if (length(serial_idx) >= 3L) {
    d <- diff(serial[serial_idx])
    plausible <- all(d > 0) && stats::median(d) >= 20 && stats::median(d) <= 370
    if (!plausible) serial_ok[] <- FALSE
  } else {
    serial_ok[] <- FALSE
  }
  which(explicit | serial_ok)
}

req_split_period_clusters <- function(cols, labels = NULL) {
  if (!length(cols)) return(list())
  breaks <- diff(cols) > 2L
  if (!is.null(labels) && length(cols) > 1L) {
    starts <- suppressWarnings(req_period(labels)$period_start)
    reset <- diff(as.numeric(starts)) <= 0
    reset[is.na(reset)] <- FALSE
    breaks <- breaks | reset
  }
  split(cols, cumsum(c(TRUE, breaks)))
}

req_header_blocks <- function(mat, family) {
  rows <- lapply(seq_len(nrow(mat)), function(i) {
    cols <- req_period_candidates(mat[i, ])
    if (length(cols) < 2L) return(NULL)
    clusters <- tryCatch(
      req_split_period_clusters(cols, mat[i, cols]),
      error = function(e) req_split_period_clusters(cols)
    )
    clusters <- clusters[vapply(clusters, length, integer(1)) >= 2L]
    if (!length(clusters)) return(NULL)
    lapply(clusters, function(period_cols) {
      unit_col <- min(period_cols) - 1L
      label_col <- max(1L, unit_col - 1L)
      # World macro-style grids put a fixed unit in the label/header cell.
      if (unit_col < 1L) {
        unit_col <- 1L
        label_col <- 1L
      }
      marker_rows <- seq.int(i, min(nrow(mat), i + 2L))
      columns_left <- seq_len(max(1L, min(period_cols) - 1L))
      marker_grid <- mat[marker_rows, columns_left, drop = FALSE]
      explicit_unit_cols <- unique(
        arrayInd(
          which(grepl(
            "^units?$", req_clean_text(marker_grid), ignore.case = TRUE
          )),
          dim(marker_grid)
        )[, 2]
      )
      if (length(explicit_unit_cols)) {
        # Some historical sheets place annual and quarterly grids on the same
        # row. The quarterly periods can begin several blank columns after the
        # one published label/unit pair, so adjacency is not a valid rule.
        unit_col <- max(columns_left[explicit_unit_cols])
        label_col <- max(1L, unit_col - 1L)
      }
      header_unit <- req_clean_text(mat[marker_rows, unit_col])
      has_unit_marker <- any(
        !is.na(header_unit) &
          grepl("^units?$", header_unit, ignore.case = TRUE)
      )
      if (!has_unit_marker) {
        label_col <- unit_col
      }
      hint <- if (family == "history_monthly") "monthly" else NULL
      measure <- ""
      if (i > 1L) {
        above <- req_clean_text(mat[seq_len(i - 1L), min(period_cols)])
        above <- above[
          !is.na(above) & nzchar(above) &
            !req_is_period_label(above) &
            is.na(suppressWarnings(as.numeric(above))) &
            !grepl("^[-\u2013\u2014]1[-\u2013\u2014]$", above)
        ]
        if (length(above)) measure <- utils::tail(above, 1L)
      }
      list(
        row = i, period_cols = period_cols, unit_col = unit_col,
        label_col = label_col, frequency_hint = hint, measure = measure,
        has_unit_marker = has_unit_marker
      )
    })
  })
  blocks <- unlist(rows, recursive = FALSE)
  if (length(blocks) > 1L) {
    keep <- rep(TRUE, length(blocks))
    marked <- which(vapply(
      blocks,
      function(block) isTRUE(block$has_unit_marker),
      logical(1)
    ))
    unmarked <- setdiff(seq_along(blocks), marked)
    for (candidate in unmarked) {
      for (reference in marked) {
        nearby <- abs(
          blocks[[candidate]]$row - blocks[[reference]]$row
        ) <= 6L
        nested_columns <-
          all(blocks[[candidate]]$period_cols %in%
            blocks[[reference]]$period_cols) ||
          all(blocks[[reference]]$period_cols %in%
            blocks[[candidate]]$period_cols)
        if (nearby && nested_columns) {
          keep[[candidate]] <- FALSE
          break
        }
      }
    }
    for (index in seq.int(2L, length(blocks))) {
      previous <- blocks[[index - 1L]]
      current <- blocks[[index]]
      if (current$row == previous$row + 1L &&
          all(current$period_cols %in% previous$period_cols)) {
        # Early XLS files repeat the most recent display-period labels on a
        # helper row directly beneath the complete header. It is not a second
        # data grid and must not truncate the full historical block.
        keep[[index]] <- FALSE
      }
    }
    blocks <- blocks[keep]
  }
  if (!length(blocks)) {
    req_abort(
      "req_workbook_schema_error",
      "No structural period grid was recognised in a data-bearing sheet.",
      remediation = "Inspect the header labels and add a release profile."
    )
  }
  blocks
}

req_table_title <- function(mat, sheet) {
  cells <- req_clean_text(as.vector(mat[seq_len(min(nrow(mat), 12L)), , drop = FALSE]))
  cells <- cells[!is.na(cells) & nzchar(cells)]
  cells <- cells[
    !grepl("logo|back to table|^unit$", cells, ignore.case = TRUE) &
      is.na(suppressWarnings(as.numeric(cells))) &
      !req_is_period_label(cells) &
      !vapply(cells, req_unit_like, logical(1))
  ]
  if (!length(cells)) sheet else cells[[which.max(nchar(cells))]]
}

req_sheet_note_metadata <- function(mat) {
  row_text <- apply(mat, 1, function(z) {
    z <- req_clean_text(z)
    z <- z[!is.na(z) & nzchar(z)]
    paste(z, collapse = " ")
  })
  note_start <- which(grepl("(^| )notes?:", row_text, ignore.case = TRUE))
  source_rows <- which(grepl("(^| )sources?:", row_text, ignore.case = TRUE))
  selected <- source_rows
  if (length(note_start)) {
    first <- min(note_start)
    end <- if (length(source_rows[source_rows >= first])) {
      max(source_rows[source_rows >= first])
    } else {
      nrow(mat)
    }
    selected <- unique(c(selected, seq.int(first, end)))
  }
  selected <- selected[nzchar(row_text[selected])]
  note <- if (length(selected)) {
    paste(row_text[selected], collapse = " | ")
  } else {
    NA_character_
  }
  code_text <- row_text[selected]
  codes <- unique(tolower(sub(
    "^\\s*([a-z]{1,3})\\s+.*$", "\\1",
    code_text[grepl("^\\s*[a-z]{1,3}\\s+", code_text, ignore.case = FALSE)]
  )))
  list(note = note, codes = codes)
}

req_row_footnotes <- function(label, known_codes) {
  if (!length(known_codes) || !nzchar(label)) return(character())
  token <- tolower(sub(".*\\s+([a-z]{1,3})$", "\\1", label))
  if (identical(token, tolower(label))) return(character())
  if (token %in% known_codes) return(strsplit(token, "", fixed = TRUE)[[1]])
  chars <- strsplit(token, "", fixed = TRUE)[[1]]
  if (length(chars) && all(chars %in% known_codes)) chars else character()
}

req_strip_footnote_suffix <- function(label, known_codes) {
  codes <- req_row_footnotes(label, known_codes)
  if (!length(codes)) return(req_clean_text(label))
  req_clean_text(sub("\\s+[a-z]{1,3}$", "", label, ignore.case = TRUE))
}

req_unit_like <- function(x) {
  grepl(
    "\\$|%|^USc/|^['\u2019]000( ct)?$|^([kM]?t|[kM]?m3|kg|g|oz|lb|bbl|ML|Bcm|Mcm|GJ|PJ|TWh|mb.?d|kb.?d|index|number|persons)$",
    req_clean_text(x), ignore.case = TRUE
  )
}

req_parse_numeric_tokens <- function(x, sheet, table_id, row, cols) {
  token <- tolower(req_clean_text(x))
  spaced_thousands <- grepl(
    "^[+-]?[0-9]{1,3}( [0-9]{3})+(\\.[0-9]+)?$",
    token
  )
  token[spaced_thousands] <- gsub(" ", "", token[spaced_thousands], fixed = TRUE)
  unicode_minus <- grepl(
    "^[\u2013\u2014]\\s*[0-9]+(\\.[0-9]+)?$",
    token
  )
  token[unicode_minus] <- sub(
    "^[\u2013\u2014]\\s*",
    "-",
    token[unicode_minus]
  )
  reason <- rep(NA_character_, length(token))
  reason[token %in% c("na", "#n/a")] <- "provider_na"
  reason[token %in% c("n/a", "not applicable", "nil")] <- "not_applicable"
  reason[token %in% c("not available", "unavailable", "n.av.")] <- "unavailable"
  reason[token %in% c("confidential", "c")] <- "confidential"
  reason[token %in% c("suppressed", "..", "\u2014", "-")] <- "suppressed"
  value <- suppressWarnings(as.numeric(token))
  bad <- is.na(reason) & is.na(value)
  if (any(bad)) {
    which_bad <- which(bad)[[1]]
    req_abort(
      "req_sheet_parse_error",
      paste0("Non-empty value could not be parsed: ", x[[which_bad]]),
      source_sheet = sheet, table_id = table_id,
      remediation = paste0(
        "Inspect workbook row ", row, ", column ", cols[[which_bad]], "."
      )
    )
  }
  value[!is.na(reason)] <- NA_real_
  list(value = value, missing_reason = reason)
}

req_assert_numeric_cells_claimed <- function(
    mat, claimed, data_rows, sheet, table_id, release_id = NA_character_,
    published_max_col = NULL) {
  if (!length(data_rows)) return(invisible(TRUE))
  tokens <- tolower(req_clean_text(mat))
  dim(tokens) <- dim(mat)
  numeric <- !is.na(suppressWarnings(as.numeric(tokens)))
  dim(numeric) <- dim(mat)
  data_markers <- tokens %in% c(
    "na", "#n/a", "n/a", "not applicable", "nil", "not available",
    "unavailable", "n.av.", "confidential", "c", "suppressed", "..",
    "\u2014", "-"
  )
  dim(data_markers) <- dim(mat)
  data_like <- numeric | data_markers
  header_rows <- seq_len(max(1L, min(data_rows) - 1L))
  labelled_column <- vapply(seq_len(ncol(mat)), function(column) {
    z <- tokens[header_rows, column]
    any(!is.na(z) & nzchar(z) & !data_like[header_rows, column])
  }, logical(1))
  profiled_control_columns <- integer()
  if (identical(release_id, "req-2024-03") &&
      !is.null(published_max_col) &&
      ncol(mat) >= published_max_col + 2L) {
    trailing <- seq.int(published_max_col + 1L, ncol(mat))
    spacer <- trailing[[1]]
    controls <- trailing[-1L]
    blank_spacer <- all(is.na(tokens[, spacer]) | !nzchar(tokens[, spacer]))
    unlabelled_controls <- all(!labelled_column[controls])
    if (blank_spacer && unlabelled_controls) {
      # This audited legacy workbook retains hidden calculation columns after
      # a blank spacer following several published FY grids. They are source
      # controls, not an additional data surface, and can differ from the
      # displayed cells because of workbook formula state.
      profiled_control_columns <- controls
    }
  }
  if (length(profiled_control_columns) &&
      all(!labelled_column[profiled_control_columns])) {
    claimed[data_rows, profiled_control_columns] <- TRUE
  }
  # Older workbooks retain unlabelled hidden formula columns duplicating the
  # final published period values. Admit only exact row-wise redundancies;
  # any labelled or novel data-like column remains a hard schema failure.
  candidates <- which(
    data_like & !claimed & row(mat) %in% data_rows,
    arr.ind = TRUE
  )
  if (nrow(candidates)) {
    for (index in seq_len(nrow(candidates))) {
      cell <- candidates[index, ]
      r <- cell[[1]]
      column <- cell[[2]]
      if (labelled_column[[column]]) next
      published <- which(claimed[r, ] & data_like[r, ])
      if (!length(published)) next
      same <- if (numeric[r, column]) {
        values <- suppressWarnings(as.numeric(tokens[r, published]))
        any(
          !is.na(values) &
            abs(values - as.numeric(tokens[r, column])) <=
              1e-6 * pmax(1, abs(values))
        )
      } else {
        any(tokens[r, published] == tokens[r, column])
      }
      if (same) claimed[r, column] <- TRUE
    }
  }
  unknown <- which(
    data_like & !claimed &
      row(mat) %in% data_rows,
    arr.ind = TRUE
  )
  if (!nrow(unknown)) return(invisible(TRUE))
  cell <- unknown[1L, , drop = FALSE]
  req_abort(
    "req_sheet_parse_error",
    paste0(
      "Data-like cell lies outside every recognised data/control block: ",
      mat[cell[[1]], cell[[2]]]
    ),
    source_sheet = sheet,
    table_id = table_id,
    remediation = paste0(
      "Inspect workbook row ", cell[[1]], ", column ", cell[[2]],
      "; classify the new block explicitly before admitting the release."
    )
  )
}

req_parent_labels <- function(mat, row, label_col, block_start,
                              period_cols = integer()) {
  if (row <= block_start + 1L) return(character())
  idx <- seq.int(block_start + 1L, row - 1L)
  labels <- req_clean_text(mat[idx, label_col])
  usable <- !is.na(labels) & nzchar(labels) &
    !grepl("notes?:|sources?:|tableend|back to", labels, ignore.case = TRUE)
  if (length(period_cols)) {
    has_period_values <- apply(
      mat[idx, period_cols, drop = FALSE], 1,
      function(z) any(!is.na(req_clean_text(z)) & nzchar(req_clean_text(z)))
    )
    usable <- usable & !has_period_values
  }
  label_rows <- idx[usable]
  labels <- labels[usable]
  keep <- !is.na(labels) & nzchar(labels) &
    !grepl("notes?:|sources?:|tableend|back to", labels, ignore.case = TRUE)
  label_rows <- label_rows[keep]
  labels <- labels[
    keep
  ]
  if (!length(labels)) return(character())
  heading_labels <- sub("\\s+[a-z]{1,3}$", "", labels, ignore.case = TRUE)
  major <- grepl(
    paste0(
      "^(production|consumption|exports?|imports?|prices?|stocks?|",
      "resources?|reserves?|exploration|employment|shipments?|capacity|",
      "trade|demand|supply|value of exports?)$"
    ),
    heading_labels, ignore.case = TRUE
  )
  if (!any(major)) return(utils::tail(labels, 1L))
  major_row <- max(label_rows[major])
  major_label <- labels[label_rows == major_row][[1L]]
  after_major <- label_rows > major_row
  minor_labels <- labels[after_major]
  minor_rows <- label_rows[after_major]
  measure <- grepl(
    "^(quantity|volume|value|mine|smelter( and refinery)?|refinery|primary|secondary)$",
    minor_labels, ignore.case = TRUE
  )
  if (!any(measure)) {
    return(unique(c(major_label, utils::tail(minor_labels, 1L))))
  }
  measure_row <- max(minor_rows[measure])
  measure_label <- minor_labels[minor_rows == measure_row][[1L]]
  leaf <- minor_labels[minor_rows > measure_row]
  unique(c(major_label, measure_label, utils::tail(leaf, 1L)))
}

req_known_geography <- function(x) {
  x <- req_clean_text(x)
  x %in% c(
    "World", "Australia", "China", "Japan", "India", "South Korea",
    "Republic of Korea", "United States", "Canada", "Russia", "Mongolia",
    "Indonesia", "Colombia", "South Africa", "European Union", "Europe",
    "other Europe", "Trading Partner (Taiwan)", "New Zealand", "France",
    "Germany", "Euro Area", "United Kingdom", "Kazakhstan", "Africa",
    "Western Australia", "New South Wales", "Queensland", "South Australia",
    "Tasmania", "Northern Territory", "Victoria", "Australian Capital Territory"
  )
}

req_infer_dimensions <- function(table_id, family, title, label, parents,
                                 current_commodity = NULL) {
  label0 <- req_clean_text(label)
  path <- c(parents, label0)
  path <- path[nzchar(path)]
  context <- paste(path, collapse = " \u2014 ")
  section <- if (any(grepl("^world$", path, ignore.case = TRUE))) {
    "World"
  } else if (any(grepl("^Australia$", path, ignore.case = TRUE))) {
    "Australia"
  } else if (family == "history_markets") {
    "export destination"
  } else if (grepl("world", title, ignore.case = TRUE)) {
    "World"
  } else {
    "Australia"
  }

  geography <- if (family == "history_markets") {
    if (!is.null(current_commodity) &&
        (identical(req_slug(label0), current_commodity) ||
          endsWith(current_commodity, paste0("_", req_slug(label0))))) {
      "All destinations"
    } else {
      label0
    }
  } else if (req_known_geography(label0)) {
    label0
  } else {
    section
  }
  geography_type <- if (geography %in% c("World", "Australia")) {
    if (geography == "World") "world" else "country"
  } else if (geography %in% c(
    "Western Australia", "New South Wales", "Queensland", "South Australia",
    "Tasmania", "Northern Territory", "Victoria", "Australian Capital Territory"
  )) {
    "state_or_territory"
  } else if (family == "history_markets") {
    "export_destination"
  } else {
    "country"
  }

  commodity <- "resources_and_energy"
  if (grepl("^forecast_(quarterly|selected)", table_id)) commodity <- req_slug(label0)
  if (table_id == "forecast_commodity_sector") {
    commodity <- if (grepl("^[\u2013\u2014-]", label0) &&
        !is.null(current_commodity) && nzchar(current_commodity)) {
      current_commodity
    } else {
      req_slug(label0)
    }
  }
  if (grepl("^forecast_(steel|iron|metallurgical|thermal|oil|gas|uranium|gold|aluminium|copper|nickel|zinc|lithium)",
    table_id
  )) {
    commodity <- sub("^forecast_", "", table_id)
  }
  if (grepl("^history_commodity_", table_id)) {
    commodity <- sub("^history_commodity_", "", table_id)
    commodity <- sub("_part_[123]$", "", commodity)
  }
  if (grepl("^history_(annual|quarterly|monthly)", table_id) &&
      !req_known_geography(label0)) {
    commodity <- if (!is.null(current_commodity) && nzchar(current_commodity)) {
      current_commodity
    } else {
      req_slug(label0)
    }
  }
  if (family == "history_markets") {
    commodity <- if (!is.null(current_commodity) && nzchar(current_commodity)) {
      current_commodity
    } else {
      req_slug(label0)
    }
  }

  base_concept <- sub("^(forecast|history)_", "", table_id)
  concept <- req_slug(if (nzchar(context)) context else base_concept)
  if (grepl("export.*value", table_id)) {
    concept <- if (family == "history_markets") {
      "export_value"
    } else if (!is.null(current_commodity) && nzchar(current_commodity)) {
      paste0("export_value_", req_slug(label0))
    } else {
      "export_value"
    }
  }
  if (grepl("export.*volume", table_id)) {
    concept <- if (family == "history_markets") {
      "export_volume"
    } else if (!is.null(current_commodity) && nzchar(current_commodity)) {
      paste0("export_volume_", req_slug(label0))
    } else {
      "export_volume"
    }
  }
  if (grepl("quarterly_prices|world_prices|benchmark_prices", table_id)) {
    concept <- paste0("price_", req_slug(label0))
  }
  if (grepl("imports", table_id)) {
    concept <- if (!is.null(current_commodity) && nzchar(current_commodity)) {
      paste0("imports_", req_slug(label0))
    } else {
      "imports"
    }
  }
  if (grepl("production", table_id) && !grepl("world_prices", table_id)) {
    concept <- if (!is.null(current_commodity) && nzchar(current_commodity)) {
      paste0("production_", req_slug(label0))
    } else if (grepl("production", context, ignore.case = TRUE)) {
      req_slug(context)
    } else {
      "production"
    }
  }

  list(
    section = section, geography = geography,
    geography_type = geography_type, commodity = commodity, concept = concept
  )
}

req_parse_monthly_sheet <- function(path, mapping_row, release_meta, asset_meta) {
  sheet <- mapping_row$source_sheet[[1]]
  table_id <- mapping_row$table_id[[1]]
  mat <- req_read_matrix(path, sheet)
  title <- req_table_title(mat, sheet)
  note_metadata <- req_sheet_note_metadata(mat)
  header_row <- which.max(apply(mat, 1, function(z) {
    sum(!is.na(z) & nzchar(z) & is.na(suppressWarnings(as.numeric(z))))
  }))
  # REQ monthly tables publish series labels and units on adjacent header rows,
  # followed by a vertical Excel-date column. Locate these structurally.
  month_pattern <- paste0(
    "^(Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|",
    "Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|",
    "Dec(ember)?)[\u2013 -]?[0-9]{2,4}$"
  )
  date_col_scores <- vapply(seq_len(ncol(mat)), function(j) {
    text <- req_clean_text(mat[, j])
    serial <- suppressWarnings(as.numeric(text))
    serial_idx <- which(!is.na(serial) & serial >= 20000 & serial <= 60000)
    serial_score <- if (length(serial_idx) >= 3L) {
      d <- diff(serial[serial_idx])
      if (all(d > 0 & d <= 40)) length(serial_idx) else 0L
    } else {
      0L
    }
    text_idx <- which(grepl(month_pattern, text, ignore.case = TRUE))
    text_score <- if (length(text_idx) >= 3L) {
      p <- req_period(text[text_idx], frequency_hint = "monthly")
      d <- diff(as.numeric(p$period_start))
      if (all(d >= 28 & d <= 31)) length(text_idx) else 0L
    } else {
      0L
    }
    max(serial_score, text_score)
  }, integer(1))
  date_col <- which.max(date_col_scores)
  if (!length(date_col) || date_col_scores[[date_col]] < 3L) {
    req_abort(
      "req_workbook_schema_error",
      "Monthly sheet has no recognised vertical Excel-date sequence.",
      source_sheet = sheet, table_id = table_id,
      remediation = "Inspect the date-column structural fingerprint."
    )
  }
  date_text <- req_clean_text(mat[, date_col])
  date_serial <- suppressWarnings(as.numeric(date_text))
  date_rows <- which(
    (!is.na(date_serial) & date_serial >= 20000 & date_serial <= 60000) |
      grepl(month_pattern, date_text, ignore.case = TRUE)
  )
  first_data <- min(date_rows)
  predata_rows <- seq_len(first_data - 1L)
  unit_scores <- vapply(predata_rows, function(i) {
    sum(vapply(req_clean_text(mat[i, ]), req_unit_like, logical(1)), na.rm = TRUE)
  }, integer(1))
  unit_row <- predata_rows[[which.max(unit_scores)]]
  if (unit_scores[[which.max(unit_scores)]] < 2L) {
    req_abort(
      "req_workbook_schema_error",
      "Monthly sheet unit row was not recognised.",
      source_sheet = sheet, table_id = table_id,
      remediation = "Inspect the published monthly label/unit header block."
    )
  }
  label_candidates <- predata_rows[predata_rows < unit_row &
    apply(mat[predata_rows, , drop = FALSE], 1, function(z) {
      sum(!is.na(z) & nzchar(z)) >= 3L
    })]
  series_header <- max(label_candidates)
  series_cols <- which(!is.na(mat[series_header, ]) &
    nzchar(req_clean_text(mat[series_header, ])) &
    seq_len(ncol(mat)) > date_col)
  if (!length(series_cols)) {
    req_abort(
      "req_workbook_schema_error",
      "Monthly sheet series headers were not recognised.",
      source_sheet = sheet, table_id = table_id,
      remediation = "Inspect label and unit header rows."
    )
  }
  claimed <- matrix(FALSE, nrow = nrow(mat), ncol = ncol(mat))
  claimed[seq_len(first_data - 1L), ] <- TRUE
  claimed[, seq_len(date_col)] <- TRUE
  claimed[date_rows, c(date_col, series_cols)] <- TRUE
  req_assert_numeric_cells_claimed(
    mat, claimed, date_rows, sheet, table_id, release_meta$release_id
  )
  rows <- list()
  k <- 0L
  series_cache <- new.env(hash = TRUE, parent = emptyenv())
  labels <- req_clean_text(mat[series_header, series_cols])
  units <- req_normalise_unit(mat[unit_row, series_cols])
  price_bases <- vapply(seq_along(series_cols), function(j) {
    req_price_basis(labels[[j]], title, units[[j]])
  }, character(1))
  currencies <- req_currency(units)
  for (i in date_rows) {
    p <- req_period(mat[i, date_col], frequency_hint = "monthly")
    raw_row <- req_clean_text(mat[i, series_cols])
    present <- !is.na(raw_row) & nzchar(raw_row)
    if (!any(present)) next
    parsed_values <- req_parse_numeric_tokens(
      raw_row[present], sheet, table_id, i, series_cols[present]
    )
    for (pos in seq_along(series_cols)[present]) {
      raw <- raw_row[[pos]]
      parsed_pos <- match(pos, which(present))
      reason <- parsed_values$missing_reason[[parsed_pos]]
      value <- parsed_values$value[[parsed_pos]]
      label <- labels[[pos]]
      unit <- units[[pos]]
      row_footnotes <- unique(c(
        req_row_footnotes(label, note_metadata$codes),
        req_row_footnotes(unit, note_metadata$codes)
      ))
      semantic_label <- req_strip_footnote_suffix(
        label, note_metadata$codes
      )
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
        record_role = "canonical",
        geography_type = "country",
        geography = "Australia",
        commodity = req_slug(semantic_label),
        concept = if (grepl("unit_value", table_id)) "export_unit_value" else "benchmark_price",
        period = p$period,
        period_start = p$period_start,
        period_end = p$period_end,
        period_basis = p$period_basis,
        period_status = "historical",
        status_source = "title",
        price_basis = price_bases[[pos]],
        currency = currencies[[pos]],
        unit = unit,
        value = value,
        raw_value = raw,
        missing_reason = reason,
        footnote_codes = I(list(row_footnotes)),
        source_note = note_metadata$note,
        series_id = "",
        observation_key = "",
        retrieved_at = asset_meta$retrieved_at,
        sha256 = asset_meta$sha256,
        parser_version = .req_parser_version,
        section = "Australia",
        frequency = "monthly"
      )
      row$series_id <- req_semantic_id_cached(row, series_cache)
      row$observation_key <- paste(row$series_id, row$period, sep = "::")
      k <- k + 1L
      rows[[k]] <- row
    }
  }
  data <- req_observation_frame(rows)
  rm(rows, mat)
  list(
    data = data,
    diagnostics = data.frame(
      source_sheet = sheet, table_id = table_id, row = NA_integer_,
      period_cells = nrow(data), parsed_cells = nrow(data),
      control_cells = 0L, stringsAsFactors = FALSE
    ),
    title = title
  )
}

req_structural_period_control <- function(
    values, label, unit, first_data_row = FALSE) {
  values <- req_clean_text(values)
  nonempty <- !is.na(values) & nzchar(values)
  label <- req_clean_text(label)
  unit <- req_clean_text(unit)
  blank_context <- (is.na(label) || !nzchar(label)) &&
    (is.na(unit) || !nzchar(unit))
  helper_suffix <- blank_context && isTRUE(first_data_row) && any(nonempty) &&
    all(!nonempty | grepl(
      "^[-\u2013\u2014][0-9]{2}\\s*[a-z]?$",
      values, ignore.case = TRUE
    ))
  page_sentinel <- blank_context && any(nonempty) &&
    all(!nonempty | grepl(
      "^[-\u2013\u2014]1[-\u2013\u2014]$",
      values
    ))
  helper_suffix || page_sentinel
}

req_parse_data_sheet <- function(path, mapping_row, release_meta, asset_meta) {
  sheet <- mapping_row$source_sheet[[1]]
  table_id <- mapping_row$table_id[[1]]
  family <- mapping_row$parser_family[[1]]
  if (family == "history_monthly") {
    return(req_parse_monthly_sheet(path, mapping_row, release_meta, asset_meta))
  }
  mat <- req_read_matrix(path, sheet)
  title <- req_table_title(mat, sheet)
  note_metadata <- req_sheet_note_metadata(mat)
  control_profile <- req_verified_control_row_profile(
    path, release_meta, mapping_row
  )
  blocks <- req_header_blocks(mat, family)
  header_rows <- sort(unique(vapply(blocks, `[[`, integer(1), "row")))
  claimed <- matrix(FALSE, nrow = nrow(mat), ncol = ncol(mat))
  marked_headers <- vapply(
    blocks, function(block) isTRUE(block$has_unit_marker), logical(1)
  )
  first_header <- if (any(marked_headers)) {
    min(vapply(blocks[marked_headers], `[[`, integer(1), "row"))
  } else {
    min(header_rows)
  }
  if (first_header > 1L) claimed[seq_len(first_header - 1L), ] <- TRUE
  left_boundary <- min(vapply(
    blocks, function(block) min(block$period_cols), integer(1)
  ))
  if (left_boundary > 1L) claimed[, seq_len(left_boundary - 1L)] <- TRUE
  for (block in blocks) {
    next_headers <- header_rows[header_rows > block$row]
    block_end <- if (length(next_headers)) {
      min(next_headers) - 1L
    } else {
      nrow(mat)
    }
    claimed[block$row, block$period_cols] <- TRUE
    if (block_end > block$row) {
      claimed[
        seq.int(block$row + 1L, block_end),
        block$period_cols
      ] <- TRUE
    }
  }
  derived_change_markers <- which(apply(mat, 2, function(z) {
    any(grepl(
      "^(CAGR|% change|annual percentage change)(\\s|$)",
      req_clean_text(z),
      ignore.case = TRUE
    ))
  }))
  derived_change_columns <- if (length(derived_change_markers)) {
    seq.int(min(derived_change_markers), ncol(mat))
  } else {
    integer()
  }
  if (length(derived_change_columns)) {
    # Legacy forecast files place a right-hand derived-change grid under one
    # spanning marker. Only its first column carries the marker; the remaining
    # columns carry period labels. The entire contiguous right-hand grid is a
    # published calculation control, not source observations.
    claimed[, derived_change_columns] <- TRUE
  }
  req_assert_numeric_cells_claimed(
    mat, claimed, seq.int(first_header + 1L, nrow(mat)), sheet, table_id,
    release_meta$release_id,
    published_max_col = max(unlist(lapply(blocks, `[[`, "period_cols")))
  )
  observations <- list()
  diagnostics <- list()
  k <- 0L
  series_cache <- new.env(hash = TRUE, parent = emptyenv())
  selected_export_starts <- if (
    identical(table_id, "forecast_selected_exports")
  ) {
    sort(unique(vapply(
      blocks,
      function(block) min(block$period_cols),
      integer(1)
    )))
  } else {
    integer()
  }

  for (b in blocks) {
    selected_export_value_grid <- FALSE
    if (length(selected_export_starts) >= 2L) {
      selected_export_value_grid <-
        min(b$period_cols) != selected_export_starts[[1L]]
      b$measure <- if (selected_export_value_grid) "Value" else "Volume"
    }
    next_headers <- header_rows[header_rows > b$row]
    end_row <- if (length(next_headers)) min(next_headers) - 1L else nrow(mat)
    # Workbooks also carry hidden calendar/fiscal-year helper rows immediately
    # above the published table header. Adjacent recognised header rows leave
    # no data interval; seq.int(start, end) would otherwise descend and parse
    # the neighbouring header itself as data.
    if (end_row <= b$row) next
    # Some editions omit the literal "Unit" marker from a later grid while
    # retaining the usual label/unit pair immediately left of the periods.
    # Prefer that left label column when its data interval contains more
    # semantic text than the inferred unit column.
    interval <- seq.int(b$row + 1L, end_row)
    label_score <- function(column) {
      z <- req_clean_text(mat[interval, column])
      sum(
        !is.na(z) & nzchar(z) &
          is.na(suppressWarnings(as.numeric(z))) &
          !req_is_period_label(z) &
          !vapply(z, req_unit_like, logical(1)) &
          !grepl("notes?:|sources?:|tableend|pagend|back to", z,
            ignore.case = TRUE
        )
      )
    }
    label_candidates <- seq_len(max(1L, min(b$period_cols) - 1L))
    label_scores <- vapply(label_candidates, label_score, integer(1))
    best_label_col <- label_candidates[[which.max(label_scores)]]
    if (best_label_col != b$label_col &&
        label_scores[[best_label_col]] > label_score(b$label_col)) {
      b$label_col <- best_label_col
    }
    periods <- req_period(mat[b$row, b$period_cols],
      frequency_hint = b$frequency_hint
    )
    current_commodity <- NULL
    market_parent <- NULL
    exploration_sector <- NULL
    exploration_group <- NULL
    active_measure <- NULL
    last_subject_label <- NULL
    last_period_data_row <- b$row
    last_unit <- req_clean_text(mat[b$row, b$unit_col])
    if (is.na(last_unit)) last_unit <- ""
    if (tolower(last_unit) == "unit") last_unit <- ""

    for (i in seq.int(b$row + 1L, end_row)) {
      vals <- req_clean_text(mat[i, b$period_cols])
      nonempty <- !is.na(vals) & nzchar(vals)
      label <- req_clean_text(mat[i, b$label_col])
      unit <- req_clean_text(mat[i, b$unit_col])
      if (is.na(label)) label <- ""
      if (is.na(unit)) unit <- ""
      if (!is.null(control_profile) && i %in% control_profile$rows) {
        blank_context <- !nzchar(label) && !nzchar(unit)
        if (isTRUE(control_profile$requires_blank_context) &&
            !blank_context) {
          req_abort(
            "req_workbook_schema_error",
            "A release-specific calculation-control row no longer matches its audited structure.",
            source_sheet = sheet,
            table_id = table_id,
            remediation = paste0("Inspect exact workbook row ", i, ".")
          )
        }
        if (any(nonempty)) {
          diagnostics[[length(diagnostics) + 1L]] <- data.frame(
            source_sheet = sheet, table_id = table_id, row = i,
            period_cells = sum(nonempty), parsed_cells = 0L,
            control_cells = sum(nonempty), stringsAsFactors = FALSE
          )
        }
        next
      }
      structural_control <- req_structural_period_control(
        vals, label, unit, first_data_row = i == b$row + 1L
      )
      if (structural_control) {
        diagnostics[[length(diagnostics) + 1L]] <- data.frame(
          source_sheet = sheet, table_id = table_id, row = i,
          period_cells = sum(nonempty), parsed_cells = 0L,
          control_cells = sum(nonempty), stringsAsFactors = FALSE
        )
        next
      }
      control <- nonempty & (
        tolower(vals) %in% c(
          "tablend", "table end", "forecastend", "forecast end",
          "pagend", "page end", "annual percentage change"
        ) |
          grepl(
            paste0(
              "^(18|19|20)[0-9]{2}([\u2013-][0-9]{2})?\\s*[a-z]?$|",
              "^(Mar|Jun|Sep|Dec)[\u2013 -]?[0-9]{2,4}\\s*[a-z]?$|",
              "^[12][0-9]{3}[- ]?Q[1-4]\\s*[a-z]?$"
            ),
            vals, ignore.case = TRUE
          ) |
          vapply(vals, req_unit_like, logical(1))
      )
      if (any(nonempty) && all(!nonempty | control)) {
        diagnostics[[length(diagnostics) + 1L]] <- data.frame(
          source_sheet = sheet, table_id = table_id, row = i,
          period_cells = sum(nonempty), parsed_cells = 0L,
          control_cells = sum(control), stringsAsFactors = FALSE
        )
        next
      }
      if (any(nonempty) && !nzchar(label) && !nzchar(unit)) {
        req_abort(
          "req_sheet_parse_error",
          "A numeric period-grid row has neither a source label nor a unit.",
          source_sheet = sheet,
          table_id = table_id,
          remediation = paste0(
            "Inspect workbook row ", i,
            "; add an exact audited control profile when it is a helper row."
          )
        )
      }
      if ((
        !nzchar(label) ||
          req_unit_like(label) ||
          !is.na(suppressWarnings(as.numeric(label))) ||
          req_is_period_label(label)
      ) && b$unit_col > 1L) {
        left <- req_clean_text(mat[i, seq_len(b$unit_col - 1L)])
        usable <- !is.na(left) & nzchar(left) &
          is.na(suppressWarnings(as.numeric(left))) &
          !vapply(left, req_unit_like, logical(1))
        if (any(usable)) label <- utils::tail(left[usable], 1L)
        if (!any(usable) && !nzchar(label)) {
          fallback <- !is.na(left) & nzchar(left) &
            is.na(suppressWarnings(as.numeric(left))) &
            !req_is_period_label(left) &
            !grepl("notes?:|sources?:|tableend|pagend|back to",
              left, ignore.case = TRUE
            )
          if (any(fallback)) label <- utils::tail(left[fallback], 1L)
        }
      }
      if (!nzchar(label) && i > b$row + 1L) {
        prior <- req_clean_text(mat[seq.int(b$row + 1L, i - 1L), b$label_col])
        prior <- prior[!is.na(prior) & nzchar(prior)]
        if (length(prior)) label <- utils::tail(prior, 1L)
      }
      if (!any(nonempty)) {
        if (family == "history_markets" && nzchar(label) &&
            !grepl("notes?:|source|tableend|back to", label,
              ignore.case = TRUE
            )) {
          market_parent <- req_slug(label)
        }
        if (family %in% c("history_annual", "history_quarterly") &&
            nzchar(label) && !req_known_geography(label) &&
            !grepl("notes?:|source|tableend|back to", label,
              ignore.case = TRUE
            )) {
          current_commodity <- req_slug(label)
        }
        if (table_id == "history_annual_exploration_expenditure" &&
            nzchar(label)) {
          heading <- req_slug(label)
          if (heading %in% c("energy", "metals_and_other_minerals")) {
            exploration_sector <- heading
            exploration_group <- NULL
          } else {
            exploration_group <- heading
          }
        }
        if (nzchar(unit) && req_unit_like(unit)) last_unit <- unit
        next
      }
      if (!nzchar(label) || grepl("notes?:|sources?:|tableend|back to",
        label, ignore.case = TRUE
      )) {
        req_abort(
          "req_sheet_parse_error",
          "A non-empty period-grid value has no semantic row label.",
          source_sheet = sheet, table_id = table_id,
          remediation = paste0("Inspect workbook row ", i, ".")
        )
      }
      row_footnotes <- unique(c(
        req_row_footnotes(label, note_metadata$codes),
        req_row_footnotes(unit, note_metadata$codes)
      ))
      semantic_label <- req_strip_footnote_suffix(
        label, note_metadata$codes
      )
      if (identical(req_slug(semantic_label), "total") && i > b$row + 1L) {
        prior_label <- req_strip_footnote_suffix(
          req_clean_text(mat[i - 1L, b$label_col]),
          note_metadata$codes
        )
        if (identical(req_slug(prior_label), "total")) {
          semantic_label <- "Overall total"
        }
      }
      if (family == "history_markets" &&
          (is.null(current_commodity) || i > last_period_data_row + 1L ||
            grepl(
              "ores? and concentrates?|refined|bullion|spodumene|hydroxide",
              semantic_label, ignore.case = TRUE
            ))) {
        label_commodity <- req_slug(semantic_label)
        current_commodity <- if (!is.null(market_parent) &&
            nzchar(market_parent) && market_parent != label_commodity) {
          paste(market_parent, label_commodity, sep = "_")
        } else {
          label_commodity
        }
      }
      if (table_id == "history_annual_exploration_expenditure") {
        label_key <- req_slug(semantic_label)
        named_commodity <- label_key %in% c(
          "coal", "uranium", "gold", "iron_ore",
          "base_metals_silver_and_cobalt_a", "mineral_sands", "diamonds",
          "other"
        )
        if (named_commodity) {
          current_commodity <- label_key
          exploration_group <- NULL
        } else if (label_key == "total") {
          current_commodity <- if (!is.null(exploration_group)) {
            exploration_group
          } else {
            exploration_sector
          }
          exploration_group <- NULL
        }
      }
      if (!nzchar(unit) || (!isTRUE(b$has_unit_marker) &&
          !req_unit_like(unit))) {
        unit <- last_unit
      }
      if (!nzchar(unit)) unit <- req_clean_text(mat[b$row, b$unit_col])
      if (is.na(unit)) unit <- ""
      if (selected_export_value_grid) unit <- "A$m"
      source_unit <- req_normalise_unit(unit)
      is_growth <- grepl(
        "annual percentage change", b$measure, ignore.case = TRUE
      )
      if (is_growth) {
        unit <- "%"
      }
      if (!nzchar(unit) || tolower(unit) == "unit") unit <- "not_applicable"
      last_unit <- unit
      parents <- req_parent_labels(
        mat, i, b$label_col, b$row, b$period_cols
      )
      continuation <- grepl("^[\u2013\u2014-]", semantic_label)
      measure_label <- semantic_label
      is_measure_label <- grepl(
        "^(production|consumption|closing stocks?|stocks?|prices?.*|exports?|export (volume|value)|imports?)$",
        measure_label, ignore.case = TRUE
      )
      if (is_measure_label && !continuation) {
        active_measure <- measure_label
      } else if (!is.null(active_measure) && !continuation) {
        parents <- c(parents, active_measure)
      }
      if (continuation && !is.null(last_subject_label) &&
          nzchar(last_subject_label)) {
        parents <- c(parents, last_subject_label)
      }
      if (nzchar(b$measure) &&
          !grepl("back to|logo", b$measure, ignore.case = TRUE)) {
        parents <- c(b$measure, parents)
      }
      if (table_id == "forecast_commodity_sector") {
        if (!continuation) current_commodity <- req_slug(label)
      }
      dims <- req_infer_dimensions(
        table_id, family, title, semantic_label, parents, current_commodity
      )
      if (!continuation) last_subject_label <- semantic_label
      last_period_data_row <- i
      unit1 <- req_normalise_unit(unit)
      price_basis <- req_price_basis(
        paste(c(parents, label), collapse = " \u2014 "), title, unit1
      )
      currency <- if (is_growth) {
        req_currency(source_unit)
      } else {
        req_currency(unit1)
      }
      parsed_values <- req_parse_numeric_tokens(
        vals[nonempty], sheet, table_id, i, b$period_cols[nonempty]
      )

      for (j in which(nonempty)) {
        raw <- vals[[j]]
        parsed_pos <- match(j, which(nonempty))
        reason <- parsed_values$missing_reason[[parsed_pos]]
        value <- parsed_values$value[[parsed_pos]]
        status <- periods$period_status[[j]]
        status_source <- periods$status_source[[j]]
        if (asset_meta$logical_dataset == "historical" &&
            status == "published-unclassified") {
          status <- "historical"
          status_source <- "title"
        }
        landing_page_note <- NA_character_
        if (identical(release_meta$release_id, "req-2026-06") &&
            identical(table_id, "forecast_commodity_sector") &&
            identical(periods$period[[j]], "2025-26") &&
            identical(dims$commodity, "resources_and_energy") &&
            identical(status, "published-unclassified")) {
          status <- "estimate"
          status_source <- "landing-page"
          landing_page_note <- paste0(
            "Official June 2026 overview: resource and energy exports are ",
            "estimated at around $405 billion in 2025-26."
          )
        }
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
          record_role = if (is_growth &&
              grepl("^USc/lb$", source_unit, ignore.case = TRUE)) {
            "supporting"
          } else {
            "canonical"
          },
          geography_type = dims$geography_type,
          geography = dims$geography,
          commodity = dims$commodity,
          concept = dims$concept,
          period = periods$period[[j]],
          period_start = periods$period_start[[j]],
          period_end = periods$period_end[[j]],
          period_basis = periods$period_basis[[j]],
          period_status = status,
          status_source = status_source,
          price_basis = price_basis,
          currency = currency,
          unit = unit1,
          value = value,
          raw_value = raw,
          missing_reason = reason,
          footnote_codes = I(list(row_footnotes)),
          source_note = paste(
            stats::na.omit(c(note_metadata$note, landing_page_note)),
            collapse = " | "
          ),
          series_id = "",
          observation_key = "",
          retrieved_at = asset_meta$retrieved_at,
          sha256 = asset_meta$sha256,
          parser_version = .req_parser_version,
          section = dims$section,
          frequency = periods$frequency[[j]]
        )
        row$series_id <- req_semantic_id_cached(row, series_cache)
        row$observation_key <- paste(row$series_id, row$period, sep = "::")
        k <- k + 1L
        observations[[k]] <- row
      }
      diagnostics[[length(diagnostics) + 1L]] <- data.frame(
        source_sheet = sheet, table_id = table_id, row = i,
        period_cells = sum(nonempty), parsed_cells = sum(nonempty),
        control_cells = 0L,
        stringsAsFactors = FALSE
      )
    }
  }
  data <- req_observation_frame(observations)
  rm(observations, mat)
  list(
    data = data,
    diagnostics = if (length(diagnostics)) do.call(rbind, diagnostics) else data.frame(),
    title = title
  )
}

req_parse_workbook <- function(path, source_dataset, release_meta,
                               retrieved_at = Sys.time(), sha256 = NULL,
                               sheets = "all") {
  if (is.null(sha256)) {
    sha256 <- digest::digest(file = path, algo = "sha256")
  }
  workbook_sheets <- readxl::excel_sheets(path)
  early_forecast <- identical(source_dataset, "forecast") &&
    length(workbook_sheets) == 15L &&
    identical(
      workbook_sheets,
      c("Contents", paste("Table", seq_len(14L)))
    )
  if (early_forecast || source_dataset %in% c(
      "statistical", "commodity",
      "historical_statistical", "historical_commodity"
  )) {
    return(req_parse_early_workbook(
      path, source_dataset, release_meta, retrieved_at, sha256, sheets
    ))
  }
  mapping <- req_map_workbook(path, source_dataset)
  selected <- mapping$classification == "data_table"
  if (!identical(sheets, "all")) {
    requested <- as.character(sheets)
    selected <- selected & (
      mapping$table_id %in% requested |
        mapping$source_sheet %in% requested |
        req_slug(mapping$source_sheet) %in% req_slug(requested)
    )
    if (!any(selected)) {
      req_abort(
        "req_sheet_parse_error",
        "No requested semantic sheet IDs or source aliases were found.",
        asset_type = source_dataset,
        remediation = "Use req_source_catalog() to inspect valid names."
      )
    }
  }
  asset_meta <- list(
    source_dataset = source_dataset,
    logical_dataset = if (source_dataset %in%
        c("historical", "historical_statistical", "historical_commodity")) {
      "historical"
    } else {
      "forecast"
    },
    retrieved_at = as.POSIXct(retrieved_at, tz = "UTC"),
    sha256 = sha256
  )
  parse_one <- function(i) {
    tryCatch(
      req_parse_data_sheet(path, mapping[i, , drop = FALSE], release_meta, asset_meta),
      error = function(e) {
        if (inherits(e, "req_error")) stop(e)
        req_abort(
          "req_sheet_parse_error",
          paste0("Failed to parse sheet '", mapping$source_sheet[[i]], "': ", conditionMessage(e)),
          source_sheet = mapping$source_sheet[[i]],
          table_id = mapping$table_id[[i]],
          remediation = "Inspect the structural fingerprint and parser diagnostics."
        )
      }
    )
  }
  indexes <- which(selected)
  workers <- getOption(
    "readreq.workers",
    1L
  )
  workers <- max(1L, min(as.integer(workers), length(indexes)))
  parsed <- if (workers > 1L) {
    parallel::mclapply(indexes, parse_one, mc.cores = workers)
  } else {
    lapply(indexes, parse_one)
  }
  diagnostics <- data.table::rbindlist(
    lapply(parsed, `[[`, "diagnostics"), use.names = TRUE, fill = TRUE
  )
  data.table::setDF(diagnostics)
  data <- data.table::rbindlist(
    lapply(parsed, `[[`, "data"), use.names = TRUE, fill = TRUE
  )
  data.table::setDF(data)
  rm(parsed)
  invisible(gc(FALSE))
  attr(data, "sheet_mapping") <- mapping
  attr(data, "parse_diagnostics") <- diagnostics
  data
}
