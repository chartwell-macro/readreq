req_source_catalog_internal <- function() {
  path <- system.file("catalogue", "source-catalog.csv", package = "readreq")
  if (!nzchar(path)) path <- file.path("inst", "catalogue", "source-catalog.csv")
  utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

req_normalise_sheet_alias <- function(x) {
  z <- req_slug(x)
  z <- sub("^aus_", "australia_", z)
  z <- sub("^quarterly_export_values$", "australia_quarterly_export_values", z)
  z <- sub("met_coal", "metallurgical_coal", z)
  z <- sub("^242$", "24_2", z)
  z <- sub("^table_([0-9]+)([abc])$", "table_\\1_\\2", z)
  z
}

req_legacy_forecast_catalog <- function() {
  data.frame(
    source_label = c(
      "Macro assumptions - world", "Macro assumptions - Australia",
      "World steel", "World iron ore trade", "World met coal trade"
    ),
    table_id = c(
      "forecast_world_macro", "forecast_australia_macro",
      "forecast_steel", "forecast_iron_ore",
      "forecast_metallurgical_coal"
    ),
    classification = "data_table",
    parser_family = c(
      "forecast_overview", "forecast_overview",
      "forecast_commodity", "forecast_commodity", "forecast_commodity"
    ),
    stringsAsFactors = FALSE
  )
}

req_early_statistical_catalog <- function(sheets) {
  if (length(sheets) == 49L) {
    labels <- sheets
    keys <- req_normalise_sheet_alias(labels)
    ids <- c(
      contents = "history_contents",
      table_1 = "history_annual_export_value",
      table_2 = "history_annual_export_unit_value",
      table_4 = "history_annual_gva",
      table_5 = "history_annual_production",
      table_6 = "history_annual_employment",
      table_7 = "history_annual_business_income",
      table_8 = "history_quarterly_business_lending",
      table_9 = "history_annual_capital_expenditure",
      table_10 = "history_annual_exploration_expenditure",
      table_11 = "history_annual_world_prices",
      table_12_a = "history_annual_world_supply_part_1",
      table_12_b = "history_annual_world_supply_part_2",
      table_13_a = "history_annual_commodity_production_part_1",
      table_13_b = "history_annual_commodity_production_part_2",
      table_14 = "history_annual_export_volume",
      table_15_a = "history_annual_export_value_part_1",
      table_15_b = "history_annual_export_value_part_2",
      table_16 = "history_annual_imports",
      table_17 = "history_quarterly_production",
      table_18 = "history_quarterly_exports_volume",
      table_19 = "history_quarterly_exports_value",
      table_20 = "history_quarterly_export_unit_value",
      table_21 = "history_quarterly_imports",
      table_22 = "history_quarterly_exploration",
      table_23 = "history_monthly_benchmark_prices",
      table_24 = "history_commodity_aluminium",
      table_25_a = "history_commodity_coal_part_1",
      table_25_b = "history_commodity_coal_part_2",
      table_26 = "history_commodity_copper",
      table_27 = "history_commodity_gemstones",
      table_28 = "history_commodity_gold",
      table_29 = "history_commodity_iron",
      table_30 = "history_commodity_lead",
      table_31 = "history_commodity_manganese",
      table_32 = "history_commodity_nickel",
      table_33_a = "history_commodity_petroleum_part_1",
      table_33_b = "history_commodity_petroleum_part_2",
      table_33_c = "history_commodity_petroleum_part_3",
      table_35_a = "history_commodity_petroleum_sales_part_1",
      table_35_b = "history_commodity_petroleum_sales_part_2",
      table_36 = "history_commodity_phosphate",
      table_37 = "history_commodity_salt",
      table_38 = "history_commodity_silver",
      table_39 = "history_commodity_tin",
      table_40 = "history_commodity_titanium",
      table_41 = "history_commodity_uranium",
      table_42 = "history_commodity_zircon",
      table_43 = "history_commodity_zinc"
    )
    table_ids <- unname(ids[keys])
    if (anyNA(table_ids)) {
      req_abort(
        "req_workbook_schema_error",
        "A full 2012 statistical-workbook sheet is outside its audited map.",
        asset_type = "statistical",
        remediation = "Inspect the exact sheet names."
      )
    }
    family <- ifelse(
      keys == "contents", "metadata",
      ifelse(
        grepl("^table_(17|18|19|20|21|22)$", keys),
        "history_quarterly",
        ifelse(
          keys == "table_23", "history_monthly",
          ifelse(
            grepl("^table_35_", keys), "history_cross_section",
            ifelse(
            grepl("^table_(2[4-9]|3[0-9]|4[0-3])", keys),
            "history_commodity", "history_annual"
            )
          )
        )
      )
    )
    return(data.frame(
      source_label = labels,
      table_id = table_ids,
      classification = ifelse(keys == "contents", "metadata", "data_table"),
      parser_family = family,
      stringsAsFactors = FALSE
    ))
  }
  if (length(sheets) != 19L) {
    req_abort(
      "req_workbook_schema_error",
      sprintf(
        "Early statistical workbook has %d sheets; expected 19 or 49.",
        length(sheets)
      ),
      asset_type = "statistical",
      remediation = "Audit the workbook before adding a release profile."
    )
  }
  labels <- c(
    "Contents", "Table 1", "Table 2", "Table 4", "Table 5",
    "Table 6", "Table 7", "Table 8", "Table 9", "Table 10",
    "Table 11", "Table 12 a", "Table 12 b", "Table 13 a",
    "Table 13 b", "Table 14", "Table 15 a", "Table 15 b",
    "Table 16"
  )
  table_ids <- c(
    "history_contents",
    "history_annual_export_value",
    "history_annual_export_unit_value",
    "history_annual_gva",
    "history_annual_production",
    "history_annual_employment",
    "history_quarterly_business_income",
    "history_annual_business_lending",
    "history_quarterly_capital_expenditure",
    "history_annual_exploration_expenditure",
    "history_quarterly_production",
    "history_quarterly_exports_volume_part_1",
    "history_quarterly_exports_volume_part_2",
    "history_quarterly_exports_value_part_1",
    "history_quarterly_exports_value_part_2",
    "history_quarterly_export_unit_value",
    "history_quarterly_imports_part_1",
    "history_quarterly_imports_part_2",
    "history_quarterly_exploration"
  )
  out <- data.frame(
    source_label = labels,
    table_id = table_ids,
    classification = ifelse(labels == "Contents", "metadata", "data_table"),
    parser_family = c(
      "metadata",
      "history_annual", "history_annual", "history_annual",
      "history_annual", "history_annual", "history_quarterly",
      "history_annual", "history_quarterly", "history_annual",
      rep("history_quarterly", 9L)
    ),
    stringsAsFactors = FALSE
  )
}

req_early_commodity_catalog <- function(sheets) {
  table_count <- length(sheets) - as.integer("Contents" %in% sheets)
  if (!table_count %in% c(13L, 14L, 15L)) {
    req_abort(
      "req_workbook_schema_error",
      sprintf(
        "Early commodity workbook has %d tables; expected 13, 14, or 15.",
        table_count
      ),
      asset_type = "commodity",
      remediation = "Audit the workbook before adding a new explicit profile."
    )
  }
  if (table_count == 13L) {
    table_ids <- c(
      "forecast_world_macro", "forecast_australia_macro",
      "forecast_commodity_sector", "forecast_aluminium",
      "forecast_thermal_coal", "forecast_copper", "forecast_gas",
      "forecast_gold", "forecast_steel_making", "forecast_nickel",
      "forecast_oil", "forecast_uranium", "forecast_zinc"
    )
    families <- c(
      rep("forecast_overview", 3L),
      rep("forecast_commodity", 10L)
    )
  } else if (table_count == 15L) {
    table_ids <- c(
      "forecast_world_macro", "forecast_australia_macro",
      "forecast_commodity_sector", "forecast_selected_exports",
      "forecast_annual_export_unit_values", "forecast_aluminium",
      "forecast_thermal_coal", "forecast_copper", "forecast_gas",
      "forecast_gold", "forecast_steel_making", "forecast_nickel",
      "forecast_oil", "forecast_uranium", "forecast_zinc"
    )
    families <- c(
      rep("forecast_overview", 5L),
      rep("forecast_commodity", 10L)
    )
  } else {
    table_ids <- c(
      "forecast_world_macro", "forecast_australia_macro",
      "forecast_commodity_sector", "forecast_selected_exports",
      "forecast_aluminium", "forecast_thermal_coal", "forecast_copper",
      "forecast_gas", "forecast_gold", "forecast_steel_making",
      "forecast_nickel", "forecast_oil", "forecast_uranium",
      "forecast_zinc"
    )
    families <- c(
      rep("forecast_overview", 4L),
      rep("forecast_commodity", 10L)
    )
  }
  data.frame(
    source_label = c("Contents", paste("Table", seq_len(table_count))),
    table_id = c("forecast_contents", table_ids),
    classification = c("metadata", rep("data_table", table_count)),
    parser_family = c("metadata", families),
    stringsAsFactors = FALSE
  )
}

req_legacy_history_catalog <- function(sheets) {
  if ("5(1)" %in% sheets && !"Data directory" %in% sheets) {
    labels <- c(
      "Contents", "1", "2(1)", "2(2)", "3", "4", "5(1)", "5(2)",
      "6", "7(1)", "7(2)", as.character(8:23), "24(1)", "242)",
      as.character(25:30), "31(1)", "31(2)", "31(3)",
      as.character(32:36)
    )
    table_ids <- c(
      "history_contents",
      "history_annual_export_volume",
      "history_annual_export_value_part_1",
      "history_annual_export_value_part_2",
      "history_annual_export_unit_value",
      "history_annual_imports",
      "history_annual_production",
      "history_annual_production_part_2",
      "history_annual_world_prices_production_consumption",
      "history_annual_world_stocks_trade_part_1",
      "history_annual_world_stocks_trade_part_2",
      "history_annual_gva", "history_quarterly_gva",
      "history_annual_employment", "history_quarterly_business_income",
      "history_annual_business_lending",
      "history_quarterly_capital_expenditure",
      "history_annual_exploration_expenditure",
      "history_quarterly_production", "history_quarterly_exports_volume",
      "history_quarterly_exports_value",
      "history_quarterly_export_unit_value", "history_quarterly_imports",
      "history_quarterly_exploration", "history_monthly_export_unit_values",
      "history_monthly_benchmark_prices", "history_commodity_aluminium",
      "history_commodity_coal_part_1", "history_commodity_coal_part_2",
      "history_commodity_copper", "history_commodity_gemstones",
      "history_commodity_gold", "history_commodity_iron_ore_steel",
      "history_commodity_lead", "history_commodity_nickel",
      "history_commodity_petroleum_part_1",
      "history_commodity_petroleum_part_2",
      "history_commodity_petroleum_part_3",
      "history_commodity_phosphate", "history_commodity_silver",
      "history_commodity_tin", "history_commodity_uranium",
      "history_commodity_zinc"
    )
    families <- c(
      "metadata",
      rep("history_annual", 11L),
      "history_quarterly", "history_annual", "history_quarterly",
      "history_annual", "history_quarterly", "history_annual",
      rep("history_quarterly", 6L),
      rep("history_monthly", 2L),
      rep("history_commodity", 17L)
    )
    return(data.frame(
      source_label = labels,
      table_id = table_ids,
      classification = ifelse(
        table_ids == "history_contents",
        "metadata",
        "data_table"
      ),
      parser_family = families,
      stringsAsFactors = FALSE
    ))
  }
  if ("31" %in% sheets && "Data directory" %in% sheets &&
      !"41" %in% sheets) {
    labels <- c(
      "Contents", "Data directory", "About",
      "1", "2(1)", "2(2)", as.character(3:6), "7(1)", "7(2)",
      as.character(8:23), "24(1)", "24(2)", as.character(25:40)
    )
    table_ids <- c(
      "history_contents", "history_data_directory", "history_about",
      "history_annual_export_volume",
      "history_annual_export_value_part_1",
      "history_annual_export_value_part_2",
      "history_annual_export_unit_value", "history_annual_imports",
      "history_annual_production",
      "history_annual_world_prices_production_consumption",
      "history_annual_world_stocks_trade_part_1",
      "history_annual_world_stocks_trade_part_2",
      "history_annual_gva", "history_quarterly_gva",
      "history_annual_employment", "history_quarterly_business_income",
      "history_annual_business_lending",
      "history_quarterly_capital_expenditure",
      "history_annual_exploration_expenditure",
      "history_quarterly_production", "history_quarterly_exports_volume",
      "history_quarterly_exports_value",
      "history_quarterly_export_unit_value", "history_quarterly_imports",
      "history_quarterly_exploration", "history_monthly_export_unit_values",
      "history_monthly_benchmark_prices", "history_commodity_aluminium",
      "history_commodity_coal_part_1", "history_commodity_coal_part_2",
      "history_commodity_copper", "history_commodity_gemstones",
      "history_commodity_gold", "history_commodity_iron_ore_steel",
      "history_commodity_lead", "history_commodity_nickel",
      "history_commodity_petroleum",
      "history_commodity_phosphate", "history_commodity_silver",
      "history_commodity_tin", "history_commodity_uranium",
      "history_commodity_zinc",
      "history_export_markets_value_financial_year",
      "history_export_markets_volume_financial_year",
      "history_export_markets_value_calendar_year",
      "history_export_markets_volume_calendar_year"
    )
    families <- ifelse(
      table_ids %in% c(
        "history_contents", "history_data_directory", "history_about"
      ),
      "metadata",
      ifelse(
        grepl("^history_monthly_", table_ids), "history_monthly",
        ifelse(
          grepl("^history_quarterly_", table_ids), "history_quarterly",
          ifelse(
            grepl("^history_export_markets_", table_ids), "history_markets",
            ifelse(
              grepl("^history_commodity_", table_ids),
              "history_commodity", "history_annual"
            )
          )
        )
      )
    )
    out <- data.frame(
      source_label = labels,
      table_id = table_ids,
      classification = ifelse(
        families == "metadata", "metadata", "data_table"
      ),
      parser_family = families,
      stringsAsFactors = FALSE
    )
    if ("Controls" %in% sheets) {
      out <- rbind(
        out,
        data.frame(
          source_label = "Controls",
          table_id = "history_controls",
          classification = "metadata",
          parser_family = "metadata",
          stringsAsFactors = FALSE
        )
      )
    }
    return(out)
  }
  if (!"31(1)" %in% sheets) return(NULL)
  labels <- c(
    "Contents", "Data directory", "About",
    "1", "2(1)", "2(2)", as.character(3:6), "7(1)", "7(2)",
    as.character(8:23), "24(1)", "24(2)", as.character(25:30),
    "31(1)", "31(2)", "31(3)",
    as.character(32:40)
  )
  table_ids <- c(
    "history_contents", "history_data_directory", "history_about",
    "history_annual_export_volume",
    "history_annual_export_value_part_1",
    "history_annual_export_value_part_2",
    "history_annual_export_unit_value", "history_annual_imports",
    "history_annual_production",
    "history_annual_world_prices_production_consumption",
    "history_annual_world_stocks_trade_part_1",
    "history_annual_world_stocks_trade_part_2",
    "history_annual_gva", "history_quarterly_gva",
    "history_annual_employment", "history_quarterly_business_income",
    "history_annual_business_lending",
    "history_quarterly_capital_expenditure",
    "history_annual_exploration_expenditure",
    "history_quarterly_production", "history_quarterly_exports_volume",
    "history_quarterly_exports_value",
    "history_quarterly_export_unit_value", "history_quarterly_imports",
    "history_quarterly_exploration", "history_monthly_export_unit_values",
    "history_monthly_benchmark_prices", "history_commodity_aluminium",
    "history_commodity_coal_part_1", "history_commodity_coal_part_2",
    "history_commodity_copper", "history_commodity_gemstones",
    "history_commodity_gold", "history_commodity_iron_ore_steel",
    "history_commodity_lead", "history_commodity_nickel",
    "history_commodity_petroleum_part_1",
    "history_commodity_petroleum_part_2",
    "history_commodity_petroleum_part_3",
    "history_commodity_phosphate", "history_commodity_silver",
    "history_commodity_tin", "history_commodity_uranium",
    "history_commodity_zinc",
    "history_export_markets_value_financial_year",
    "history_export_markets_volume_financial_year",
    "history_export_markets_value_calendar_year",
    "history_export_markets_volume_calendar_year"
  )
  families <- c(
    rep("metadata", 3L),
    rep("history_annual", 10L),
    "history_quarterly", "history_annual", "history_quarterly",
    "history_annual", "history_quarterly", "history_annual",
    rep("history_quarterly", 6L),
    rep("history_monthly", 2L),
    rep("history_commodity", 17L),
    rep("history_markets", 4L)
  )
  out <- data.frame(
    source_label = labels,
    table_id = table_ids,
    classification = ifelse(
      table_ids %in% c(
        "history_contents", "history_data_directory", "history_about"
      ),
      "metadata", "data_table"
    ),
    parser_family = families,
    stringsAsFactors = FALSE
  )
  if ("Controls" %in% sheets) {
    out <- rbind(
      out,
      data.frame(
        source_label = "Controls",
        table_id = "history_controls",
        classification = "metadata",
        parser_family = "metadata",
        stringsAsFactors = FALSE
      )
    )
  }
  out
}

req_workbook_catalog <- function(source_dataset, sheets) {
  if (source_dataset %in% c("statistical", "historical_statistical")) {
    return(req_early_statistical_catalog(sheets))
  }
  if (source_dataset %in% c("commodity", "historical_commodity")) {
    return(req_early_commodity_catalog(sheets))
  }
  catalogue <- req_source_catalog_internal()
  catalogue <- catalogue[
    catalogue$source_dataset == source_dataset,
    c("source_label", "table_id", "classification", "parser_family"),
    drop = FALSE
  ]
  if (source_dataset == "forecast") {
    if (length(sheets) == 15L &&
        identical(sheets, c("Contents", paste("Table", seq_len(14L))))) {
      return(req_early_commodity_catalog(sheets))
    }
    legacy <- req_legacy_forecast_catalog()
    missing <- !req_normalise_sheet_alias(legacy$source_label) %in%
      req_normalise_sheet_alias(catalogue$source_label)
    catalogue <- rbind(catalogue, legacy[missing, , drop = FALSE])
  } else {
    legacy <- req_legacy_history_catalog(sheets)
    if (!is.null(legacy)) catalogue <- legacy
  }
  catalogue
}

req_sheet_fingerprint <- function(path, sheet) {
  x <- suppressWarnings(readxl::read_excel(
    path, sheet = sheet, col_names = FALSE,
    n_max = 12, .name_repair = "minimal"
  ))
  cells <- req_clean_text(unlist(x, use.names = FALSE))
  cells <- cells[!is.na(cells) & nzchar(cells)]
  list(
    sheet = sheet,
    normalised_title = req_normalise_sheet_alias(sheet),
    title_tokens = req_slug(paste(utils::head(cells, 30), collapse = " ")),
    header_markers = sort(unique(c(
      if (any(grepl("unit", cells, ignore.case = TRUE))) "unit" else NULL,
      if (sum(req_is_period_label(cells)) >= 2L) "period_grid" else NULL,
      if (any(grepl("resources and energy quarterly", cells, ignore.case = TRUE))) "req_identity" else NULL
    ))),
    sha256 = digest::digest(paste(cells, collapse = "\u001f"),
      algo = "sha256", serialize = FALSE
    )
  )
}

req_map_workbook <- function(path, source_dataset) {
  sheets <- readxl::excel_sheets(path)
  catalogue <- req_workbook_catalog(source_dataset, sheets)
  mapped <- lapply(sheets, function(sheet) {
    alias <- req_normalise_sheet_alias(sheet)
    candidates <- catalogue[
      req_normalise_sheet_alias(catalogue$source_label) == alias |
        req_slug(catalogue$table_id) == alias,
      , drop = FALSE
    ]
    if (nrow(candidates) != 1L) {
      fp <- req_sheet_fingerprint(path, sheet)
      title_matches <- vapply(catalogue$source_label, function(label) {
        grepl(req_slug(label), fp$title_tokens, fixed = TRUE)
      }, logical(1))
      candidates <- catalogue[title_matches, , drop = FALSE]
    }
    if (nrow(candidates) != 1L) {
      req_abort(
        "req_workbook_schema_error",
        paste0("Could not map ", source_dataset, " sheet '", sheet, "' by title and structural fingerprint."),
        asset_type = source_dataset, source_sheet = sheet,
        remediation = "Audit the new sheet fingerprint and update the checked-in source catalogue."
      )
    }
    fp <- req_sheet_fingerprint(path, sheet)
    data.frame(
      source_sheet = sheet,
      table_id = candidates$table_id[[1]],
      classification = candidates$classification[[1]],
      parser_family = candidates$parser_family[[1]],
      fingerprint = fp$sha256,
      markers = paste(fp$header_markers, collapse = ";"),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, mapped)
  accepted_counts <- switch(
    source_dataset,
    forecast = c(15L, 16L, 17L, 20L, 21L, 22L, 23L),
    historical = c(42L, 43L, 46L, 47L, 48L),
    statistical = c(19L, 49L),
    historical_statistical = c(19L, 49L),
    commodity = c(14L, 15L, 16L),
    historical_commodity = c(14L, 15L, 16L),
    integer()
  )
  required <- if (source_dataset == "forecast") {
    c(
      "forecast_world_macro", "forecast_australia_macro",
      "forecast_commodity_sector", "forecast_selected_exports",
      "forecast_steel_making", "forecast_oil", "forecast_gas",
      "forecast_thermal_coal", "forecast_gold"
    )
  } else if (source_dataset == "historical") {
    c(
      "history_annual_export_volume", "history_annual_export_value_part_1",
      "history_annual_production", "history_quarterly_exports_value",
      "history_monthly_benchmark_prices", "history_commodity_aluminium",
      "history_commodity_gold", "history_commodity_zinc"
    )
  } else if (source_dataset %in%
      c("statistical", "historical_statistical")) {
    c(
      "history_annual_export_value", "history_annual_export_unit_value",
      "history_annual_production", "history_annual_employment"
    )
  } else {
    c(
      "forecast_world_macro", "forecast_australia_macro",
      "forecast_commodity_sector", "forecast_aluminium",
      "forecast_thermal_coal", "forecast_gold", "forecast_zinc"
    )
  }
  if (source_dataset == "forecast" && length(sheets) == 16L &&
      !"Thermal coal" %in% sheets) {
    required <- setdiff(required, "forecast_thermal_coal")
  }
  if (!nrow(out) %in% accepted_counts ||
      anyDuplicated(out$table_id) ||
      !all(required %in% out$table_id)) {
    req_abort(
      "req_workbook_schema_error",
      sprintf(
        "%s workbook mapped %d sheets outside an audited REQ workbook profile.",
        source_dataset, nrow(out)
      ),
      asset_type = source_dataset,
      remediation = paste0(
        "Inspect actual sheet titles and structural fingerprints; add an ",
        "explicit release profile before admitting structural drift."
      )
    )
  }
  out
}
